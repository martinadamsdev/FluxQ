#!/bin/bash
set -e

# 颜色
FLUXQ_GREEN="#00C733"

# 输出目录
OUT_DIR="FluxQ/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$OUT_DIR"

echo "Generating FluxQ app icons..."

# 检查 ImageMagick
if ! command -v convert &> /dev/null; then
    echo "Error: ImageMagick not found. Installing..."
    brew install imagemagick
fi

# 生成基础 1024x1024 图标
echo "Creating base icon..."
convert -size 1024x1024 xc:"$FLUXQ_GREEN" \
        -gravity center \
        -font "Helvetica-Bold" \
        -pointsize 600 \
        -fill white \
        -annotate +0+0 "F" \
        /tmp/icon-base.png

# macOS 尺寸
echo "Generating macOS icons..."
for size in 16 32 64 128 256 512 1024; do
    convert /tmp/icon-base.png -resize ${size}x${size} "$OUT_DIR/icon-mac-${size}.png"
done

# iOS 尺寸
echo "Generating iOS icons..."
for size in 20 29 40 60 76 83.5 1024; do
    # @2x
    size2x=$(echo "$size * 2" | bc | cut -d. -f1)
    convert /tmp/icon-base.png -resize ${size2x}x${size2x} "$OUT_DIR/icon-ios-${size}@2x.png"

    # @3x (仅部分尺寸)
    if [[ "$size" =~ ^(20|29|40|60)$ ]]; then
        size3x=$(echo "$size * 3" | bc | cut -d. -f1)
        convert /tmp/icon-base.png -resize ${size3x}x${size3x} "$OUT_DIR/icon-ios-${size}@3x.png"
    fi
done

# watchOS 尺寸
echo "Generating watchOS icons..."
for size in 24 27.5 29 40 44 50 86 98 108 1024; do
    sizepx=$(echo "$size * 2" | bc | cut -d. -f1)
    convert /tmp/icon-base.png -resize ${sizepx}x${sizepx} "$OUT_DIR/icon-watch-${size}@2x.png"
done

echo "✅ Icons generated successfully!"
echo "📁 Output: $OUT_DIR"

# 清理
rm /tmp/icon-base.png
