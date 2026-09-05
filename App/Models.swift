import Foundation
import SwiftData
import StudioCore

@Model
final class GenerationRecord {
    @Attribute(.unique) var id: UUID
    var prompt: String
    var providerRaw: String
    var model: String
    var ratioRaw: String
    var requestedCount: Int
    var createdAt: Date
    var parentImageID: UUID?
    @Relationship(deleteRule: .cascade, inverse: \ImageAsset.generation)
    var images: [ImageAsset] = []

    init(prompt: String, options: GenerationOptions, parentImageID: UUID?) {
        id = UUID()
        self.prompt = prompt
        providerRaw = options.provider.rawValue
        model = options.provider.model
        ratioRaw = options.ratio.rawValue
        requestedCount = options.count
        createdAt = Date()
        self.parentImageID = parentImageID
    }

    var options: GenerationOptions {
        GenerationOptions(provider: ProviderID(rawValue: providerRaw) ?? .openAI,
                          count: requestedCount, ratio: AspectRatio(rawValue: ratioRaw) ?? .square)
    }
    var orderedImages: [ImageAsset] { images.sorted { $0.index < $1.index } }
}

@Model
final class ImageAsset {
    @Attribute(.unique) var id: UUID
    var filename: String
    var index: Int
    var isFavorite = false
    var createdAt: Date
    var generation: GenerationRecord?

    init(filename: String, index: Int, generation: GenerationRecord) {
        id = UUID()
        self.filename = filename
        self.index = index
        createdAt = generation.createdAt
        self.generation = generation
    }
}
