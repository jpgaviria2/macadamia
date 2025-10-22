//
//  EcashTransactionListView.swift
//  macadamia
//
//  UI for displaying list of ecash transactions
//

import SwiftUI

struct EcashTransactionListView: View {
    @ObservedObject var ecashService: EcashBluetoothService
    @State private var selectedFilter: TransactionFilter = .all
    @State private var searchText = ""
    
    private var filteredTransactions: [EcashTransaction] {
        let filtered = ecashService.transactions.filter { transaction in
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
        NavigationView {
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
            .navigationTitle("Transactions")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Refresh") {
                            // Refresh transactions
                        }
                        
                        Button("Export") {
                            // Export transactions
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }
    
    private func getFilterCount(for filter: TransactionFilter) -> Int {
        switch filter {
        case .all:
            return ecashService.transactions.count
        case .incoming:
            return ecashService.transactions.filter { $0.isIncoming }.count
        case .outgoing:
            return ecashService.transactions.filter { !$0.isIncoming }.count
        case .pending:
            return ecashService.transactions.filter { $0.status == .pending }.count
        case .confirmed:
            return ecashService.transactions.filter { $0.status == .confirmed }.count
        case .failed:
            return ecashService.transactions.filter { $0.status == .failed }.count
        }
    }
}

#Preview {
    EcashTransactionListView(
        ecashService: EcashBluetoothService(
            bluetoothBridge: BitchatBridge(),
            cashuService: CashuService()
        )
    )
}
