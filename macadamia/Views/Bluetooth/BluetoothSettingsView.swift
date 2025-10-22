//
//  BluetoothSettingsView.swift
//  macadamia
//
//  Bluetooth settings and configuration
//

import SwiftUI

struct BluetoothSettingsView: View {
    @ObservedObject var bitchatBridge: BitchatBridge
    @State private var nickname: String = "Macadamia User"
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Bluetooth Mesh") {
                    Toggle("Enable Bluetooth Mesh", isOn: Binding(
                        get: { bitchatBridge.isActive },
                        set: { isOn in
                            if isOn {
                                bitchatBridge.startServices()
                            } else {
                                bitchatBridge.stopServices()
                            }
                        }
                    ))
                    
                    HStack {
                        Text("Nickname")
                        Spacer()
                        TextField("Enter nickname", text: $nickname)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 150)
                    }
                    .onChange(of: nickname) { newValue in
                        bitchatBridge.setNickname(newValue)
                    }
                }
                
                Section("Nearby Devices") {
                    if bitchatBridge.peers.isEmpty {
                        Text("No nearby devices found")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(bitchatBridge.peers, id: \.peerID) { peer in
                            PeerRowView(peer: peer)
                        }
                    }
                }
                
                Section("Received Ecash Tokens") {
                    if bitchatBridge.receivedEcashTokens.isEmpty {
                        Text("No received tokens")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(bitchatBridge.receivedEcashTokens) { token in
                            EcashTokenRowView(token: token) {
                                bitchatBridge.claimEcashToken(token)
                            }
                        }
                    }
                }
                
                Section("Compatibility") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bitchat Compatible")
                            .font(.headline)
                        
                        Text("This app uses the same Bluetooth mesh protocol as bitchat, enabling you to send and receive ecash tokens with bitchat users.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• Send ecash tokens to nearby devices")
                        Text("• Receive tokens from bitchat users")
                        Text("• Works offline without internet")
                        Text("• Compatible with any Cashu wallet")
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Bluetooth Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            nickname = "Macadamia User" // Get from user defaults
        }
    }
}

struct PeerRowView: View {
    let peer: BluetoothPeer
    
    var body: some View {
        HStack {
            Image(systemName: peer.isConnected ? "bluetooth.connected" : "bluetooth")
                .foregroundColor(peer.isConnected ? .green : .blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(peer.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(peer.isConnected ? "Connected" : "Available")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let rssi = peer.rssi {
                Text("\(rssi) dBm")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct EcashTokenRowView: View {
    let token: EcashToken
    let onClaim: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "bitcoinsign.circle")
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Ecash Token")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("From: \(String(token.senderPeerID.prefix(8)))...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Received: \(token.receivedAt, style: .time)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if token.isClaimed {
                Text("Claimed")
                    .font(.caption)
                    .foregroundColor(.green)
            } else {
                Button("Claim") {
                    onClaim()
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(6)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    BluetoothSettingsView(bitchatBridge: BitchatBridge())
}
