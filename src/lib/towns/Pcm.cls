' Pcm - the FM Towns' RF5C68 for a game (8 PCM channels playing from 64K of wave RAM, at 8 MHz /
' 384 = 20833 samples a second, each stepping through it at its own rate): music on channel 0, and
' four channels for sound effects (a square wave for 3 tones, a noise). NTC platform class:
' Fujitsu FM Towns (first written for TIANLONG). (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'   Init data     the chip on, the wave RAM laid out, nothing playing. data: the songs' address
'                 (a Long; in the high data: NTC_HIGHFILE), made by tools/towns/adpcm.js
'   Have(n)       1 when song n (0-4) is there
'   Play n, lp    song n from its start; lp 1: round again at its end
'   Quiet         the music stopped
'   Update        once a frame: the music decoded on (see below)
'   Voice k, fd, env / Gate k, on: channel k's (1-4) step (fd / 2048 of a sample each 1/20833 s)
'                 and loudness (0-255), on or off. Channels 1-3 play the square, 4 the noise
' The songs' data: 5 x (a Long: the song's place from the data's start, a Long: its bytes; 0 for
' none), then the songs: 4-bit OKI ADPCM at 7812.5 samples a second. Update turns the frame's
' worth (130 samples a frame) into the chip's 8-bit samples (a sign bit and 7 of size) in a ring
' of 32K in wave RAM (0-$7FFE; $7FFF is $FF: the chip's "back to the loop start", 0), half a
' second ahead of the channel playing it at a step of 768 (7812.5 a second). Each start of a song
' (and each time round) starts the ring again, so the frame clock and the chip's never drift
' apart. Wave RAM: $C000 the square (8 samples), $C100 the noise (3839 samples).
Option Explicit

Private Const LEAD = 4096
Private mb As Long, wram As Long
Private cur As Integer, lpf As Integer, chm As Integer
Private src As Long, remain As Long, nib As Integer, pv As Integer, ix As Integer
Private wpos As Integer, t0 As Integer, played As Long

' the long at address a
Private Function L(ByVal a As Long) As Long
#asm
            pop esi
            mov esi, [esi]
            mov eax, [esi]
            pop edi
            mov [edi], eax
#endasm
End Function

' the machine's wave RAM window: the 386SX machines (the Marty, the UX) have it elsewhere
Private Function Wave() As Long
#asm
            in al, 0x30
            and al, 7
            cmp al, 3
            mov eax, 0xC2200000
            jne pw_dx
            mov eax, 0xF80000                   ; 386SX
pw_dx:
            pop edi
            mov [edi], eax
#endasm
End Function

Public Sub Init(ByVal data As Long)
    mb = data
    wram = Wave()
    cur = -1
    chm = 255
    Chip
    Lay
    Setup 0, 0, 768, 200
    Setup 1, &HC000, 0, 0
    Setup 2, &HC000, 0, 0
    Setup 3, &HC000, 0, 0
    Setup 4, &HC100, 0, 0
End Sub

' the chip on: not muted, every channel off
Private Sub Chip()
#asm
            mov dx, 0x4D5
            mov al, 3
            out dx, al
            mov dx, 0x4EC
            mov al, 0x40
            out dx, al
            mov dx, 0x4F8
            mov al, 0xFF
            out dx, al
            mov dx, 0x4F7
            mov al, 0x80
            out dx, al
#endasm
End Sub

' the wave RAM: the ring silent, the square, the noise
Private Sub Lay()
#asm
            mov esi, [{wram}]
            xor ebx, ebx                        ; the bank
pl_bank:
            mov dx, 0x4F7
            mov al, bl
            or al, 0x80
            out dx, al
            mov edi, esi
            mov ecx, 4096
            xor al, al
            rep stosb
            inc ebx
            cmp ebx, 16
            jb pl_bank
            mov dx, 0x4F7                       ; $7FFF: the ring's end
            mov al, 0x87
            out dx, al
            mov byte [esi + 0xFFF], 0xFF
            mov dx, 0x4F7                       ; $C000: the square; $C100: the noise
            mov al, 0x8C
            out dx, al
            mov dword [esi], 0x60606060
            mov dword [esi + 4], 0xE0E0E0E0
            mov byte [esi + 8], 0xFF
            mov edi, esi
            add edi, 0x100
            mov ecx, 0xEFF
            mov ax, 0x1234
pl_noise:
            mov bx, ax                          ; a 16 bit xorshift
            shl bx, 7
            xor ax, bx
            mov bx, ax
            shr bx, 9
            xor ax, bx
            mov bx, ax
            shl bx, 8
            xor ax, bx
            mov bl, al
            and bl, 0xBF                        ; sign and up to 63
            mov [edi], bl
            inc edi
            dec ecx
            jnz pl_noise
            mov byte [edi], 0xFF
#endasm
End Sub

' Setup ch, start, fd, env: channel ch plays from start (a multiple of 256; back to it at $FF)
Private Sub Setup(ByVal ch As Integer, ByVal st As Long, ByVal fd As Integer, ByVal env As Integer)
#asm
            pop esi
            mov al, [esi]
            and al, 7
            or al, 0xC0
            mov dx, 0x4F7
            out dx, al
            pop esi
            mov ebx, [esi]
            pop esi
            mov cx, [esi]
            pop esi
            mov al, [esi]
            mov dx, 0x4F0                       ; ENV
            out dx, al
            mov dx, 0x4F1                       ; PAN: both sides, all of it
            mov al, 0xFF
            out dx, al
            mov dx, 0x4F2                       ; FD
            mov al, cl
            out dx, al
            mov dx, 0x4F3
            mov al, ch
            out dx, al
            mov dx, 0x4F4                       ; LS
            mov al, bl
            out dx, al
            mov dx, 0x4F5
            mov al, bh
            out dx, al
            mov dx, 0x4F6                       ; ST
            mov al, bh
            out dx, al
#endasm
End Sub

' Voice k, fd, env: channel k's step and loudness
Public Sub Voice(ByVal k As Integer, ByVal fd As Integer, ByVal env As Integer)
#asm
            pop esi
            mov al, [esi]
            and al, 7
            or al, 0xC0
            mov dx, 0x4F7
            out dx, al
            pop esi
            mov cx, [esi]
            pop esi
            mov al, [esi]
            mov dx, 0x4F0
            out dx, al
            mov dx, 0x4F2
            mov al, cl
            out dx, al
            mov dx, 0x4F3
            mov al, ch
            out dx, al
#endasm
End Sub

' Gate k, on: channel k on (from its start) or off
Public Sub Gate(ByVal k As Integer, ByVal intOn As Integer)
#asm
            pop esi
            mov cl, [esi]
            and cl, 7
            mov al, 1
            shl al, cl
            pop esi
            cmp word [esi], 0
            je pg_off
            not al
            and [{chm}], al
            jmp pg_out
pg_off:
            or [{chm}], al
pg_out:
            mov al, [{chm}]
            mov dx, 0x4F8
            out dx, al
#endasm
End Sub

Public Function Have(ByVal n As Integer) As Integer
    If L(mb + n * 8 + 4) <> 0 Then Have = 1 Else Have = 0
End Function

Public Sub Play(ByVal n As Integer, ByVal lp As Integer)
    Quiet
    If Have(n) = 0 Then Exit Sub
    cur = n : lpf = lp
    Start
End Sub

' the song from its start: the ring from 0, half a second decoded, the channel on from 0
Private Sub Start()
    Gate 0, 0
    src = mb + L(mb + cur * 8)
    remain = L(mb + cur * 8 + 4) * 2
    nib = 0 : pv = 0 : ix = 0 : wpos = 0
    Decode LEAD
    Gate 0, 1
    t0 = System.Ticks()
    played = 0
End Sub

Public Sub Quiet()
    Gate 0, 0
    cur = -1
End Sub

' Update: the samples the channel has played since the last (59.94 frames a second: 130.34 a
' frame, kept in 65536ths) decoded on; at the song's end, round again (or quiet)
Public Sub Update()
    Dim lngT As Long, lngN As Long
    If cur < 0 Then Exit Sub
    lngT = (System.Ticks() - t0) And &HFFFF&
    lngN = lngT * 130 + (lngT * 22217) \ 65536 - played
    If lngN > 3000 Then lngN = 3000
    If lngN > 0 Then
        Decode CInt(lngN)
        played = played + lngN
    End If
    If remain <= 0 Then
        If lpf Then Start Else Quiet
    End If
End Sub

' Decode n: n samples (or what is left of the song) into the ring at wpos
Private Sub Decode(ByVal n As Integer)
#asm
            pop esi
            movzx ecx, word [esi]
            mov esi, [{src}]
            mov edi, [{wram}]
            movzx ebx, word [{wpos}]
            mov eax, ebx                        ; the bank for wpos
            shr eax, 12
            or al, 0x80
            mov dx, 0x4F7
            out dx, al
pd_lp:
            test ecx, ecx
            jz pd_end
            cmp dword [{remain}], 0
            jle pd_end
            movzx eax, byte [esi]               ; the nibble: the low first
            cmp word [{nib}], 0
            je pd_lo
            shr eax, 4
            inc esi
            mov word [{nib}], 0
            jmp pd_n
pd_lo:
            mov word [{nib}], 1
pd_n:
            and eax, 15
            dec dword [{remain}]
            movzx edx, word [{ix}]
            movzx edx, word [pd_steps + edx * 2]   ; the step
            mov [pd_st], edx
            mov ebp, edx
            shr ebp, 3                          ; diff
            test eax, 4
            jz pd_b2
            add ebp, edx
pd_b2:
            shr edx, 1
            test eax, 2
            jz pd_b1
            add ebp, edx
pd_b1:
            shr edx, 1
            test eax, 1
            jz pd_b0
            add ebp, edx
pd_b0:
            movsx edx, word [{pv}]
            test eax, 8
            jz pd_add
            sub edx, ebp
            jmp pd_cl
pd_add:
            add edx, ebp
pd_cl:
            cmp edx, 2047
            jle pd_c1
            mov edx, 2047
pd_c1:
            cmp edx, -2048
            jge pd_c2
            mov edx, -2048
pd_c2:
            mov [{pv}], dx
            and eax, 7                          ; the step's index on
            movsx eax, byte [pd_adj + eax]
            movsx ebp, word [{ix}]
            add ebp, eax
            jns pd_i1
            xor ebp, ebp
pd_i1:
            cmp ebp, 48
            jle pd_i2
            mov ebp, 48
pd_i2:
            mov [{ix}], bp
            ; the chip's sample: a sign bit ($80 under 0) and 7 bits of size (never $FF)
            mov eax, edx
            test eax, eax
            jns pd_pos
            neg eax
            shr eax, 4
            cmp eax, 126
            jbe pd_neg
            mov eax, 126
pd_neg:
            or eax, 0x80
            jmp pd_put
pd_pos:
            shr eax, 4
            cmp eax, 127
            jbe pd_put
            mov eax, 127
pd_put:
            mov edx, ebx
            and edx, 0xFFF
            mov [edi + edx], al
            inc ebx
            cmp ebx, 0x7FFF
            jb pd_wrap
            xor ebx, ebx
pd_wrap:
            test ebx, 0xFFF
            jnz pd_nb
            mov eax, ebx                        ; a new bank
            shr eax, 12
            or al, 0x80
            mov dx, 0x4F7
            out dx, al
pd_nb:
            dec ecx
            jmp pd_lp
pd_st:      dd 0
pd_steps:
            dw 16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41, 45, 50, 55, 60, 66, 73, 80, 88, 97, 107, 118, 130
            dw 143, 157, 173, 190, 209, 230, 253, 279, 307, 337, 371, 408, 449, 494, 544, 598, 658, 724, 796, 876, 963, 1060
            dw 1166, 1282, 1411, 1552
pd_adj:
            db -1, -1, -1, -1, 2, 4, 6, 8
pd_end:
            mov [{src}], esi
            mov [{wpos}], bx
#endasm
End Sub
