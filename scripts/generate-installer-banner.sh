#!/bin/bash
# Generate the Debian Installer banner from the Gaia logo
# Requires: imagemagick (convert) or python3 as fallback
# Output: 800x75 PNG banner for the GTK d-i

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOGO="$PROJECT_DIR/assets/branding/logo.png"
OUTPUT="$PROJECT_DIR/config/includes.installer/usr/share/graphics/logo_debian.png"

mkdir -p "$(dirname "$OUTPUT")"

if command -v convert &> /dev/null; then
    # Create a polished banner with gradient background, logo, and text
    convert -size 800x75 \
        \( xc:"#0f0d2e" xc:"#1e1b4b" +append -resize 800x75\! \) \
        \( "$LOGO" -resize x50 -gravity center \) \
        -gravity West -geometry +20+0 -composite \
        -font "Noto-Sans-Bold" -pointsize 26 -fill "#e9d5ff" \
        -gravity West -annotate +85+0 "Gaia Linux" \
        -font "Noto-Sans" -pointsize 13 -fill "#a78bfa" \
        -gravity West -annotate +85+22 "Installation" \
        -font "Noto-Sans" -pointsize 11 -fill "#6d28d9" \
        -gravity East -annotate +20+0 "Powered by Debian" \
        \( -size 800x2 xc:"#7c3aed" \) -gravity South -composite \
        "$OUTPUT"
elif command -v python3 &> /dev/null; then
    echo "Warning: ImageMagick not found. Creating gradient banner with Python3."
    python3 - "$OUTPUT" << 'PYEOF'
import struct, zlib, sys

output_path = sys.argv[1]
width, height = 800, 75

# Gradient from #0f0d2e to #1e1b4b with purple accent line at bottom
raw = b''
for y in range(height):
    raw += b'\x00'
    for x in range(width):
        t = x / width
        if y >= height - 2:
            # Purple accent line at bottom
            r, g, b = 0x7c, 0x3a, 0xed
        else:
            r = int(0x0f + (0x1e - 0x0f) * t)
            g = int(0x0d + (0x1b - 0x0d) * t)
            b = int(0x2e + (0x4b - 0x2e) * t)
        raw += bytes([r, g, b])

def chunk(ctype, data):
    c = ctype + data
    return struct.pack('>I', len(data)) + c + struct.pack('>I', zlib.crc32(c) & 0xffffffff)

with open(output_path, 'wb') as f:
    f.write(b'\x89PNG\r\n\x1a\n')
    f.write(chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)))
    f.write(chunk(b'IDAT', zlib.compress(raw)))
    f.write(chunk(b'IEND', b''))

print(f"Created gradient banner: {output_path}")
PYEOF
else
    echo "Error: Neither ImageMagick nor Python3 available."
    exit 1
fi

echo "Banner generated: $OUTPUT"
