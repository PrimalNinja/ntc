' Scroll - NTC build: the copper scrolls Layer 2 sideways in three bands: the scanner (lines 0-43)
' not at all, the sky and its stars (44-158) slowly, the terrain (159 down) with the camera.
' Show sets the two scrolls for the next frame; Upload (straight after Frame) hands the list to
' the copper.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Option Explicit

Private cop(15) As Byte

Public Sub Show(ByVal stars As Integer, ByVal sx As Integer)     ' <--- CHANGED (Main.bas gives two scrolls: the stars', the terrain's)
  cop(0) = &H80 : cop(1) = 0                ' line 0:
  cop(2) = &H16 : cop(3) = 0                '   no scroll (the scanner)
  cop(4) = &H80 : cop(5) = 44               ' <--- NEW   line 44:
  cop(6) = &H16 : cop(7) = stars And 255    ' <--- NEW     the stars' scroll
  cop(8) = &H80 : cop(9) = 159              ' line 159:
  cop(10) = &H16 : cop(11) = sx And 255     '   the terrain's scroll
  cop(12) = &HFF : cop(13) = &HFF           ' the end
End Sub

Public Sub Upload()
#asm
            ld bc, #243B
            ld a, #61
            out (c), a
            inc b
            xor a
            out (c), a
            dec b
            ld a, #62
            out (c), a
            inc b
            xor a
            out (c), a              ; stopped, index 0
            dec b
            ld a, #60
            out (c), a
            inc b
            ld hl, {cop}
            ld e, 14                ; <--- CHANGED (was 10: the list is 14 bytes now)
sc_lp:
            ld a, (hl)
            out (c), a
            inc hl
            dec e
            jr nz, sc_lp
            dec b
            ld a, #62
            out (c), a
            inc b
            ld a, #C0
            out (c), a              ; start: from 0, again at each frame
#endasm
End Sub
