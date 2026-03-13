#!/bin/bash
# Generate the installer background wallpaper
# Uses the actual Gaia wallpaper if available, falls back to generated gradient

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
WALLPAPER="$PROJECT_DIR/assets/branding/wallpaper.png"
OUTPUT="$PROJECT_DIR/config/includes.installer/usr/share/graphics/desktop-background.png"

mkdir -p "$(dirname "$OUTPUT")"

# Use the actual Gaia wallpaper for the installer background
if [ -f "$WALLPAPER" ]; then
    cp "$WALLPAPER" "$OUTPUT"
    echo "Installer wallpaper: copied from Gaia wallpaper"
elif command -v convert &> /dev/null; then
    # Fallback: generate cream/green radial gradient
    convert -size 1920x1080 \
        radial-gradient:"#c4d600"-"#f5f5eb" \
        "$OUTPUT"
    echo "Installer wallpaper: generated gradient"
elif command -v python3 &> /dev/null; then
    python3 - "$OUTPUT" << 'PYEOF'
import struct, zlib, sys, math

output_path = sys.argv[1]
width, height = 640, 360
cx, cy = width / 2, height / 2
max_dist = math.sqrt(cx * cx + cy * cy)

# Center: yellow-green (#c4d600), edges: cream (#f5f5eb)
cr, cg, cb = 0xc4, 0xd6, 0x00
er, eg, eb = 0xf5, 0xf5, 0xeb

raw = bytearray()
for y in range(height):
    raw += b'\x00'
    row = bytearray()
    for x in range(width):
        d = min(math.sqrt((x - cx) ** 2 + (y - cy) ** 2) / max_dist, 1.0)
        row += bytes([int(cr + (er - cr) * d), int(cg + (eg - cg) * d), int(cb + (eb - cb) * d)])
    raw += row

def chunk(ctype, data):
    c = ctype + data
    return struct.pack('>I', len(data)) + c + struct.pack('>I', zlib.crc32(c) & 0xffffffff)

with open(output_path, 'wb') as f:
    f.write(b'\x89PNG\r\n\x1a\n')
    f.write(chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)))
    f.write(chunk(b'IDAT', zlib.compress(bytes(raw), 9)))
    f.write(chunk(b'IEND', b''))

print(f"Created installer wallpaper: {output_path}")
PYEOF
else
    echo "Error: Neither wallpaper file, ImageMagick, nor Python3 available."
    exit 1
fi

echo "Installer wallpaper generated: $OUTPUT"
