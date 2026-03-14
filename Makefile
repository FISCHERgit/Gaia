# Gaia Linux - LFS Build System
# Build an independent Linux distribution from source

GAIA       ?= /mnt/gaia
GAIA_TGT   := x86_64-gaia-linux-gnu
NPROC      := $(shell nproc 2>/dev/null || echo 2)
ISO_NAME   := gaia-linux-2.0-x86_64.iso
PROJECT    := $(shell pwd)

export GAIA GAIA_TGT NPROC PROJECT

.PHONY: all stage0 stage1 stage2 stage3 stage4 stage5 stage6 stage7 iso clean distclean help

all: stage0 stage1 stage2 stage3 stage4 stage5 stage6 stage7
	@echo ""
	@echo "=== Gaia Linux build complete ==="
	@echo "ISO: $(ISO_NAME)"

help:
	@echo "Gaia Linux LFS Build System"
	@echo ""
	@echo "Usage: make [target] [GAIA=/path/to/build]"
	@echo ""
	@echo "Stages:"
	@echo "  stage0    - Validate host & download sources"
	@echo "  stage1    - Build cross-toolchain"
	@echo "  stage2    - Build temporary tools"
	@echo "  stage3    - Build base system (chroot)"
	@echo "  stage4    - System configuration (systemd, kernel)"
	@echo "  stage5    - Build pacman package manager"
	@echo "  stage6    - Build desktop (KDE Plasma 6)"
	@echo "  stage7    - Generate bootable ISO"
	@echo ""
	@echo "Other:"
	@echo "  iso       - Alias for stage7"
	@echo "  clean     - Remove toolchain and sources"
	@echo "  distclean - Remove entire build tree"
	@echo ""
	@echo "Variables:"
	@echo "  GAIA      - Build root (default: /mnt/gaia)"
	@echo "  NPROC     - Parallel jobs (default: $(NPROC))"

stage0:
	@echo "=== Stage 0: Host Preparation ==="
	@bash stages/stage0-prepare.sh

stage1: stage0
	@echo "=== Stage 1: Cross-Toolchain ==="
	@bash stages/stage1-toolchain.sh

stage2: stage1
	@echo "=== Stage 2: Temporary Tools ==="
	@bash stages/stage2-temptools.sh

stage3: stage2
	@echo "=== Stage 3: Base System (chroot) ==="
	@bash stages/stage3-base.sh

stage4: stage3
	@echo "=== Stage 4: System Configuration ==="
	@bash stages/stage4-system.sh

stage5: stage4
	@echo "=== Stage 5: Package Manager (pacman) ==="
	@bash stages/stage5-pacman.sh

stage6: stage5
	@echo "=== Stage 6: Desktop (KDE Plasma 6) ==="
	@bash stages/stage6-desktop.sh

stage7: stage6
	@echo "=== Stage 7: ISO Generation ==="
	@bash stages/stage7-iso.sh

iso: stage7

clean:
	@echo "Cleaning toolchain and sources..."
	rm -rf $(GAIA)/tools $(GAIA)/sources
	@echo "Done."

distclean:
	@echo "Removing entire build tree at $(GAIA)..."
	rm -rf $(GAIA)
	rm -f $(ISO_NAME)
	@echo "Done."
