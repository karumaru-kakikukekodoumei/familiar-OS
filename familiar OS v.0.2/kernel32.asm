[BITS 32]
org 0x00080000      ; ★ ここは“配置想定”の宣言。nasm -f bin なら実体は生バイナリ

start:
    cli
.hang:
    hlt
    jmp .hang
