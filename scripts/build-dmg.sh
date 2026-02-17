#!/bin/bash
set -euo pipefail

# 此脚本由 Xcode Aggregate Target "FluxQ DMG" 的 Run Script Phase 调用
# 也可独立使用: ./scripts/build-dmg.sh [path-to-app] [output-dir]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_PATH="${1:-${BUILT_PRODUCTS_DIR:-build}/FluxQ.app}"
OUTPUT_DIR="${2:-${SCRIPT_DIR}/../build}"

if [ ! -d "$APP_PATH" ]; then
  echo "Error: FluxQ.app not found at $APP_PATH"
  echo "Usage: build-dmg.sh [path-to-app] [output-dir]"
  exit 1
fi

echo "========================================"
echo "  FluxQ DMG Builder"
echo "========================================"
echo "App: $APP_PATH"
echo ""

# 签名 + 公证（设置 SKIP_NOTARIZE=1 可跳过）
if [ "${SKIP_NOTARIZE:-0}" != "1" ]; then
  echo "==> Step 1/2: 签名 + 公证"
  "$SCRIPT_DIR/notarize.sh" "$APP_PATH"
else
  echo "==> Step 1/2: 跳过签名公证 (SKIP_NOTARIZE=1)"
fi

# 打包 DMG
echo "==> Step 2/2: 打包 DMG"
"$SCRIPT_DIR/create-dmg.sh" "$APP_PATH" "$OUTPUT_DIR"

echo "========================================"
echo "  完成！"
echo "========================================"
