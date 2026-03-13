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
    # Create a minimal banner with logo on the far left, no text
    convert -size 800x75 xc:"#1e1e1e" \
        \( "$LOGO" -resize x55 -gravity center \) \
        -gravity West -geometry +10+0 -composite \
        \( -size 800x1 xc:"#c4d600" \) -gravity South -composite \
        "$OUTPUT"
elif command -v python3 &> /dev/null; then
    echo "Warning: ImageMagick not found. Creating gradient banner with Python3."
    python3 - "$OUTPUT" << 'PYEOF'
import struct, zlib, sys

output_path = sys.argv[1]
width, height = 800, 75

# Dark background with thin green accent line at bottom
raw = b''
for y in range(height):
    raw += b'\x00'
    for x in range(width):
        if y >= height - 1:
            # Green accent line at bottom
            r, g, b = 0xc4, 0xd6, 0x00
        else:
            r, g, b = 0x1e, 0x1e, 0x1e
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
