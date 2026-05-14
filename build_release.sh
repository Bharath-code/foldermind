#!/bin/bash
set -e

echo "🚀 Building FolderMind for Release..."

# Check for required environment variables
if [ -z "$APPLE_ID" ] || [ -z "$APPLE_TEAM_ID" ] || [ -z "$APPLE_APP_SPECIFIC_PASSWORD" ]; then
    echo "⚠️  Missing credentials. Set APPLE_ID, APPLE_TEAM_ID, and APPLE_APP_SPECIFIC_PASSWORD."
    echo "   Skipping code signing and notarization."
    SIGN_FLAGS="CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO"
else
    SIGN_FLAGS=""
fi

# 1. Regenerate project
xcodegen generate

# 2. Archive the app
xcodebuild archive \
    -project FolderMind.xcodeproj \
    -scheme FolderMind \
    -configuration Release \
    -archivePath build/FolderMind.xcarchive \
    $SIGN_FLAGS

# 3. Export the app
mkdir -p build/Export
cp -R build/FolderMind.xcarchive/Products/Applications/FolderMind.app build/Export/

echo "✅ Build completed: build/Export/FolderMind.app"

# 4. Create DMG
echo "📦 Creating DMG..."
hdiutil create -volname FolderMind -srcfolder build/Export -ov -format UDZO build/FolderMind.dmg

echo "✅ DMG created: build/FolderMind.dmg"

# 5. Notarize (if credentials available)
if [ -n "$APPLE_ID" ] && [ -n "$APPLE_TEAM_ID" ] && [ -n "$APPLE_APP_SPECIFIC_PASSWORD" ]; then
    echo "🔐 Submitting for notarization..."
    xcrun notarytool submit build/FolderMind.dmg \
        --apple-id "$APPLE_ID" \
        --team-id "$APPLE_TEAM_ID" \
        --password "$APPLE_APP_SPECIFIC_PASSWORD" \
        --wait

    echo "📎 Stapling notarization ticket..."
    xcrun stapler staple build/FolderMind.dmg

    echo "✅ Notarization complete."
else
    echo "⚠️  Skipping notarization (credentials not set)."
fi

echo "🎉 Done! build/FolderMind.dmg is ready."
