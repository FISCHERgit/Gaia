<p align="center">
  <img src="assets/branding/logo.png" width="120" alt="Gaia Linux Logo">
</p>

<h1 align="center">Gaia Linux</h1>

<p align="center">
  <strong>An independent Linux distribution built from scratch with KDE Plasma 6</strong><br>
  Built from source. Optimized for speed. Zero bloat.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/type-Independent%20LFS-brightgreen?style=flat-square" alt="Independent">
  <img src="https://img.shields.io/badge/desktop-KDE%20Plasma%206-1d99f3?style=flat-square&logo=kde" alt="KDE Plasma 6">
  <img src="https://img.shields.io/badge/package%20manager-pacman-blue?style=flat-square" alt="pacman">
  <img src="https://img.shields.io/badge/init-systemd-gray?style=flat-square" alt="systemd">
  <img src="https://img.shields.io/badge/arch-x86__64-blue?style=flat-square" alt="x86_64">
  <img src="https://img.shields.io/badge/shell-zsh-green?style=flat-square" alt="zsh">
  <img src="https://img.shields.io/badge/license-GPL--3.0-orange?style=flat-square" alt="GPL-3.0">
</p>

---

## What is Gaia Linux?

Gaia Linux is an **independent Linux distribution** built entirely from source using Linux From Scratch (LFS) methodology. Every package — from the toolchain to the desktop — is compiled from source code, giving complete control over the system.

It ships a carefully curated KDE Plasma 6 desktop with the **pacman** package manager, **systemd** init, and aggressive performance tuning out of the box.

### Why Gaia?

| | Typical Distro | Gaia Linux |
|---|---|---|
| **Base** | Derived from Debian/Ubuntu/Arch | Built from scratch (LFS) |
| **Packages** | Pre-compiled binaries | Compiled from source |
| **Package Manager** | apt / dnf | pacman (libalpm) |
| **Boot** | 30+ services at startup | Only what you need |
| **RAM** | 1.2 GB+ idle | ~600 MB idle with zRAM |
| **Disk I/O** | Generic scheduler | SSD/NVMe-optimized (mq-deadline) |
| **Desktop** | Full effects + indexing | Tuned compositor, no file indexer |

---

## Architecture

### Build System (7 Stages)

```
Stage 0: Host Preparation     → Validate host, download sources
Stage 1: Cross-Toolchain      → binutils, gcc, glibc (cross-compiled)
Stage 2: Temporary Tools       → Minimal tools for chroot
Stage 3: Base System           → Native rebuild of all packages in chroot
Stage 4: System Configuration  → Kernel, systemd, networking, branding
Stage 5: Package Manager       → pacman + makepkg (self-hosting)
Stage 6: Desktop               → Xorg/Wayland, Qt6, KDE Plasma 6, apps
Stage 7: ISO Generation        → Bootable hybrid ISO (UEFI + BIOS)
```

### Project Structure

```
GaiaLinux/
├── Makefile                  # Master build orchestrator
├── stages/                   # Build stage scripts (0-7)
├── packages/                 # PKGBUILDs for all packages
│   ├── toolchain/           # gcc, glibc, binutils
│   ├── base/                # kernel, coreutils, systemd, ...
│   ├── pacman/              # pacman + dependencies
│   ├── graphics/            # mesa, xorg, wayland
│   ├── qt/                  # Qt6 modules
│   ├── kde-frameworks/      # KDE Frameworks 6
│   ├── kde-plasma/          # KDE Plasma 6
│   ├── kde-apps/            # Dolphin, Konsole, Kate, ...
│   ├── audio/               # PipeWire + WirePlumber
│   ├── apps/                # Firefox, Alacritty, htop, ...
│   └── ...
├── overlay/                  # Files installed into the rootfs
│   ├── etc/                 # System configs, skel, calamares
│   ├── usr/                 # Scripts, themes, branding
│   └── boot/                # GRUB theme
├── toolchain/config/         # Version pins, kernel config
├── assets/branding/          # Logo, wallpaper
├── scripts/                  # Helper scripts
├── iso/                      # ISO generation configs
└── docs/                     # Documentation
```

---

## Features

### Performance
- **zRAM Compressed Swap** — 50% of RAM as compressed swap
- **Smart I/O Scheduling** — `mq-deadline` for SSDs, `bfq` for HDDs
- **Kernel Tuning** — swappiness=10, optimized dirty ratios
- **RAM-backed /tmp** — 512 MB tmpfs
- **Fast Shutdown** — systemd timeouts reduced to 10s
- **VM Auto-Detection** — disables compositor, forces X11 in VMs

### Desktop
- **KDE Plasma 6** with Breeze Dark + lime green accent (#c4d600)
- **macOS-style floating dock** + slim top panel
- **PipeWire** audio with WirePlumber
- **Baloo file indexer disabled** by default

### Package Management
- **pacman** (Arch-compatible PKGBUILD format)
- Every package has a PKGBUILD for reproducible builds
- System is self-hosting (can rebuild itself)

### Branding
- Custom GRUB theme
- Plymouth boot animation (breathing logo)
- SDDM login with Gaia wallpaper
- Calamares installer with branded slideshow
- Custom fastfetch/neofetch output

### Included Software

| Category | Software |
|----------|----------|
| **Shell** | zsh (default), bash |
| **Terminal** | Alacritty |
| **Browser** | Firefox |
| **File Manager** | Dolphin |
| **Text Editor** | Kate |
| **System** | htop, fastfetch, NetworkManager |
| **Fonts** | Noto Sans, Hack, Liberation |

---

## Building

### Requirements

- Linux x86_64 host system
- GCC 12+, make, bash 5+, bison, gawk, python3, perl
- 50 GB+ free disk space
- 8 GB+ RAM recommended

### Build

```bash
# Full build (all stages)
sudo make GAIA=/mnt/gaia

# Or stage by stage
sudo make stage0    # Download sources
sudo make stage1    # Cross-toolchain
sudo make stage2    # Temporary tools
sudo make stage3    # Base system
sudo make stage4    # System config
sudo make stage5    # pacman
sudo make stage6    # Desktop
sudo make stage7    # ISO
```

### Test

```bash
qemu-system-x86_64 -m 4G -enable-kvm -cdrom gaia-linux-2.0-x86_64.iso
```

### Write to USB

```bash
sudo dd if=gaia-linux-2.0-x86_64.iso of=/dev/sdX bs=4M status=progress
```

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

## License

This project is licensed under the GPL-3.0 License. See individual package licenses for included software.

---

<p align="center">
  <strong>Gaia Linux</strong> — Built from scratch. Performance without compromise.
</p>
