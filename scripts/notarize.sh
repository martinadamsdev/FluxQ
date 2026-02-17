#!/bin/bash
set -euo pipefail

# Usage: notarize.sh <path-to-app>
# Required env: DEVELOPER_ID_NAME, NOTARIZE_KEYCHAIN_PROFILE
APP_PATH="${1:?Usage: notarize.sh <path-to-app>}"

DEVELOPER_ID_NAME="${DEVELOPER_ID_NAME:?Set DEVELOPER_ID_NAME env var (e.g. 'Developer ID Application: Your Name (TEAMID)')}"
NOTARIZE_KEYCHAIN_PROFILE="${NOTARIZE_KEYCHAIN_PROFILE:?Set NOTARIZE_KEYCHAIN_PROFILE env var (run: xcrun notarytool store-credentials)}"

APP_NAME=$(basename "$APP_PATH" .app)

echo "==> 签名: $APP_PATH"
codesign --deep --force --options runtime \
  --sign "$DEVELOPER_ID_NAME" \
  "$APP_PATH"

codesign --verify --verbose "$APP_PATH"
echo "==> 签名验证通过"

echo "==> 创建 zip 用于公证提交..."
ZIP_PATH=$(mktemp -d)/"${APP_NAME}.zip"
trap 'rm -f "$ZIP_PATH"' EXIT

ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "==> 提交公证..."
xcrun notarytool submit "$ZIP_PATH" \
  --keychain-profile "$NOTARIZE_KEYCHAIN_PROFILE" \
  --wait

echo "==> 钉合公证票据..."
xcrun stapler staple "$APP_PATH"

echo "==> 公证完成: $APP_PATH"
