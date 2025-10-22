//
//  Alerts.swift
//  macadamia
//
//  Created by zm on 12.11.24.
//

import Foundation
import SwiftUI
import CashuSwift

struct AlertDetail {
    let title: String
    let alertDescription: String?
    let primaryButton: AlertButton?
    let secondaryButton: AlertButton?
    let tertiaryButton: AlertButton?
    
    init(title: String,
         description: String? = nil,
         primaryButton: AlertButton? = nil,
         secondaryButton: AlertButton? = nil,
         tertiaryButton: AlertButton? = nil) {
        self.title = title
        self.alertDescription = description
        self.primaryButton = primaryButton
        self.secondaryButton = secondaryButton
        self.tertiaryButton = tertiaryButton
    }
    
    init(with error: Swift.Error) {
        switch error {
        case let cashuError as CashuError:
            switch cashuError {
            case .networkError:
                self = AlertDetail(title: "Network error 📡", description: "The mint could not be reached due to a network issue. Are you both online?")
                
            case .invalidToken:
                self = AlertDetail(title: "Invalid Token", description: "The Cashu token is invalid or corrupted.")
                
            case .insufficientInputs:
                self = AlertDetail(title: "Insufficient Funds 💰", description: "The wallet was unable to collect enough ecash for this transaction.")
                
            default:
                self = AlertDetail(title: "Unhandled Error", description: String(describing: cashuError))
            }
        case let macadamiaError as macadamiaError:
            switch macadamiaError {
            case .multiMintToken:
                self = AlertDetail(title: "Multi Mint Token 📑", description: "macadamia no longer supports tokens that contain ecash from multiple mints. Please use separate tokens and the seed phrase for restoring ecash.")
            case .databaseError(let message):
                self = AlertDetail(title: "Database Error 📂", description: "The operation could not be completed due to an unexpected database inconsistency. \(message)")
            case .lockedToken:
                self = AlertDetail(title: "Locked Token 🔒", description: "macadamia can not yet redeem locked tokens. This feature is coming soon™.")
            case .unsupportedUnit:
                self = AlertDetail(title: "Unit Error 💵", description: "macadamia can only redeem tokens denominated in Satoshis. Multi unit support is coming soon™.")
            case .unknownMint(_):
                self = AlertDetail(title: "Unknown Mint 🥷", description: "You are trying to redeem from a mint that is not known to the wallet. Please add it first.")
            case .unknownKeyset(let string):
                self = AlertDetail(title: "Keyset Error", description: "Detail: \(string)")
            case .mintVerificationError(let detail):
                self = AlertDetail(title: "Mint Verification Error", description: "This mint did not pass verification before being added. Detail: \(detail ?? "None")")
            }
        default:
            self = AlertDetail(title: "Unknown Error", description: error.localizedDescription)
        }
    }
}

struct AlertViewModifier: ViewModifier {
    @Binding var isPresented: Bool
    var currentAlert: AlertDetail? // optional because SwiftUI view modifier requires it

    func body(content: Content) -> some View {
        content
            .alert(currentAlert?.title ?? "Error", isPresented: $isPresented) {
                if let primaryButton = currentAlert?.primaryButton {
                    Button(role: primaryButton.role) {
                        primaryButton.action()
                    } label: {
                        Text(primaryButton.title)
                    }
                } 
                if let secondaryButton = currentAlert?.secondaryButton {
                    Button(role: secondaryButton.role) {
                        secondaryButton.action()
                    } label: {
                        Text(secondaryButton.title)
                    }
                }
                if let tertiaryButton = currentAlert?.tertiaryButton {
                    Button(role: tertiaryButton.role) {
                        tertiaryButton.action()
                    } label: {
                        Text(tertiaryButton.title)
                    }
                }
            } message: {
                Text(currentAlert?.alertDescription ?? "")
            }
    }
}

struct AlertButton {
    var title: String
    var role: ButtonRole?
    var action: (() -> Void)
}

extension View {
    func alertView(isPresented: Binding<Bool>, currentAlert: AlertDetail?) -> some View {
        modifier(AlertViewModifier(isPresented: isPresented, currentAlert: currentAlert))
    }
}
