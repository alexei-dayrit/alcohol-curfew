import Foundation
import UserNotifications
import Observation

@MainActor
@Observable
final class NotificationManager {
    private(set) var isAuthorized = false

    private let hydrationID = "hydration"

    func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else {
            isAuthorized = [.authorized, .provisional].contains(settings.authorizationStatus)
            return
        }
        do {
            isAuthorized = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            isAuthorized = false
        }
    }

    func scheduleHydrationReminder(in minutes: Int) async {
        guard isAuthorized else { return }
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        guard !pending.contains(where: { $0.identifier == hydrationID }) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Stay Hydrated 💧"
        content.body = "You've been drinking. Have a glass of water."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(minutes * 60),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: hydrationID,
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    func cancelHydrationReminders() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [hydrationID])
    }
}
