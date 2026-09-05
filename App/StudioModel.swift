import SwiftUI
import SwiftData
import StudioCore

enum StudioTab: Hashable { case create, history, favorites, settings }

@MainActor @Observable
final class StudioModel {
    var tab: StudioTab = .create
    var prompt = ""
    var provider: ProviderID
    var count: Int
    var ratio: AspectRatio
    var reference: ImageAsset?
    var current: GenerationRecord?
    var isGenerating = false
    var message: String?
    var notice: String?
    var isBackgrounded = false
    private var generationTask: Task<Void, Never>?
    private let service = ImageGenerationService()

    init() {
        let defaults = UserDefaults.standard
        provider = ProviderID(rawValue: defaults.string(forKey: "defaultProvider") ?? "") ?? .openAI
        count = [1, 2, 3, 4].contains(defaults.integer(forKey: "defaultCount")) ? defaults.integer(forKey: "defaultCount") : 4
        ratio = AspectRatio(rawValue: defaults.string(forKey: "defaultRatio") ?? "") ?? .square
    }

    func refine(_ image: ImageAsset) {
        guard !isGenerating else { return }
        reference = image
        prompt = ""
        if let generation = image.generation {
            provider = generation.options.provider
            ratio = generation.options.ratio
            current = generation
        }
        tab = .create
    }

    func reuse(_ generation: GenerationRecord, allImages: [ImageAsset]) {
        guard !isGenerating else { return }
        if let parentID = generation.parentImageID {
            guard let parent = allImages.first(where: { $0.id == parentID }) else {
                message = "The reference image was deleted. Choose a new reference to repeat this edit."
                return
            }
            reference = parent
        } else { reference = nil }
        prompt = generation.prompt
        provider = generation.options.provider
        count = generation.requestedCount
        ratio = generation.options.ratio
        current = generation
        tab = .create
        notice = "Settings restored. Select Generate to create new variants. API charges apply."
    }

    func generate(context: ModelContext) {
        guard !isGenerating else { return }
        let options = GenerationOptions(provider: provider, count: count, ratio: ratio)
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let parentID = reference?.id
        let referenceFile = reference?.filename
        isGenerating = true
        notice = nil
        NativeActions.haptic(completed: false)
        generationTask = Task {
            let backgroundToken = NativeActions.beginBackgroundTime { [weak self] in self?.cancel() }
            defer {
                NativeActions.endBackgroundTime(backgroundToken)
                isGenerating = false
                generationTask = nil
            }
            var savedFiles: [String] = []
            do {
                let key = try CredentialStore.read(options.provider) ?? ""
                let referenceData: Data?
                if let referenceFile { referenceData = try await ImageStore.shared.read(referenceFile) }
                else { referenceData = nil }
                let request = ImageRequest(prompt: text, options: options, referencePNG: referenceData)
                let data = try await service.generate(request, apiKey: key)
                try Task.checkCancellation()
                savedFiles = try await ImageStore.shared.save(data, cropTo: options.provider == .openAI ? options.ratio : nil)
                try Task.checkCancellation()
                let record = GenerationRecord(prompt: text, options: options, parentImageID: parentID)
                context.insert(record)
                for (index, filename) in savedFiles.enumerated() {
                    let image = ImageAsset(filename: filename, index: index, generation: record)
                    context.insert(image)
                }
                try context.save()
                current = record
                NativeActions.haptic(completed: true)
                notice = "\(data.count) variants saved to History."
                if isBackgrounded && UserDefaults.standard.bool(forKey: "notifyOnCompletion") {
                    await NativeActions.notifyCompletion()
                }
            } catch {
                context.rollback()
                for file in savedFiles { try? await ImageStore.shared.remove(file) }
                if Task.isCancelled || (error as? URLError)?.code == .cancelled {
                    notice = "Generation stopped. The provider may still charge for work already started."
                } else { message = error.localizedDescription }
            }
        }
    }

    func cancel() { generationTask?.cancel() }

    func favorite(_ image: ImageAsset, context: ModelContext) {
        image.isFavorite.toggle()
        do { try context.save() } catch { context.rollback(); message = error.localizedDescription }
    }

    func delete(_ image: ImageAsset, context: ModelContext) async {
        guard !isGenerating else { return }
        let filename = image.filename
        if reference?.id == image.id { reference = nil }
        context.delete(image)
        do {
            try context.save()
            try await ImageStore.shared.remove(filename)
        } catch {
            context.rollback()
            message = "Could not finish deleting the image: \(error.localizedDescription)"
        }
    }
}
