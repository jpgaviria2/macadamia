# 🔧 Fix iPhone Deployment - Step by Step Guide

## The Issue
The provisioning profile doesn't include the Bluetooth entitlements for your new bundle ID `com.jpgaviria.macadamia`.

## Solution: Force Xcode to Regenerate Provisioning Profile

### Step 1: Open Xcode
```bash
open /Users/dayi/git/macadamia/macadamia.xcodeproj
```

### Step 2: Configure Main App Target
1. **Select the project** "macadamia" in the navigator
2. **Select the "macadamia" target** (not the project)
3. **Go to "Signing & Capabilities" tab**
4. **Uncheck "Automatically manage signing"**
5. **Wait 2-3 seconds**
6. **Check "Automatically manage signing" again**
7. **Select your Apple Developer team** from the dropdown
8. **Verify the bundle identifier** shows `com.jpgaviria.macadamia`

### Step 3: Configure Messages Extension Target
1. **Select the "macadamiaMessages" target**
2. **Go to "Signing & Capabilities" tab**
3. **Uncheck "Automatically manage signing"**
4. **Wait 2-3 seconds**
5. **Check "Automatically manage signing" again**
6. **Select your Apple Developer team** from the dropdown
7. **Verify the bundle identifier** shows `com.jpgaviria.macadamia.macadamiaMessages`

### Step 4: Verify Bluetooth Capabilities
Make sure both targets have these capabilities:
- ✅ **Background Modes** (with Background processing enabled)
- ✅ **Bluetooth Central** 
- ✅ **Bluetooth Peripheral**

### Step 5: Clean and Build
1. **Product** → **Clean Build Folder** (Cmd+Shift+K)
2. **Select your iPhone** as the destination device
3. **Click the "Play" button** to build and run (Cmd+R)

## Alternative: Manual Provisioning Profile Fix

If the above doesn't work:

### Option A: Change Bundle ID Temporarily
1. Change bundle ID to `com.jpgaviria.macadamia2`
2. Build successfully (this creates a new provisioning profile)
3. Change bundle ID back to `com.jpgaviria.macadamia`
4. Build again

### Option B: Apple Developer Portal
1. Go to [developer.apple.com](https://developer.apple.com)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Find your App ID `com.jpgaviria.macadamia`
4. Edit it and make sure Bluetooth capabilities are enabled
5. Regenerate the provisioning profile

## Expected Result
After following these steps, Xcode should automatically generate a new provisioning profile that includes the Bluetooth entitlements, allowing you to deploy to your physical iPhone.

## Troubleshooting
- If you get "No profiles found", try changing the bundle ID slightly
- If you get "Team not found", make sure you're signed in to Xcode with your Apple ID
- If you get "Entitlements not found", make sure the `.entitlements` file has the Bluetooth capabilities
