#!/bin/bash
# Integrate the custom Gaia kernel into the live-build config
# Run this BEFORE build.sh to use the custom kernel in the ISO
#
# Usage: sudo ./integrate-kernel.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
OUT_DIR="$SCRIPT_DIR/out"
PACKAGES_DIR="$PROJECT_DIR/config/packages.chroot"

echo "=== Integrating Gaia Kernel ==="

# Check kernel debs exist
if ! ls "$OUT_DIR"/linux-image-*.deb &>/dev/null; then
    echo "Error: No kernel .deb found in $OUT_DIR/"
    echo "Run build-kernel.sh first."
    exit 1
fi

# Copy kernel .debs into live-build packages directory
# live-build auto-installs any .deb in packages.chroot/
mkdir -p "$PACKAGES_DIR"

echo "Copying kernel packages..."
cp -v "$OUT_DIR"/linux-image-*.deb "$PACKAGES_DIR/"
cp -v "$OUT_DIR"/linux-headers-*.deb "$PACKAGES_DIR/" 2>/dev/null || true

# Show what will be installed
echo ""
echo "Kernel packages staged for ISO build:"
ls -lh "$PACKAGES_DIR"/linux-*.deb 2>/dev/null

echo ""
echo "Done. Now run: sudo ./scripts/build.sh"
echo "The custom kernel will be included automatically."
