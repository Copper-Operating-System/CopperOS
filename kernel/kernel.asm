; CopperOS Kernel
; This is the minimal kernel loaded by the bootloader.
; It prints a boot confirmation message and halts.

[BITS 16]
[ORG 0x8000]

start:
    ; Print kernel boot message
    mov si, msg_booted
    call print_string

    ; Halt the CPU — the OS is running
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

msg_booted db 'CopperOS kernel has booted successfully!', 0x0D, 0x0A, 0
