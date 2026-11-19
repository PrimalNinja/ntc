' Z80 - the Mega Drive's second processor (a Z80 with 8K of RAM, the sound chips on its bus).
' NTC platform class: Sega Mega Drive / Genesis (68000)
'
' NTC's start leaves the Z80 held in reset. A program gives it a program of its own (a sound
' driver) and talks to it through its RAM, taking the Z80's bus for each read or write.
'   Z80.Load addr, n     n bytes from addr (a Long) to the Z80's RAM from 0, then it starts at 0
'   Z80.Poke a, v        the Z80's RAM (0-$1FFF): a byte written / read (the Z80 waits meanwhile)
'   v = Z80.Peek(a)
'   Z80.Stop             held in reset again
Option Explicit

Public Sub Load(ByVal addr As Long, ByVal n As Integer)
#asm
            movea.l (sp)+, a0
            movea.l (a0), a2
            movea.l (sp)+, a0
            move.w (a0), d0
            move.w #$0100, $A11100      ; the Z80's bus ...
            move.w #$0100, $A11200      ; ... out of reset, so its RAM can be written
zl_bus:
            btst #0, $A11100
            bne zl_bus
            lea $A00000, a1
            subq.w #1, d0
            bmi zl_run
zl_lp:
            move.b (a2)+, (a1)+
            dbra d0, zl_lp
zl_run:
            move.w #$0000, $A11200      ; a reset (it starts at 0) ...
            moveq #31, d0
zl_rst:
            dbra d0, zl_rst
            move.w #$0000, $A11100      ; its bus back
            move.w #$0100, $A11200      ; ... and it runs
#endasm
End Sub

Public Sub Poke(ByVal a As Integer, ByVal v As Integer)
#asm
            movea.l (sp)+, a0
            move.w (a0), d0
            movea.l (sp)+, a0
            move.w (a0), d1
            andi.l #$1FFF, d0
            lea $A00000, a1
            adda.l d0, a1
            move.w #$0100, $A11100
zp_bus:
            btst #0, $A11100
            bne zp_bus
            move.b d1, (a1)
            move.w #$0000, $A11100
#endasm
End Sub

Public Function Peek(ByVal a As Integer) As Integer
#asm
            movea.l (sp)+, a0
            move.w (a0), d0
            andi.l #$1FFF, d0
            lea $A00000, a1
            adda.l d0, a1
            move.w #$0100, $A11100
zk_bus:
            btst #0, $A11100
            bne zk_bus
            moveq #0, d1
            move.b (a1), d1
            move.w #$0000, $A11100
            movea.l (sp)+, a0
            move.w d1, (a0)
#endasm
End Function

Public Sub Stop()
#asm
            move.w #$0000, $A11200
#endasm
End Sub
