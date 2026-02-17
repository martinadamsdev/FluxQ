#!/bin/bash
set -euo pipefail

# Usage: create-dmg.sh <path-to-app> [output-dir]
APP_PATH="${1:?Usage: create-dmg.sh <path-to-app> [output-dir]}"
OUTPUT_DIR="${2:-build}"

APP_NAME=$(basename "$APP_PATH" .app)
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo "1.0.0")
DMG_NAME="${APP_NAME}-${VERSION}.dmg"

echo "==> 创建 DMG: $DMG_NAME"

# 准备临时目录
STAGING_DIR=$(mktemp -d)
trap 'rm -rf "$STAGING_DIR"' EXIT

cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# 确保输出目录存在
mkdir -p "$OUTPUT_DIR"

DMG_PATH="$OUTPUT_DIR/$DMG_NAME"
rm -f "$DMG_PATH"

# 创建 DMG
hdiutil create "$DMG_PATH" \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO

echo "==> DMG 已生成: $DMG_PATH"
