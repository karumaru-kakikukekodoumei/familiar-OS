[BITS 32]
[ORG 0x00080000]

section .text
global _start

_start:
    ; スタックポインターを設定
    mov esp, 0x88000

    ; 画面クリア
    call clear_screen
    
    ; アスキーアートを表示
    call print_ascii_art
    
    ; IDTを設定
    call setup_idt
    
    ; PICを初期化
    call init_pic
    
    ; キーボードを初期化
    call init_keyboard
    
    ; 割り込み有効化
    sti
    
    ; プロンプト表示
    call print_prompt
    
    ; メインループ
main_loop:
    hlt                    ; 割り込み待ち
    jmp main_loop

; ================ 画面関連 ================
clear_screen:
    push eax
    push ecx
    push edi
    
    mov edi, 0xB8000
    mov ax, 0x0F20         ; 明るい白文字、黒背景、スペース
    mov ecx, 80*25
    rep stosw
    
    pop edi
    pop ecx
    pop eax
    ret

print_ascii_art:
    push esi
    push edi
    push eax
    
    mov esi, ascii_art
    mov edi, 0xB8000
    
.print_loop:
    mov al, [esi]
    test al, al
    jz .done
    cmp al, 0x0A
    je .newline
    mov ah, 0x0F           ; 明るい白文字
    stosw
    inc esi
    jmp .print_loop

.newline:
    mov eax, edi
    sub eax, 0xB8000
    shr eax, 1
    mov ebx, 80
    xor edx, edx
    div ebx
    test edx, edx
    jz .at_line_start
    mov eax, 80
    sub eax, edx
    shl eax, 1
    add edi, eax
.at_line_start:
    inc esi
    jmp .print_loop

.done:
    ; カーソル位置を保存（次の行へ）
    mov eax, edi
    sub eax, 0xB8000
    shr eax, 1
    add eax, 80            ; 次の行
    mov [cursor_pos], eax
    
    pop eax
    pop edi
    pop esi
    ret

print_prompt:
    push esi
    push edi
    push eax
    push ebx
    
    ; カーソル位置に移動
    mov eax, [cursor_pos]
    mov ebx, eax
    shl eax, 1             ; バイト位置に変換
    add eax, 0xB8000
    mov edi, eax
    
    ; プロンプト文字列を表示
    mov esi, prompt_str
.loop:
    mov al, [esi]
    test al, al
    jz .done
    mov ah, 0x0E           ; 明るい黄色
    stosw
    inc esi
    inc ebx
    jmp .loop
    
.done:
    mov [cursor_pos], ebx
    call update_cursor
    
    pop ebx
    pop eax
    pop edi
    pop esi
    ret

; カーソル位置を更新（ハードウェアカーソル）
update_cursor:
    push eax
    push edx
    
    mov eax, [cursor_pos]
    
    ; 上位8ビット
    mov dx, 0x3D4
    mov al, 0x0E
    out dx, al
    mov dx, 0x3D5
    mov eax, [cursor_pos]
    shr eax, 8
    out dx, al
    
    ; 下位8ビット
    mov dx, 0x3D4
    mov al, 0x0F
    out dx, al
    mov dx, 0x3D5
    mov eax, [cursor_pos]
    and eax, 0xFF
    out dx, al
    
    pop edx
    pop eax
    ret

; ================ 割り込み関連 ================
setup_idt:
    push eax
    push ebx
    push ecx
    
    ; IDTエントリをクリア
    mov edi, idt_start
    mov eax, 0
    mov ecx, 256 * 2       ; 256エントリ * 8バイト / 4
    rep stosd
    
    ; キーボード割り込み（IRQ1 = INT 21h）を設定
    mov eax, keyboard_isr
    mov bx, 0x08           ; カーネルコードセグメント
    mov cx, 0x8E00         ; Present, DPL=0, 32bit interrupt gate
    
    ; IDTエントリ21h（IRQ1）に設定
    mov edi, idt_start + (0x21 * 8)
    mov [edi], ax          ; オフセット下位16ビット
    mov [edi+2], bx        ; セグメントセレクタ
    mov [edi+4], cx        ; フラグ
    shr eax, 16
    mov [edi+6], ax        ; オフセット上位16ビット
    
    ; IDTRを設定
    lidt [idt_desc]
    
    pop ecx
    pop ebx
    pop eax
    ret

init_pic:
    push eax
    
    ; マスターPIC初期化
    mov al, 0x11           ; ICW1: 初期化コマンド
    out 0x20, al
    mov al, 0x20           ; ICW2: 割り込みベクター開始番号（32）
    out 0x21, al
    mov al, 0x04           ; ICW3: スレーブPICはIRQ2に接続
    out 0x21, al
    mov al, 0x01           ; ICW4: 8086モード
    out 0x21, al
    
    ; スレーブPIC初期化
    mov al, 0x11           ; ICW1
    out 0xA0, al
    mov al, 0x28           ; ICW2: 割り込みベクター開始番号（40）
    out 0xA1, al
    mov al, 0x02           ; ICW3: スレーブID
    out 0xA1, al
    mov al, 0x01           ; ICW4
    out 0xA1, al
    
    ; IRQ1（キーボード）のみ有効化
    mov al, 0xFD           ; すべてマスクしてIRQ1のみ有効
    out 0x21, al
    mov al, 0xFF           ; スレーブは全マスク
    out 0xA1, al
    
    pop eax
    ret

init_keyboard:
    ; キーボードコントローラーの初期化は基本的に不要
    ; PS/2キーボードは通常すでに動作している
    ret

; ================ キーボード割り込みハンドラー ================
keyboard_isr:
    pushad
    
    ; キーボードからスキャンコードを読み取り
    in al, 0x60
    
    ; ブレイクコード（キーリリース）はスキップ
    test al, 0x80
    jnz .done
    
    ; スキャンコード→ASCII変換
    call scancode_to_ascii
    test al, al
    jz .done
    
    ; 特殊キー処理
    cmp al, 0x08           ; Backspace
    je .handle_backspace
    cmp al, 0x0D           ; Enter
    je .handle_enter
    
    ; 通常文字を表示
    call print_char
    jmp .done

.handle_backspace:
    call handle_backspace
    jmp .done

.handle_enter:
    call handle_enter
    jmp .done

.done:
    ; PICにEOI（End of Interrupt）を送信
    mov al, 0x20
    out 0x20, al
    
    popad
    iret

; スキャンコードをASCIIに変換
scancode_to_ascii:
    push ebx
    
    cmp al, 128
    jae .invalid
    
    movzx ebx, al
    mov al, [scancode_table + ebx]
    
.invalid:
    pop ebx
    ret

; 文字を画面に表示
print_char:
    push eax
    push ebx
    push edi
    
    ; カーソル位置に文字を表示
    mov ebx, [cursor_pos]
    shl ebx, 1
    add ebx, 0xB8000
    mov ah, 0x0F           ; 明るい白文字
    mov [ebx], ax
    
    ; カーソルを進める
    inc dword [cursor_pos]
    call update_cursor
    
    pop edi
    pop ebx
    pop eax
    ret

; バックスペース処理
handle_backspace:
    push eax
    push ebx
    push edi
    
    ; プロンプトより前には戻れない
    mov eax, [cursor_pos]
    mov ebx, [prompt_start]
    cmp eax, ebx
    jle .done
    
    ; カーソルを戻す
    dec dword [cursor_pos]
    
    ; 文字を削除（スペースで上書き）
    mov ebx, [cursor_pos]
    shl ebx, 1
    add ebx, 0xB8000
    mov word [ebx], 0x0F20 ; 白いスペース
    
    call update_cursor

.done:
    pop edi
    pop ebx
    pop eax
    ret

; Enter処理
handle_enter:
    push eax
    
    ; 新しい行に移動
    mov eax, [cursor_pos]
    add eax, 80
    mov ebx, 80
    xor edx, edx
    div ebx
    mul ebx                ; 行の先頭に移動
    mov [cursor_pos], eax
    mov [prompt_start], eax
    
    ; 新しいプロンプトを表示
    call print_prompt
    
    pop eax
    ret

; ================ データセクション ================
section .data

ascii_art db " #######                    ##   ###    ##                     #####    #####   ", 0x0A
          db "  ##   #                          ##                          ##   ##  ##   ##  ", 0x0A
          db "  ## #     ####   ##  ##   ###    ##   ###    ####   ######   ##   ##  #        ", 0x0A
          db "  ####        ##  #######   ##    ##    ##       ##   ##  ##  ##   ##   #####   ", 0x0A
          db "  ## #     #####  ## # ##   ##    ##    ##    #####   ##      ##   ##       ##  ", 0x0A
          db "  ##      ##  ##  ##   ##   ##    ##    ##   ##  ##   ##      ##   ##  ##   ##  ", 0x0A
          db " ####      #####  ##   ##  ####  ####  ####   #####  ####      #####    #####   ", 0x0A
          db 0x0A, 0x0A
          db " Welcome to familiar OS v0.1", 0x0A
          db 0

prompt_str db "familiar> ", 0

; スキャンコードテーブル（US配列）
scancode_table:
    db 0,    0, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 0x08, 0    ; 00-0F
    db 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', 0x0D, 0, 'a', 's'  ; 10-1F
    db 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', "'", '`', 0, '\', 'z', 'x', 'c', 'v'   ; 20-2F
    db 'b', 'n', 'm', ',', '.', '/', 0, '*', 0, ' ', 0, 0, 0, 0, 0, 0                  ; 30-3F
    times (128-64) db 0                                                                  ; 40-7F

cursor_pos    dd 0
prompt_start  dd 0

; IDT関連
align 8
idt_start:
    times 256*8 db 0       ; 256エントリ * 8バイト

idt_desc:
    dw 256*8-1             ; IDTのサイズ-1
    dd idt_start           ; IDTの開始アドレス