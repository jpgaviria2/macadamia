//
//  BluetoothStatusView.swift
//  macadamia
//
//  Bluetooth status indicator and controls
//

import SwiftUI

struct BluetoothStatusView: View {
    @StateObject private var bitchatBridge = BitchatBridge()
    @State private var showingSettings = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Status indicator
            HStack {
                Image(systemName: bitchatBridge.isActive ? "bluetooth" : "bluetooth.disabled")
                    .foregroundColor(bitchatBridge.isActive ? .blue : .gray)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bluetooth Mesh")
                        .font(.headline)
                    
                    Text(bitchatBridge.isActive ? "Active" : "Inactive")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    if bitchatBridge.isActive {
                        bitchatBridge.stopServices()
                    } else {
                        bitchatBridge.startServices()
                    }
                }) {
                    Text(bitchatBridge.isActive ? "Stop" : "Start")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(bitchatBridge.isActive ? Color.red : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Peer count
            if bitchatBridge.isActive {
                HStack {
                    Image(systemName: "person.2")
                        .foregroundColor(.blue)
                    
                    Text("\(bitchatBridge.peers.count) nearby devices")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if !bitchatBridge.connectedPeers.isEmpty {
                        Text("\(bitchatBridge.connectedPeers.count) connected")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                .padding(.horizontal)
            }
            
            // Settings button
            Button(action: {
                showingSettings = true
            }) {
                HStack {
                    Image(systemName: "gear")
                    Text("Bluetooth Settings")
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
        }
        .sheet(isPresented: $showingSettings) {
            BluetoothSettingsView(bitchatBridge: bitchatBridge)
        }
    }
}

#Preview {
    BluetoothStatusView()
        .padding()
}
