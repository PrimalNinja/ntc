' Vdp - the FM Towns' video for games: sprites, a scrolling backdrop, words. NTC platform class:
' Fujitsu FM Towns (the FM Towns' answer to the Mega Drive's Vdp class and the X68000's; first
' written for TIANLONG). (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' The screen: 256 x 240, two layers of 32768 colours (Towns OS's screen mode 8 on both layers:
' 15 kHz, the Marty's TV), set up from the CRTC's registers:
'   layer 1 (in front)  the sprite controller's: 1024 sprites of 16 x 16, 16 colours each from one
'                       of 256 palettes; it draws them into this layer's back page every frame
'                       (57 microseconds a sprite) and shows them the frame after
'   layer 0 (behind)    a bitmap, 512 bytes a line: the backdrop (from a copy in RAM, BGBUF, 256 x
'                       192 at 2 bytes a pixel, wrapping across), and the words (an 8 x 8 font with
'                       a shadow, in 32 x 32 cells)
' The program runs in ring 3 with every port and all of memory (NTC's towns platform), so this is
' done straight on the hardware. The 386SX machines (the Marty, the UX) have a 24-bit address bus
' and the video at other addresses: Init looks at the machine's ID (port $30) and takes the right
' ones.
'
' Sprites: a table in RAM (Sat: 128 x 4 words, as the hardware's: x, y (the screen's, 9 bits:
' -8 is 504), the pattern (0-1023) with the flips ($2000 mirrored, $1000 upside down), the palette
' word ($8000 or the palette, 256 on; $2000 hidden)), written by the program, sent by Update into
' the hardware's entries 896-1023 (the controller draws from 896 on: the later in front).
' Patterns (Pcg) are stored from the hardware's pattern 128 on (0-127 is where the table and the
' palettes are), palettes (Colors) from palette 256 on.
'
' The backdrop: Load a picture (256 x 192, a byte a pixel) with its palette into BGBUF (taken from
' the Memory class at Init); Bands sets
' the four bands' scroll (lines 0-55, 56-111, 112-151, 152-191), Blit draws the bands that moved
' into the layer (lines 32-223), and the words on them again.
' The words: Text / TFill write the cells (Cell, Cells): rows 4-27 are on the backdrop (a cell is
' the backdrop under it, then the letter's shadow and the letter), the others black.
Option Explicit

Private bg As Long                       ' BGBUF: the backdrop's copy in RAM (192 lines of 512 bytes: 96K from the Memory class)
Private vram As Long, sram As Long, wram As Long, sx As Integer
Private spr(511) As Integer              ' the sprite table (128 x 4 words)
Private sc(3) As Integer, shown(3) As Integer
Private tch(1023) As Integer             ' the cells: 0 none, else the character + 1, its colour << 8, its shadow's << 12
Private fontp As Long, tcol As Long
Private bc(1) As Integer                 ' the backdrop palette's last two colours (the lightning's)

' ---------------------------------------------------------------- set up
Public Sub Init()
    Dim intK As Integer
    If bg = 0 Then bg = Memory.Alloc(98304)
    Screen
    HideAll
    Update
    For intK = 0 To 3
        shown(intK) = -1 : sc(intK) = 0
    Next intK
    For intK = 0 To 1023
        tch(intK) = 0
    Next intK
End Sub

' the machine's addresses, the CRTC (screen mode 8 on both layers), the layers shown (layer 1 in
' front), layer 0 black, the sprite pages' clear lines see-through, every sprite hidden, the
' controller on from entry 896
Private Sub Screen()
#asm
            in al, 0x30
            and al, 7
            cmp al, 3
            jne vi_dx
            mov dword [{vram}], 0xA00000         ; 386SX: the Marty, the UX
            mov dword [{sram}], 0xC00000
            mov dword [{wram}], 0xF80000
            mov word [{sx}], 1
            jmp vi_go
vi_dx:
            mov dword [{vram}], 0x80000000
            mov dword [{sram}], 0x81000000
            mov dword [{wram}], 0xC2200000
            mov word [{sx}], 0
vi_go:
            mov esi, vi_regs
            xor ecx, ecx
vi_crtc:
            mov dx, 0x440
            mov al, cl
            out dx, al
            mov dx, 0x442
            mov ax, [esi + ecx * 2]
            out dx, ax
            inc ecx
            cmp ecx, 32
            jb vi_crtc
            mov dx, 0x448                       ; the video out: 2 layers, both shown
            xor al, al
            out dx, al
            mov dx, 0x44A
            mov al, 0x15
            out dx, al
            mov dx, 0x448                       ; layer 1 (the sprites) in front
            mov al, 1
            out dx, al
            mov dx, 0x44A
            mov al, 0x09
            out dx, al
            mov dx, 0xFDA0                      ; both layers out
            mov al, 0x0F
            out dx, al
            mov edi, [{vram}]                   ; layer 0 black (512 lines)
            mov ecx, 0x40000 / 4
            xor eax, eax
            rep stosd
            mov edi, [{vram}]                   ; the sprite pages' clear lines: see-through
            add edi, 0x40000
            mov ecx, 0x40000 / 4
            mov eax, 0x80008000
            rep stosd
            mov edi, [{sram}]                   ; every entry hidden
            mov ecx, 1024
vi_hide:
            mov dword [edi], 0
            mov dword [edi + 4], 0x20000000
            add edi, 8
            dec ecx
            jnz vi_hide
            mov dx, 0x450                       ; the controller: from entry 896 (3 * 256 + $80), on
            mov al, 0
            out dx, al
            mov dx, 0x452
            mov al, 0x80
            out dx, al
            mov bl, 2                           ; offsets 0
vi_off:
            mov dx, 0x450
            mov al, bl
            out dx, al
            mov dx, 0x452
            xor al, al
            out dx, al
            inc bl
            cmp bl, 6
            jb vi_off
            mov dx, 0x450
            mov al, 1
            out dx, al
            mov dx, 0x452
            mov al, 0x83
            out dx, al
            jmp vi_end
vi_regs:
            dw 0x0074,0x0530,0x0000,0x0000,0x0617,0x0006,0x000C,0x0012,0x020B,0x00E7,0x04E7,0x00E7,0x04E7,0x002A,0x020A,0x002A
            dw 0x020A,0x0000,0x00E7,0x0000,0x0080,0x0000,0x00E7,0x0000,0x0080,0x0056,0x0001,0x0303,0x8005,0x0001,0x0002,0x0188
vi_end:
#endasm
End Sub

' the machine's wave RAM window (the PCM's: Pcm.cls), and 1 on a 386SX machine
Public Function WaveRam() As Long
    WaveRam = wram
End Function

Public Function IsSX() As Integer
    IsSX = sx
End Function

' ---------------------------------------------------------------- sprites
' Sat(): the sprite table's address
Public Function Sat() As Long
#asm
            pop edi
            mov dword [edi], {spr}
#endasm
End Function

Public Sub HideAll()
#asm
            mov edi, {spr}
            mov ecx, 128
vh_lp:
            mov dword [edi], 0
            mov dword [edi + 4], 0x20000000
            add edi, 8
            dec ecx
            jnz vh_lp
#endasm
End Sub

' Update: the table to the hardware's entries 896-1023
Public Sub Update()
#asm
            mov esi, {spr}
            mov edi, [{sram}]
            add edi, 896 * 8
            mov ecx, 256
            rep movsd
#endasm
End Sub

' Pcg addr, first, n: n patterns (128 bytes each) to patterns first .. (the hardware's 128 + first)
Public Sub Pcg(ByVal a As Long, ByVal first As Integer, ByVal n As Integer)
#asm
            pop esi
            mov esi, [esi]
            pop ebx
            movzx eax, word [ebx]
            pop ebx
            movzx ecx, word [ebx]
            mov edi, [{sram}]
            add eax, 128
            shl eax, 7
            add edi, eax
            shl ecx, 5
            rep movsd
#endasm
End Sub

' Colors addr, first, n: n palettes (16 words each) to palettes first .. (the hardware's 256 + first)
Public Sub Colors(ByVal a As Long, ByVal first As Integer, ByVal n As Integer)
#asm
            pop esi
            mov esi, [esi]
            pop ebx
            movzx eax, word [ebx]
            pop ebx
            movzx ecx, word [ebx]
            mov edi, [{sram}]
            add eax, 256
            shl eax, 5
            add edi, eax
            shl ecx, 3
            rep movsd
#endasm
End Sub

' ---------------------------------------------------------------- the backdrop
' Load pic, pal: the picture (256 x 192 bytes) in its palette (256 words) into BGBUF; every band
' drawn again at the next Blit
Public Sub Load(ByVal pic As Long, ByVal pal As Long)
    Convert pic, pal
    Dirty
End Sub

Private Sub Convert(ByVal pic As Long, ByVal pal As Long)
#asm
            pop esi
            mov esi, [esi]
            pop ebx
            mov ebx, [ebx]
            mov ax, [ebx + 254 * 2]
            mov [{bc}], ax
            mov ax, [ebx + 255 * 2]
            mov [{bc} + 2], ax
            mov edi, [{bg}]
            mov ecx, 256 * 192
            xor eax, eax
vc_lp:
            mov al, [esi]
            inc esi
            mov dx, [ebx + eax * 2]
            mov [edi], dx
            add edi, 2
            dec ecx
            jnz vc_lp
#endasm
End Sub

' Buffer(): BGBUF's address (a program drawing on the backdrop's copy itself: 2 bytes a pixel,
' 512 bytes a line, then Dirty)
Public Function Buffer() As Long
    Buffer = bg
End Function

' BgColour(k): the backdrop palette's colour 254 + k (the lightning's glow, its core)
Public Function BgColour(ByVal k As Integer) As Integer
    BgColour = bc(k And 1)
End Function

' Dirty: every band drawn again at the next Blit (the lightning drew on the copy)
Public Sub Dirty()
    shown(0) = -1 : shown(1) = -1 : shown(2) = -1 : shown(3) = -1
End Sub

Public Sub Bands(ByVal a As Integer, ByVal b As Integer, ByVal c As Integer, ByVal d As Integer)
    sc(0) = a And 255 : sc(1) = b And 255 : sc(2) = c And 255 : sc(3) = d And 255
End Sub

' Blit: the bands that moved (or all, after Dirty) into layer 0, then their words
Public Sub Blit()
    If sc(0) <> shown(0) Then
        Band 0, 56, sc(0) : shown(0) = sc(0) : Cells 4, 10, 0
    End If
    If sc(1) <> shown(1) Then
        Band 56, 56, sc(1) : shown(1) = sc(1) : Cells 11, 17, 0
    End If
    If sc(2) <> shown(2) Then
        Band 112, 40, sc(2) : shown(2) = sc(2) : Cells 18, 22, 0
    End If
    If sc(3) <> shown(3) Then
        Band 152, 40, sc(3) : shown(3) = sc(3) : Cells 23, 27, 0
    End If
End Sub

' Band y, n, s: BGBUF's lines y .. y + n - 1 to layer 0's lines 32 + y on, from column s (wrapping)
Private Sub Band(ByVal y As Integer, ByVal n As Integer, ByVal s As Integer)
#asm
            pop esi
            movzx eax, word [esi]
            pop esi
            movzx edx, word [esi]
            pop esi
            movzx ebx, word [esi]
            and ebx, 255
            shl ebx, 1                          ; the first column's byte
            mov ebp, eax
            shl ebp, 9                          ; the line's start in BGBUF
            add eax, 32
            shl eax, 9
            mov edi, [{vram}]
            add edi, eax
            cld
vb_line:
            mov esi, [{bg}]
            add esi, ebp
            add esi, ebx
            mov ecx, 512
            sub ecx, ebx
            shr ecx, 1                          ; the pixels to the line's end (s odd: words)
            test ecx, 1
            jz vb_w1
            movsw
vb_w1:
            shr ecx, 1
            rep movsd
            mov esi, [{bg}]
            add esi, ebp
            mov ecx, ebx
            shr ecx, 1
            test ecx, 1
            jz vb_w2
            movsw
vb_w2:
            shr ecx, 1
            rep movsd
            add ebp, 512
            dec edx
            jnz vb_line
#endasm
End Sub

' GFill y, n, c: layer 0's lines y .. y + n - 1 all colour c (15 bits)
Public Sub GFill(ByVal y As Integer, ByVal n As Integer, ByVal c As Integer)
#asm
            pop esi
            movzx eax, word [esi]
            pop esi
            movzx ecx, word [esi]
            pop esi
            movzx edx, word [esi]
            mov edi, [{vram}]
            shl eax, 9
            add edi, eax
            shl ecx, 7                          ; dwords
            mov eax, edx
            shl eax, 16
            or eax, edx
            rep stosd
#endasm
End Sub

' Pic4 pic, pal: a 256 x 240 picture of 4 bits a pixel (the left pixel low) in 16 colours (pal) to
' layer 0's lines 0-239 (the splash)
Public Sub Pic4(ByVal pic As Long, ByVal pal As Long)
#asm
            pop esi
            mov esi, [esi]
            pop ebx
            mov ebx, [ebx]
            mov edi, [{vram}]
            mov ecx, 128 * 240
            xor eax, eax
vp_lp:
            mov al, [esi]
            inc esi
            mov edx, eax
            and edx, 15
            mov dx, [ebx + edx * 2]
            mov [edi], dx
            mov edx, eax
            shr edx, 4
            mov dx, [ebx + edx * 2]
            mov [edi + 2], dx
            add edi, 4
            dec ecx
            jnz vp_lp
#endasm
End Sub

' ---------------------------------------------------------------- the words
' Font addr, colours: the font (68 characters from 32, 16 bytes each: the letter's 8 rows, its
' shadow's 8) and the words' 16 colours
Public Sub Font(ByVal a As Long, ByVal c As Long)
    fontp = a
    tcol = c
End Sub

' Text cx, cy, s, c, sh: s from cell cx, cy on, colour c, shadow sh (characters 32-95; 123-126 the
' font's 64-67: a life, a bomb, the bar full / empty)
Public Sub Text(ByVal cx As Integer, ByVal cy As Integer, ByVal s As String, ByVal c As Integer, ByVal sh As Integer)
    Dim intI As Integer, intC As Integer
    If cy < 0 Or cy > 31 Then Exit Sub
    For intI = 1 To Len(s)
        intC = Asc(Mid$(s, intI, 1))
        Cell cx + intI - 1, cy, intC, c, sh
    Next intI
    Cells cy, cy, 1
End Sub

' TFill cx, cy, w, h: no words in those cells
Public Sub TFill(ByVal cx As Integer, ByVal cy As Integer, ByVal w As Integer, ByVal h As Integer)
    Dim intX As Integer, intY As Integer
    For intY = cy To cy + h - 1
        For intX = cx To cx + w - 1
            Cell intX, intY, 32, 0, 0
        Next intX
    Next intY
    Cells cy, cy + h - 1, 1
End Sub

' Cell cx, cy, ch, c, sh: the cell's character (not drawn: Cells draws it)
Private Sub Cell(ByVal cx As Integer, ByVal cy As Integer, ByVal ch As Integer, ByVal c As Integer, ByVal sh As Integer)
#asm
            pop esi
            movzx ebx, word [esi]
            pop esi
            movzx eax, word [esi]
            pop esi
            movzx edx, word [esi]
            pop esi
            movzx ecx, word [esi]
            pop esi
            movzx esi, word [esi]
            cmp ebx, 32
            jae vl_end
            cmp eax, 32
            jae vl_end
            shl eax, 5
            add eax, ebx                        ; the cell
            cmp edx, 123
            jb vl_asc
            cmp edx, 126
            ja vl_none
            sub edx, 123 - 96                   ; 123-126: the font's 64-67
vl_asc:
            sub edx, 32
            jb vl_none
            cmp edx, 68
            jae vl_none
            test edx, edx
            jz vl_none                          ; a space: none
            inc edx
            and ecx, 15
            shl ecx, 8
            or edx, ecx
            and esi, 15
            shl esi, 12
            or edx, esi
            mov [{tch} + eax * 2], dx
            jmp vl_end
vl_none:
            mov word [{tch} + eax * 2], 0
vl_end:
#endasm
End Sub

' Cells r0, r1, under: rows r0 .. r1 drawn: under 1 - each cell what is under it first (the
' backdrop on rows 4-27, else black); then each cell's shadow and letter
Private Sub Cells(ByVal r0 As Integer, ByVal r1 As Integer, ByVal under As Integer)
#asm
            pop esi
            movzx eax, word [esi]
            pop esi
            movzx edx, word [esi]
            pop esi
            mov bx, [esi]
            mov [vs_under], bx
            mov [vs_r], eax
            mov [vs_r1], edx
vs_row:
            mov eax, [vs_r]
            cmp eax, [vs_r1]
            ja vs_end
            cmp eax, 31
            ja vs_end
            mov dword [vs_x], 0
vs_cell:
            ; edi: the cell's top left in layer 0
            mov eax, [vs_r]
            shl eax, 12                         ; * 8 lines * 512
            mov edi, [{vram}]
            add edi, eax
            mov eax, [vs_x]
            shl eax, 4                          ; * 8 pixels * 2
            add edi, eax
            cmp word [vs_under], 0
            je vs_glyph
            mov eax, [vs_r]
            cmp eax, 4
            jb vs_black
            cmp eax, 28
            jae vs_black
            ; the backdrop under it: its band's scroll
            sub eax, 4
            shl eax, 3                          ; the paper's line
            movzx ebx, word [{shown}]
            cmp eax, 56
            jb vs_bs
            movzx ebx, word [{shown} + 2]
            cmp eax, 112
            jb vs_bs
            movzx ebx, word [{shown} + 4]
            cmp eax, 152
            jb vs_bs
            movzx ebx, word [{shown} + 6]
vs_bs:
            and ebx, 255
            mov ecx, [vs_x]
            shl ecx, 3
            add ebx, ecx                        ; the backdrop's column
            shl eax, 9
            add eax, [{bg}]
            mov ebp, eax                        ; its line in BGBUF
            mov edx, 8
vs_ul:
            mov ecx, 8
vs_up:
            and ebx, 255
            mov ax, [ebp + ebx * 2]
            mov [edi], ax
            add edi, 2
            inc ebx
            dec ecx
            jnz vs_up
            sub ebx, 8
            add edi, 512 - 16
            add ebp, 512
            dec edx
            jnz vs_ul
            sub edi, 8 * 512
            jmp vs_glyph
vs_black:
            mov edx, 8
            xor eax, eax
vs_bl:
            mov [edi], eax
            mov [edi + 4], eax
            mov [edi + 8], eax
            mov [edi + 12], eax
            add edi, 512
            dec edx
            jnz vs_bl
            sub edi, 8 * 512
vs_glyph:
            mov eax, [vs_r]
            shl eax, 5
            add eax, [vs_x]
            movzx edx, word [{tch} + eax * 2]
            test edx, edx
            jz vs_next
            mov ebx, [{tcol}]
            mov ecx, edx
            shr ecx, 8
            and ecx, 15
            mov ax, [ebx + ecx * 2]
            mov [vs_c], ax                      ; the letter's colour
            mov ecx, edx
            shr ecx, 12
            mov ax, [ebx + ecx * 2]
            mov [vs_s], ax                      ; the shadow's
            and edx, 127
            dec edx
            shl edx, 4
            mov esi, [{fontp}]
            add esi, edx
            mov edx, 8
vs_gl:
            mov bl, [esi + 8]                   ; the shadow's row, then the letter's over it
            mov bh, [esi]
            mov ecx, 0
vs_gp:
            mov al, 0x80
            shr al, cl
            test bh, al
            jz vs_g1
            mov ax, [vs_c]
            mov [edi + ecx * 2], ax
            jmp vs_g2
vs_g1:
            mov al, 0x80
            shr al, cl
            test bl, al
            jz vs_g2
            mov ax, [vs_s]
            mov [edi + ecx * 2], ax
vs_g2:
            inc ecx
            cmp ecx, 8
            jb vs_gp
            inc esi
            add edi, 512
            dec edx
            jnz vs_gl
vs_next:
            inc dword [vs_x]
            cmp dword [vs_x], 32
            jb vs_cell
            inc dword [vs_r]
            jmp vs_row
vs_r:       dd 0
vs_r1:      dd 0
vs_x:       dd 0
vs_under:   dw 0
vs_c:       dw 0
vs_s:       dw 0
vs_end:
#endasm
End Sub
