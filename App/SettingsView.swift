import SwiftUI
import SwiftData
import StudioCore
import UserNotifications

struct SettingsView: View {
    @AppStorage("defaultProvider") private var defaultProvider = ProviderID.openAI.rawValue
    @AppStorage("defaultCount") private var defaultCount = 4
    @AppStorage("defaultRatio") private var defaultRatio = AspectRatio.square.rawValue
    @AppStorage("notifyOnCompletion") private var notifyOnCompletion = false
    @Environment(StudioModel.self) private var studio
    #if os(macOS)
    @EnvironmentObject private var sparkleUpdater: SparkleUpdater
    #endif
    @State private var storage = "Calculating…"

    var body: some View {
        Form {
            Section {
                Label("Your studio. Your provider.", systemImage: "key.horizontal")
                    .font(.headline)
                Text("Connect an API account to generate images. ChatGPT Plus/Pro and Grok consumer subscriptions do not automatically include API access. API billing is separate.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(ProviderID.allCases) { provider in
                Section(provider.title) { ProviderSettings(provider: provider) }
            }
            Section {
                Picker("Default model", selection: $defaultProvider) {
                    ForEach(ProviderID.allCases) { Text("\($0.title) · \($0.model)").tag($0.rawValue) }
                }
                Picker("Variants", selection: $defaultCount) {
                    ForEach(1...4, id: \.self) { Text("\($0)").tag($0) }
                }
                Picker("Aspect ratio", selection: $defaultRatio) {
                    ForEach(AspectRatio.allCases) { Text($0.rawValue).tag($0.rawValue) }
                }
                Button("Apply defaults to the studio") {
                    studio.provider = ProviderID(rawValue: defaultProvider) ?? .openAI
                    studio.count = defaultCount
                    studio.ratio = AspectRatio(rawValue: defaultRatio) ?? .square
                }.disabled(studio.isGenerating)
            } header: { Text("Generation defaults") }
            footer: { Text("Defaults apply on the next app launch. Apply now to update the current composer.") }
            Section {
                Toggle("Notify when images are ready", isOn: Binding(get: { notifyOnCompletion }, set: { enabled in
                    if !enabled { notifyOnCompletion = false; return }
                    Task {
                        do {
                            notifyOnCompletion = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                            if !notifyOnCompletion { studio.message = "Notifications are disabled. Allow them in system Settings." }
                        } catch { studio.message = error.localizedDescription }
                    }
                }))
            } header: { Text("Notifications") }
            footer: { Text("Sent only when generation finishes while the app is in the background. iOS limits background time. Long requests can stop if you leave the app; keep it open for reliable results.") }
            #if os(macOS)
            Section {
                if !sparkleUpdater.isConfigured {
                    Text("Update signing is not configured. Set SPARKLE_PUBLIC_ED_KEY in project.yml and the SPARKLE_PRIVATE_KEY GitHub secret.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Toggle("Automatically check for updates", isOn: Binding(
                    get: { sparkleUpdater.automaticallyChecksForUpdates },
                    set: { sparkleUpdater.setAutomaticallyChecksForUpdates($0) }
                )).disabled(!sparkleUpdater.isConfigured)
                Toggle("Automatically download updates", isOn: Binding(
                    get: { sparkleUpdater.automaticallyDownloadsUpdates },
                    set: { sparkleUpdater.setAutomaticallyDownloadsUpdates($0) }
                )).disabled(!sparkleUpdater.isConfigured || !sparkleUpdater.automaticallyChecksForUpdates)
                Button("Check for Updates Now") { sparkleUpdater.checkForUpdates() }
                    .disabled(!sparkleUpdater.isConfigured || !sparkleUpdater.canCheckForUpdates)
            } header: { Text("Updates") }
            footer: { Text("Mac updates use Sparkle and the GitHub Releases appcast. Builds are unsigned until you add an Apple Developer certificate.") }
            #endif
            Section("Local storage") {
                LabeledContent("Images and thumbnails", value: storage)
                Text("History and favorites stay on this device. Images are stored in the app’s private folder. Delete individual images from History to free space. Deleting the app removes its library.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Privacy") {
                Text("API keys are stored in Keychain on this device. They are never stored in preferences or shared with the other provider. No analytics or app-operated server is used. Prompts and reference images follow the selected provider’s data policy.")
                    .font(.caption).foregroundStyle(.secondary)
                Link("OpenAI API data policy", destination: URL(string: "https://platform.openai.com/docs/guides/your-data")!)
                Link("xAI privacy policy", destination: URL(string: "https://x.ai/legal/privacy-policy")!)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .task {
            do { storage = ByteCountFormatter.string(fromByteCount: try await ImageStore.shared.byteCount(), countStyle: .file) }
            catch { storage = "Unavailable" }
        }
    }
}

private struct ProviderSettings: View {
    let provider: ProviderID
    @Environment(StudioModel.self) private var studio
    @State private var key = ""
    @State private var configured = false
    @State private var removing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(provider.model).font(.subheadline.monospaced())
                Spacer()
                Label(configured ? "Key saved" : "Not connected", systemImage: configured ? "checkmark.shield" : "circle.dashed")
                    .font(.caption).foregroundStyle(configured ? Color.green : Color.secondary)
            }
            SecureField(configured ? "Enter replacement API key" : "Enter API key", text: $key)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .privacySensitive()
            HStack {
                Button("Save key") {
                    do { try CredentialStore.save(key, for: provider); key = ""; configured = true }
                    catch { studio.message = error.localizedDescription }
                }.disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if configured { Button("Remove", role: .destructive) { removing = true } }
                Spacer()
                Link("Get API key ↗", destination: URL(string: provider == .openAI ? "https://platform.openai.com/api-keys" : "https://console.x.ai")!)
            }.font(.subheadline)
            Text("Saving a key does not verify access or spend API credit. The first generation checks provider access.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .task {
            do { configured = try CredentialStore.read(provider) != nil }
            catch { studio.message = error.localizedDescription }
        }
        .onDisappear { key = "" }
        .confirmationDialog("Remove the saved API key?", isPresented: $removing, titleVisibility: .visible) {
            Button("Remove key", role: .destructive) {
                do { try CredentialStore.remove(provider); configured = false; key = "" }
                catch { studio.message = error.localizedDescription }
            }
        }
    }
}
