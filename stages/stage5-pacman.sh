#!/bin/bash
# Gaia Linux - Stage 5: Package Manager (pacman)
# Build pacman + dependencies, register all existing packages

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../toolchain/config/toolchain.conf"

echo "=== Gaia Linux Stage 5: Package Manager ==="

cat > "$GAIA/tmp/build-pacman.sh" << 'CHROOTEOF'
#!/bin/bash
set -e

export HOME=/root
export TERM=xterm-256color
export PATH=/usr/bin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"

SRC="/sources"

# --- libarchive ---
echo ""
echo ">>> libarchive"
cd "$SRC" && tar xf libarchive-*.tar.xz 2>/dev/null || tar xf libarchive-*.tar.gz 2>/dev/null
cd libarchive-*/
./configure --prefix=/usr \
    --disable-static \
    --without-nettle
make && make install
cd "$SRC" && rm -rf libarchive-*/

# --- libgpg-error ---
echo ""
echo ">>> libgpg-error"
cd "$SRC" && tar xf libgpg-error-*.tar.bz2
cd libgpg-error-*/
./configure --prefix=/usr \
    --disable-static
make && make install
cd "$SRC" && rm -rf libgpg-error-*/

# --- libassuan ---
echo ""
echo ">>> libassuan"
cd "$SRC" && tar xf libassuan-*.tar.bz2
cd libassuan-*/
./configure --prefix=/usr \
    --disable-static
make && make install
cd "$SRC" && rm -rf libassuan-*/

# --- GPGME ---
echo ""
echo ">>> gpgme"
cd "$SRC" && tar xf gpgme-*.tar.bz2
cd gpgme-*/
./configure --prefix=/usr \
    --disable-static \
    --disable-gpg-test
make && make install
cd "$SRC" && rm -rf gpgme-*/

# --- Fakeroot ---
echo ""
echo ">>> fakeroot"
cd "$SRC" && tar xf fakeroot*.tar.gz
cd fakeroot-*/
./configure --prefix=/usr \
    --libdir=/usr/lib/libfakeroot \
    --disable-static \
    --with-ipc=sysv
make && make install
cd "$SRC" && rm -rf fakeroot-*/

# --- Pacman ---
echo ""
echo ">>> pacman"
cd "$SRC" && tar xf pacman-*.tar.xz
cd pacman-*/
meson setup build \
    --prefix=/usr \
    --buildtype=release \
    -Ddoc=disabled \
    -Dscriptlet-shell=/usr/bin/bash \
    -Dldconfig=/usr/bin/ldconfig
meson compile -C build
meson install -C build
cd "$SRC" && rm -rf pacman-*/

# --- Configure pacman ---
echo ""
echo "Configuring pacman..."

# pacman.conf
cat > /etc/pacman.conf << 'PACCONF'
#
# /etc/pacman.conf - Gaia Linux Package Manager Configuration
#

[options]
RootDir     = /
DBPath      = /var/lib/pacman/
CacheDir    = /var/cache/pacman/pkg/
LogFile     = /var/log/pacman.log
GPGDir      = /etc/pacman.d/gnupg/
HoldPkg     = pacman glibc systemd
Architecture = x86_64
CheckSpace
Color
ParallelDownloads = 5

SigLevel    = Optional TrustAll
LocalFileSigLevel = Optional

[gaia]
Server = file:///var/cache/gaia-repo
PACCONF

# makepkg.conf
cat > /etc/makepkg.conf << 'MKPKG'
#!/hint/bash
# Gaia Linux makepkg configuration

DLAGENTS=('file::/usr/bin/curl -qgC - -o %o %u'
          'ftp::/usr/bin/curl -qfC - --ftp-pasv --retry 3 --retry-delay 3 -o %o %u'
          'http::/usr/bin/curl -qb "" -fLC - --retry 3 --retry-delay 3 -o %o %u'
          'https::/usr/bin/curl -qb "" -fLC - --retry 3 --retry-delay 3 -o %o %u')

CARCH="x86_64"
CHOST="x86_64-gaia-linux-gnu"

CFLAGS="-march=x86-64 -mtune=generic -O2 -pipe -fno-plt -fexceptions -Wp,-D_FORTIFY_SOURCE=2 -Wformat -Werror=format-security -fstack-clash-protection -fcf-protection"
CXXFLAGS="$CFLAGS -Wp,-D_GLIBCXX_ASSERTIONS"
LDFLAGS="-Wl,-O1,--sort-common,--as-needed,-z,relro,-z,now"
LTOFLAGS="-flto=auto"
RUSTFLAGS="-C opt-level=2 -C target-cpu=x86-64"

MAKEFLAGS="-j$(nproc)"

BUILDENV=(!distcc color !ccache check !sign)
OPTIONS=(strip docs !libtool !staticlibs emptydirs zipman purge !debug lto)

INTEGRITY_CHECK=(sha256)
STRIP_BINARIES="--strip-all"
STRIP_SHARED="--strip-unneeded"
STRIP_STATIC="--strip-debug"

PKGEXT='.pkg.tar.zst'
SRCEXT='.src.tar.gz'
MKPKG

# Initialize pacman database
mkdir -p /var/lib/pacman /var/cache/pacman/pkg /var/cache/gaia-repo
pacman-key --init 2>/dev/null || true

# --- Register existing packages in pacman database ---
echo ""
echo "Registering base system packages in pacman..."

# Create a script to register packages
register_pkg() {
    local pkgname="$1" pkgver="$2"
    local tmpdir="/tmp/fakepkg-${pkgname}"
    mkdir -p "$tmpdir"

    cat > "$tmpdir/.PKGINFO" << PKGINFO
pkgname = ${pkgname}
pkgver = ${pkgver}-1
pkgdesc = Base system package
url = https://gaialinux.org
builddate = $(date +%s)
packager = Gaia Build System
size = 0
arch = x86_64
PKGINFO

    cat > "$tmpdir/.BUILDINFO" << BINFO
format = 2
pkgname = ${pkgname}
pkgver = ${pkgver}-1
pkgarch = x86_64
BINFO

    cd "$tmpdir"
    tar -czf "/var/cache/gaia-repo/${pkgname}-${pkgver}-1-x86_64.pkg.tar.zst" \
        .PKGINFO .BUILDINFO 2>/dev/null || \
    tar -czf "/var/cache/gaia-repo/${pkgname}-${pkgver}-1-x86_64.pkg.tar.gz" \
        .PKGINFO .BUILDINFO
    rm -rf "$tmpdir"
}

# Register all packages built so far
PACKAGES=(
    "linux-api-headers:$(uname -r | cut -d- -f1)"
    "glibc:2.40"
    "gcc:14.2.0"
    "binutils:2.43"
    "coreutils:9.5"
    "bash:5.2.37"
    "ncurses:6.5"
    "sed:4.9"
    "grep:3.11"
    "gawk:5.3.1"
    "findutils:4.10"
    "diffutils:3.10"
    "tar:1.35"
    "gzip:1.13"
    "xz:5.6.3"
    "zstd:1.5.6"
    "make:4.4.1"
    "patch:2.7.6"
    "m4:1.4.19"
    "bison:3.8.2"
    "gettext:0.22.5"
    "texinfo:7.1"
    "util-linux:2.40.2"
    "zlib:1.3.1"
    "openssl:3.3.2"
    "readline:8.2"
    "expat:2.6.3"
    "perl:5.40.0"
    "python:3.12.7"
    "ninja:1.12.1"
    "meson:1.5.2"
    "cmake:3.30.5"
    "pkg-config:0.29.2"
    "systemd:256"
    "dbus:1.14.10"
    "linux-gaia:6.12.8"
    "libarchive:3.7.6"
    "pacman:7.0.0"
    "fakeroot:1.36"
    "gpgme:1.23.2"
)

for entry in "${PACKAGES[@]}"; do
    IFS=: read -r name ver <<< "$entry"
    register_pkg "$name" "$ver"
done

# Generate repo database
echo ""
echo "Generating pacman repository database..."
cd /var/cache/gaia-repo
repo-add gaia.db.tar.gz *.pkg.tar.* 2>/dev/null || true

# Sync database
pacman -Sy 2>/dev/null || true

echo ""
echo "=== Pacman installation complete ==="
echo "Registered $(ls /var/cache/gaia-repo/*.pkg.tar.* 2>/dev/null | wc -l) packages"
CHROOTEOF

chmod +x "$GAIA/tmp/build-pacman.sh"

# Ensure virtual filesystems are mounted
mountpoint -q "$GAIA/dev" || mount -v --bind /dev "$GAIA/dev"
mountpoint -q "$GAIA/proc" || mount -vt proc proc "$GAIA/proc"
mountpoint -q "$GAIA/sys" || mount -vt sysfs sysfs "$GAIA/sys"
mountpoint -q "$GAIA/run" || mount -vt tmpfs tmpfs "$GAIA/run"

chroot "$GAIA" /usr/bin/env -i \
    HOME=/root \
    TERM="$TERM" \
    PATH=/usr/bin:/usr/sbin \
    MAKEFLAGS="-j${NPROC:-$(nproc)}" \
    /bin/bash /tmp/build-pacman.sh

rm -f "$GAIA/tmp/build-pacman.sh"

echo ""
echo "=== Stage 5 complete ==="
echo "Pacman installed and configured"
echo ""
echo "Next: make stage6"
