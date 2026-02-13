#!/usr/bin/env python3
from PIL import Image, ImageDraw, ImageFont
import sys

# FluxQ brand color
FLUXQ_GREEN = "#00C733"

def generate_base_icon(output_path, size=1024):
    """Generate base icon with white F on FluxQ green background"""
    # Create image with green background
    img = Image.new('RGB', (size, size), FLUXQ_GREEN)
    draw = ImageDraw.Draw(img)

    # Try to use Arial Bold, fallback to system default
    font_size = int(size * 0.6)  # 60% of image size
    font_paths = [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/System/Library/Fonts/Supplemental/Helvetica.ttc",
        "/Library/Fonts/Arial Bold.ttf",
    ]

    font = None
    for font_path in font_paths:
        try:
            font = ImageFont.truetype(font_path, font_size)
            print(f"Using font: {font_path}")
            break
        except Exception as e:
            continue

    if font is None:
        print("Warning: Could not load TrueType font, using default")
        font = ImageFont.load_default()

    # Draw white "F" centered
    text = "F"

    # Get text bounding box
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]

    # Calculate position to center the text
    x = (size - text_width) // 2 - bbox[0]
    y = (size - text_height) // 2 - bbox[1]

    # Draw text
    draw.text((x, y), text, fill="white", font=font)

    # Save image
    img.save(output_path, 'PNG')
    print(f"✅ Generated icon: {output_path}")

if __name__ == "__main__":
    output = sys.argv[1] if len(sys.argv) > 1 else "/tmp/icon-base.png"
    generate_base_icon(output)
