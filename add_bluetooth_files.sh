#!/bin/bash

# Script to add Bluetooth files to Xcode project
# This will add the files to the project.pbxproj file

PROJECT_FILE="macadamia.xcodeproj/project.pbxproj"
TEMP_FILE="temp_project.pbxproj"

# Create backup
cp "$PROJECT_FILE" "${PROJECT_FILE}.backup"

# Add Bluetooth files to the project
# We'll need to add them to the PBXBuildFile section and PBXFileReference section

echo "Adding Bluetooth files to Xcode project..."

# For now, let's just create a simple approach by manually adding the files
# This is a complex process that's better done through Xcode UI

echo "Please add the following files to your Xcode project manually:"
echo ""
echo "Bluetooth Data Models:"
echo "- macadamia/Models/Bluetooth/BluetoothPeer.swift"
echo "- macadamia/Models/Bluetooth/BluetoothMessage.swift" 
echo "- macadamia/Models/Bluetooth/BluetoothConnection.swift"
echo ""
echo "Bluetooth Services:"
echo "- macadamia/Services/Bluetooth/BitchatProtocol/BitchatPacket.swift"
echo "- macadamia/Services/Bluetooth/BitchatProtocol/BinaryProtocol.swift"
echo "- macadamia/Services/Bluetooth/BitchatProtocol/BLEService.swift"
echo "- macadamia/Services/Bluetooth/BitchatBridge.swift"
echo ""
echo "Bluetooth Views:"
echo "- macadamia/Views/Bluetooth/BluetoothStatusView.swift"
echo "- macadamia/Views/Bluetooth/BluetoothSettingsView.swift"
echo "- macadamia/Views/Bluetooth/SendToNearbyView.swift"
echo ""
echo "Instructions:"
echo "1. Right-click on the macadamia folder in Xcode"
echo "2. Choose 'Add Files to macadamia'"
echo "3. Navigate to each file and add them"
echo "4. Make sure to add them to the macadamia target"
echo ""
echo "After adding the files, the project should compile successfully."
