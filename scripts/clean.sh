#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"

echo "=== Cleaning Gaia Linux build ==="

if [ -d "$BUILD_DIR" ]; then
    cd "$BUILD_DIR"
    case "${1:-soft}" in
        soft)
            # Keep caches (downloaded packages), only rebuild the image
            sudo lb clean
            echo "Soft clean done. Package cache kept."
            ;;
        hard)
            # Remove everything including caches
            sudo lb clean --purge
            cd "$PROJECT_DIR"
            rm -rf "$BUILD_DIR"
            echo "Hard clean done. Everything removed."
            ;;
        *)
            echo "Usage: clean.sh [soft|hard]"
            echo "  soft (default) - keep package cache, rebuild faster"
            echo "  hard           - remove everything, full fresh build"
            exit 1
            ;;
    esac
else
    echo "No build directory found."
fi

echo "Done."
