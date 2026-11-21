import Foundation
import SwiftData

public actor PersistenceController {
    public static let shared = PersistenceController()

    public let modelContainer: ModelContainer

    private init(inMemory: Bool = false) {
        let schema = Schema([
            LEDDevice.self,
            WeeklySchedule.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )

        do {
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    public static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.modelContainer.mainContext

        let device1 = LEDDevice(
            name: "Bedroom Lights",
            room: "Bedroom",
            serviceUUID: "FFF0",
            characteristicUUID: "FFF1",
            isConnected: true,
            lastKnownState: RGBCCT.warmWhite.data
        )
        let device2 = LEDDevice(
            name: "Living Room",
            room: "Living Room",
            serviceUUID: "FFF0",
            characteristicUUID: "FFF1",
            isConnected: false,
            lastKnownState: RGBCCT.off.data
        )

        context.insert(device1)
        context.insert(device2)

        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = 7
        components.minute = 0
        let weekdaysOn = calendar.date(from: components)!
        components.hour = 23
        components.minute = 0
        let weekdaysOff = calendar.date(from: components)!
        components.hour = 8
        components.minute = 0
        let weekendOn = calendar.date(from: components)!
        components.hour = 22
        components.minute = 0
        let weekendOff = calendar.date(from: components)!

        let schedule1 = WeeklySchedule(
            name: "Bedroom Schedule",
            weekdaysOn: weekdaysOn,
            weekdaysOff: weekdaysOff,
            weekendOn: weekendOn,
            weekendOff: weekendOff,
            targetColor: RGBCCT.warmWhite.data,
            targetIntensity: 0.8,
            targetColorTemp: 3000,
            isEnabled: true
        )
        schedule1.device = device1
        context.insert(schedule1)

        return controller
    }()

    public func newBackgroundContext() -> ModelContext {
        ModelContext(modelContainer)
    }
}

extension PersistenceController {
    public func save(context: ModelContext) throws {
        try context.save()
    }

    public func delete<T: PersistentModel>(_ object: T, in context: ModelContext) {
        context.delete(object)
    }

    public func fetch<T: PersistentModel>(
        _ type: T.Type,
        predicate: Predicate<T>? = nil,
        sortBy: [SortDescriptor<T>] = [],
        in context: ModelContext
    ) throws -> [T] {
        let descriptor = FetchDescriptor<T>(predicate: predicate, sortBy: sortBy)
        return try context.fetch(descriptor)
    }
}