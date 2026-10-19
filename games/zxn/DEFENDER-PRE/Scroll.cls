' Scroll - NTC build: the copper scrolls Layer 2 sideways from line 160 down (the terrain) and
' not above it (the scanner). Show sets the scroll for the next frame; Upload (straight after
' Frame) hands the list to the copper.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Option Explicit

Private cop(15) As Byte

Public Sub Show(ByVal sx As Integer)
  cop(0) = &H80 : cop(1) = 0                ' line 0:
  cop(2) = &H16 : cop(3) = 0                '   no scroll
  cop(4) = &H80 : cop(5) = 160              ' line 160:
  cop(6) = &H16 : cop(7) = sx And 255       '   the terrain's scroll
  cop(8) = &HFF : cop(9) = &HFF             ' the end
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
            ld e, 10
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
