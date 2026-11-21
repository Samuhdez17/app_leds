import SwiftUI
import SwiftData

@main
struct SiriLEDControllerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(persistenceController.modelContainer)
    }
}