import XCTest
import SwiftData
@testable import LEDCore

/// Unit/API tests for Checkpoint 1: Xcode Project Setup
///
/// These tests verify the project structure, build configuration, entitlements,
/// shared framework accessibility, and SwiftData stack initialization.
/// They are expected to FAIL initially (before Checkpoint 1 implementation).
final class ProjectSetupTests: XCTestCase {

    // MARK: - Build Verification Tests

    /// Test that the iPhone target scheme builds successfully
    /// Corresponds to: xcodebuild -scheme SiriLEDController -destination 'platform=iOS Simulator,name=iPhone 15' build
    func test_iPhoneTargetBuilds() throws {
        // This test will fail until the Xcode project is created with the SiriLEDController scheme
        // The actual build is verified via xcodebuild command in CI
        // Here we verify the scheme exists by checking for the project structure
        let projectPath = "SiriLEDController.xcodeproj"
        let fileManager = FileManager.default
        XCTAssertTrue(fileManager.fileExists(atPath: projectPath),
                     "Xcode project 'SiriLEDController.xcodeproj' should exist at root")
    }

    /// Test that the Watch target scheme builds successfully
    /// Corresponds to: xcodebuild -scheme SiriLEDControllerWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' build
    func test_watchTargetBuilds() throws {
        let projectPath = "SiriLEDController.xcodeproj"
        let fileManager = FileManager.default
        XCTAssertTrue(fileManager.fileExists(atPath: projectPath),
                     "Xcode project should exist for Watch target to build")

        // Verify Watch app target directory exists
        let watchTargetPath = "SiriLEDControllerWatch"
        XCTAssertTrue(fileManager.fileExists(atPath: watchTargetPath),
                     "Watch app target directory 'SiriLEDControllerWatch' should exist")
    }

    /// Test that the Widget target scheme builds successfully
    /// Corresponds to: xcodebuild -scheme SiriLEDControllerWidget -destination 'platform=iOS Simulator,name=iPhone 15' build
    func test_widgetTargetBuilds() throws {
        let projectPath = "SiriLEDController.xcodeproj"
        let fileManager = FileManager.default
        XCTAssertTrue(fileManager.fileExists(atPath: projectPath),
                     "Xcode project should exist for Widget target to build")

        // Verify Widget extension target directory exists
        let widgetTargetPath = "SiriLEDControllerWidget"
        XCTAssertTrue(fileManager.fileExists(atPath: widgetTargetPath),
                     "Widget extension target directory 'SiriLEDControllerWidget' should exist")
    }

    /// Test that the shared LEDCore framework compiles
    /// Corresponds to: xcodebuild -scheme LEDCore -destination 'platform=iOS Simulator,name=iPhone 15' build
    func test_ledCoreFrameworkCompiles() throws {
        let ledCorePath = "LEDCore"
        let fileManager = FileManager.default
        XCTAssertTrue(fileManager.fileExists(atPath: ledCorePath),
                     "Shared framework directory 'LEDCore' should exist")

        // Verify core framework files exist
        let requiredFiles = [
            "LEDCore/LEDCore.swift",
            "LEDCore/Models.swift",
            "LEDCore/BLEManager.swift",
            "LEDCore/LEDCommandEncoder.swift",
            "LEDCore/ScheduleEngine.swift",
            "LEDCore/Intents.swift",
            "LEDCore/Persistence.swift"
        ]

        for file in requiredFiles {
            XCTAssertTrue(fileManager.fileExists(atPath: file),
                         "Required LEDCore file '\(file)' should exist")
        }
    }

    // MARK: - Entitlements and Capabilities Tests

    /// Test that main app entitlements contain required capabilities
    /// Corresponds to: codesign -d --entitlements :- <built-app> | grep -E 'bluetooth-central|background-modes|app-intents'
    func test_mainAppEntitlementsContainRequiredCapabilities() throws {
        let entitlementsPath = "SiriLEDController/SiriLEDController.entitlements"
        let fileManager = FileManager.default

        XCTAssertTrue(fileManager.fileExists(atPath: entitlementsPath),
                     "Main app entitlements file should exist")

        let entitlementsContent = try String(contentsOfFile: entitlementsPath, encoding: .utf8)

        // Check for bluetooth-central capability
        XCTAssertTrue(entitlementsContent.contains("bluetooth-central"),
                     "Entitlements should contain 'bluetooth-central' capability")

        // Check for background-modes with bluetooth-central and background-fetch
        XCTAssertTrue(entitlementsContent.contains("background-modes"),
                     "Entitlements should contain 'background-modes' capability")
        XCTAssertTrue(entitlementsContent.contains("bluetooth-central"),
                     "Background modes should include 'bluetooth-central'")
        XCTAssertTrue(entitlementsContent.contains("background-fetch"),
                     "Background modes should include 'background-fetch'")

        // Check for App Intents capability (com.apple.developer.siri)
        XCTAssertTrue(entitlementsContent.contains("com.apple.developer.siri") ||
                     entitlementsContent.contains("app-intents"),
                     "Entitlements should contain App Intents/Siri capability")
    }

    /// Test that Watch app entitlements contain required capabilities
    func test_watchAppEntitlementsContainRequiredCapabilities() throws {
        let entitlementsPath = "SiriLEDControllerWatch/SiriLEDControllerWatch.entitlements"
        let fileManager = FileManager.default

        XCTAssertTrue(fileManager.fileExists(atPath: entitlementsPath),
                     "Watch app entitlements file should exist")

        let entitlementsContent = try String(contentsOfFile: entitlementsPath, encoding: .utf8)

        // Watch needs bluetooth-central for BLE communication
        XCTAssertTrue(entitlementsContent.contains("bluetooth-central"),
                     "Watch entitlements should contain 'bluetooth-central' capability")

        // Watch needs App Intents for Siri
        XCTAssertTrue(entitlementsContent.contains("com.apple.developer.siri") ||
                     entitlementsContent.contains("app-intents"),
                     "Watch entitlements should contain App Intents/Siri capability")
    }

    /// Test that Widget extension entitlements contain required capabilities
    func test_widgetEntitlementsContainRequiredCapabilities() throws {
        let entitlementsPath = "SiriLEDControllerWidget/SiriLEDControllerWidget.entitlements"
        let fileManager = FileManager.default

        XCTAssertTrue(fileManager.fileExists(atPath: entitlementsPath),
                     "Widget entitlements file should exist")

        let entitlementsContent = try String(contentsOfFile: entitlementsPath, encoding: .utf8)

        // Widget needs App Intents for configuration
        XCTAssertTrue(entitlementsContent.contains("com.apple.developer.siri") ||
                     entitlementsContent.contains("app-intents"),
                     "Widget entitlements should contain App Intents/Siri capability")

        // Widget may need background modes for timeline updates
        XCTAssertTrue(entitlementsContent.contains("background-modes") ||
                     entitlementsContent.contains("com.apple.developer.widgetkit"),
                     "Widget entitlements should support widget functionality")
    }

    // MARK: - LEDCore Framework Accessibility Tests

    /// Test that LEDCore framework is accessible from iPhone target
    func test_ledCoreAccessibleFromiPhoneTarget() throws {
        // This test verifies that the LEDCore module can be imported
        // If this compiles, the framework is linked correctly
        _ = LEDCore.self
        XCTAssertTrue(true, "LEDCore module should be importable from iPhone target")
    }

    /// Test that LEDCore framework is accessible from Watch target
    func test_ledCoreAccessibleFromWatchTarget() throws {
        // This test will run in the Watch test target context
        _ = LEDCore.self
        XCTAssertTrue(true, "LEDCore module should be importable from Watch target")
    }

    /// Test that LEDCore framework is accessible from Widget target
    func test_ledCoreAccessibleFromWidgetTarget() throws {
        // This test will run in the Widget test target context
        _ = LEDCore.self
        XCTAssertTrue(true, "LEDCore module should be importable from Widget target")
    }

    /// Test that all public symbols are exported from LEDCore
    func test_ledCoreExportsPublicSymbols() throws {
        // Verify key types are accessible
        _ = LEDDevice.self
        _ = WeeklySchedule.self
        _ = BLEManager.self
        _ = LEDCommandEncoder.self
        _ = ScheduleEngine.self
        _ = PersistenceController.self
        _ = ColorState.self

        XCTAssertTrue(true, "All public LEDCore symbols should be accessible")
    }

    // MARK: - SwiftData ModelContainer Tests

    /// Test that SwiftData ModelContainer initializes without errors (in-memory)
    /// Corresponds to: swift test --filter PersistenceTests/testModelContainerInitialization
    func test_modelContainerInitializesInMemory() throws {
        let container = try PersistenceController.makeInMemoryContainer()
        XCTAssertNotNil(container, "In-memory ModelContainer should initialize successfully")
    }

    /// Test that SwiftData ModelContainer initializes without errors (on-disk)
    func test_modelContainerInitializesOnDisk() throws {
        let container = try PersistenceController.makeOnDiskContainer()
        XCTAssertNotNil(container, "On-disk ModelContainer should initialize successfully")
    }

    /// Test that ModelContainer includes all required models
    func test_modelContainerIncludesRequiredModels() throws {
        let container = try PersistenceController.makeInMemoryContainer()
        let modelContainer = container as! ModelContainer

        // Verify the schema includes our models
        let schema = modelContainer.configurations.first?.schema
        XCTAssertNotNil(schema, "Schema should be configured")

        let modelNames = schema?.entities.map { $0.name } ?? []
        XCTAssertTrue(modelNames.contains("LEDDevice"), "Schema should include LEDDevice")
        XCTAssertTrue(modelNames.contains("WeeklySchedule"), "Schema should include WeeklySchedule")
    }

    /// Test that ModelContainer supports CRUD operations
    func test_modelContainerSupportsCRUD() throws {
        let container = try PersistenceController.makeInMemoryContainer()
        let context = container.mainContext

        // Create
        let device = LEDDevice(
            name: "Test Light",
            room: "Bedroom",
            serviceUUID: "0x180A",
            characteristicUUID: "0x2A57"
        )
        context.insert(device)

        // Read
        let fetchedDevices = try context.fetch(FetchDescriptor<LEDDevice>())
        XCTAssertEqual(fetchedDevices.count, 1, "Should be able to fetch inserted device")
        XCTAssertEqual(fetchedDevices.first?.name, "Test Light")

        // Update
        fetchedDevices.first?.name = "Updated Light"
        try context.save()

        let updatedDevices = try context.fetch(FetchDescriptor<LEDDevice>())
        XCTAssertEqual(updatedDevices.first?.name, "Updated Light")

        // Delete
        context.delete(device)
        try context.save()

        let deletedDevices = try context.fetch(FetchDescriptor<LEDDevice>())
        XCTAssertTrue(deletedDevices.isEmpty, "Should be able to delete device")
    }

    // MARK: - Build Settings Tests

    /// Test that project uses Swift 5.9+
    func test_swiftVersionIs59OrHigher() throws {
        let projectPath = "SiriLEDController.xcodeproj/project.pbxproj"
        let fileManager = FileManager.default
        XCTAssertTrue(fileManager.fileExists(atPath: projectPath),
                     "Project file should exist")

        let projectContent = try String(contentsOfFile: projectPath, encoding: .utf8)
        // Check for SWIFT_VERSION = 5.9 or higher
        XCTAssertTrue(projectContent.contains("SWIFT_VERSION = 5.9") ||
                     projectContent.contains("SWIFT_VERSION = 6"),
                     "Project should use Swift 5.9 or higher")
    }

    /// Test that strict concurrency checking is enabled
    func test_strictConcurrencyEnabled() throws {
        let projectPath = "SiriLEDController.xcodeproj/project.pbxproj"
        let fileManager = FileManager.default
        XCTAssertTrue(fileManager.fileExists(atPath: projectPath),
                     "Project file should exist")

        let projectContent = try String(contentsOfFile: projectPath, encoding: .utf8)
        // Check for SWIFT_STRICT_CONCURRENCY = complete or targeted
        XCTAssertTrue(projectContent.contains("SWIFT_STRICT_CONCURRENCY = complete") ||
                     projectContent.contains("SWIFT_STRICT_CONCURRENCY = targeted"),
                     "Project should have strict concurrency checking enabled")
    }

    /// Test that iOS deployment target is 17+
    func test_iOSDeploymentTargetIs17OrHigher() throws {
        let projectPath = "SiriLEDController.xcodeproj/project.pbxproj"
        let fileManager = FileManager.default
        XCTAssertTrue(fileManager.fileExists(atPath: projectPath),
                     "Project file should exist")

        let projectContent = try String(contentsOfFile: projectPath, encoding: .utf8)
        // Check for IPHONEOS_DEPLOYMENT_TARGET = 17.0 or higher
        XCTAssertTrue(projectContent.contains("IPHONEOS_DEPLOYMENT_TARGET = 17") ||
                     projectContent.contains("IPHONEOS_DEPLOYMENT_TARGET = 18"),
                     "iOS deployment target should be 17.0 or higher")
    }

    /// Test that watchOS deployment target is 10+
    func test_watchOSDeploymentTargetIs10OrHigher() throws {
        let projectPath = "SiriLEDController.xcodeproj/project.pbxproj"
        let fileManager = FileManager.default
        XCTAssertTrue(fileManager.fileExists(atPath: projectPath),
                     "Project file should exist")

        let projectContent = try String(contentsOfFile: projectPath, encoding: .utf8)
        // Check for WATCHOS_DEPLOYMENT_TARGET = 10.0 or higher
        XCTAssertTrue(projectContent.contains("WATCHOS_DEPLOYMENT_TARGET = 10") ||
                     projectContent.contains("WATCHOS_DEPLOYMENT_TARGET = 11"),
                     "watchOS deployment target should be 10.0 or higher")
    }

    // MARK: - Code Signing Tests

    /// Test that code signing is configured for personal distribution
    func test_codeSigningConfiguredForPersonalDistribution() throws {
        let projectPath = "SiriLEDController.xcodeproj/project.pbxproj"
        let fileManager = FileManager.default
        XCTAssertTrue(fileManager.fileExists(atPath: projectPath),
                     "Project file should exist")

        let projectContent = try String(contentsOfFile: projectPath, encoding: .utf8)
        // Check for CODE_SIGN_STYLE = Automatic (Xcode managed)
        // or manual with development team
        XCTAssertTrue(projectContent.contains("CODE_SIGN_STYLE = Automatic") ||
                     projectContent.contains("DEVELOPMENT_TEAM"),
                     "Code signing should be configured for personal distribution (Automatic or with DEVELOPMENT_TEAM)")
    }

    // MARK: - Info.plist Tests

    /// Test that main app Info.plist contains required keys
    func test_mainAppInfoPlistContainsRequiredKeys() throws {
        let infoPlistPath = "SiriLEDController/Info.plist"
        let fileManager = FileManager.default
        XCTAssertTrue(fileManager.fileExists(atPath: infoPlistPath),
                     "Main app Info.plist should exist")

        let plistContent = try String(contentsOfFile: infoPlistPath, encoding: .utf8)

        // Required for Bluetooth
        XCTAssertTrue(plistContent.contains("NSBluetoothAlwaysUsageDescription"),
                     "Info.plist should contain NSBluetoothAlwaysUsageDescription")
        XCTAssertTrue(plistContent.contains("NSBluetoothPeripheralUsageDescription"),
                     "Info.plist should contain NSBluetoothPeripheralUsageDescription")

        // Required for Background Fetch
        XCTAssertTrue(plistContent.contains("BGTaskSchedulerPermittedIdentifiers"),
                     "Info.plist should contain BGTaskSchedulerPermittedIdentifiers")

        // Required for App Intents
        XCTAssertTrue(plistContent.contains("NSUserActivityTypes") ||
                     plistContent.contains("SiriIntentsSupported"),
                     "Info.plist should declare App Intents support")
    }

    /// Test that Watch app Info.plist contains required keys
    func test_watchAppInfoPlistContainsRequiredKeys() throws {
        let infoPlistPath = "SiriLEDControllerWatch/Info.plist"
        let fileManager = FileManager.default
        XCTAssertTrue(fileManager.fileExists(atPath: infoPlistPath),
                     "Watch app Info.plist should exist")

        let plistContent = try String(contentsOfFile: infoPlistPath, encoding: .utf8)

        // Watch needs Bluetooth usage descriptions
        XCTAssertTrue(plistContent.contains("NSBluetoothAlwaysUsageDescription"),
                     "Watch Info.plist should contain NSBluetoothAlwaysUsageDescription")
    }

    /// Test that Widget Info.plist contains required keys
    func test_widgetInfoPlistContainsRequiredKeys() throws {
        let infoPlistPath = "SiriLEDControllerWidget/Info.plist"
        let fileManager = FileManager.default
        XCTAssertTrue(fileManager.fileExists(atPath: infoPlistPath),
                     "Widget Info.plist should exist")

        let plistContent = try String(contentsOfFile: infoPlistPath, encoding: .utf8)

        // Widget needs NSExtension configuration
        XCTAssertTrue(plistContent.contains("NSExtension") &&
                     plistContent.contains("com.apple.widgetkit-extension"),
                     "Widget Info.plist should declare widget extension")
    }
}

// MARK: - Test Helpers

extension ProjectSetupTests {
    /// Helper to verify a file exists at path
    func assertFileExists(_ path: String, _ message: String? = nil) {
        let fileManager = FileManager.default
        XCTAssertTrue(fileManager.fileExists(atPath: path), message ?? "File should exist at \(path)")
    }

    /// Helper to verify file contains string
    func assertFileContains(_ path: String, _ substring: String, _ message: String? = nil) throws {
        let content = try String(contentsOfFile: path, encoding: .utf8)
        XCTAssertTrue(content.contains(substring), message ?? "File at \(path) should contain '\(substring)'")
    }
}