# CopperOS Build System
#
# Targets:
#   all      - Build the OS disk image (default)
#   run      - Run the OS image in QEMU
#   clean    - Remove all build artifacts
#
# Disk layout:
#   Sector 1  (bytes    0–511) — bootloader (boot/boot.asm)
#   Sectors 2+ (bytes 512+)   — kernel      (kernel/kernel.asm)
#
# KERNEL_SECTORS in boot/boot.asm controls how many sectors the bootloader
# reads. Increase it (and the kernel image) if the kernel grows beyond
# KERNEL_SECTORS * 512 bytes.

BOOT_SRC   := boot/boot.asm
KERNEL_SRC := kernel/kernel.asm

BOOT_BIN   := boot/boot.bin
KERNEL_BIN := kernel/kernel.bin
OS_IMG     := os.img

.PHONY: all run clean

all: $(OS_IMG)

$(BOOT_BIN): $(BOOT_SRC)
	nasm -f bin -o $@ $<

$(KERNEL_BIN): $(KERNEL_SRC)
	nasm -f bin -o $@ $<

# Combine the bootloader and kernel into a single raw disk image.
$(OS_IMG): $(BOOT_BIN) $(KERNEL_BIN)
	cat $(BOOT_BIN) $(KERNEL_BIN) > $(OS_IMG)

run: $(OS_IMG)
	qemu-system-x86_64 -drive format=raw,file=$(OS_IMG)

clean:
	rm -f $(BOOT_BIN) $(KERNEL_BIN) $(OS_IMG)
