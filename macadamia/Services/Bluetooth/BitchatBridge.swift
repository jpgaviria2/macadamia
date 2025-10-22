//
//  BitchatBridge.swift
//  macadamia
//
//  Bridge between bitchat Bluetooth mesh and macadamia UI
//  Uses original bitchat implementation for text exchange, adapted for ecash tokens
//

import Foundation
import Combine
import OSLog

/// Bridge between bitchat services and macadamia UI
class BitchatBridge: ObservableObject, BitchatDelegate {
    
    // MARK: - Properties
    
    @Published var isActive = false
    @Published var peers: [BluetoothPeer] = []
    @Published var connectedPeers: Set<String> = []
    @Published var receivedEcashTokens: [EcashToken] = []
    
    // Bitchat services
    private let bleService: BLEService
    
    // Macadamia-specific state
    private var macadamiaPeers: [String: BluetoothPeer] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    // Logging
    private let logger = Logger(subsystem: "macadamia", category: "BitchatBridge")
    
    // MARK: - Initialization
    
    init() {
        // Initialize bitchat dependencies
        let keychain = KeychainManager()
        let identityManager = SecureIdentityStateManager(keychain: keychain)
        let idBridge = NostrIdentityBridge(identityManager: identityManager)
        
        // Initialize BLEService with all dependencies
        self.bleService = BLEService(
            keychain: keychain,
            idBridge: idBridge,
            identityManager: identityManager
        )
        
        setupBitchatServices()
    }
    
    deinit {
        cancellables.removeAll()
        bleService.stopServices()
    }
    
    private func setupBitchatServices() {
        // Set ourselves as the delegate for bitchat events
        bleService.delegate = self
        
        // Subscribe to peer updates
        bleService.peerSnapshotPublisher
            .sink { [weak self] peers in
                self?.updatePeersFromBitchat(peers)
            }
            .store(in: &cancellables)
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
    
    /// Send ecash token as text message (bitchat compatible)
    func sendEcashToken(_ token: String, to peerID: String? = nil, memo: String? = nil) {
        logger.info("Sending ecash token to peer: \(peerID ?? "broadcast")")
        
        // Format the ecash token as a text message
        var message = token
        if let memo = memo, !memo.isEmpty {
            message = "\(memo)\n\(token)"
        }
        
        // Use bitchat's text messaging to send the ecash token
        if let peerID = peerID {
            let peerIDObj = PeerID(str: peerID)
            bleService.sendPublicMessage(message, to: peerIDObj)
        } else {
            bleService.sendPublicMessage(message, to: nil) // Broadcast
        }
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
    
    // MARK: - Helper Methods
    
    private func updatePeersFromBitchat(_ bitchatPeers: [TransportPeerSnapshot]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            var newPeers: [BluetoothPeer] = []
            var newConnectedPeers: Set<String> = []
            
            for peerSnapshot in bitchatPeers {
                let macadamiaPeer = BluetoothPeer(
                    peerID: peerSnapshot.peerID,
                    nickname: peerSnapshot.nickname,
                    lastSeen: peerSnapshot.lastSeen,
                    isConnected: peerSnapshot.isConnected,
                    isReachable: peerSnapshot.isConnected,
                    isDirect: peerSnapshot.isConnected,
                    rssi: nil,
                    noisePublicKey: peerSnapshot.noisePublicKey,
                    signingPublicKey: peerSnapshot.signingPublicKey,
                    nostrPublicKey: nil,
                    isFavorite: false,
                    isMutualFavorite: false
                )
                
                newPeers.append(macadamiaPeer)
                if peerSnapshot.isConnected {
                    newConnectedPeers.insert(peerSnapshot.peerID)
                }
            }
            
            self.peers = newPeers
            self.connectedPeers = newConnectedPeers
        }
    }
    
    private func convertBitchatPeer(_ peer: BitchatPeerInfo) -> BluetoothPeer {
        return BluetoothPeer(
            peerID: peer.peerID,
            nickname: peer.nickname,
            lastSeen: peer.lastSeen,
            isConnected: peer.isConnected,
            isReachable: peer.isConnected,
            isDirect: peer.isConnected,
            rssi: nil,
            noisePublicKey: peer.noisePublicKey,
            signingPublicKey: peer.signingPublicKey,
            nostrPublicKey: nil,
            isFavorite: false,
            isMutualFavorite: false
        )
    }
    
    private func processReceivedEcashToken(_ tokenString: String, from peerID: PeerID) {
        // Process the received ecash token
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Create an EcashToken object
            let ecashToken = EcashToken(
                id: UUID().uuidString,
                token: tokenString,
                senderPeerID: peerID,
                receivedAt: Date(),
                isClaimed: false
            )
            
            self.receivedEcashTokens.append(ecashToken)
            self.logger.info("Added ecash token from \(peerID) to received tokens")
        }
    }
    
    private func updatePeersList() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.peers = Array(self.macadamiaPeers.values)
        }
    }
}

// MARK: - BitchatDelegate

extension BitchatBridge {
    func didReceiveMessage(_ message: BitchatMessage) {
        logger.info("Received message from peer: \(message.senderPeerID)")
        
        // Check if this message contains an ecash token
        if message.content.hasPrefix("cashuA") || message.content.hasPrefix("cashuB") {
            logger.info("Received ecash token from peer: \(message.senderPeerID)")
            processReceivedEcashToken(message.content, from: message.senderPeerID)
        } else if message.content.contains("cashuA") || message.content.contains("cashuB") {
            // Extract ecash token from message (might have memo prefix)
            let lines = message.content.components(separatedBy: .newlines)
            for line in lines {
                if line.hasPrefix("cashuA") || line.hasPrefix("cashuB") {
                    logger.info("Extracted ecash token from message")
                    processReceivedEcashToken(line, from: message.senderPeerID)
                    break
                }
            }
        }
    }
    
    func didConnectToPeer(_ peerID: PeerID) {
        logger.info("Connected to peer: \(peerID)")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.connectedPeers.insert(peerID)
        }
    }
    
    func didDisconnectFromPeer(_ peerID: PeerID) {
        logger.info("Disconnected from peer: \(peerID)")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.connectedPeers.remove(peerID)
        }
    }
    
    func didUpdatePeerList(_ peers: [PeerID]) {
        logger.info("Updated peer list: \(peers.count) peers")
        // This will be handled by the peerSnapshotPublisher subscription
    }
    
    func didReceiveNoisePayload(from peerID: PeerID, type: NoisePayloadType, payload: Data, timestamp: Date) {
        logger.info("Received noise payload from peer: \(peerID)")
        
        // Check if this is an ecash token
        if let tokenString = String(data: payload, encoding: .utf8),
           tokenString.hasPrefix("cashuA") || tokenString.hasPrefix("cashuB") {
            logger.info("Received ecash token via noise payload from peer: \(peerID)")
            processReceivedEcashToken(tokenString, from: peerID)
        }
    }
    
    func didUpdateBluetoothState(_ state: CBManagerState) {
        logger.info("Bluetooth state updated: \(state.rawValue)")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isActive = (state == .poweredOn)
        }
    }
    
    func didReceivePublicMessage(from peerID: PeerID, nickname: String, content: String, timestamp: Date) {
        logger.info("Received public message from peer: \(peerID)")
        
        // Check if this message contains an ecash token
        if content.hasPrefix("cashuA") || content.hasPrefix("cashuB") {
            logger.info("Received ecash token from peer: \(peerID)")
            processReceivedEcashToken(content, from: peerID)
        } else if content.contains("cashuA") || content.contains("cashuB") {
            // Extract ecash token from message (might have memo prefix)
            let lines = content.components(separatedBy: .newlines)
            for line in lines {
                if line.hasPrefix("cashuA") || line.hasPrefix("cashuB") {
                    logger.info("Extracted ecash token from message")
                    processReceivedEcashToken(line, from: peerID)
                    break
                }
            }
        }
    }
    
    func didUpdateMessageDeliveryStatus(_ messageID: String, status: DeliveryStatus) {
        logger.info("Message delivery status updated: \(messageID) - \(status)")
    }
    
    func isFavorite(fingerprint: String) -> Bool {
        // Check if this fingerprint belongs to a favorite peer
        return false // Implement based on your favorites logic
    }
}

// MARK: - EcashToken Model

struct EcashToken: Identifiable {
    let id: String
    let token: String
    let senderPeerID: PeerID
    let receivedAt: Date
    var isClaimed: Bool
}
