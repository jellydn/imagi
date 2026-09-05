#if os(macOS)
import Foundation
import Sparkle

private let sparkleAppcastFeedURL = "https://raw.githubusercontent.com/jellydn/imagi/main/appcast.xml"

@MainActor
final class SparkleUpdater: NSObject, ObservableObject, SPUUpdaterDelegate {
    @Published var canCheckForUpdates = false
    @Published var automaticallyChecksForUpdates = true
    @Published var automaticallyDownloadsUpdates = false
    @Published private(set) var isConfigured = false

    private var updaterController: SPUStandardUpdaterController?
    private var canCheckObservation: NSKeyValueObservation?

    override init() {
        super.init()
        guard Self.hasValidPublicEDKey else { return }
        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
        updaterController = controller
        isConfigured = true
        canCheckForUpdates = controller.updater.canCheckForUpdates
        automaticallyChecksForUpdates = controller.updater.automaticallyChecksForUpdates
        automaticallyDownloadsUpdates = controller.updater.automaticallyDownloadsUpdates
        canCheckObservation = controller.updater.observe(\.canCheckForUpdates, options: [.new]) { [weak self] _, change in
            Task { @MainActor [weak self] in
                self?.canCheckForUpdates = change.newValue ?? false
            }
        }
    }

    func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        updaterController?.updater.automaticallyChecksForUpdates = enabled
        automaticallyChecksForUpdates = enabled
    }

    func setAutomaticallyDownloadsUpdates(_ enabled: Bool) {
        updaterController?.updater.automaticallyDownloadsUpdates = enabled
        automaticallyDownloadsUpdates = enabled
    }

    nonisolated func feedURLString(for _: SPUUpdater) -> String? {
        sparkleAppcastFeedURL
    }

    private static var hasValidPublicEDKey: Bool {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String else { return false }
        let key = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return !key.isEmpty && !key.contains("$(")
    }
}
#endif
