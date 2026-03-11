<p align="center">
  <img src="config/includes.chroot/usr/share/pixmaps/gaia-logo.png" width="120" alt="Gaia Linux Logo">
</p>

<h1 align="center">Gaia Linux</h1>

<p align="center">
  <strong>A blazing-fast, minimal Debian-based distribution with KDE Plasma 6</strong><br>
  Built for speed. Designed for daily use. Zero bloat.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/base-Debian%20Trixie-A81D33?style=flat-square&logo=debian" alt="Debian Trixie">
  <img src="https://img.shields.io/badge/desktop-KDE%20Plasma%206-1d99f3?style=flat-square&logo=kde" alt="KDE Plasma 6">
  <img src="https://img.shields.io/badge/arch-amd64-blue?style=flat-square" alt="amd64">
  <img src="https://img.shields.io/badge/shell-zsh-green?style=flat-square" alt="zsh">
  <img src="https://img.shields.io/badge/license-GPL--3.0-orange?style=flat-square" alt="GPL-3.0">
</p>

---

## What is Gaia Linux?

Gaia Linux is a **performance-first** Linux distribution based on Debian Trixie (Testing). It ships a carefully curated KDE Plasma 6 desktop stripped down to the essentials - no unnecessary services, no background bloat, no wasted resources.

Every default has been tuned for **responsiveness**: from kernel I/O scheduling to compositor settings to systemd timeouts. Whether you're running on bare metal or inside a virtual machine, Gaia adapts automatically to give you the best experience.

### Why Gaia?

| | Typical Distro | Gaia Linux |
|---|---|---|
| **Boot** | 30+ services at startup | Only what you need |
| **RAM** | 1.2 GB+ idle | ~600 MB idle with zRAM |
| **Disk I/O** | Generic scheduler | SSD/NVMe-optimized (mq-deadline) |
| **Desktop** | Full effects + indexing | Tuned compositor, no file indexer |
| **VM** | Same as bare metal | Auto-detects VM, disables compositor |
| **Swap** | Disk-based | zRAM compressed swap (RAM-backed) |

---

## Features

### Performance

- **zRAM Compressed Swap** - Uses 50% of RAM as compressed swap, dramatically improving performance on systems with limited memory
- **Smart I/O Scheduling** - Automatically applies `mq-deadline` for SSDs/NVMe and `bfq` for HDDs via udev rules
- **Kernel Tuning** - `swappiness=10`, optimized dirty ratios, reduced vfs cache pressure
- **RAM-backed /tmp** - 512 MB tmpfs mount for faster temporary file operations
- **Minimal Services** - Disabled: apt-daily, ModemManager, avahi-daemon, CUPS (install when needed)
- **Fast Shutdown** - systemd default timeout reduced to 10s, inhibitor delay 5s

### Desktop

- **KDE Plasma 6** with Breeze Dark theme and purple accent (`#7c3aed`)
- **Wayland + X11** support (X11 preferred in VMs for stability)
- **PipeWire** audio stack with WirePlumber session manager
- **Smooth animations** tuned for responsiveness (0.5x duration factor)
- **No file indexer** - Baloo disabled by default

### VM Auto-Detection

Gaia automatically detects virtual machine environments and applies optimizations:

- Disables KWin compositor (major performance gain in VMs)
- Forces X11/XRender backend
- Disables all animations
- Installs guest tools: `spice-vdagent`, `qemu-guest-agent`, `open-vm-tools`

### Branding

- Custom GRUB theme (dark purple)
- Plymouth boot animation with pulsing Gaia logo
- SDDM login manager with autologin on live session
- Branded Calamares installer with slideshow
- Custom `uname` and `fastfetch` output showing "Gaia Linux"

### Included Software

| Category | Software |
|----------|----------|
| **Shell** | zsh (default), bash |
| **Terminal** | Alacritty (GPU-accelerated) |
| **Browser** | Firefox ESR |
| **File Manager** | Dolphin |
| **Text Editor** | Kate |
| **System** | htop, fastfetch, NetworkManager |
| **Dev Tools** | git, curl, wget |
| **Fonts** | Noto Sans, Hack, Liberation |

### Installer

Gaia includes the **Calamares** graphical installer with:

- Guided & manual partitioning (ext4, btrfs, xfs)
- EFI + Legacy BIOS support
- Minimum requirements: 1 GB RAM, 8 GB storage
- Automatic hardware detection
- Branded slideshow during installation

---

## Screenshots

> *Coming soon - build the ISO and try it yourself!*

---

## Building

### Prerequisites

A Debian or Ubuntu host (bare metal, VM, or container):

```bash
sudo apt install live-build debootstrap curl
```

### Quick Build

```bash
git clone https://github.com/FISCHERgit/Gaia.git
cd Gaia
chmod +x scripts/build.sh
sudo bash scripts/build.sh
```

The ISO will be created in `build/`.

### Fast Build (Recommended for Development)

For significantly faster repeated builds, install an apt cache:

```bash
# Install apt-cacher-ng (auto-detected by build script)
sudo apt install apt-cacher-ng

# Build with RAM-backed build directory (requires >8 GB RAM)
sudo GAIA_TMPFS_BUILD=1 bash scripts/build.sh
```

### Build Performance Features

| Feature | Effect |
|---------|--------|
| **Parallel squashfs** | Uses all CPU cores for compression |
| **apt-cacher-ng** | Auto-detected, caches packages between builds |
| **tmpfs build** | `GAIA_TMPFS_BUILD=1` - build entirely in RAM |
| **Custom mirror** | `GAIA_MIRROR=http://...` - use a faster mirror |
| **force-unsafe-io** | Skips fsync during package install (removed from final image) |
| **--apt-recommends false** | Installs only essential dependencies |
| **Build timer** | Reports total build time and ISO size |

### Cleaning

```bash
# Soft clean - keep package cache for faster rebuilds
bash scripts/clean.sh soft

# Hard clean - remove everything, full fresh start
bash scripts/clean.sh hard
```

---

## Project Structure

```
GaiaLinux/
├── config/
│   ├── package-lists/
│   │   └── gaia.list.chroot          # All packages to include
│   ├── includes.chroot/              # Files overlaid onto the live filesystem
│   │   ├── etc/
│   │   │   ├── skel/.config/         # Default user KDE/GTK/terminal configs
│   │   │   ├── calamares/            # Installer configuration & branding
│   │   │   ├── default/grub          # GRUB defaults
│   │   │   └── sddm.conf.d/         # Display manager config
│   │   ├── usr/share/
│   │   │   ├── backgrounds/gaia/     # Wallpaper
│   │   │   ├── pixmaps/             # Logo
│   │   │   └── plymouth/themes/gaia/ # Boot animation
│   │   └── boot/grub/themes/gaia/    # GRUB theme
│   ├── includes.binary/              # Files on the ISO itself
│   │   └── boot/grub/grub.cfg       # GRUB boot menu
│   ├── includes.installer/           # Debian Installer branding
│   └── hooks/live/
│       ├── 0100-gaia-customization.hook.chroot   # Main customization
│       └── 0200-gaia-kernel-branding.hook.chroot # Kernel branding
├── scripts/
│   ├── build.sh                      # Main build script
│   ├── clean.sh                      # Cleanup script
│   ├── kernel/                       # Custom kernel build system
│   ├── generate-installer-banner.sh  # Installer asset generation
│   └── generate-installer-wallpaper.sh
└── README.md
```

---

## Customization

### Packages

Edit `config/package-lists/gaia.list.chroot` to add or remove packages:

```bash
# Add a package
echo "vlc" >> config/package-lists/gaia.list.chroot

# Rebuild
sudo bash scripts/build.sh
```

### Custom Kernel

Place custom kernel `.deb` files in `config/packages.chroot/`:

```bash
mkdir -p config/packages.chroot
cp linux-image-*.deb linux-headers-*.deb config/packages.chroot/
```

The build script automatically detects and uses custom kernel packages instead of the Debian default.

### Theme

- **Wallpaper**: Replace `config/includes.chroot/usr/share/backgrounds/gaia/wallpaper.png`
- **Logo**: Replace `config/includes.chroot/usr/share/pixmaps/gaia-logo.png`
- **Accent Color**: Search for `#7c3aed` in the hook scripts
- **GRUB Theme**: Edit `config/includes.chroot/boot/grub/themes/gaia/theme.txt`

### Performance Tuning

All performance settings are in `config/hooks/live/0100-gaia-customization.hook.chroot`:

- **sysctl values** - vm.swappiness, dirty ratios, cache pressure
- **zRAM config** - Compression algorithm and size
- **Disabled services** - Add or remove from the systemctl disable list
- **KWin compositor** - OpenGL settings, effects, FPS limits

---

## System Requirements

| | Minimum | Recommended |
|---|---|---|
| **CPU** | x86_64 (64-bit) | 2+ cores |
| **RAM** | 1 GB | 4 GB |
| **Storage** | 8 GB | 20 GB |
| **GPU** | Any (VESA fallback) | OpenGL 3.0+ |
| **Boot** | BIOS or UEFI | UEFI |

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Make your changes
4. Test by building the ISO
5. Submit a Pull Request

### Reporting Issues

Please include:
- Build log (if build fails)
- Hardware info (`lspci`, `lsusb`)
- Whether running in a VM or bare metal
- Steps to reproduce

---

## License

This project is licensed under the GPL-3.0 License. See individual package licenses for included software.

---

<p align="center">
  <strong>Gaia Linux</strong> &mdash; Performance without compromise.
</p>
