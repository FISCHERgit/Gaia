#!/bin/bash
# Launch Calamares automatically if booted with "autoinstall" parameter
if grep -q "autoinstall" /proc/cmdline; then
    sleep 3
    pkexec calamares
fi
