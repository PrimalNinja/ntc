' Pad - the Neo Geo's pads (the joystick, A B C D, Start and Select). NTC platform class: SNK Neo
' Geo (68000, cartridge: AES / MVS). (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' The VBlank interrupt reads both pads every frame. Pad.Read(1) / Pad.Read(2): the buttons held
' now, one bit each (And them with the constants). (On an MVS, Start is the player's start button
' and SelectKey isn't there.)

Public Const Up = 1
Public Const Down = 2
Public Const Left = 4
Public Const Right = 8
Public Const A = 16
Public Const B = 32
Public Const C = 64
Public Const D = 128
Public Const Start = 256
Public Const SelectKey = 512

' the buttons held on pad n (1 or 2; 0 is 1 too)
Public Function Read(ByVal n As Integer) As Integer
#asm
            movea.l (sp)+, a0
            move.w (a0), d0
            movea.l (sp)+, a1
            cmpi.w #2, d0
            beq pd_two
            move.w ntc_pad1, (a1)
            bra pd_done
pd_two:
            move.w ntc_pad2, (a1)
pd_done:
#endasm
End Function
