#!/bin/bash
# Gaia Linux - Install Overlay
# Copies all overlay files into the target root filesystem

set -e

TARGET="${1:-$GAIA}"

if [ -z "$TARGET" ] || [ ! -d "$TARGET" ]; then
    echo "Usage: $0 <target-rootfs>"
    echo "Example: $0 /mnt/gaia"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OVERLAY_DIR="$(dirname "$SCRIPT_DIR")/overlay"

if [ ! -d "$OVERLAY_DIR" ]; then
    echo "Error: Overlay directory not found: $OVERLAY_DIR"
    exit 1
fi

echo "=== Installing Gaia overlay ==="
echo "Source: $OVERLAY_DIR"
echo "Target: $TARGET"
echo ""

# Copy all overlay files preserving permissions
cp -rv "$OVERLAY_DIR/"* "$TARGET/" 2>/dev/null || true

# Copy binary assets from assets/branding/
ASSETS="$(dirname "$SCRIPT_DIR")/assets/branding"
if [ -d "$ASSETS" ]; then
    echo ""
    echo "Installing branding assets..."

    # Wallpaper
    if [ -f "$ASSETS/wallpaper.png" ]; then
        mkdir -p "$TARGET/usr/share/backgrounds/gaia"
        cp -v "$ASSETS/wallpaper.png" "$TARGET/usr/share/backgrounds/gaia/"

        # Create wallpaper package for all resolutions
        mkdir -p "$TARGET/usr/share/wallpapers/Gaia/contents/images"
        for res in 3840x2160 2560x1440 1920x1200 1920x1080 1680x1050 1440x900 1366x768 1280x1024 1024x768; do
            cp "$ASSETS/wallpaper.png" "$TARGET/usr/share/wallpapers/Gaia/contents/images/${res}.png"
        done
        cp "$ASSETS/wallpaper.png" "$TARGET/usr/share/wallpapers/Gaia/contents/screenshot.png"

        # Override default wallpapers
        for wpdir in Next Breeze default; do
            mkdir -p "$TARGET/usr/share/wallpapers/$wpdir/contents/images"
            for res in 3840x2160 2560x1440 1920x1200 1920x1080 1680x1050 1440x900 1366x768 1280x1024 1024x768; do
                cp "$ASSETS/wallpaper.png" "$TARGET/usr/share/wallpapers/$wpdir/contents/images/${res}.png" 2>/dev/null || true
            done
            cp "$ASSETS/wallpaper.png" "$TARGET/usr/share/wallpapers/$wpdir/contents/screenshot.png" 2>/dev/null || true
        done

        # Symlink default wallpaper
        rm -rf "$TARGET/usr/share/wallpapers/default"
        ln -sf /usr/share/wallpapers/Gaia "$TARGET/usr/share/wallpapers/default"
    fi

    # Logo
    if [ -f "$ASSETS/logo.png" ]; then
        cp -v "$ASSETS/logo.png" "$TARGET/usr/share/pixmaps/gaia-logo.png"
        cp -v "$ASSETS/logo.png" "$TARGET/usr/share/icons/hicolor/256x256/apps/gaia-logo.png"
        cp -v "$ASSETS/logo.png" "$TARGET/usr/share/pixmaps/distributor-logo.png"

        # Plymouth theme logo
        cp -v "$ASSETS/logo.png" "$TARGET/usr/share/plymouth/themes/gaia/logo.png"

        # GRUB theme logo
        cp -v "$ASSETS/logo.png" "$TARGET/boot/grub/themes/gaia/logo.png"

        # Calamares logo
        mkdir -p "$TARGET/etc/calamares/branding/gaia"
        cp -v "$ASSETS/logo.png" "$TARGET/etc/calamares/branding/gaia/logo.png"

        # AccountsService
        mkdir -p "$TARGET/var/lib/AccountsService/icons"
        cp -v "$ASSETS/logo.png" "$TARGET/var/lib/AccountsService/icons/gaia.png"
    fi
fi

# Set executable permissions on scripts
chmod +x "$TARGET"/usr/local/bin/gaia-*.sh 2>/dev/null || true
chmod +x "$TARGET"/usr/local/bin/uname 2>/dev/null || true
chmod +x "$TARGET"/etc/skel/Desktop/gaia-installer.desktop 2>/dev/null || true

# Create Plasma shell defaults
mkdir -p "$TARGET/usr/share/plasma/shells/org.kde.plasma.desktop/contents"
cat > "$TARGET/usr/share/plasma/shells/org.kde.plasma.desktop/contents/defaults" << 'EOF'
[Desktop][Containments][General]
Image=file:///usr/share/backgrounds/gaia/wallpaper.png

[Wallpaper]
defaultWallpaperTheme=Gaia
defaultFileSuffix=.png
defaultWidth=1920
defaultHeight=1080
EOF

cat > "$TARGET/usr/share/plasma/shells/org.kde.plasma.desktop/contents/layout.js" << 'EOF'
var wallpaper = desktops()[0];
wallpaper.wallpaperPlugin = "org.kde.image";
wallpaper.currentConfigGroup = Array("Wallpaper", "org.kde.image", "General");
wallpaper.writeConfig("Image", "file:///usr/share/backgrounds/gaia/wallpaper.png");
wallpaper.writeConfig("FillMode", 2);
EOF

# SDDM wallpaper override
mkdir -p "$TARGET/usr/share/sddm/themes/breeze"
cat > "$TARGET/usr/share/sddm/themes/breeze/theme.conf.user" << 'EOF'
[General]
background=/usr/share/backgrounds/gaia/wallpaper.png
type=image
EOF

# Wallpaper metadata
cat > "$TARGET/usr/share/wallpapers/Gaia/metadata.json" << 'EOF'
{
    "KPlugin": {
        "Id": "Gaia",
        "Name": "Gaia Linux",
        "Authors": [{ "Name": "Gaia Project" }]
    }
}
EOF

echo ""
echo "=== Overlay installation complete ==="
