#!/bin/bash
# Remove installer shortcuts from desktop and application menu
# Only runs on installed system (ConditionKernelCommandLine in service ensures this)

# Remove installer .desktop files from all user desktops
for homedir in /home/*; do
    [ -d "$homedir/Desktop" ] || continue
    rm -f "$homedir/Desktop/gaia-installer.desktop"
    rm -f "$homedir/Desktop/calamares.desktop"
done
rm -f /root/Desktop/gaia-installer.desktop

# Remove from /etc/skel so new users don't get installer icons
rm -f /etc/skel/Desktop/gaia-installer.desktop

# Remove from application menu
rm -f /usr/share/applications/gaia-installer.desktop
rm -f /usr/share/applications/calamares.desktop

# Remove autoinstall script and autostart
rm -f /usr/local/bin/gaia-autoinstall.sh
rm -f /etc/xdg/autostart/gaia-autoinstall.desktop
rm -f /etc/skel/.config/autostart/gaia-autoinstall.desktop
for homedir in /home/*; do
    rm -f "$homedir/.config/autostart/gaia-autoinstall.desktop" 2>/dev/null
done

# Uninstall Calamares (not needed after installation)
if pacman -Q calamares &>/dev/null 2>&1; then
    pacman -Rns --noconfirm calamares 2>/dev/null || true
fi

# Self-destruct: disable and remove this service
systemctl disable gaia-post-install-cleanup.service 2>/dev/null || true
rm -f /etc/systemd/system/gaia-post-install-cleanup.service
rm -f /usr/local/bin/gaia-post-install-cleanup.sh
