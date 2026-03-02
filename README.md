# Gaia Linux

A custom Debian-based Linux distribution.

## Base
- **Parent Distro:** Debian (Bookworm / Stable)
- **Build System:** live-build
- **Architecture:** amd64

## Project Structure

```
GaiaLinux/
├── config/
│   ├── package-lists/       # Package selections (.list.chroot files)
│   ├── includes.chroot/     # Files overlaid onto the live filesystem
│   │   └── etc/skel/        # Default user home skeleton
│   ├── hooks/live/          # Build-time hook scripts
│   └── bootloaders/         # GRUB/syslinux customization
├── scripts/
│   ├── build.sh             # Main build script
│   └── clean.sh             # Cleanup script
├── assets/
│   └── branding/            # Logos, wallpapers, Plymouth themes
├── docs/                    # Documentation
└── README.md
```

## Prerequisites

Build must run on a Debian/Ubuntu host (or VM/container):

```bash
sudo apt install live-build debootstrap
```

## Build

```bash
cd GaiaLinux
chmod +x scripts/build.sh
sudo ./scripts/build.sh
```

The ISO will be output to `build/`.

## Customization

- **Packages:** Edit `config/package-lists/gaia.list.chroot`
- **Desktop Environment:** Configured in package list and hooks
- **Branding:** Place wallpapers/logos in `assets/branding/`
- **System Config:** Add files to `config/includes.chroot/`
