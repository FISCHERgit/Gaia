#!/bin/bash
# Gaia Linux Post-Install Branding
# Called from preseed late_command to apply all Gaia customizations
# to the installed system (which d-i installs fresh from packages).
#
# The live system gets customized by the hook, but d-i doesn't copy
# any of that — so this script replicates the essential parts.

set -e
TARGET="/target"

echo "=== Gaia Post-Install Branding ==="

# --- OS branding ---
echo "gaia" > "$TARGET/etc/hostname" || true
cat > "$TARGET/etc/os-release" << 'EOF'
PRETTY_NAME="Gaia Linux"
NAME="Gaia"
ID=gaia
ID_LIKE=debian
VERSION_CODENAME=trixie
HOME_URL="https://github.com/FISCHERgit/Gaia"
EOF

# --- Default shell: zsh ---
in-target sed -i 's|DSHELL=/bin/bash|DSHELL=/bin/zsh|' /etc/default/useradd || true

# --- SDDM ---
mkdir -p "$TARGET/etc/sddm.conf.d"
cat > "$TARGET/etc/sddm.conf.d/gaia.conf" << 'EOF'
[Theme]
Current=breeze
CursorTheme=breeze_cursors

[Theme-Breeze]
Background=/usr/share/backgrounds/gaia/wallpaper.png
EOF

in-target systemctl set-default graphical.target || true
in-target systemctl enable sddm || true
in-target systemctl disable gdm3 || true
in-target systemctl disable lightdm || true

# --- Wallpaper ---
# Copy from ISO media (try both d-i and live paths)
WALLPAPER_SRC=""
for src in /cdrom/live/filesystem.squashfs /run/live/medium/live/filesystem.squashfs; do
    [ -f "$src" ] && break
done

# The wallpaper should be on the ISO in includes.chroot
# Try to find it from the ISO media
mkdir -p "$TARGET/usr/share/backgrounds/gaia"
for src in \
    /cdrom/usr/share/backgrounds/gaia/wallpaper.png \
    /run/live/medium/usr/share/backgrounds/gaia/wallpaper.png \
    /media/cdrom/usr/share/backgrounds/gaia/wallpaper.png \
    /usr/share/backgrounds/gaia/wallpaper.png; do
    if [ -f "$src" ]; then
        cp "$src" "$TARGET/usr/share/backgrounds/gaia/wallpaper.png"
        WALLPAPER_SRC="$src"
        echo "Wallpaper copied from: $src"
        break
    fi
done

# If wallpaper not found directly, try to extract from squashfs
if [ -z "$WALLPAPER_SRC" ]; then
    for sqfs in /cdrom/live/filesystem.squashfs /run/live/medium/live/filesystem.squashfs; do
        if [ -f "$sqfs" ]; then
            unsquashfs -f -d /tmp/sqfs-extract "$sqfs" usr/share/backgrounds/gaia/wallpaper.png 2>/dev/null || true
            if [ -f /tmp/sqfs-extract/usr/share/backgrounds/gaia/wallpaper.png ]; then
                cp /tmp/sqfs-extract/usr/share/backgrounds/gaia/wallpaper.png "$TARGET/usr/share/backgrounds/gaia/wallpaper.png"
                echo "Wallpaper extracted from squashfs"
                WALLPAPER_SRC="squashfs"
            fi
            rm -rf /tmp/sqfs-extract
            break
        fi
    done
fi

# Set wallpaper in all standard locations
if [ -f "$TARGET/usr/share/backgrounds/gaia/wallpaper.png" ]; then
    # Wallpaper package for Plasma
    mkdir -p "$TARGET/usr/share/wallpapers/Gaia/contents/images"
    for res in 3840x2160 2560x1440 1920x1200 1920x1080 1680x1050 1440x900 1366x768 1280x1024 1024x768; do
        cp "$TARGET/usr/share/backgrounds/gaia/wallpaper.png" "$TARGET/usr/share/wallpapers/Gaia/contents/images/${res}.png" || true
    done
    cp "$TARGET/usr/share/backgrounds/gaia/wallpaper.png" "$TARGET/usr/share/wallpapers/Gaia/contents/screenshot.png" || true

    cat > "$TARGET/usr/share/wallpapers/Gaia/metadata.json" << 'EOF'
{
    "KPlugin": {
        "Id": "Gaia",
        "Name": "Gaia Linux",
        "Authors": [{ "Name": "Gaia Project" }]
    }
}
EOF

    # Override default wallpapers
    for wpdir in Next Breeze default; do
        mkdir -p "$TARGET/usr/share/wallpapers/$wpdir/contents/images"
        for res in 3840x2160 2560x1440 1920x1200 1920x1080 1680x1050 1440x900 1366x768 1280x1024 1024x768; do
            cp "$TARGET/usr/share/backgrounds/gaia/wallpaper.png" "$TARGET/usr/share/wallpapers/$wpdir/contents/images/${res}.png" 2>/dev/null || true
        done
        cp "$TARGET/usr/share/backgrounds/gaia/wallpaper.png" "$TARGET/usr/share/wallpapers/$wpdir/contents/screenshot.png" 2>/dev/null || true
    done

    # Plasma shell defaults
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

    # Layout.js
    cat > "$TARGET/usr/share/plasma/shells/org.kde.plasma.desktop/contents/layout.js" << 'LAYOUTEOF'
var wallpaper = desktops()[0];
wallpaper.wallpaperPlugin = "org.kde.image";
wallpaper.currentConfigGroup = Array("Wallpaper", "org.kde.image", "General");
wallpaper.writeConfig("Image", "file:///usr/share/backgrounds/gaia/wallpaper.png");
wallpaper.writeConfig("FillMode", 2);
LAYOUTEOF

    # SDDM breeze theme wallpaper
    mkdir -p "$TARGET/usr/share/sddm/themes/breeze"
    cat > "$TARGET/usr/share/sddm/themes/breeze/theme.conf.user" << 'EOF'
[General]
background=/usr/share/backgrounds/gaia/wallpaper.png
type=image
EOF
fi

# --- KDE skel configs (for all new users + existing users) ---
SKEL="$TARGET/etc/skel"
mkdir -p "$SKEL/.config" "$SKEL/.config/autostart" "$SKEL/.config/gtk-3.0" "$SKEL/.config/gtk-4.0"
mkdir -p "$SKEL/.local/share/konsole"

# Plasma dark theme + Gaia accent
cat > "$SKEL/.config/kdeglobals" << 'EOF'
[General]
ColorScheme=BreezeDark
Name=Breeze Dark
WidgetStyle=Breeze

[Colors:View]
BackgroundNormal=26,28,18
ForegroundNormal=232,228,216

[Colors:Selection]
BackgroundNormal=196,214,0
ForegroundNormal=26,28,18

[Colors:Button]
BackgroundNormal=49,54,18
ForegroundNormal=232,228,216

[Icons]
Theme=breeze-dark

[KDE]
LookAndFeelPackage=org.kde.breezedark.desktop
SingleClick=false
AnimationDurationFactor=0.5
EOF

cat > "$SKEL/.config/plasmarc" << 'EOF'
[Theme]
name=breeze-dark

[Colors]
accentColor=#c4d600
EOF

cat > "$SKEL/.config/kwinrc" << 'EOF'
[TabBox]
DesktopLayout=org.kde.breeze.desktop
DesktopListLayout=org.kde.breeze.desktop
LayoutName=org.kde.breeze.desktop

[Desktops]
Number=1
Rows=1

[Compositing]
Backend=OpenGL
Enabled=true
GLCore=true
GLPreferBufferSwap=a
LatencyPolicy=Low
MaxFPS=60
OpenGLIsUnsafe=false
VBlankTime=6000
WindowsBlockCompositing=true
AnimationSpeed=2

[Plugins]
blurEnabled=false
contrastEnabled=false
slideEnabled=false
fadeEnabled=true
loginEnabled=false
logoutEnabled=false
maximizeEnabled=false
squashEnabled=false
translucencyEnabled=false
kwin4_effect_scaleEnabled=false
kwin4_effect_fadingpopupsEnabled=true
kwin4_effect_morphingpopupsEnabled=true
kwin4_effect_dimscreenEnabled=false
kwin4_effect_fullscreenEnabled=false
kwin4_effect_dialogparentEnabled=false
overviewEnabled=false
screenedgeEnabled=false
desktopgridEnabled=false
highlightwindowEnabled=false
kwin4_effect_windowapertureEnabled=false
shakecursorEnabled=false
tileseditorEnabled=false

[org.kde.kdecoration2]
BorderSize=None
BorderSizeAuto=false
ButtonsOnLeft=XIA
ButtonsOnRight=
library=org.kde.breeze
theme=Breeze

[Windows]
Placement=Smart
FocusPolicy=ClickToFocus
EOF

cat > "$SKEL/.config/baloofilerc" << 'EOF'
[Basic Settings]
Indexing-Enabled=false
EOF

# Desktop layout (wallpaper + panels)
cat > "$SKEL/.config/plasma-org.kde.plasma.desktop-appletsrc" << 'EOF'
[Containments][1]
activityId=
formfactor=0
immutability=1
lastScreen=0
location=0
plugin=org.kde.plasma.folder
wallpaperplugin=org.kde.image

[Containments][1][Wallpaper][org.kde.image][General]
Image=file:///usr/share/backgrounds/gaia/wallpaper.png
FillMode=2
SlidePaths=

[Containments][2]
activityId=
formfactor=2
immutability=1
lastScreen=0
location=3
plugin=org.kde.panel

[Containments][2][General]
AppletOrder=4;5;6

[Containments][2][Applets][4]
immutability=1
plugin=org.kde.plasma.appmenu

[Containments][2][Applets][5]
immutability=1
plugin=org.kde.plasma.systemtray

[Containments][2][Applets][6]
immutability=1
plugin=org.kde.plasma.digitalclock

[Containments][2][Applets][6][Configuration][Appearance]
showDate=true
dateFormat=custom
customDateFormat=ddd d MMM

[Containments][3]
activityId=
formfactor=2
immutability=1
lastScreen=0
location=4
plugin=org.kde.panel

[Containments][3][General]
AppletOrder=7;8;9

[Containments][3][Applets][7]
immutability=1
plugin=org.kde.plasma.kickoff

[Containments][3][Applets][7][Configuration][General]
icon=/usr/share/pixmaps/gaia-logo.png
favoritesPortedToKAstats=true

[Containments][3][Applets][8]
immutability=1
plugin=org.kde.plasma.icontasks

[Containments][3][Applets][8][Configuration][General]
launchers=preferred://filemanager,preferred://browser,applications:org.kde.konsole.desktop,applications:org.kde.kate.desktop

[Containments][3][Applets][9]
immutability=1
plugin=org.kde.plasma.trash
EOF

cat > "$SKEL/.config/plasmashellrc" << 'EOF'
[Wallpapers][org.kde.image][General]
Image=file:///usr/share/backgrounds/gaia/wallpaper.png
FillMode=2

[PlasmaViews][Panel 2]
thickness=26
floating=0
alignment=2

[PlasmaViews][Panel 3]
thickness=56
floating=1
alignment=4
panelVisibility=2
lengthMode=2
EOF

cat > "$SKEL/.config/kscreenlockerrc" << 'EOF'
[Greeter][Wallpaper][org.kde.image][General]
Image=file:///usr/share/backgrounds/gaia/wallpaper.png
FillMode=2
EOF

# Konsole profile
cat > "$SKEL/.local/share/konsole/Gaia.profile" << 'EOF'
[Appearance]
ColorScheme=Breeze
Font=Hack,12,-1,5,50,0,0,0,0,0

[General]
Command=/bin/zsh
Name=Gaia
Parent=FALLBACK/

[Scrolling]
HistoryMode=2
EOF

cat > "$SKEL/.config/konsolerc" << 'EOF'
[Desktop Entry]
DefaultProfile=Gaia.profile

[TabBar]
TabBarVisibility=ShowTabBarWhenNeeded
EOF

# GTK dark theme
cat > "$SKEL/.config/gtk-3.0/settings.ini" << 'EOF'
[Settings]
gtk-theme-name=Breeze-Dark
gtk-icon-theme-name=breeze-dark
gtk-font-name=Noto Sans 10
gtk-cursor-theme-name=breeze_cursors
gtk-application-prefer-dark-theme=true
EOF

cat > "$SKEL/.config/gtk-4.0/settings.ini" << 'EOF'
[Settings]
gtk-theme-name=Breeze-Dark
gtk-icon-theme-name=breeze-dark
gtk-font-name=Noto Sans 10
gtk-cursor-theme-name=breeze_cursors
gtk-application-prefer-dark-theme=true
EOF

# --- Copy skel to existing user home directories ---
for homedir in "$TARGET"/home/*; do
    [ -d "$homedir" ] || continue
    username=$(basename "$homedir")
    cp -rn "$SKEL/.config" "$homedir/" 2>/dev/null || true
    cp -rn "$SKEL/.local" "$homedir/" 2>/dev/null || true
    # Fix ownership
    in-target chown -R "$username:$username" "/home/$username/.config" "/home/$username/.local" 2>/dev/null || true
done

# --- Gaia apply-config script (first-login wallpaper enforcement) ---
cat > "$TARGET/usr/local/bin/gaia-apply-config.sh" << 'APPLYEOF'
#!/bin/bash
MARKER="$HOME/.gaia-configured"
[ -f "$MARKER" ] && exit 0

mkdir -p "$HOME/.config" "$HOME/.local/share/konsole"
cp -rn /etc/skel/.config/* "$HOME/.config/" 2>/dev/null || true
cp -rn /etc/skel/.local/share/konsole/* "$HOME/.local/share/konsole/" 2>/dev/null || true

IS_VM=false
if systemd-detect-virt -q 2>/dev/null; then
    IS_VM=true
fi
if [ "$IS_VM" = true ]; then
    kwriteconfig6 --file kwinrc --group Compositing --key Enabled false 2>/dev/null || true
    kwriteconfig6 --file kdeglobals --group KDE --key AnimationDurationFactor 0 2>/dev/null || true
    kwriteconfig6 --file kwinrc --group Compositing --key Backend XRender 2>/dev/null || true
fi

balooctl6 disable 2>/dev/null || balooctl disable 2>/dev/null || true
killall baloo_file 2>/dev/null || true

if command -v plasma-apply-wallpaperimage &> /dev/null; then
    plasma-apply-wallpaperimage /usr/share/backgrounds/gaia/wallpaper.png 2>/dev/null || true
fi
if command -v plasma-apply-lookandfeel &> /dev/null; then
    plasma-apply-lookandfeel --apply org.kde.breezedark.desktop 2>/dev/null || true
fi
if command -v plasma-apply-colorscheme &> /dev/null; then
    plasma-apply-colorscheme BreezeDark 2>/dev/null || true
fi

if [ -f "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" ]; then
    sed -i 's|Image=.*|Image=file:///usr/share/backgrounds/gaia/wallpaper.png|g' "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" 2>/dev/null || true
fi

touch "$MARKER"
APPLYEOF
chmod +x "$TARGET/usr/local/bin/gaia-apply-config.sh"

# Autostart for apply-config
mkdir -p "$TARGET/etc/xdg/autostart"
cat > "$TARGET/etc/xdg/autostart/gaia-apply-config.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Gaia Config
Exec=/usr/local/bin/gaia-apply-config.sh
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
X-KDE-autostart-phase=2
EOF

# --- Gaia logo ---
# Try to copy logo from ISO
for src in \
    /cdrom/usr/share/pixmaps/gaia-logo.png \
    /run/live/medium/usr/share/pixmaps/gaia-logo.png \
    /usr/share/pixmaps/gaia-logo.png; do
    if [ -f "$src" ]; then
        cp "$src" "$TARGET/usr/share/pixmaps/gaia-logo.png" || true
        cp "$src" "$TARGET/usr/share/pixmaps/distributor-logo.png" || true
        for size in 16 22 24 32 48 64 128 256; do
            ICON_DIR="$TARGET/usr/share/icons/hicolor/${size}x${size}/apps"
            mkdir -p "$ICON_DIR"
            cp "$src" "$ICON_DIR/distributor-logo.png" 2>/dev/null || true
            cp "$src" "$ICON_DIR/start-here-kde.png" 2>/dev/null || true
        done
        break
    fi
done

# --- GRUB Theme ---
mkdir -p "$TARGET/boot/grub/themes/gaia"
for src in /cdrom/boot/grub/themes/gaia /run/live/medium/boot/grub/themes/gaia; do
    if [ -d "$src" ]; then
        cp "$src"/* "$TARGET/boot/grub/themes/gaia/" 2>/dev/null || true
        break
    fi
done

sed -i '/GRUB_THEME/d' "$TARGET/etc/default/grub" 2>/dev/null || true
sed -i '/GRUB_DISTRIBUTOR/d' "$TARGET/etc/default/grub" 2>/dev/null || true
cat >> "$TARGET/etc/default/grub" << 'EOF'
GRUB_DISTRIBUTOR="Gaia Linux"
GRUB_THEME=/boot/grub/themes/gaia/theme.txt
GRUB_TIMEOUT=3
GRUB_GFXMODE=auto
GRUB_GFXPAYLOAD_LINUX=keep
EOF
in-target update-grub || true

# --- Performance tuning ---
mkdir -p "$TARGET/etc/systemd/system.conf.d"
cat > "$TARGET/etc/systemd/system.conf.d/gaia-performance.conf" << 'EOF'
[Manager]
DefaultTimeoutStartSec=10s
DefaultTimeoutStopSec=10s
DefaultDeviceTimeoutSec=10s
EOF

mkdir -p "$TARGET/etc/systemd/logind.conf.d"
cat > "$TARGET/etc/systemd/logind.conf.d/gaia.conf" << 'EOF'
[Login]
InhibitDelayMaxSec=5
EOF

cat > "$TARGET/etc/sysctl.d/99-gaia-performance.conf" << 'EOF'
vm.swappiness=10
vm.dirty_ratio=10
vm.dirty_background_ratio=5
vm.vfs_cache_pressure=50
kernel.sysrq=0
EOF

# Journald limits
mkdir -p "$TARGET/etc/systemd/journald.conf.d"
cat > "$TARGET/etc/systemd/journald.conf.d/gaia.conf" << 'EOF'
[Journal]
SystemMaxUse=100M
RuntimeMaxUse=50M
MaxFileSec=7day
EOF

# --- Cleanup installer artifacts ---
rm -f "$TARGET/usr/share/applications/gaia-installer.desktop" || true
rm -f "$TARGET/usr/share/applications/calamares.desktop" || true
rm -f "$TARGET/usr/share/applications/debian-installer-launcher.desktop" || true
rm -f "$TARGET/usr/share/applications/install-debian.desktop" || true
rm -f "$SKEL/Desktop/gaia-installer.desktop" || true
rm -f "$SKEL/Desktop/install-debian.desktop" || true
rm -f "$SKEL/Desktop/calamares.desktop" || true
for u in "$TARGET"/home/*; do
    rm -f "$u/Desktop/gaia-installer.desktop" "$u/Desktop/install-debian.desktop" "$u/Desktop/calamares.desktop" 2>/dev/null || true
done
rm -f "$TARGET/usr/local/bin/gaia-autoinstall.sh" || true
rm -f "$SKEL/.config/autostart/gaia-autoinstall.desktop" || true
in-target apt-get remove --purge -y calamares calamares-settings-debian 2>/dev/null || true
in-target apt-get autoremove -y 2>/dev/null || true

echo "=== Gaia Post-Install Branding Complete ==="
