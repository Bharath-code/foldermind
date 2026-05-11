#!/bin/bash
set -e

echo "🚀 Building FolderMind for Release..."

# 1. Regenerate project
xcodegen generate

# 2. Archive the app
xcodebuild archive \
    -project FolderMind.xcodeproj \
    -scheme FolderMind \
    -configuration Release \
    -archivePath build/FolderMind.xcarchive \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

# 3. Export the app
mkdir -p build/Export
cp -R build/FolderMind.xcarchive/Products/Applications/FolderMind.app build/Export/

echo "✅ Build completed: build/Export/FolderMind.app"

# 4. Create DMG (simple version)
echo "📦 Creating DMG..."
hdiutil create -volname FolderMind -srcfolder build/Export -ov -format UDZO FolderMind.dmg

echo "🎉 Done! FolderMind.dmg is ready."
