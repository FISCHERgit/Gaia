#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"

echo "=== Gaia Linux Build ==="
echo "Project: $PROJECT_DIR"
echo "Build:   $BUILD_DIR"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: Build must run as root (sudo)."
    exit 1
fi

# Check dependencies
for cmd in lb debootstrap; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: '$cmd' not found. Install with: sudo apt install live-build debootstrap"
        exit 1
    fi
done

# Prepare build directory
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Initialize live-build config
lb config \
    --distribution bookworm \
    --archive-areas "main contrib non-free non-free-firmware" \
    --architectures amd64 \
    --binary-images iso-hybrid \
    --bootloaders "grub-efi" \
    --debian-installer live \
    --iso-application "Gaia Linux" \
    --iso-publisher "Gaia Project" \
    --iso-volume "GaiaLinux"

# Copy custom package lists
cp "$PROJECT_DIR/config/package-lists/"*.list.chroot "$BUILD_DIR/config/package-lists/" 2>/dev/null || true

# Copy filesystem overlay
if [ -d "$PROJECT_DIR/config/includes.chroot" ]; then
    cp -r "$PROJECT_DIR/config/includes.chroot/"* "$BUILD_DIR/config/includes.chroot/" 2>/dev/null || true
fi

# Copy hooks
if [ -d "$PROJECT_DIR/config/hooks/live" ]; then
    cp "$PROJECT_DIR/config/hooks/live/"* "$BUILD_DIR/config/hooks/live/" 2>/dev/null || true
fi

# Build
echo ""
echo "=== Starting build... ==="
lb build

echo ""
echo "=== Build complete ==="
echo "ISO: $(find "$BUILD_DIR" -name '*.iso' -type f)"
