#!/bin/bash
# Apply Gaia desktop configs for current user (runs once at first login)
MARKER="$HOME/.gaia-configured"
[ -f "$MARKER" ] && exit 0

# Force-copy all skel configs (overwrite Plasma defaults)
mkdir -p "$HOME/.config" "$HOME/.local/share/konsole"
cp -rf /etc/skel/.config/* "$HOME/.config/" 2>/dev/null || true
cp -rf /etc/skel/.local/share/konsole/* "$HOME/.local/share/konsole/" 2>/dev/null || true

# VM detection — optimize for virtual machines
IS_VM=false
if systemd-detect-virt -q 2>/dev/null; then
    IS_VM=true
fi

if [ "$IS_VM" = true ]; then
    echo "VM detected — applying VM optimizations"

    # Disable compositor in VMs (huge performance gain)
    kwriteconfig6 --file kwinrc --group Compositing --key Enabled false 2>/dev/null || true

    # Reduce desktop effects to zero
    kwriteconfig6 --file kdeglobals --group KDE --key AnimationDurationFactor 0 2>/dev/null || true

    # Force X11 rendering backend in VMs (more stable than Wayland in VMs)
    kwriteconfig6 --file kwinrc --group Compositing --key Backend XRender 2>/dev/null || true
fi

# Kill Baloo if it somehow started
balooctl6 disable 2>/dev/null || balooctl disable 2>/dev/null || true
killall baloo_file 2>/dev/null || true

# Force wallpaper via Plasma CLI tools
if command -v plasma-apply-wallpaperimage &> /dev/null; then
    plasma-apply-wallpaperimage /usr/share/backgrounds/gaia/wallpaper.png 2>/dev/null || true
fi
if command -v plasma-apply-lookandfeel &> /dev/null; then
    plasma-apply-lookandfeel --apply org.kde.breezedark.desktop 2>/dev/null || true
fi
if command -v plasma-apply-colorscheme &> /dev/null; then
    plasma-apply-colorscheme BreezeDark 2>/dev/null || true
fi

# Force wallpaper in Plasma config files directly (belt and suspenders)
mkdir -p "$HOME/.config"
kwriteconfig6 --file "$HOME/.config/plasmarc" --group Wallpapers --key usersWallpapers "/usr/share/backgrounds/gaia/wallpaper.png" 2>/dev/null || true

# Overwrite plasma-org.kde.plasma.desktop-appletsrc wallpaper setting
if [ -f "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" ]; then
    sed -i 's|Image=.*|Image=file:///usr/share/backgrounds/gaia/wallpaper.png|g' "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" 2>/dev/null || true
fi

# Disable Baloo file indexer
balooctl6 disable 2>/dev/null || balooctl disable 2>/dev/null || true

touch "$MARKER"
