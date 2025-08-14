; familiar OS bootloader - boot.asm
; BIOS起動→A20→kernel.binをCHSで読み込み→32bit移行→0x00080000へジャンプ

%include "kernel_sectors.inc"     ; ← ビルド時に生成（KERNEL_SECTORS 定義）

[BITS 16]
[ORG 0x7C00]

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    mov [boot_drive], dl          ; ブートドライブ退避（FDD=00h/HDD=80h）

; --- A20 enable (8042) ---
.wait_ibf_clear:
    in al, 0x64
    test al, 2
    jnz .wait_ibf_clear
    mov al, 0xD1
    out 0x64, al
.wait_ibf_clear2:
    in al, 0x64
    test al, 2
    jnz .wait_ibf_clear2
    mov al, 0xDF
    out 0x60, al

; --- kernel.bin を物理 0x00080000 へ読み込み（セクタ2から KERNEL_SECTORS 個） ---
    mov bx, 0x8000               ; ES=0x8000 → 物理 0x00080000
    mov es, bx
    xor bx, bx                   ; BX=0
    mov dh, 0                    ; head 0
    mov dl, [boot_drive]         ; ブートドライブ
    mov ch, 0                    ; cylinder 0
    mov cl, 2                    ; sector 2 から
    mov ah, 2                    ; INT13h read sectors (CHS)
    mov al, KERNEL_SECTORS       ; ← ここが可変
    int 0x13
    jc disk_error

; --- GDT & 32bit へ ---
    lgdt [gdt_desc]
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp 0x08:protected_entry

disk_error:
    mov si, disk_err_msg
.print:
    lodsb
    or al, al
    jz .hang
    mov ah, 0x0E
    mov bx, 0x0007
    int 0x10
    jmp .print
.hang:
    jmp .hang

; ================= 32-bit =================
[BITS 32]
protected_entry:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x88000

    jmp 0x00080000               ; カーネルへ

; ================ data (16bit) ============
[BITS 16]
disk_err_msg db 'Disk read error!',0
boot_drive   db 0

align 8
gdt_start:
    dq 0x0000000000000000
    dq 0x00CF9A000000FFFF       ; code base=0 limit=4GB
    dq 0x00CF92000000FFFF       ; data base=0 limit=4GB
gdt_end:
gdt_desc:
    dw gdt_end - gdt_start - 1
    dd gdt_start

times 510-($-$$) db 0
dw 0xAA55
