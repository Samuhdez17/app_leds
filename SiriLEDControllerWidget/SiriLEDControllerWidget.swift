import WidgetKit
import SwiftUI

@main
struct SiriLEDControllerWidget: Widget {
    let kind: String = "SiriLEDControllerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WidgetProvider()) { entry in
            WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("LED Controller")
        .description("Quick control and status for your LED devices")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemSmall) {
    SiriLEDControllerWidget()
} timeline: {
    WidgetEntry(date: Date(), devices: [
        WidgetDeviceEntry(id: "1", name: "Bedroom", room: "Bedroom", isConnected: true, state: .warmWhite)
    ], nextSchedule: nil)
}

#Preview(as: .systemMedium) {
    SiriLEDControllerWidget()
} timeline: {
    WidgetEntry(date: Date(), devices: [
        WidgetDeviceEntry(id: "1", name: "Bedroom", room: "Bedroom", isConnected: true, state: .warmWhite),
        WidgetDeviceEntry(id: "2", name: "Living Room", room: "Living Room", isConnected: false, state: .off),
        WidgetDeviceEntry(id: "3", name: "Kitchen", room: "Kitchen", isConnected: true, state: .coolWhite)
    ], nextSchedule: nil)
}

#Preview(as: .systemLarge) {
    SiriLEDControllerWidget()
} timeline: {
    WidgetEntry(date: Date(), devices: [
        WidgetDeviceEntry(id: "1", name: "Bedroom", room: "Bedroom", isConnected: true, state: .warmWhite),
        WidgetDeviceEntry(id: "2", name: "Living Room", room: "Living Room", isConnected: false, state: .off),
        WidgetDeviceEntry(id: "3", name: "Kitchen", room: "Kitchen", isConnected: true, state: .coolWhite),
        WidgetDeviceEntry(id: "4", name: "Office", room: "Office", isConnected: true, state: .neutralWhite)
    ], nextSchedule: nil)
}