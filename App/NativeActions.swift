import SwiftUI
import Photos
import UserNotifications
#if os(iOS)
import UIKit
#endif

@MainActor
enum NativeActions {
    static func saveToPhotos(_ filename: String) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw PhotoError()
        }
        let data = try await ImageStore.shared.read(filename)
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
        }
    }

    static func haptic(completed: Bool) {
        #if os(iOS)
        if completed { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        else { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        #endif
    }

    static func beginBackgroundTime(expiration: @escaping @MainActor () -> Void) -> Int {
        #if os(iOS)
        return UIApplication.shared.beginBackgroundTask(withName: "Image generation") {
            Task { @MainActor in expiration() }
        }.rawValue
        #else
        return 0
        #endif
    }

    static func endBackgroundTime(_ token: Int) {
        #if os(iOS)
        let identifier = UIBackgroundTaskIdentifier(rawValue: token)
        if identifier != .invalid { UIApplication.shared.endBackgroundTask(identifier) }
        #endif
    }

    static func notifyCompletion() async {
        let content = UNMutableNotificationContent()
        content.title = "Your images are ready"
        content.body = "Open Image Studio to compare your new variants."
        content.sound = .default
        // Notifications are best-effort; generated images remain saved if delivery fails.
        try? await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        )
    }

    private struct PhotoError: LocalizedError {
        var errorDescription: String? { "Allow Photos access in system Settings to save images. You can still use Share to export a file." }
    }
}
