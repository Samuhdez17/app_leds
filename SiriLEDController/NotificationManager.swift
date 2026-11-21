import Foundation
import UserNotifications

public actor NotificationManager {
    public static let shared = NotificationManager()

    private init() {}

    public func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }
    }

    public func sendScheduleFailedNotification(deviceId: UUID, action: ScheduleActionType) {
        let content = UNMutableNotificationContent()
        content.title = "Schedule Failed"
        content.body = "Failed to execute scheduled action for device \(deviceId.uuidString.prefix(8))"
        content.sound = .default
        content.categoryIdentifier = "SCHEDULE_FAILED"

        let request = UNNotificationRequest(
            identifier: "schedule-failed-\(deviceId.uuidString)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }

    public func sendDeviceDisconnectedNotification(deviceId: UUID, deviceName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Device Disconnected"
        content.body = "\(deviceName) is no longer connected"
        content.sound = .default
        content.categoryIdentifier = "DEVICE_DISCONNECTED"

        let request = UNNotificationRequest(
            identifier: "device-disconnected-\(deviceId.uuidString)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }

    public func sendScheduleUpcomingNotification(deviceName: String, action: String, at time: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Upcoming Schedule"
        content.body = "\(deviceName) will \(action) at \(time.formatted(date: .omitted, time: .shortened))"
        content.sound = .default

        let triggerDate = time.addingTimeInterval(-60) // 1 minute before
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "schedule-upcoming-\(deviceName)-\(time.timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }
}