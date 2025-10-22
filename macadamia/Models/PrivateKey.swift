//
//  PrivateKey.swift
//  macadamia
//
//  Private key model for Nostr integration
//

import Foundation
import CryptoKit

/// Private key for Nostr integration
struct PrivateKey {
    let rawValue: Data
    let publicKey: PublicKey
    
    init(rawValue: Data) {
        self.rawValue = rawValue
        self.publicKey = PublicKey(rawValue: Data(rawValue.prefix(32)))
    }
    
    init() {
        let randomData = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        self.init(rawValue: randomData)
    }
    
    /// Sign data with this private key
    func signature(for data: Data) throws -> Data {
        // Mock implementation - in real app, this would use proper cryptographic signing
        let hash = SHA256.hash(data: data)
        return Data(hash.prefix(32))
    }
}

/// Public key for Nostr integration
struct PublicKey {
    let rawValue: Data
    
    init(rawValue: Data) {
        self.rawValue = rawValue
    }
    
    var hexString: String {
        return rawValue.map { String(format: "%02x", $0) }.joined()
    }
}
