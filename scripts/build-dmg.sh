#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_NAME="FolderMind"
SCHEME="FolderMind"
DERIVED_DATA="$(mktemp -d "${TMPDIR:-/tmp}/foldermind-derived-data.XXXXXX")"
trap 'rm -rf "$DERIVED_DATA"' EXIT

echo "🔨 Building $PROJECT_NAME (Release)..."

xcodebuild \
  -project "$PROJECT_DIR/$PROJECT_NAME.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  build -quiet

APP_PATH="$DERIVED_DATA/Build/Products/Release/$PROJECT_NAME.app"

if [ ! -d "$APP_PATH" ]; then
  echo "❌ Build product not found"
  exit 1
fi

DMG_PATH="$PROJECT_DIR/$PROJECT_NAME.dmg"

echo "📦 Creating DMG..."
hdiutil create -volname "$PROJECT_NAME" -srcfolder "$APP_PATH" -ov -format UDZO "$DMG_PATH" -quiet

echo "✅ $DMG_PATH"
ls -lh "$DMG_PATH" | awk '{print "   Size:", $5}'
