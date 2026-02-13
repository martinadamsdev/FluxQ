#!/bin/bash
set -e

# 颜色
FLUXQ_GREEN="#00C733"

# 输出目录
OUT_DIR="FluxQ/Assets.xcassets/AppIcon.appiconset"
OUT_DIR_WATCH="FluxQWatch/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$OUT_DIR"
mkdir -p "$OUT_DIR_WATCH"

echo "Generating FluxQ app icons..."

# 清理旧图标文件（保留 Contents.json）
echo "Cleaning old icons..."
find "$OUT_DIR" -name "icon-*.png" -type f -delete
find "$OUT_DIR_WATCH" -name "icon-*.png" -type f -delete

# 检查 ImageMagick
if ! command -v magick &> /dev/null; then
    echo "Error: ImageMagick not found. Installing..."
    brew install imagemagick
fi

# 检查 Python 和 Pillow
if ! python3 -c "from PIL import Image" &> /dev/null; then
    echo "Installing Pillow for icon generation..."
    pip3 install --break-system-packages --user Pillow
fi

# 生成基础 1024x1024 图标
echo "Creating base icon..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
python3 "$SCRIPT_DIR/generate-icon-base.py" /tmp/icon-base.png

# macOS 尺寸
echo "Generating macOS icons..."
for size in 16 32 64 128 256 512 1024; do
    magick /tmp/icon-base.png -resize ${size}x${size} "$OUT_DIR/icon-mac-${size}.png"
done

# iOS 尺寸
echo "Generating iOS icons..."
for size in 20 29 40 60 76 83.5 1024; do
    # 1024 是 iOS marketing icon，需要 1x (1024x1024)
    if [[ "$size" == "1024" ]]; then
        magick /tmp/icon-base.png -resize 1024x1024 "$OUT_DIR/icon-ios-1024.png"
        continue
    fi

    # @2x
    size2x=$(echo "$size * 2" | bc | cut -d. -f1)
    magick /tmp/icon-base.png -resize ${size2x}x${size2x} "$OUT_DIR/icon-ios-${size}@2x.png"

    # @3x (仅部分尺寸)
    if [[ "$size" =~ ^(20|29|40|60)$ ]]; then
        size3x=$(echo "$size * 3" | bc | cut -d. -f1)
        magick /tmp/icon-base.png -resize ${size3x}x${size3x} "$OUT_DIR/icon-ios-${size}@3x.png"
    fi
done

# watchOS 尺寸
echo "Generating watchOS icons..."
for size in 24 27.5 29 40 44 50 86 98 108 1024; do
    # 1024 是 watchOS marketing icon，需要 1x (1024x1024)
    if [[ "$size" == "1024" ]]; then
        magick /tmp/icon-base.png -resize 1024x1024 "$OUT_DIR/icon-watch-1024.png"
        continue
    fi

    # 其他尺寸都是 @2x
    sizepx=$(echo "$size * 2" | bc | cut -d. -f1)
    magick /tmp/icon-base.png -resize ${sizepx}x${sizepx} "$OUT_DIR/icon-watch-${size}@2x.png"
done

# 复制 watchOS 图标到 FluxQWatch 应用
echo "Copying watchOS icon to FluxQWatch..."
cp "$OUT_DIR/icon-watch-1024.png" "$OUT_DIR_WATCH/"

# 验证生成的图标
echo ""
echo "Validating generated icons..."

# 验证 FluxQ
if [[ -f "$OUT_DIR/Contents.json" ]]; then
    VALIDATION_RESULT=$(python3 << 'PYEOF'
import json
import os
import sys

os.chdir('FluxQ/Assets.xcassets/AppIcon.appiconset')

try:
    with open('Contents.json', 'r') as f:
        data = json.load(f)

    required = set([img.get('filename') for img in data['images'] if img.get('filename')])
    existing = set([f for f in os.listdir('.') if f.endswith('.png')])

    missing = required - existing
    extra = existing - required

    if missing:
        print(f"❌ Missing files: {', '.join(sorted(missing))}")
        sys.exit(1)
    elif extra:
        print(f"⚠️  Extra files: {', '.join(sorted(extra))}")
        sys.exit(1)
    else:
        print(f"✅ FluxQ: All {len(existing)} icons match Contents.json")
        sys.exit(0)
except Exception as e:
    print(f"❌ Validation error: {e}")
    sys.exit(1)
PYEOF
)
    VALIDATION_EXIT=$?
    echo "$VALIDATION_RESULT"

    if [[ $VALIDATION_EXIT -ne 0 ]]; then
        echo ""
        echo "⚠️  Validation failed. Please check the files."
        exit 1
    fi
else
    echo "❌ Contents.json not found in $OUT_DIR"
    exit 1
fi

# 验证 FluxQWatch
if [[ -f "$OUT_DIR_WATCH/Contents.json" ]]; then
    WATCH_VALIDATION=$(python3 << 'PYEOF'
import json
import os
import sys

os.chdir('FluxQWatch/Assets.xcassets/AppIcon.appiconset')

try:
    with open('Contents.json', 'r') as f:
        data = json.load(f)

    required = set([img.get('filename') for img in data['images'] if img.get('filename')])
    existing = set([f for f in os.listdir('.') if f.endswith('.png')])

    missing = required - existing
    extra = existing - required

    if missing:
        print(f"❌ Missing files: {', '.join(sorted(missing))}")
        sys.exit(1)
    elif extra:
        print(f"⚠️  Extra files: {', '.join(sorted(extra))}")
        sys.exit(1)
    else:
        print(f"✅ FluxQWatch: All {len(existing)} icons match Contents.json")
        sys.exit(0)
except Exception as e:
    print(f"❌ Validation error: {e}")
    sys.exit(1)
PYEOF
)
    WATCH_EXIT=$?
    echo "$WATCH_VALIDATION"

    if [[ $WATCH_EXIT -ne 0 ]]; then
        echo ""
        echo "⚠️  FluxQWatch validation failed. Please check the files."
        exit 1
    fi
fi

echo ""
echo "✅ Icons generated successfully!"
echo "📁 FluxQ Output: $OUT_DIR"
echo "📁 FluxQWatch Output: $OUT_DIR_WATCH"

# 清理
rm /tmp/icon-base.png
