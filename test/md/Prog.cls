' Prog - a Z80 program for test/md/Classes.bas: ld a, $55 / ld ($1000), a / jr $
Option Explicit

Public Function Where() As Long
#asm
            movea.l (sp)+, a0
            move.l #zt_prog, (a0)
            bra zt_end
zt_prog:
            dc.b $3E, $55, $32, $00, $10, $18, $FE, $00
zt_end:
#endasm
End Function
