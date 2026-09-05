import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct LocalImage: View {
    let filename: String
    var thumbnail = true
    @State private var image: Image?
    @State private var failed = false

    var body: some View {
        ZStack {
            StudioTheme.canvas
            if let image { image.resizable().scaledToFit() }
            else if failed {
                Label("Image unavailable", systemImage: "photo.badge.exclamationmark")
                    .font(.caption).foregroundStyle(.secondary)
            } else { ProgressView() }
        }
        .task(id: filename + String(thumbnail)) {
            image = nil
            failed = false
            do {
                let data = try await ImageStore.shared.read(filename + (thumbnail ? ".thumb.png" : ""))
                try Task.checkCancellation()
                #if os(macOS)
                if let native = NSImage(data: data) { image = Image(nsImage: native) }
                #else
                if let native = UIImage(data: data) { image = Image(uiImage: native) }
                #endif
                failed = image == nil
            } catch {
                if !Task.isCancelled { failed = true }
            }
        }
    }
}

struct ImageGrid: View {
    let images: [ImageAsset]
    var columns: Int? = nil
    var tileHeight: CGFloat? = nil
    @Environment(StudioModel.self) private var studio
    @Environment(\.modelContext) private var context
    @State private var selected: ImageAsset?
    @State private var deleting: ImageAsset?

    private var layout: [GridItem] {
        if let columns { return Array(repeating: GridItem(.flexible(), spacing: 16), count: columns) }
        return [GridItem(.adaptive(minimum: 170, maximum: 360), spacing: 16)]
    }

    var body: some View {
        LazyVGrid(columns: layout, spacing: 18) {
            ForEach(images) { image in
                VStack(alignment: .leading, spacing: 9) {
                    Button { selected = image } label: {
                        LocalImage(filename: image.filename)
                            .aspectRatio(tileHeight == nil ? 1 : nil, contentMode: .fit)
                            .frame(height: tileHeight)
                            .clipShape(.rect(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open variant \(image.index + 1): \(image.generation?.prompt ?? "Image")")
                    .contextMenu { ImageActions(image: image, onDelete: { deleting = image }) }
                    HStack {
                        Text("Variant \(image.index + 1)").font(.caption.weight(.medium))
                        Spacer()
                        Button { studio.favorite(image, context: context) } label: {
                            Image(systemName: image.isFavorite ? "heart.fill" : "heart")
                                .foregroundStyle(image.isFavorite ? StudioTheme.accent : .secondary)
                        }
                        .buttonStyle(.plain)
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityLabel(image.isFavorite ? "Remove favorite" : "Favorite")
                    }
                }
            }
        }
        #if os(iOS)
        .fullScreenCover(item: $selected) { ImageViewer(image: $0) }
        #else
        .sheet(item: $selected) { ImageViewer(image: $0).frame(minWidth: 720, minHeight: 640) }
        #endif
        .confirmationDialog("Delete this image?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("Delete image", role: .destructive) {
                if let image = deleting { Task { await studio.delete(image, context: context) } }
                deleting = nil
            }
        } message: { Text("This removes the local file. Existing refinements remain, but cannot reuse this reference.") }
    }
}

struct ImageActions: View {
    let image: ImageAsset
    var onLeave: () -> Void = {}
    let onDelete: () -> Void
    @Environment(StudioModel.self) private var studio
    @Environment(\.modelContext) private var context
    @Query private var allImages: [ImageAsset]

    var body: some View {
        Button {
            Task {
                do { try await NativeActions.saveToPhotos(image.filename); studio.message = "Saved to Photos." }
                catch { studio.message = error.localizedDescription }
            }
        } label: { Label("Save to Photos", systemImage: "square.and.arrow.down") }
        ImageShareLink(filename: image.filename)
        Button { studio.favorite(image, context: context) } label: {
            Label(image.isFavorite ? "Remove favorite" : "Favorite", systemImage: image.isFavorite ? "heart.slash" : "heart")
        }
        Button { studio.refine(image); onLeave() } label: { Label("Refine", systemImage: "slider.horizontal.3") }
            .disabled(studio.isGenerating)
        Button {
            if let generation = image.generation { studio.reuse(generation, allImages: allImages); onLeave() }
        } label: { Label("Regenerate…", systemImage: "arrow.clockwise") }
        .disabled(studio.isGenerating)
        Divider()
        Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
            .disabled(studio.isGenerating)
    }
}

struct ImageShareLink: View {
    let filename: String
    var body: some View {
        ShareLink(item: ImageStore.shared.url(for: filename)) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
    }
}

struct LibraryView: View {
    let favoritesOnly: Bool
    @Query(sort: \GenerationRecord.createdAt, order: .reverse) private var history: [GenerationRecord]
    @Query(filter: #Predicate<ImageAsset> { $0.isFavorite }, sort: \ImageAsset.createdAt, order: .reverse)
    private var favorites: [ImageAsset]
    @State private var search = ""

    private var filteredHistory: [GenerationRecord] {
        history.filter { search.isEmpty || $0.prompt.localizedCaseInsensitiveContains(search) }
    }
    private var filteredFavorites: [ImageAsset] {
        favorites.filter { search.isEmpty || ($0.generation?.prompt.localizedCaseInsensitiveContains(search) ?? false) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                if favoritesOnly {
                    if filteredFavorites.isEmpty {
                        ContentUnavailableView("Keep the ones you love", systemImage: "heart",
                            description: Text(search.isEmpty ? "Favorite an image to find it here." : "No favorites match this prompt."))
                    } else { ImageGrid(images: filteredFavorites) }
                } else if filteredHistory.isEmpty {
                    ContentUnavailableView("Your ideas live here", systemImage: "clock",
                        description: Text(search.isEmpty ? "Generated images and refinements are saved automatically." : "No generations match this prompt."))
                } else {
                    ForEach(filteredHistory) { generation in
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text(generation.createdAt, format: .dateTime.month().day().hour().minute())
                                    .font(.caption.weight(.semibold)).foregroundStyle(StudioTheme.accent)
                                Spacer()
                                if generation.parentImageID != nil { Label("Refinement", systemImage: "arrow.turn.down.right").font(.caption) }
                            }
                            Text(generation.prompt).font(.headline).textSelection(.enabled)
                            Text("\(generation.model) · \(generation.ratioRaw) · \(generation.images.count)/\(generation.requestedCount) images")
                                .font(.caption).foregroundStyle(.secondary)
                            ImageGrid(images: generation.orderedImages)
                            Divider()
                        }
                    }
                }
            }.padding(24).frame(maxWidth: 1200)
                .frame(maxWidth: .infinity)
        }
        .background(StudioTheme.canvas)
        .navigationTitle(favoritesOnly ? "Favorites" : "History")
        .searchable(text: $search, prompt: "Search prompts")
    }
}
