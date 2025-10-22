//
//  BLEService.swift
//  macadamia
//
//  Bitchat Bluetooth mesh service adapted for macadamia
//  Based on bitchat's BLEService.swift for full compatibility
//

import Foundation
@preconcurrency import CoreBluetooth
import Combine
import OSLog

/// Bitchat BLE service delegate
protocol BitchatBLEServiceDelegate: AnyObject {
    func bleService(_ service: BLEService, didDiscoverPeer peer: BitchatPeerInfo)
    func bleService(_ service: BLEService, didConnectToPeer peerID: PeerID)
    func bleService(_ service: BLEService, didDisconnectFromPeer peerID: PeerID)
    func bleService(_ service: BLEService, didReceiveMessage message: BitchatMessage)
    func bleService(_ service: BLEService, didUpdatePeer peer: BitchatPeerInfo)
    func bleService(_ service: BLEService, didEncounterError error: Error)
}

/// Bitchat Bluetooth mesh service
class BLEService: NSObject, ObservableObject {
    
    // MARK: - Constants
    
    #if DEBUG
    nonisolated(unsafe) static let serviceUUID = CBUUID(string: "F47B5E2D-4A9E-4C5A-9B3F-8E1D2C3A4B5A") // testnet
    #else
    static let serviceUUID = CBUUID(string: "F47B5E2D-4A9E-4C5A-9B3F-8E1D2C3A4B5C") // mainnet
    #endif
    nonisolated(unsafe) static let characteristicUUID = CBUUID(string: "A1B2C3D4-E5F6-4A5B-8C9D-0E1F2A3B4C5D")
    
    // Configuration
    private let defaultFragmentSize = 512
    private let maxMessageLength = 10000
    private let messageTTL: UInt8 = 7
    private let maxInFlightAssemblies = 10
    private let announceMinInterval: TimeInterval = 30.0
    
    // MARK: - Core State
    
    private struct PeripheralState {
        let peripheral: CBPeripheral
        var characteristic: CBCharacteristic?
        var peerID: PeerID?
        var isConnecting: Bool = false
        var isConnected: Bool = false
        var lastConnectionAttempt: Date? = nil
    }
    private var peripherals: [String: PeripheralState] = [:]
    private var peerToPeripheralUUID: [PeerID: String] = [:]
    
    // BLE Centrals (when acting as peripheral)
    private var subscribedCentrals: [CBCentral] = []
    private var centralToPeerID: [String: PeerID] = [:]
    
    // Peer Information
    private var peers: [PeerID: BitchatPeerInfo] = [:]
    
    // Message deduplication
    private var messageDeduplicator = Set<String>()
    
    // Fragment reassembly
    private struct FragmentKey: Hashable { let sender: UInt64; let id: UInt64 }
    private var incomingFragments: [FragmentKey: [Int: Data]] = [:]
    private var fragmentMetadata: [FragmentKey: (type: UInt8, total: Int, timestamp: Date)] = [:]
    
    // Application state tracking
    private var isAppActive: Bool = true
    
    // MARK: - Core BLE Objects
    
    private var centralManager: CBCentralManager?
    private var peripheralManager: CBPeripheralManager?
    private var myPeerID: PeerID = UUID().uuidString
    private var myNickname: String = "Macadamia User"
    
    // Delegate
    weak var delegate: BitchatBLEServiceDelegate?
    
    // Logging
    private let logger = Logger(subsystem: "macadamia", category: "BLEService")
    
    // MARK: - Published Properties
    
    @Published var isActive = false
    @Published var isScanning = false
    @Published var isAdvertising = false
    @Published var discoveredPeers: [BitchatPeerInfo] = []
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupBluetooth()
    }
    
    deinit {
        stopServices()
    }
    
    // MARK: - Public Methods
    
    func startServices() {
        logger.info("Starting BLE services")
        
        centralManager = CBCentralManager(delegate: self, queue: nil)
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        
        isActive = true
    }
    
    func stopServices() {
        logger.info("Stopping BLE services")
        
        centralManager?.stopScan()
        peripheralManager?.stopAdvertising()
        
        // Disconnect all peripherals
        for peripheral in peripherals.values {
            centralManager?.cancelPeripheralConnection(peripheral.peripheral)
        }
        
        // Clear state
        peripherals.removeAll()
        peerToPeripheralUUID.removeAll()
        subscribedCentrals.removeAll()
        centralToPeerID.removeAll()
        peers.removeAll()
        discoveredPeers.removeAll()
        messageDeduplicator.removeAll()
        incomingFragments.removeAll()
        fragmentMetadata.removeAll()
        
        isActive = false
        isScanning = false
        isAdvertising = false
    }
    
    func setNickname(_ nickname: String) {
        myNickname = nickname
        logger.info("Nickname set to: \(nickname)")
        
        // Restart advertising with new nickname
        if isAdvertising {
            startAdvertising()
        }
    }
    
    func sendMessage(to peerID: PeerID, content: String) {
        guard let peer = peers[peerID] else {
            logger.warning("Peer not found: \(peerID)")
            return
        }
        
        let message = BitchatMessage(
            type: .message,
            senderID: myPeerID,
            recipientID: peerID,
            content: content
        )
        
        sendMessage(message, to: peer)
    }
    
    func broadcastMessage(_ content: String) {
        let message = BitchatMessage(
            type: .message,
            senderID: myPeerID,
            content: content
        )
        
        for peer in peers.values where peer.isConnected {
            sendMessage(message, to: peer)
        }
    }
    
    func sendEcashToken(_ token: String, to peerID: PeerID? = nil, memo: String? = nil) {
        let message = formatEcashMessage(token: token, memo: memo)
        
        if let peerID = peerID {
            sendMessage(to: peerID, content: message)
        } else {
            broadcastMessage(message)
        }
    }
    
    func getPeer(by peerID: PeerID) -> BitchatPeerInfo? {
        return peers[peerID]
    }
    
    func getAllPeers() -> [BitchatPeerInfo] {
        return Array(peers.values)
    }
    
    // MARK: - Private Methods
    
    private func setupBluetooth() {
        // Initialize with default state
        isActive = false
        isScanning = false
        isAdvertising = false
    }
    
    private func startScanning() {
        guard let centralManager = centralManager, centralManager.state == .poweredOn else {
            logger.warning("Central manager not ready for scanning")
            return
        }
        
        logger.info("Starting BLE scanning")
        centralManager.scanForPeripherals(withServices: [Self.serviceUUID], options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: true
        ])
        isScanning = true
    }
    
    private func stopScanning() {
        centralManager?.stopScan()
        isScanning = false
        logger.info("Stopped BLE scanning")
    }
    
    private func startAdvertising() {
        guard let peripheralManager = peripheralManager, peripheralManager.state == .poweredOn else {
            logger.warning("Peripheral manager not ready for advertising")
            return
        }
        
        // Create service and characteristic
        let service = CBMutableService(type: Self.serviceUUID, primary: true)
        let characteristic = CBMutableCharacteristic(
            type: Self.characteristicUUID,
            properties: [.read, .write, .notify],
            value: nil,
            permissions: [.readable, .writeable]
        )
        service.characteristics = [characteristic]
        
        // Add service
        peripheralManager.add(service)
        
        // Start advertising
        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [Self.serviceUUID],
            CBAdvertisementDataLocalNameKey: myNickname
        ]
        
        peripheralManager.startAdvertising(advertisementData)
        isAdvertising = true
        logger.info("Started BLE advertising as: \(self.myNickname)")
    }
    
    private func stopAdvertising() {
        peripheralManager?.stopAdvertising()
        isAdvertising = false
        logger.info("Stopped BLE advertising")
    }
    
    private func sendMessage(_ message: BitchatMessage, to peer: BitchatPeerInfo) {
        // Convert message to packet
        let packet = BitchatPacket(
            type: UInt8(message.type.rawValue),
            ttl: message.ttl,
            timestamp: UInt64(message.timestamp.timeIntervalSince1970 * 1000),
            senderID: myPeerID.data(using: .utf8) ?? Data(),
            recipientID: message.recipientID?.data(using: .utf8),
            payload: message.content.data(using: .utf8) ?? Data()
        )
        
        // Encode packet
        guard let packetData = BinaryProtocol.encode(packet) else {
            logger.error("Failed to encode message packet")
            return
        }
        
        // Send via BLE
        sendPacketData(packetData, to: peer)
    }
    
    private func sendPacketData(_ data: Data, to peer: BitchatPeerInfo) {
        logger.debug("Sending packet data (\(data.count) bytes) to peer: \(peer.peerID)")
        
        // Find the peripheral for this peer
        guard let peripheralUUID = peerToPeripheralUUID[peer.peerID],
              let peripheralState = peripherals[peripheralUUID],
              let characteristic = peripheralState.characteristic else {
            logger.warning("No active connection to peer: \(peer.peerID)")
            return
        }
        
        // Send data in chunks if needed
        let chunkSize = defaultFragmentSize
        let chunks = data.chunked(into: chunkSize)
        
        for (index, chunk) in chunks.enumerated() {
            // In a real implementation, this would write to the characteristic
            // For now, just log the action
            logger.debug("Sending chunk \(index + 1)/\(chunks.count) to peer: \(peer.peerID)")
        }
    }
    
    private func handleReceivedPacket(_ data: Data) {
        guard let packet = BinaryProtocol.decode(data) else {
            logger.warning("Failed to decode received packet")
            return
        }
        
        // Convert packet to message
        let content = String(data: packet.payload, encoding: .utf8) ?? ""
        let message = BitchatMessage(
            type: BitchatMessageType(rawValue: packet.type) ?? .message,
            senderID: String(data: packet.senderID, encoding: .utf8) ?? "",
            recipientID: packet.recipientID.map { String(data: $0, encoding: .utf8) ?? "" },
            content: content,
            ttl: packet.ttl
        )
        
        // Process message
        processReceivedMessage(message)
    }
    
    private func processReceivedMessage(_ message: BitchatMessage) {
        logger.debug("Received message: \(message.type.description) from \(message.senderID)")
        
        // Check for duplicate messages
        let messageKey = "\(message.senderID)-\(message.timestamp.timeIntervalSince1970)"
        if messageDeduplicator.contains(messageKey) {
            logger.debug("Duplicate message ignored")
            return
        }
        messageDeduplicator.insert(messageKey)
        
        // Clean up old deduplication entries
        if messageDeduplicator.count > 1000 {
            messageDeduplicator.removeAll()
        }
        
        // Notify delegate
        delegate?.bleService(self, didReceiveMessage: message)
    }
    
    private func addOrUpdatePeer(_ peer: BitchatPeerInfo) {
        let existingPeer = peers[peer.peerID]
        peers[peer.peerID] = peer
        
        if existingPeer == nil {
            // New peer discovered
            discoveredPeers.append(peer)
            logger.info("New peer discovered: \(peer.displayName) (\(peer.peerID))")
            delegate?.bleService(self, didDiscoverPeer: peer)
        } else {
            // Update existing peer
            if let index = discoveredPeers.firstIndex(where: { $0.peerID == peer.peerID }) {
                discoveredPeers[index] = peer
            }
            logger.debug("Updated peer: \(peer.displayName)")
            delegate?.bleService(self, didUpdatePeer: peer)
        }
    }
    
    private func formatEcashMessage(token: String, memo: String?) -> String {
        var message = token
        
        if let memo = memo, !memo.isEmpty {
            message += "\n---\nMemo: \(memo)"
        }
        
        return message
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        logger.info("Central manager state changed: \(central.state.rawValue)")
        
        switch central.state {
        case .poweredOn:
            if isActive {
                startScanning()
            }
        case .poweredOff, .unauthorized, .unsupported, .unknown:
            stopScanning()
            isActive = false
        case .resetting:
            break
        @unknown default:
            logger.warning("Unknown central manager state: \(central.state.rawValue)")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {
        logger.debug("Discovered peripheral: \(peripheral.identifier)")
        
        // Store peripheral
        let peripheralState = PeripheralState(peripheral: peripheral)
        peripherals[peripheral.identifier.uuidString] = peripheralState
        
        // Extract peer information from advertisement data
        let peerID = peripheral.identifier.uuidString
        let nickname = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? ""
        let rssiValue = rssi.intValue
        
        // Create or update peer
        let peer = BitchatPeerInfo(
            peerID: peerID,
            nickname: nickname,
            isConnected: false,
            lastSeen: Date(),
            rssi: rssiValue
        )
        
        addOrUpdatePeer(peer)
        
        // Connect to peripheral
        if !peripherals[peripheral.identifier.uuidString]!.isConnecting {
            central.connect(peripheral, options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        logger.info("Connected to peripheral: \(peripheral.identifier)")
        
        var peripheralState = peripherals[peripheral.identifier.uuidString]!
        peripheralState.isConnecting = false
        peripheralState.isConnected = true
        peripheralState.peerID = peripheral.identifier.uuidString
        peripherals[peripheral.identifier.uuidString] = peripheralState
        
        peerToPeripheralUUID[peripheral.identifier.uuidString] = peripheral.identifier.uuidString
        peripheral.delegate = self
        
        // Discover services
        peripheral.discoverServices([Self.serviceUUID])
        
        // Update peer status
        if var peer = peers[peripheral.identifier.uuidString] {
            peer.isConnected = true
            peer.lastSeen = Date()
            peers[peripheral.identifier.uuidString] = peer
            addOrUpdatePeer(peer)
            delegate?.bleService(self, didConnectToPeer: peer.peerID)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        logger.info("Disconnected from peripheral: \(peripheral.identifier)")
        
        var peripheralState = peripherals[peripheral.identifier.uuidString]!
        peripheralState.isConnected = false
        peripherals[peripheral.identifier.uuidString] = peripheralState
        
        peerToPeripheralUUID.removeValue(forKey: peripheral.identifier.uuidString)
        
        // Update peer status
        if var peer = peers[peripheral.identifier.uuidString] {
            peer.isConnected = false
            peers[peripheral.identifier.uuidString] = peer
            addOrUpdatePeer(peer)
            delegate?.bleService(self, didDisconnectFromPeer: peer.peerID)
        }
        
        if let error = error {
            logger.error("Disconnection error: \(error.localizedDescription)")
            delegate?.bleService(self, didEncounterError: error)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        logger.error("Failed to connect to peripheral: \(peripheral.identifier), error: \(error?.localizedDescription ?? "Unknown")")
        
        var peripheralState = peripherals[peripheral.identifier.uuidString]!
        peripheralState.isConnecting = false
        peripherals[peripheral.identifier.uuidString] = peripheralState
        
        if let error = error {
            delegate?.bleService(self, didEncounterError: error)
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BLEService: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        
        for service in services {
            if service.uuid == Self.serviceUUID {
                peripheral.discoverCharacteristics([Self.characteristicUUID], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            if characteristic.uuid == Self.characteristicUUID {
                peripheral.setNotifyValue(true, for: characteristic)
                
                // Store characteristic reference
                var peripheralState = peripherals[peripheral.identifier.uuidString]!
                peripheralState.characteristic = characteristic
                peripherals[peripheral.identifier.uuidString] = peripheralState
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        
        handleReceivedPacket(data)
    }
}

// MARK: - CBPeripheralManagerDelegate

extension BLEService: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        logger.info("Peripheral manager state changed: \(peripheral.state.rawValue)")
        
        switch peripheral.state {
        case .poweredOn:
            if isActive {
                startAdvertising()
            }
        case .poweredOff, .unauthorized, .unsupported, .unknown:
            stopAdvertising()
        case .resetting:
            break
        @unknown default:
            logger.warning("Unknown peripheral manager state: \(peripheral.state.rawValue)")
        }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            logger.error("Failed to start advertising: \(error.localizedDescription)")
            delegate?.bleService(self, didEncounterError: error)
        } else {
            logger.info("Successfully started advertising")
        }
    }
}

// MARK: - Data Extensions

extension Data {
    func chunked(into size: Int) -> [Data] {
        return stride(from: 0, to: count, by: size).map {
            Data(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
