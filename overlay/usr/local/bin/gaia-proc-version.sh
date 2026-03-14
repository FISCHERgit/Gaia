#!/bin/bash
# Override /proc/version to show Gaia Linux branding
REAL_VERSION=$(cat /proc/version)
GAIA_VERSION=$(echo "$REAL_VERSION" | sed 's/Debian/Gaia Linux/g')
echo "$GAIA_VERSION" > /run/gaia-version
mount --bind /run/gaia-version /proc/version 2>/dev/null || true
