//
//  BluetoothConnection.swift
//  macadamia
//
//  Bluetooth connection management and state tracking
//

import Foundation
import CoreBluetooth

enum BluetoothConnectionState: String, Codable {
    case connecting
    case connected
    case disconnecting
    case disconnected
    case failed
}

struct BluetoothConnection: Identifiable, Equatable, Hashable {
    let id: String // Peripheral UUID string
    let peripheral: CBPeripheral // The connected peripheral
    var state: BluetoothConnectionState
    var lastActivity: Date // Timestamp of last data exchange

    init(peripheral: CBPeripheral, state: BluetoothConnectionState, lastActivity: Date = Date()) {
        self.id = peripheral.identifier.uuidString
        self.peripheral = peripheral
        self.state = state
        self.lastActivity = lastActivity
    }

    // Equatable conformance
    static func == (lhs: BluetoothConnection, rhs: BluetoothConnection) -> Bool {
        lhs.id == rhs.id
    }

    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}