; CopperOS Bootloader
; This is a 16-bit x86 real-mode bootloader that:
;   1. Prints a loading message
;   2. Loads the kernel from disk sector 2 into memory at 0x8000
;   3. Jumps to the kernel

[BITS 16]
[ORG 0x7C00]

; Number of 512-byte sectors reserved for the kernel.
; Must be large enough to cover kernel code + embedded image data (~24 KB).
KERNEL_SECTORS    equ 50
SECTORS_PER_TRACK equ 18    ; Standard 1.44 MB floppy geometry

start:
    ; Set up segment registers and stack
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    ; Store the boot drive number (passed in DL by BIOS)
    mov [boot_drive], dl

    ; Print loading message
    mov si, msg_loading
    call print_string

    ; Load kernel from disk using BIOS INT 13h.
    ; Reading a large kernel may cross track boundaries, so we load one sector
    ; at a time, advancing the CHS address (cylinder / head / sector) manually.
    ;
    ; 1.44 MB floppy geometry: 80 cylinders, 2 heads, 18 sectors per track.
    ; The kernel starts at CHS (0, 0, 2) — sector 2, immediately after the MBR.
    ; Kernel is loaded at physical 0x1000 (ES=0, BX=0x1000) so that the large
    ; embedded pixel data stays below 0xA0000 and avoids the VGA address window.
    mov bx, 0x1000          ; ES:BX destination (ES = 0 from setup above)
    mov ch, 0               ; Cylinder 0
    mov dh, 0               ; Head 0
    mov cl, 2               ; Sector 2 (1-indexed)
    mov si, KERNEL_SECTORS  ; Sector counter

.read_loop:
    mov ah, 0x02            ; BIOS: read sectors
    mov al, 1               ; Read exactly one sector per call
    mov dl, [boot_drive]
    int 0x13
    jc disk_error

    add bx, 512             ; Advance destination buffer by one sector

    ; Advance CHS: increment sector, wrap at SECTORS_PER_TRACK
    inc cl
    cmp cl, SECTORS_PER_TRACK + 1
    jb .sector_ok
    mov cl, 1               ; Reset to sector 1
    inc dh                  ; Next head
    cmp dh, 2
    jb .sector_ok
    mov dh, 0               ; Reset head, advance cylinder
    inc ch
.sector_ok:
    dec si
    jnz .read_loop

    ; Jump to the loaded kernel
    jmp 0x0000:0x1000

; Disk error handler: prints an error message including the BIOS error code
; stored in AH after INT 13h.
disk_error:
    mov [disk_error_code], ah  ; Save BIOS error code before AH is clobbered
    mov si, msg_disk_error
    call print_string
    ; Print the error code as two hex digits
    mov al, [disk_error_code]
    call print_hex_byte
    mov si, msg_crlf
    call print_string
    hlt
    jmp $

; Prints a null-terminated string pointed to by SI using BIOS teletype output
print_string:
    mov ah, 0x0E        ; BIOS teletype function
.loop:
    lodsb               ; Load byte from SI into AL, increment SI
    cmp al, 0
    je .done
    int 0x10            ; Print character in AL
    jmp .loop
.done:
    ret

; Prints the byte in AL as two uppercase hex digits
print_hex_byte:
    push ax
    ; Print high nibble
    shr al, 4
    call print_hex_nibble
    pop ax
    ; Print low nibble
    and al, 0x0F
    call print_hex_nibble
    ret

print_hex_nibble:
    cmp al, 10
    jl .digit
    add al, 'A' - 10    ; A-F
    jmp .print
.digit:
    add al, '0'         ; 0-9
.print:
    mov ah, 0x0E
    int 0x10
    ret

msg_loading     db 'Loading CopperOS...', 0x0D, 0x0A, 0
msg_disk_error  db 'Disk read error (code 0x', 0
msg_crlf        db 0x0D, 0x0A, 0
boot_drive      db 0
disk_error_code db 0

; Pad to 510 bytes and append the MBR boot signature
times 510-($-$$) db 0
dw 0xAA55
