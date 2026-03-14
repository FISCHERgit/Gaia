#!/bin/bash
# Gaia Linux - Download pre-built binaries for heavy packages
# This dramatically reduces build time by skipping LLVM and Qt6 compilation

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../toolchain/config/toolchain.conf"

SRC="$GAIA/sources"
mkdir -p "$SRC/binaries"

echo "=== Downloading pre-built binaries ==="
echo "This saves 4-7 hours of compilation time."
echo ""

download() {
    local url="$1" dest="$2"
    local filename="$(basename "$url")"
    [ -n "$dest" ] && filename="$dest"
    if [ -f "$SRC/binaries/$filename" ]; then
        echo "  Already have: $filename"
    else
        echo "  Downloading: $filename"
        wget -q --show-progress "$url" -O "$SRC/binaries/$filename" || {
            echo "  FAILED: $url"
            return 1
        }
    fi
}

# --- LLVM (pre-built, saves 2-3 hours) ---
# Official LLVM release binaries for x86_64 Linux
LLVM_BIN_VER="18.1.8"
echo ">>> LLVM ${LLVM_BIN_VER} (pre-built)"
download "https://github.com/llvm/llvm-project/releases/download/llvmorg-${LLVM_BIN_VER}/clang+llvm-${LLVM_BIN_VER}-x86_64-linux-gnu-ubuntu-18.04.tar.xz" \
    "llvm-${LLVM_BIN_VER}-bin.tar.xz"

# --- Qt6 (pre-built, saves 2-4 hours) ---
# We use the official Qt online installer binaries
# Alternative: build Qt6 once, cache the result
echo ""
echo ">>> Qt6 ${QT6_VER} — will use cached build or source"
echo "  (Qt6 binary download requires Qt account; using source + ccache instead)"

echo ""
echo "=== Binary downloads complete ==="
echo ""
echo "To use: set GAIA_USE_LLVM_BINARY=1 before running make stage6"
