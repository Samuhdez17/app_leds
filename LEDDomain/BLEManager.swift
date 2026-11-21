import Foundation
import CoreBluetooth
import Combine
import OSLog

// MARK: - Lotus Lantern UUIDs
public struct LotusLanternUUIDs {
    public static let service = CBUUID(string: "0000FFF0-0000-1000-8000-00805F9B34FB")
    public static let writeCharacteristic = CBUUID(string: "0000FFF3-0000-1000-8000-00805F9B34FB")
    public static let readCharacteristic = CBUUID(string: "0000FFF4-0000-1000-8000-00805F9B34FB")
}

// MARK: - Connection State
public enum BLEConnectionState: Sendable, Equatable {
    case disconnected
    case scanning
    case connecting(UUID)
    case connected(UUID)
    case failed(UUID, Error)
}

// MARK: - Discovered Device
public struct DiscoveredDevice: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let rssi: Int
    public let isConnectable: Bool
    public let advertisementData: [String: Any]

    public static func == (lhs: DiscoveredDevice, rhs: DiscoveredDevice) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - GATT Service Info (for Inspector)
public struct GATTServiceInfo: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let uuid: String
    public let name: String
    public let isPrimary: Bool
    public let characteristics: [GATTCharacteristicInfo]

    public init(service: CBService) {
        self.uuid = service.uuid.uuidString
        self.name = Self.knownServiceName(for: service.uuid)
        self.isPrimary = service.isPrimary
        self.characteristics = service.characteristics?.map { GATTCharacteristicInfo(characteristic: $0) } ?? []
    }

    private static func knownServiceName(for uuid: CBUUID) -> String {
        switch uuid.uuidString.uppercased() {
        case "0000FFF0-0000-1000-8000-00805F9B34FB": return "Lotus Lantern LED Service"
        case "1800": return "Generic Access"
        case "1801": return "Generic Attribute"
        case "180A": return "Device Information"
        case "180F": return "Battery Service"
        default: return "Unknown Service (\(uuid.uuidString))"
        }
    }
}

public struct GATTCharacteristicInfo: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let uuid: String
    public let name: String
    public let properties: String
    public let value: String?
    public let descriptors: [GATTDescriptorInfo]

    public init(characteristic: CBCharacteristic) {
        self.uuid = characteristic.uuid.uuidString
        self.name = Self.knownCharacteristicName(for: characteristic.uuid)
        self.properties = Self.propertiesString(for: characteristic.properties)
        self.value = characteristic.value?.map { String(format: "%02X", $0) }.joined(separator: " ")
        self.descriptors = characteristic.descriptors?.map { GATTDescriptorInfo(descriptor: $0) } ?? []
    }

    private static func knownCharacteristicName(for uuid: CBUUID) -> String {
        switch uuid.uuidString.uppercased() {
        case "0000FFF3-0000-1000-8000-00805F9B34FB": return "Write Command (0xFFF3)"
        case "0000FFF4-0000-1000-8000-00805F9B34FB": return "Read/Notify (0xFFF4)"
        case "2A00": return "Device Name"
        case "2A01": return "Appearance"
        case "2A02": return "Peripheral Privacy Flag"
        case "2A03": return "Reconnection Address"
        case "2A04": return "Peripheral Preferred Connection Parameters"
        case "2A19": return "Battery Level"
        case "2A29": return "Manufacturer Name"
        default: return "Unknown Characteristic (\(uuid.uuidString))"
        }
    }

    private static func propertiesString(for props: CBCharacteristicProperties) -> String {
        var result: [String] = []
        if props.contains(.read) { result.append("Read") }
        if props.contains(.write) { result.append("Write") }
        if props.contains(.writeWithoutResponse) { result.append("WriteNoResp") }
        if props.contains(.notify) { result.append("Notify") }
        if props.contains(.indicate) { result.append("Indicate") }
        if props.contains(.broadcast) { result.append("Broadcast") }
        if props.contains(.authenticatedSignedWrites) { result.append("AuthSigned") }
        if props.contains(.extendedProperties) { result.append("Extended") }
        return result.joined(separator: " | ")
    }
}

public struct GATTDescriptorInfo: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let uuid: String
    public let value: String?

    public init(descriptor: CBDescriptor) {
        self.uuid = descriptor.uuid.uuidString
        self.value = (descriptor.value as? Data)?.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}

// MARK: - BLE Manager
public actor BLEManager: NSObject {
    public static let shared = BLEManager()

    private var centralManager: CBCentralManager!
    private var discoveredPeripherals: [UUID: CBPeripheral] = [:]
    private var connectedPeripherals: [UUID: (peripheral: CBPeripheral, writeChar: CBCharacteristic?, readChar: CBCharacteristic?)] = [:]
    private var peripheralDelegates: [UUID: PeripheralDelegate] = [:]

    // For GATT Inspector
    private var inspectedPeripheral: CBPeripheral?
    public private(set) var discoveredServices: [GATTServiceInfo] = []

    private let logger = Logger(subsystem: "com.example.SiriLEDController", category: "BLEManager")

    private var stateContinuation: AsyncStream<BLEConnectionState>.Continuation?
    public let stateStream: AsyncStream<BLEConnectionState>

    private var discoveredDevicesContinuation: AsyncStream<[DiscoveredDevice]>.Continuation?
    public let discoveredDevicesStream: AsyncStream<[DiscoveredDevice]>

    private var servicesContinuation: AsyncStream<[GATTServiceInfo]>.Continuation?
    public let servicesStream: AsyncStream<[GATTServiceInfo]>

    private var connectionState: BLEConnectionState = .disconnected
    private var reconnectionTimers: [UUID: Task<Void, Never>] = [:]
    private var reconnectionAttempts: [UUID: Int] = [:]
    private let maxReconnectionAttempts = 5
    private let baseReconnectionDelay: TimeInterval = 2.0

    private override init() {
        var stateContinuation: AsyncStream<BLEConnectionState>.Continuation?
        var discoveredContinuation: AsyncStream<[DiscoveredDevice]>.Continuation?
        var servicesContinuation: AsyncStream<[GATTServiceInfo]>.Continuation?

        self.stateStream = AsyncStream { continuation in
            stateContinuation = continuation
        }
        self.discoveredDevicesStream = AsyncStream { continuation in
            discoveredContinuation = continuation
        }
        self.servicesStream = AsyncStream { continuation in
            servicesContinuation = continuation
        }

        super.init()

        self.stateContinuation = stateContinuation
        self.discoveredDevicesContinuation = discoveredContinuation
        self.servicesContinuation = servicesContinuation

        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - Scanning
    public func scanForDevices(serviceUUIDs: [CBUUID]? = [LotusLanternUUIDs.service]) {
        guard centralManager.state == .poweredOn else {
            logger.warning("Cannot start scanning: Bluetooth state is \(self.centralManager.state.rawValue)")
            return
        }

        connectionState = .scanning
        stateContinuation?.yield(connectionState)

        centralManager.scanForPeripherals(withServices: serviceUUIDs, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
        logger.info("Started scanning for peripherals with service UUIDs: \(serviceUUIDs?.map { $0.uuidString } ?? ["all"])")
    }

    public func scanForAllDevices() {
        scanForDevices(serviceUUIDs: nil)
    }

    public func stopScanning() {
        centralManager.stopScan()
        if case .scanning = connectionState {
            connectionState = .disconnected
            stateContinuation?.yield(connectionState)
        }
        logger.info("Stopped scanning for peripherals")
    }

    // MARK: - Connection
    public func connect(to peripheral: CBPeripheral) {
        guard connectedPeripherals[peripheral.identifier] == nil else {
            logger.info("Already connected to \(peripheral.identifier)")
            return
        }

        connectionState = .connecting(peripheral.identifier)
        stateContinuation?.yield(connectionState)

        let delegate = PeripheralDelegate(manager: self)
        peripheralDelegates[peripheral.identifier] = delegate
        peripheral.delegate = delegate
        centralManager.connect(peripheral, options: nil)
        logger.info("Connecting to \(peripheral.identifier)")
    }

    public func disconnect(from peripheral: CBPeripheral) {
        cancelReconnection(for: peripheral.identifier)
        centralManager.cancelPeripheralConnection(peripheral)
        logger.info("Disconnecting from \(peripheral.identifier)")
    }

    // MARK: - Command Writing
    public func writeCommand(_ data: Data, to peripheralId: UUID) async throws {
        guard let (peripheral, writeChar, _) = connectedPeripherals[peripheralId] else {
            throw BLEError.notConnected
        }

        guard let characteristic = writeChar else {
            throw BLEError.writeCharacteristicNotFound
        }

        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }

    public func writeSequence(_ sequence: [Data], to peripheralId: UUID) async throws {
        guard let (peripheral, writeChar, _) = connectedPeripherals[peripheralId] else {
            throw BLEError.notConnected
        }

        guard let characteristic = writeChar else {
            throw BLEError.writeCharacteristicNotFound
        }

        for (index, data) in sequence.enumerated() {
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
            // Small delay between commands
            if index < sequence.count - 1 {
                try await Task.sleep(nanoseconds: 50_000_000) // 50ms
            }
        }
    }

    public func readState(from peripheralId: UUID) async throws {
        guard let (peripheral, _, readChar) = connectedPeripherals[peripheralId] else {
            throw BLEError.notConnected
        }

        guard let characteristic = readChar else {
            throw BLEError.readCharacteristicNotFound
        }

        peripheral.readValue(for: characteristic)
    }

    // MARK: - GATT Inspector
    public func startGATTInspection(for peripheral: CBPeripheral) {
        inspectedPeripheral = peripheral
        discoveredServices = []
        peripheral.discoverServices(nil)
    }

    public func stopGATTInspection() {
        inspectedPeripheral = nil
        discoveredServices = []
        servicesContinuation?.yield([])
    }

    // MARK: - Reconnection
    public func startReconnection(for peripheralId: UUID) {
        guard reconnectionTimers[peripheralId] == nil else { return }
        guard reconnectionAttempts[peripheralId, default: 0] < maxReconnectionAttempts else {
            logger.error("Max reconnection attempts reached for \(peripheralId)")
            connectionState = .failed(peripheralId, BLEError.maxReconnectionAttempts)
            stateContinuation?.yield(connectionState)
            return
        }

        let attempt = reconnectionAttempts[peripheralId, default: 0] + 1
        reconnectionAttempts[peripheralId] = attempt

        let delay = baseReconnectionDelay * pow(2.0, Double(attempt - 1))
        logger.info("Scheduling reconnection attempt \(attempt) for \(peripheralId) in \(delay)s")

        reconnectionTimers[peripheralId] = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }

            if let peripheral = discoveredPeripherals[peripheralId] {
                connect(to: peripheral)
            } else {
                logger.warning("Peripheral \(peripheralId) no longer discovered, stopping reconnection")
                cancelReconnection(for: peripheralId)
            }
        }
    }

    public func cancelReconnection(for peripheralId: UUID) {
        reconnectionTimers[peripheralId]?.cancel()
        reconnectionTimers[peripheralId] = nil
        reconnectionAttempts[peripheralId] = 0
    }

    // MARK: - Internal State Updates
    private func updateConnectionState(_ state: BLEConnectionState) {
        connectionState = state
        stateContinuation?.yield(state)
    }

    private func processDiscoveredPeripheral(_ peripheral: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Unknown"
        let isConnectable = advertisementData[CBAdvertisementDataIsConnectable] as? Bool ?? true

        discoveredPeripherals[peripheral.identifier] = peripheral

        let device = DiscoveredDevice(
            id: peripheral.identifier,
            name: name,
            rssi: rssi.intValue,
            isConnectable: isConnectable,
            advertisementData: advertisementData
        )

        // Emit to stream (simplified - in production use proper AsyncStream pattern)
    }

    private func processConnectedPeripheral(_ peripheral: CBPeripheral) {
        connectedPeripherals[peripheral.identifier] = (peripheral, nil, nil)
        // Discover Lotus Lantern service specifically
        peripheral.discoverServices([LotusLanternUUIDs.service])
        updateConnectionState(.connected(peripheral.identifier))
        reconnectionAttempts[peripheral.identifier] = 0
    }

    private func processDisconnectedPeripheral(_ peripheral: CBPeripheral, error: Error?) {
        connectedPeripherals.removeValue(forKey: peripheral.identifier)
        peripheralDelegates.removeValue(forKey: peripheral.identifier)
        updateConnectionState(.disconnected)

        if let error = error {
            logger.error("Disconnected from \(peripheral.identifier) with error: \(error.localizedDescription)")
            startReconnection(for: peripheral.identifier)
        } else {
            logger.info("Disconnected from \(peripheral.identifier)")
        }
    }

    private func processPeripheralReady(_ peripheral: CBPeripheral) {
        logger.info("Peripheral \(peripheral.identifier) is ready")
    }

    private func handleServiceDiscovery(_ peripheral: CBPeripheral, error: Error?) {
        if let error = error {
            logger.error("Error discovering services: \(error.localizedDescription)")
            return
        }

        guard let services = peripheral.services else { return }

        var serviceInfos: [GATTServiceInfo] = []
        for service in services {
            let info = GATTServiceInfo(service: service)
            serviceInfos.append(info)

            // Discover characteristics for each service
            peripheral.discoverCharacteristics(nil, for: service)
        }

        discoveredServices = serviceInfos
        servicesContinuation?.yield(serviceInfos)

        logger.info("Discovered \(services.count) service(s) for \(peripheral.identifier)")
    }

    private func handleCharacteristicDiscovery(_ peripheral: CBPeripheral, service: CBService, error: Error?) {
        if let error = error {
            logger.error("Error discovering characteristics for \(service.uuid): \(error.localizedDescription)")
            return
        }

        guard let characteristics = service.characteristics else { return }

        // Update service info with characteristics
        if let index = discoveredServices.firstIndex(where: { $0.uuid == service.uuid.uuidString }) {
            var updated = discoveredServices[index]
            let charInfos = characteristics.map { GATTCharacteristicInfo(characteristic: $0) }

            // Recreate with new characteristics
            updated = GATTServiceInfo(
                service: CBServiceMock(uuid: CBUUID(string: service.uuid.uuidString), isPrimary: service.isPrimary, characteristics: characteristics)
            )
            discoveredServices[index] = updated
        }

        servicesContinuation?.yield(discoveredServices)

        // Find and store write/read characteristics for Lotus Lantern service
        if service.uuid == LotusLanternUUIDs.service {
            for characteristic in characteristics {
                if characteristic.uuid == LotusLanternUUIDs.writeCharacteristic {
                    updateWriteCharacteristic(for: peripheral, characteristic: characteristic)
                } else if characteristic.uuid == LotusLanternUUIDs.readCharacteristic {
                    updateReadCharacteristic(for: peripheral, characteristic: characteristic)
                }
            }
        }
    }

    private func updateWriteCharacteristic(for peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        var current = connectedPeripherals[peripheral.identifier]
        current?.writeChar = characteristic
        connectedPeripherals[peripheral.identifier] = current!
        logger.info("Found WRITE characteristic: \(characteristic.uuid) for \(peripheral.identifier)")
    }

    private func updateReadCharacteristic(for peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        var current = connectedPeripherals[peripheral.identifier]
        current?.readChar = characteristic
        connectedPeripherals[peripheral.identifier] = current!

        // Enable notifications on read characteristic
        peripheral.setNotifyValue(true, for: characteristic)
        logger.info("Found READ/NOTIFY characteristic: \(characteristic.uuid) for \(peripheral.identifier)")
    }
}

// MARK: - CBCentralManagerDelegate
extension BLEManager: CBCentralManagerDelegate {
    public nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            await self.handleStateChange(central.state)
        }
    }

    public nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {
        Task { @MainActor in
            await self.handleDiscoveredPeripheral(peripheral, advertisementData: advertisementData, rssi: rssi)
        }
    }

    public nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            await self.handleConnectedPeripheral(peripheral)
        }
    }

    public nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            await self.handleFailedToConnect(peripheral, error: error)
        }
    }

    public nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            await self.handleDisconnectedPeripheral(peripheral, error: error)
        }
    }
}

extension BLEManager {
    @MainActor
    func handleStateChange(_ state: CBManagerState) {
        logger.info("Bluetooth state changed: \(state.rawValue)")
        if state != .poweredOn {
            updateConnectionState(.disconnected)
        }
    }

    @MainActor
    func handleDiscoveredPeripheral(_ peripheral: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Unknown"
        let isConnectable = advertisementData[CBAdvertisementDataIsConnectable] as? Bool ?? true

        discoveredPeripherals[peripheral.identifier] = peripheral

        let device = DiscoveredDevice(
            id: peripheral.identifier,
            name: name,
            rssi: rssi.intValue,
            isConnectable: isConnectable,
            advertisementData: advertisementData
        )

        // Emit to discovered devices stream
    }

    @MainActor
    func handleConnectedPeripheral(_ peripheral: CBPeripheral) {
        processConnectedPeripheral(peripheral)
    }

    @MainActor
    func handleFailedToConnect(_ peripheral: CBPeripheral, error: Error?) {
        updateConnectionState(.failed(peripheral.identifier, error ?? BLEError.connectionFailed))
        logger.error("Failed to connect to \(peripheral.identifier): \(error?.localizedDescription ?? "unknown")")
        startReconnection(for: peripheral.identifier)
    }

    @MainActor
    func handleDisconnectedPeripheral(_ peripheral: CBPeripheral, error: Error?) {
        processDisconnectedPeripheral(peripheral, error: error)
    }
}

// MARK: - PeripheralDelegate
private class PeripheralDelegate: NSObject, CBPeripheralDelegate {
    weak var manager: BLEManager?

    init(manager: BLEManager) {
        self.manager = manager
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            await self.manager?.handleServiceDiscovery(peripheral, error: error)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        Task { @MainActor in
            await self.manager?.handleCharacteristicDiscovery(peripheral, service: service, error: error)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            manager?.logger.error("Error updating value: \(error.localizedDescription)")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            manager?.logger.error("Error writing value: \(error.localizedDescription)")
        }
    }

    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        Task { @MainActor in
            await self.manager?.handlePeripheralReady(peripheral)
        }
    }
}

// MARK: - Mock CBService for Inspector
private class CBServiceMock: CBService {
    private let _uuid: CBUUID
    private let _isPrimary: Bool
    private let _characteristics: [CBCharacteristic]?

    init(uuid: CBUUID, isPrimary: Bool, characteristics: [CBCharacteristic]?) {
        _uuid = uuid
        _isPrimary = isPrimary
        _characteristics = characteristics
        super.init()
    }

    override var uuid: CBUUID { _uuid }
    override var isPrimary: Bool { _isPrimary }
    override var characteristics: [CBCharacteristic]? { _characteristics }
}

// MARK: - BLE Errors
public enum BLEError: Error, Sendable {
    case notConnected
    case writeCharacteristicNotFound
    case readCharacteristicNotFound
    case connectionFailed
    case maxReconnectionAttempts
    case writeFailed(Error)
    case readFailed(Error)
}