#!/bin/bash
# generate_appcast_entry.sh
# Generates a Sparkle appcast entry for a new FolderMind release.
#
# Usage: ./scripts/generate_appcast_entry.sh <version> <dmg_path>
# Example: ./scripts/generate_appcast_entry.sh 1.0.0 ./build/FolderMind-1.0.0.dmg
#
# Prerequisites:
#   1. Sparkle framework installed (via SPM, already in project)
#   2. Your EdDSA signing key in ~/.edsparkle (generated once with generate_appcast)
#   3. The DMG file already built and code-signed
#
# This script uses Sparkle's generate_appcast tool to:
#   - Sign the DMG with your EdDSA key
#   - Generate the <item> XML block
#   - Output the XML to stdout (copy into appcast.xml)

set -euo pipefail

VERSION="${1:?Usage: $0 <version> <dmg_path>}"
DMG_PATH="${2:?Usage: $0 <version> <dmg_path>}"

if [ ! -f "$DMG_PATH" ]; then
    echo "Error: DMG not found at $DMG_PATH"
    exit 1
fi

# Find Sparkle's generate_appcast tool
SPARKLE_DIR=$(find ~/Library/Developer/Xcode/DerivedData -name "Sparkle" -type d -path "*/SourcePackages/checkouts/Sparkle" 2>/dev/null | head -1)

if [ -z "$SPARKLE_DIR" ]; then
    echo "Error: Sparkle directory not found. Build the project first to download Sparkle via SPM."
    echo "Then run: find ~/Library/Developer/Xcode/DerivedData -name 'generate_appcast' -type f"
    exit 1
fi

GENERATE_APPCAST="$SPARKLE_DIR/bin/generate_appcast"

if [ ! -f "$GENERATE_APPCAST" ]; then
    echo "Error: generate_appcast not found at $GENERATE_APPCAST"
    echo "Build Sparkle from source or find it in DerivedData."
    exit 1
fi

# Generate the appcast entry to a temp directory
TEMP_DIR=$(mktemp -d)
cp "$DMG_PATH" "$TEMP_DIR/FolderMind-$VERSION.dmg"

echo "Generating Sparkle signature for FolderMind $VERSION..."
echo "DMG: $DMG_PATH"
echo ""

# Run generate_appcast — this creates an appcast.xml in the temp dir
"$GENERATE_APPCAST" "$TEMP_DIR" 2>&1

# Output the generated entry
if [ -f "$TEMP_DIR/appcast.xml" ]; then
    echo ""
    echo "=== COPY THIS INTO appcast.xml ==="
    cat "$TEMP_DIR/appcast.xml"
    echo ""
    echo "=== END ==="
else
    echo "Error: appcast.xml was not generated."
    exit 1
fi

# Cleanup
rm -rf "$TEMP_DIR"
