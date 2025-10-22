//
//  EcashTransactionView.swift
//  macadamia
//
//  UI for displaying and managing ecash transactions
//

import SwiftUI
import CashuSwift

struct EcashTransactionView: View {
    @ObservedObject var transaction: EcashTransaction
    @State private var showingDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Transaction direction icon
                Image(systemName: transaction.isIncoming ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                    .foregroundColor(transaction.isIncoming ? .green : .red)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    // Amount and currency
                    Text(transaction.displayAmount)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    // Status and peer info
                    HStack {
                        Text(transaction.status.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color(transaction.status.color).opacity(0.2))
                            .foregroundColor(Color(transaction.status.color))
                            .cornerRadius(4)
                        
                        if let peerID = transaction.bluetoothPeerID {
                            Text("via \(String(peerID.prefix(8)))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Timestamp
                Text(transaction.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Memo if available
            if let memo = transaction.memo, !memo.isEmpty {
                Text(memo)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // Mesh hops indicator
            if transaction.meshHops > 0 {
                HStack {
                    Image(systemName: "network")
                        .font(.caption)
                    Text("\(transaction.meshHops) hops")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .onTapGesture {
            showingDetails = true
        }
        .sheet(isPresented: $showingDetails) {
            EcashTransactionDetailView(transaction: transaction)
        }
    }
}

struct EcashTransactionDetailView: View {
    @ObservedObject var transaction: EcashTransaction
    @Environment(\.dismiss) private var dismiss
    @State private var showingShareSheet = false
    @State private var showingQRCode = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(spacing: 16) {
                        // Amount
                        Text(transaction.displayAmount)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        // Status
                        HStack {
                            Circle()
                                .fill(Color(transaction.status.color))
                                .frame(width: 8, height: 8)
                            
                            Text(transaction.status.displayName)
                                .font(.headline)
                                .foregroundColor(Color(transaction.status.color))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Transaction Details
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Transaction Details")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        DetailRow(title: "Transaction ID", value: transaction.id)
                        DetailRow(title: "Direction", value: transaction.isIncoming ? "Received" : "Sent")
                        DetailRow(title: "Timestamp", value: DateFormatter.detailed.string(from: transaction.timestamp))
                        
                        if let peerID = transaction.bluetoothPeerID {
                            DetailRow(title: "Peer ID", value: peerID)
                        }
                        
                        if transaction.meshHops > 0 {
                            DetailRow(title: "Mesh Hops", value: "\(transaction.meshHops)")
                        }
                        
                        if let rssi = transaction.rssi {
                            DetailRow(title: "Signal Strength", value: "\(rssi) dBm")
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    
                    // Cashu Token
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Cashu Token")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(transaction.token)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .lineLimit(nil)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    
                    // Memo
                    if let memo = transaction.memo, !memo.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Memo")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(memo)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    }
                    
                    // Nostr Integration
                    if let nostrEventID = transaction.nostrEventID {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Nostr Event")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(nostrEventID)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    }
                }
                .padding()
            }
            .navigationTitle("Transaction Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Share Token") {
                            showingShareSheet = true
                        }
                        
                        Button("Show QR Code") {
                            showingQRCode = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [transaction.token])
        }
        .sheet(isPresented: $showingQRCode) {
            QRCodeView(text: transaction.token)
        }
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}


// MARK: - Extensions

extension DateFormatter {
    static let detailed: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .medium
        return formatter
    }()
}

#Preview {
    EcashTransactionView(
        transaction: EcashTransaction(
            senderID: "peer123",
            amount: 1000,
            currency: "USD",
            token: "cashu_1000_USD_abc123",
            memo: "Payment for coffee",
            isIncoming: true,
            bluetoothPeerID: "peer123",
            meshHops: 2,
            rssi: -45
        )
    )
    .padding()
}
