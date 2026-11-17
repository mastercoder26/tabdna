#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "Building TabDNA for macOS..."
swift build -c release --arch arm64 --arch x86_64

APP_NAME="TabDNA"
APP_DIR="${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

swift Scripts/MakeAppIcon.swift "${RESOURCES_DIR}"

RELEASE_BIN=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/TabDNA
cp "${RELEASE_BIN}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

cat <<EOF > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.tabdna.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>TabDNA</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>TabDNA uses AppleScript to inspect active tabs in Comet, Google Chrome, and Safari to construct your local browsing graph.</string>
</dict>
</plist>
EOF

# A local ad-hoc signature makes both architectures internally verifiable.
# Public distribution still requires Developer ID signing and notarization.
codesign --force --sign - "${APP_DIR}"
codesign --verify --deep --strict "${APP_DIR}"

echo "Built $(pwd)/${APP_DIR}"
