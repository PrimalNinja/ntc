' Scroll - the copper scrolls Layer 2 sideways: not at all at the top (the scanner), by the stars'
' amount from line 44 (the sky), by the ground's from line 160 (the terrain). Show sets them for
' the next frame; Upload (straight after Frame) hands the list to the copper.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Option Explicit

Private cop(19) As Byte

Public Sub Show(ByVal stars As Integer, ByVal ground As Integer)
  cop(0) = &H80 : cop(1) = 0                ' line 0:
  cop(2) = &H16 : cop(3) = 0                '   no scroll
  cop(4) = &H80 : cop(5) = 44               ' line 44: the sky
  cop(6) = &H16 : cop(7) = stars And 255
  cop(8) = &H80 : cop(9) = 160              ' line 160: the ground
  cop(10) = &H16 : cop(11) = ground And 255
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
            ld e, 14
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
