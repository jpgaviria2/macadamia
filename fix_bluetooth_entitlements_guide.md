# 🔧 Fix Bluetooth Entitlements - Complete Guide

## The Issue
The provisioning profile doesn't include the Bluetooth entitlements because the App ID in Apple Developer Portal doesn't have Bluetooth capabilities enabled.

## Solution: Enable Bluetooth Capabilities in Apple Developer Portal

### Step 1: Go to Apple Developer Portal
1. Open [developer.apple.com](https://developer.apple.com)
2. Sign in with your Apple ID
3. Go to **"Certificates, Identifiers & Profiles"**

### Step 2: Find Your App ID
1. Click on **"Identifiers"** in the left sidebar
2. Look for your App ID: `com.jpgaviria.macadamia`
3. If it doesn't exist, create it:
   - Click the **"+"** button
   - Select **"App IDs"**
   - Choose **"App"**
   - Enter Bundle ID: `com.jpgaviria.macadamia`
   - Enter Description: "macadamia Bluetooth App"

### Step 3: Enable Bluetooth Capabilities
1. Click on your App ID (`com.jpgaviria.macadamia`)
2. Click **"Edit"**
3. Scroll down to **"Capabilities"**
4. Check these boxes:
   - ✅ **Bluetooth Central**
   - ✅ **Bluetooth Peripheral**
5. Click **"Save"**

### Step 4: Regenerate Provisioning Profile
1. Go to **"Profiles"** in the left sidebar
2. Find your provisioning profile for `com.jpgaviria.macadamia`
3. Click **"Edit"**
4. Click **"Generate"** to regenerate the profile
5. Download the new profile

### Step 5: Update Xcode
1. In Xcode, go to **"Signing & Capabilities"** for both targets
2. Uncheck **"Automatically manage signing"**
3. Wait 2-3 seconds
4. Check **"Automatically manage signing"** again
5. This will force Xcode to download the new provisioning profile

## Alternative: Manual Provisioning Profile

If the above doesn't work, try creating a manual provisioning profile:

### Step 1: Create Manual Profile
1. In Apple Developer Portal, go to **"Profiles"**
2. Click **"+"** to create new profile
3. Select **"iOS App Development"**
4. Select your App ID (`com.jpgaviria.macadamia`)
5. Select your development certificate
6. Select your device
7. Name it "macadamia Bluetooth Development"
8. Download the profile

### Step 2: Install Profile in Xcode
1. Double-click the downloaded `.mobileprovision` file
2. It will install in Xcode automatically

### Step 3: Use Manual Profile
1. In Xcode, go to **"Signing & Capabilities"**
2. Uncheck **"Automatically manage signing"**
3. Select the manual provisioning profile you just created

## Expected Result
After following these steps, Xcode should be able to build and deploy your app to the physical iPhone with Bluetooth capabilities enabled.

## Troubleshooting
- If you get "No profiles found", make sure the App ID has Bluetooth capabilities enabled
- If you get "Team not found", make sure you're signed in to Xcode with your Apple ID
- If you get "Entitlements not found", make sure the `.entitlements` file has the Bluetooth capabilities

## Quick Test
After making these changes, try building again:
```bash
xcodebuild -project macadamia.xcodeproj -scheme macadamia -destination 'platform=iOS,id=00008101-0009388A1E06001E' -allowProvisioningUpdates build
```
