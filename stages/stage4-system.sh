#!/bin/bash
# Gaia Linux - Stage 4: System Configuration
# Build systemd, kernel, networking, bootloader; apply Gaia branding

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../toolchain/config/toolchain.conf"

echo "=== Gaia Linux Stage 4: System Configuration ==="

# Generate the chroot build script
cat > "$GAIA/tmp/build-system.sh" << 'CHROOTEOF'
#!/bin/bash
set -e

export HOME=/root
export TERM=xterm-256color
export PATH=/usr/bin:/usr/sbin
export MAKEFLAGS="-j$(nproc)"

SRC="/sources"

echo "=== Building system packages ==="

# --- D-Bus ---
echo ""
echo ">>> dbus"
cd "$SRC" && tar xf dbus-*.tar.xz
cd dbus-*/
./configure --prefix=/usr \
    --sysconfdir=/etc \
    --localstatedir=/var \
    --runstatedir=/run \
    --enable-user-session \
    --disable-static \
    --disable-doxygen-docs \
    --with-system-socket=/run/dbus/system_bus_socket
make && make install
ln -sfv /etc/machine-id /var/lib/dbus/machine-id 2>/dev/null || true
cd "$SRC" && rm -rf dbus-*/

# --- Systemd ---
echo ""
echo ">>> systemd"
cd "$SRC" && tar xf systemd-*.tar.gz
cd systemd-*/

# Patch: remove unneeded deps for minimal build
sed -i 's/GROUP="render"/GROUP="video"/' rules.d/50-udev-default.rules.in

mkdir -v build && cd build
meson setup .. \
    --prefix=/usr \
    --buildtype=release \
    -Dmode=release \
    -Ddev-kvm-mode=0660 \
    -Ddefault-dnssec=no \
    -Dfirstboot=false \
    -Dinstall-tests=false \
    -Dldconfig=false \
    -Dman=false \
    -Dsysusers=false \
    -Db_lto=false \
    -Drpmmacrosdir=no \
    -Dhomed=disabled \
    -Duserdb=false \
    -Ddocdir=/usr/share/doc/systemd \
    -Dblkid=enabled \
    -Dkmod=disabled
ninja
ninja install

# Enable essential systemd services
systemctl preset-all 2>/dev/null || true
systemd-machine-id-setup 2>/dev/null || true

cd "$SRC" && rm -rf systemd-*/

# --- Shadow (user management) ---
echo ""
echo ">>> shadow"
cd "$SRC"
# Download if not present (may need manual download)
if ls shadow-*.tar.xz &>/dev/null; then
    tar xf shadow-*.tar.xz
    cd shadow-*/
    # Disable installation of groups program (util-linux provides it)
    sed -i 's/groups$(EXEEXT) //' src/Makefile.in
    find man -name Makefile.in -exec sed -i 's/groups\.1 / /' {} \;
    find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
    find man -name Makefile.in -exec sed -i 's/passwd\.5 / /' {} \;

    sed -e 's:#ENCRYPT_METHOD DES:ENCRYPT_METHOD YESCRYPT:' \
        -e 's:/var/spool/mail:/var/mail:' \
        -e '/PATH=/{s@/sbin:@@;s@/bin:@@}' \
        -i etc/login.defs

    ./configure --sysconfdir=/etc \
        --disable-static \
        --with-{b,yes}crypt \
        --without-libbsd \
        --with-group-name-max-length=32
    make && make exec_prefix=/usr install
    make -C man install-man

    # Configure
    pwconv
    grpconv

    cd "$SRC" && rm -rf shadow-*/
fi

# --- Kmod ---
echo ""
echo ">>> kmod"
if ls "$SRC"/kmod-*.tar.xz &>/dev/null; then
    cd "$SRC" && tar xf kmod-*.tar.xz
    cd kmod-*/
    ./configure --prefix=/usr \
        --sysconfdir=/etc \
        --with-openssl \
        --with-xz \
        --with-zstd \
        --with-zlib
    make && make install
    # Create symlinks
    for tool in depmod insmod modinfo modprobe rmmod; do
        ln -sfv ../bin/kmod /usr/sbin/$tool
    done
    ln -sfv kmod /usr/bin/lsmod
    cd "$SRC" && rm -rf kmod-*/
fi

# --- Sudo ---
echo ""
echo ">>> sudo"
if ls "$SRC"/sudo-*.tar.gz &>/dev/null; then
    cd "$SRC" && tar xf sudo-*.tar.gz
    cd sudo-*/
    ./configure --prefix=/usr \
        --libexecdir=/usr/lib \
        --with-secure-path \
        --with-env-editor \
        --docdir=/usr/share/doc/sudo \
        --with-passprompt="[sudo] password for %p: "
    make && make install
    cd "$SRC" && rm -rf sudo-*/
fi

# Create sudoers
cat > /etc/sudoers << 'SUDOEOF'
root ALL=(ALL:ALL) ALL
%wheel ALL=(ALL:ALL) ALL
%sudo ALL=(ALL:ALL) ALL
SUDOEOF
chmod 0440 /etc/sudoers
mkdir -p /etc/sudoers.d

# --- Linux Kernel ---
echo ""
echo ">>> linux kernel (with Gaia branding)"
cd "$SRC" && tar xf linux-*.tar.xz
cd linux-*/

make mrproper

# Use provided config or generate a default one
if [ -f /tmp/kernel.config ]; then
    cp /tmp/kernel.config .config
else
    make defconfig
fi

# Apply Gaia branding
scripts/config --set-str LOCALVERSION "-gaia" 2>/dev/null || \
    sed -i 's/CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION="-gaia"/' .config

# Enable essential options
scripts/config --enable CONFIG_EFI 2>/dev/null || true
scripts/config --enable CONFIG_EFI_STUB 2>/dev/null || true
scripts/config --enable CONFIG_OVERLAY_FS 2>/dev/null || true
scripts/config --enable CONFIG_SQUASHFS 2>/dev/null || true
scripts/config --enable CONFIG_SQUASHFS_XZ 2>/dev/null || true
scripts/config --enable CONFIG_BLK_DEV_LOOP 2>/dev/null || true
scripts/config --enable CONFIG_ZRAM 2>/dev/null || true

make olddefconfig
make
make modules_install

# Install kernel
cp -v arch/x86/boot/bzImage /boot/vmlinuz-gaia
cp -v System.map /boot/System.map-gaia
cp -v .config /boot/config-gaia

cd "$SRC" && rm -rf linux-*/

# --- Nano ---
echo ""
echo ">>> nano"
if ls "$SRC"/nano-*.tar.xz &>/dev/null; then
    cd "$SRC" && tar xf nano-*.tar.xz
    cd nano-*/
    ./configure --prefix=/usr \
        --sysconfdir=/etc \
        --enable-utf8 \
        --docdir=/usr/share/doc/nano
    make && make install
    cd "$SRC" && rm -rf nano-*/
fi

# --- Zsh ---
echo ""
echo ">>> zsh"
if ls "$SRC"/zsh-*.tar.xz &>/dev/null; then
    cd "$SRC" && tar xf zsh-*.tar.xz
    cd zsh-*/
    ./configure --prefix=/usr \
        --enable-multibyte \
        --enable-fndir=/usr/share/zsh/functions \
        --enable-scriptdir=/usr/share/zsh/scripts \
        --with-tcsetpgrp \
        --enable-pcre \
        --enable-cap
    make && make install
    # Add to valid shells
    echo "/usr/bin/zsh" >> /etc/shells
    cd "$SRC" && rm -rf zsh-*/
fi
echo "/bin/bash" >> /etc/shells
echo "/usr/bin/bash" >> /etc/shells

# --- GRUB ---
echo ""
echo ">>> grub"
if ls "$SRC"/grub-*.tar.xz &>/dev/null; then
    cd "$SRC" && tar xf grub-*.tar.xz
    cd grub-*/
    ./configure --prefix=/usr \
        --sysconfdir=/etc \
        --disable-efiemu \
        --enable-grub-mkfont=no \
        --with-platform=efi \
        --target=x86_64 \
        --disable-werror
    make && make install
    cd "$SRC" && rm -rf grub-*/
fi

# --- NetworkManager ---
echo ">>> NetworkManager (skipping - build from source if available)"

# --- Generate initramfs ---
echo ""
echo ">>> Generating initramfs"
# Use dracut if available, otherwise create a basic one
if command -v dracut &>/dev/null; then
    dracut --force --add "dmsquash-live livenet" /boot/initrd-gaia.img
else
    echo "  dracut not available — initramfs will be generated in stage7"
fi

echo ""
echo "=== System packages complete ==="
CHROOTEOF

chmod +x "$GAIA/tmp/build-system.sh"

# Copy kernel config if it exists
if [ -f "$SCRIPT_DIR/../toolchain/config/kernel.config" ]; then
    cp "$SCRIPT_DIR/../toolchain/config/kernel.config" "$GAIA/tmp/kernel.config"
fi

# Ensure virtual filesystems are mounted
mountpoint -q "$GAIA/dev" || mount -v --bind /dev "$GAIA/dev"
mountpoint -q "$GAIA/proc" || mount -vt proc proc "$GAIA/proc"
mountpoint -q "$GAIA/sys" || mount -vt sysfs sysfs "$GAIA/sys"
mountpoint -q "$GAIA/run" || mount -vt tmpfs tmpfs "$GAIA/run"

# Enter chroot
echo "Entering chroot for system build..."
chroot "$GAIA" /usr/bin/env -i \
    HOME=/root \
    TERM="$TERM" \
    PATH=/usr/bin:/usr/sbin \
    MAKEFLAGS="-j${NPROC:-$(nproc)}" \
    /bin/bash /tmp/build-system.sh

rm -f "$GAIA/tmp/build-system.sh" "$GAIA/tmp/kernel.config"

# --- Apply Gaia overlay ---
echo ""
echo "=== Applying Gaia overlay ==="
bash "$SCRIPT_DIR/../scripts/install-overlay.sh" "$GAIA"

echo ""
echo "=== Stage 4 complete ==="
echo "System configured with kernel, systemd, and Gaia branding"
echo ""
echo "Next: make stage5"
