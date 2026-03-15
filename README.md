# CopperOS

A minimal x86 operating system featuring a two-stage bootloader and a kernel that confirms it has booted.

## Architecture

```
os.img (raw disk image)
├── Sector 1 — boot/boot.asm   (512 bytes, MBR bootloader)
└── Sector 2 — kernel/kernel.asm (loaded at 0x8000)
```

### Bootloader (`boot/boot.asm`)
- Runs in 16-bit real mode at address `0x7C00` (standard BIOS load address)
- Prints `Loading CopperOS...`
- Loads the kernel from disk sector 2 into memory at `0x8000` using BIOS INT 13h
- Jumps to the kernel

### Kernel (`kernel/kernel.asm`)
- Runs in 16-bit real mode at address `0x8000`
- Prints `CopperOS kernel has booted successfully!`
- Halts the CPU

## Requirements

- [NASM](https://www.nasm.us/) — Netwide Assembler
- [xorriso](https://www.gnu.org/software/xorriso/) — to build the ISO image (`make iso`)
- [QEMU](https://www.qemu.org/) — to run the OS image (optional)

## Building

```bash
make
```

This produces `os.img`, a raw disk image containing the bootloader and kernel.

### Building a bootable ISO

```bash
make iso
```

This produces `os.iso`, a bootable El Torito ISO image suitable for burning to a CD/DVD or booting in a virtual machine.

## Running

```bash
make run
```

This launches QEMU with the disk image. You should see:

```
Loading CopperOS...
CopperOS kernel has booted successfully!
```

## Cleaning

```bash
make clean
```

## Releases

Pre-built ISO images are available on the [Releases](../../releases) page.
A new release is automatically published whenever a version tag is pushed (e.g. `v0.1.0-beta`).
Tags that include `alpha`, `beta`, `rc`, or `pre` are published as pre-releases.

