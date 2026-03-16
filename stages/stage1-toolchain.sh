#!/bin/bash
# Gaia Linux - Stage 1: Cross-Toolchain
# Builds binutils, gcc (pass 1), glibc, libstdc++ for cross-compilation

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../toolchain/config/toolchain.conf"

echo "=== Gaia Linux Stage 1: Cross-Toolchain ==="
echo "Target: $GAIA_TGT"
echo "Build root: $GAIA"
echo ""

SRC="$GAIA/sources"
TOOLS="$GAIA/tools"

export PATH="$TOOLS/bin:$PATH"
export LC_ALL=POSIX
export MAKEFLAGS="-j${NPROC:-$(nproc)}"

# --- Linux API Headers ---
echo ">>> linux-${LINUX_VER} (API headers)"
cd "$SRC"
rm -rf "linux-${LINUX_VER}"
tar xf "linux-${LINUX_VER}.tar.xz"
cd "linux-${LINUX_VER}"
make mrproper
make headers
find usr/include -type f ! -name '*.h' -delete
cp -rv usr/include "$GAIA/usr/"
cd "$SRC" && rm -rf "linux-${LINUX_VER}"

# --- Binutils (Pass 1) ---
echo ""
echo ">>> binutils-${BINUTILS_VER} (pass 1)"
cd "$SRC"
rm -rf "binutils-${BINUTILS_VER}"
tar xf "binutils-${BINUTILS_VER}.tar.xz"
cd "binutils-${BINUTILS_VER}"
mkdir -v build && cd build
../configure \
    --prefix="$TOOLS" \
    --with-sysroot="$GAIA" \
    --target="$GAIA_TGT" \
    --disable-nls \
    --enable-gprofng=no \
    --disable-werror \
    --enable-new-dtags \
    --enable-default-hash-style=gnu
make
make install
cd "$SRC" && rm -rf "binutils-${BINUTILS_VER}"

# --- GCC (Pass 1) ---
echo ""
echo ">>> gcc-${GCC_VER} (pass 1)"
cd "$SRC"
rm -rf "gcc-${GCC_VER}"
tar xf "gcc-${GCC_VER}.tar.xz"
cd "gcc-${GCC_VER}"

# Extract GCC dependencies
tar xf "$SRC/mpfr-${MPFR_VER}.tar.xz" && mv "mpfr-${MPFR_VER}" mpfr
tar xf "$SRC/gmp-${GMP_VER}.tar.xz"   && mv "gmp-${GMP_VER}"   gmp
tar xf "$SRC/mpc-${MPC_VER}.tar.gz"    && mv "mpc-${MPC_VER}"   mpc

# On x86_64, set the default directory name for 64-bit libraries to "lib"
case $(uname -m) in
    x86_64) sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64 ;;
esac

mkdir -v build && cd build
../configure \
    --target="$GAIA_TGT" \
    --prefix="$TOOLS" \
    --with-glibc-version="${GLIBC_VER}" \
    --with-sysroot="$GAIA" \
    --with-newlib \
    --without-headers \
    --enable-default-pie \
    --enable-default-ssp \
    --disable-nls \
    --disable-shared \
    --disable-multilib \
    --disable-threads \
    --disable-libatomic \
    --disable-libgomp \
    --disable-libquadmath \
    --disable-libssp \
    --disable-libvtv \
    --disable-libstdcxx \
    --enable-languages=c,c++
make
make install

# Create a full version of the internal header (limits.h)
cd ..
cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
    "$(dirname $("$GAIA_TGT-gcc" -print-libgcc-file-name))/include/limits.h"

# Create a libgcc_s.so linker script so glibc can link against it
# (GCC pass 1 is built with --disable-shared, so no real libgcc_s exists yet)
LIBGCC_DIR="$(dirname $("$GAIA_TGT-gcc" -print-libgcc-file-name))"
echo "/* GNU ld script */ GROUP ( libgcc.a )" > "$LIBGCC_DIR/libgcc_s.so"
echo "  Created temporary libgcc_s.so linker script"

cd "$SRC" && rm -rf "gcc-${GCC_VER}"

# --- Glibc ---
echo ""
echo ">>> glibc-${GLIBC_VER}"
cd "$SRC"
rm -rf "glibc-${GLIBC_VER}"
tar xf "glibc-${GLIBC_VER}.tar.xz"
cd "glibc-${GLIBC_VER}"

# Ensure ldconfig and sln are installed into /usr/sbin
case $(uname -m) in
    x86_64) ln -sfv ../lib/ld-linux-x86-64.so.2 "$GAIA/lib64"
            ln -sfv ../lib/ld-linux-x86-64.so.2 "$GAIA/lib64/ld-lsb-x86-64.so.3" ;;
esac

mkdir -v build && cd build
echo "rootsbindir=/usr/sbin" > configparms
../configure \
    --prefix=/usr \
    --host="$GAIA_TGT" \
    --build="$(../scripts/config.guess)" \
    --enable-kernel=4.19 \
    --with-headers="$GAIA/usr/include" \
    --disable-nscd \
    libc_cv_slibdir=/usr/lib
make
make DESTDIR="$GAIA" install

# Fix for ldd
sed '/RTLDLIST=/s@/usr@@g' -i "$GAIA/usr/bin/ldd"

# Sanity check
echo 'int main(){}' | "$GAIA_TGT-gcc" -xc -
readelf -l a.out | grep -q "ld-linux" && echo "  Toolchain sanity check: PASSED" || {
    echo "  ERROR: Toolchain sanity check FAILED"
    exit 1
}
rm -v a.out

cd "$SRC" && rm -rf "glibc-${GLIBC_VER}"

# --- libstdc++ (from GCC source, pass 1) ---
echo ""
echo ">>> libstdc++ (pass 1)"
cd "$SRC"
rm -rf "gcc-${GCC_VER}"
tar xf "gcc-${GCC_VER}.tar.xz"
cd "gcc-${GCC_VER}"
mkdir -v build && cd build
../libstdc++-v3/configure \
    --host="$GAIA_TGT" \
    --build="$(../config.guess)" \
    --prefix=/usr \
    --disable-multilib \
    --disable-nls \
    --disable-libstdcxx-pch \
    --with-gxx-include-dir="/tools/$GAIA_TGT/include/c++/${GCC_VER}"
make
make DESTDIR="$GAIA" install

# Remove libtool archives (not needed, can cause problems)
rm -v "$GAIA"/usr/lib/lib{stdc++{,exp,fs},supc++}.la

cd "$SRC" && rm -rf "gcc-${GCC_VER}"

echo ""
echo "=== Stage 1 complete ==="
echo "Cross-toolchain installed to: $TOOLS"
echo ""
echo "Next: make stage2"
