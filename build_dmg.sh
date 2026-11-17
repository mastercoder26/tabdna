#!/bin/sh
set -eu

cd "$(dirname "$0")"
sh build_app.sh

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' TabDNA.app/Contents/Info.plist)
OUTPUT_DIR="$(pwd)/dist"
DMG_NAME="TabDNA-${VERSION}-universal.dmg"
STAGING_DIR=$(mktemp -d "${TMPDIR:-/tmp}/tabdna-dmg.XXXXXX")
trap 'rm -rf "$STAGING_DIR"' EXIT HUP INT TERM

mkdir -p "$OUTPUT_DIR"
ditto TabDNA.app "$STAGING_DIR/TabDNA.app"
ln -s /Applications "$STAGING_DIR/Applications"
hdiutil create -volname "TabDNA" -srcfolder "$STAGING_DIR" \
    -ov -format UDZO "$OUTPUT_DIR/$DMG_NAME"
hdiutil verify "$OUTPUT_DIR/$DMG_NAME"
(cd "$OUTPUT_DIR" && shasum -a 256 "$DMG_NAME" > "$DMG_NAME.sha256")
echo "Built $OUTPUT_DIR/$DMG_NAME"
