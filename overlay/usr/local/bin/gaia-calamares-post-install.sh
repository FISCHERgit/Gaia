#!/bin/bash
# Called by Calamares shellprocess module after user creation
# Ensures Gaia wallpaper, theme, and macOS-style dock are applied

echo "=== Gaia post-install: applying desktop customization ==="

# Find the first non-root user created by the installer
TARGET_USER=""
TARGET_HOME=""
for homedir in /home/*; do
    [ -d "$homedir" ] || continue
    u="$(basename "$homedir")"
    [ "$u" = "user" ] && continue  # skip live user
    TARGET_USER="$u"
    TARGET_HOME="$homedir"
    break
done

# Fallback
if [ -z "$TARGET_USER" ]; then
    for homedir in /home/*; do
        [ -d "$homedir" ] || continue
        TARGET_USER="$(basename "$homedir")"
        TARGET_HOME="$homedir"
        break
    done
fi

[ -z "$TARGET_USER" ] && { echo "No user found, skipping"; exit 0; }

echo "Applying Gaia configs for user: $TARGET_USER ($TARGET_HOME)"

# Force-copy ALL skel configs (overwrite any Plasma defaults)
mkdir -p "$TARGET_HOME/.config"
mkdir -p "$TARGET_HOME/.local/share/konsole"
cp -rf /etc/skel/.config/* "$TARGET_HOME/.config/" 2>/dev/null || true
cp -rf /etc/skel/.local/share/konsole/* "$TARGET_HOME/.local/share/konsole/" 2>/dev/null || true

# Also copy Desktop directory (minus installer shortcut)
mkdir -p "$TARGET_HOME/Desktop"
for f in /etc/skel/Desktop/*; do
    [ -f "$f" ] || continue
    case "$(basename "$f")" in
        *installer*) continue ;;
        *) cp -f "$f" "$TARGET_HOME/Desktop/" 2>/dev/null || true ;;
    esac
done

# Fix ownership
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.config" "$TARGET_HOME/.local" "$TARGET_HOME/Desktop" 2>/dev/null || true

# Remove SDDM autologin (was for live session only)
rm -f /etc/sddm.conf.d/gaia.conf
cat > /etc/sddm.conf.d/gaia.conf << 'SDDMEOF'
[Theme]
Current=breeze

[General]
InputMethod=
SDDMEOF

# Ensure wallpaper file exists
if [ ! -f /usr/share/backgrounds/gaia/wallpaper.png ]; then
    echo "WARNING: Gaia wallpaper missing!"
fi

# Mark as configured
touch "$TARGET_HOME/.gaia-configured"
chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.gaia-configured"

echo "=== Gaia post-install complete ==="
