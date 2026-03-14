#!/bin/bash
# Gaia Linux - Stage 2: Temporary Tools
# Build minimal tools needed inside chroot for native rebuild

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../toolchain/config/toolchain.conf"

echo "=== Gaia Linux Stage 2: Temporary Tools ==="

SRC="$GAIA/sources"
export PATH="$GAIA/tools/bin:$PATH"
export LC_ALL=POSIX
export MAKEFLAGS="-j${NPROC:-$(nproc)}"
export CONFIG_SITE="$GAIA/usr/share/config.site"

# Helper: extract, build, install a package with configure/make
build_pkg() {
    local name="$1" ver="$2" tarball="$3" configure_opts="$4" pre_cmd="$5"
    echo ""
    echo ">>> $name-$ver"
    cd "$SRC"
    tar xf "$tarball"
    cd "$name-$ver"
    [ -n "$pre_cmd" ] && eval "$pre_cmd"
    ./configure --prefix=/usr --host="$GAIA_TGT" --build=$(build-aux/config.guess 2>/dev/null || echo x86_64-pc-linux-gnu) $configure_opts
    make
    make DESTDIR="$GAIA" install
    cd "$SRC" && rm -rf "$name-$ver"
}

# --- M4 ---
build_pkg "m4" "$M4_VER" "m4-${M4_VER}.tar.xz" ""

# --- Ncurses ---
echo ""
echo ">>> ncurses-${NCURSES_VER}"
cd "$SRC"
tar xf "ncurses-${NCURSES_VER}.tar.gz"
cd "ncurses-${NCURSES_VER}"
# Build tic for the host first
mkdir -v build-host && cd build-host
../configure
make -C include
make -C progs tic
cd ..
./configure \
    --prefix=/usr \
    --host="$GAIA_TGT" \
    --build="$(./config.guess)" \
    --mandir=/usr/share/man \
    --with-manpage-format=normal \
    --with-shared \
    --without-normal \
    --with-cxx-shared \
    --without-debug \
    --without-ada \
    --disable-stripping \
    --enable-widec
make
make DESTDIR="$GAIA" TIC_PATH="$(pwd)/build-host/progs/tic" install
# Ensure libncurses.so links to libncursesw.so
ln -sv libncursesw.so "$GAIA/usr/lib/libncurses.so"
# Fix pkg-config
sed -e 's/^#if.*XOPEN.*$/#if 1/' -i "$GAIA/usr/include/curses.h"
cd "$SRC" && rm -rf "ncurses-${NCURSES_VER}"

# --- Bash ---
build_pkg "bash" "$BASH_VER" "bash-${BASH_VER}.tar.gz" \
    "--without-bash-malloc --disable-nls"
ln -sfv bash "$GAIA/usr/bin/sh"

# --- Coreutils ---
build_pkg "coreutils" "$COREUTILS_VER" "coreutils-${COREUTILS_VER}.tar.xz" \
    "--enable-install-program=hostname --enable-no-install-program=kill,uptime" \
    "sed -i 's|test.*nologin|true|' gnulib-tests/Makefile.in 2>/dev/null || true"

# --- Diffutils ---
build_pkg "diffutils" "$DIFFUTILS_VER" "diffutils-${DIFFUTILS_VER}.tar.xz" ""

# --- File ---
echo ""
echo ">>> file-${FILE_VER}"
cd "$SRC"
tar xf "file-${FILE_VER}.tar.gz"
cd "file-${FILE_VER}"
mkdir -v build-host && cd build-host
../configure --disable-bzlib --disable-libseccomp --disable-xzlib --disable-zlib
make
cd ..
./configure --prefix=/usr --host="$GAIA_TGT" --build="$(./config.guess)"
make FILE_COMPILE="$(pwd)/build-host/src/file"
make DESTDIR="$GAIA" install
rm -v "$GAIA/usr/lib/libmagic.la"
cd "$SRC" && rm -rf "file-${FILE_VER}"

# --- Findutils ---
build_pkg "findutils" "$FINDUTILS_VER" "findutils-${FINDUTILS_VER}.tar.xz" \
    "--localstatedir=/var/lib/locate"

# --- Gawk ---
build_pkg "gawk" "$GAWK_VER" "gawk-${GAWK_VER}.tar.xz" ""

# --- Grep ---
build_pkg "grep" "$GREP_VER" "grep-${GREP_VER}.tar.xz" ""

# --- Gzip ---
build_pkg "gzip" "$GZIP_VER" "gzip-${GZIP_VER}.tar.xz" ""

# --- Make ---
build_pkg "make" "$MAKE_VER" "make-${MAKE_VER}.tar.gz" \
    "--without-guile"

# --- Patch ---
build_pkg "patch" "$PATCH_VER" "patch-${PATCH_VER}.tar.xz" ""

# --- Sed ---
build_pkg "sed" "$SED_VER" "sed-${SED_VER}.tar.xz" ""

# --- Tar ---
build_pkg "tar" "$TAR_VER" "tar-${TAR_VER}.tar.xz" ""

# --- Xz ---
build_pkg "xz" "$XZ_VER" "xz-${XZ_VER}.tar.xz" \
    "--disable-static --docdir=/usr/share/doc/xz-${XZ_VER}"

# --- Binutils (Pass 2) ---
echo ""
echo ">>> binutils-${BINUTILS_VER} (pass 2)"
cd "$SRC"
tar xf "binutils-${BINUTILS_VER}.tar.xz"
cd "binutils-${BINUTILS_VER}"
sed '6009s/$add_dir//' -i ltmain.sh
mkdir -v build && cd build
../configure \
    --prefix=/usr \
    --build="$(../config.guess)" \
    --host="$GAIA_TGT" \
    --disable-nls \
    --enable-shared \
    --enable-gprofng=no \
    --disable-werror \
    --enable-64-bit-bfd \
    --enable-new-dtags \
    --enable-default-hash-style=gnu
make
make DESTDIR="$GAIA" install
rm -v "$GAIA"/usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes,sframe}.{a,la}
cd "$SRC" && rm -rf "binutils-${BINUTILS_VER}"

# --- GCC (Pass 2) ---
echo ""
echo ">>> gcc-${GCC_VER} (pass 2)"
cd "$SRC"
tar xf "gcc-${GCC_VER}.tar.xz"
cd "gcc-${GCC_VER}"

tar xf "$SRC/mpfr-${MPFR_VER}.tar.xz" && mv "mpfr-${MPFR_VER}" mpfr
tar xf "$SRC/gmp-${GMP_VER}.tar.xz"   && mv "gmp-${GMP_VER}"   gmp
tar xf "$SRC/mpc-${MPC_VER}.tar.gz"    && mv "mpc-${MPC_VER}"   mpc

case $(uname -m) in
    x86_64) sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64 ;;
esac

sed '/thread_header =/s/@.*@/gthr-posix.h/' \
    -i libgcc/Makefile.in libstdc++-v3/include/Makefile.in

mkdir -v build && cd build
../configure \
    --build="$(../config.guess)" \
    --host="$GAIA_TGT" \
    --target="$GAIA_TGT" \
    LDFLAGS_FOR_TARGET="-L$PWD/$GAIA_TGT/libgcc" \
    --prefix=/usr \
    --with-build-sysroot="$GAIA" \
    --enable-default-pie \
    --enable-default-ssp \
    --disable-nls \
    --disable-multilib \
    --disable-libatomic \
    --disable-libgomp \
    --disable-libquadmath \
    --disable-libsanitizer \
    --disable-libssp \
    --disable-libvtv \
    --enable-languages=c,c++
make
make DESTDIR="$GAIA" install
ln -sfv gcc "$GAIA/usr/bin/cc"
cd "$SRC" && rm -rf "gcc-${GCC_VER}"

# --- Gettext (minimal) ---
echo ""
echo ">>> gettext-${GETTEXT_VER} (minimal)"
cd "$SRC"
tar xf "gettext-${GETTEXT_VER}.tar.xz"
cd "gettext-${GETTEXT_VER}"
./configure --disable-shared
make
cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext} "$GAIA/usr/bin"
cd "$SRC" && rm -rf "gettext-${GETTEXT_VER}"

# --- Bison ---
build_pkg "bison" "$BISON_VER" "bison-${BISON_VER}.tar.xz" \
    "--docdir=/usr/share/doc/bison-${BISON_VER}"

# --- Perl (minimal) ---
echo ""
echo ">>> perl-${PERL_VER} (minimal)"
cd "$SRC"
tar xf "perl-${PERL_VER}.tar.xz"
cd "perl-${PERL_VER}"
sh Configure -des \
    -Dprefix=/usr \
    -Dvendorprefix=/usr \
    -Duseshrplib \
    -Dprivlib=/usr/lib/perl5/${PERL_VER%%.*}/core_perl \
    -Darchlib=/usr/lib/perl5/${PERL_VER%%.*}/core_perl \
    -Dsitelib=/usr/lib/perl5/${PERL_VER%%.*}/site_perl \
    -Dsitearch=/usr/lib/perl5/${PERL_VER%%.*}/site_perl \
    -Dvendorlib=/usr/lib/perl5/${PERL_VER%%.*}/vendor_perl \
    -Dvendorarch=/usr/lib/perl5/${PERL_VER%%.*}/vendor_perl
make
make DESTDIR="$GAIA" install
cd "$SRC" && rm -rf "perl-${PERL_VER}"

# --- Python (minimal) ---
echo ""
echo ">>> Python-${PYTHON_VER} (minimal)"
cd "$SRC"
tar xf "Python-${PYTHON_VER}.tar.xz"
cd "Python-${PYTHON_VER}"
./configure --prefix=/usr \
    --enable-shared \
    --without-ensurepip
make
make DESTDIR="$GAIA" install
cd "$SRC" && rm -rf "Python-${PYTHON_VER}"

# --- Texinfo ---
build_pkg "texinfo" "$TEXINFO_VER" "texinfo-${TEXINFO_VER}.tar.xz" ""

# --- Util-linux (minimal) ---
echo ""
echo ">>> util-linux-${UTIL_LINUX_VER} (minimal)"
cd "$SRC"
tar xf "util-linux-${UTIL_LINUX_VER}.tar.xz"
cd "util-linux-${UTIL_LINUX_VER}"
mkdir -pv "$GAIA/var/lib/hwclock"
./configure \
    --libdir=/usr/lib \
    --runstatedir=/run \
    --disable-chfn-chsh \
    --disable-login \
    --disable-nologin \
    --disable-su \
    --disable-setpriv \
    --disable-runuser \
    --disable-pylibmount \
    --disable-static \
    --without-python \
    --without-systemd \
    --without-systemdsystemunitdir \
    ADJTIME_PATH=/var/lib/hwclock/adjtime \
    --docdir=/usr/share/doc/util-linux-${UTIL_LINUX_VER}
make
make DESTDIR="$GAIA" install
cd "$SRC" && rm -rf "util-linux-${UTIL_LINUX_VER}"

echo ""
echo "=== Stage 2 complete ==="
echo "Temporary tools installed to: $GAIA/usr"
echo ""
echo "Next: make stage3"
