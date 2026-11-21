import Foundation
import Testing
@testable import LEDCore

@Suite("BLEManager Tests")
struct BLEManagerTests {

    @Test("BLEConnectionState equality")
    func testBLEConnectionStateEquality() {
        let disconnected = BLEConnectionState.disconnected
        let scanning = BLEConnectionState.scanning
        let id = UUID()

        #expect(disconnected == disconnected)
        #expect(scanning == scanning)
        #expect(BLEConnectionState.connecting(id) == BLEConnectionState.connecting(id))
        #expect(BLEConnectionState.connected(id) == BLEConnectionState.connected(id))
        #expect(BLEConnectionState.failed(id, BLEError.notConnected) == BLEConnectionState.failed(id, BLEError.notConnected))
        #expect(disconnected != scanning)
    }

    @Test("DiscoveredDevice equality")
    func testDiscoveredDeviceEquality() {
        let id = UUID()
        let device1 = DiscoveredDevice(id: id, name: "Test", rssi: -50, isConnectable: true, advertisementData: [:])
        let device2 = DiscoveredDevice(id: id, name: "Test", rssi: -50, isConnectable: true, advertisementData: [:])
        let device3 = DiscoveredDevice(id: UUID(), name: "Other", rssi: -60, isConnectable: true, advertisementData: [:])

        #expect(device1 == device2)
        #expect(device1 != device3)
    }

    @Test("BLEError cases")
    func testBLEErrorCases() {
        let errors: [BLEError] = [
            .notConnected,
            .characteristicNotFound,
            .connectionFailed,
            .maxReconnectionAttempts,
            .writeFailed(.connectionFailed),
            .readFailed(.connectionFailed)
        ]

        for error in errors {
            #expect(error.localizedDescription.count > 0)
        }
    }
}

@Suite("MockBLEManager Tests")
struct MockBLEManagerTests {

    @Test("MockBLEManager scan updates state")
    func testMockScan() {
        var mock = MockBLEManager()
        #expect(mock.connectionState == .disconnected)

        mock.scanForDevices()
        #expect(mock.connectionState == .scanning)
    }

    @Test("MockBLEManager successful connection")
    func testMockConnectSuccess() async throws {
        var mock = MockBLEManager()
        let id = UUID()

        try await mock.connect(to: id)

        #expect(mock.connectionState == .connected(id))
        #expect(mock.lastConnectedPeripheral == id)
    }

    @Test("MockBLEManager failed connection")
    func testMockConnectFailure() async {
        var mock = MockBLEManager()
        mock.shouldFailConnection = true
        let id = UUID()

        do {
            try await mock.connect(to: id)
            #expect(Bool(false), "Should have thrown")
        } catch {
            #expect(mock.connectionState == .failed(id, BLEError.connectionFailed))
        }
    }

    @Test("MockBLEManager disconnect")
    func testMockDisconnect() async throws {
        var mock = MockBLEManager()
        let id = UUID()

        try await mock.connect(to: id)
        #expect(mock.connectionState == .connected(id))

        mock.disconnect(from: id)
        #expect(mock.connectionState == .disconnected)
        #expect(mock.lastConnectedPeripheral == nil)
    }

    @Test("MockBLEManager write command")
    func testMockWriteCommand() async throws {
        var mock = MockBLEManager()
        let id = UUID()

        try await mock.connect(to: id)
        let testData = Data([0x01, 0x02, 0x03])

        try await mock.writeCommand(testData, to: id)

        #expect(mock.lastWrittenData == testData)
    }

    @Test("MockBLEManager write failure")
    func testMockWriteFailure() async {
        var mock = MockBLEManager()
        mock.shouldFailWrite = true
        let id = UUID()

        try await mock.connect(to: id)

        do {
            try await mock.writeCommand(Data([0x01]), to: id)
            #expect(Bool(false), "Should have thrown")
        } catch {
            #expect(error is BLEError)
        }
    }

    @Test("MockBLEManager read state")
    func testMockReadState() async throws {
        var mock = MockBLEManager()
        let id = UUID()

        try await mock.connect(to: id)
        let state = try await mock.readState(from: id)

        #expect(state.count > 0)
    }
}