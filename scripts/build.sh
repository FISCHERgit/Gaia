#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
NPROC=$(nproc 2>/dev/null || echo 2)

echo "=== Gaia Linux Build ==="
echo "Project: $PROJECT_DIR"
echo "Build:   $BUILD_DIR"
echo "CPUs:    $NPROC"
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

# --- VM Build Performance: use tmpfs or RAM-backed build if enough RAM ---
MEMTOTAL_MB=$(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
if [ "$MEMTOTAL_MB" -gt 8000 ] && [ ! -d "$BUILD_DIR/chroot" ]; then
    # If >8GB RAM and fresh build, offer tmpfs-backed build dir for speed
    if mountpoint -q "$BUILD_DIR" 2>/dev/null; then
        echo "Build dir already mounted (tmpfs or other)"
    elif [ "${GAIA_TMPFS_BUILD:-0}" = "1" ]; then
        echo "=== Using tmpfs for build (GAIA_TMPFS_BUILD=1) ==="
        mkdir -p "$BUILD_DIR"
        mount -t tmpfs -o size=6G tmpfs "$BUILD_DIR"
        echo "  Mounted 6G tmpfs on $BUILD_DIR — builds will be much faster"
    fi
fi

# --- Use apt-cacher-ng if available (huge speedup on repeated builds) ---
APT_PROXY=""
if curl -s --connect-timeout 1 http://127.0.0.1:3142 &>/dev/null; then
    APT_PROXY="http://127.0.0.1:3142"
    echo "=== apt-cacher-ng detected at $APT_PROXY ==="
elif curl -s --connect-timeout 1 http://192.168.1.1:3142 &>/dev/null; then
    APT_PROXY="http://192.168.1.1:3142"
    echo "=== apt-cacher-ng detected at $APT_PROXY ==="
fi

# Use a fast mirror (auto-detect or use German mirror for EU)
MIRROR="${GAIA_MIRROR:-http://deb.debian.org/debian}"

# Generate installer assets
echo "=== Generating installer banner ==="
bash "$SCRIPT_DIR/generate-installer-banner.sh"
echo "=== Generating installer wallpaper ==="
bash "$SCRIPT_DIR/generate-installer-wallpaper.sh"

# Prepare build directory
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Initialize live-build config
# NOTE: --debian-installer live = real Debian installer using the live filesystem
# Calamares remains in live session as alternative
APT_PROXY_OPTS=""
[ -n "$APT_PROXY" ] && APT_PROXY_OPTS="--apt-http-proxy $APT_PROXY"

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
    --apt-recommends false \
    --mirror-bootstrap "$MIRROR" \
    --mirror-chroot "$MIRROR" \
    --mirror-chroot-security "http://security.debian.org/debian-security" \
    $APT_PROXY_OPTS \
    --bootappend-live "boot=live components quiet splash" \
    --iso-application "Gaia Linux" \
    --iso-publisher "Gaia Project" \
    --iso-volume "GaiaLinux"

echo ""
echo "=== Copying custom config ==="

# Copy custom package lists
echo "Copying package lists..."
cp -v "$PROJECT_DIR/config/package-lists/"*.list.chroot "$BUILD_DIR/config/package-lists/"

# If custom Gaia kernel .debs exist, use them instead of Debian kernel
CUSTOM_KERNEL_DIR="$PROJECT_DIR/config/packages.chroot"
if ls "$CUSTOM_KERNEL_DIR"/linux-image-*.deb &>/dev/null; then
    echo "Custom Gaia kernel detected — using it instead of Debian kernel"
    mkdir -p "$BUILD_DIR/config/packages.chroot"
    cp -v "$CUSTOM_KERNEL_DIR"/linux-*.deb "$BUILD_DIR/config/packages.chroot/"
    # Remove linux-image-amd64 from package list to avoid conflict
    sed -i '/^linux-image-amd64$/d' "$BUILD_DIR/config/package-lists/gaia.list.chroot"
    echo "  Removed linux-image-amd64 from package list"
else
    echo "No custom kernel found — using Debian kernel"
fi

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
    "$BUILD_DIR/config/hooks/live/0100-gaia-customization.hook.chroot"; do
    if [ -f "$f" ]; then
        echo "  OK: $(basename "$f")"
    else
        echo "  MISSING: $f"
        exit 1
    fi
done

# --- Speed up mksquashfs compression (biggest time sink) ---
# Use all available CPU cores and faster compression
export MKSQUASHFS_OPTIONS="-processors $NPROC -comp xz -Xbcj x86 -b 1M"

# Speed up dpkg during build (force-unsafe-io skips fsync = much faster installs)
mkdir -p "$BUILD_DIR/config/includes.chroot/etc/dpkg/dpkg.cfg.d"
echo 'force-unsafe-io' > "$BUILD_DIR/config/includes.chroot/etc/dpkg/dpkg.cfg.d/force-unsafe-io"

# Cleanup hook: remove build-time speedups from final image
cat > "$BUILD_DIR/config/hooks/live/9999-cleanup.hook.chroot" << 'EOF'
#!/bin/bash
# Remove build-time dpkg speedup from final image
rm -f /etc/dpkg/dpkg.cfg.d/force-unsafe-io
# Clean apt caches to reduce image size
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
EOF
chmod +x "$BUILD_DIR/config/hooks/live/9999-cleanup.hook.chroot"

# Build
echo ""
echo "=== Starting build (using $NPROC CPU cores)... ==="
TIME_START=$(date +%s)

lb build

TIME_END=$(date +%s)
TIME_DIFF=$((TIME_END - TIME_START))
MINUTES=$((TIME_DIFF / 60))
SECONDS=$((TIME_DIFF % 60))

echo ""
echo "=== Build complete in ${MINUTES}m ${SECONDS}s ==="
echo "ISO: $(find "$BUILD_DIR" -maxdepth 1 -name '*.iso' -type f)"
ISO_FILE=$(find "$BUILD_DIR" -maxdepth 1 -name '*.iso' -type f | head -1)
if [ -n "$ISO_FILE" ]; then
    ISO_SIZE=$(du -h "$ISO_FILE" | cut -f1)
    echo "Size: $ISO_SIZE"
fi
