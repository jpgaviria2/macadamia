//
//  BluetoothMessage.swift
//  macadamia
//
//  Bluetooth message types and data structures
//

import Foundation

/// Types of Bluetooth messages in the mesh network
enum BluetoothMessageType: UInt8, CaseIterable {
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

/// Bluetooth message structure
struct BluetoothMessage {
    let id: String
    let type: BluetoothMessageType
    let senderID: String
    let recipientID: String?
    let content: String
    let timestamp: Date
    let ttl: UInt8
    let signature: Data?
    
    init(
        type: BluetoothMessageType,
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

/// Bluetooth packet structure for binary protocol
struct BluetoothPacket {
    let version: UInt8
    let type: UInt8
    let ttl: UInt8
    let timestamp: UInt64
    let flags: UInt8
    let payloadLength: UInt32
    let senderID: Data
    let recipientID: Data?
    let payload: Data
    let signature: Data?
    
    init(
        version: UInt8 = 1,
        type: UInt8,
        ttl: UInt8 = 7,
        timestamp: UInt64 = UInt64(Date().timeIntervalSince1970 * 1000),
        flags: UInt8 = 0,
        payloadLength: UInt32,
        senderID: Data,
        recipientID: Data? = nil,
        payload: Data,
        signature: Data? = nil
    ) {
        self.version = version
        self.type = type
        self.ttl = ttl
        self.timestamp = timestamp
        self.flags = flags
        self.payloadLength = payloadLength
        self.senderID = senderID
        self.recipientID = recipientID
        self.payload = payload
        self.signature = signature
    }
}

/// Connection status for a peer
enum BluetoothConnectionStatus {
    case disconnected
    case connecting
    case connected
    case reachable
    case failed(Error)
    
    var isConnected: Bool {
        if case .connected = self {
            return true
        }
        return false
    }
    
    var isReachable: Bool {
        switch self {
        case .connected, .reachable:
            return true
        default:
            return false
        }
    }
}

/// Bluetooth service state
enum BluetoothServiceState {
    case idle
    case starting
    case running
    case stopping
    case error(Error)
    
    var isActive: Bool {
        if case .running = self {
            return true
        }
        return false
    }
}

/// Bluetooth discovery state
enum BluetoothDiscoveryState {
    case idle
    case scanning
    case advertising
    case both
    case error(Error)
    
    var isScanning: Bool {
        switch self {
        case .scanning, .both:
            return true
        default:
            return false
        }
    }
    
    var isAdvertising: Bool {
        switch self {
        case .advertising, .both:
            return true
        default:
            return false
        }
    }
}
