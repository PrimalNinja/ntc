' V9990 - the Yamaha V9990 video chip: the MSX's GFX9000 (Sunrise), and V9990 boards for the CPC.
' 512K of its own video RAM, two tile layers, 125 sprites of 16 x 16 in 16 colours (4 bits a
' pixel), 16 on a line, a palette of 64 out of 32768.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' The ports, from VPort: +0 video RAM data, +1 palette data, +3 register data, +4 register select,
' +5 status. GFX9000 on the MSX: VPort #60. On the CPC: build with --const=CPC; VPort is then
' &HFF60 - CHANGE IT to the board's own address (not known here: the CPC V9990 build is
' untested). Interrupts stay off (NTC's turbo): Frame waits for the frame by reading the status.
'
' Modes (Mode, StdIO's Mode): 1 (and 0) P1 - 256 x 212, 32 x 26 characters on layer A, sprites.
' 2: B1 - a 256 x 212 bitmap, a byte a pixel (BP6: 64 colours from the palette), two screens in
' video RAM (lines 0-211 and 256-467) shown in turn: for vectors. Text is drawn on both (colour 1
' on colour 0). Begin / Keep / Spans / Show draw with the chip's own fill command (LMMV, a line at a
' time) on the screen not shown. (P2, 512 wide, 64 columns, is still to add.)
' P1's video RAM: layer A patterns #00000 (a 256 pixel wide picture of 8 x 8 tiles: tile n at
' x (n mod 32) * 8, y (n \ 32) * 8), the font as tiles 288-382 (256 + the character), sprite
' patterns #00000 too (16 x 16: pattern n at x (n mod 16) * 16, y (n \ 16) * 16 - patterns 0-15
' use the picture's top 16 lines, clear of the font), layer B patterns #40000, sprite attributes
' #3FE00, layer A names #7C000, layer B names #7E000 (64 x 64, 2 bytes each).
'
' The game library's calls, the same in every chip's class (Zxn, Cpc, Asic, Tms9918, V9938,
' V9990): Init, Pattern, Put, Hide, Anim, Move, Bounds, Frame, X, Y. The V9990's own: Palette,
' Shades (a sprite's set of 16 colours), the text (Cls, Locate, PutStr, NewLine: the project's
' StdIO calls them).
Option Explicit

#If CPC Then
Public Const VPort = &HFF60
#Else
Public Const VPort = &H60
#End If
Public Const Slots = 16            ' sprites this class keeps (the chip has 125)

Private sx(15) As Integer, sy(15) As Integer, vx(15) As Integer, vy(15) As Integer
Private pt(15) As Integer, af(15) As Integer, ac(15) As Integer, ad(15) As Integer, at(15) As Integer
Private son(15) As Integer, sc(15) As Integer
Private bx0 As Integer, by0 As Integer, bx1 As Integer, by1 As Integer
Private cx As Integer, cy As Integer, fontAt As Integer
Private md As Integer, bk As Integer            ' B1: the screen drawn on (0 / 1; the other shown)
Private ex0(1) As Integer, ey0(1) As Integer, ex1(1) As Integer, ey1(1) As Integer   ' drawn on each
Private sat(63) As Byte            ' the sprite attributes for the next frame (4 bytes a sprite)

' ---- the chip

' Reg r, v: a register
Public Sub Reg(ByVal r As Integer, ByVal v As Integer)
  Out VPort + 4, r
  Out VPort + 3, v
End Sub

' Palette n, r, g, b: colour n (0-63), each part 0-31
Public Sub Palette(ByVal n As Integer, ByVal r As Integer, ByVal g As Integer, ByVal b As Integer)
  Reg 14, n * 4
  Out VPort + 1, r
  Out VPort + 1, g
  Out VPort + 1, b
End Sub

' VAddr hi, lo: the video RAM address to write next (hi: bits 16-18)
Public Sub VAddr(ByVal hi As Integer, ByVal lo As Integer)
#asm
            pop hl              ; hi
            ld e, (hl)
            pop hl              ; lo
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld bc, {VPort} + 4
            xor a               ; register 0 (then 1, 2: the select moves on itself)
            out (c), a
            ld bc, {VPort} + 3
            out (c), l
            out (c), h
            out (c), e
#endasm
End Sub

' VCopy hi, lo, ram, n: n bytes from RAM to video RAM
Public Sub VCopy(ByVal hi As Integer, ByVal lo As Integer, ByVal ram As Integer, ByVal n As Integer)
  VAddr hi, lo
  VOut ram, n
End Sub

' VOut ram, n: n bytes from RAM to video RAM at the address set
Public Sub VOut(ByVal ram As Integer, ByVal n As Integer)
#asm
            pop hl              ; ram
            ld e, (hl)
            inc hl
            ld d, (hl)
            pop hl              ; n
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ex de, hl           ; hl ram, de n
            ld bc, {VPort}
vo_loop:    ld a, d
            or e
            jr z, vo_done
            ld a, (hl)
            out (c), a
            inc hl
            dec de
            jr vo_loop
vo_done:
#endasm
End Sub

' VFill hi, lo, value, n: n bytes of video RAM set to value
Public Sub VFill(ByVal hi As Integer, ByVal lo As Integer, ByVal v As Integer, ByVal n As Integer)
  VAddr hi, lo
  VRep v, n
End Sub

' VRep value, n: n bytes of value to video RAM at the address set
Public Sub VRep(ByVal v As Integer, ByVal n As Integer)
#asm
            pop hl              ; value
            ld e, (hl)
            pop hl              ; n
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld bc, {VPort}
vr_loop:    ld a, h
            or l
            jr z, vr_done
            out (c), e
            dec hl
            jr vr_loop
vr_done:
#endasm
End Sub

' WaitFrame: until the frame's blank starts (the status' VR bit set)
Public Sub WaitFrame()
#asm
            ld bc, {VPort} + 5
wf_out:     in a, (c)           ; (in the blank already: wait for it to end)
            and #40
            jr nz, wf_out
wf_in:      in a, (c)
            and #40
            jr z, wf_in
#endasm
End Sub

' ---- screen and text

' Init: everything cleared, P1
Public Sub Init()
  Dim i As Integer
  For i = 0 To Slots - 1
    son(i) = 0 : vx(i) = 0 : vy(i) = 0 : ac(i) = 0 : sc(i) = 0
  Next
  bx0 = 0 : by0 = 0 : bx1 = 239 : by1 = 195
  Mode 1
End Sub

' Mode m: P1 whatever m (256 x 212, 32 x 26 characters, sprites); the screen cleared
Public Sub Mode(ByVal m As Integer)
  Dim c As Integer, r As Integer, b As Integer, i As Integer
  If fontAt = 0 Then fontAt = Art.Font()
  md = m
  If m = 2 Then ModeB : Exit Sub
  Reg 8, &H02                    ' the screen off (512K of video RAM)
  Reg 9, 0                       ' no interrupts
  Reg 6, &H05 : Reg 7, 0         ' P1 (4 bits a pixel), 60Hz
  Reg 13, 0 : Reg 15, 0          ' palette offsets 0, the backdrop colour 0
  For i = 17 To 24               ' no scrolling
    Reg i, 0
  Next
  Reg 25, 0 : Reg 27, 0          ' sprite patterns from #00000; sprites over both layers
  Palette 0, 0, 0, 12            ' dark blue (the backdrop)
  Palette 15, 31, 31, 31         ' white (the text)
  VFill 0, 0, 0, 16 * 128        ' the sprite patterns' lines clear
  For c = 32 To 126              ' the font: 1 bit to 4 (colour 15) as tiles 256 + c
    For r = 0 To 7
      VAddr 0, ((256 + c) \ 32) * 1024 + r * 128 + (c Mod 32) * 4
      b = Peek(fontAt + (c - 32) * 8 + r)
      VExpand b
    Next
  Next
  For r = 0 To 7                 ' layer B: its tile 288 (all of it, see Cls) clear
    VFill 4, &H2400 + r * 128, 0, 4
  Next
  VFill 3, &HFE00, 0, 512        ' the sprite attributes: all off ...
  For i = 0 To 124
    VFill 3, &HFE00 + i * 4 + 3, &H10, 1       ' (D: not shown)
  Next
  Cls
  Reg 8, &H82                    ' on
End Sub

' VExpand b: 8 pixels of 1 bit (b) as 4 bytes of 4 bit pixels (colour 15) at the address set
Private Sub VExpand(ByVal b As Integer)
#asm
            pop hl
            ld e, (hl)
            ld bc, {VPort}
            ld d, 4
ve_loop:    xor a
            sla e
            jr nc, ve_1
            or #F0
ve_1:       sla e
            jr nc, ve_2
            or #0F
ve_2:       out (c), a
            dec d
            jr nz, ve_loop
#endasm
End Sub

Public Sub Cls()
  Dim i As Integer
  If md = 2 Then
    VCmd 0, 0, 256, 512, 0, &H20                 ' both screens colour 0 (LMMV)
    cx = 0 : cy = 0
    Exit Sub
  End If
  For i = 0 To 1                   ' both layers: tile 288 (a space) everywhere
    VAddr 7, &HC000 + i * &H2000
    VRep2 288, 4096
  Next
  cx = 0 : cy = 0
End Sub

' VRep2 w, n: the word w n times to video RAM at the address set (low byte first)
Private Sub VRep2(ByVal w As Integer, ByVal n As Integer)
#asm
            pop hl              ; w
            ld e, (hl)
            inc hl
            ld d, (hl)
            pop hl              ; n
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld bc, {VPort}
r2_loop:    ld a, h
            or l
            jr z, r2_done
            out (c), e
            out (c), d
            dec hl
            jr r2_loop
r2_done:
#endasm
End Sub

' Locate x, y: 1 based, as the statement
Public Sub Locate(ByVal x As Integer, ByVal y As Integer)
  cx = x - 1 : cy = y - 1
End Sub

Public Sub PutStr(ByVal s As String Max 255)
  Dim i As Integer, n As Integer
  n = Len(s)
  For i = 1 To n
    If cx >= 32 Then NewLine
    If md = 2 Then
      GlyphB Asc(Mid$(s, i, 1))
    Else
      VAddr 7, &HC000 + (cy * 64 + cx) * 2
      VRep2 256 + Asc(Mid$(s, i, 1)), 1
    End If
    cx = cx + 1
  Next
End Sub

Public Sub NewLine()
  cx = 0
  cy = cy + 1
  If cy > 25 Then cy = 25
End Sub

' ---- sprites

' Pattern n: a 16 x 16 sprite pattern (128 bytes: 16 lines of 8, 2 pixels a byte) from address a
Public Sub Pattern(ByVal n As Integer, ByVal a As Integer)
  Dim r As Integer
  For r = 0 To 15
    VCopy 0, (n \ 16) * 2048 + r * 128 + (n Mod 16) * 8, a + r * 8, 8
  Next
End Sub

Public Sub Put(ByVal n As Integer, ByVal x As Integer, ByVal y As Integer, ByVal p As Integer)
  sx(n) = x : sy(n) = y : pt(n) = p : son(n) = 1 : ac(n) = 0
End Sub

' Shades n, s: sprite n's colours are palette s * 16 .. s * 16 + 15 (s 0-3)
Public Sub Shades(ByVal n As Integer, ByVal s As Integer)
  sc(n) = s
End Sub

Public Sub Hide(ByVal n As Integer)
  son(n) = 0
End Sub

Public Sub Anim(ByVal n As Integer, ByVal first As Integer, ByVal count As Integer, ByVal delay As Integer)
  af(n) = first : ac(n) = count : ad(n) = delay : at(n) = delay : pt(n) = first
End Sub

Public Sub Move(ByVal n As Integer, ByVal dx As Integer, ByVal dy As Integer)
  vx(n) = dx : vy(n) = dy
End Sub

Public Sub Bounds(ByVal x0 As Integer, ByVal y0 As Integer, ByVal x1 As Integer, ByVal y1 As Integer)
  bx0 = x0 : by0 = y0 : bx1 = x1 : by1 = y1
End Sub

Public Function X(ByVal n As Integer) As Integer
  X = sx(n)
End Function

Public Function Y(ByVal n As Integer) As Integer
  Y = sy(n)
End Function

' Frame: wait for the frame, the sprite attributes to the chip at once (made the frame before),
' then each sprite moves and animates on, and the next attributes are made
Public Sub Frame()
  Dim i As Integer, k As Integer
  WaitFrame
  VCopy 3, &HFE00, VarPtr(sat), Slots * 4
  For i = 0 To Slots - 1
    k = i * 4
    If son(i) Then
      sx(i) = sx(i) + vx(i)
      If sx(i) < bx0 Then sx(i) = bx0 : vx(i) = -vx(i)
      If sx(i) > bx1 Then sx(i) = bx1 : vx(i) = -vx(i)
      sy(i) = sy(i) + vy(i)
      If sy(i) < by0 Then sy(i) = by0 : vy(i) = -vy(i)
      If sy(i) > by1 Then sy(i) = by1 : vy(i) = -vy(i)
      If ac(i) Then
        at(i) = at(i) - 1
        If at(i) <= 0 Then
          at(i) = ad(i)
          pt(i) = pt(i) + 1
          If pt(i) >= af(i) + ac(i) Then pt(i) = af(i)
        End If
      End If
      sat(k) = sy(i) - 1
      sat(k + 1) = pt(i)
      sat(k + 2) = sx(i)
      sat(k + 3) = sc(i) * 64 + ((sx(i) \ 256) And 3)
    Else
      sat(k + 3) = &H10             ' (D: not shown)
    End If
  Next
End Sub

' ---- B1: a bitmap for vectors

Private Sub ModeB()
  Dim i As Integer
  Reg 8, &H02                    ' the screen off
  Reg 9, 0
  Reg 6, &H82 : Reg 7, 0         ' B1: 256 wide, a byte a pixel, 60Hz
  Reg 13, 0 : Reg 15, 0          ' the palette (BP6), the backdrop colour 0
  For i = 17 To 24
    Reg i, 0
  Next
  Palette 0, 0, 0, 12            ' dark blue (the background)
  Palette 1, 31, 31, 31          ' white (the text)
  bk = 1
  ex0(0) = 0 : ex1(0) = -1 : ex0(1) = 0 : ex1(1) = -1
  Cls
  Reg 8, &H82                    ' on
End Sub

' GlyphB c: character c at the cursor on both screens
Private Sub GlyphB(ByVal c As Integer)
  Dim p As Integer, r As Integer
  If c < 32 Or c > 126 Then c = 32
  For p = 0 To 1
    For r = 0 To 7
      VAddr p, (cy * 8 + r) * 256 + cx * 8
      RowB Peek(fontAt + (c - 32) * 8 + r)
    Next
  Next
End Sub

' RowB b: 8 pixels of 1 bit as 8 bytes (colour 1 on 0) at the address set
Private Sub RowB(ByVal b As Integer)
#asm
            pop hl
            ld e, (hl)
            ld bc, {VPort}
            ld d, 8
rb_loop:    xor a
            sla e
            rla
            out (c), a
            dec d
            jr nz, rb_loop
#endasm
End Sub

' WaitCE: until the chip's command (fill, copy ...) is done
Public Sub WaitCE()
#asm
            ld bc, {VPort} + 5
ce_loop:    in a, (c)
            rrca
            jr c, ce_loop
#endasm
End Sub

' VCmd dx, dy, nx, ny, colour, op: a chip command on a rectangle (#20 LMMV: fill)
Public Sub VCmd(ByVal dx As Integer, ByVal dy As Integer, ByVal nx As Integer, ByVal ny As Integer, ByVal c As Integer, ByVal op As Integer)
  WaitCE
  Out VPort + 4, 36
  Out VPort + 3, dx And 255 : Out VPort + 3, dx \ 256 : Out VPort + 3, dy And 255 : Out VPort + 3, dy \ 256
  Out VPort + 3, nx And 255 : Out VPort + 3, nx \ 256 : Out VPort + 3, ny And 255 : Out VPort + 3, ny \ 256
  Out VPort + 3, 0 : Out VPort + 3, &H0C                   ' ARG; logic: copy
  Out VPort + 3, 255 : Out VPort + 3, 255                  ' write mask
  Out VPort + 3, c : Out VPort + 3, c                      ' the colour
  Out VPort + 3, 0 : Out VPort + 3, 0                      ' (background colour)
  Out VPort + 3, op
End Sub

' Back(): the screen being drawn on (0 or 1)
Public Function Back() As Integer
  Back = bk
End Function

' Begin: drawing starts on the screen not shown: the box kept for it last time cleared - by the
' chip, while the program goes on (the next Spans waits for it)
Public Sub Begin()
  If ex1(bk) >= ex0(bk) Then VCmd ex0(bk), ey0(bk) + bk * 256, ex1(bk) - ex0(bk) + 1, ey1(bk) - ey0(bk) + 1, 0, &H20
End Sub

' Keep x0, y0, x1, y1: the box about to be drawn on this screen, to clear next time
Public Sub Keep(ByVal x0 As Integer, ByVal y0 As Integer, ByVal x1 As Integer, ByVal y1 As Integer)
  ex0(bk) = x0 : ey0(bk) = y0 : ex1(bk) = x1 : ey1(bk) = y1
End Sub

' Spans y0, y1, colour, tl, tr: lines y0-y1 filled from the left table's x to the right's (a
' byte for each line), in colour - on the screen being drawn
Public Sub Spans(ByVal y0 As Integer, ByVal y1 As Integer, ByVal c As Integer, ByVal tl As Integer, ByVal tr As Integer)
  SpansP y0, y1, c, tl, tr, bk
End Sub

Private Sub SpansP(ByVal y0 As Integer, ByVal y1 As Integer, ByVal c As Integer, ByVal tl As Integer, ByVal tr As Integer, ByVal pg As Integer)
#asm
            pop hl
            ld a, (hl)
            ld (sp_y), a
            pop hl
            ld a, (hl)
            ld (sp_y1), a
            pop hl
            ld a, (hl)
            ld (sp_c), a
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (sp_tl), de
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (sp_tr), de
            pop hl
            ld a, (hl)
            ld (sp_pg), a
            ld bc, {VPort} + 5  ; the registers that stay the same: NY 1, ARG, copy, mask, colour
sp_ce0:     in a, (c)
            rrca
            jr c, sp_ce0
            ld bc, {VPort} + 4
            ld a, 42
            out (c), a
            ld bc, {VPort} + 3
            ld a, 1
            out (c), a
            xor a
            out (c), a
            out (c), a
            ld a, #0C
            out (c), a
            ld a, #FF
            out (c), a
            out (c), a
            ld a, (sp_c)
            out (c), a
            out (c), a
sp_line:    ld a, (sp_y)
            ld e, a
            ld d, 0
            ld hl, (sp_tl)
            add hl, de
            ld b, (hl)          ; b: left
            ld hl, (sp_tr)
            add hl, de
            ld a, (hl)          ; a: right
            sub b
            jp c, sp_skip       ; (left past right: nothing)
            inc a
            ld c, a             ; c: NX (0: 256)
            ld a, b
            ld (sp_xa), a
            ld a, c
            ld (sp_n), a
            ld bc, {VPort} + 5
sp_ce:      in a, (c)
            rrca
            jr c, sp_ce
            ld bc, {VPort} + 4
            ld a, 36
            out (c), a
            ld bc, {VPort} + 3
            ld a, (sp_xa)
            out (c), a          ; DX
            xor a
            out (c), a
            ld a, (sp_y)
            out (c), a          ; DY (+ 256 a screen)
            ld a, (sp_pg)
            out (c), a
            ld a, (sp_n)
            out (c), a          ; NX
            cp 1
            ld a, 0
            adc a, 0
            out (c), a
            ld bc, {VPort} + 4
            ld a, 52
            out (c), a
            ld bc, {VPort} + 3
            ld a, #20
            out (c), a          ; LMMV
sp_skip:    ld a, (sp_y1)
            ld e, a
            ld a, (sp_y)
            cp e
            ret z
            inc a
            ld (sp_y), a
            jp sp_line
sp_y:       db 0
sp_y1:      db 0
sp_c:       db 0
sp_pg:      db 0
sp_xa:      db 0
sp_n:       db 0
sp_tl:      dw 0
sp_tr:      dw 0
#endasm
End Sub

' Show: at the frame, the screen just drawn shown; drawing goes to the other
Public Sub Show()
  WaitCE
  WaitFrame
  Reg 17, 0 : Reg 18, bk
  bk = 1 - bk
End Sub
