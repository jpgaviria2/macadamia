//
//  BluetoothPeer.swift
//  macadamia
//
//  Bluetooth peer representation for mesh networking
//

import Foundation
import CoreBluetooth

/// Represents a Bluetooth peer in the mesh network
class BluetoothPeer: ObservableObject, Identifiable {
    let peerID: String
    
    // Identifiable conformance
    var id: String { peerID }
    
    var nickname: String
    var lastSeen: Date
    var isConnected: Bool
    var isReachable: Bool
    var isDirect: Bool
    var rssi: Int?
    var noisePublicKey: Data?
    var signingPublicKey: Data?
    var nostrPublicKey: String?
    var isFavorite: Bool
    var isMutualFavorite: Bool
    
    // Connection metadata
    var connectionCount: Int
    var lastConnectionAttempt: Date?
    var connectionFailures: Int
    
    init(
        peerID: String,
        nickname: String = "",
        lastSeen: Date = Date(),
        isConnected: Bool = false,
        isReachable: Bool = false,
        isDirect: Bool = false,
        rssi: Int? = nil,
        noisePublicKey: Data? = nil,
        signingPublicKey: Data? = nil,
        nostrPublicKey: String? = nil,
        isFavorite: Bool = false,
        isMutualFavorite: Bool = false,
        connectionCount: Int = 0,
        lastConnectionAttempt: Date? = nil,
        connectionFailures: Int = 0
    ) {
        self.peerID = peerID
        self.nickname = nickname
        self.lastSeen = lastSeen
        self.isConnected = isConnected
        self.isReachable = isReachable
        self.isDirect = isDirect
        self.rssi = rssi
        self.noisePublicKey = noisePublicKey
        self.signingPublicKey = signingPublicKey
        self.nostrPublicKey = nostrPublicKey
        self.isFavorite = isFavorite
        self.isMutualFavorite = isMutualFavorite
        self.connectionCount = connectionCount
        self.lastConnectionAttempt = lastConnectionAttempt
        self.connectionFailures = connectionFailures
    }
    
    /// Display name for UI (nickname or peerID prefix)
    var displayName: String {
        if !nickname.isEmpty {
            return nickname
        }
        return String(peerID.prefix(8))
    }
    
    /// Check if peer is currently available
    var isAvailable: Bool {
        return isConnected || isReachable
    }
    
    /// Update connection status
    func updateConnectionStatus(connected: Bool, reachable: Bool, direct: Bool) {
        self.isConnected = connected
        self.isReachable = reachable
        self.isDirect = direct
        self.lastSeen = Date()
        
        if connected {
            self.connectionCount += 1
            self.connectionFailures = 0
        }
    }
    
    /// Update RSSI value
    func updateRSSI(_ rssi: Int) {
        self.rssi = rssi
        self.lastSeen = Date()
    }
    
    /// Mark connection attempt
    func markConnectionAttempt() {
        self.lastConnectionAttempt = Date()
    }
    
    /// Mark connection failure
    func markConnectionFailure() {
        self.connectionFailures += 1
        self.lastConnectionAttempt = Date()
    }
    
    /// Reset connection failures
    func resetConnectionFailures() {
        self.connectionFailures = 0
    }
    
    /// Update last seen timestamp
    func updateLastSeen() {
        self.lastSeen = Date()
    }
}

// MARK: - Extensions

extension BluetoothPeer: Equatable {
    static func == (lhs: BluetoothPeer, rhs: BluetoothPeer) -> Bool {
        return lhs.peerID == rhs.peerID
    }
}

extension BluetoothPeer: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(peerID)
    }
}
