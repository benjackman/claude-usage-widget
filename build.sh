#!/bin/zsh
# Builds ClaudeUsage.app (menu-bar only, no Dock icon) and optionally installs it.
#   ./build.sh            -> build/ClaudeUsage.app
#   ./build.sh install    -> also copies to /Applications and launches it
set -e
cd "$(dirname "$0")"

swift build -c release
APP=build/ClaudeUsage.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/ClaudeUsage "$APP/Contents/MacOS/"
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>ClaudeUsage</string>
  <key>CFBundleIdentifier</key><string>local.claude-usage-widget</string>
  <key>CFBundleExecutable</key><string>ClaudeUsage</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
EOF
codesign --force --sign - "$APP"
echo "Built $APP"

if [[ "$1" == "install" ]]; then
  pkill -x ClaudeUsage 2>/dev/null || true
  rm -rf /Applications/ClaudeUsage.app
  cp -R "$APP" /Applications/
  open /Applications/ClaudeUsage.app
  echo "Installed to /Applications"
fi
