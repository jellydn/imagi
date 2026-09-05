import SwiftUI
import SwiftData

struct ImageViewer: View {
    @State var image: ImageAsset
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(StudioModel.self) private var studio
    @Query private var allImages: [ImageAsset]
    @State private var deleting = false
    @State private var zoomed = false

    private var parent: ImageAsset? {
        guard let parentID = image.generation?.parentImageID else { return nil }
        return allImages.first { $0.id == parentID }
    }
    private var children: [ImageAsset] {
        allImages.filter { $0.generation?.parentImageID == image.id }.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        LocalImage(filename: image.filename, thumbnail: false)
                            .frame(height: max(260, geometry.size.height * (zoomed ? 1.2 : 0.60)))
                            .clipShape(.rect(cornerRadius: 12))
                            .onTapGesture(count: 2) { zoomed.toggle() }
                            .accessibilityLabel("Generated image. \(image.generation?.prompt ?? "")")
                        HStack {
                            Button { studio.refine(image); dismiss() } label: { Label("Refine image", systemImage: "sparkles") }
                                .buttonStyle(.borderedProminent).disabled(studio.isGenerating)
                            ImageShareLink(filename: image.filename).buttonStyle(.bordered)
                            Spacer()
                            Button(zoomed ? "Fit" : "Enlarge") { zoomed.toggle() }.buttonStyle(.bordered)
                        }
                        if let generation = image.generation {
                            Text(generation.prompt).font(.headline).textSelection(.enabled)
                            Text("\(generation.model) · \(generation.ratioRaw) · Variant \(image.index + 1)")
                                .font(.caption).foregroundStyle(.secondary)
                            Text(generation.createdAt, format: .dateTime).font(.caption).foregroundStyle(.secondary)
                            Divider()
                            Text("GENERATION PATH").font(.caption.weight(.semibold)).tracking(1)
                            if let parent {
                                Button { image = parent; zoomed = false } label: {
                                    Label("Back to reference · Variant \(parent.index + 1)", systemImage: "arrow.up.left")
                                }
                            } else {
                                Text(generation.parentImageID == nil ? "Original generation" : "Reference image was deleted")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            if !children.isEmpty {
                                ScrollView(.horizontal) {
                                    HStack(spacing: 12) {
                                        ForEach(children) { child in
                                            Button { image = child; zoomed = false } label: {
                                                VStack {
                                                    LocalImage(filename: child.filename).frame(width: 90, height: 90)
                                                        .clipShape(.rect(cornerRadius: 8))
                                                    Text("Refine · \(child.index + 1)").font(.caption)
                                                }
                                            }.buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                    }.padding(20)
                }
            }
            .navigationTitle("Variant \(image.index + 1)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        ImageActions(image: image, onLeave: { dismiss() }, onDelete: { deleting = true })
                    } label: { Label("Image actions", systemImage: "ellipsis.circle") }
                }
            }
            .confirmationDialog("Delete this image?", isPresented: $deleting, titleVisibility: .visible) {
                Button("Delete image", role: .destructive) {
                    let target = image
                    dismiss()
                    Task { await studio.delete(target, context: context) }
                }
            } message: { Text("This removes the local file. Existing refinements remain, but cannot reuse this reference.") }
            .alert("Image Studio", isPresented: Binding(get: { studio.message != nil }, set: { if !$0 { studio.message = nil } })) {
                Button("OK") { studio.message = nil }
            } message: { Text(studio.message ?? "") }
        }
    }
}
