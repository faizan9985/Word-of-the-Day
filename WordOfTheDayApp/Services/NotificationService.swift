// Target membership: WordOfTheDay app only

import Foundation
import UserNotifications

actor NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private let requestIdentifier = "daily-word-reminder"

    func setDailyReminder(enabled: Bool, hour: Int = 9) async throws {
        if enabled {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            guard granted else { throw NotificationError.permissionDenied }

            let content = UNMutableNotificationContent()
            content.title = "Your word of the day is ready"
            content.body = "Open the app to learn a new word."
            content.sound = .default

            var components = DateComponents()
            components.hour = hour
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: components,
                repeats: true
            )
            let request = UNNotificationRequest(
                identifier: requestIdentifier,
                content: content,
                trigger: trigger
            )
            try await center.add(request)
        } else {
            center.removePendingNotificationRequests(withIdentifiers: [requestIdentifier])
        }
    }
}

extension NotificationService {
    enum NotificationError: LocalizedError {
        case permissionDenied

        var errorDescription: String? {
            "Notifications are disabled. You can enable them in Settings."
        }
    }
}
