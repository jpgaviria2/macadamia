//
//  BitchatBridge.swift
//  macadamia
//
//  Bridge between bitchat Bluetooth mesh and macadamia UI
//  Ensures full compatibility with bitchat users
//

import Foundation
import Combine
import OSLog

/// Bridge between bitchat services and macadamia UI
class BitchatBridge: ObservableObject {
    
    // MARK: - Properties
    
    @Published var isActive = false
    @Published var peers: [BluetoothPeer] = []
    @Published var connectedPeers: Set<String> = []
    @Published var receivedEcashTokens: [EcashToken] = []
    
    // Bitchat services
    private let bleService = BLEService()
    
    // Macadamia-specific state
    private var macadamiaPeers: [String: BluetoothPeer] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    // Logging
    private let logger = Logger(subsystem: "macadamia", category: "BitchatBridge")
    
    // MARK: - Initialization
    
    init() {
        setupBitchatServices()
    }
    
    deinit {
        cancellables.removeAll()
        bleService.stopServices()
    }
    
    // MARK: - Public Methods
    
    /// Start bitchat services
    func startServices() {
        logger.info("Starting bitchat bridge services")
        bleService.startServices()
        isActive = true
    }
    
    /// Stop bitchat services
    func stopServices() {
        logger.info("Stopping bitchat bridge services")
        bleService.stopServices()
        isActive = false
        peers.removeAll()
        connectedPeers.removeAll()
        macadamiaPeers.removeAll()
    }
    
    /// Set nickname for bitchat compatibility
    func setNickname(_ nickname: String) {
        logger.info("Setting bitchat nickname: \(nickname)")
        bleService.setNickname(nickname)
    }
    
    /// Send message to specific peer
    func sendMessage(to peerID: String, content: String) {
        logger.info("Sending message to peer: \(peerID)")
        bleService.sendMessage(to: peerID, content: content)
    }
    
    /// Broadcast message to all peers
    func broadcastMessage(_ content: String) {
        logger.info("Broadcasting message to all peers")
        bleService.broadcastMessage(content)
    }
    
    /// Send ecash token as text message (bitchat compatible)
    func sendEcashToken(_ token: String, to peerID: String? = nil, memo: String? = nil) {
        logger.info("Sending ecash token to peer: \(peerID ?? "broadcast")")
        bleService.sendEcashToken(token, to: peerID, memo: memo)
    }
    
    /// Get peer by ID
    func getPeer(by peerID: String) -> BluetoothPeer? {
        return macadamiaPeers[peerID]
    }
    
    /// Get all peers
    func getAllPeers() -> [BluetoothPeer] {
        return Array(macadamiaPeers.values)
    }
    
    /// Claim received ecash token
    func claimEcashToken(_ token: EcashToken) {
        logger.info("Claiming ecash token: \(token.id)")
        
        // Mark as claimed
        if let index = receivedEcashTokens.firstIndex(where: { $0.id == token.id }) {
            receivedEcashTokens[index].isClaimed = true
        }
        
        // Here you would integrate with macadamia's wallet to actually claim the token
        // This would involve calling the existing CashuSwift library to redeem the token
    }
    
    // MARK: - Private Methods
    
    private func setupBitchatServices() {
        // Set up bitchat BLE service delegate
        bleService.delegate = self
        
        // Set up initial state
        isActive = false
    }
    
    private func convertBitchatPeer(_ bitchatPeer: BitchatPeerInfo) -> BluetoothPeer {
        return BluetoothPeer(
            peerID: bitchatPeer.peerID,
            nickname: bitchatPeer.nickname,
            lastSeen: bitchatPeer.lastSeen,
            isConnected: bitchatPeer.isConnected,
            isReachable: true, // Assume reachable if we can see them
            isDirect: true,
            rssi: bitchatPeer.rssi,
            noisePublicKey: bitchatPeer.noisePublicKey,
            signingPublicKey: bitchatPeer.signingPublicKey
        )
    }
    
    private func updatePeersList() {
        peers = Array(macadamiaPeers.values)
        connectedPeers = Set(peers.filter { $0.isConnected }.map { $0.peerID })
    }
    
    private func processReceivedEcashToken(_ token: String, from peerID: String) {
        logger.info("Processing received ecash token from peer: \(peerID)")
        
        // Parse token and create EcashToken entry
        let ecashToken = EcashToken(
            id: UUID().uuidString,
            token: token,
            senderPeerID: peerID,
            receivedAt: Date(),
            isClaimed: false
        )
        
        receivedEcashTokens.append(ecashToken)
        
        // Update peer if needed
        if let peer = macadamiaPeers[peerID] {
            peer.updateLastSeen()
            macadamiaPeers[peerID] = peer
            updatePeersList()
        }
    }
}

// MARK: - BitchatBLEServiceDelegate

extension BitchatBridge: BitchatBLEServiceDelegate {
    func bleService(_ service: BLEService, didDiscoverPeer peer: BitchatPeerInfo) {
        logger.info("Bitchat discovered peer: \(peer.displayName)")
        
        let macadamiaPeer = convertBitchatPeer(peer)
        macadamiaPeers[peer.peerID] = macadamiaPeer
        updatePeersList()
    }
    
    func bleService(_ service: BLEService, didConnectToPeer peerID: PeerID) {
        logger.info("Bitchat connected to peer: \(peerID)")
        
        if let peer = macadamiaPeers[peerID] {
            peer.updateConnectionStatus(connected: true, reachable: true, direct: true)
            macadamiaPeers[peerID] = peer
            updatePeersList()
        }
    }
    
    func bleService(_ service: BLEService, didDisconnectFromPeer peerID: PeerID) {
        logger.info("Bitchat disconnected from peer: \(peerID)")
        
        if let peer = macadamiaPeers[peerID] {
            peer.updateConnectionStatus(connected: false, reachable: false, direct: false)
            macadamiaPeers[peerID] = peer
            updatePeersList()
        }
    }
    
    func bleService(_ service: BLEService, didReceiveMessage message: BitchatMessage) {
        logger.info("Bitchat received message: \(message.type.description) from \(message.senderID)")
        
        // Check if message contains ecash token
        if message.content.hasPrefix("cashuA") || message.content.hasPrefix("cashuB") {
            logger.info("Received ecash token from peer: \(message.senderID)")
            processReceivedEcashToken(message.content, from: message.senderID)
        } else {
            logger.debug("Received regular message from peer: \(message.senderID)")
            // Handle regular message if needed
        }
    }
    
    func bleService(_ service: BLEService, didUpdatePeer peer: BitchatPeerInfo) {
        logger.debug("Bitchat updated peer: \(peer.displayName)")
        
        let macadamiaPeer = convertBitchatPeer(peer)
        macadamiaPeers[peer.peerID] = macadamiaPeer
        updatePeersList()
    }
    
    func bleService(_ service: BLEService, didEncounterError error: Error) {
        logger.error("Bitchat service error: \(error.localizedDescription)")
        // Handle error appropriately
    }
}

// MARK: - Ecash Token Model

/// Ecash token received via Bluetooth
struct EcashToken: Identifiable, Codable {
    let id: String
    let token: String
    let senderPeerID: String
    let receivedAt: Date
    var isClaimed: Bool
    
    init(id: String = UUID().uuidString, token: String, senderPeerID: String, receivedAt: Date = Date(), isClaimed: Bool = false) {
        self.id = id
        self.token = token
        self.senderPeerID = senderPeerID
        self.receivedAt = receivedAt
        self.isClaimed = isClaimed
    }
}
