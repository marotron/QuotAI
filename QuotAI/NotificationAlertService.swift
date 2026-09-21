import Foundation
import UserNotifications

/// Thin UserNotifications adapter — not unit-tested.
enum NotificationAlertService {
    private static let presenter = ForegroundPresenter()

    /// Must run early so banners still appear while Settings (`.regular`) is frontmost.
    static func install() {
        let center = UNUserNotificationCenter.current()
        center.delegate = presenter
    }

    static func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound])
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }

    /// Returns `true` only when the system accepted the request.
    @discardableResult
    static func deliver(subject: String, body: String) async -> Bool {
        install()
        guard await requestAuthorizationIfNeeded() else { return false }
        let content = UNMutableNotificationContent()
        content.title = subject
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "pace-alert-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        do {
            try await UNUserNotificationCenter.current().add(request)
            return true
        } catch {
            return false
        }
    }
}

/// Shows banners even when QuotAI is foregrounded (Settings window).
private final class ForegroundPresenter: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}
