#!/bin/bash
# Gaia Linux - Stage 6: Desktop (KDE Plasma 6)
# Optimized build: ccache, binary LLVM, parallel cmake, reduced Mesa drivers
# Expected time: ~2-3 hours (down from 8-16h)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../toolchain/config/toolchain.conf"

TIME_START=$(date +%s)

echo "=== Gaia Linux Stage 6: Desktop ==="
echo "Building: Xorg + Wayland → Qt6 → KDE Frameworks 6 → KDE Plasma 6"
echo ""

# --- Install LLVM binary if available (saves 2-3 hours) ---
if [ -f "$GAIA/sources/binaries/llvm-18.1.8-bin.tar.xz" ]; then
    echo ">>> Installing pre-built LLVM (saves ~2-3 hours)..."
    mkdir -p "$GAIA/opt/llvm"
    tar xf "$GAIA/sources/binaries/llvm-18.1.8-bin.tar.xz" -C "$GAIA/opt/llvm" --strip-components=1
    # Create symlinks so Mesa/other packages find LLVM
    for bin in llvm-config llc opt; do
        ln -sfv /opt/llvm/bin/$bin "$GAIA/usr/bin/$bin" 2>/dev/null || true
    done
    for lib in "$GAIA"/opt/llvm/lib/libLLVM*.so*; do
        [ -f "$lib" ] && ln -sfv "$lib" "$GAIA/usr/lib/$(basename "$lib")" 2>/dev/null || true
    done
    cp -rv "$GAIA/opt/llvm/include/llvm" "$GAIA/usr/include/" 2>/dev/null || true
    cp -rv "$GAIA/opt/llvm/include/llvm-c" "$GAIA/usr/include/" 2>/dev/null || true
    echo "  LLVM binary installed."
else
    echo "  No LLVM binary found — will build from source (slow)."
    echo "  Run: bash scripts/download-binaries.sh  to get pre-built LLVM."
fi

# --- Setup ccache inside chroot (saves hours on rebuilds) ---
echo ""
echo "Setting up ccache..."
if [ -f "$GAIA/usr/bin/ccache" ]; then
    echo "  ccache already installed"
else
    # Build ccache inside chroot if source available
    if ls "$GAIA/sources"/ccache-*.tar.* &>/dev/null; then
        echo "  Building ccache..."
    else
        echo "  Downloading ccache..."
        wget -q "https://github.com/ccache/ccache/releases/download/v4.10.2/ccache-4.10.2-linux-x86_64.tar.xz" \
            -O "$GAIA/sources/ccache-4.10.2-linux-x86_64.tar.xz" 2>/dev/null || true
    fi
fi

# --- Generate chroot build script ---
cat > "$GAIA/tmp/build-desktop.sh" << 'CHROOTEOF'
#!/bin/bash
set -e

export HOME=/root
export TERM=xterm-256color
export PATH=/usr/bin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"
export PKG_CONFIG_PATH="/usr/lib/pkgconfig:/usr/share/pkgconfig"
export CMAKE_BUILD_PARALLEL_LEVEL=$(nproc)

SRC="/sources"

# ====================================================
# OPTIMIZATION 1: Setup ccache
# ====================================================
if [ -f "$SRC/ccache-"*"-linux-x86_64.tar.xz" ]; then
    echo ">>> Installing ccache (binary)..."
    cd /tmp && tar xf "$SRC"/ccache-*-linux-x86_64.tar.xz
    install -vm755 ccache-*/ccache /usr/bin/ccache
    rm -rf /tmp/ccache-*/
fi

if command -v ccache &>/dev/null; then
    echo ">>> Enabling ccache for all compilers"
    mkdir -p /usr/lib/ccache/bin
    for comp in gcc g++ cc c++ cpp; do
        ln -sfv /usr/bin/ccache /usr/lib/ccache/bin/$comp
    done
    export PATH="/usr/lib/ccache/bin:$PATH"
    export CCACHE_DIR="/var/cache/ccache"
    export CCACHE_MAXSIZE="10G"
    export CCACHE_COMPRESS=1
    mkdir -p "$CCACHE_DIR"
    ccache --zero-stats
    echo "  ccache enabled (max ${CCACHE_MAXSIZE})"
fi

# ====================================================
# OPTIMIZATION 2: Compiler flags for speed
# ====================================================
# Use -pipe (faster, uses more RAM) and skip debug info
export CFLAGS="-O2 -pipe -fno-plt -march=x86-64 -mtune=generic"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-Wl,-O1,--as-needed,-z,relro,-z,now"

# ====================================================
# Helper functions
# ====================================================
build_meson() {
    local name="$1" opts="$2"
    local t_start=$(date +%s)
    echo ""
    echo ">>> $name"
    cd "$SRC"
    # Try multiple naming conventions
    local tarball=$(ls ${name}-*.tar.* 2>/dev/null | head -1)
    [ -z "$tarball" ] && tarball=$(ls ${name}*.tar.* 2>/dev/null | head -1)
    [ -z "$tarball" ] && { echo "  SKIP: no source found"; return 0; }
    tar xf "$tarball"
    local srcdir=$(ls -d ${name}-*/ 2>/dev/null | head -1)
    [ -z "$srcdir" ] && srcdir=$(ls -d ${name}*/ 2>/dev/null | head -1)
    [ -z "$srcdir" ] && { echo "  SKIP: no source dir"; return 0; }
    cd "$srcdir"
    mkdir -p build && cd build
    meson setup .. --prefix=/usr --buildtype=release $opts
    ninja
    ninja install
    cd "$SRC" && rm -rf "$srcdir"
    echo "  Done in $(($(date +%s) - t_start))s"
}

build_cmake() {
    local name="$1" opts="$2"
    local t_start=$(date +%s)
    echo ""
    echo ">>> $name"
    cd "$SRC"
    local tarball=$(ls ${name}-*.tar.* 2>/dev/null | head -1)
    [ -z "$tarball" ] && { echo "  SKIP: no source found"; return 0; }
    tar xf "$tarball"
    local srcdir=$(ls -d ${name}-*/ 2>/dev/null | head -1)
    [ -z "$srcdir" ] && { echo "  SKIP: no source dir"; return 0; }
    cd "$srcdir"
    mkdir -p build && cd build
    cmake .. -DCMAKE_INSTALL_PREFIX=/usr \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_TESTING=OFF \
        -DCMAKE_C_FLAGS_RELEASE="-O2 -DNDEBUG" \
        -DCMAKE_CXX_FLAGS_RELEASE="-O2 -DNDEBUG" \
        $opts
    make -j$(nproc)
    make install
    cd "$SRC" && rm -rf "$srcdir"
    echo "  Done in $(($(date +%s) - t_start))s"
}

build_conf() {
    local name="$1" opts="$2"
    local t_start=$(date +%s)
    echo ""
    echo ">>> $name"
    cd "$SRC"
    local tarball=$(ls ${name}-*.tar.* 2>/dev/null | head -1)
    [ -z "$tarball" ] && { echo "  SKIP: no source found"; return 0; }
    tar xf "$tarball"
    local srcdir=$(ls -d ${name}-*/ 2>/dev/null | head -1)
    [ -z "$srcdir" ] && { echo "  SKIP: no source dir"; return 0; }
    cd "$srcdir"
    ./configure --prefix=/usr $opts
    make -j$(nproc) && make install
    cd "$SRC" && rm -rf "$srcdir"
    echo "  Done in $(($(date +%s) - t_start))s"
}

# Build multiple packages sequentially from a list (for Xorg libs etc.)
build_xorg_lib() {
    local tarball="$1" opts="$2"
    local name=$(basename "$tarball" | sed 's/\.tar\..*//')
    echo "  >>> $name"
    cd "$SRC" && tar xf "$tarball"
    cd "$name"/
    if [ -f meson.build ]; then
        mkdir -p build && cd build
        meson setup .. --prefix=/usr --buildtype=release $opts 2>/dev/null
        ninja && ninja install
    else
        ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var \
            --disable-static $opts 2>/dev/null
        make -j$(nproc) && make install
    fi
    cd "$SRC" && rm -rf "$name"/
}

echo ""
echo "============================================"
echo "PHASE 1: Xorg Dependencies (~15 min)"
echo "============================================"
PHASE_START=$(date +%s)

# Build all Xorg proto, libs in sequence (small packages, fast)
echo "Building Xorg protocol headers and libraries..."
for pkg in util-macros xorgproto xcb-proto libXau libXdmcp xtrans; do
    tarball=$(ls "$SRC"/${pkg}-*.tar.* 2>/dev/null | head -1)
    [ -n "$tarball" ] && build_xorg_lib "$tarball"
done

# libxcb (depends on xcb-proto)
tarball=$(ls "$SRC"/libxcb-*.tar.* 2>/dev/null | head -1)
[ -n "$tarball" ] && build_xorg_lib "$tarball" "--without-doxygen"

# X11 libs (depend on libxcb)
for pkg in libX11 libXext libXfixes libXi libXtst libXrandr libXrender \
           libXcursor libXcomposite libXdamage libXinerama libXScrnSaver \
           libxshmfence libXxf86vm libICE libSM libXt libXmu libXpm libXaw \
           libXfont2 libxkbfile libpciaccess pixman; do
    tarball=$(ls "$SRC"/${pkg}-*.tar.* 2>/dev/null | head -1)
    [ -n "$tarball" ] && build_xorg_lib "$tarball"
done

# xkeyboard-config, font-util
for pkg in xkeyboard-config font-util; do
    tarball=$(ls "$SRC"/${pkg}-*.tar.* 2>/dev/null | head -1)
    [ -n "$tarball" ] && build_xorg_lib "$tarball"
done

echo "  Xorg libs done in $(($(date +%s) - PHASE_START))s"

echo ""
echo "============================================"
echo "PHASE 2: Graphics Stack (~30 min)"
echo "============================================"
PHASE_START=$(date +%s)

# Core graphics
build_meson "libdrm" "-Dudev=true -Dvalgrind=disabled"
build_meson "wayland" "-Ddocumentation=false -Dtests=false"
build_meson "wayland-protocols" "-Dtests=false"

# libglvnd
echo ""
echo ">>> libglvnd"
cd "$SRC"
tarball=$(ls libglvnd-*.tar.* 2>/dev/null | head -1)
if [ -n "$tarball" ]; then
    tar xf "$tarball"
    cd libglvnd-*/
    mkdir -p build && cd build
    meson setup .. --prefix=/usr --buildtype=release
    ninja && ninja install
    cd "$SRC" && rm -rf libglvnd-*/
fi

# Vulkan headers + loader
build_cmake "Vulkan-Headers" ""
build_cmake "Vulkan-Loader" "-DVULKAN_HEADERS_INSTALL_DIR=/usr"

# LLVM — skip if binary already installed
if [ -f /usr/bin/llvm-config ] || [ -f /opt/llvm/bin/llvm-config ]; then
    echo ""
    echo ">>> LLVM: already installed (binary), skipping build"
    # Ensure llvm-config is in PATH
    [ -f /opt/llvm/bin/llvm-config ] && export PATH="/opt/llvm/bin:$PATH"
else
    echo ""
    echo ">>> LLVM (building from source — this takes 2-3 hours!)"
    echo "    TIP: Run scripts/download-binaries.sh to skip this"
    cd "$SRC"
    tarball=$(ls llvm-project-*.tar.* 2>/dev/null | head -1)
    if [ -n "$tarball" ]; then
        tar xf "$tarball"
        cd llvm-project-*/
        mkdir -p build && cd build
        cmake ../llvm -DCMAKE_INSTALL_PREFIX=/usr \
            -DCMAKE_BUILD_TYPE=Release \
            -DLLVM_ENABLE_PROJECTS="clang" \
            -DLLVM_BUILD_LLVM_DYLIB=ON \
            -DLLVM_LINK_LLVM_DYLIB=ON \
            -DLLVM_TARGETS_TO_BUILD="X86;AMDGPU" \
            -DLLVM_ENABLE_RTTI=ON \
            -DLLVM_INSTALL_UTILS=ON \
            -DBUILD_SHARED_LIBS=OFF \
            -DLLVM_BUILD_TESTS=OFF \
            -DLLVM_BUILD_DOCS=OFF
        make -j$(nproc)
        make install
        cd "$SRC" && rm -rf llvm-project-*/
    fi
fi

# OPTIMIZATION 3: Mesa with REDUCED drivers (saves 15-20 min)
echo ""
echo ">>> mesa (optimized: reduced drivers)"
cd "$SRC"
tarball=$(ls mesa-*.tar.* 2>/dev/null | head -1)
if [ -n "$tarball" ]; then
    tar xf "$tarball"
    cd mesa-*/
    mkdir -p build && cd build
    meson setup .. --prefix=/usr --buildtype=release \
        -Dgallium-drivers=iris,swrast \
        -Dvulkan-drivers=intel \
        -Dplatforms=x11,wayland \
        -Dglx=dri \
        -Degl=enabled \
        -Dgles2=enabled \
        -Dvalgrind=disabled \
        -Dllvm=enabled \
        -Dvideo-codecs='' \
        -Dgallium-nine=false \
        -Dgallium-opencl=disabled \
        -Dgallium-va=disabled \
        -Dgallium-vdpau=disabled \
        -Dgallium-xa=disabled
    ninja && ninja install
    cd "$SRC" && rm -rf mesa-*/
fi

build_meson "libxkbcommon" "-Denable-docs=false"
build_meson "libevdev" ""
build_meson "libinput" "-Ddocumentation=false -Dtests=false -Ddebug-gui=false"

# Xorg server
echo ""
echo ">>> xorg-server"
cd "$SRC"
tarball=$(ls xorg-server-*.tar.* 2>/dev/null | head -1)
if [ -n "$tarball" ]; then
    tar xf "$tarball"
    cd xorg-server-*/
    mkdir -p build && cd build
    meson setup .. --prefix=/usr --buildtype=release \
        -Dxorg=true -Dxwayland=true -Dglamor=true \
        -Dxkb_dir=/usr/share/X11/xkb
    ninja && ninja install
    cd "$SRC" && rm -rf xorg-server-*/
fi

# X11 drivers (small, fast)
for drv in xf86-video-amdgpu xf86-video-nouveau xf86-input-libinput; do
    tarball=$(ls "$SRC"/${drv}-*.tar.* 2>/dev/null | head -1)
    [ -n "$tarball" ] && build_xorg_lib "$tarball"
done

echo "  Graphics stack done in $(($(date +%s) - PHASE_START))s"

echo ""
echo "============================================"
echo "PHASE 3: Qt6 Dependencies (~20 min)"
echo "============================================"
PHASE_START=$(date +%s)

# Build Qt6 deps that aren't already present
for dep in libpng libjpeg-turbo libwebp freetype harfbuzz fontconfig \
           libogg libvorbis flac alsa-lib libsndfile cairo glib \
           gobject-introspection freeglut shared-mime-info \
           gdk-pixbuf pango polkit libgudev libusb; do
    tarball=$(ls "$SRC"/${dep}-*.tar.* 2>/dev/null | head -1)
    if [ -n "$tarball" ] && ! pkg-config --exists "$dep" 2>/dev/null; then
        name=$(basename "$tarball" | sed 's/\.tar\..*//')
        echo "  >>> $name"
        cd "$SRC" && tar xf "$tarball"
        cd "$name"/ 2>/dev/null || cd ${dep}-*/ 2>/dev/null || continue
        if [ -f meson.build ]; then
            mkdir -p build && cd build
            meson setup .. --prefix=/usr --buildtype=release 2>/dev/null
            ninja && ninja install
        elif [ -f CMakeLists.txt ]; then
            mkdir -p build && cd build
            cmake .. -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release 2>/dev/null
            make -j$(nproc) && make install
        elif [ -f configure ]; then
            ./configure --prefix=/usr --disable-static 2>/dev/null
            make -j$(nproc) && make install
        fi
        cd "$SRC" && rm -rf "$name"/ ${dep}-*/
    fi
done

echo "  Qt6 deps done in $(($(date +%s) - PHASE_START))s"

echo ""
echo "============================================"
echo "PHASE 4: Qt6 Modules (~60 min)"
echo "============================================"
PHASE_START=$(date +%s)

# Qt6 modules in dependency order
# The Qt tarballs use "qtFOO-everywhere-src-VERSION" naming
QT6_MODULES=(
    qtbase
    qtshadertools
    qtdeclarative
    qtwayland
    qtsvg
    qtimageformats
    qt5compat
    qtmultimedia
    qttools
)

for qt_mod in "${QT6_MODULES[@]}"; do
    tarball=$(ls "$SRC"/${qt_mod}-everywhere-src-*.tar.* 2>/dev/null | head -1)
    if [ -n "$tarball" ]; then
        t_start=$(date +%s)
        echo ""
        echo ">>> $qt_mod"
        cd "$SRC" && tar xf "$tarball"
        srcdir=$(ls -d ${qt_mod}-everywhere-src-*/ 2>/dev/null | head -1)
        [ -z "$srcdir" ] && { echo "  SKIP"; continue; }
        cd "$srcdir"
        mkdir -p build && cd build

        # qtbase needs special flags
        if [ "$qt_mod" = "qtbase" ]; then
            cmake .. -DCMAKE_INSTALL_PREFIX=/usr \
                -DCMAKE_BUILD_TYPE=Release \
                -DBUILD_TESTING=OFF \
                -DINPUT_opengl=desktop \
                -DQT_FEATURE_journald=OFF \
                -DQT_FEATURE_vulkan=ON \
                -DQT_BUILD_EXAMPLES=OFF \
                -DQT_BUILD_BENCHMARKS=OFF
        else
            cmake .. -DCMAKE_INSTALL_PREFIX=/usr \
                -DCMAKE_BUILD_TYPE=Release \
                -DBUILD_TESTING=OFF \
                -DQT_BUILD_EXAMPLES=OFF \
                -DQT_BUILD_BENCHMARKS=OFF
        fi
        make -j$(nproc)
        make install
        cd "$SRC" && rm -rf "$srcdir"
        echo "  Done in $(($(date +%s) - t_start))s"
    else
        echo ">>> $qt_mod (source not found, skipping)"
    fi
done

echo "  Qt6 done in $(($(date +%s) - PHASE_START))s"

echo ""
echo "============================================"
echo "PHASE 5: KDE Frameworks 6 (~40 min)"
echo "============================================"
PHASE_START=$(date +%s)

# KDE Frameworks 6 in strict dependency order
KF6_MODULES=(
    extra-cmake-modules
    karchive
    kcoreaddons
    ki18n
    kcodecs
    kconfig
    kguiaddons
    kwidgetsaddons
    kitemviews
    kitemmodels
    kcolorscheme
    kcompletion
    kwindowsystem
    kdbusaddons
    kiconthemes
    kauth
    kconfigwidgets
    kcrash
    sonnet
    solid
    kjobwidgets
    kglobalaccel
    knotifications
    kservice
    ktextwidgets
    kxmlgui
    kbookmarks
    kio
    kpackage
    kdeclarative
    kcmutils
    knewstuff
    kparts
    kirigami
    ksvg
    plasma-framework
    kstatusnotifieritem
    kidletime
    krunner
    ktexteditor
    syntax-highlighting
    purpose
    kwallet
    networkmanager-qt
    bluez-qt
    prison
    kfilemetadata
    baloo
    kpeople
    kcontacts
    knotifyconfig
    kunitconversion
    layer-shell-qt
    kscreen
)

for kf in "${KF6_MODULES[@]}"; do
    build_cmake "$kf" ""
done

echo "  KDE Frameworks done in $(($(date +%s) - PHASE_START))s"

echo ""
echo "============================================"
echo "PHASE 6: KDE Plasma 6 (~30 min)"
echo "============================================"
PHASE_START=$(date +%s)

PLASMA_MODULES=(
    kdecoration
    libkscreen
    breeze
    breeze-icons
    breeze-gtk
    kscreenlocker
    kwayland
    plasma-activities
    plasma-activities-stats
    kpipewire
    libksysguard
    ksystemstats
    kwin
    plasma-workspace
    plasma-integration
    plasma-desktop
    plasma-nm
    plasma-pa
    powerdevil
    bluedevil
    systemsettings
    polkit-kde-agent-1
    kde-cli-tools
    sddm-kcm
    xdg-desktop-portal-kde
    kinfocenter
    drkonqi
    kdeplasma-addons
    milou
    plasma-browser-integration
)

for pm in "${PLASMA_MODULES[@]}"; do
    build_cmake "$pm" ""
done

echo "  KDE Plasma done in $(($(date +%s) - PHASE_START))s"

echo ""
echo "============================================"
echo "PHASE 7: Apps & Extras (~15 min)"
echo "============================================"
PHASE_START=$(date +%s)

# KDE Apps
for app in dolphin konsole kate ark spectacle kcalc; do
    build_cmake "$app" ""
done

# Audio
build_meson "pipewire" "-Dsession-managers=[] -Djack=disabled -Dtests=disabled"
build_meson "wireplumber" "-Dtests=disabled -Ddoc=disabled"

# Firefox (binary — instant)
echo ""
echo ">>> firefox (binary install)"
tarball=$(ls "$SRC"/firefox-*.tar.bz2 2>/dev/null | head -1)
if [ -n "$tarball" ]; then
    cd /opt && tar xf "$tarball"
    ln -sfv /opt/firefox/firefox /usr/bin/firefox
    cat > /usr/share/applications/firefox.desktop << 'FFDESK'
[Desktop Entry]
Type=Application
Name=Firefox
Comment=Web Browser
Exec=firefox %u
Icon=/opt/firefox/browser/chrome/icons/default/default128.png
Categories=Network;WebBrowser;
MimeType=text/html;application/xhtml+xml;
FFDESK
    echo "  Firefox installed"
fi

# Rust + Alacritty
echo ""
echo ">>> Rust toolchain (for Alacritty)"
tarball=$(ls "$SRC"/rust-*-x86_64-*.tar.* 2>/dev/null | head -1)
if [ -n "$tarball" ]; then
    cd /tmp && tar xf "$tarball"
    cd rust-*/
    ./install.sh --prefix=/usr --without=rust-docs 2>/dev/null || true
    cd /tmp && rm -rf rust-*/

    # Alacritty
    tarball=$(ls "$SRC"/alacritty-*.tar.* 2>/dev/null | head -1)
    if [ -n "$tarball" ] && command -v cargo &>/dev/null; then
        echo ">>> alacritty"
        cd "$SRC" && tar xf "$tarball"
        cd alacritty-*/
        cargo build --release 2>/dev/null && \
            install -vm755 target/release/alacritty /usr/bin/ || \
            echo "  Alacritty build failed (non-critical)"
        cd "$SRC" && rm -rf alacritty-*/
    fi
fi

# Small tools (fast)
build_conf "htop" "--enable-unicode"
build_cmake "fastfetch" ""

# Performance tools
for tool in earlyoom irqbalance thermald; do
    tarball=$(ls "$SRC"/${tool}-*.tar.* "$SRC"/thermal_daemon-*.tar.* 2>/dev/null | head -1)
    if [ -n "$tarball" ]; then
        echo ""
        echo ">>> $tool"
        name=$(basename "$tarball" | sed 's/\.tar\..*//')
        cd "$SRC" && tar xf "$tarball"
        cd "$name"/
        if [ -f meson.build ]; then
            mkdir -p build && cd build
            meson setup .. --prefix=/usr --buildtype=release
            ninja && ninja install
        elif [ -f CMakeLists.txt ]; then
            mkdir -p build && cd build
            cmake .. -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release
            make -j$(nproc) && make install
        elif [ -f Makefile ]; then
            make -j$(nproc) PREFIX=/usr
            make PREFIX=/usr install
        fi
        cd "$SRC" && rm -rf "$name"/
    fi
done

# Fonts (just copy TTFs)
echo ""
echo ">>> Fonts"
mkdir -p /usr/share/fonts/TTF
for font_pkg in Hack liberation noto; do
    tarball=$(ls "$SRC"/*${font_pkg}*.tar.* 2>/dev/null | head -1)
    if [ -n "$tarball" ]; then
        cd "$SRC" && tar xf "$tarball"
        find . -maxdepth 3 -name "*.ttf" 2>/dev/null | head -200 | \
            xargs -I{} install -Dm644 {} /usr/share/fonts/TTF/
        rm -rf "$SRC"/*${font_pkg}*/
    fi
done
fc-cache -fv 2>/dev/null || true

# Plymouth + SDDM
build_meson "plymouth" "-Dgtk=disabled -Dlogo=/usr/share/pixmaps/gaia-logo.png"
build_cmake "sddm" "-DBUILD_MAN_PAGES=OFF"

# Calamares
build_cmake "calamares" "-DWITH_QT6=ON -DSKIP_MODULES='webview;interactiveterminal;initramfs;initramfscfg'"

# Dracut (for live boot initramfs)
tarball=$(ls "$SRC"/dracut-*.tar.* 2>/dev/null | head -1)
if [ -n "$tarball" ]; then
    echo ""
    echo ">>> dracut"
    name=$(basename "$tarball" | sed 's/\.tar\..*//')
    cd "$SRC" && tar xf "$tarball"
    cd "$name"/ 2>/dev/null || cd dracut-*/
    if [ -f configure ]; then
        ./configure --prefix=/usr --sysconfdir=/etc
        make -j$(nproc) && make install
    elif [ -f meson.build ]; then
        mkdir -p build && cd build
        meson setup .. --prefix=/usr
        ninja && ninja install
    fi
    cd "$SRC" && rm -rf "$name"/ dracut-*/
fi

echo "  Apps & extras done in $(($(date +%s) - PHASE_START))s"

echo ""
echo "============================================"
echo "Enabling services"
echo "============================================"

systemctl enable sddm 2>/dev/null || true
systemctl enable NetworkManager 2>/dev/null || true
systemctl enable zram-swap 2>/dev/null || true
systemctl enable earlyoom 2>/dev/null || true
systemctl enable irqbalance 2>/dev/null || true
systemctl enable thermald 2>/dev/null || true
systemctl enable gaia-branding 2>/dev/null || true
systemctl enable gaia-post-install-cleanup 2>/dev/null || true

systemctl set-default graphical.target
sed -i 's|SHELL=.*|SHELL=/usr/bin/zsh|' /etc/default/useradd 2>/dev/null || true

# ccache stats
if command -v ccache &>/dev/null; then
    echo ""
    echo "=== ccache statistics ==="
    ccache --show-stats
fi

echo ""
echo "=== Desktop build complete ==="
CHROOTEOF

chmod +x "$GAIA/tmp/build-desktop.sh"

# --- OPTIMIZATION 4: Use tmpfs for build if enough RAM ---
MEMTOTAL_MB=$(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
if [ "$MEMTOTAL_MB" -gt 32000 ]; then
    echo ">>> 32GB+ RAM detected — mounting tmpfs for /tmp inside chroot"
    mountpoint -q "$GAIA/tmp" || mount -t tmpfs -o size=16G tmpfs "$GAIA/tmp"
fi

# Ensure virtual filesystems are mounted
mountpoint -q "$GAIA/dev" || mount -v --bind /dev "$GAIA/dev"
mountpoint -q "$GAIA/proc" || mount -vt proc proc "$GAIA/proc"
mountpoint -q "$GAIA/sys" || mount -vt sysfs sysfs "$GAIA/sys"
mountpoint -q "$GAIA/run" || mount -vt tmpfs tmpfs "$GAIA/run"

# Persist ccache across builds
mkdir -p "$GAIA/var/cache/ccache"

chroot "$GAIA" /usr/bin/env -i \
    HOME=/root \
    TERM="$TERM" \
    PATH=/usr/bin:/usr/sbin \
    MAKEFLAGS="-j${NPROC:-$(nproc)}" \
    /bin/bash /tmp/build-desktop.sh

rm -f "$GAIA/tmp/build-desktop.sh"

TIME_END=$(date +%s)
ELAPSED=$(( (TIME_END - TIME_START) / 60 ))

echo ""
echo "=== Stage 6 complete in ${ELAPSED} minutes ==="
echo "KDE Plasma 6 desktop installed"
echo ""
echo "Next: make stage7"
