//
//  EcashSendView.swift
//  macadamia
//
//  UI for sending ecash via Bluetooth mesh
//

import SwiftUI
import CashuSwift

struct EcashSendView: View {
    @ObservedObject var ecashService: EcashBluetoothService
    @ObservedObject var bluetoothBridge: BitchatBridge
    @State private var selectedPeer: BluetoothPeer?
    @State private var amount: String = ""
    @State private var currency: String = "USD"
    @State private var memo: String = ""
    @State private var showingPeerPicker = false
    @State private var showingConfirmation = false
    @State private var isSending = false
    @State private var errorMessage: String?
    
    private let currencies = ["USD", "EUR", "GBP", "JPY", "BTC", "SAT"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text("Send Ecash")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Send digital cash via Bluetooth mesh")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
                
                // Peer Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recipient")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Button(action: {
                        showingPeerPicker = true
                    }) {
                        HStack {
                            if let peer = selectedPeer {
                                VStack(alignment: .leading) {
                                    Text(peer.displayName)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    
                                    Text(peer.peerID)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Text("Select a peer")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                
                // Amount Input
                VStack(alignment: .leading, spacing: 12) {
                    Text("Amount")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .font(.title2)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Picker("Currency", selection: $currency) {
                            ForEach(currencies, id: \.self) { currency in
                                Text(currency).tag(currency)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 80)
                    }
                }
                
                // Memo Input
                VStack(alignment: .leading, spacing: 12) {
                    Text("Memo (Optional)")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Add a note...", text: $memo)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                // Available Peers
                if !bluetoothBridge.peers.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Available Peers")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(bluetoothBridge.peers.filter { $0.isConnected }) { peer in
                                    PeerCard(
                                        peer: peer,
                                        isSelected: selectedPeer?.peerID == peer.peerID,
                                        onTap: {
                                            selectedPeer = peer
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                Spacer()
                
                // Send Button
                Button(action: {
                    showingConfirmation = true
                }) {
                    HStack {
                        if isSending {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                        
                        Text(isSending ? "Sending..." : "Send Ecash")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canSend ? Color.blue : Color.gray)
                    .cornerRadius(12)
                }
                .disabled(!canSend || isSending)
                
                // Error Message
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingPeerPicker) {
            PeerPickerView(
                peers: bluetoothBridge.peers.filter { $0.isConnected },
                selectedPeer: $selectedPeer
            )
        }
        .alert("Confirm Send", isPresented: $showingConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Send") {
                sendEcash()
            }
        } message: {
            if let peer = selectedPeer, let amountValue = Double(amount) {
                Text("Send \(String(format: "%.2f", amountValue)) \(currency) to \(peer.displayName)?")
            }
        }
    }
    
    private var canSend: Bool {
        guard let _ = selectedPeer,
              let amountValue = Double(amount),
              amountValue > 0 else {
            return false
        }
        return true
    }
    
    private func sendEcash() {
        guard let peer = selectedPeer,
              let amountValue = Double(amount),
              amountValue > 0 else {
            return
        }
        
        isSending = true
        errorMessage = nil
        
        Task {
            do {
                let amountInSatoshis = UInt64(amountValue * 100) // Convert to satoshis
                try await ecashService.sendEcash(
                    to: peer,
                    amount: amountInSatoshis,
                    currency: currency,
                    memo: memo.isEmpty ? nil : memo
                )
                
                // Reset form
                amount = ""
                memo = ""
                selectedPeer = nil
                
            } catch {
                errorMessage = error.localizedDescription
            }
            
            isSending = false
        }
    }
}


struct PeerPickerView: View {
    let peers: [BluetoothPeer]
    @Binding var selectedPeer: BluetoothPeer?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(peers) { peer in
                Button(action: {
                    selectedPeer = peer
                    dismiss()
                }) {
                    HStack {
                        // Peer Avatar
                        Circle()
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(peer.displayName.prefix(1).uppercased())
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            )
                        
                        VStack(alignment: .leading) {
                            Text(peer.displayName)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(peer.peerID)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if peer.isConnected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .navigationTitle("Select Peer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    EcashSendView(
        ecashService: EcashBluetoothService(
            bluetoothBridge: BitchatBridge(),
            cashuService: CashuService()
        ),
        bluetoothBridge: BitchatBridge()
    )
}
