#!/bin/bash
# Gaia Linux - Stage 7: ISO Generation
# Create a bootable hybrid ISO (UEFI + BIOS) with live session

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../toolchain/config/toolchain.conf"

echo "=== Gaia Linux Stage 7: ISO Generation ==="

ISO_ROOT="$GAIA/build/iso-root"
ISO_NAME="${PROJECT}/gaia-linux-2.0-x86_64.iso"
NPROC="${NPROC:-$(nproc)}"

# --- Create ISO directory structure ---
echo "Creating ISO structure..."
rm -rf "$ISO_ROOT"
mkdir -p "$ISO_ROOT"/{boot/grub/themes/gaia,EFI/BOOT,live,isolinux}

# --- Copy kernel and initramfs ---
echo "Copying kernel..."
VMLINUZ=$(find "$GAIA/boot" -name 'vmlinuz*' -type f | sort -V | tail -1)
INITRD=$(find "$GAIA/boot" -name 'initrd*' -o -name 'initramfs*' | sort -V | tail -1)

if [ -z "$VMLINUZ" ]; then
    echo "Error: No kernel found in $GAIA/boot"
    exit 1
fi

cp -v "$VMLINUZ" "$ISO_ROOT/live/vmlinuz"

if [ -n "$INITRD" ]; then
    cp -v "$INITRD" "$ISO_ROOT/live/initrd.img"
else
    echo "Warning: No initramfs found. Generating with dracut..."
    KVER=$(basename "$VMLINUZ" | sed 's/vmlinuz-//')
    chroot "$GAIA" dracut --force --add "dmsquash-live livenet" \
        /boot/initrd-gaia.img "$KVER" 2>/dev/null || {
        echo "  dracut failed — creating minimal initramfs"
        # Create a minimal initramfs that can find and mount squashfs
        bash "$SCRIPT_DIR/../iso/mkinitramfs.sh" "$GAIA" "$ISO_ROOT/live/initrd.img"
    }
    [ -f "$GAIA/boot/initrd-gaia.img" ] && cp -v "$GAIA/boot/initrd-gaia.img" "$ISO_ROOT/live/initrd.img"
fi

# --- Create squashfs ---
echo ""
echo "Creating squashfs filesystem image..."
echo "This will take several minutes..."

mksquashfs "$GAIA" "$ISO_ROOT/live/filesystem.squashfs" \
    -comp xz \
    -Xbcj x86 \
    -b 1M \
    -processors "$NPROC" \
    -e boot/grub \
    -e dev \
    -e proc \
    -e sys \
    -e run \
    -e tmp \
    -e build \
    -e sources \
    -e tools \
    -noappend

SQFS_SIZE=$(du -h "$ISO_ROOT/live/filesystem.squashfs" | cut -f1)
echo "  squashfs size: $SQFS_SIZE"

# --- GRUB configuration for live boot ---
echo "Setting up GRUB..."

# Copy Gaia GRUB theme
if [ -d "$GAIA/boot/grub/themes/gaia" ]; then
    cp -rv "$GAIA/boot/grub/themes/gaia/"* "$ISO_ROOT/boot/grub/themes/gaia/"
fi

cat > "$ISO_ROOT/boot/grub/grub.cfg" << 'GRUBCFG'
# Gaia Linux Live Boot

set timeout=5
set default=0

insmod all_video
insmod gfxterm
insmod png
loadfont unicode

set gfxmode=auto
terminal_output gfxterm

# Load Gaia theme
set theme=/boot/grub/themes/gaia/theme.txt

menuentry "Gaia Linux (Live)" --class gaia --class linux {
    linux /live/vmlinuz boot=live toram quiet splash
    initrd /live/initrd.img
}

menuentry "Gaia Linux (Live, Safe Graphics)" --class gaia --class linux {
    linux /live/vmlinuz boot=live toram nomodeset quiet
    initrd /live/initrd.img
}

menuentry "Gaia Linux (Live, Auto Install)" --class gaia --class linux {
    linux /live/vmlinuz boot=live toram quiet splash autoinstall
    initrd /live/initrd.img
}

menuentry "Gaia Linux (Live, Debug)" --class gaia --class linux {
    linux /live/vmlinuz boot=live toram debug
    initrd /live/initrd.img
}

menuentry "System Setup (UEFI Firmware)" {
    fwsetup
}

menuentry "Reboot" {
    reboot
}

menuentry "Shutdown" {
    halt
}
GRUBCFG

# --- Create EFI boot image ---
echo "Creating EFI boot image..."

# Find GRUB EFI binary
GRUB_EFI=""
for path in "$GAIA/usr/lib/grub/x86_64-efi" "/usr/lib/grub/x86_64-efi"; do
    if [ -d "$path" ]; then
        GRUB_EFI="$path"
        break
    fi
done

if [ -n "$GRUB_EFI" ]; then
    grub-mkstandalone \
        --format=x86_64-efi \
        --output="$ISO_ROOT/EFI/BOOT/BOOTX64.EFI" \
        --locales="" \
        --fonts="" \
        "boot/grub/grub.cfg=$ISO_ROOT/boot/grub/grub.cfg" 2>/dev/null || \
    grub-mkimage \
        -O x86_64-efi \
        -o "$ISO_ROOT/EFI/BOOT/BOOTX64.EFI" \
        -p /boot/grub \
        part_gpt part_msdos fat iso9660 normal linux echo \
        all_video test multiboot2 search search_fs_uuid \
        search_fs_file search_label gfxmenu gfxterm \
        gfxterm_background efi_gop efi_uga 2>/dev/null || true
fi

# Create EFI system partition image
dd if=/dev/zero of="$ISO_ROOT/boot/efiboot.img" bs=1M count=10
mkfs.fat -F12 "$ISO_ROOT/boot/efiboot.img"
EFIMNT=$(mktemp -d)
mount "$ISO_ROOT/boot/efiboot.img" "$EFIMNT"
mkdir -p "$EFIMNT/EFI/BOOT"
[ -f "$ISO_ROOT/EFI/BOOT/BOOTX64.EFI" ] && \
    cp "$ISO_ROOT/EFI/BOOT/BOOTX64.EFI" "$EFIMNT/EFI/BOOT/"
umount "$EFIMNT"
rmdir "$EFIMNT"

# --- Legacy BIOS boot (isolinux) ---
echo "Setting up legacy BIOS boot..."

# Find isolinux files
for path in "$GAIA/usr/lib/syslinux/bios" "$GAIA/usr/share/syslinux" \
            "/usr/lib/syslinux/bios" "/usr/share/syslinux"; do
    if [ -d "$path" ]; then
        cp -v "$path/isolinux.bin" "$ISO_ROOT/isolinux/" 2>/dev/null || true
        cp -v "$path/ldlinux.c32" "$ISO_ROOT/isolinux/" 2>/dev/null || true
        cp -v "$path/libutil.c32" "$ISO_ROOT/isolinux/" 2>/dev/null || true
        cp -v "$path/libcom32.c32" "$ISO_ROOT/isolinux/" 2>/dev/null || true
        cp -v "$path/menu.c32" "$ISO_ROOT/isolinux/" 2>/dev/null || true
        break
    fi
done

cat > "$ISO_ROOT/isolinux/isolinux.cfg" << 'ISOCFG'
DEFAULT live
TIMEOUT 50
PROMPT 0

MENU TITLE Gaia Linux

LABEL live
    MENU LABEL Gaia Linux (Live)
    KERNEL /live/vmlinuz
    APPEND initrd=/live/initrd.img boot=live toram quiet splash

LABEL safe
    MENU LABEL Gaia Linux (Safe Graphics)
    KERNEL /live/vmlinuz
    APPEND initrd=/live/initrd.img boot=live toram nomodeset quiet
ISOCFG

# --- Generate ISO ---
echo ""
echo "Generating ISO image..."

ISOHDPFX=""
for path in "$GAIA/usr/lib/grub/i386-pc/boot_hybrid.img" \
            "/usr/lib/grub/i386-pc/boot_hybrid.img" \
            "$GAIA/usr/share/syslinux/isohdpfx.bin" \
            "/usr/share/syslinux/isohdpfx.bin"; do
    if [ -f "$path" ]; then
        ISOHDPFX="$path"
        break
    fi
done

XORRISO_OPTS=(
    -as mkisofs
    -iso-level 3
    -full-iso9660-filenames
    -joliet
    -joliet-long
    -rational-rock
    -volid "GAIALINUX"
    -appid "Gaia Linux 2.0"
    -publisher "Gaia Project"
)

# Add EFI boot
if [ -f "$ISO_ROOT/boot/efiboot.img" ]; then
    XORRISO_OPTS+=(
        -eltorito-alt-boot
        -e boot/efiboot.img
        -no-emul-boot
        -isohybrid-gpt-basdat
    )
fi

# Add BIOS boot
if [ -f "$ISO_ROOT/isolinux/isolinux.bin" ] && [ -n "$ISOHDPFX" ]; then
    XORRISO_OPTS+=(
        -eltorito-boot isolinux/isolinux.bin
        -eltorito-catalog isolinux/boot.cat
        -no-emul-boot
        -boot-load-size 4
        -boot-info-table
        -isohybrid-mbr "$ISOHDPFX"
    )
fi

XORRISO_OPTS+=(
    -output "$ISO_NAME"
    "$ISO_ROOT"
)

xorriso "${XORRISO_OPTS[@]}"

# --- Summary ---
echo ""
echo "============================================"
ISO_SIZE=$(du -h "$ISO_NAME" | cut -f1)
echo "  ISO generated: $ISO_NAME"
echo "  Size: $ISO_SIZE"
echo "============================================"
echo ""
echo "=== Gaia Linux build complete! ==="
echo ""
echo "Boot the ISO with:"
echo "  qemu-system-x86_64 -m 4G -enable-kvm -cdrom $ISO_NAME"
echo ""
echo "Or write to USB:"
echo "  sudo dd if=$ISO_NAME of=/dev/sdX bs=4M status=progress"
