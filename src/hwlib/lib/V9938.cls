' V9938 - the Yamaha V9938 video chip: MSX2 (and the V9958 of the MSX2+, which runs this the same).
' 128K of video RAM (this class uses the first 16K), a palette of 16 out of 512, 32 sprites of
' 16 x 16 with a colour for each line (sprite mode 2), 8 on a line (more on a line: Frame turns
' the order round each frame, so they flicker in turn instead of vanishing).
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' The ports: #98 data, #99 control, #9A palette. Interrupts stay off (NTC's turbo): Frame waits for
' the frame by reading status 0 (its frame bit).
'
' Modes (Mode, StdIO's Mode):
'   0  Text 1: 40 x 24 characters, no sprites
'   1  Graphic 3: 32 x 24 characters (a colour for each line of each), sprites with a colour a line
'   2  Text 2: 80 x 24 characters, no sprites
'   3  Graphic 4: 256 x 212 bitmap, 16 colours (a byte = 2 pixels), two pages shown in turn: for
'      vectors. Text is drawn on both pages (white on colour 1). Begin / Keep / Spans / Show draw with
'      the chip's own fill command (LMMV, a line at a time) on the page not shown
' Graphic 3's tables: patterns #0000 (3 x 2K, a set for each third of the screen), names #1800,
' sprite colours #1C00, sprite attributes #1E00, colours #2000 (3 x 2K), sprite patterns #3800.
'
' The game library's calls, the same in every chip's class (Zxn, Cpc, Asic, Tms9918, V9938,
' V9990): Init, Pattern, Put, Hide, Anim, Move, Bounds, Frame, X, Y. The V9938's own: Colour (a
' sprite in one colour), Lines (a sprite's colour for each of its 16 lines), Palette, the text
' (Cls, Locate, PutStr, NewLine: the project's StdIO calls them).
Option Explicit

Public Const VData = &H98
Public Const VCtrl = &H99
Public Const VPal = &H9A
Public Const Slots = 16            ' sprites this class keeps (the chip has 32)

Private sx(15) As Integer, sy(15) As Integer, vx(15) As Integer, vy(15) As Integer
Private pt(15) As Integer, af(15) As Integer, ac(15) As Integer, ad(15) As Integer, at(15) As Integer
Private son(15) As Integer, cl(15) As Integer
Private bx0 As Integer, by0 As Integer, bx1 As Integer, by1 As Integer
Private md As Integer, cols As Integer, cx As Integer, cy As Integer, rot As Integer
Private fontAt As Integer, nameAt As Integer
Private sat(64) As Byte            ' the sprite list for the next frame (4 bytes a sprite, then #D8)
Private sct(255) As Byte           ' the sprite colours for the next frame (16 lines a sprite)
Private one(255) As Byte           ' each slot's colours when set by Colour (16 bytes a slot)
Private bk As Integer              ' Graphic 4: the page drawn on (the other is shown)
Private ex0(1) As Integer, ey0(1) As Integer, ex1(1) As Integer, ey1(1) As Integer   ' drawn on each

' ---- the chip

' Reg r, v: a register
Public Sub Reg(ByVal r As Integer, ByVal v As Integer)
  Out VCtrl, v
  Out VCtrl, &H80 Or r
End Sub

' Palette n, r, g, b: colour n (0-15), each part 0-7
Public Sub Palette(ByVal n As Integer, ByVal r As Integer, ByVal g As Integer, ByVal b As Integer)
  Reg 16, n
  Out VPal, r * 16 + b
  Out VPal, g
End Sub

' VCopy vram, ram, n: n bytes from RAM to video RAM (the first 16K)
Public Sub VCopy(ByVal vram As Integer, ByVal ram As Integer, ByVal n As Integer)
#asm
            pop hl              ; vram
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld c, {VCtrl}
            out (c), e
            ld a, d
            and #3F
            or #40              ; write
            out (c), a
            pop hl              ; ram
            ld e, (hl)
            inc hl
            ld d, (hl)
            pop hl              ; n
            ld c, (hl)
            inc hl
            ld b, (hl)
            ex de, hl
cp_loop:    ld a, b
            or c
            jr z, cp_done
            ld a, (hl)
            out ({VData}), a
            inc hl
            dec bc
            jr cp_loop
cp_done:
#endasm
End Sub

' VFill vram, value, n: n bytes of video RAM set to value
Public Sub VFill(ByVal vram As Integer, ByVal v As Integer, ByVal n As Integer)
#asm
            pop hl              ; vram
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld c, {VCtrl}
            out (c), e
            ld a, d
            and #3F
            or #40
            out (c), a
            pop hl              ; value
            ld e, (hl)
            pop hl              ; n
            ld c, (hl)
            inc hl
            ld b, (hl)
fl_loop:    ld a, b
            or c
            jr z, fl_done
            ld a, e
            out ({VData}), a
            dec bc
            jr fl_loop
fl_done:
#endasm
End Sub

' WaitFrame: until status 0's frame bit is set (reading it clears it)
Public Sub WaitFrame()
#asm
            xor a               ; status register 0
            out ({VCtrl}), a
            ld a, #8F
            out ({VCtrl}), a
            in a, ({VCtrl})     ; (a frame bit already set is cleared: wait for the next)
wf_loop:    in a, ({VCtrl})
            rlca
            jr nc, wf_loop
#endasm
End Sub

' ---- screen and text

' Init: everything cleared, Graphic 3
Public Sub Init()
  Dim i As Integer
  For i = 0 To Slots - 1
    son(i) = 0 : vx(i) = 0 : vy(i) = 0 : ac(i) = 0
    Colour i, 15
  Next
  bx0 = 0 : by0 = 0 : bx1 = 239 : by1 = 175
  Mode 1
End Sub

' Mode m: 0 Text 1 (40 x 24), 1 Graphic 3 (32 x 24, sprites), 2 Text 2 (80 x 24); the screen cleared
Public Sub Mode(ByVal m As Integer)
  Dim i As Integer
  If fontAt = 0 Then fontAt = Art.Font()
  md = m
  If m = 3 Then Mode3 : Exit Sub
  Reg 1, &H80                    ' (the screen off while the tables are set)
  Reg 8, &H08 : Reg 9, 0 : Reg 14, 0 : Reg 11, 0 : Reg 13, 0     ' 64K chips, 192 lines, no blink
  VFill 0, 0, &H4000
  If m = 1 Then
    Reg 0, &H04 : Reg 2, &H06 : Reg 3, &HFF : Reg 10, 0 : Reg 4, &H03 : Reg 5, &H3F : Reg 6, &H07 : Reg 7, &H04
    cols = 32 : nameAt = &H1800
    For i = 0 To 2                 ' the font in each third's set, white on dark blue
      VCopy i * &H800 + 32 * 8, fontAt, 95 * 8
    Next
    VFill &H2000, &HF4, &H1800
  ElseIf m = 2 Then
    Reg 0, &H04 : Reg 2, &H03 : Reg 4, &H02 : Reg 7, &HF4
    cols = 80 : nameAt = 0
    VCopy &H1000 + 32 * 8, fontAt, 95 * 8
  Else
    Reg 0, 0 : Reg 2, &H06 : Reg 4, 0 : Reg 7, &HF4
    cols = 40 : nameAt = &H1800
    VCopy 32 * 8, fontAt, 95 * 8
  End If
  Cls
  If m = 1 Then Reg 1, &HC2 Else Reg 1, &HD0      ' on (Graphic 3: 16 x 16 sprites; text: M1)
End Sub

Public Sub Cls()
  If md = 3 Then
    VCmd 0, 0, 256, 212, &H11, &HC0              ' both pages colour 1 (HMMV)
    VCmd 0, 256, 256, 212, &H11, &HC0
    cx = 0 : cy = 0
    Exit Sub
  End If
  VFill nameAt, 32, cols * 24
  If md = 1 Then VFill &H1E00, &HD8, 1            ' no sprites (the list ends at once)
  cx = 0 : cy = 0
End Sub

' Locate x, y: 1 based, as the statement
Public Sub Locate(ByVal x As Integer, ByVal y As Integer)
  cx = x - 1 : cy = y - 1
End Sub

Public Sub PutStr(ByVal s As String Max 255)
  Dim i As Integer, n As Integer
  n = Len(s)
  For i = 1 To n
    If cx >= cols Then NewLine
    If md = 3 Then
      Glyph Asc(Mid$(s, i, 1))
    Else
      VFill nameAt + cy * cols + cx, Asc(Mid$(s, i, 1)), 1
    End If
    cx = cx + 1
  Next
End Sub

Public Sub NewLine()
  cx = 0
  cy = cy + 1
  If cy > 23 Then cy = 23
End Sub

' ---- sprites

' Pattern n: a 16 x 16 sprite pattern (32 bytes, the chip's order) from address a
Public Sub Pattern(ByVal n As Integer, ByVal a As Integer)
  VCopy &H3800 + n * 32, a, 32
End Sub

Public Sub Put(ByVal n As Integer, ByVal x As Integer, ByVal y As Integer, ByVal p As Integer)
  sx(n) = x : sy(n) = y : pt(n) = p : son(n) = 1 : ac(n) = 0
  If cl(n) = 0 Then Colour n, 15
End Sub

' Colour n, c: sprite n all in colour c
Public Sub Colour(ByVal n As Integer, ByVal c As Integer)
  Dim i As Integer
  For i = 0 To 15
    one(n * 16 + i) = c
  Next
  cl(n) = VarPtr(one) + n * 16
End Sub

' Lines n, a: sprite n's colour for each of its 16 lines, from 16 bytes at address a
Public Sub Lines(ByVal n As Integer, ByVal a As Integer)
  cl(n) = a
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

' Frame: wait for the frame, the sprite list and colours to the chip at once (made the frame
' before), then each sprite moves and animates on, and the next list is made - its order turned
' round one each frame, so more than 8 on a line flicker in turn
Public Sub Frame()
  Dim i As Integer, j As Integer, k As Integer
  WaitFrame
  VCopy &H1C00, VarPtr(sct), 256
  VCopy &H1E00, VarPtr(sat), Slots * 4 + 1
  For i = 0 To Slots - 1
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
    End If
  Next
  k = 0
  For j = 0 To Slots - 1
    i = (j + rot) Mod Slots
    If son(i) Then
      sat(k * 4) = sy(i) - 1        ' (the chip draws a sprite a line below its Y)
      sat(k * 4 + 1) = sx(i)
      sat(k * 4 + 2) = pt(i) * 4    ' (16 x 16: four 8 x 8 patterns)
      CopyMem VarPtr(sct) + k * 16, cl(i), 16
      k = k + 1
    End If
  Next
  sat(k * 4) = &HD8                 ' the end of the list
  rot = (rot + 1) Mod Slots
End Sub

' CopyMem dst, src, n: n (1-255) bytes in RAM
Private Sub CopyMem(ByVal dst As Integer, ByVal src As Integer, ByVal n As Integer)
#asm
            pop hl              ; dst
            ld e, (hl)
            inc hl
            ld d, (hl)
            pop hl              ; src
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            pop bc              ; n (its low byte)
            ld a, (bc)
            ld c, a
            ld b, 0
            ldir
#endasm
End Sub

' ---- Graphic 4: a bitmap for vectors

Private Sub Mode3()
  Reg 1, 0                       ' (the screen off)
  Reg 0, &H06 : Reg 8, &H0A : Reg 9, &H80 : Reg 14, 0     ' Graphic 4; 64K chips, no sprites; 212 lines
  Reg 2, &H1F : Reg 7, 1          ' page 0 shown; the border colour 1
  Palette 1, 0, 0, 3              ' the background: dark blue
  Palette 15, 7, 7, 7             ' the text: white
  cols = 32 : bk = 1
  ex0(0) = 0 : ex1(0) = -1 : ex0(1) = 0 : ex1(1) = -1
  Cls
  Reg 1, &H40                    ' on
End Sub

' Glyph c: character c at the cursor on both pages (white on colour 1)
Private Sub Glyph(ByVal c As Integer)
  If c < 32 Or c > 126 Then c = 32
  GlyphA 0, cy * 1024 + cx * 4, fontAt + (c - 32) * 8
  GlyphA 1, cy * 1024 + cx * 4, fontAt + (c - 32) * 8
End Sub

' GlyphA page, a, src: 8 rows of 1 bit from src as Graphic 4 pixels (15 on 1) at a, 128 apart
Private Sub GlyphA(ByVal page As Integer, ByVal a As Integer, ByVal src As Integer)
#asm
            pop hl
            ld a, (hl)
            add a, a
            ld (ga_pg), a       ; page * 2
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)          ; de: the address
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a             ; hl: the font
            ld c, 8
ga_row:     ld a, d             ; R14: page * 2 + address bit 14
            rlca
            rlca
            and 1
            ld b, a
            ld a, (ga_pg)
            or b
            out ({VCtrl}), a
            ld a, #8E
            out ({VCtrl}), a
            ld a, e
            out ({VCtrl}), a
            ld a, d
            and #3F
            or #40
            out ({VCtrl}), a
            ld b, (hl)          ; the row's bits
            inc hl
            ld a, #11           ; two pixels: colour 1, 1 ...
            sla b
            jr nc, ga_h0
            or #F0              ; ... 15 on the left
ga_h0:      sla b
            jr nc, ga_l0
            or #0F              ; ... 15 on the right
ga_l0:      out ({VData}), a
            ld a, #11           ; two pixels: colour 1, 1 ...
            sla b
            jr nc, ga_h1
            or #F0              ; ... 15 on the left
ga_h1:      sla b
            jr nc, ga_l1
            or #0F              ; ... 15 on the right
ga_l1:      out ({VData}), a
            ld a, #11           ; two pixels: colour 1, 1 ...
            sla b
            jr nc, ga_h2
            or #F0              ; ... 15 on the left
ga_h2:      sla b
            jr nc, ga_l2
            or #0F              ; ... 15 on the right
ga_l2:      out ({VData}), a
            ld a, #11           ; two pixels: colour 1, 1 ...
            sla b
            jr nc, ga_h3
            or #F0              ; ... 15 on the left
ga_h3:      sla b
            jr nc, ga_l3
            or #0F              ; ... 15 on the right
ga_l3:      out ({VData}), a
            ld a, e             ; the next row: 128 on
            add a, #80
            ld e, a
            jr nc, ga_nc
            inc d
ga_nc:      dec c
            jr nz, ga_row
            ret
ga_pg:      db 0
#endasm
End Sub

' VAddr17 page, a: the video RAM address to write next: Graphic 4 page (0-3, 32K each), address
' in it
Public Sub VAddr17(ByVal page As Integer, ByVal a As Integer)
  Reg 14, page * 2 + ((a \ 16384) And 1)
  Out VCtrl, a And 255
  Out VCtrl, ((a \ 256) And &H3F) Or &H40
End Sub

' GlyphRow b, fg, bg: 8 pixels of 1 bit (b) as 4 Graphic 4 bytes at the address set
Private Sub GlyphRow(ByVal b As Integer, ByVal fg As Integer, ByVal bg As Integer)
#asm
            pop hl
            ld e, (hl)          ; the bits
            pop hl
            ld d, (hl)          ; fg
            pop hl
            ld l, (hl)          ; bg
            ld b, 4
gr_loop:    ld a, l
            sla e
            jr nc, gr_1
            ld a, d
gr_1:       rlca
            rlca
            rlca
            rlca
            ld h, a
            ld a, l
            sla e
            jr nc, gr_2
            ld a, d
gr_2:       or h
            out ({VData}), a
            djnz gr_loop
#endasm
End Sub

' WaitCE: until the chip's command (fill, copy ...) is done
Public Sub WaitCE()
#asm
            ld a, 2             ; status register 2
            out ({VCtrl}), a
            ld a, #8F
            out ({VCtrl}), a
ce_loop:    in a, ({VCtrl})
            rrca
            jr c, ce_loop
            xor a
            out ({VCtrl}), a
            ld a, #8F
            out ({VCtrl}), a
#endasm
End Sub

' VCmd dx, dy, nx, ny, colour, command: a chip command on a rectangle (#C0 HMMV: fill by bytes,
' #80 LMMV: fill by pixels ...). dy: 256 a page
Public Sub VCmd(ByVal dx As Integer, ByVal dy As Integer, ByVal nx As Integer, ByVal ny As Integer, ByVal c As Integer, ByVal cmd As Integer)
  WaitCE
  Reg 17, 36
  Out &H9B, dx And 255 : Out &H9B, dx \ 256 : Out &H9B, dy And 255 : Out &H9B, dy \ 256
  Out &H9B, nx And 255 : Out &H9B, nx \ 256 : Out &H9B, ny And 255 : Out &H9B, ny \ 256
  Out &H9B, c : Out &H9B, 0 : Out &H9B, cmd
End Sub

' Back(): the page being drawn on (0 or 1)
Public Function Back() As Integer
  Back = bk
End Function

' Begin: drawing starts on the page not shown: the box kept for it last time cleared - by the
' chip (HMMV), while the program goes on (the next Spans waits for it)
Public Sub Begin()
  Dim a As Integer
  If ex1(bk) >= ex0(bk) Then
    a = ex0(bk) And &HFE
    VCmd a, ey0(bk) + bk * 256, (ex1(bk) Or 1) - a + 1, ey1(bk) - ey0(bk) + 1, &H11, &HC0
  End If
End Sub

' Keep x0, y0, x1, y1: the box about to be drawn on this page, to clear next time
Public Sub Keep(ByVal x0 As Integer, ByVal y0 As Integer, ByVal x1 As Integer, ByVal y1 As Integer)
  ex0(bk) = x0 : ey0(bk) = y0 : ex1(bk) = x1 : ey1(bk) = y1
End Sub

' Spans y0, y1, colour, tl, tr: lines y0-y1 filled from the left table's x to the right's (a
' byte for each line), in colour - on the page being drawn
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
            ld a, 2             ; status register 2 (the command's busy bit) while filling
            out ({VCtrl}), a
            ld a, #8F
            out ({VCtrl}), a
sp_ce0:     in a, ({VCtrl})     ; the registers that stay the same: the colour, ARG
            rrca
            jr c, sp_ce0
            ld a, 42
            out ({VCtrl}), a
            ld a, #91
            out ({VCtrl}), a
            ld a, 1
            out (#9B), a
            xor a
            out (#9B), a
            ld a, (sp_c)
            out (#9B), a
            xor a
            out (#9B), a
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
sp_ce:      in a, ({VCtrl})
            rrca
            jr c, sp_ce
            ld a, 36            ; DX, DY, NX, NY
            out ({VCtrl}), a
            ld a, #91
            out ({VCtrl}), a
            ld a, b
            out (#9B), a
            xor a
            out (#9B), a
            ld a, (sp_y)
            out (#9B), a
            ld a, (sp_pg)
            out (#9B), a
            ld a, c
            out (#9B), a
            cp 1
            ld a, 0
            adc a, 0
            out (#9B), a
            ld a, 1             ; NY 1 (the chip counts it down: set each time)
            out (#9B), a
            xor a
            out (#9B), a
            ld a, #80           ; R46 = LMMV
            out ({VCtrl}), a
            ld a, #AE
            out ({VCtrl}), a
sp_skip:    ld a, (sp_y1)
            ld e, a
            ld a, (sp_y)
            cp e
            jr z, sp_done
            inc a
            ld (sp_y), a
            jp sp_line
sp_done:    xor a               ; status register 0 again
            out ({VCtrl}), a
            ld a, #8F
            out ({VCtrl}), a
            ret
sp_y:       db 0
sp_y1:      db 0
sp_c:       db 0
sp_pg:      db 0
sp_tl:      dw 0
sp_tr:      dw 0
#endasm
End Sub

' Show: at the frame, the page just drawn shown; drawing goes to the other
Public Sub Show()
  WaitCE
  WaitFrame
  Reg 2, bk * 32 + &H1F
  bk = 1 - bk
End Sub
