' Splash - the Cyborg Unicorn splash screen for the ZX Spectrum Next (NTC BASIC, platform zxn): the
' QR code of https://cyborgunicorn.com.au filling the screen, the unicorn's head in its middle (or a
' plain code), CYBORG UNICORN under it. It fades in (1 second), stays (3 seconds) and fades out (1
' second); a key cuts it short (a quick fade out). One command:
'
'   Splash.Show 1        ' with the unicorn
'   Splash.Show 0        ' the plain code (no hole, bigger modules)
'   Splash.Show 2        ' DEVELOPED USING NTC BASIC: the code of https://cyborgunicorn.com.au/ntc.htm
'
' Both, one after the other: Splash.Show 1 : Splash.Show 2. Each screen costs about 4K of main RAM;
' one the program doesn't show can be left out, with a #Const before this class (on the command
' line, the program's .bas before Splash.cls; or cli.js --const=):
'
'   #Const SplashNoLogo      ' no unicorn screen
'   #Const SplashNoPlain     ' no plain screen
'   #Const SplashNoNtc       ' no NTC BASIC screen
'
' Show with a screen that was left out does nothing.
'
' It can go in a bank (the screens and the code with it; main RAM keeps only the call stub):
'
'   Option Page SplashPg Loaded 20 = Splash
'   Option Page 0, &H4000, &H4000     ' the window reserved, page 0 (NTC 20261105-6 on)
'
' (c) 2026 Cyborg Unicorn Pty Ltd - made by tools/mksplash.py (do not edit the data by hand)
'
' The picture is a ZX Spectrum screen (assets/cyborgunicorn-logo.scr, -plain.scr, ntcbasic.scr), packed into this
' class (the unicorn's screen 3838 bytes packed, the plain one 4147, NTC BASIC's 4236), unpacked onto the ULA's screen (bank 5's page 10, put in slot 6 for it). The
' fade is the ULA's palette (32 entries: inks 0-15, papers 16-31, 9-bit colours through NextReg
' #44) stepped through 17 brightnesses.
' Show keeps and puts back what it changes: the ULA's palette, NextRegs #15 (sprites), #43 (the
' palette chosen), #56 (slot 6), #68 (the ULA), #69 (Layer 2), #6B (the tilemap). For its 5
' seconds only the ULA shows (white border: the code's quiet zone); the border is black after.
' The ULA's screen itself is left with the picture on it (the program draws its own over it).
' A key held when Show starts (the one that ran the program) doesn't count until it is let go.
' The internal jumps come back through JP (IX); no CALL, no PUSH (NTC's threaded code).
Option Explicit
Option SaveNex "SPLASH.DAT", 20     ' <--- NEW   the packed screens (tools/splashdat.py makes build/SPLASH.DAT) in page 20 of the NEX file; it was a Banks() Sub with MMU and INCBIN lines

' the picture packed at src unpacked, everything kept, the palette black
Private Sub Begin(ByVal src As Integer)
#asm
; SPW r: NextReg r = A (BC lost); SPR r: A = NextReg r
  MACRO SPW r
            ex af, af'
            ld a, r
            ld (ntc_zxsel), a
            ld bc, #243B
            out (c), a
            ex af, af'
            inc b
            out (c), a
  ENDM
  MACRO SPR r
            ld a, r
            ld (ntc_zxsel), a
            ld bc, #243B
            out (c), a
            inc b
            in a, (c)
  ENDM
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (spl_src), de
            SPR #56
            ld (spl_r56), a
            SPR #57
            ld (spl_r57), a
            SPR #6B
            ld (spl_r6b), a
            SPR #69
            ld (spl_r69), a
            SPR #15
            ld (spl_r15), a
            SPR #68
            ld (spl_r68), a
            SPR #43
            ld (spl_r43), a
            xor a                   ; the ULA's first palette, written and shown
            SPW #43
            ld hl, spl_pal          ; its 32 colours kept (9 bits: RRRGGGBB, then the blue's low bit)
            xor a
            ld (spl_i), a
spb_k:
            ld a, (spl_i)
            SPW #40
            SPR #41
            ld (hl), a
            inc hl
            SPR #44
            ld (hl), a
            inc hl
            ld a, (spl_i)
            inc a
            ld (spl_i), a
            cp 32
            jr nz, spb_k
            xor a                   ; all black
            SPW #40
            ld e, 64
spb_z:
            xor a
            SPW #44
            dec e
            jr nz, spb_z
            ld a, (spl_r69)         ; Layer 2 off, the tilemap off, sprites off, the ULA on
            and #7F
            SPW #69
            ld a, (spl_r6b)
            and #7F
            SPW #6B
            ld a, (spl_r15)
            and #FE
            SPW #15
            ld a, (spl_r68)
            and #7F
            SPW #68
            ld a, 7                 ; the border white (its colour is paper 7's: faded too)
            out (#FE), a
            ld a, 10                ; bank 5's page 10 (the ULA's screen) in slot 6
            SPW #56
            ld a, (spl_bank)        ; the packed screen is in bank 20, in slot 7
            SPW #57
            ld hl, (spl_src)
            ld de, #C000            ; unpacked: n < 128, n + 1 bytes as they are; else the next
spu_lp:                             ; byte n - 125 times
            ld a, (hl)
            inc hl
            cp 128
            jr nc, spu_rep
            inc a
            ld c, a
            ld b, 0
            ldir
            jr spu_chk
spu_rep:
            sub 125
            ld b, a
            ld a, (hl)
            inc hl
spu_r:
            ld (de), a
            inc de
            djnz spu_r
spu_chk:
            ld a, d
            cp #DB
            jr c, spu_lp
            ld a, (spl_r57)         ; slot 7 put back
            SPW #57
            ret
@spl_src:   dw 0
@spl_bank:  db 0
@spl_r57:   db 0
@spl_i:     db 0
@spl_r56:   db 0
@spl_r6b:   db 0
@spl_r69:   db 0
@spl_r15:   db 0
@spl_r68:   db 0
@spl_r43:   db 0
@spl_pal:   ds 64
@spl_lev:
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #01, #20, #00, #20, #01, #04, #00, #04, #01, #24, #00, #24, #01
            db #00, #00, #00, #01, #20, #00, #20, #01, #04, #00, #04, #01, #24, #00, #24, #01
            db #00, #00, #00, #01, #20, #00, #20, #01, #04, #00, #04, #01, #24, #00, #24, #01
            db #00, #00, #00, #01, #20, #00, #20, #01, #04, #00, #04, #01, #24, #00, #24, #01
            db #00, #00, #00, #01, #20, #00, #20, #01, #04, #00, #04, #01, #24, #00, #24, #01
            db #00, #00, #00, #01, #20, #00, #20, #01, #04, #00, #04, #01, #24, #00, #24, #01
            db #00, #00, #00, #01, #20, #00, #20, #01, #04, #00, #04, #01, #24, #00, #24, #01
            db #00, #00, #00, #01, #20, #00, #20, #01, #04, #00, #04, #01, #24, #00, #24, #01
            db #00, #00, #00, #01, #20, #00, #20, #01, #04, #00, #04, #01, #24, #00, #24, #01
            db #00, #00, #01, #00, #40, #00, #41, #00, #08, #00, #09, #00, #48, #00, #49, #00
            db #00, #00, #00, #01, #20, #00, #20, #01, #04, #00, #04, #01, #24, #00, #24, #01
            db #00, #00, #01, #00, #40, #00, #41, #00, #08, #00, #09, #00, #48, #00, #49, #00
            db #00, #00, #01, #00, #40, #00, #41, #00, #08, #00, #09, #00, #48, #00, #49, #00
            db #00, #00, #01, #00, #40, #00, #41, #00, #08, #00, #09, #00, #48, #00, #49, #00
            db #00, #00, #01, #00, #40, #00, #41, #00, #08, #00, #09, #00, #48, #00, #49, #00
            db #00, #00, #01, #00, #40, #00, #41, #00, #08, #00, #09, #00, #48, #00, #49, #00
            db #00, #00, #01, #00, #40, #00, #41, #00, #08, #00, #09, #00, #48, #00, #49, #00
            db #00, #00, #01, #01, #60, #00, #61, #01, #0C, #00, #0D, #01, #6C, #00, #6D, #01
            db #00, #00, #01, #00, #40, #00, #41, #00, #08, #00, #09, #00, #48, #00, #49, #00
            db #00, #00, #01, #01, #60, #00, #61, #01, #0C, #00, #0D, #01, #6C, #00, #6D, #01
            db #00, #00, #01, #00, #40, #00, #41, #00, #08, #00, #09, #00, #48, #00, #49, #00
            db #00, #00, #01, #01, #60, #00, #61, #01, #0C, #00, #0D, #01, #6C, #00, #6D, #01
            db #00, #00, #01, #00, #40, #00, #41, #00, #08, #00, #09, #00, #48, #00, #49, #00
            db #00, #00, #01, #01, #60, #00, #61, #01, #0C, #00, #0D, #01, #6C, #00, #6D, #01
            db #00, #00, #01, #01, #60, #00, #61, #01, #0C, #00, #0D, #01, #6C, #00, #6D, #01
            db #00, #00, #02, #00, #80, #00, #82, #00, #10, #00, #12, #00, #90, #00, #92, #00
            db #00, #00, #01, #01, #60, #00, #61, #01, #0C, #00, #0D, #01, #6C, #00, #6D, #01
            db #00, #00, #02, #00, #80, #00, #82, #00, #10, #00, #12, #00, #90, #00, #92, #00
            db #00, #00, #01, #01, #60, #00, #61, #01, #0C, #00, #0D, #01, #6C, #00, #6D, #01
            db #00, #00, #02, #00, #80, #00, #82, #00, #10, #00, #12, #00, #90, #00, #92, #00
            db #00, #00, #01, #01, #60, #00, #61, #01, #0C, #00, #0D, #01, #6C, #00, #6D, #01
            db #00, #00, #02, #00, #80, #00, #82, #00, #10, #00, #12, #00, #90, #00, #92, #00
            db #00, #00, #01, #01, #60, #00, #61, #01, #0C, #00, #0D, #01, #6C, #00, #6D, #01
            db #00, #00, #02, #00, #80, #00, #82, #00, #10, #00, #12, #00, #90, #00, #92, #00
            db #00, #00, #01, #01, #60, #00, #61, #01, #0C, #00, #0D, #01, #6C, #00, #6D, #01
            db #00, #00, #02, #00, #80, #00, #82, #00, #10, #00, #12, #00, #90, #00, #92, #00
            db #00, #00, #01, #01, #60, #00, #61, #01, #0C, #00, #0D, #01, #6C, #00, #6D, #01
            db #00, #00, #02, #01, #A0, #00, #A2, #01, #14, #00, #16, #01, #B4, #00, #B6, #01
            db #00, #00, #01, #01, #60, #00, #61, #01, #0C, #00, #0D, #01, #6C, #00, #6D, #01
            db #00, #00, #02, #01, #A0, #00, #A2, #01, #14, #00, #16, #01, #B4, #00, #B6, #01
            db #00, #00, #02, #00, #80, #00, #82, #00, #10, #00, #12, #00, #90, #00, #92, #00
            db #00, #00, #02, #01, #A0, #00, #A2, #01, #14, #00, #16, #01, #B4, #00, #B6, #01
            db #00, #00, #02, #00, #80, #00, #82, #00, #10, #00, #12, #00, #90, #00, #92, #00
            db #00, #00, #02, #01, #A0, #00, #A2, #01, #14, #00, #16, #01, #B4, #00, #B6, #01
            db #00, #00, #02, #00, #80, #00, #82, #00, #10, #00, #12, #00, #90, #00, #92, #00
            db #00, #00, #03, #00, #C0, #00, #C3, #00, #18, #00, #1B, #00, #D8, #00, #DB, #00
            db #00, #00, #02, #00, #80, #00, #82, #00, #10, #00, #12, #00, #90, #00, #92, #00
            db #00, #00, #03, #00, #C0, #00, #C3, #00, #18, #00, #1B, #00, #D8, #00, #DB, #00
            db #00, #00, #02, #00, #80, #00, #82, #00, #10, #00, #12, #00, #90, #00, #92, #00
            db #00, #00, #03, #00, #C0, #00, #C3, #00, #18, #00, #1B, #00, #D8, #00, #DB, #00
            db #00, #00, #02, #00, #80, #00, #82, #00, #10, #00, #12, #00, #90, #00, #92, #00
            db #00, #00, #03, #00, #C0, #00, #C3, #00, #18, #00, #1B, #00, #D8, #00, #DB, #00
            db #00, #00, #02, #01, #A0, #00, #A2, #01, #14, #00, #16, #01, #B4, #00, #B6, #01
            db #00, #00, #03, #01, #E0, #00, #E3, #01, #1C, #00, #1F, #01, #FC, #00, #FF, #01
            db #00, #00, #02, #01, #A0, #00, #A2, #01, #14, #00, #16, #01, #B4, #00, #B6, #01
            db #00, #00, #03, #01, #E0, #00, #E3, #01, #1C, #00, #1F, #01, #FC, #00, #FF, #01
            db #00, #00, #02, #01, #A0, #00, #A2, #01, #14, #00, #16, #01, #B4, #00, #B6, #01
            db #00, #00, #03, #01, #E0, #00, #E3, #01, #1C, #00, #1F, #01, #FC, #00, #FF, #01
            db #00, #00, #02, #01, #A0, #00, #A2, #01, #14, #00, #16, #01, #B4, #00, #B6, #01
            db #00, #00, #03, #01, #E0, #00, #E3, #01, #1C, #00, #1F, #01, #FC, #00, #FF, #01
#endasm
End Sub

' where each screen is packed (none: the screen left out, 0)
#If SplashNoLogo = 0 Then
Private Function LogoAt() As Integer
#asm
            ld a, 40
            ld (spl_bank), a
            ld de, #E000
            pop hl
            ld (hl), e
            inc hl
            ld (hl), d
            ret
#endasm
End Function
#End If

#If SplashNoPlain = 0 Then
Private Function PlainAt() As Integer
#asm
            ld a, 41
            ld (spl_bank), a
            ld de, #E000
            pop hl
            ld (hl), e
            inc hl
            ld (hl), d
            ret
#endasm
End Function
#End If

#If SplashNoNtc = 0 Then
Private Function NtcAt() As Integer
#asm
            ld a, 40
            ld (spl_bank), a
            ld de, #EEFE
            pop hl
            ld (hl), e
            inc hl
            ld (hl), d
            ret
#endasm
End Function
#End If

' the palette at brightness k (0 black - 16 full)
Private Sub Level(ByVal k As Integer)
#asm
            pop hl
            ld l, (hl)              ; spl_lev + k * 64
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, spl_lev
            add hl, de
            xor a
            SPW #43
            xor a
            SPW #40
            ld e, 64
spl_l:
            ld a, (hl)
            inc hl
            SPW #44
            dec e
            jr nz, spl_l
#endasm
End Sub

' everything put back as it was (the border black)
Private Sub Finish()
#asm
            xor a
            SPW #43
            xor a
            SPW #40
            ld hl, spl_pal
            ld e, 64
spf_l:
            ld a, (hl)
            inc hl
            SPW #44
            dec e
            jr nz, spf_l
            ld a, (spl_r43)
            SPW #43
            ld a, (spl_r68)
            SPW #68
            ld a, (spl_r15)
            SPW #15
            ld a, (spl_r69)
            SPW #69
            ld a, (spl_r6b)
            SPW #6B
            ld a, (spl_r56)
            SPW #56
            xor a                   ; the border black
            out (#FE), a
#endasm
End Sub

' 1 while any key is down
Private Function Key() As Integer
#asm
            xor a                   ; every half row at once
            in a, (#FE)
            cpl
            and #1F
            ld e, 0
            jr z, spk_n
            inc e
spk_n:
            pop hl
            ld (hl), e
            inc hl
            ld (hl), 0
#endasm
End Function

' the splash: n 1 the unicorn, 0 plain, 2 NTC BASIC
Public Sub Show(ByVal n As Integer)
  Dim a As Integer
  a = 0
#If SplashNoLogo = 0 Then
  If n = 1 Then a = LogoAt()
#End If
#If SplashNoPlain = 0 Then
  If n = 0 Then a = PlainAt()
#End If
#If SplashNoNtc = 0 Then
  If n = 2 Then a = NtcAt()
#End If
  If a <> 0 Then Run a
End Sub

' the screen packed at src: in (1 second: 16 steps, 3 frames each), 3 seconds, out (1 second); a key:
' out quickly
Private Sub Run(ByVal src As Integer)
  Dim k As Integer, t As Integer, held As Integer, skip As Integer, hold As Integer
  Begin src
  held = Key()
  skip = 0
  k = 0
  Do While k < 16 And skip = 0
    k = k + 1
    Level k
    For t = 1 To 3
      Frame
    Next
    If Key() = 0 Then
      held = 0
    ElseIf held = 0 Then
      skip = 1
    End If
  Loop
  hold = 0
  Do While hold < 150 And skip = 0
    Frame
    hold = hold + 1
    If Key() = 0 Then
      held = 0
    ElseIf held = 0 Then
      skip = 1
    End If
  Loop
  Do While k > 0
    k = k - 1
    Level k
    Frame
    If skip = 0 Then
      Frame
      Frame
    End If
  Loop
  Finish
End Sub
