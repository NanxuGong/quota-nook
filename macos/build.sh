#!/bin/zsh
# Build Quota Nook.app (needs Xcode command line tools)
set -e
cd "$(dirname "$0")"
APP="dist/Quota Nook.app"
MODULE_CACHE="${TMPDIR:-/tmp}/quota-nook-module-cache"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
mkdir -p "$MODULE_CACHE"
swiftc -O main.swift PixelTheme.swift FlatThemes.swift PixelSciFi.swift Scenic.swift \
  -module-cache-path "$MODULE_CACHE" \
  -o "$APP/Contents/MacOS/QuotaNook" -framework Cocoa -framework SwiftUI
cat > "$APP/Contents/Info.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Quota Nook</string>
<key>CFBundleIdentifier</key><string>local.quota-nook</string>
<key>CFBundleExecutable</key><string>QuotaNook</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>LSUIElement</key><true/>
<key>LSMinimumSystemVersion</key><string>14.0</string>
</dict></plist>
PL
xattr -cr "$APP"
codesign -s - --force "$APP"
echo "✅ Built $PWD/$APP"
