#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"

echo "=== Cleaning Gaia Linux build ==="

if [ -d "$BUILD_DIR" ]; then
    cd "$BUILD_DIR"
    sudo lb clean --purge 2>/dev/null || true
    cd "$PROJECT_DIR"
    rm -rf "$BUILD_DIR"
    echo "Build directory removed."
else
    echo "No build directory found."
fi

echo "Done."
