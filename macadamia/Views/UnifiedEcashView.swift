//
//  UnifiedEcashView.swift
//  macadamia
//
//  Unified UI for ecash via Bluetooth mesh
//

import SwiftUI

struct UnifiedEcashView: View {
    @StateObject private var unifiedService = UnifiedEcashService()
    @State private var selectedTab = 0
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Status Bar
                HStack {
                    // Bluetooth Status
                    HStack(spacing: 6) {
                        Circle()
                            .fill(unifiedService.isBluetoothActive ? .green : .red)
                            .frame(width: 8, height: 8)
                        
                        Text("Bluetooth")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("\(unifiedService.connectedPeers.count) peers")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                
                // Tab Picker
                Picker("Mode", selection: $selectedTab) {
                    Text("Send").tag(0)
                    Text("Receive").tag(1)
                    Text("History").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Content based on selected tab
                TabView(selection: $selectedTab) {
                    // Send Tab
                    UnifiedSendView(unifiedService: unifiedService)
                        .tag(0)
                    
                    // Receive Tab
                    UnifiedReceiveView(unifiedService: unifiedService)
                        .tag(1)
                    
                    // History Tab
                    UnifiedHistoryView(unifiedService: unifiedService)
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Bluetooth Ecash")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Settings") {
                        showingSettings = true
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                UnifiedSettingsView(unifiedService: unifiedService)
            }
        }
        .onAppear {
            Task {
                await unifiedService.startBluetoothServices()
            }
        }
    }
}

struct UnifiedSendView: View {
    @ObservedObject var unifiedService: UnifiedEcashService
    @State private var selectedPeer: BluetoothPeer?
    @State private var amount: String = ""
    @State private var currency: String = "USD"
    @State private var memo: String = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    
    private let currencies = ["USD", "EUR", "GBP", "JPY", "BTC", "SAT"]
    
    var body: some View {
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
            
            // Recipient Selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Bluetooth Recipient")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if unifiedService.connectedPeers.isEmpty {
                    Text("No Bluetooth peers available")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(unifiedService.connectedPeers) { peer in
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
            
            Spacer()
            
            // Send Button
            Button(action: sendEcash) {
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
    }
    
    private var canSend: Bool {
        guard let amountValue = Double(amount),
              amountValue > 0 else {
            return false
        }
        
        return selectedPeer != nil
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
                
                try await unifiedService.sendEcashBluetooth(
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

struct UnifiedReceiveView: View {
    @ObservedObject var unifiedService: UnifiedEcashService
    @State private var showingQRCode = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Text("Receive Ecash")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Receive digital cash via Bluetooth mesh")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top)
            
            // QR Code Section
            VStack(spacing: 16) {
                Text("Your QR Code")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Button(action: {
                    showingQRCode = true
                }) {
                    VStack(spacing: 12) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Show QR Code")
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            
            // Service Status
            VStack(spacing: 12) {
                Text("Service Status")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack {
                    VStack(spacing: 8) {
                        Circle()
                            .fill(unifiedService.isBluetoothActive ? .green : .red)
                            .frame(width: 20, height: 20)
                        
                        Text("Bluetooth")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 8) {
                        Text("\(unifiedService.connectedPeers.count)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("Connected Peers")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingQRCode) {
            QRCodeView(text: "ecash_receive_bluetooth")
        }
    }
}

struct UnifiedHistoryView: View {
    @ObservedObject var unifiedService: UnifiedEcashService
    @State private var searchText = ""
    @State private var selectedFilter: TransactionFilter = .all
    
    private var filteredTransactions: [EcashTransaction] {
        let filtered = unifiedService.transactions.filter { transaction in
            switch selectedFilter {
            case .all:
                return true
            case .incoming:
                return transaction.isIncoming
            case .outgoing:
                return !transaction.isIncoming
            case .pending:
                return transaction.status == .pending
            case .confirmed:
                return transaction.status == .confirmed
            case .failed:
                return transaction.status == .failed
            }
        }
        
        if searchText.isEmpty {
            return filtered.sorted { $0.timestamp > $1.timestamp }
        } else {
            return filtered.filter { transaction in
                transaction.memo?.localizedCaseInsensitiveContains(searchText) == true ||
                transaction.displayAmount.localizedCaseInsensitiveContains(searchText) ||
                transaction.bluetoothPeerID?.localizedCaseInsensitiveContains(searchText) == true
            }.sorted { $0.timestamp > $1.timestamp }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            SearchBar(text: $searchText)
                .padding(.horizontal)
            
            // Filter Picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(TransactionFilter.allCases, id: \.self) { filter in
                        FilterChip(
                            title: filter.displayName,
                            isSelected: selectedFilter == filter,
                            count: getFilterCount(for: filter)
                        ) {
                            selectedFilter = filter
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
            
            // Transactions List
            if filteredTransactions.isEmpty {
                EmptyStateView(filter: selectedFilter)
            } else {
                List(filteredTransactions) { transaction in
                    EcashTransactionView(transaction: transaction)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                }
                .listStyle(PlainListStyle())
            }
        }
    }
    
    private func getFilterCount(for filter: TransactionFilter) -> Int {
        switch filter {
        case .all:
            return unifiedService.transactions.count
        case .incoming:
            return unifiedService.transactions.filter { $0.isIncoming }.count
        case .outgoing:
            return unifiedService.transactions.filter { !$0.isIncoming }.count
        case .pending:
            return unifiedService.transactions.filter { $0.status == .pending }.count
        case .confirmed:
            return unifiedService.transactions.filter { $0.status == .confirmed }.count
        case .failed:
            return unifiedService.transactions.filter { $0.status == .failed }.count
        }
    }
}

struct UnifiedSettingsView: View {
    @ObservedObject var unifiedService: UnifiedEcashService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Bluetooth") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(unifiedService.isBluetoothActive ? "Active" : "Inactive")
                            .foregroundColor(unifiedService.isBluetoothActive ? .green : .red)
                    }
                    
                    HStack {
                        Text("Connected Peers")
                        Spacer()
                        Text("\(unifiedService.connectedPeers.count)")
                    }
                }
                
                Section("Transactions") {
                    HStack {
                        Text("Total Transactions")
                        Spacer()
                        Text("\(unifiedService.transactions.count)")
                    }
                    
                    HStack {
                        Text("Confirmed")
                        Spacer()
                        Text("\(unifiedService.getTransactions(by: .confirmed).count)")
                    }
                    
                    HStack {
                        Text("Pending")
                        Spacer()
                        Text("\(unifiedService.getTransactions(by: .pending).count)")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    UnifiedEcashView()
}

// MARK: - Helper Views and Components

struct PeerCard: View {
    let peer: BluetoothPeer
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Peer Avatar
                Circle()
                    .fill(isSelected ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(peer.displayName.prefix(1).uppercased())
                            .font(.headline)
                            .foregroundColor(isSelected ? .white : .primary)
                    )
                
                // Peer Name
                Text(peer.displayName)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                // Connection Status
                HStack(spacing: 4) {
                    Circle()
                        .fill(peer.isConnected ? .green : .orange)
                        .frame(width: 6, height: 6)
                    
                    Text(peer.isConnected ? "Connected" : "Available")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct QRCodeView: View {
    let text: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Scan this QR code to send ecash")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                // Placeholder QR code - in real app, generate actual QR
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 200, height: 200)
                    .overlay(
                        Text("QR Code")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    )
                
                Text(text)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Spacer()
            }
            .padding()
            .navigationTitle("Receive Ecash")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

enum TransactionFilter: String, CaseIterable {
    case all = "all"
    case incoming = "incoming"
    case outgoing = "outgoing"
    case pending = "pending"
    case confirmed = "confirmed"
    case failed = "failed"
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .incoming: return "Incoming"
        case .outgoing: return "Outgoing"
        case .pending: return "Pending"
        case .confirmed: return "Confirmed"
        case .failed: return "Failed"
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search transactions...", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !text.isEmpty {
                Button("Clear") {
                    text = ""
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                Text("(\(count))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EmptyStateView: View {
    let filter: TransactionFilter
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No Transactions")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("No \(filter.displayName.lowercased()) transactions found")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
