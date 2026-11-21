import Foundation
import UIKit
import BackgroundTasks
import SwiftData
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    private let scheduleEngine = ScheduleEngine.shared
    private let notificationManager = NotificationManager.shared

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Register background task
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.example.SiriLEDController.schedule-evaluation", using: nil) { task in
            self.handleScheduleEvaluation(task: task as! BGAppRefreshTask)
        }

        // Request notification permissions
        notificationManager.requestAuthorization()

        // Reschedule background task on launch
        scheduleBackgroundTask()

        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        scheduleBackgroundTask()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Evaluate schedules immediately on foreground
        Task {
            await evaluateAndExecuteSchedules()
        }
    }

    private func scheduleBackgroundTask() {
        let request = BGAppRefreshTaskRequest(identifier: "com.example.SiriLEDController.schedule-evaluation")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule background task: \(error)")
        }
    }

    private func handleScheduleEvaluation(task: BGAppRefreshTask) {
        scheduleBackgroundTask() // Schedule next one

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        Task {
            await evaluateAndExecuteSchedules()
            task.setTaskCompleted(success: true)
        }
    }

    private func evaluateAndExecuteSchedules() async {
        let actions = scheduleEngine.evaluateSchedules()

        for action in actions {
            await executeAction(action)
        }
    }

    private func executeAction(_ action: ScheduleAction) async {
        let bleManager = BLEManager.shared
        let encoder = CommonLEDCommandEncoder.shared

        do {
            switch action.type {
            case .turnOn(let deviceId, let targetColor, let intensity, let colorTemp):
                let data = encoder.encodeFullState(
                    power: true,
                    red: targetColor.red,
                    green: targetColor.green,
                    blue: targetColor.blue,
                    warmWhite: targetColor.warmWhite,
                    coolWhite: targetColor.coolWhite,
                    intensity: intensity,
                    colorTemp: Int(colorTemp)
                )
                try await bleManager.writeCommand(data, to: deviceId)

                // Update device state in SwiftData
                await updateDeviceState(deviceId: deviceId, state: targetColor, intensity: intensity, colorTemp: colorTemp)

            case .turnOff(let deviceId):
                let data = encoder.encodePower(on: false)
                try await bleManager.writeCommand(data, to: deviceId)

                // Update device state
                await updateDeviceState(deviceId: deviceId, state: .off, intensity: 0, colorTemp: 4000)
            }
        } catch {
            print("Failed to execute schedule action: \(error)")
            await notificationManager.sendScheduleFailedNotification(
                deviceId: action.deviceId,
                action: action.type
            )
        }
    }

    private func updateDeviceState(deviceId: UUID, state: RGBCCT, intensity: Double, colorTemp: Double) async {
        let context = PersistenceController.shared.newBackgroundContext()

        do {
            let descriptor = FetchDescriptor<LEDDevice>(
                predicate: #Predicate { $0.id == deviceId }
            )
            if let device = try context.fetch(descriptor).first {
                device.lastKnownState = state.data
                device.updatedAt = Date()
                try context.save()
            }
        } catch {
            print("Failed to update device state: \(error)")
        }
    }
}