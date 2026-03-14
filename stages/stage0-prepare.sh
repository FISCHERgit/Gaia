#!/bin/bash
# Gaia Linux - Stage 0: Host Preparation
# Validates host system, creates directory structure, downloads sources

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../toolchain/config/toolchain.conf"

echo "=== Gaia Linux Stage 0: Host Preparation ==="
echo "Build root: $GAIA"
echo ""

# --- Check running as root ---
if [ "$EUID" -ne 0 ]; then
    echo "Error: Build must run as root (sudo)."
    exit 1
fi

# --- Check host architecture ---
if [ "$(uname -m)" != "x86_64" ]; then
    echo "Error: Host must be x86_64."
    exit 1
fi

# --- Check required host tools ---
echo "Checking host tools..."
MISSING=""
for cmd in bash gcc g++ ld make bison gawk m4 tar xz wget git patch sed grep \
           gzip bzip2 python3 perl diff find xargs chown chmod; do
    if ! command -v "$cmd" &>/dev/null; then
        MISSING="$MISSING $cmd"
    fi
done

if [ -n "$MISSING" ]; then
    echo "Error: Missing required tools:$MISSING"
    echo "Install them with your distro's package manager."
    exit 1
fi

# Check versions
BASH_MAJOR=$(bash --version | head -1 | grep -oP '\d+\.\d+' | head -1)
GCC_MAJOR=$(gcc -dumpversion | cut -d. -f1)
echo "  bash: $BASH_MAJOR"
echo "  gcc:  $GCC_MAJOR"

if [ "$GCC_MAJOR" -lt 12 ]; then
    echo "Warning: GCC $GCC_MAJOR detected. GCC 12+ recommended."
fi

echo "  All tools OK"

# --- Check disk space ---
AVAIL_GB=$(df --output=avail -BG "${GAIA%/*}" 2>/dev/null | tail -1 | tr -d ' G')
echo ""
echo "Available disk space: ${AVAIL_GB}G"
if [ "$AVAIL_GB" -lt 40 ]; then
    echo "Warning: Less than 40G available. Full build needs ~50G."
fi

# --- Create directory structure ---
echo ""
echo "Creating build directories..."
mkdir -pv "$GAIA"/{sources,tools,build}
mkdir -pv "$GAIA"/{bin,boot,dev,etc,home,lib,lib64,media,mnt,opt,proc}
mkdir -pv "$GAIA"/{root,run,sbin,srv,sys,tmp,usr,var}
mkdir -pv "$GAIA"/usr/{bin,include,lib,libexec,sbin,share,src}
mkdir -pv "$GAIA"/usr/share/{doc,info,locale,man,misc,terminfo,zoneinfo}
mkdir -pv "$GAIA"/usr/share/man/man{1..8}
mkdir -pv "$GAIA"/var/{cache,lib,local,log,opt,run,spool,tmp}
install -dv -m 1777 "$GAIA"/tmp "$GAIA"/var/tmp

# Symlinks for merged /usr
ln -sfv usr/bin  "$GAIA"/bin   2>/dev/null || true
ln -sfv usr/lib  "$GAIA"/lib   2>/dev/null || true
ln -sfv usr/lib  "$GAIA"/lib64 2>/dev/null || true
ln -sfv usr/sbin "$GAIA"/sbin  2>/dev/null || true

# --- Create gaia build user ---
if ! id gaia &>/dev/null; then
    groupadd -f gaia
    useradd -s /bin/bash -g gaia -m -k /dev/null gaia 2>/dev/null || true
fi
chown -v gaia:gaia "$GAIA"/tools "$GAIA"/sources

# --- Download source tarballs ---
echo ""
echo "=== Downloading source tarballs ==="
cd "$GAIA/sources"

# Use aria2c for parallel downloads if available (5-10x faster)
if command -v aria2c &>/dev/null; then
    DOWNLOADER="aria2"
    echo "  Using aria2c (parallel downloads)"
else
    DOWNLOADER="wget"
    echo "  Using wget (install aria2 for faster downloads: apt install aria2)"
fi

# Collect URLs for batch download with aria2
DOWNLOAD_LIST="$GAIA/sources/.download-list.txt"
> "$DOWNLOAD_LIST"

download() {
    local url="$1"
    local filename="${2:-$(basename "$url")}"
    if [ -f "$filename" ]; then
        return 0
    fi
    if [ "$DOWNLOADER" = "aria2" ]; then
        echo "$url" >> "$DOWNLOAD_LIST"
        echo "  out=$filename" >> "$DOWNLOAD_LIST"
    else
        echo "  Downloading: $filename"
        wget -q --show-progress "$url" -O "$filename" || {
            echo "  FAILED: $url"
            return 1
        }
    fi
}

# Flush all queued downloads via aria2 at end of section
flush_downloads() {
    if [ "$DOWNLOADER" = "aria2" ] && [ -s "$DOWNLOAD_LIST" ]; then
        local count=$(grep -c '^http' "$DOWNLOAD_LIST")
        echo ""
        echo "  Downloading $count files with aria2 (16 parallel connections)..."
        aria2c --input-file="$DOWNLOAD_LIST" \
            --dir="$GAIA/sources" \
            --max-concurrent-downloads=16 \
            --max-connection-per-server=4 \
            --min-split-size=1M \
            --continue=true \
            --auto-file-renaming=false \
            --console-log-level=warn \
            --summary-interval=10 || true
        > "$DOWNLOAD_LIST"
    fi
}

# ccache binary (for build acceleration)
download "https://github.com/ccache/ccache/releases/download/v4.10.2/ccache-4.10.2-linux-x86_64.tar.xz"

# Toolchain
download "$GNU_MIRROR/binutils/binutils-${BINUTILS_VER}.tar.xz"
download "$GNU_MIRROR/gcc/gcc-${GCC_VER}/gcc-${GCC_VER}.tar.xz"
download "$GNU_MIRROR/glibc/glibc-${GLIBC_VER}.tar.xz"
download "$KERNEL_MIRROR/v6.x/linux-${LINUX_VER}.tar.xz"
download "$GNU_MIRROR/mpfr/mpfr-${MPFR_VER}.tar.xz"
download "$GNU_MIRROR/gmp/gmp-${GMP_VER}.tar.xz"
download "$GNU_MIRROR/mpc/mpc-${MPC_VER}.tar.gz"

# Core utilities
download "$GNU_MIRROR/m4/m4-${M4_VER}.tar.xz"
download "$GNU_MIRROR/ncurses/ncurses-${NCURSES_VER}.tar.gz"
download "$GNU_MIRROR/bash/bash-${BASH_VER}.tar.gz"
download "$GNU_MIRROR/coreutils/coreutils-${COREUTILS_VER}.tar.xz"
download "$GNU_MIRROR/diffutils/diffutils-${DIFFUTILS_VER}.tar.xz"
download "https://astron.com/pub/file/file-${FILE_VER}.tar.gz"
download "$GNU_MIRROR/findutils/findutils-${FINDUTILS_VER}.tar.xz"
download "$GNU_MIRROR/gawk/gawk-${GAWK_VER}.tar.xz"
download "$GNU_MIRROR/grep/grep-${GREP_VER}.tar.xz"
download "$GNU_MIRROR/gzip/gzip-${GZIP_VER}.tar.xz"
download "$GNU_MIRROR/make/make-${MAKE_VER}.tar.gz"
download "$GNU_MIRROR/patch/patch-${PATCH_VER}.tar.xz"
download "$GNU_MIRROR/sed/sed-${SED_VER}.tar.xz"
download "$GNU_MIRROR/tar/tar-${TAR_VER}.tar.xz"
download "https://github.com/tukaani-project/xz/releases/download/v${XZ_VER}/xz-${XZ_VER}.tar.xz"
download "$GITHUB/facebook/zstd/releases/download/v${ZSTD_VER}/zstd-${ZSTD_VER}.tar.gz"
download "$GNU_MIRROR/gettext/gettext-${GETTEXT_VER}.tar.xz"
download "$GNU_MIRROR/bison/bison-${BISON_VER}.tar.xz"
download "https://www.cpan.org/src/5.0/perl-${PERL_VER}.tar.xz"
download "https://www.python.org/ftp/python/${PYTHON_VER}/Python-${PYTHON_VER}.tar.xz"
download "$GNU_MIRROR/texinfo/texinfo-${TEXINFO_VER}.tar.xz"
download "$KERNEL_MIRROR/utils/util-linux/v${UTIL_LINUX_VER%.*}/util-linux-${UTIL_LINUX_VER}.tar.xz"

# Libraries
download "https://zlib.net/zlib-${ZLIB_VER}.tar.xz"
download "$GITHUB/libffi/libffi/releases/download/v${LIBFFI_VER}/libffi-${LIBFFI_VER}.tar.gz"
download "https://www.openssl.org/source/openssl-${OPENSSL_VER}.tar.gz"
download "$GNU_MIRROR/readline/readline-${READLINE_VER}.tar.gz"
download "$GITHUB/libexpat/libexpat/releases/download/R_${EXPAT_VER//./_}/expat-${EXPAT_VER}.tar.xz"

# System
download "$GITHUB/systemd/systemd/archive/v${SYSTEMD_VER}/systemd-${SYSTEMD_VER}.tar.gz"
download "https://dbus.freedesktop.org/releases/dbus/dbus-${DBUS_VER}.tar.xz"

# Build tools
download "https://pkg-config.freedesktop.org/releases/pkg-config-${PKG_CONFIG_VER}.tar.gz"
download "https://cmake.org/files/v${CMAKE_VER%.*}/cmake-${CMAKE_VER}.tar.gz"
download "$GITHUB/mesonbuild/meson/releases/download/${MESON_VER}/meson-${MESON_VER}.tar.gz"
download "$GITHUB/ninja-build/ninja/archive/v${NINJA_VER}/ninja-${NINJA_VER}.tar.gz"

# Pacman
download "https://gitlab.archlinux.org/pacman/pacman/-/releases/v${PACMAN_VER}/downloads/pacman-${PACMAN_VER}.tar.xz"
download "https://deb.debian.org/debian/pool/main/f/fakeroot/fakeroot_${FAKEROOT_VER}.orig.tar.gz"
download "https://gnupg.org/ftp/gcrypt/gpgme/gpgme-${GPGME_VER}.tar.bz2"
download "https://gnupg.org/ftp/gcrypt/libgpg-error/libgpg-error-${LIBGPG_ERROR_VER}.tar.bz2"
download "https://gnupg.org/ftp/gcrypt/libassuan/libassuan-${LIBASSUAN_VER}.tar.bz2"

# Additional base system packages
download "$GNU_MIRROR/autoconf/autoconf-${AUTOCONF_VER}.tar.xz"
download "$GNU_MIRROR/automake/automake-${AUTOMAKE_VER}.tar.xz"
download "$GNU_MIRROR/libtool/libtool-${LIBTOOL_VER}.tar.xz"
download "$GITHUB/shadow-maint/shadow/releases/download/${SHADOW_VER}/shadow-${SHADOW_VER}.tar.xz"
download "https://www.sudo.ws/dist/sudo-${SUDO_VER}.tar.gz"
download "$GNU_MIRROR/nano/nano-${NANO_VER}.tar.xz"
download "$SOURCEFORGE/zsh/zsh/${ZSH_VER}/zsh-${ZSH_VER}.tar.xz"
download "$GNU_MIRROR/less/less-${LESS_VER}.tar.gz"
download "$GNU_MIRROR/inetutils/inetutils-3.5.tar.xz" 2>/dev/null || true
download "$GITHUB/besser82/libxcrypt/releases/download/v4.4.36/libxcrypt-4.4.36.tar.xz"
download "https://www.kernel.org/pub/linux/libs/security/linux-privs/libcap2/libcap-2.70.tar.xz"
download "https://download.savannah.gnu.org/releases/attr/attr-2.5.2.tar.xz"
download "https://download.savannah.gnu.org/releases/acl/acl-2.3.2.tar.xz"
download "$GNU_MIRROR/bc/bc-6.7.6.tar.xz" 2>/dev/null || true
download "$GITHUB/westes/flex/releases/download/v2.6.4/flex-2.6.4.tar.gz"
download "$GNU_MIRROR/gdbm/gdbm-1.24.tar.gz"
download "$GNU_MIRROR/gperf/gperf-3.1.tar.gz"
download "$GITHUB/kmod-project/kmod/releases/download/v${KMOD_VER}/kmod-${KMOD_VER}.tar.xz"
download "$GITHUB/procps-ng/procps/releases/download/v${PROCPS_VER}/procps-ng-${PROCPS_VER}.tar.xz"
download "$KERNEL_MIRROR/utils/net/iproute2/iproute2-${IPROUTE2_VER}.tar.xz"
download "$GNU_MIRROR/kbd/kbd-2.6.4.tar.xz" 2>/dev/null || true
download "https://download.savannah.nongnu.org/releases/man-db/man-db-2.12.1.tar.xz" 2>/dev/null || true
download "$KERNEL_MIRROR/docs/man-pages/man-pages-6.9.1.tar.xz" 2>/dev/null || true
download "https://download.savannah.gnu.org/releases/libpipeline/libpipeline-1.5.7.tar.gz"
download "$GNU_MIRROR/psmisc/psmisc-23.7.tar.xz"
download "$GNU_MIRROR/which/which-2.21.tar.gz" 2>/dev/null || true

# Filesystem tools
download "$SOURCEFORGE/e2fsprogs/e2fsprogs/v${E2FSPROGS_VER}/e2fsprogs-${E2FSPROGS_VER}.tar.gz"
download "$KERNEL_MIRROR/utils/fs/btrfs-progs/btrfs-progs-v${BTRFS_PROGS_VER}.tar.xz"
download "$GITHUB/dosfstools/dosfstools/releases/download/v${DOSFSTOOLS_VER}/dosfstools-${DOSFSTOOLS_VER}.tar.gz"
download "$GITHUB/plougher/squashfs-tools/archive/refs/tags/${SQUASHFS_TOOLS_VER}/squashfs-tools-${SQUASHFS_TOOLS_VER}.tar.gz"

# Bootloader
download "$GNU_MIRROR/grub/grub-${GRUB_VER}.tar.xz"
download "$GITHUB/rhboot/efibootmgr/archive/refs/tags/${EFIBOOTMGR_VER}/efibootmgr-${EFIBOOTMGR_VER}.tar.gz"
download "$GITHUB/rhboot/efivar/releases/download/39/efivar-39.tar.bz2"

# Networking
download "https://curl.se/download/curl-${CURL_VER}.tar.xz"
download "$GNU_MIRROR/wget/wget-${WGET_VER}.tar.gz"
download "$GITHUB/git/git/archive/refs/tags/v${GIT_VER}/git-${GIT_VER}.tar.gz"
download "$GITHUB/NetworkManager/NetworkManager/archive/refs/tags/${NETWORKMANAGER_VER}/NetworkManager-${NETWORKMANAGER_VER}.tar.gz"

# Libarchive (pacman dependency)
download "$GITHUB/libarchive/libarchive/releases/download/v${LIBARCHIVE_VER}/libarchive-${LIBARCHIVE_VER}.tar.xz"

# ============================================
# Desktop: Graphics Foundation
# ============================================
echo ""
echo "--- Desktop: Graphics ---"

download "https://dri.freedesktop.org/libdrm/libdrm-${LIBDRM_VER}.tar.xz"
download "https://gitlab.freedesktop.org/wayland/wayland/-/releases/${WAYLAND_VER}/downloads/wayland-${WAYLAND_VER}.tar.xz"
download "https://gitlab.freedesktop.org/wayland/wayland-protocols/-/releases/${WAYLAND_PROTOCOLS_VER}/downloads/wayland-protocols-${WAYLAND_PROTOCOLS_VER}.tar.xz"
download "https://archive.mesa3d.org/mesa-${MESA_VER}.tar.xz"
download "https://xkbcommon.org/download/libxkbcommon-${LIBXKBCOMMON_VER}.tar.xz"
download "https://gitlab.freedesktop.org/libinput/libinput/-/releases/${LIBINPUT_VER}/downloads/libinput-${LIBINPUT_VER}.tar.bz2"

# Xorg dependencies (proto, libs, server)
XORG_MIRROR="https://www.x.org/releases/individual"
download "$XORG_MIRROR/util/util-macros-1.20.1.tar.xz"
download "$XORG_MIRROR/proto/xorgproto-2024.1.tar.xz"
download "$XORG_MIRROR/lib/libXau-1.0.11.tar.xz"
download "$XORG_MIRROR/lib/libXdmcp-1.1.5.tar.xz"
download "$XORG_MIRROR/lib/xtrans-1.5.0.tar.xz"
download "https://xcb.freedesktop.org/dist/libxcb-1.17.0.tar.xz"
download "https://xcb.freedesktop.org/dist/xcb-proto-1.17.0.tar.xz"
download "$XORG_MIRROR/lib/libX11-1.8.10.tar.xz"
download "$XORG_MIRROR/lib/libXext-1.3.6.tar.xz"
download "$XORG_MIRROR/lib/libXfixes-6.0.1.tar.xz"
download "$XORG_MIRROR/lib/libXi-1.8.2.tar.xz"
download "$XORG_MIRROR/lib/libXtst-1.2.5.tar.xz"
download "$XORG_MIRROR/lib/libXrandr-1.5.4.tar.xz"
download "$XORG_MIRROR/lib/libXrender-0.9.11.tar.xz"
download "$XORG_MIRROR/lib/libXcursor-1.2.2.tar.xz"
download "$XORG_MIRROR/lib/libXcomposite-0.4.6.tar.xz"
download "$XORG_MIRROR/lib/libXdamage-1.1.6.tar.xz"
download "$XORG_MIRROR/lib/libXinerama-1.1.5.tar.xz"
download "$XORG_MIRROR/lib/libXScrnSaver-1.2.4.tar.xz"
download "$XORG_MIRROR/lib/libxshmfence-1.3.2.tar.xz"
download "$XORG_MIRROR/lib/libXxf86vm-1.1.5.tar.xz"
download "$XORG_MIRROR/lib/libICE-1.1.1.tar.xz"
download "$XORG_MIRROR/lib/libSM-1.2.4.tar.xz"
download "$XORG_MIRROR/lib/libXt-1.3.0.tar.xz"
download "$XORG_MIRROR/lib/libXmu-1.2.1.tar.xz"
download "$XORG_MIRROR/lib/libXpm-3.5.17.tar.xz"
download "$XORG_MIRROR/lib/libXaw-1.0.16.tar.xz"
download "$XORG_MIRROR/lib/libXfont2-2.0.7.tar.xz"
download "$XORG_MIRROR/lib/libxkbfile-1.1.3.tar.xz"
download "$XORG_MIRROR/lib/libpciaccess-0.18.1.tar.xz"
download "$XORG_MIRROR/lib/pixman-0.43.4.tar.gz"
download "$XORG_MIRROR/data/xkeyboard-config-2.42.tar.xz"
download "$XORG_MIRROR/font/font-util-1.4.1.tar.xz"
download "$XORG_MIRROR/server/xorg-server-${XORG_SERVER_VER}.tar.xz"
download "$XORG_MIRROR/driver/xf86-video-amdgpu-23.0.0.tar.xz"
download "$XORG_MIRROR/driver/xf86-video-intel-2.99.917.tar.bz2" 2>/dev/null || true
download "$XORG_MIRROR/driver/xf86-video-nouveau-1.0.17.tar.bz2"
download "$XORG_MIRROR/driver/xf86-input-libinput-1.4.0.tar.xz"
download "$XORG_MIRROR/app/xrandr-1.5.2.tar.xz"
download "$XORG_MIRROR/app/setxkbmap-1.3.4.tar.xz"
download "$XORG_MIRROR/app/xset-1.2.5.tar.xz"

# LLVM (needed by Mesa for llvmpipe/radeonsi)
LLVM_VER="18.1.8"
download "$GITHUB/llvm/llvm-project/releases/download/llvmorg-${LLVM_VER}/llvm-project-${LLVM_VER}.src.tar.xz"

# Additional graphics libs
download "https://gitlab.freedesktop.org/glvnd/libglvnd/-/archive/v1.7.0/libglvnd-v1.7.0.tar.gz"
download "$GITHUB/KhronosGroup/Vulkan-Headers/archive/refs/tags/v1.3.296/Vulkan-Headers-1.3.296.tar.gz"
download "$GITHUB/KhronosGroup/Vulkan-Loader/archive/refs/tags/v1.3.296/Vulkan-Loader-1.3.296.tar.gz"
download "https://github.com/KhronosGroup/OpenCL-Headers/archive/refs/tags/v2024.05.08/OpenCL-Headers-2024.05.08.tar.gz" 2>/dev/null || true

# ============================================
# Desktop: Qt6
# ============================================
echo ""
echo "--- Desktop: Qt6 ---"

QT6_BASE="https://download.qt.io/official_releases/qt/${QT6_VER%.*}/${QT6_VER}/submodules"
download "$QT6_BASE/qtbase-everywhere-src-${QT6_VER}.tar.xz"
download "$QT6_BASE/qtdeclarative-everywhere-src-${QT6_VER}.tar.xz"
download "$QT6_BASE/qtshadertools-everywhere-src-${QT6_VER}.tar.xz"
download "$QT6_BASE/qtwayland-everywhere-src-${QT6_VER}.tar.xz"
download "$QT6_BASE/qtsvg-everywhere-src-${QT6_VER}.tar.xz"
download "$QT6_BASE/qtmultimedia-everywhere-src-${QT6_VER}.tar.xz"
download "$QT6_BASE/qt5compat-everywhere-src-${QT6_VER}.tar.xz"
download "$QT6_BASE/qttools-everywhere-src-${QT6_VER}.tar.xz"
download "$QT6_BASE/qtimageformats-everywhere-src-${QT6_VER}.tar.xz"
download "$QT6_BASE/qtsensors-everywhere-src-${QT6_VER}.tar.xz" 2>/dev/null || true
download "$QT6_BASE/qtnetworkauth-everywhere-src-${QT6_VER}.tar.xz" 2>/dev/null || true
download "$QT6_BASE/qtspeech-everywhere-src-${QT6_VER}.tar.xz" 2>/dev/null || true

# Qt6 dependencies
download "https://harfbuzz.github.io/release/harfbuzz-9.0.0.tar.xz" 2>/dev/null || \
    download "$GITHUB/harfbuzz/harfbuzz/releases/download/9.0.0/harfbuzz-9.0.0.tar.xz"
download "https://download.savannah.gnu.org/releases/freetype/freetype-2.13.3.tar.xz"
download "$GITHUB/ArtifexSoftware/thirdparty-lcms2/releases/download/lcms2.16/lcms2-2.16.tar.gz" 2>/dev/null || true
download "$SOURCEFORGE/libjpeg-turbo/3.0.4/libjpeg-turbo-3.0.4.tar.gz"
download "$SOURCEFORGE/libpng/libpng16/1.6.44/libpng-1.6.44.tar.xz"
download "https://github.com/AcademySoftwareFoundation/openexr/archive/refs/tags/v3.3.1/openexr-3.3.1.tar.gz" 2>/dev/null || true
download "https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.4.0.tar.gz"
download "https://gitlab.freedesktop.org/fontconfig/fontconfig/-/archive/2.15.0/fontconfig-2.15.0.tar.gz"
download "$GITHUB/libffi/libffi/releases/download/v${LIBFFI_VER}/libffi-${LIBFFI_VER}.tar.gz" 2>/dev/null || true
download "https://www.cairographics.org/releases/cairo-1.18.2.tar.xz"
download "https://download.gnome.org/sources/pango/1.54/pango-1.54.0.tar.xz"
download "https://download.gnome.org/sources/glib/2.82/glib-2.82.2.tar.xz"
download "https://download.gnome.org/sources/gdk-pixbuf/2.42/gdk-pixbuf-2.42.12.tar.xz"
download "https://download.gnome.org/sources/shared-mime-info/2.4/shared-mime-info-2.4.tar.xz"
download "$GITHUB/libusb/libusb/releases/download/v1.0.27/libusb-1.0.27.tar.bz2"
download "https://www.freedesktop.org/software/polkit/releases/polkit-125.tar.gz"
download "$GITHUB/FreeGLUT/freeglut/releases/download/v3.6.0/freeglut-3.6.0.tar.gz" 2>/dev/null || true
download "https://download.gnome.org/sources/gobject-introspection/1.82/gobject-introspection-1.82.0.tar.xz"
download "https://freedesktop.org/software/libevdev/libevdev-1.13.3.tar.xz"
download "https://www.freedesktop.org/software/libgudev/libgudev-238.tar.xz" 2>/dev/null || true
download "https://github.com/libfido2/libfido2/archive/refs/tags/1.14.0/libfido2-1.14.0.tar.gz" 2>/dev/null || true
download "$GITHUB/cisco/openh264/archive/refs/tags/v2.4.1/openh264-2.4.1.tar.gz" 2>/dev/null || true
download "https://downloads.xiph.org/releases/ogg/libogg-1.3.5.tar.xz"
download "https://downloads.xiph.org/releases/vorbis/libvorbis-1.3.7.tar.xz"
download "https://downloads.xiph.org/releases/flac/flac-1.4.3.tar.xz"
download "https://www.freedesktop.org/software/libsndfile/libsndfile-1.2.2.tar.xz" 2>/dev/null || true
download "$GITHUB/alsa-project/alsa-lib/archive/refs/tags/v1.2.12/alsa-lib-1.2.12.tar.gz"

# ============================================
# Desktop: KDE Frameworks 6
# ============================================
echo ""
echo "--- Desktop: KDE Frameworks 6 ---"

KDE_MIRROR="https://download.kde.org/stable/frameworks/${KF6_VER}"
KF6_MODULES=(
    extra-cmake-modules
    karchive
    kcoreaddons
    ki18n
    kconfig
    kwidgetsaddons
    kwindowsystem
    kdbusaddons
    kguiaddons
    kitemviews
    kitemmodels
    kcompletion
    kcolorscheme
    kiconthemes
    kauth
    kcodecs
    kconfigwidgets
    kcrash
    kglobalaccel
    kjobwidgets
    knotifications
    kservice
    ktextwidgets
    kxmlgui
    solid
    sonnet
    kpackage
    kdeclarative
    kcmutils
    knewstuff
    kparts
    kio
    kbookmarks
    kirigami
    plasma-framework
    ksvg
    krunner
    kunitconversion
    kstatusnotifieritem
    kidletime
    ktexteditor
    syntax-highlighting
    purpose
    kwallet
    networkmanager-qt
    modemmanager-qt
    bluez-qt
    prison
    kfilemetadata
    baloo
    kpeople
    kcontacts
    kcalendarcore
    kholidays
    knotifyconfig
    kscreen
    layer-shell-qt
)

for kf in "${KF6_MODULES[@]}"; do
    download "$KDE_MIRROR/${kf}-${KF6_VER}.tar.xz" 2>/dev/null || \
        echo "  Note: ${kf}-${KF6_VER} not found, may use different naming"
done

# ============================================
# Desktop: KDE Plasma 6
# ============================================
echo ""
echo "--- Desktop: KDE Plasma 6 ---"

PLASMA_MIRROR="https://download.kde.org/stable/plasma/${PLASMA_VER}"
PLASMA_MODULES=(
    breeze
    breeze-icons
    breeze-gtk
    kwin
    plasma-workspace
    plasma-desktop
    kscreen
    plasma-nm
    plasma-pa
    powerdevil
    bluedevil
    systemsettings
    polkit-kde-agent-1
    kde-cli-tools
    sddm-kcm
    kdecoration
    libkscreen
    kwayland
    plasma-integration
    plasma-activities
    plasma-activities-stats
    kpipewire
    kscreenlocker
    milou
    oxygen
    drkonqi
    plasma-vault
    plasma-systemmonitor
    plasma-firewall
    xdg-desktop-portal-kde
    plasma-browser-integration
    kdeplasma-addons
    kgamma
    kinfocenter
    ksystemstats
    libksysguard
)

for pm in "${PLASMA_MODULES[@]}"; do
    download "$PLASMA_MIRROR/${pm}-${PLASMA_VER}.tar.xz" 2>/dev/null || \
        echo "  Note: ${pm}-${PLASMA_VER} not found, may use different naming"
done

# ============================================
# Desktop: KDE Applications
# ============================================
echo ""
echo "--- Desktop: KDE Applications ---"

KDE_APPS_MIRROR="https://download.kde.org/stable/release-service/${KDE_APPS_VER}/src"
KDE_APPS=(
    dolphin
    konsole
    kate
    ark
    spectacle
    kcalc
)

for app in "${KDE_APPS[@]}"; do
    download "$KDE_APPS_MIRROR/${app}-${KDE_APPS_VER}.tar.xz" 2>/dev/null || \
        echo "  Note: ${app}-${KDE_APPS_VER} not found"
done

# ============================================
# Desktop: Audio (PipeWire)
# ============================================
echo ""
echo "--- Desktop: Audio ---"

download "https://gitlab.freedesktop.org/pipewire/pipewire/-/archive/${PIPEWIRE_VER}/pipewire-${PIPEWIRE_VER}.tar.gz"
download "https://gitlab.freedesktop.org/pipewire/wireplumber/-/archive/${WIREPLUMBER_VER}/wireplumber-${WIREPLUMBER_VER}.tar.gz"
download "$GITHUB/alsa-project/alsa-utils/archive/refs/tags/v1.2.12/alsa-utils-1.2.12.tar.gz" 2>/dev/null || true

# ============================================
# Desktop: Applications
# ============================================
echo ""
echo "--- Desktop: Applications ---"

# Firefox (binary release — building from source takes 6+ hours)
download "https://download-installer.cdn.mozilla.net/pub/firefox/releases/${FIREFOX_VER}/linux-x86_64/en-US/firefox-${FIREFOX_VER}.tar.bz2"

# Alacritty (needs Rust)
download "$GITHUB/alacritty/alacritty/archive/refs/tags/v${ALACRITTY_VER}/alacritty-${ALACRITTY_VER}.tar.gz"

# Rust toolchain (needed for Alacritty)
download "https://static.rust-lang.org/dist/rust-1.82.0-x86_64-unknown-linux-gnu.tar.xz" 2>/dev/null || \
    download "https://static.rust-lang.org/dist/rust-1.82.0-x86_64-unknown-linux-gnu.tar.gz"

# htop
download "$GITHUB/htop-dev/htop/releases/download/${HTOP_VER}/htop-${HTOP_VER}.tar.xz"

# fastfetch
download "$GITHUB/fastfetch-cli/fastfetch/archive/refs/tags/${FASTFETCH_VER}/fastfetch-${FASTFETCH_VER}.tar.gz"

# wmctrl (for auto-install script)
download "https://sites.google.com/site/aborber/wmctrl/wmctrl-1.07.tar.gz" 2>/dev/null || true

# ============================================
# Desktop: Performance & VM Tools
# ============================================
echo ""
echo "--- Desktop: Performance & VM tools ---"

download "$GITHUB/rfjakob/earlyoom/archive/refs/tags/v${EARLYOOM_VER}/earlyoom-${EARLYOOM_VER}.tar.gz"
download "$GITHUB/Irqbalance/irqbalance/archive/refs/tags/v${IRQBALANCE_VER}/irqbalance-${IRQBALANCE_VER}.tar.gz"
download "$GITHUB/intel/thermal_daemon/archive/refs/tags/v${THERMALD_VER}/thermal_daemon-${THERMALD_VER}.tar.gz"
download "$GITHUB/spice-space/linux/archive/refs/tags/v0.22.1/spice-vdagent-0.22.1.tar.gz" 2>/dev/null || \
    download "https://www.spice-space.org/download/releases/spice-vdagent/spice-vdagent-0.22.1.tar.bz2" 2>/dev/null || true
download "$GITHUB/qemu/qemu/archive/refs/tags/v9.1.1/qemu-9.1.1.tar.gz" 2>/dev/null || true
download "$GITHUB/vmware/open-vm-tools/releases/download/stable-12.4.0/open-vm-tools-12.4.0-23259341.tar.gz" 2>/dev/null || true

# Dracut (for live initramfs)
download "$GITHUB/dracut-ng/dracut-ng/archive/refs/tags/103/dracut-ng-103.tar.gz" 2>/dev/null || \
    download "$GITHUB/dracutdevs/dracut/archive/refs/tags/059/dracut-059.tar.gz" 2>/dev/null || true

# ============================================
# Desktop: Fonts
# ============================================
echo ""
echo "--- Desktop: Fonts ---"

download "$GITHUB/googlefonts/noto-fonts/archive/refs/tags/v2024-08-01/noto-fonts-v2024-08-01.tar.gz" 2>/dev/null || \
    download "https://github.com/notofonts/notofonts.github.io/archive/refs/heads/main.tar.gz" 2>/dev/null || true
download "$GITHUB/liberationfonts/liberation-fonts/files/7261482/liberation-fonts-ttf-2.1.5.tar.gz"
download "$GITHUB/source-foundry/Hack/releases/download/v3.003/Hack-v3.003-ttf.tar.xz" 2>/dev/null || \
    download "$GITHUB/source-foundry/Hack/releases/download/v3.003/Hack-v3.003-ttf.tar.gz"

# ============================================
# Desktop: Calamares Installer
# ============================================
echo ""
echo "--- Desktop: Calamares ---"

download "$GITHUB/calamares/calamares/releases/download/v${CALAMARES_VER}/calamares-${CALAMARES_VER}.tar.gz"

# ============================================
# Desktop: SDDM + Plymouth
# ============================================
echo ""
echo "--- Desktop: SDDM + Plymouth ---"

download "$GITHUB/sddm/sddm/archive/refs/tags/v${SDDM_VER}/sddm-${SDDM_VER}.tar.gz"
download "https://gitlab.freedesktop.org/plymouth/plymouth/-/archive/${PLYMOUTH_VER}/plymouth-${PLYMOUTH_VER}.tar.gz"

# xorriso (for ISO generation in stage7)
download "$GNU_MIRROR/xorriso/xorriso-1.5.6.pl02.tar.gz" 2>/dev/null || true
# syslinux (for legacy BIOS boot)
download "https://mirrors.edge.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.xz" 2>/dev/null || true

# --- Flush all queued downloads ---
flush_downloads
rm -f "$DOWNLOAD_LIST"

# --- Download LLVM binary (saves 2-3 hours in stage6) ---
echo ""
echo "=== Downloading pre-built binaries ==="
mkdir -p "$GAIA/sources/binaries"
cd "$GAIA/sources/binaries"

LLVM_BIN_URL="https://github.com/llvm/llvm-project/releases/download/llvmorg-18.1.8/clang+llvm-18.1.8-x86_64-linux-gnu-ubuntu-18.04.tar.xz"
LLVM_BIN_FILE="llvm-18.1.8-bin.tar.xz"
if [ ! -f "$LLVM_BIN_FILE" ]; then
    echo "  Downloading pre-built LLVM (saves 2-3 hours)..."
    wget -q --show-progress "$LLVM_BIN_URL" -O "$LLVM_BIN_FILE" || {
        echo "  LLVM binary download failed — will build from source"
        rm -f "$LLVM_BIN_FILE"
    }
else
    echo "  Already have: $LLVM_BIN_FILE"
fi

cd "$GAIA/sources"

echo ""
echo "=== Stage 0 complete ==="
echo "Sources: $(ls "$GAIA/sources" | wc -l) tarballs downloaded"
echo ""
echo "Optimizations active:"
command -v aria2c &>/dev/null && echo "  ✓ aria2 parallel downloads" || echo "  ✗ aria2 not installed (using wget)"
[ -f "$GAIA/sources/binaries/llvm-18.1.8-bin.tar.xz" ] && echo "  ✓ LLVM binary (saves ~2-3h)" || echo "  ✗ LLVM binary missing (will build from source)"
[ -f "$GAIA/sources/ccache-4.10.2-linux-x86_64.tar.xz" ] && echo "  ✓ ccache (saves hours on rebuilds)" || echo "  ✗ ccache not downloaded"
echo ""
echo "Next: make stage1"
