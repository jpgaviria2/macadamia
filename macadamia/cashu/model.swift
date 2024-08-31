//
//  model.swift
//  macadamia-cli
//
//  Created by zeugmaster on 01.12.23.
//

/*

import Foundation
import CryptoKit

struct KeysetIDResponse: Codable {
    let keysets: [String]
}

struct Promise: Codable {
    let id: String
    let amount: Int
    let C_: String
}
struct SignatureRequestResponse: Codable {
    let promises: [Promise]
}

class Proof: Codable, Equatable, CustomStringConvertible {
    
    static func == (lhs: Proof, rhs: Proof) -> Bool {
        if lhs.C == rhs.C {
            return true
        } else {
            return false
        }
    }
    
    let id: String
    let amount: Int
    let secret: String
    let C: String
    
    var description: String {
        return "Proof: ...\(C.suffix(6)) secret: ...\(secret.suffix(8)) amount: \(amount)"
    }
    
    init(id: String, amount: Int, secret: String, C: String) {
        self.id = id
        self.amount = amount
        self.secret = secret
        self.C = C
    }
}

struct SplitRequest_JSON: Codable {
    let proofs:[Proof]
    let outputs:[Output]
}

class Mint: Codable, Identifiable, Hashable {
    
    static func == (lhs: Mint, rhs: Mint) -> Bool {
        lhs.url == rhs.url
    }
    
    func hash(into hasher: inout Hasher) {
            hasher.combine(url) // Combine all properties that contribute to the object's uniqueness
            // If needed, combine more properties:
            // hasher.combine(name)
        }
    
    let url: URL
    var activeKeyset: Keyset
    var allKeysets: [Keyset]
    var info:LegacyMintInfo
    
    init(url: URL, activeKeyset: Keyset, allKeysets: [Keyset], info: LegacyMintInfo) {
        self.url = url
        self.activeKeyset = activeKeyset
        self.allKeysets = allKeysets
        self.info = info
    }
    
    static func calculateKeysetID(keyset:Dictionary<String,String>) -> String {
        let sortedValues = keyset.sorted { (firstElement, secondElement) -> Bool in
            guard let firstKey = UInt(firstElement.key), let secondKey = UInt(secondElement.key) else {
                return false
            }
            return firstKey < secondKey
        }.map { $0.value }
        //print(sortedValues)
        
        let concat = sortedValues.joined()
        let hashData = Data(SHA256.hash(data: concat.data(using: .utf8)!))
        
        let id = String(hashData.base64EncodedString().prefix(12))
        
        return id
    }
    
    static func calculateHexKeysetID(keyset:Dictionary<String,String>) -> String {
        let sortedValues = keyset.sorted { (firstElement, secondElement) -> Bool in
            guard let firstKey = UInt(firstElement.key), let secondKey = UInt(secondElement.key) else {
                return false
            }
            return firstKey < secondKey
        }.map { $0.value }
        //print(sortedValues)
        var concatData = [UInt8]()
        for stringKey in sortedValues {
            try! concatData.append(contentsOf: stringKey.bytes)
        }
        
        let hashData = Data(SHA256.hash(data: concatData))
        let result = String(bytes: hashData).prefix(14)
        
        return "00" + result
    }
    
    ///Pings the mint for it's info to check wether it is online or not
    func checkAvailability() async -> Bool {
        do {
            // if the network doesn't throw an error we can assume the mint is online
            let _ = try await Network.mintInfo(mintURL: self.url)
            //and return true
            return true
        } catch {
            return false
        }
    }
}

struct LegacyMintInfo: Codable {
    let name: String
    let pubkey: String
    let version: String
    let contact: [[String]] //FIXME: array in array?
    let nuts: [String]
    let parameter:Dictionary<String,Bool>
}



struct MintInfoV0_16 {
    
}

class Keyset: Codable {
    let id: String
    let keys: Dictionary<String, String>
    var derivationCounter:Int
    
    init(id: String, keys: Dictionary<String, String>, derivationCounter: Int) {
        self.id = id
        self.keys = keys
        self.derivationCounter = derivationCounter
    }
}

struct QuoteRequestResponse: Codable {
    let pr: String
    let hash: String
    
    static func satAmountFromInvoice(pr:String) throws -> Int {
        guard let range = pr.range(of: "1", options: .backwards) else {
            throw WalletError.invalidInvoiceError
        }
        let endIndex = range.lowerBound
        let hrp = String(pr[..<endIndex])
        if hrp.prefix(4) == "lnbc" {
            var num = hrp.dropFirst(4)
            let multiplier = num.popLast()
            guard var n = Double(num) else {
                throw WalletError.invalidInvoiceError
            }
            switch multiplier {
            case "m": n *= 100000
            case "u": n *= 100
            case "n": n *= 0.1
            case "p": n *= 0.0001
            default: throw WalletError.invalidInvoiceError
            }
            return n >= 1 ? Int(n) : 0
        } else {
            throw WalletError.invalidInvoiceError
        }
    }
}

struct MeltRequest: Codable {
    let proofs: [Proof]
    let pr: String
}
struct MeltRequestResponse: Codable {
    let paid: Bool
    let preimage: String?
}
struct PostMintRequest: Codable {
    let outputs: [Output]
}
struct Output: Codable {
    let amount: Int
    let B_: String
}
struct Token_Container: Codable {
    let token: [Token_JSON]
    let memo: String?
}
struct Token_JSON: Codable {
    let mint: String
    var proofs: [Proof]
}
struct RestoreRequestResponse:Decodable {
    let outputs:[Output]
    let promises:[Promise]
}
struct StateCheckResponse: Codable {
    let spendable:[Bool]
    let pending:[Bool]
}

enum TransactionType:String,Codable {
    // DO NOT REMOVE CODABLE STRING EQV, otherwise db will not read from file
    case lightning = "TransactionTypeLightning"
    case cashu = "TransactionTypeCashu"
    //----
    case drain
}
class Transaction:Codable, Identifiable {
    let timeStamp:String
    let unixTimestamp:Double
    let amount:Int //positive values for incoming, negative for outgoing
    let type:TransactionType
    var pending:Bool
    
    let invoice:String?
    let token:String?
    let proofs:[Proof]?
    
    init(timeStamp: String,
         unixTimestamp:Double,
         amount: Int,
         type: TransactionType,
         pending:Bool = false,
         invoice: String? = nil,
         token: String? = nil,
         proofs: [Proof]? = nil) {
        
        self.timeStamp = timeStamp
        self.unixTimestamp = unixTimestamp
        self.amount = amount
        self.type = type
        self.pending = pending
        self.invoice = invoice
        self.token = token
        self.proofs = proofs
    }
}


extension String {
    func makeURLSafe() -> String {
        return self
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
*/
