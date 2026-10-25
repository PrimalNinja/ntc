' Art - ZX Spectrum Next (Zxn): the test's ball (4 frames) and what else it needs, made by tools/art.py
' (don't edit: run the tool). (c) 2026 Cyborg Unicorn Pty Ltd
Option Explicit

' the ball: 4 frames of 16 x 16, 8 bit (RGB332, #E3 see-through)
Public Function Ball() As Integer
#asm
            pop hl              ; the result: the table's address
            ld de, art_ball
            ld (hl), e
            inc hl
            ld (hl), d
            ret                 ; (on along the thread; the table after it is never run)
art_ball:
            db #E3, #E3, #E3, #E3, #E3, #E3, #E3, #E8, #D8, #E3, #E3, #E3, #E3, #E3, #E3, #E3
            db #E3, #E3, #E3, #E3, #F1, #F1, #F1, #F1, #FD, #FD, #D8, #80, #E3, #E3, #E3, #E3
            db #E3, #E3, #E3, #FD, #F1, #F1, #F1, #F1, #FD, #FD, #D8, #80, #60, #E3, #E3, #E3
            db #E3, #E3, #FD, #FD, #F1, #F1, #F1, #F1, #FD, #FD, #FF, #80, #80, #60, #E3, #E3
            db #E3, #FD, #FD, #FD, #F1, #F1, #F1, #F1, #FD, #FF, #FF, #FF, #80, #60, #20, #E3
            db #E3, #FD, #FD, #FD, #F1, #F1, #F1, #E8, #FD, #FF, #FF, #FF, #60, #20, #20, #E3
            db #E3, #FD, #FD, #FD, #F1, #F1, #E8, #E8, #FD, #D8, #FF, #80, #60, #20, #20, #E3
            db #E8, #FD, #FD, #FD, #E8, #E8, #E8, #E8, #D8, #D8, #D8, #60, #60, #20, #20, #B4
            db #C4, #FD, #FD, #FD, #E8, #E8, #C4, #C4, #D8, #D8, #D8, #60, #20, #20, #20, #B4
            db #E3, #D8, #FD, #FD, #C4, #C4, #C4, #C4, #D8, #D8, #B4, #20, #20, #20, #20, #E3
            db #E3, #D8, #D8, #D8, #C4, #C4, #80, #80, #B4, #B4, #B4, #20, #20, #20, #20, #E3
            db #E3, #D8, #D8, #D8, #80, #80, #80, #60, #B4, #B4, #B4, #20, #20, #20, #20, #E3
            db #E3, #E3, #B4, #B4, #60, #60, #60, #20, #B4, #B4, #B4, #20, #20, #20, #E3, #E3
            db #E3, #E3, #E3, #B4, #20, #20, #20, #20, #B4, #B4, #B4, #20, #20, #E3, #E3, #E3
            db #E3, #E3, #E3, #E3, #20, #20, #20, #20, #B4, #B4, #B4, #20, #E3, #E3, #E3, #E3
            db #E3, #E3, #E3, #E3, #E3, #E3, #E3, #20, #B4, #E3, #E3, #E3, #E3, #E3, #E3, #E3
            db #E3, #E3, #E3, #E3, #E3, #E3, #E3, #FD, #C4, #E3, #E3, #E3, #E3, #E3, #E3, #E3
            db #E3, #E3, #E3, #E3, #FD, #FD, #FD, #F1, #E8, #E8, #C4, #80, #E3, #E3, #E3, #E3
            db #E3, #E3, #E3, #FD, #FD, #FD, #F1, #F1, #E8, #E8, #C4, #80, #B4, #E3, #E3, #E3
            db #E3, #E3, #FD, #FD, #FD, #F1, #F1, #F1, #E8, #E8, #FF, #D8, #D8, #B4, #E3, #E3
            db #E3, #FD, #FD, #FD, #F1, #F1, #F1, #F1, #E8, #FF, #FF, #FF, #D8, #60, #20, #E3
            db #E3, #FD, #FD, #F1, #F1, #F1, #F1, #E8, #E8, #FF, #FF, #FF, #60, #20, #20, #E3
            db #E3, #FD, #F1, #F1, #F1, #F1, #E8, #E8, #FD, #D8, #FF, #80, #60, #20, #20, #E3
            db #FD, #E8, #F1, #F1, #E8, #E8, #E8, #FD, #D8, #D8, #80, #60, #60, #20, #20, #20
            db #C4, #E8, #E8, #E8, #E8, #E8, #D8, #D8, #D8, #80, #80, #60, #20, #20, #20, #B4
            db #E3, #C4, #E8, #E8, #C4, #D8, #D8, #D8, #80, #80, #60, #20, #20, #20, #B4, #E3
            db #E3, #C4, #C4, #C4, #D8, #D8, #D8, #80, #60, #60, #20, #20, #20, #B4, #B4, #E3
            db #E3, #80, #80, #D8, #D8, #D8, #80, #60, #60, #20, #20, #20, #B4, #B4, #B4, #E3
            db #E3, #E3, #B4, #B4, #B4, #60, #60, #20, #20, #20, #20, #B4, #B4, #B4, #E3, #E3
            db #E3, #E3, #E3, #B4, #20, #20, #20, #20, #20, #20, #B4, #B4, #B4, #E3, #E3, #E3
            db #E3, #E3, #E3, #E3, #20, #20, #20, #20, #20, #B4, #B4, #B4, #E3, #E3, #E3, #E3
            db #E3, #E3, #E3, #E3, #E3, #E3, #E3, #20, #B4, #E3, #E3, #E3, #E3, #E3, #E3, #E3
            db #E3, #E3, #E3, #E3, #E3, #E3, #E3, #FD, #D8, #E3, #E3, #E3, #E3, #E3, #E3, #E3
            db #E3, #E3, #E3, #E3, #F1, #F1, #F1, #F1, #E8, #E8, #C4, #80, #E3, #E3, #E3, #E3
            db #E3, #E3, #E3, #F1, #F1, #F1, #F1, #F1, #E8, #E8, #C4, #80, #60, #E3, #E3, #E3
            db #E3, #E3, #F1, #F1, #F1, #F1, #F1, #F1, #E8, #E8, #FF, #80, #80, #60, #E3, #E3
            db #E3, #F1, #F1, #F1, #F1, #F1, #F1, #F1, #E8, #FF, #FF, #FF, #80, #60, #20, #E3
            db #E3, #FD, #FD, #FD, #FD, #FD, #FD, #FD, #FD, #FF, #FF, #FF, #B4, #B4, #B4, #E3
            db #E3, #FD, #FD, #FD, #FD, #FD, #FD, #FD, #FD, #D8, #FF, #D8, #B4, #B4, #B4, #E3
            db #FD, #FD, #FD, #FD, #FD, #FD, #FD, #FD, #D8, #D8, #D8, #B4, #B4, #B4, #B4, #B4
            db #C4, #E8, #E8, #E8, #E8, #E8, #C4, #C4, #C4, #80, #80, #60, #20, #20, #20, #20
            db #E3, #C4, #E8, #E8, #C4, #C4, #C4, #C4, #80, #80, #60, #20, #20, #20, #20, #E3
            db #E3, #C4, #C4, #C4, #C4, #C4, #80, #80, #60, #60, #20, #20, #20, #20, #20, #E3
            db #E3, #80, #80, #80, #80, #80, #80, #60, #60, #20, #20, #20, #20, #20, #20, #E3
            db #E3, #E3, #B4, #B4, #B4, #B4, #B4, #B4, #B4, #B4, #B4, #B4, #B4, #B4, #E3, #E3
            db #E3, #E3, #E3, #B4, #B4, #B4, #B4, #B4, #B4, #B4, #B4, #B4, #B4, #E3, #E3, #E3
            db #E3, #E3, #E3, #E3, #B4, #B4, #B4, #B4, #B4, #B4, #B4, #B4, #E3, #E3, #E3, #E3
            db #E3, #E3, #E3, #E3, #E3, #E3, #E3, #20, #20, #E3, #E3, #E3, #E3, #E3, #E3, #E3
            db #E3, #E3, #E3, #E3, #E3, #E3, #E3, #E8, #C4, #E3, #E3, #E3, #E3, #E3, #E3, #E3
            db #E3, #E3, #E3, #E3, #FD, #FD, #FD, #FD, #E8, #E8, #C4, #80, #E3, #E3, #E3, #E3
            db #E3, #E3, #E3, #F1, #F1, #FD, #FD, #FD, #FD, #E8, #C4, #80, #60, #E3, #E3, #E3
            db #E3, #E3, #F1, #F1, #F1, #F1, #FD, #FD, #FD, #FD, #FF, #80, #80, #60, #E3, #E3
            db #E3, #FD, #F1, #F1, #F1, #F1, #F1, #FD, #FD, #FF, #FF, #FF, #80, #60, #20, #E3
            db #E3, #FD, #FD, #F1, #F1, #F1, #F1, #E8, #FD, #FF, #FF, #FF, #60, #20, #20, #E3
            db #E3, #FD, #FD, #FD, #F1, #F1, #E8, #E8, #E8, #D8, #FF, #D8, #B4, #20, #20, #E3
            db #E8, #FD, #FD, #FD, #FD, #E8, #E8, #E8, #C4, #C4, #D8, #B4, #B4, #B4, #20, #20
            db #C4, #E8, #FD, #FD, #FD, #FD, #C4, #C4, #C4, #80, #80, #B4, #B4, #B4, #B4, #20
            db #E3, #C4, #E8, #FD, #D8, #D8, #D8, #C4, #80, #80, #60, #20, #B4, #B4, #B4, #E3
            db #E3, #C4, #C4, #C4, #D8, #D8, #D8, #D8, #60, #60, #20, #20, #20, #B4, #B4, #E3
            db #E3, #80, #80, #80, #80, #D8, #D8, #B4, #B4, #20, #20, #20, #20, #20, #B4, #E3
            db #E3, #E3, #60, #60, #60, #60, #B4, #B4, #B4, #B4, #20, #20, #20, #20, #E3, #E3
            db #E3, #E3, #E3, #20, #20, #20, #20, #B4, #B4, #B4, #B4, #20, #20, #E3, #E3, #E3
            db #E3, #E3, #E3, #E3, #20, #20, #20, #20, #B4, #B4, #B4, #B4, #E3, #E3, #E3, #E3
            db #E3, #E3, #E3, #E3, #E3, #E3, #E3, #20, #20, #E3, #E3, #E3, #E3, #E3, #E3, #E3
#endasm
End Function
