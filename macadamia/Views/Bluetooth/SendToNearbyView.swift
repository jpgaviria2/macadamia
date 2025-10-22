//
//  SendToNearbyView.swift
//  macadamia
//
//  UI for sending ecash to nearby devices via Bluetooth mesh
//

import SwiftUI

struct SendToNearbyView: View {
    @StateObject private var bluetoothBridge = BitchatBridge()
    @StateObject private var ecashService: EcashBluetoothService
    @State private var selectedTab = 0
    
    init() {
        // Initialize with mock services for preview
        let bridge = BitchatBridge()
        let cashuService = CashuService() // You'll need to implement this
        self._ecashService = StateObject(wrappedValue: EcashBluetoothService(bluetoothBridge: bridge, cashuService: cashuService))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Picker
                Picker("Mode", selection: $selectedTab) {
                    Text("Send").tag(0)
                    Text("Receive").tag(1)
                    Text("Transactions").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Content based on selected tab
                TabView(selection: $selectedTab) {
                    // Send Tab
                    EcashSendView(
                        ecashService: ecashService,
                        bluetoothBridge: bluetoothBridge
                    )
                    .tag(0)
                    
                    // Receive Tab
                    EcashReceiveView(
                        ecashService: ecashService,
                        bluetoothBridge: bluetoothBridge
                    )
                    .tag(1)
                    
                    // Transactions Tab
                    EcashTransactionListView(ecashService: ecashService)
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Bluetooth Ecash")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Bluetooth Settings") {
                            // Show Bluetooth settings
                        }
                        
                        Button("Scan for Peers") {
                            ecashService.startScanning()
                        }
                        
                        Button("Stop Scanning") {
                            ecashService.stopScanning()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear {
            ecashService.startScanning()
        }
    }
}

struct EcashReceiveView: View {
    @ObservedObject var ecashService: EcashBluetoothService
    @ObservedObject var bluetoothBridge: BitchatBridge
    @State private var isAdvertising = false
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
            
            // Advertising Status
            VStack(spacing: 12) {
                HStack {
                    Circle()
                        .fill(isAdvertising ? .green : .gray)
                        .frame(width: 12, height: 12)
                    
                    Text(isAdvertising ? "Advertising for ecash" : "Not advertising")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                Button(action: toggleAdvertising) {
                    Text(isAdvertising ? "Stop Advertising" : "Start Advertising")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isAdvertising ? Color.red : Color.green)
                        .cornerRadius(12)
                }
            }
            
            // Connected Peers
            if !bluetoothBridge.connectedPeers.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Connected Peers")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    ForEach(Array(bluetoothBridge.peers), id: \.peerID) { peer in
                        HStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            
                            Text(peer.displayName)
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text(peer.peerID)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
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
            QRView(string: "ecash_receive_local_peer")
        }
    }
    
    private func toggleAdvertising() {
        if isAdvertising {
            ecashService.stopAdvertising()
        } else {
            ecashService.startAdvertising()
        }
        isAdvertising.toggle()
    }
}

#Preview {
    SendToNearbyView()
}