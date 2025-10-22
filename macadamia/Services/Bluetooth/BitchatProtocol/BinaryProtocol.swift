//
//  BinaryProtocol.swift
//  macadamia
//
//  Bitchat binary protocol for Bluetooth mesh networking
//  Copied from bitchat for full compatibility
//

import Foundation
import Compression

extension Data {
    func trimmingNullBytes() -> Data {
        // Find the first null byte
        if let nullIndex = self.firstIndex(of: 0) {
            return self.prefix(nullIndex)
        }
        return self
    }
}

/// Implements binary encoding and decoding for Bitchat protocol messages.
/// Provides static methods for converting between BitchatPacket objects and
/// their binary wire format representation.
/// - Note: All multi-byte values use network byte order (big-endian)
struct BinaryProtocol {
    static let v1HeaderSize = 14
    static let v2HeaderSize = 16
    static let senderIDSize = 8
    static let recipientIDSize = 8
    static let signatureSize = 64

    // Field offsets within packet header
    struct Offsets {
        static let version = 0
        static let type = 1
        static let ttl = 2
        static let timestamp = 3
        static let flags = 11  // After version(1) + type(1) + ttl(1) + timestamp(8)
    }

    static func headerSize(for version: UInt8) -> Int? {
        switch version {
        case 1: return v1HeaderSize
        case 2: return v2HeaderSize
        default: return nil
        }
    }

    private static func lengthFieldSize(for version: UInt8) -> Int {
        return version == 2 ? 4 : 2
    }
    
    struct Flags {
        static let hasRecipient: UInt8 = 0x01
        static let hasSignature: UInt8 = 0x02
        static let isCompressed: UInt8 = 0x04
    }
    
    // Encode BitchatPacket to binary format
    static func encode(_ packet: BitchatPacket, padding: Bool = true) -> Data? {
        let version = packet.version
        guard version == 1 || version == 2 else { return nil }

        // Try to compress payload when beneficial, keeping original size for later decoding
        var payload = packet.payload
        var isCompressed = false
        var originalPayloadSize: Int?
        if shouldCompress(payload) {
            // Only compress when we can represent the original length in the outbound frame
            let maxRepresentable = version == 2 ? Int(UInt32.max) : Int(UInt16.max)
            if payload.count <= maxRepresentable,
               let compressedPayload = compress(payload) {
                originalPayloadSize = payload.count
                payload = compressedPayload
                isCompressed = true
            }
        }

        let lengthFieldBytes = lengthFieldSize(for: version)
        let originalSizeFieldBytes = isCompressed ? lengthFieldBytes : 0
        let payloadDataSize = payload.count + originalSizeFieldBytes

        if version == 1 && payloadDataSize > Int(UInt16.max) { return nil }
        if version == 2 && payloadDataSize > Int(UInt32.max) { return nil }

        guard let headerSize = headerSize(for: version) else { return nil }
        let estimatedHeader = headerSize + senderIDSize + (packet.recipientID == nil ? 0 : recipientIDSize)
        let estimatedPayload = payloadDataSize
        let estimatedSignature = (packet.signature == nil ? 0 : signatureSize)
        var data = Data()
        data.reserveCapacity(estimatedHeader + estimatedPayload + estimatedSignature + 255)

        data.append(version)
        data.append(packet.type)
        data.append(packet.ttl)

        for shift in stride(from: 56, through: 0, by: -8) {
            data.append(UInt8((packet.timestamp >> UInt64(shift)) & 0xFF))
        }

        var flags: UInt8 = 0
        if packet.recipientID != nil { flags |= Flags.hasRecipient }
        if packet.signature != nil { flags |= Flags.hasSignature }
        if isCompressed { flags |= Flags.isCompressed }
        data.append(flags)

        if version == 2 {
            let length = UInt32(payloadDataSize)
            for shift in stride(from: 24, through: 0, by: -8) {
                data.append(UInt8((length >> UInt32(shift)) & 0xFF))
            }
        } else {
            let length = UInt16(payloadDataSize)
            data.append(UInt8((length >> 8) & 0xFF))
            data.append(UInt8(length & 0xFF))
        }

        let senderBytes = packet.senderID.prefix(senderIDSize)
        data.append(senderBytes)
        if senderBytes.count < senderIDSize {
            data.append(Data(repeating: 0, count: senderIDSize - senderBytes.count))
        }

        if let recipientID = packet.recipientID {
            let recipientBytes = recipientID.prefix(recipientIDSize)
            data.append(recipientBytes)
            if recipientBytes.count < recipientIDSize {
                data.append(Data(repeating: 0, count: recipientIDSize - recipientBytes.count))
            }
        }

        if isCompressed, let originalSize = originalPayloadSize {
            if version == 2 {
                let value = UInt32(originalSize)
                for shift in stride(from: 24, through: 0, by: -8) {
                    data.append(UInt8((value >> UInt32(shift)) & 0xFF))
                }
            } else {
                let value = UInt16(originalSize)
                data.append(UInt8((value >> 8) & 0xFF))
                data.append(UInt8(value & 0xFF))
            }
        }
        data.append(payload)

        if let signature = packet.signature {
            data.append(signature.prefix(signatureSize))
        }

        if padding {
            let optimalSize = MessagePadding.optimalBlockSize(for: data.count)
            return MessagePadding.pad(data, toSize: optimalSize)
        }
        return data
    }
    
    // Decode binary data to BitchatPacket
    static func decode(_ data: Data) -> BitchatPacket? {
        // Try decode as-is first (robust when padding wasn't applied)
        if let pkt = decodeCore(data) { return pkt }
        // If that fails, try after removing padding
        let unpadded = MessagePadding.unpad(data)
        if unpadded as NSData === data as NSData { return nil }
        return decodeCore(unpadded)
    }

    // Core decoding implementation used by decode(_:) with and without padding removal
    private static func decodeCore(_ raw: Data) -> BitchatPacket? {
        guard raw.count >= v1HeaderSize + senderIDSize else { return nil }

        return raw.withUnsafeBytes { (buf: UnsafeRawBufferPointer) -> BitchatPacket? in
            guard let base = buf.baseAddress else { return nil }
            var offset = 0
            func require(_ n: Int) -> Bool { offset + n <= buf.count }
            func read8() -> UInt8? {
                guard require(1) else { return nil }
                let value = base.advanced(by: offset).assumingMemoryBound(to: UInt8.self).pointee
                offset += 1
                return value
            }
            func read16() -> UInt16? {
                guard require(2) else { return nil }
                let ptr = base.advanced(by: offset).assumingMemoryBound(to: UInt8.self)
                let value = (UInt16(ptr[0]) << 8) | UInt16(ptr[1])
                offset += 2
                return value
            }
            func read32() -> UInt32? {
                guard require(4) else { return nil }
                let ptr = base.advanced(by: offset).assumingMemoryBound(to: UInt8.self)
                let value = (UInt32(ptr[0]) << 24) | (UInt32(ptr[1]) << 16) | (UInt32(ptr[2]) << 8) | UInt32(ptr[3])
                offset += 4
                return value
            }
            func readData(_ n: Int) -> Data? {
                guard require(n) else { return nil }
                let ptr = base.advanced(by: offset)
                let data = Data(bytes: ptr, count: n)
                offset += n
                return data
            }

            guard let version = read8(), version == 1 || version == 2 else { return nil }
            let lengthFieldBytes = lengthFieldSize(for: version)
            guard let headerSize = headerSize(for: version) else { return nil }
            let minimumRequired = headerSize + senderIDSize
            guard raw.count >= minimumRequired else { return nil }

            guard let type = read8(), let ttl = read8() else { return nil }

            var timestamp: UInt64 = 0
            for _ in 0..<8 {
                guard let byte = read8() else { return nil }
                timestamp = (timestamp << 8) | UInt64(byte)
            }

            guard let flags = read8() else { return nil }
            let hasRecipient = (flags & Flags.hasRecipient) != 0
            let hasSignature = (flags & Flags.hasSignature) != 0
            let isCompressed = (flags & Flags.isCompressed) != 0

            let payloadLength: Int
            if version == 2 {
                guard let len = read32() else { return nil }
                payloadLength = Int(len)
            } else {
                guard let len = read16() else { return nil }
                payloadLength = Int(len)
            }

            guard payloadLength >= 0 else { return nil }

            guard let senderID = readData(senderIDSize) else { return nil }

            var recipientID: Data? = nil
            if hasRecipient {
                recipientID = readData(recipientIDSize)
                if recipientID == nil { return nil }
            }

            let payload: Data
            if isCompressed {
                guard payloadLength >= lengthFieldBytes else { return nil }
                let originalSize: Int
                if version == 2 {
                    guard let rawSize = read32() else { return nil }
                    originalSize = Int(rawSize)
                } else {
                    guard let rawSize = read16() else { return nil }
                    originalSize = Int(rawSize)
                }
                // Guard to keep decompression bounded to sane BLE payload limits
                guard originalSize >= 0 && originalSize <= 1_000_000 else { return nil } // 1MB limit
                let compressedSize = payloadLength - lengthFieldBytes
                guard compressedSize >= 0, let compressed = readData(compressedSize) else { return nil }

                // Validate compression ratio to prevent zip bomb attacks
                guard compressedSize > 0 else { return nil }
                let compressionRatio = Double(originalSize) / Double(compressedSize)
                guard compressionRatio <= 50_000.0 else {
                    print("🚫 Suspicious compression ratio: \(String(format: "%.0f", compressionRatio)):1")
                    return nil
                }

                guard let decompressed = decompress(compressed, originalSize: originalSize),
                      decompressed.count == originalSize else { return nil }
                payload = decompressed
            } else {
                guard let rawPayload = readData(payloadLength) else { return nil }
                payload = rawPayload
            }

            var signature: Data? = nil
            if hasSignature {
                signature = readData(signatureSize)
                if signature == nil { return nil }
            }

            guard offset <= buf.count else { return nil }

            return BitchatPacket(
                version: version,
                type: type,
                ttl: ttl,
                timestamp: timestamp,
                senderID: senderID,
                recipientID: recipientID,
                payload: payload,
                signature: signature
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private static func shouldCompress(_ data: Data) -> Bool {
        return data.count > 256
    }
    
    private static func compress(_ data: Data) -> Data? {
        return data.compressed(using: .zlib)
    }
    
    private static func decompress(_ data: Data, originalSize: Int) -> Data? {
        return data.decompressed(using: .zlib, originalSize: originalSize)
    }
}

// MARK: - Data Extensions

extension Data {
    func compressed(using algorithm: NSData.CompressionAlgorithm) -> Data? {
        return self.withUnsafeBytes { bytes in
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: self.count)
            defer { buffer.deallocate() }
            
            let compressedLength = compression_encode_buffer(
                buffer, self.count,
                bytes.bindMemory(to: UInt8.self).baseAddress!, self.count,
                nil, compression_algorithm(UInt32(algorithm.rawValue))
            )
            
            guard compressedLength > 0 else { return nil }
            return Data(bytes: buffer, count: compressedLength)
        }
    }
    
    func decompressed(using algorithm: NSData.CompressionAlgorithm, originalSize: Int) -> Data? {
        return self.withUnsafeBytes { bytes in
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: originalSize)
            defer { buffer.deallocate() }
            
            let decompressedLength = compression_decode_buffer(
                buffer, originalSize,
                bytes.bindMemory(to: UInt8.self).baseAddress!, self.count,
                nil, compression_algorithm(UInt32(algorithm.rawValue))
            )
            
            guard decompressedLength > 0 else { return nil }
            return Data(bytes: buffer, count: decompressedLength)
        }
    }
}

// MARK: - Message Padding

struct MessagePadding {
    static func optimalBlockSize(for dataSize: Int) -> Int {
        // Round up to nearest 16-byte boundary for BLE efficiency
        return ((dataSize + 15) / 16) * 16
    }
    
    static func pad(_ data: Data, toSize size: Int) -> Data {
        guard data.count < size else { return data }
        let paddingSize = size - data.count
        var padded = data
        padded.append(Data(repeating: 0, count: paddingSize))
        return padded
    }
    
    static func unpad(_ data: Data) -> Data {
        return data.trimmingNullBytes()
    }
}
