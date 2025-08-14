[BITS 32]
[ORG 0x00080000]

section .text
global _start
_start:
    ; clear whole text screen (80x25) to avoid overlap with BIOS/iPXE messages
    mov edi, 0xB8000              ; VGA text VRAM base
    mov ax, 0x0F20                ; ' ' (space) with bright white attribute
    mov ecx, 80*25
    rep stosw

    mov esi, ascii_art
    mov edi, 0xB8000              ; VGA text VRAM
    ; print until null terminator

.print_loop:
    mov al, [esi]
    test al, al
    jz .hang                      ; 文字列終端 0 を検出したら終了
    cmp al, 0x0A                  ; LF を改行として扱う
    je .newline
    mov ah, 0x0F                  ; bright white
    stosw                         ; [edi]=ax, edi+=2
    inc esi
    jmp .print_loop

.newline:
    ; 次の行頭へ
    mov eax, edi
    sub eax, 0xB8000
    shr eax, 1                    ; 文字数に換算
    mov ebx, 80
    xor edx, edx
    div ebx                       ; edx = 現在行の列
    test edx, edx
    jz .at_line_start             ; 既に次行の先頭にいる（余計に進めない）
    mov eax, 80
    sub eax, edx                  ; 残り列ぶん
    shl eax, 1
    add edi, eax
.at_line_start:
    inc esi                        ; '\n' を飛ばす
    jmp .print_loop

.hang:
    hlt
    jmp .hang

section .data
ascii_art db " #######                    ##   ###    ##                     #####    #####   ", 0x0A
          db "  ##   #                          ##                          ##   ##  ##   ##  ", 0x0A
          db "  ## #     ####   ##  ##   ###    ##   ###    ####   ######   ##   ##  #        ", 0x0A
          db "  ####        ##  #######   ##    ##    ##       ##   ##  ##  ##   ##   #####   ", 0x0A
          db "  ## #     #####  ## # ##   ##    ##    ##    #####   ##      ##   ##       ##  ", 0x0A
          db "  ##      ##  ##  ##   ##   ##    ##    ##   ##  ##   ##      ##   ##  ##   ##  ", 0x0A
          db " ####      #####  ##   ##  ####  ####  ####   #####  ####      #####    #####   ", 0x0A
          db 0
ascii_len equ $-ascii_art
