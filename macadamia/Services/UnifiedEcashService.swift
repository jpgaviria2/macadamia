//
//  UnifiedEcashService.swift
//  macadamia
//
//  Unified service for ecash across Bluetooth mesh
//

import Foundation
import Combine
import CashuSwift

/// Unified service for managing ecash across Bluetooth mesh
@MainActor
class UnifiedEcashService: ObservableObject {
    @Published var transactions: [EcashTransaction] = []
    @Published var isBluetoothActive = false
    @Published var connectedPeers: [BluetoothPeer] = []
    
    private let bluetoothBridge: BitchatBridge
    private let ecashBluetoothService: EcashBluetoothService
    private let cashuService: CashuService
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Initialize services
        self.bluetoothBridge = BitchatBridge()
        self.cashuService = CashuService()
        self.ecashBluetoothService = EcashBluetoothService(
            bluetoothBridge: bluetoothBridge,
            cashuService: cashuService
        )
        
        setupObservers()
    }
    
    // MARK: - Public Methods
    
    /// Start Bluetooth services
    func startBluetoothServices() async {
        ecashBluetoothService.startScanning()
        ecashBluetoothService.startAdvertising()
    }
    
    /// Stop Bluetooth services
    func stopBluetoothServices() {
        ecashBluetoothService.stopScanning()
        ecashBluetoothService.stopAdvertising()
    }
    
    /// Send ecash via Bluetooth
    func sendEcashBluetooth(
        to peer: BluetoothPeer,
        amount: UInt64,
        currency: String = "USD",
        memo: String? = nil
    ) async throws {
        try await ecashBluetoothService.sendEcash(
            to: peer,
            amount: amount,
            currency: currency,
            memo: memo
        )
    }
    
    /// Request ecash via Bluetooth
    func requestEcashBluetooth(
        from peer: BluetoothPeer,
        amount: UInt64,
        currency: String = "USD",
        memo: String? = nil
    ) async throws {
        try await ecashBluetoothService.requestEcash(
            from: peer,
            amount: amount,
            currency: currency,
            memo: memo
        )
    }
    
    /// Get transaction history
    func getTransactionHistory() -> [EcashTransaction] {
        return transactions.sorted { $0.timestamp > $1.timestamp }
    }
    
    /// Get transactions by status
    func getTransactions(by status: TransactionStatus) -> [EcashTransaction] {
        return transactions.filter { $0.status == status }
    }
    
    /// Get transactions by direction
    func getTransactions(isIncoming: Bool) -> [EcashTransaction] {
        return transactions.filter { $0.isIncoming == isIncoming }
    }
    
    /// Get transactions by currency
    func getTransactions(by currency: String) -> [EcashTransaction] {
        return transactions.filter { $0.currency == currency }
    }
    
    /// Search transactions
    func searchTransactions(query: String) -> [EcashTransaction] {
        return transactions.filter { transaction in
            transaction.memo?.localizedCaseInsensitiveContains(query) == true ||
            transaction.displayAmount.localizedCaseInsensitiveContains(query) ||
            transaction.bluetoothPeerID?.localizedCaseInsensitiveContains(query) == true
        }
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Observe Bluetooth transactions
        ecashBluetoothService.$transactions
            .sink { [weak self] bluetoothTransactions in
                Task { @MainActor in
                    self?.updateTransactions()
                }
            }
            .store(in: &cancellables)
        
        // Observe Bluetooth peers
        bluetoothBridge.$peers
            .sink { [weak self] peers in
                Task { @MainActor in
                    self?.connectedPeers = Array(peers)
                }
            }
            .store(in: &cancellables)
        
        // Observe Bluetooth status
        bluetoothBridge.$isActive
            .assign(to: &$isBluetoothActive)
    }
    
    private func updateTransactions() {
        // Merge Bluetooth transactions with existing ones
        let bluetoothTransactions = ecashBluetoothService.transactions
        
        for bluetoothTransaction in bluetoothTransactions {
            if !transactions.contains(where: { $0.id == bluetoothTransaction.id }) {
                transactions.append(bluetoothTransaction)
            }
        }
        
        // Remove duplicates and sort
        transactions = Array(Set(transactions)).sorted { $0.timestamp > $1.timestamp }
    }
}

// MARK: - Extensions

extension UnifiedEcashService {
    /// Get service status summary
    var statusSummary: String {
        if isBluetoothActive {
            return "Bluetooth: \(connectedPeers.count) peers"
        } else {
            return "Bluetooth: Inactive"
        }
    }
    
    /// Get total balance across all currencies
    var totalBalance: [String: UInt64] {
        var balances: [String: UInt64] = [:]
        
        for transaction in transactions where transaction.status == .confirmed {
            if transaction.isIncoming {
                balances[transaction.currency, default: 0] += transaction.amount
            } else {
                balances[transaction.currency, default: 0] -= transaction.amount
            }
        }
        
        return balances
    }
    
    /// Get recent activity
    var recentActivity: [EcashTransaction] {
        return Array(transactions.prefix(10))
    }
}
