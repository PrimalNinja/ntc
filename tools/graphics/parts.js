// parts.js - each platform's part of its Graphics class (see gen.js)
// (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'use strict';
var o = {};

o.ep128 = {
	header: `
' Graphics - drawing on the Enterprise's screen: the console's own bitmap (Nick, 2 colours),
' 320 x 200 in Mode 1 (40 columns) and 640 x 200 in Mode 2 (80 columns). NTC platform class:
' Enterprise 64 / 128. Print and the lines share the one picture. Pen 0 draws nothing.`,
	w: 'm_w', h: 200, wexpr: 'Wide()', bits: true, pennote: '0 = none, anything else = the ink',
	vars: 'Private m_w As Integer, m_bytes As Integer',
	start: `
  Size`,
	dot: `
  Dim a As Integer, m As Integer
  If m_pen = 0 Then
    Exit Sub
  End If
  a = &HC000 + y * m_bytes + (x \\ 8)
  m = Bits(x And 7)
  Poke a, Peek(a) Xor m`,
	extra: `
' the width now (the console's mode)
Private Sub Size()
  m_bytes = 40
  If StdIO.Cols() > 40 Then
    m_bytes = 80
  End If
  m_w = m_bytes * 8
End Sub

Private Function Wide() As Integer
  Size
  Wide = m_w
End Function`
};

o.trs80 = {
	header: `
' Graphics - drawing on the TRS-80 Model I's screen (and the System 80's) with its block graphics:
' each of the 64 x 16 characters is 2 dots wide and 3 high, so 128 x 48. NTC platform class:
' TRS-80 Model I, System 80. A character cell holds text or dots, not both: a dot drawn in a
' cell of text takes the letter off. Pen 0 draws nothing.`,
	w: 128, h: 48, pennote: '0 = none, anything else = on',
	dot: `
  Dim a As Integer, v As Integer, m As Integer
  If m_pen = 0 Then
    Exit Sub
  End If
  a = &H3C00 + (y \\ 3) * 64 + (x \\ 2)
  m = (y Mod 3) * 2 + (x And 1)
  Select Case m
    Case 0
      m = 1
    Case 1
      m = 2
    Case 2
      m = 4
    Case 3
      m = 8
    Case 4
      m = 16
    Case Else
      m = 32
  End Select
  v = Peek(a)
  If v < 128 Then
    v = 128
  End If
  v = v Xor m
  Poke a, v Or 128`
};

o.ti89 = {
	header: `
' Graphics - drawing on the TI-89's LCD (160 x 100, on or off), straight into its bitmap at
' $4C00 (30 bytes a row). NTC platform class: TI-89 / TI-92 Plus / Voyage 200 (the bigger
' screens show the same 160 x 100 at their top left). Pen 0 draws nothing.`,
	w: 160, h: 100, bits: true, pennote: '0 = none, anything else = on',
	dot: `
  Dim a As Integer, m As Integer
  If m_pen = 0 Then
    Exit Sub
  End If
  a = &H4C00 + y * 30 + (x \\ 8)
  m = Bits(x And 7)
  Poke a, Peek(a) Xor m`
};

o.ti83 = {
	header: `
' Graphics - drawing on the TI-83 Plus / TI-84 Plus LCD (96 x 64, on or off): dots go into the
' OS's graph buffer (plotSScreen, #9340) and each Line or Plot ends by having the OS copy the
' buffer to the LCD (_GrBufCpy). NTC platform class: TI-83 Plus / TI-84 Plus. The first line
' clears the buffer. Pen 0 draws nothing.`,
	w: 96, h: 64, bits: true, pennote: '0 = none, anything else = on',
	vars: 'Private m_sp As Integer',
	start: `
  Dim i As Integer
  For i = 0 To 767
    Poke &H9340 + i, 0
  Next`,
	dot: `
  Dim a As Integer, m As Integer
  If m_pen = 0 Then
    Exit Sub
  End If
  a = &H9340 + y * 12 + (x \\ 8)
  m = Bits(x And 7)
  Poke a, Peek(a) Xor m`,
	after: `
  Show`,
	extra: `
' the graph buffer copied to the LCD by the OS (IY = the OS's flags while it runs)
Private Sub Show()
#asm
            ld ({m_sp}), sp
            ld sp, (ntc_csp)
            push ix
            push iy
            ld iy, #89F0
            rst #28
            dw #486A            ; _GrBufCpy
            pop iy
            pop ix
            ld sp, ({m_sp})
#endasm
End Sub`
};

o.tms = {
	platforms: ['msx', 'sc3000', 'colecovision'],
	header: `
' Graphics - drawing on the TMS9918's Screen 2 (256 x 192) through the VDP class, a dot at a
' time by the CPU. NTC platform class: MSX (and the V9938 / V9990 card builds), Sega SC-3000,
' ColecoVision. The first line sets Screen 2 (the text goes: Mode or Cls brings the console
' back). Pens are the chip's colours 1-15; the chip keeps one ink for each 8 dots of a row, so
' lines of different pens that share 8 dots take the newer pen. Pen 1 is white (the pen that
' shows, as on the CPC); 2-15 are the chip's colours. Pen 0 draws nothing.`,
	w: 256, h: 192, pen: 1, bits: true, pennote: "1 = white, 2-15 the chip's colours; 0 = none",
	vars: 'Private m_ink As Integer',
	start: `
  VDP.Screen 2
  Ink`,
	penset: `
  Ink`,
	extra: `
' the byte for the chip's colour table: the pen as the ink, black as the paper. Pen 1 is white
' (15), as the CPC's pen 1 is the one that shows; 2-15 are the chip's own colours
Private Sub Ink()
  m_ink = (m_pen And 15) * 16 + 1
  If m_pen = 1 Then
    m_ink = 241
  End If
End Sub`,
	dot: `
  Dim a As Integer
  If m_pen = 0 Then
    Exit Sub
  End If
  a = (y \\ 8) * 256 + (x And 248) + (y And 7)
  VDP.VPoke a, VDP.VPeek(a) Xor Bits(x And 7)
  VDP.VPoke &H2000 + a, m_ink`
};

o.x68000 = {
	header: `
' Graphics - drawing on the Sharp X68000's graphics page (256 x 256, 256 colours) through the
' Vdp class (GPixel, GPlot). NTC platform class: Sharp X68000. The first line sets the Vdp
' class's screen up (Vdp.Init) and makes colour 1 white. Pens are the page's palette entries
' (Vdp.GColors sets them): 1-255. Pen 0 draws nothing.`,
	w: 256, h: 256, pennote: "1-255: the graphics page's palette entries; 0 = none",
	vars: 'Private m_pal As Integer',
	start: `
  Vdp.Init
  m_pal = &HFFFE
  Vdp.GColors VarPtr(m_pal), 1, 1`,
	dot: `
  If m_pen = 0 Then
    Exit Sub
  End If
  Vdp.GPlot x, y, Vdp.GPixel(x, y) Xor m_pen`
};

o.towns = {
	header: `
' Graphics - drawing on the FM Towns' back layer (256 x 240, 32768 colours) through the Vdp
' class (GPixel, GPlot). NTC platform class: Fujitsu FM Towns. The first line sets the Vdp
' class's screen up (Vdp.Init). Pen 1 is white (the pen that shows, as on the CPC); any other
' pen is the 15 bit colour itself (green in bits 10-14, red in 5-9, blue in 0-4). Pen 0 draws
' nothing.`,
	w: 256, h: 240, pennote: '1 = white, else a 15 bit colour; 0 = none',
	vars: 'Private m_col As Integer',
	start: `
  Vdp.Init
  Ink`,
	penset: `
  Ink`,
	extra: `
Private Sub Ink()
  m_col = m_pen
  If m_pen = 1 Then
    m_col = &H7FFF
  End If
End Sub`,
	dot: `
  If m_col = 0 Then
    Exit Sub
  End If
  Vdp.GPlot x, y, Vdp.GPixel(x, y) Xor m_col`
};

o.md = {
	header: `
' Graphics - drawing on the Sega Mega Drive, which has no bitmap: plane B's 40 x 28 cells are
' given a tile each (tiles 128-1247) and the dots are written into those tiles, so 320 x 224.
' NTC platform class: Sega Mega Drive / Genesis. A copy of the picture is kept in RAM (9K, a
' bit a dot: the chip's memory is not read back). The text (plane A) stays in front. Pens are
' palette 0's colours 1-15 (Vdp.Color sets them; 1 is the text's colour); the 8 dots of a row
' that share a byte take the newest pen. Pen 0 draws nothing.`,
	w: 320, h: 224, bits: true, pennote: "1-15: palette 0's colours; 0 = none",
	vars: 'Private m_sh(8959) As Byte, m_w(1) As Integer',
	start: `
  Dim cx As Integer, cy As Integer
  For cy = 0 To 27
    For cx = 0 To 39
      Vdp.Cell Vdp.PlaneB, cx, cy, 128 + cy * 40 + cx
    Next
  Next`,
	dot: `
  Dim i As Integer, b As Integer, p As Integer
  p = m_pen And 15
  If p = 0 Then
    Exit Sub
  End If
  i = y * 40 + (x \\ 8)
  b = m_sh(i) Xor Bits(x And 7)
  m_sh(i) = b
  m_w(0) = Spread(b \\ 16) * p
  m_w(1) = Spread(b And 15) * p
  Vdp.Copy VarPtr(m_w(0)), (128 + (y \\ 8) * 40 + (x \\ 8)) * 32 + (y And 7) * 4, 2`,
	extra: `
' four dots (bits 3-0, the left one first) as a tile row's four colour 1 nibbles
Private Function Spread(ByVal n As Integer) As Integer
  Dim v As Integer
  v = 0
  If (n And 8) <> 0 Then
    v = v + &H1000
  End If
  If (n And 4) <> 0 Then
    v = v + &H0100
  End If
  If (n And 2) <> 0 Then
    v = v + &H0010
  End If
  If (n And 1) <> 0 Then
    v = v + &H0001
  End If
  Spread = v
End Function`
};

o.amiga = {
	header: `
' Graphics - drawing on the Amiga's screen: the console's own bitplane, 640 wide and as many
' lines as the console has rows of 8 (256 on a PAL machine, 200 on an NTSC one), on or off.
' NTC platform class: Commodore Amiga. Print and the lines share the one picture. Pen 0 draws
' nothing.`,
	w: 640, h: 'm_h', hexpr: 'High()', pennote: '0 = none, anything else = on',
	vars: 'Private m_h As Integer',
	start: `
  m_h = Rows() * 8`,
	dot: `
  If m_pen = 0 Then
    Exit Sub
  End If
  Tog x, y`,
	extra: `
Private Function High() As Integer
  High = Rows() * 8
End Function

' the console's rows: 32 (PAL) or 25 (NTSC)
Private Function Rows() As Integer
#asm
            movea.l (sp)+, a0
            moveq #0, d0
            move.b ntc_srows, d0
            move.w d0, (a0)
#endasm
End Function

' one dot of the bitplane turned over
Private Sub Tog(ByVal x As Integer, ByVal y As Integer)
#asm
            movea.l (sp)+, a0
            move.w (a0), d1
            movea.l (sp)+, a0
            move.w (a0), d2
            mulu #80, d2
            moveq #0, d0
            move.w d1, d0
            lsr.w #3, d0
            add.l d0, d2
            movea.l ntc_ami_scr, a0
            not.b d1
            bchg d1, 0(a0, d2.l)
#endasm
End Sub`
};

o.neogeo = {
	header: `
' Graphics - drawing on the SNK Neo Geo, which has no bitmap and keeps its tiles in ROM: the fix
' layer's 40 x 28 cells show block tiles of 2 x 4 dots (tiles 256-511 of the S ROM, which
' test/ngbuild.js puts there with NTC's font), so 80 x 112 dots, each 4 x 2 of the TV's pixels.
' NTC platform class: SNK Neo Geo, Neo Geo CD. A cell holds text or dots, not both. A cartridge
' with its own S ROM needs those 256 tiles in it. Pen 1 is fix palette 0 (white at the start),
' pen 2 palette 1 ... pen 16 palette 15 (Vdp.Color sets a palette's colour 1); a cell's 8 dots
' take the newest pen. Pen 0 draws nothing.`,
	w: 80, h: 112, bits: true, pennote: '1-16: fix palettes 0-15; 0 = none',
	vars: 'Private m_sh(1119) As Byte',
	dot: `
  Dim i As Integer, b As Integer
  If m_pen = 0 Then
    Exit Sub
  End If
  i = (y \\ 4) * 40 + (x \\ 2)
  b = m_sh(i) Xor Bits(7 - ((y And 3) * 2 + (x And 1)))
  m_sh(i) = b
  Vdp.Cell x \\ 2, y \\ 4, ((m_pen - 1) And 15) * 4096 + 256 + b`
};

o.c64reu = {
	header: `
' Graphics - drawing on the Commodore 64's text screen with block characters: each of the 40 x
' 25 characters is 2 dots wide and 2 high, so 80 x 50 dots of 4 x 4 pixels. NTC platform class:
' Commodore 64 + REU. The first line makes characters 128-143 the sixteen blocks (in the
' program's own font at $E800). A character cell holds text or dots, not both. Pens are the
' C64's colours 1-15 (1 white); a cell's 4 dots take the newest pen. Pen 0 draws nothing.`,
	w: 80, h: 50, pennote: "1-15: the C64's colours; 0 = none",
	start: `
  Dim c As Integer, r As Integer, v As Integer
  For c = 0 To 15
    v = 0
    If (c And 1) <> 0 Then
      v = v + 240
    End If
    If (c And 2) <> 0 Then
      v = v + 15
    End If
    For r = 0 To 3
      Poke &HE800 + (128 + c) * 8 + r, v
    Next
    v = 0
    If (c And 4) <> 0 Then
      v = v + 240
    End If
    If (c And 8) <> 0 Then
      v = v + 15
    End If
    For r = 4 To 7
      Poke &HE800 + (128 + c) * 8 + r, v
    Next
  Next`,
	dot: `
  Dim a As Integer, c As Integer, m As Integer
  If (m_pen And 15) = 0 Then
    Exit Sub
  End If
  a = (y \\ 2) * 40 + (x \\ 2)
  c = Peek(&HE000 + a)
  If c < 128 Or c > 143 Then
    c = 128
  End If
  m = 1
  If (x And 1) <> 0 Then
    m = 2
  End If
  If (y And 1) <> 0 Then
    m = m * 4
  End If
  Poke &HE000 + a, 128 + ((c - 128) Xor m)
  Poke &HD800 + a, m_pen And 15`
};

o.m65 = {
	header: `
' Graphics - drawing on the MEGA65 through the Vic class's 320 x 200, 256 colour screen (Vic.Box
' a dot at a time, into both of its buffers). NTC platform class: MEGA65. The first line turns
' the Vic class's screen on (Vic.Screen 1) with a playfield of one column (Vic.Field 1), so a
' Vic.Update - which the text needs to show - clears only the left 8 dots. A copy of the
' picture is kept in RAM (8K, a bit a dot). Pens are the palette's entries: 1-15 the C64's
' colours (1 white), 16-255 set with Vic.Color. A dot turned off goes to colour 0. Pen 0 draws
' nothing.`,
	w: 320, h: 200, bits: true, pennote: "1-255: the palette's entries; 0 = none",
	vars: 'Private m_sh(7999) As Byte',
	start: `
  Vic.Screen 1
  Vic.Field 1`,
	dot: `
  Dim i As Integer, b As Integer, m As Integer
  If m_pen = 0 Then
    Exit Sub
  End If
  i = y * 40 + (x \\ 8)
  m = Bits(x And 7)
  b = m_sh(i) Xor m
  m_sh(i) = b
  If (b And m) <> 0 Then
    Vic.Box x, y, 1, 1, m_pen
  Else
    Vic.Box x, y, 1, 1, 0
  End If`
};

o.zxndot = {
	header: `
' Graphics - drawing on the Spectrum's own screen (256 x 192, the ULA's bitmap at #4000) from a
' ZX Spectrum Next dot command: the screen BASIC prints on. NTC platform class: ZX Spectrum Next
' dot commands (both models). The dots take the ink and paper already in each character cell.
' Pen 0 draws nothing.`,
	w: 256, h: 192, bits: true, pennote: '0 = none, anything else = on',
	dot: `
  Dim a As Integer
  If m_pen = 0 Then
    Exit Sub
  End If
  a = &H4000 + (y \\ 64) * 2048 + (y And 7) * 256 + ((y \\ 8) And 7) * 32 + (x \\ 8)
  Poke a, Peek(a) Xor Bits(x And 7)`
};

o.zxndotl = {
	header: `
' Graphics - drawing on the Spectrum's own screen (256 x 192, the ULA's bitmap) from a Large
' Model ZX Spectrum Next dot command: the screen BASIC prints on. NTC platform class: ZX Spectrum
' Next dot command, Large Model. The program's own pages are in the slots while it runs, so each
' dot puts the screen's page (10) in slot 2 for the one byte and the slot's own page back,
' interrupts held meanwhile. The dots take the ink and paper already in each character cell.
' Pen 0 draws nothing.`,
	w: 256, h: 192, bits: true, pennote: '0 = none, anything else = on',
	vars: 'Private m_pg As Integer',
	dot: `
  If m_pen = 0 Then
    Exit Sub
  End If
  Tog &H4000 + (y \\ 64) * 2048 + (y And 7) * 256 + ((y \\ 8) And 7) * 32 + (x \\ 8), Bits(x And 7)`,
	extra: `
' the byte at a (in the screen's page, seen at #4000) XORed with m
Private Sub Tog(ByVal a As Integer, ByVal m As Integer)
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            pop hl
            ld l, (hl)
            ld h, 0
            ld a, i
            di
            jp po, gdl_off
            inc h
gdl_off:
            ld bc, #243B
            ld a, #52
            out (c), a
            inc b
            in a, (c)
            ld ({m_pg}), a
            ld a, 10
            out (c), a
            ld a, (de)
            xor l
            ld (de), a
            ld a, ({m_pg})
            out (c), a
            dec h
            jr nz, gdl_end
            ei
gdl_end:
#endasm
End Sub`
};

o.mem = {
	platforms: ['baremetal', 'test', 'pcw16'],
	header: `
' Graphics - drawing into a picture kept in memory: 320 x 200, a bit a dot, 40 bytes a row, 8000
' bytes, the left dot of a byte its bit 7. NTC platform class: Bare Metal, the test harness and
' the PCW16 - platforms where NTC has no screen of the machine's to draw on. Buffer() is the
' picture's address: the platform's own code shows it (bare metal: yours), a test reads it. On
' the PCW16 nothing shows it yet. Pen 0 draws nothing.`,
	w: 320, h: 200, bits: true, pennote: '0 = none, anything else = on',
	vars: 'Private m_pic(7999) As Byte',
	dot: `
  Dim i As Integer
  If m_pen = 0 Then
    Exit Sub
  End If
  i = y * 40 + (x \\ 8)
  m_pic(i) = m_pic(i) Xor Bits(x And 7)`,
	extra: `
' Buffer(): the picture's address (8000 bytes)
Public Function Buffer() As Integer
  Buffer = VarPtr(m_pic(0))
End Function`
};

module.exports = o;
