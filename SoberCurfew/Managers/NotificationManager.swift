import Foundation
import UserNotifications
import Observation

@Observable
final class NotificationManager {
    private(set) var isAuthorized = false

    private let hydrationID = "hydration"

    func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else {
            isAuthorized = settings.authorizationStatus == .authorized
            return
        }
        do {
            isAuthorized = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            isAuthorized = false
        }
    }

    func scheduleHydrationReminder(in minutes: Int) {
        guard isAuthorized else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [hydrationID])

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
        center.add(request)
    }

    func cancelHydrationReminders() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [hydrationID])
    }
}
