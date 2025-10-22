//
//  EcashBluetoothService.swift
//  macadamia
//
//  Service for handling ecash transactions over Bluetooth mesh
//

import Foundation
import CashuSwift
import Combine

// Message types for ecash communication
enum EcashMessageType: String, CaseIterable {
    case ecashOffer = "ecash_offer"
    case ecashAccept = "ecash_accept"
    case ecashReject = "ecash_reject"
    case ecashToken = "ecash_token"
    case ecashConfirmation = "ecash_confirmation"
    case ecashRequest = "ecash_request"
}

/// Service for managing ecash transactions over Bluetooth mesh network
@MainActor
class EcashBluetoothService: ObservableObject {
    @Published var transactions: [EcashTransaction] = []
    @Published var isScanning: Bool = false
    @Published var isAdvertising: Bool = false
    @Published var connectedPeers: [BluetoothPeer] = []
    
    private let bluetoothBridge: BitchatBridge
    private let cashuService: CashuService
    private var cancellables = Set<AnyCancellable>()
    
    init(bluetoothBridge: BitchatBridge, cashuService: CashuService) {
        self.bluetoothBridge = bluetoothBridge
        self.cashuService = cashuService
        
        setupBluetoothObservers()
    }
    
    // MARK: - Public Methods
    
    /// Send ecash to a specific peer
    func sendEcash(to peer: BluetoothPeer, amount: UInt64, currency: String = "USD", memo: String? = nil) async throws {
        guard let token = try await createCashuToken(amount: amount, currency: currency) else {
            throw EcashError.tokenCreationFailed
        }
        
        let transaction = EcashTransaction(
            senderID: "local_peer", // Mock sender ID
            recipientID: peer.peerID,
            amount: amount,
            currency: currency,
            token: token,
            memo: memo,
            isIncoming: false,
            bluetoothPeerID: peer.peerID,
            meshHops: 0
        )
        
        // Add to local transactions
        transactions.append(transaction)
        
        // Send ecash offer
        try await sendEcashOffer(to: peer, transaction: transaction)
    }
    
    /// Request ecash from a specific peer
    func requestEcash(from peer: BluetoothPeer, amount: UInt64, currency: String = "USD", memo: String? = nil) async throws {
        let requestData = EcashRequestData(
            amount: amount,
            currency: currency,
            memo: memo,
            requestID: UUID().uuidString
        )
        
        let message = EcashMessage(
            type: EcashMessageType.ecashRequest,
            data: try JSONEncoder().encode(requestData)
        )
        
        try await bluetoothBridge.sendMessage(to: peer.peerID, content: try JSONEncoder().encode(message).base64EncodedString())
    }
    
    /// Start scanning for ecash transactions
    func startScanning() {
        isScanning = true
        bluetoothBridge.startServices()
    }
    
    /// Stop scanning
    func stopScanning() {
        isScanning = false
        // No stop method in BitchatBridge
    }
    
    /// Start advertising ecash availability
    func startAdvertising() {
        isAdvertising = true
        bluetoothBridge.startServices()
    }
    
    /// Stop advertising
    func stopAdvertising() {
        isAdvertising = false
        // No stop method in BitchatBridge
    }
    
    // MARK: - Private Methods
    
    private func setupBluetoothObservers() {
        // Observe connected peers
        bluetoothBridge.$peers
            .sink { [weak self] peers in
                Task { @MainActor in
                    self?.connectedPeers = Array(peers)
                }
            }
            .store(in: &cancellables)
        
        // Observe incoming messages - mock implementation
        // In real app, this would observe actual message events
    }
    
    private func handleIncomingMessage(_ message: BluetoothMessage) async {
        guard let data = Data(base64Encoded: message.content),
              let ecashMessage = try? JSONDecoder().decode(EcashMessage.self, from: data) else {
            return
        }
        
        switch ecashMessage.type {
        case EcashMessageType.ecashOffer.rawValue:
            await handleEcashOffer(message, ecashMessage)
        case EcashMessageType.ecashAccept.rawValue:
            await handleEcashAccept(message, ecashMessage)
        case EcashMessageType.ecashReject.rawValue:
            await handleEcashReject(message, ecashMessage)
        case EcashMessageType.ecashToken.rawValue:
            await handleEcashToken(message, ecashMessage)
        case EcashMessageType.ecashConfirmation.rawValue:
            await handleEcashConfirmation(message, ecashMessage)
        case EcashMessageType.ecashRequest.rawValue:
            await handleEcashRequest(message, ecashMessage)
        default:
            break
        }
    }
    
    private func handleEcashOffer(_ message: BluetoothMessage, _ ecashMessage: EcashMessage) async {
        guard let offerData = try? JSONDecoder().decode(EcashOfferData.self, from: ecashMessage.data) else {
            return
        }
        
        // Show notification to user about incoming ecash offer
        // This would typically show a UI alert or notification
        print("Received ecash offer: \(offerData.amount) \(offerData.currency) from \(message.senderID)")
    }
    
    private func handleEcashAccept(_ message: BluetoothMessage, _ ecashMessage: EcashMessage) async {
        guard let acceptData = try? JSONDecoder().decode(EcashAcceptData.self, from: ecashMessage.data) else {
            return
        }
        
        // Update transaction status
        if let transactionIndex = transactions.firstIndex(where: { $0.id == acceptData.transactionID }) {
            transactions[transactionIndex].updateStatus(.confirmed)
        }
    }
    
    private func handleEcashReject(_ message: BluetoothMessage, _ ecashMessage: EcashMessage) async {
        guard let rejectData = try? JSONDecoder().decode(EcashRejectData.self, from: ecashMessage.data) else {
            return
        }
        
        // Update transaction status
        if let transactionIndex = transactions.firstIndex(where: { $0.id == rejectData.transactionID }) {
            transactions[transactionIndex].updateStatus(.failed)
        }
    }
    
    private func handleEcashToken(_ message: BluetoothMessage, _ ecashMessage: EcashMessage) async {
        guard let tokenData = try? JSONDecoder().decode(EcashTokenData.self, from: ecashMessage.data) else {
            return
        }
        
        // Process received token
        do {
            let transaction = EcashTransaction(
                senderID: message.senderID,
                amount: tokenData.amount,
                currency: tokenData.currency,
                token: tokenData.token,
                memo: tokenData.memo,
                isIncoming: true,
                bluetoothPeerID: message.senderID,
                meshHops: 0 // Mock hop count
            )
            
            transactions.append(transaction)
            
            // Verify and redeem token
            try await verifyAndRedeemToken(transaction)
            
        } catch {
            print("Failed to process ecash token: \(error)")
        }
    }
    
    private func handleEcashConfirmation(_ message: BluetoothMessage, _ ecashMessage: EcashMessage) async {
        guard let confirmationData = try? JSONDecoder().decode(EcashConfirmationData.self, from: ecashMessage.data) else {
            return
        }
        
        // Update transaction status
        if let transactionIndex = transactions.firstIndex(where: { $0.id == confirmationData.transactionID }) {
            transactions[transactionIndex].updateStatus(.confirmed)
        }
    }
    
    private func handleEcashRequest(_ message: BluetoothMessage, _ ecashMessage: EcashMessage) async {
        guard let requestData = try? JSONDecoder().decode(EcashRequestData.self, from: ecashMessage.data) else {
            return
        }
        
        // Show notification to user about ecash request
        print("Received ecash request: \(requestData.amount) \(requestData.currency) from \(message.senderID)")
    }
    
    private func sendEcashOffer(to peer: BluetoothPeer, transaction: EcashTransaction) async throws {
        let offerData = EcashOfferData(
            transactionID: transaction.id,
            amount: transaction.amount,
            currency: transaction.currency,
            memo: transaction.memo
        )
        
        let message = EcashMessage(
            type: EcashMessageType.ecashOffer,
            data: try JSONEncoder().encode(offerData)
        )
        
        try await bluetoothBridge.sendMessage(to: peer.peerID, content: try JSONEncoder().encode(message).base64EncodedString())
    }
    
    private func createCashuToken(amount: UInt64, currency: String) async throws -> String? {
        // This would integrate with the existing CashuSwift service
        // For now, return a placeholder token
        return "cashu_\(amount)_\(currency)_\(UUID().uuidString)"
    }
    
    private func verifyAndRedeemToken(_ transaction: EcashTransaction) async throws {
        // Verify the Cashu token
        // This would integrate with CashuSwift verification
        // For now, just mark as confirmed
        transaction.updateStatus(.confirmed)
    }
}

// MARK: - Supporting Data Structures

struct EcashMessage: Codable {
    let type: String
    let data: Data
    let timestamp: Date
    
    init(type: EcashMessageType, data: Data, timestamp: Date = Date()) {
        self.type = type.rawValue
        self.data = data
        self.timestamp = timestamp
    }
}

struct EcashOfferData: Codable {
    let transactionID: String
    let amount: UInt64
    let currency: String
    let memo: String?
}

struct EcashAcceptData: Codable {
    let transactionID: String
    let accepted: Bool
}

struct EcashRejectData: Codable {
    let transactionID: String
    let reason: String?
}

struct EcashTokenData: Codable {
    let transactionID: String
    let amount: UInt64
    let currency: String
    let token: String
    let memo: String?
}

struct EcashConfirmationData: Codable {
    let transactionID: String
    let confirmed: Bool
}

struct EcashRequestData: Codable {
    let amount: UInt64
    let currency: String
    let memo: String?
    let requestID: String
}

// MARK: - Errors

enum EcashError: Error, LocalizedError {
    case tokenCreationFailed
    case tokenVerificationFailed
    case peerNotConnected
    case invalidAmount
    case insufficientFunds
    
    var errorDescription: String? {
        switch self {
        case .tokenCreationFailed:
            return "Failed to create Cashu token"
        case .tokenVerificationFailed:
            return "Failed to verify Cashu token"
        case .peerNotConnected:
            return "Peer is not connected"
        case .invalidAmount:
            return "Invalid amount specified"
        case .insufficientFunds:
            return "Insufficient funds"
        }
    }
}
