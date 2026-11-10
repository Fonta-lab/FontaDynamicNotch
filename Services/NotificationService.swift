import Foundation
import UserNotifications

/// macOS notifications, used as a fallback (missed timers, alarm sound failure). Asks for
/// permission the first time one is needed (SPEC §14).
@MainActor
final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    func post(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        Task {
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            try? await center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }
}
