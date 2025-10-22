//
//  EcashTransaction.swift
//  macadamia
//
//  Ecash transaction model for Bluetooth mesh communication
//

import Foundation
import CashuSwift

/// Represents an ecash transaction sent over Bluetooth mesh
class EcashTransaction: ObservableObject, Identifiable, Codable, Hashable {
    let id: String
    let timestamp: Date
    let senderID: String
    let recipientID: String?
    let amount: UInt64 // Amount in satoshis
    let currency: String
    let token: String // Cashu token
    let memo: String?
    var status: TransactionStatus
    let isIncoming: Bool
    
    // Bluetooth-specific fields
    let bluetoothPeerID: String?
    let meshHops: Int
    let rssi: Int?
    
    // Nostr integration fields
    let nostrEventID: String?
    let nostrRelayURL: String?
    
    init(
        id: String = UUID().uuidString,
        timestamp: Date = Date(),
        senderID: String,
        recipientID: String? = nil,
        amount: UInt64,
        currency: String = "USD",
        token: String,
        memo: String? = nil,
        status: TransactionStatus = .pending,
        isIncoming: Bool,
        bluetoothPeerID: String? = nil,
        meshHops: Int = 0,
        rssi: Int? = nil,
        nostrEventID: String? = nil,
        nostrRelayURL: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.senderID = senderID
        self.recipientID = recipientID
        self.amount = amount
        self.currency = currency
        self.token = token
        self.memo = memo
        self.status = status
        self.isIncoming = isIncoming
        self.bluetoothPeerID = bluetoothPeerID
        self.meshHops = meshHops
        self.rssi = rssi
        self.nostrEventID = nostrEventID
        self.nostrRelayURL = nostrRelayURL
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let id = try container.decode(String.self, forKey: .id)
        let timestamp = try container.decode(Date.self, forKey: .timestamp)
        let senderID = try container.decode(String.self, forKey: .senderID)
        let recipientID = try container.decodeIfPresent(String.self, forKey: .recipientID)
        let amount = try container.decode(UInt64.self, forKey: .amount)
        let currency = try container.decode(String.self, forKey: .currency)
        let token = try container.decode(String.self, forKey: .token)
        let memo = try container.decodeIfPresent(String.self, forKey: .memo)
        let status = try container.decode(TransactionStatus.self, forKey: .status)
        let isIncoming = try container.decode(Bool.self, forKey: .isIncoming)
        let bluetoothPeerID = try container.decodeIfPresent(String.self, forKey: .bluetoothPeerID)
        let meshHops = try container.decode(Int.self, forKey: .meshHops)
        let rssi = try container.decodeIfPresent(Int.self, forKey: .rssi)
        let nostrEventID = try container.decodeIfPresent(String.self, forKey: .nostrEventID)
        let nostrRelayURL = try container.decodeIfPresent(String.self, forKey: .nostrRelayURL)
        
        self.id = id
        self.timestamp = timestamp
        self.senderID = senderID
        self.recipientID = recipientID
        self.amount = amount
        self.currency = currency
        self.token = token
        self.memo = memo
        self.status = status
        self.isIncoming = isIncoming
        self.bluetoothPeerID = bluetoothPeerID
        self.meshHops = meshHops
        self.rssi = rssi
        self.nostrEventID = nostrEventID
        self.nostrRelayURL = nostrRelayURL
    }
    
    /// Update transaction status
    func updateStatus(_ newStatus: TransactionStatus) {
        self.status = newStatus
    }
    
    /// Get display amount with currency
    var displayAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        
        let amountInCurrency = Double(amount) / 100.0 // Convert satoshis to currency
        let formattedAmount = formatter.string(from: NSNumber(value: amountInCurrency)) ?? "0"
        return "\(formattedAmount) \(currency)"
    }
    
    /// Get transaction summary for UI
    var summary: String {
        let direction = isIncoming ? "Received" : "Sent"
        let peer = bluetoothPeerID?.prefix(8) ?? "Unknown"
        return "\(direction) \(displayAmount) via \(peer)"
    }
    
    // MARK: - Hashable conformance
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: EcashTransaction, rhs: EcashTransaction) -> Bool {
        return lhs.id == rhs.id
    }
}

enum TransactionStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case confirmed = "confirmed"
    case failed = "failed"
    case expired = "expired"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .confirmed: return "Confirmed"
        case .failed: return "Failed"
        case .expired: return "Expired"
        }
    }
    
    var color: String {
        switch self {
        case .pending: return "orange"
        case .confirmed: return "green"
        case .failed: return "red"
        case .expired: return "gray"
        }
    }
}

// MARK: - Codable Implementation

extension EcashTransaction {
    enum CodingKeys: String, CodingKey {
        case id, timestamp, senderID, recipientID, amount, currency, token, memo, status
        case isIncoming, bluetoothPeerID, meshHops, rssi, nostrEventID, nostrRelayURL
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(senderID, forKey: .senderID)
        try container.encodeIfPresent(recipientID, forKey: .recipientID)
        try container.encode(amount, forKey: .amount)
        try container.encode(currency, forKey: .currency)
        try container.encode(token, forKey: .token)
        try container.encodeIfPresent(memo, forKey: .memo)
        try container.encode(status, forKey: .status)
        try container.encode(isIncoming, forKey: .isIncoming)
        try container.encodeIfPresent(bluetoothPeerID, forKey: .bluetoothPeerID)
        try container.encode(meshHops, forKey: .meshHops)
        try container.encodeIfPresent(rssi, forKey: .rssi)
        try container.encodeIfPresent(nostrEventID, forKey: .nostrEventID)
        try container.encodeIfPresent(nostrRelayURL, forKey: .nostrRelayURL)
    }
}
