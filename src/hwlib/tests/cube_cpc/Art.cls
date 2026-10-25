' Art - Amstrad CPC cube (Cpc, mode 0): the test's ball (4 frames) and what else it needs, made by tools/art.py
' (don't edit: run the tool). (c) 2026 Cyborg Unicorn Pty Ltd
Option Explicit

' pens 0-15 as hardware colour numbers: 0 black, 1 white (the text), 2-7 the cube dark to light
Public Function Inks() As Integer
#asm
            pop hl              ; the result: the table's address
            ld de, art_inks
            ld (hl), e
            inc hl
            ld (hl), d
            ret                 ; (on along the thread; the table after it is never run)
art_inks:
            db #14, #0B, #04, #15, #17, #1F, #1B, #0B, #14, #14, #14, #14, #14, #14, #14, #14
#endasm
End Function
