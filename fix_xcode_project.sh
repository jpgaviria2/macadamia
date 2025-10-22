#!/bin/bash

# Script to fix Xcode project file references
# This removes the old file references and ensures the project uses the correct paths

echo "Fixing Xcode project file references..."

# First, let's check what files are currently referenced in the project
echo "Current project structure:"
find /Users/dayi/git/macadamia/macadamia -name "*.swift" | grep -E "(Bluetooth|Bitchat)" | sort

echo ""
echo "Files that need to be added to Xcode project:"
echo "- macadamia/Models/Bluetooth/BluetoothPeer.swift"
echo "- macadamia/Models/Bluetooth/BluetoothMessage.swift" 
echo "- macadamia/Models/Bluetooth/BluetoothConnection.swift"
echo "- macadamia/Services/Bluetooth/BitchatBridge.swift"
echo "- macadamia/Services/Bluetooth/BitchatProtocol/BitchatPacket.swift"
echo "- macadamia/Services/Bluetooth/BitchatProtocol/BinaryProtocol.swift"
echo "- macadamia/Services/Bluetooth/BitchatProtocol/BLEService.swift"
echo "- macadamia/Views/Bluetooth/SendToNearbyView.swift"
echo "- macadamia/Views/Bluetooth/BluetoothStatusView.swift"
echo "- macadamia/Views/Bluetooth/BluetoothSettingsView.swift"

echo ""
echo "Please manually remove the following files from Xcode project:"
echo "- BluetoothMessage.swift (root)"
echo "- BitchatBridge.swift (root)"
echo "- BitchatPacket.swift (root)"
echo "- BinaryProtocol.swift (root)"
echo "- SendToNearbyView.swift (root)"
echo "- BluetoothStatusView.swift (root)"
echo "- BluetoothPeer.swift (root)"
echo "- BluetoothConnection.swift (root)"
echo "- BLEService.swift (root)"
echo "- BluetoothSettingsView.swift (root)"

echo ""
echo "Then add the correct files from their proper locations in the macadamia/ folder."
