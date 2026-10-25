' Pad - the Mega Drive's pads (3 and 6 button). NTC platform class: Sega Mega Drive / Genesis
'
' The frame interrupt reads both pads every frame. Pad.Read(1) / Pad.Read(2): the buttons held
' now, one bit each (And them with the constants). A 3 button pad has no X, Y, Z or Mode.

Public Const Up = 1
Public Const Down = 2
Public Const Left = 4
Public Const Right = 8
Public Const B = 16
Public Const C = 32
Public Const A = 64
Public Const Start = 128
Public Const X = 256
Public Const Y = 512
Public Const Z = 1024
Public Const Mode = 2048

' the buttons held on pad n (1 or 2)
Public Function Read(ByVal n As Integer) As Integer
#asm
            movea.l (sp)+, a0
            move.w (a0), d0
            movea.l (sp)+, a1
            cmpi.w #2, d0
            beq two
            move.w ntc_pad1, (a1)
            bra done
two:
            move.w ntc_pad2, (a1)
done:
#endasm
End Function
