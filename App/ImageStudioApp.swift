import SwiftUI
import SwiftData

@main
struct ImageStudioApp: App {
    private let persistence: Result<ModelContainer, Error>
    @State private var studio = StudioModel()

    init() {
        persistence = Result {
            let schema = Schema([GenerationRecord.self, ImageAsset.self])
            let config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            return try ModelContainer(for: schema, configurations: [config])
        }
    }

    var body: some Scene {
        WindowGroup {
            switch persistence {
            case .success(let container):
                RootView()
                    .modelContainer(container)
                    .environment(studio)
                    .tint(StudioTheme.accent)
            case .failure:
                ContentUnavailableView("Library could not open", systemImage: "externaldrive.badge.exclamationmark",
                    description: Text("Restart the app and check free storage. Your existing library has not been deleted."))
                    .padding()
            }
        }
        #if os(macOS)
        .defaultSize(width: 1180, height: 820)
        #endif
    }
}

enum StudioTheme {
    static let accent = Color(red: 0.83, green: 0.29, blue: 0.13)
    static let canvas = Color.primary.opacity(0.035)
}

struct RootView: View {
    @Environment(StudioModel.self) private var studio
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var studio = studio
        TabView(selection: $studio.tab) {
            NavigationStack { StudioView() }
                .tabItem { Label("Create", systemImage: "sparkles") }.tag(StudioTab.create)
            NavigationStack { LibraryView(favoritesOnly: false) }
                .tabItem { Label("History", systemImage: "clock") }.tag(StudioTab.history)
            NavigationStack { LibraryView(favoritesOnly: true) }
                .tabItem { Label("Favorites", systemImage: "heart") }.tag(StudioTab.favorites)
            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }.tag(StudioTab.settings)
        }
        .onChange(of: scenePhase) { _, phase in studio.isBackgrounded = phase == .background }
        .alert("Image Studio", isPresented: Binding(get: { studio.message != nil }, set: { if !$0 { studio.message = nil } })) {
            Button("OK") { studio.message = nil }
        } message: { Text(studio.message ?? "") }
    }
}
