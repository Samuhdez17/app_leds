import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            DevicesView()
                .tabItem {
                    Label("Devices", systemImage: "lightbulb.2")
                }
                .tag(0)

            SchedulesView()
                .tabItem {
                    Label("Schedules", systemImage: "calendar")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(2)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [LEDDevice.self, WeeklySchedule.self], inMemory: true)
}