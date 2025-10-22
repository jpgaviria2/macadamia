//
//  BitchatPacket.swift
//  macadamia
//
//  Bitchat packet structure for Bluetooth mesh networking
//  Copied from bitchat for full compatibility
//

import Foundation

/// Bitchat packet structure for Bluetooth mesh networking
struct BitchatPacket {
    let version: UInt8
    let type: UInt8
    let ttl: UInt8
    let timestamp: UInt64
    let senderID: Data
    let recipientID: Data?
    let payload: Data
    let signature: Data?
    
    init(
        version: UInt8 = 1,
        type: UInt8,
        ttl: UInt8 = 7,
        timestamp: UInt64 = UInt64(Date().timeIntervalSince1970 * 1000),
        senderID: Data,
        recipientID: Data? = nil,
        payload: Data,
        signature: Data? = nil
    ) {
        self.version = version
        self.type = type
        self.ttl = ttl
        self.timestamp = timestamp
        self.senderID = senderID
        self.recipientID = recipientID
        self.payload = payload
        self.signature = signature
    }
}

/// Bitchat message types
enum BitchatMessageType: UInt8, CaseIterable {
    case announce = 1
    case message = 2
    case sync = 3
    case requestSync = 33
    case ecash = 225  // 0xE1 - Custom type for ecash tokens
    
    var description: String {
        switch self {
        case .announce:
            return "Announce"
        case .message:
            return "Message"
        case .sync:
            return "Sync"
        case .requestSync:
            return "Request Sync"
        case .ecash:
            return "Ecash"
        }
    }
}

/// Bitchat message structure
struct BitchatMessage {
    let id: String
    let type: BitchatMessageType
    let senderID: String
    let recipientID: String?
    let content: String
    let timestamp: Date
    let ttl: UInt8
    let signature: Data?
    
    init(
        type: BitchatMessageType,
        senderID: String,
        recipientID: String? = nil,
        content: String,
        ttl: UInt8 = 7,
        signature: Data? = nil
    ) {
        self.id = UUID().uuidString
        self.type = type
        self.senderID = senderID
        self.recipientID = recipientID
        self.content = content
        self.timestamp = Date()
        self.ttl = ttl
        self.signature = signature
    }
}

/// Peer ID type for bitchat compatibility
typealias PeerID = String

/// Bitchat peer information
struct BitchatPeerInfo {
    let peerID: PeerID
    var nickname: String
    var isConnected: Bool
    var noisePublicKey: Data?
    var signingPublicKey: Data?
    var isVerifiedNickname: Bool
    var lastSeen: Date
    var rssi: Int?
    
    init(
        peerID: PeerID,
        nickname: String = "",
        isConnected: Bool = false,
        noisePublicKey: Data? = nil,
        signingPublicKey: Data? = nil,
        isVerifiedNickname: Bool = false,
        lastSeen: Date = Date(),
        rssi: Int? = nil
    ) {
        self.peerID = peerID
        self.nickname = nickname
        self.isConnected = isConnected
        self.noisePublicKey = noisePublicKey
        self.signingPublicKey = signingPublicKey
        self.isVerifiedNickname = isVerifiedNickname
        self.lastSeen = lastSeen
        self.rssi = rssi
    }
    
    var displayName: String {
        if !nickname.isEmpty {
            return nickname
        }
        return String(peerID.prefix(8))
    }
}
