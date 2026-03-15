# CopperOS Build System
#
# Targets:
#   all      - Build the OS disk image (default)
#   iso      - Build a bootable ISO image (os.iso)
#   vmdk     - Build a VirtualBox-compatible VMDK disk image (os.vmdk)
#   run      - Run the OS image in QEMU
#   clean    - Remove all build artifacts
#
# Disk layout:
#   Sector 1  (bytes    0–511) — bootloader (boot/boot.asm)
#   Sectors 2+ (bytes 512+)   — kernel      (kernel/kernel.asm)
#
# The raw disk image (os.img) is padded to 1.44 MB (2880 sectors) so that
# VirtualBox and other hypervisors recognise it as a valid floppy disk image.
#
# KERNEL_SECTORS in boot/boot.asm controls how many sectors the bootloader
# reads. Increase it (and the kernel image) if the kernel grows beyond
# KERNEL_SECTORS * 512 bytes.

# Check for required tools (skip for the 'clean' target)
ifneq ($(MAKECMDGOALS),clean)
ifeq ($(shell which nasm 2>/dev/null),)
$(error nasm not found. Install it first: Ubuntu/Debian: sudo apt-get install nasm -- Fedora: sudo dnf install nasm -- macOS: brew install nasm)
endif
endif

BOOT_SRC   := boot/boot.asm
KERNEL_SRC := kernel/kernel.asm

BOOT_BIN   := boot/boot.bin
KERNEL_BIN := kernel/kernel.bin
OS_IMG     := os.img
OS_ISO     := os.iso
OS_VMDK    := os.vmdk
ISO_DIR    := isodir

# Standard 1.44 MB floppy image size: 2880 sectors × 512 bytes.
# This is the minimum size VirtualBox accepts for a bootable raw disk image.
FLOPPY_SECTORS := 2880

.PHONY: all iso vmdk run clean

all: $(OS_IMG)

$(BOOT_BIN): $(BOOT_SRC)
	nasm -f bin -o $@ $<

$(KERNEL_BIN): $(KERNEL_SRC) kernel/image_palette.bin kernel/image_pixels.bin
	nasm -f bin -I kernel/ -o $@ $<

# Combine the bootloader and kernel into a single raw disk image padded to
# 1.44 MB (FLOPPY_SECTORS × 512 bytes).  The padding is required so that
# VirtualBox (and other hypervisors) accept the image as a valid floppy disk.
$(OS_IMG): $(BOOT_BIN) $(KERNEL_BIN)
	dd if=/dev/zero        of=$(OS_IMG) bs=512 count=$(FLOPPY_SECTORS) 2>/dev/null
	dd if=$(BOOT_BIN)      of=$(OS_IMG) conv=notrunc bs=512 count=1 2>/dev/null
	dd if=$(KERNEL_BIN)    of=$(OS_IMG) conv=notrunc bs=512 seek=1 2>/dev/null

# Build a bootable El Torito ISO image from the raw disk image.
# Requires xorriso: https://www.gnu.org/software/xorriso/
iso: $(OS_ISO)

$(OS_ISO): $(OS_IMG)
	@command -v xorriso >/dev/null 2>&1 || { echo "Error: xorriso not found. Install it first: Ubuntu/Debian: sudo apt-get install xorriso -- Fedora: sudo dnf install xorriso -- macOS: brew install xorriso"; exit 1; }
	mkdir -p $(ISO_DIR)
	cp $(OS_IMG) $(ISO_DIR)/$(OS_IMG)
	xorriso -as mkisofs \
	  -b $(OS_IMG) \
	  -no-emul-boot \
	  -boot-load-size 4 \
	  -boot-info-table \
	  -o $(OS_ISO) \
	  $(ISO_DIR)/
	rm -rf $(ISO_DIR)

run: $(OS_IMG)
	@command -v qemu-system-x86_64 >/dev/null 2>&1 || { echo "Error: qemu-system-x86_64 not found. Install it first: Ubuntu/Debian: sudo apt-get install qemu-system-x86 -- Fedora: sudo dnf install qemu-system-x86 -- macOS: brew install qemu"; exit 1; }
	qemu-system-x86_64 -fda $(OS_IMG)

# Build a VMDK disk image from the raw disk image for use in VirtualBox.
# Requires qemu-img: https://www.qemu.org/
vmdk: $(OS_VMDK)

$(OS_VMDK): $(OS_IMG)
	@command -v qemu-img >/dev/null 2>&1 || { echo "Error: qemu-img not found. Install it first: Ubuntu/Debian: sudo apt-get install qemu-utils -- Fedora: sudo dnf install qemu-img -- macOS: brew install qemu"; exit 1; }
	qemu-img convert -f raw -O vmdk $(OS_IMG) $(OS_VMDK)

clean:
	rm -f $(BOOT_BIN) $(KERNEL_BIN) $(OS_IMG) $(OS_ISO) $(OS_VMDK)
	rm -rf $(ISO_DIR)
