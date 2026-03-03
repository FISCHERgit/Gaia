#!/bin/bash
# Launch Calamares automatically if booted with "autoinstall" parameter
if grep -q "autoinstall" /proc/cmdline; then
    # Wait for desktop to be ready
    sleep 1

    # Set a plain dark background (hide desktop icons)
    xfconf-query -c xfce4-desktop -p /desktop-icons/style -s 0 2>/dev/null || true
    xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorscreen/workspace0/color-style -s 0 2>/dev/null || true
    xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorscreen/workspace0/image-style -s 0 2>/dev/null || true

    # Hide panels
    xfconf-query -c xfce4-panel -p /panels/panel-1/autohide-behavior -s 2 2>/dev/null || true
    xfconf-query -c xfce4-panel -p /panels/panel-2/autohide-behavior -s 2 2>/dev/null || true

    # Launch Calamares maximized
    pkexec calamares &
    CALA_PID=$!

    # Wait for Calamares window and maximize it
    sleep 2
    wmctrl -r "Gaia" -b add,maximized_vert,maximized_horz 2>/dev/null || true
    wmctrl -r "Install" -b add,maximized_vert,maximized_horz 2>/dev/null || true
    wmctrl -r "Calamares" -b add,maximized_vert,maximized_horz 2>/dev/null || true

    # When Calamares closes, reboot if installation was successful
    wait $CALA_PID
fi
