#!/bin/bash

# Fix signing configuration for the fork
echo "🔧 Fixing signing configuration for your fork..."

# Update bundle identifier to use your own domain
sed -i '' 's/com\.BZ32L9M6QB\.macadamia/com.jpgaviria.macadamia/g' macadamia.xcodeproj/project.pbxproj

# Update development team to your team ID
sed -i '' 's/DEVELOPMENT_TEAM = BZ32L9M6QB;/DEVELOPMENT_TEAM = LNE8NMXLL2;/g' macadamia.xcodeproj/project.pbxproj

# Set automatic signing
sed -i '' 's/CODE_SIGN_STYLE = Manual;/CODE_SIGN_STYLE = Automatic;/g' macadamia.xcodeproj/project.pbxproj

# Remove any manual provisioning profile settings
sed -i '' 's/PROVISIONING_PROFILE_SPECIFIER = .*;//g' macadamia.xcodeproj/project.pbxproj

echo "✅ Signing configuration updated!"
echo "📱 New bundle identifier: com.jpgaviria.macadamia"
echo "👤 Development team: LNE8NMXLL2"
echo "🔄 Signing style: Automatic"
