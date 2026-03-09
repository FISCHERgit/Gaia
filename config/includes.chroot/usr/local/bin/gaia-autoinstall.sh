#!/bin/bash
# Launch Calamares automatically if booted with "autoinstall" parameter
if grep -q "autoinstall" /proc/cmdline; then
    # Wait for Plasma desktop to be ready
    sleep 2

    # Launch Calamares maximized
    pkexec calamares &
    CALA_PID=$!

    # Wait for Calamares window and maximize it
    sleep 3
    wmctrl -r "Gaia" -b add,maximized_vert,maximized_horz 2>/dev/null || true
    wmctrl -r "Install" -b add,maximized_vert,maximized_horz 2>/dev/null || true
    wmctrl -r "Calamares" -b add,maximized_vert,maximized_horz 2>/dev/null || true

    # When Calamares closes, reboot if installation was successful
    wait $CALA_PID
fi
