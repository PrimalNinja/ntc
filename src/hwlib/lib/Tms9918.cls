' Tms9918 - the TI TMS9918 (and TMS9928 / 9929) video chip: MSX1, the Sega SC-3000 / SG-1000,
' ColecoVision. 16K of video RAM through two ports; 32 sprites, 16 x 16 here, one colour each,
' 4 on a line (more on a line: Frame turns the order round each frame, so they flicker in turn
' instead of vanishing).
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' The ports: MSX #98 (data) / #99 (control); SC-3000, SG-1000: #BE / #BF (build with
' --const=SC3000). Interrupts stay off (NTC's turbo): Frame waits for the frame by reading the
' status (its frame bit).
'
' Modes (Mode, StdIO's Mode):
'   0  Text 1: 40 x 24 characters, no sprites
'   1  Graphic 1: 32 x 24 characters (a colour for each 8 of them), sprites
'   2  Graphic 2 (a bitmap, 2 colours in each 8 pixels) for vectors: text on the top 8 rows; below,
'      a 120 x 128 picture (columns 9-23, rows 8-23) drawn in RAM (Begin / Spans: shading by
'      dither patterns) and copied in by Show to the character set not shown, then that set's
'      name table shown (two sets and two name tables: no flicker, no tearing)
' Tables: patterns #0000, names #1800, colours #2000, sprite attributes #1B00, sprite patterns #3800.
'
' The game library's calls, the same in every chip's class (Zxn, Cpc, Asic, Tms9918, V9938,
' V9990): Init, Pattern, Put, Hide, Anim, Move, Bounds, Frame, X, Y. The TMS9918's own: Colour
' (a sprite's colour), the text (Cls, Locate, PutStr, NewLine: the project's StdIO calls them, so
' Print, Cls, Locate and Mode work on a machine with no firmware).
Option Explicit

#If SC3000 Then
Public Const VData = &HBE
Public Const VCtrl = &HBF
#Else
Public Const VData = &H98
Public Const VCtrl = &H99
#End If
Public Const Slots = 16            ' sprites this class keeps (the chip has 32)

Private sx(15) As Integer, sy(15) As Integer, vx(15) As Integer, vy(15) As Integer
Private pt(15) As Integer, af(15) As Integer, ac(15) As Integer, ad(15) As Integer, at(15) As Integer
Private son(15) As Integer, col(15) As Integer
Private bx0 As Integer, by0 As Integer, bx1 As Integer, by1 As Integer
Private md As Integer, cols As Integer, cx As Integer, cy As Integer, rot As Integer
Private fontAt As Integer
Private hs As Integer, pr0 As Integer, pr1 As Integer   ' Graphic 2: the set not shown; the rows drawn
Private buf(1919) As Byte          ' Graphic 2: the picture, character by character (15 x 16)
Private nm(31) As Byte             ' (a name table row)
Private sat(64) As Byte           ' the sprite list for the next frame (4 bytes a sprite, then #D0)

' ---- the chip

' Reg r, v: a register
Public Sub Reg(ByVal r As Integer, ByVal v As Integer)
  Out VCtrl, v
  Out VCtrl, &H80 Or r
End Sub

' VCopy vram, ram, n: n bytes from RAM to video RAM
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

' WaitFrame: until the chip's frame bit is set (reading the status clears it)
Public Sub WaitFrame()
#asm
            in a, ({VCtrl})     ; (a frame bit already set is cleared: wait for the next)
wf_loop:    in a, ({VCtrl})
            rlca
            jr nc, wf_loop
#endasm
End Sub

' ---- screen and text

' Init: the font in, Graphic 1, everything cleared
Public Sub Init()
  Dim i As Integer
  fontAt = Art.Font()
  For i = 0 To Slots - 1
    son(i) = 0 : vx(i) = 0 : vy(i) = 0 : ac(i) = 0 : col(i) = 15
  Next
  bx0 = 0 : by0 = 0 : bx1 = 239 : by1 = 175
  Mode 1
End Sub

' Mode m: 0 Text 1 (40 x 24), 1 Graphic 1 (32 x 24, sprites); the screen cleared
Public Sub Mode(ByVal m As Integer)
  If fontAt = 0 Then fontAt = Art.Font()
  md = m
  If m = 2 Then Mode2 : Exit Sub
  Reg 1, &H80                    ' (the screen off while the tables are set)
  VFill 0, 0, &H4000
  If m = 0 Then
    Reg 0, 0 : Reg 2, 6 : Reg 4, 0 : Reg 7, &HF4      ' white on dark blue
    cols = 40
  Else
    Reg 0, 0 : Reg 2, 6 : Reg 3, &H80 : Reg 4, 0 : Reg 5, &H36 : Reg 6, 7 : Reg 7, &H04
    cols = 32
    VFill &H2000, &HF4, 32         ' every character white on dark blue
  End If
  VCopy 32 * 8, fontAt, 95 * 8
  Cls
  If m = 0 Then Reg 1, &HD0 Else Reg 1, &HC2      ' on (Text: M1; Graphic 1: 16 x 16 sprites)
End Sub

Public Sub Cls()
  If md = 2 Then
    VFill &H1800, 32, 256 : VFill &H1C00, 32, 256  ' (the text rows only)
    cx = 0 : cy = 0
    Exit Sub
  End If
  VFill &H1800, 32, 960
  If md <> 0 Then VFill &H1B00, &HD0, 1            ' no sprites (the list ends at once)
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
    VFill &H1800 + cy * cols + cx, Asc(Mid$(s, i, 1)), 1
    If md = 2 Then VFill &H1C00 + cy * cols + cx, Asc(Mid$(s, i, 1)), 1
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
End Sub

' Colour n, c: sprite n's colour (the chip's 15: 6 dark red, 8 red, 9 light red, 10 dark yellow,
' 11 light yellow, 2 green, 7 cyan, 13 magenta, 15 white ...)
Public Sub Colour(ByVal n As Integer, ByVal c As Integer)
  col(n) = c
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

' Frame: wait for the frame, the sprite list to the chip at once (made the frame before), then
' each sprite moves and animates on, and the next list is made - its order turned round one each
' frame, so more than 4 on a line flicker in turn
Public Sub Frame()
  Dim i As Integer, j As Integer, k As Integer
  WaitFrame
  VCopy &H1B00, VarPtr(sat), Slots * 4 + 1
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
      sat(k) = sy(i) - 1            ' (the chip draws a sprite a line below its Y)
      sat(k + 1) = sx(i)
      sat(k + 2) = pt(i) * 4        ' (16 x 16: four 8 x 8 patterns)
      sat(k + 3) = col(i)
      k = k + 4
    End If
  Next
  sat(k) = &HD0                     ' the end of the list
  rot = (rot + 1) Mod Slots
End Sub

' ---- Graphic 2: a bitmap for vectors

Private Sub Mode2()
  Dim t As Integer, r As Integer, c As Integer
  Reg 1, &H80                    ' (the screen off)
  VFill 0, 0, &H4000
  Reg 0, &H02 : Reg 2, 6 : Reg 3, &HFF : Reg 4, &H03 : Reg 5, &H7F : Reg 6, 7 : Reg 7, &H04
  cols = 32
  VCopy 32 * 8, fontAt, 95 * 8   ' the font in the top third's set
  VFill &H2000, &HF4, &H800      ' the top third: white on dark blue
  VFill &H2800, &HB4, &H1000     ' the picture: light yellow on dark blue
  VFill &H3F80, &HD0, 1          ' no sprites
  For t = 0 To 1                 ' the name tables (set 0's, set 1's): rows 8-23
    For r = 8 To 23
      For c = 0 To 31
        If c >= 9 And c <= 23 Then nm(c) = t * 120 + (r And 7) * 15 + c - 9 Else nm(c) = 255
      Next
      VCopy &H1800 + t * &H400 + r * 32, VarPtr(nm), 32
    Next
  Next
  hs = 1 : pr0 = 0 : pr1 = -1
  Cls
  Reg 1, &HC0                    ' on
End Sub

' Back(): the picture being drawn (there's one: 0)
Public Function Back() As Integer
  Back = 0
End Function

' Begin: drawing starts: the picture's character rows drawn last time cleared
Public Sub Begin()
  If pr1 >= pr0 Then Fill VarPtr(buf) + pr0 * 120, (pr1 - pr0 + 1) * 120
End Sub

' Keep x0, y0, x1, y1: the box about to be drawn (picture coordinates 0-119, 0-127): its rows
' to clear next time
Public Sub Keep(ByVal x0 As Integer, ByVal y0 As Integer, ByVal x1 As Integer, ByVal y1 As Integer)
  pr0 = y0 \ 8 : pr1 = y1 \ 8
  If pr0 < 0 Then pr0 = 0
  If pr1 > 15 Then pr1 = 15
End Sub

' Fill a, n: n bytes of RAM cleared
Private Sub Fill(ByVal a As Integer, ByVal n As Integer)
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            pop hl
            ld c, (hl)
            inc hl
            ld b, (hl)
            ld a, b
            or c
            ret z
            ex de, hl
            ld (hl), 0
            dec bc
            ld a, b
            or c
            ret z
            ld d, h
            ld e, l
            inc de
            ldir
#endasm
End Sub

' Spans y0, y1, pat, tl, tr: lines y0-y1 filled from the left table's x to the right's (a byte for
' each line) with the 4 line dither pattern at pat (a byte a line, repeating)
Public Sub Spans(ByVal y0 As Integer, ByVal y1 As Integer, ByVal pat As Integer, ByVal tl As Integer, ByVal tr As Integer)
  SpansP y0, y1, pat, tl, tr, VarPtr(buf)
End Sub

' Show: the picture copied to the set not shown, and at the frame that set shown
Public Sub Show()
  VCopy &H0800 + hs * 960, VarPtr(buf), 960
  VCopy &H1000 + hs * 960, VarPtr(buf) + 960, 960
  WaitFrame
  Reg 2, 6 + hs
  hs = 1 - hs
End Sub

Private Sub SpansP(ByVal y0 As Integer, ByVal y1 As Integer, ByVal pat As Integer, ByVal tl As Integer, ByVal tr As Integer, ByVal bf As Integer)
#asm
            pop hl
            ld a, (hl)
            ld (sp_y), a
            pop hl
            ld a, (hl)
            ld (sp_y1), a
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (sp_pat), de
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
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (sp_bf), de
sp_line:    ld a, (sp_y)
            ld e, a
            ld d, 0
            ld hl, (sp_tl)
            add hl, de
            ld b, (hl)          ; b: left x
            ld hl, (sp_tr)
            add hl, de
            ld c, (hl)          ; c: right x
            ld a, c
            cp b
            jp c, sp_next       ; (left past right: nothing)
sp_ok:      ld a, e             ; the line's pattern byte
            and 3
            ld l, a
            ld h, 0
            ld de, (sp_pat)
            add hl, de
            ld a, (hl)
            ld (sp_p), a
            ld a, (sp_y)        ; hl: the picture at the line: (y \ 8) * 120 + (y and 7)
            rrca
            rrca
            rrca
            and #1F
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            ld d, h
            ld e, l             ; de: * 8
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl          ; * 128
            or a
            sbc hl, de          ; * 120
            ld a, (sp_y)
            and 7
            ld e, a
            ld d, 0
            add hl, de
            ld de, (sp_bf)
            add hl, de
            ld a, b             ; the end bits
            and 7
            ld (sp_lb), a
            ld a, c
            and 7
            ld (sp_rb), a
            ld a, b             ; the cells: first, how many after it
            rrca
            rrca
            rrca
            and #1F
            ld b, a
            ld a, c
            rrca
            rrca
            rrca
            and #1F
            sub b
            ld c, a
            ld a, b
            add a, a
            add a, a
            add a, a
            ld e, a
            ld d, 0
            add hl, de          ; hl: the first cell
            ld de, sp_lmask
            ld a, (sp_lb)
            add a, e
            ld e, a
            jr nc, sp_n1
            inc d
sp_n1:      ld a, (de)
            ld (sp_lm), a
            ld de, sp_rmask
            ld a, (sp_rb)
            add a, e
            ld e, a
            jr nc, sp_n2
            inc d
sp_n2:      ld a, (de)
            ld (sp_rm), a
            ld a, (sp_p)
            ld d, a             ; d: the pattern
            ld a, c
            or a
            jr nz, sp_multi
            ld a, (sp_lm)       ; one cell: both ends' masks
            ld e, a
            ld a, (sp_rm)
            and e
            ld e, a
            ld a, (hl)
            xor d
            and e
            xor (hl)
            ld (hl), a
            jr sp_next
sp_multi:   ld a, (sp_lm)
            ld e, a
            ld a, (hl)
            xor d
            and e
            xor (hl)
            ld (hl), a
            ld b, c
            dec b
            jr z, sp_last
sp_mid:     ld a, l
            add a, 8
            ld l, a
            jr nc, sp_n3
            inc h
sp_n3:      ld (hl), d
            djnz sp_mid
sp_last:    ld a, l
            add a, 8
            ld l, a
            jr nc, sp_n4
            inc h
sp_n4:      ld a, (sp_rm)
            ld e, a
            ld a, (hl)
            xor d
            and e
            xor (hl)
            ld (hl), a
sp_next:    ld a, (sp_y1)
            ld e, a
            ld a, (sp_y)
            cp e
            ret z
            inc a
            ld (sp_y), a
            jp sp_line
sp_y:       db 0
sp_y1:      db 0
sp_p:       db 0
sp_lb:      db 0
sp_rb:      db 0
sp_lm:      db 0
sp_rm:      db 0
sp_pat:     dw 0
sp_tl:      dw 0
sp_tr:      dw 0
sp_bf:      dw 0
sp_lmask:   db #FF, #7F, #3F, #1F, #0F, #07, #03, #01
sp_rmask:   db #80, #C0, #E0, #F0, #F8, #FC, #FE, #FF
#endasm
End Sub
