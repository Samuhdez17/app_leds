import SwiftUI
import SwiftData

@main
struct SiriLEDControllerWatchApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            DeviceListView()
        }
        .modelContainer(persistenceController.modelContainer)
    }
}