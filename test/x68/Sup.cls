' Sup - the platform's supervisor call tried: test/x68/Classes.bas
Option Explicit

' Mode(): the status register's supervisor bit ($2000) as the called routine sees it
Public Function Mode() As Integer
#asm
            lea su_read, a0
            trap #1
            movea.l (sp)+, a0
            move.w d1, (a0)
            bra su_end
su_read:
            move.w sr, d1
            andi.w #$2000, d1
            rts
su_end:
#endasm
End Function
