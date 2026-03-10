#!/bin/bash
# Generate a subtle dark wallpaper for the Debian Installer background

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT="$PROJECT_DIR/config/includes.installer/usr/share/graphics/desktop-background.png"

mkdir -p "$(dirname "$OUTPUT")"

if command -v convert &> /dev/null; then
    convert -size 1920x1080 \
        radial-gradient:"#1e1b4b"-"#0a0820" \
        "$OUTPUT"
elif command -v python3 &> /dev/null; then
    python3 - "$OUTPUT" << 'PYEOF'
import struct, zlib, sys, math

output_path = sys.argv[1]
# Generate at 640x360, d-i will scale it up — much faster
width, height = 640, 360
cx, cy = width / 2, height / 2
max_dist = math.sqrt(cx * cx + cy * cy)

cr, cg, cb = 0x1e, 0x1b, 0x4b
er, eg, eb = 0x0a, 0x08, 0x20

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
    echo "Error: Neither ImageMagick nor Python3 available."
    exit 1
fi

echo "Installer wallpaper generated: $OUTPUT"
