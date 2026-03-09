#!/bin/bash
# Gaia Linux - Custom Kernel Builder
# Takes the Debian kernel source, rebrands it to "gaia", and builds .deb packages.
#
# Usage: sudo ./build-kernel.sh [--clean]
# Output: .deb packages in kernel/out/
#
# Prerequisites:
#   sudo apt install build-essential fakeroot libncurses-dev \
#       libssl-dev libelf-dev bc flex bison dwarves \
#       linux-source dpkg-dev debhelper rsync cpio

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
KERNEL_DIR="$SCRIPT_DIR/build"
OUT_DIR="$SCRIPT_DIR/out"

# Gaia branding
GAIA_LOCALVERSION="-gaia"
GAIA_BUILD_ID="Gaia Linux"

echo "=== Gaia Kernel Builder ==="

# Check root
if [ "$EUID" -ne 0 ]; then
    echo "Error: Must run as root (sudo)."
    exit 1
fi

# Clean mode
if [ "$1" = "--clean" ]; then
    echo "Cleaning kernel build..."
    rm -rf "$KERNEL_DIR" "$OUT_DIR"
    echo "Done."
    exit 0
fi

# Check deps
for cmd in make gcc dpkg-buildpackage; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: '$cmd' not found."
        echo "Install: sudo apt install build-essential fakeroot libncurses-dev libssl-dev libelf-dev bc flex bison dwarves dpkg-dev debhelper"
        exit 1
    fi
done

# Find Debian kernel source
KERNEL_SRC=""
if [ -f /usr/src/linux-source-*.tar.xz ]; then
    KERNEL_SRC=$(ls -1 /usr/src/linux-source-*.tar.xz | sort -V | tail -1)
elif dpkg -l linux-source* 2>/dev/null | grep -q "^ii"; then
    KERNEL_SRC=$(dpkg -L $(dpkg -l linux-source* | grep "^ii" | awk '{print $2}' | sort -V | tail -1) | grep ".tar.xz" | head -1)
fi

if [ -z "$KERNEL_SRC" ] || [ ! -f "$KERNEL_SRC" ]; then
    echo "Debian kernel source not found. Installing..."
    apt-get update
    apt-get install -y linux-source
    KERNEL_SRC=$(ls -1 /usr/src/linux-source-*.tar.xz | sort -V | tail -1)
fi

echo "Using kernel source: $KERNEL_SRC"
KERNEL_VERSION=$(basename "$KERNEL_SRC" | sed 's/linux-source-\(.*\)\.tar\.xz/\1/')
echo "Kernel version: $KERNEL_VERSION"

# Extract source
mkdir -p "$KERNEL_DIR"
cd "$KERNEL_DIR"

if [ ! -d "linux-source-$KERNEL_VERSION" ]; then
    echo "Extracting kernel source..."
    tar xf "$KERNEL_SRC"
fi

cd "linux-source-$KERNEL_VERSION"

# Copy current Debian kernel config
echo "Copying running kernel config..."
if [ -f "/boot/config-$(uname -r)" ]; then
    cp "/boot/config-$(uname -r)" .config
elif [ -f /proc/config.gz ]; then
    zcat /proc/config.gz > .config
else
    echo "Warning: No kernel config found, using Debian default"
    make defconfig
fi

# Apply Gaia branding
echo "Applying Gaia branding..."

# Set local version string (shows in uname -r)
scripts/config --set-str CONFIG_LOCALVERSION "$GAIA_LOCALVERSION"

# Set build ID
scripts/config --set-str CONFIG_BUILD_SALT "$GAIA_BUILD_ID"

# Disable debug info to speed up build
scripts/config --disable CONFIG_DEBUG_INFO_BTF
scripts/config --disable CONFIG_DEBUG_INFO_DWARF5
scripts/config --disable CONFIG_DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT

# Accept all defaults for new options
make olddefconfig

# Show what we're building
echo ""
echo "  Version:  $KERNEL_VERSION"
echo "  Local:    $GAIA_LOCALVERSION"
echo "  uname -r: ${KERNEL_VERSION}${GAIA_LOCALVERSION}"
echo ""

# Build as .deb packages
NPROC=$(nproc)
echo "Building with $NPROC threads..."

make -j"$NPROC" bindeb-pkg \
    LOCALVERSION="$GAIA_LOCALVERSION" \
    KDEB_PKGVERSION="1.0-gaia" \
    KDEB_COMPRESS="xz" \
    2>&1 | tee "$SCRIPT_DIR/kernel-build.log"

# Collect output
mkdir -p "$OUT_DIR"
mv "$KERNEL_DIR"/*.deb "$OUT_DIR/" 2>/dev/null || true

echo ""
echo "=== Kernel build complete ==="
echo "Packages:"
ls -lh "$OUT_DIR/"*.deb 2>/dev/null || echo "  No .deb files found!"
echo ""
echo "To install: sudo dpkg -i $OUT_DIR/linux-image-*.deb $OUT_DIR/linux-headers-*.deb"
