' Opm - the X68000's FM sound chip (YM2151), its registers written through the ROM's call (IOCS
' _OPMSET), which works from user mode. NTC platform class: Sharp X68000
'   Opm.Reg r, v     register r = v (0-255 each)
'   Opm.Quiet        every channel's key off
' A note: the channel's operators set up once (registers $20 on), then its pitch (KC $28 + ch, KF
' $30 + ch) and key on ($08: the operators' bits << 3, the channel).
Option Explicit

Public Sub Reg(ByVal r As Integer, ByVal v As Integer)
#asm
            movea.l (sp)+, a0
            move.w (a0), d1
            movea.l (sp)+, a0
            move.w (a0), d2
            andi.l #255, d1
            andi.l #255, d2
            moveq #$68, d0              ; IOCS _OPMSET
            trap #15
#endasm
End Sub

Public Sub Quiet()
    Dim intC As Integer
    For intC = 0 To 7
        Reg 8, intC
    Next intC
End Sub
