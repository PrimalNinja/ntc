' Art - Amstrad CPC Plus cube (Cpc + Asic palette): the test's ball (4 frames) and what else it needs, made by tools/art.py
' (don't edit: run the tool). (c) 2026 Cyborg Unicorn Pty Ltd
Option Explicit

' pens 0-15 as hardware colour numbers (the start, before the ASIC palette)
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

' the ASIC palette for pens 0-15: 2 bytes each (red * 16 + blue, green): 0 black, 1 white, 2-15 the cube dark to light
Public Function Pal() As Integer
#asm
            pop hl              ; the result: the table's address
            ld de, art_pal
            ld (hl), e
            inc hl
            ld (hl), d
            ret                 ; (on along the thread; the table after it is never run)
art_pal:
            db #00, #00, #FF, #0F, #04, #00, #05, #01, #06, #02, #17, #03, #17, #04, #28, #05
            db #39, #06, #4A, #07, #5B, #08, #7C, #09, #8C, #0A, #AD, #0B, #CE, #0C, #EF, #0D
#endasm
End Function
