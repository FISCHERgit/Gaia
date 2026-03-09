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

# Generate installer banner from logo
echo "=== Generating installer banner ==="
bash "$SCRIPT_DIR/generate-installer-banner.sh"

# Prepare build directory
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Initialize live-build config
# NOTE: --debian-installer live = real Debian installer using the live filesystem
# Calamares remains in live session as alternative
lb config \
    --distribution trixie \
    --archive-areas "main contrib non-free non-free-firmware" \
    --architectures amd64 \
    --binary-images iso-hybrid \
    --bootloaders "grub-efi,grub-pc" \
    --debian-installer live \
    --debian-installer-gui true \
    --memtest none \
    --cache true \
    --cache-packages true \
    --cache-stages "bootstrap rootfs" \
    --apt-indices false \
    --iso-application "Gaia Linux" \
    --iso-publisher "Gaia Project" \
    --iso-volume "GaiaLinux"

echo ""
echo "=== Copying custom config ==="

# Copy custom package lists
echo "Copying package lists..."
cp -v "$PROJECT_DIR/config/package-lists/"*.list.chroot "$BUILD_DIR/config/package-lists/"

# Copy filesystem overlay (files that go into the live system)
echo "Copying includes.chroot..."
if [ -d "$PROJECT_DIR/config/includes.chroot" ]; then
    cp -rv "$PROJECT_DIR/config/includes.chroot/." "$BUILD_DIR/config/includes.chroot/"
fi

# Copy binary overlay (files that go onto the ISO, e.g. GRUB config)
echo "Copying includes.binary..."
if [ -d "$PROJECT_DIR/config/includes.binary" ]; then
    cp -rv "$PROJECT_DIR/config/includes.binary/." "$BUILD_DIR/config/includes.binary/"
fi

# Copy installer preseed and branding (for Debian Installer)
echo "Copying installer config..."
if [ -d "$PROJECT_DIR/config/includes.installer" ]; then
    mkdir -p "$BUILD_DIR/config/includes.installer"
    cp -rv "$PROJECT_DIR/config/includes.installer/." "$BUILD_DIR/config/includes.installer/"
fi

# Copy hooks
echo "Copying hooks..."
if [ -d "$PROJECT_DIR/config/hooks/live" ]; then
    cp -v "$PROJECT_DIR/config/hooks/live/"* "$BUILD_DIR/config/hooks/live/"
fi

# Verify critical files are in place
echo ""
echo "=== Verifying config ==="
for f in \
    "$BUILD_DIR/config/package-lists/gaia.list.chroot" \
    "$BUILD_DIR/config/includes.chroot/usr/share/backgrounds/gaia/wallpaper.png" \
    "$BUILD_DIR/config/includes.chroot/usr/share/pixmaps/gaia-logo.png" \
    "$BUILD_DIR/config/includes.chroot/etc/calamares/settings.conf" \
    "$BUILD_DIR/config/includes.binary/boot/grub/grub.cfg" \
    "$BUILD_DIR/config/hooks/live/0100-gaia-customization.hook.chroot"; do
    if [ -f "$f" ]; then
        echo "  OK: $(basename "$f")"
    else
        echo "  MISSING: $f"
        exit 1
    fi
done

# Build
echo ""
echo "=== Starting build... ==="
lb build

echo ""
echo "=== Build complete ==="
echo "ISO: $(find "$BUILD_DIR" -maxdepth 1 -name '*.iso' -type f)"
