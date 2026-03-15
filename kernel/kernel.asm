; CopperOS Kernel
; Switches to VGA mode 13h (320x200, 256 colours) and displays PNG.gif
; centred on the screen, then halts.
;
; The kernel is loaded at physical address 0x1000 by the bootloader so that
; the embedded pixel data (up to ~25 KB) stays well below the 0xA0000 VGA
; boundary and is never inadvertently treated as VGA memory.

[BITS 16]
[ORG 0x1000]

; Image dimensions
IMG_WIDTH  equ 304
IMG_HEIGHT equ 78

; VGA mode 13h screen dimensions
VGA_WIDTH  equ 320
VGA_HEIGHT equ 200

; Pixel offset to centre the image on screen
IMG_X equ (VGA_WIDTH  - IMG_WIDTH)  / 2   ; = 8
IMG_Y equ (VGA_HEIGHT - IMG_HEIGHT) / 2   ; = 61

start:
    ; Ensure DS = 0 (bootloader sets it to 0, but make it explicit)
    xor ax, ax
    mov ds, ax

    ; Switch to VGA mode 13h: 320x200, 256 colours, linear framebuffer at 0xA000:0
    mov ax, 0x0013
    int 0x10

    ; Restore DS = 0 in case the BIOS call changed it
    xor ax, ax
    mov ds, ax

    ; Program the VGA DAC palette from the embedded 6-bit RGB table.
    ; Port 0x3C8 – DAC write-address register (select first entry)
    ; Port 0x3C9 – DAC data register (stream R, G, B bytes for each entry)
    mov dx, 0x3C8
    xor al, al
    out dx, al
    mov dx, 0x3C9
    mov si, palette_data
    mov cx, 256 * 3         ; 256 palette entries, 3 bytes each
.palette_loop:
    lodsb                   ; AL = next palette byte (DS:SI, DS=0)
    out dx, al
    loop .palette_loop

    ; Blit image data into the VGA framebuffer (ES = 0xA000).
    ; The image is copied one row at a time so that the screen stride (320
    ; bytes) is handled correctly even though the image is only 304 pixels wide.
    ; After each rep movsb, DI has advanced IMG_WIDTH bytes; we then add the
    ; remaining VGA_WIDTH-IMG_WIDTH bytes to reach the next screen row.
    mov ax, 0xA000
    mov es, ax

    ; Restore DS = 0 for the pixel copy (DS:SI must point to pixel data)
    xor ax, ax
    mov ds, ax

    ; Starting framebuffer offset: IMG_Y rows down + IMG_X columns in
    mov di, IMG_Y * VGA_WIDTH + IMG_X

    mov si, pixel_data
    mov bp, IMG_HEIGHT      ; Use BP as row counter (preserves CX for movsb)
.draw_loop:
    mov cx, IMG_WIDTH
    rep movsb               ; Copy one row: DS:SI → ES:DI, SI+=IMG_WIDTH, DI+=IMG_WIDTH
    add di, VGA_WIDTH - IMG_WIDTH   ; Skip gap to reach start of next screen row
    dec bp
    jnz .draw_loop

    ; Image displayed — halt the CPU
    hlt
    jmp $

; Embedded image data (generated from PNG.gif by the build toolchain).
; palette_data: 256 entries × 3 bytes, each component scaled to 6-bit (0–63).
; pixel_data:   IMG_WIDTH × IMG_HEIGHT bytes, one byte per pixel (palette index).
palette_data:
    incbin "image_palette.bin"

pixel_data:
    incbin "image_pixels.bin"
