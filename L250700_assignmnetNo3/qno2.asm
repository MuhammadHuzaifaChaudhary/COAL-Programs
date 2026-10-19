[org 0x0100]
jmp start

TEXT_TOP     equ 4
TEXT_BOTTOM  equ 20
TEXT_LEFT    equ 10
TEXT_RIGHT   equ 70

title:       db '  text viewport manager  ', 0
keyword:     db 'memory', 0
str1:        db 'Total Matches Found: ', 0
str2:        db ' | Viewport Status: ACTIVE', 0
hint1:       db 'press any key to scroll the window up by 2 lines...', 0
hint2:       db 'press any key to exit.'
             times 29 db ' '
             db 0

next_line:   dw 0
match_count: dw 0

doc:
    db 'the 8088 cpu can address one megabyte of memory.', 0
    db 'text mode video memory starts at address b8000.', 0
    db 'every cell has a character byte and an attribute byte.', 0
    db 'the attribute byte controls color and blinking.', 0
    db 'a screen of 80 by 25 cells needs 4000 bytes of memory.', 0
    db 'scrolling moves rows of memory up and blanks the last row.', 0
    db 'highlighting changes only the attribute of a cell,', 0
    db 'so the characters stored in memory stay the same.', 0
    db 'string instructions make these jobs short and fast.', 0
    db 'searching the screen for a word is done in memory.', 0
    db 0xFF

draw_window:
    push bp
    mov bp, sp
    sub sp, 4
    push ax
    push bx
    push cx
    push dx
    push di
    push es

    mov ax, 0xB800
    mov es, ax
    cld

    mov ax, [bp+4]
    sub ax, [bp+8]
    dec ax
    mov [bp-2], ax

    mov bx, 80
    mov ax, [bp+10]
    mul bx
    add ax, [bp+8]
    shl ax, 1
    mov di, ax
    mov ah, 0x0F
    mov al, 0xC9
    stosw
    mov al, 0xCD
    mov cx, [bp-2]
    rep stosw
    mov al, 0xBB
    stosw

    mov ax, [bp+10]
    inc ax
    mov [bp-4], ax
.side:
    mov ax, [bp-4]
    cmp ax, [bp+6]
    jae .bottom
    mul bx
    add ax, [bp+8]
    shl ax, 1
    mov di, ax
    mov ah, 0x0F
    mov al, 0xBA
    stosw
    mov ax, [bp-2]
    shl ax, 1
    add di, ax
    mov ah, 0x0F
    mov al, 0xBA
    stosw
    inc word [bp-4]
    jmp .side

.bottom:
    mov ax, [bp+6]
    mul bx
    add ax, [bp+8]
    shl ax, 1
    mov di, ax
    mov ah, 0x0F
    mov al, 0xC8
    stosw
    mov al, 0xCD
    mov cx, [bp-2]
    rep stosw
    mov al, 0xBC
    stosw

    pop es
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    mov sp, bp
    pop bp
    ret 8

print_string:
    push bp
    mov bp, sp
    push ax
    push bx
    push dx
    push si
    push di
    push ds
    push es

    mov ax, 0xB800
    mov es, ax
    push cs
    pop ds
    mov bx, 80
    mov ax, [bp+10]
    mul bx
    add ax, [bp+8]
    shl ax, 1
    mov di, ax
    mov si, [bp+6]
    mov ah, [bp+4]
    cld
.next:
    lodsb
    cmp al, 0
    je .done
    stosw
    jmp .next
.done:
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop bx
    pop ax
    pop bp
    ret 8

print_lines:
    push bp
    mov bp, sp
    sub sp, 4
    push bx
    push dx
    push si
    push di
    push ds
    push es

    push cs
    pop ds
    mov ax, 0xB800
    mov es, ax
    mov si, [bp+8]
    mov ax, [bp+6]
    mov [bp-2], ax
    mov ax, [bp+4]
    mov [bp-4], ax
    mov bx, 80
    cld
.line:
    cmp word [bp-4], 0
    je .done
    cmp byte [si], 0xFF
    je .done
    mov ax, [bp-2]
    mul bx
    add ax, TEXT_LEFT
    shl ax, 1
    mov di, ax
    mov ah, 0x07
.char:
    lodsb
    cmp al, 0
    je .eol
    stosw
    jmp .char
.eol:
    inc word [bp-2]
    dec word [bp-4]
    jmp .line
.done:
    mov ax, si
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop bx
    mov sp, bp
    pop bp
    ret 6

scroll_window_up:
    push bp
    mov bp, sp
    sub sp, 6
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es

    mov ax, 0xB800
    mov ds, ax
    mov es, ax
    cld

    mov ax, [bp+6]
    sub ax, [bp+10]
    dec ax
    mov [bp-4], ax
    mov ax, [bp+12]
    inc ax
    mov [bp-2], ax
    mov ax, [bp+8]
    dec ax
    mov [bp-6], ax
    mov bx, 80

.copy_row:
    mov ax, [bp-2]
    add ax, [bp+4]
    cmp ax, [bp-6]
    ja .blank
    mul bx
    add ax, [bp+10]
    inc ax
    shl ax, 1
    mov si, ax
    mov ax, [bp-2]
    mul bx
    add ax, [bp+10]
    inc ax
    shl ax, 1
    mov di, ax
    mov cx, [bp-4]
    rep movsw
    inc word [bp-2]
    jmp .copy_row

.blank:
    mov ax, [bp-2]
    cmp ax, [bp-6]
    ja .done
    mul bx
    add ax, [bp+10]
    inc ax
    shl ax, 1
    mov di, ax
    mov cx, [bp-4]
    mov ax, 0x0720
    rep stosw
    inc word [bp-2]
    jmp .blank

.done:
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    mov sp, bp
    pop bp
    ret 10

find_and_highlight:
    push bp
    mov bp, sp
    sub sp, 8
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es

    push cs
    pop ds
    mov ax, 0xB800
    mov es, ax
    cld

    mov word [bp-8], 0
    mov word [bp-6], 0
    mov si, [bp+6]
.length:
    cmp byte [si], 0
    je .length_done
    inc word [bp-6]
    inc si
    jmp .length
.length_done:

    mov word [bp-2], TEXT_TOP
.row:
    mov word [bp-4], TEXT_LEFT
.col:
    mov ax, TEXT_RIGHT + 1
    sub ax, [bp-6]
    cmp [bp-4], ax
    ja .next_row

    mov ax, [bp-2]
    mov bx, 80
    mul bx
    add ax, [bp-4]
    shl ax, 1
    mov di, ax
    mov dx, di
    mov si, [bp+6]
    mov cx, [bp-6]
.compare:
    cmpsb
    jne .no_match
    inc di
    loop .compare

    mov di, dx
    inc di
    mov cx, [bp-6]
    mov al, [bp+4]
.paint:
    stosb
    inc di
    loop .paint
    inc word [bp-8]
    mov ax, [bp-6]
    add [bp-4], ax
    jmp .col

.no_match:
    inc word [bp-4]
    jmp .col

.next_row:
    inc word [bp-2]
    cmp word [bp-2], TEXT_BOTTOM
    jbe .row

    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    mov ax, [bp-8]
    mov sp, bp
    pop bp
    ret 4

printNum:
    push bp
    mov bp, sp
    sub sp, 2
    push bx
    push cx
    push dx
    push di
    push es

    mov ax, 0xB800
    mov es, ax
    mov bx, 80
    mov ax, [bp+8]
    mul bx
    add ax, [bp+6]
    shl ax, 1
    mov di, ax

    mov ax, [bp+10]
    mov word [bp-2], 0
    mov bx, 10
.divide:
    xor dx, dx
    div bx
    add dl, '0'
    push dx
    inc word [bp-2]
    cmp ax, 0
    jne .divide

    mov cx, [bp-2]
    mov ah, [bp+4]
    cld
.out:
    pop dx
    mov al, dl
    stosw
    loop .out

    pop es
    pop di
    pop dx
    pop cx
    pop bx
    mov ax, [bp-2]
    mov sp, bp
    pop bp
    ret 8

start:
    push cs
    pop ds
    mov ax, 0xB800
    mov es, ax
    xor di, di
    mov ax, 0x0720
    mov cx, 2000
    cld
    rep stosw

    push word 3
    push word 8
    push word 21
    push word 72
    call draw_window

    push word 3
    push word 28
    push word title
    push word 0x1E
    call print_string

    push word doc
    push word 4
    push word 17
    call print_lines
    mov [next_line], ax

    push word 22
    push word 8
    push word hint1
    push word 0x07
    call print_string

    xor ah, ah
    int 0x16

    push word 3
    push word 8
    push word 21
    push word 72
    push word 2
    call scroll_window_up

    push word [next_line]
    push word 19
    push word 2
    call print_lines
    mov [next_line], ax

    push word keyword
    push word 0xCE
    call find_and_highlight
    mov [match_count], ax

    push word 23
    push word 8
    push word str1
    push word 0x0F
    call print_string

    push word [match_count]
    push word 23
    push word 29
    push word 0x0E
    call printNum

    add ax, 29
    mov dx, ax
    push word 23
    push dx
    push word str2
    push word 0x0F
    call print_string

    push word 22
    push word 8
    push word hint2
    push word 0x07
    call print_string

    mov ah, 0x02
    xor bh, bh
    mov dh, 24
    xor dl, dl
    int 0x10

    xor ah, ah
    int 0x16

    mov ax, 0x4C00
    int 0x21