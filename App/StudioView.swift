import SwiftUI
import SwiftData
import StudioCore

struct StudioView: View {
    @Environment(StudioModel.self) private var studio
    @Environment(\.modelContext) private var context
    @Query(sort: \GenerationRecord.createdAt, order: .reverse) private var history: [GenerationRecord]

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width >= 760 {
                HStack(alignment: .top, spacing: 0) {
                    ScrollView { composer.padding(24) }
                        .frame(width: geometry.size.width < 1000 ? 320 : 350)
                    Divider()
                    ScrollView {
                        results(tileHeight: max(120, (geometry.size.height - 330) / 2)).padding(32)
                    }.background(StudioTheme.canvas)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        composer
                        Divider()
                        results()
                    }.padding(22)
                }
            }
        }
        .navigationTitle("Image Studio")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    studio.prompt = ""
                    studio.reference = nil
                    studio.current = nil
                    studio.notice = nil
                } label: { Label("New canvas", systemImage: "square.and.pencil") }
                .disabled(studio.isGenerating)
            }
        }
    }

    private var composer: some View {
        @Bindable var studio = studio
        return VStack(alignment: .leading, spacing: 25) {
            VStack(alignment: .leading, spacing: 8) {
                Text("YOUR NEXT IDEA, IN VIEW")
                    .font(.caption2.weight(.semibold)).tracking(2).foregroundStyle(StudioTheme.accent)
                Text(studio.reference == nil ? "What do you\nimagine?" : "Make it\nyour own.")
                    .font(.system(.largeTitle, design: .serif).weight(.medium))
                Text(studio.reference == nil ? "One idea. A few possibilities." : "Describe what to change. Keep the original.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            if let reference = studio.reference {
                HStack(spacing: 12) {
                    LocalImage(filename: reference.filename).frame(width: 54, height: 54).clipShape(.rect(cornerRadius: 8))
                    VStack(alignment: .leading) {
                        Text("Reference image").font(.subheadline.weight(.medium))
                        Text("Variant \(reference.index + 1)").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { studio.reference = nil } label: { Image(systemName: "xmark.circle.fill") }
                        .accessibilityLabel("Remove reference")
                }.padding(12).background(StudioTheme.canvas, in: .rect(cornerRadius: 14))
            }
            VStack(alignment: .leading, spacing: 10) {
                Text(studio.reference == nil ? "PROMPT" : "REFINEMENT").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                TextField(studio.reference == nil ? "A tiny astronaut exploring futuristic Singapore at night, cinematic, warm lighting…" : "Keep everything, but change the lighting to golden hour…", text: $studio.prompt, axis: .vertical)
                    .lineLimit(6...12)
                    .textFieldStyle(.plain)
                    .padding(16)
                    .background(StudioTheme.canvas, in: .rect(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.10)))
                    .accessibilityLabel("Image prompt")
                if studio.prompt.isEmpty && studio.reference == nil {
                    Button("Try a little inspiration ↗") {
                        studio.prompt = "A tiny astronaut exploring futuristic Singapore at night, cinematic composition, warm amber lighting, intricate miniature city"
                    }.font(.caption).buttonStyle(.plain).foregroundStyle(StudioTheme.accent)
                }
            }
            VStack(alignment: .leading, spacing: 16) {
                Picker("Provider", selection: $studio.provider) {
                    ForEach(ProviderID.allCases) { Text($0.title).tag($0) }
                }
                Text(studio.provider.model).font(.caption.monospaced()).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Variants").font(.subheadline.weight(.medium))
                    Picker("Variants", selection: $studio.count) {
                        ForEach(1...4, id: \.self) { Text("\($0)").tag($0) }
                    }.pickerStyle(.segmented)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Aspect ratio").font(.subheadline.weight(.medium))
                    Picker("Aspect ratio", selection: $studio.ratio) {
                        ForEach(AspectRatio.allCases) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented)
                    if studio.provider == .openAI && studio.ratio != .square {
                        Text("OpenAI generates at \(studio.ratio.openAISize). The result is center-cropped to \(studio.ratio.rawValue).")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Button { studio.generate(context: context) } label: {
                HStack {
                    Spacer()
                    Image(systemName: "sparkles")
                    Text(studio.reference == nil ? "Generate \(studio.count) variants" : "Refine · \(studio.count) variants")
                    Spacer()
                }.font(.headline).padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .disabled(studio.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Text("Uses your provider API credit. Prompts and reference images are sent only to the selected provider.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .disabled(studio.isGenerating)
    }

    private func results(tileHeight: CGFloat? = nil) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .firstTextBaseline) {
                Text("The canvas").font(.title2.weight(.semibold))
                Spacer()
                Text(studio.isGenerating ? "CREATING" : "EXPLORE · COMPARE · REFINE")
                    .font(.caption2.weight(.medium)).tracking(1).foregroundStyle(.secondary)
            }
            if studio.isGenerating {
                HStack(spacing: 14) {
                    ProgressView()
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Making room for your idea…").font(.subheadline.weight(.medium))
                        Text("This can take a few minutes. Keep the app open.").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Cancel", role: .cancel) { studio.cancel() }
                }.padding().background(StudioTheme.accent.opacity(0.08), in: .rect(cornerRadius: 14))
            }
            if let notice = studio.notice {
                Label(notice, systemImage: "info.circle").font(.caption).foregroundStyle(.secondary)
            }
            if let generation = studio.current {
                VStack(alignment: .leading, spacing: 6) {
                    Text(generation.prompt).font(.subheadline).lineLimit(3)
                    Text("\(generation.model) · \(generation.ratioRaw) · \(generation.images.count) images")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ImageGrid(images: generation.orderedImages, columns: 2, tileHeight: tileHeight)
            } else {
                VStack(spacing: 18) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24).fill(StudioTheme.accent.opacity(0.06))
                            .frame(width: 132, height: 148).rotationEffect(.degrees(-12)).offset(x: -17, y: 3)
                        RoundedRectangle(cornerRadius: 24).fill(.background)
                            .frame(width: 132, height: 148).rotationEffect(.degrees(8))
                            .shadow(color: .black.opacity(0.05), radius: 18, y: 8)
                        Image(systemName: "sparkles.rectangle.stack").font(.system(size: 42, weight: .ultraLight))
                            .foregroundStyle(StudioTheme.accent)
                    }.frame(height: 185).accessibilityHidden(true)
                    Text("A blank canvas.\nEndless possibilities.")
                        .font(.system(.title2, design: .serif)).multilineTextAlignment(.center)
                    Text("Describe a scene, choose your settings,\nand see where your imagination goes.")
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("Connect a provider") { studio.tab = .settings }.buttonStyle(.bordered)
                }.frame(maxWidth: .infinity).padding(.vertical, 32)
            }
            if studio.current == nil, let recent = history.first, !recent.images.isEmpty {
                Divider()
                HStack {
                    Text("Pick up where you left off").font(.subheadline.weight(.medium))
                    Spacer()
                    Button("View") { studio.current = recent }.font(.subheadline)
                }
                ImageGrid(images: Array(recent.orderedImages.prefix(4)), columns: 2)
            }
        }
    }
}
