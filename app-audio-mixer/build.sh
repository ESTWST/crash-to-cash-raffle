#!/bin/bash
# Builds AudioMixer.app (needs Xcode command line tools, macOS 14.2+)
set -e
cd "$(dirname "$0")"
swift build -c release
APP=AudioMixer.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/AudioMixer "$APP/Contents/MacOS/AudioMixer"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>AudioMixer</string>
  <key>CFBundleDisplayName</key><string>Audio Mixer</string>
  <key>CFBundleIdentifier</key><string>local.audiomixer</string>
  <key>CFBundleExecutable</key><string>AudioMixer</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.2</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAudioCaptureUsageDescription</key>
  <string>Audio Mixer captures audio from the apps you choose so it can play it on a different output device.</string>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
echo "Built $APP  ->  open $APP"
