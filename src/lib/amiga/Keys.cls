' Keys - the keyboard as keys held down, and the joysticks. NTC platform class: Commodore Amiga 500
'
' Inkey / Inkey$ give characters typed; Keys tells whether a key is held down right now - for
' games: several at once, held keys, no auto repeat. The keyboard sends each key going down and
' up (CIA-A, interrupt level 2); NTC keeps a byte for each. Key numbers are the Amiga keyboard's
' own (0-103) - the constants below name them, with the same names as on NTC's other machines.
'   If Keys.Down(Keys.KeyLeft) Then x = x - 1
'   j = Keys.Joystick(0) : If j And Keys.JoyFire1 Then ...
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Option Explicit

' ---- key numbers
Public Const KeyEsc = 69
Public Const Key1 = 1
Public Const Key2 = 2
Public Const Key3 = 3
Public Const Key4 = 4
Public Const Key5 = 5
Public Const Key6 = 6
Public Const Key7 = 7
Public Const Key8 = 8
Public Const Key9 = 9
Public Const Key0 = 10
Public Const KeyDel = 70
Public Const KeyBackspace = 65
Public Const KeyTab = 66
Public Const KeyQ = 16
Public Const KeyW = 17
Public Const KeyE = 18
Public Const KeyR = 19
Public Const KeyT = 20
Public Const KeyY = 21
Public Const KeyU = 22
Public Const KeyI = 23
Public Const KeyO = 24
Public Const KeyP = 25
Public Const KeyEnter = 68        ' Return
Public Const KeyReturn = 68
Public Const KeyA = 32
Public Const KeyS = 33
Public Const KeyD = 34
Public Const KeyF = 35
Public Const KeyG = 36
Public Const KeyH = 37
Public Const KeyJ = 38
Public Const KeyK = 39
Public Const KeyL = 40
Public Const KeyZ = 49
Public Const KeyX = 50
Public Const KeyC = 51
Public Const KeyV = 52
Public Const KeyB = 53
Public Const KeyN = 54
Public Const KeyM = 55
Public Const KeySpace = 64
Public Const KeyLeft = 79
Public Const KeyUp = 76
Public Const KeyRight = 78
Public Const KeyDown = 77
Public Const KeyShift = 96        ' the left Shift (the right: 97)
Public Const KeyControl = 99
Public Const KeyCaps = 96         ' the left Shift (the CPC's and the Spectrum's Caps Shift)
Public Const KeySymbol = 99       ' Ctrl
Public Const KeyCopy = 100        ' the left Alt
Public Const KeyAlt = 100         ' the left Alt (the right: 101)
Public Const KeyAmiga = 102       ' the left Amiga key (the right: 103)
Public Const KeyHelp = 95
Public Const KeyF1 = 80
Public Const KeyF2 = 81
Public Const KeyF3 = 82
Public Const KeyF4 = 83
Public Const KeyF5 = 84
Public Const KeyF6 = 85
Public Const KeyF7 = 86
Public Const KeyF8 = 87
Public Const KeyF9 = 88
Public Const KeyF10 = 89

' ---- Joystick() bits (the same as NTC's other machines)
Public Const JoyUp = 1
Public Const JoyDown = 2
Public Const JoyLeft = 4
Public Const JoyRight = 8
Public Const JoyFire2 = 16        ' the second button (a two button stick or a pad)
Public Const JoyFire1 = 32        ' the fire button

' Down(key): True while the key is held
Public Function Down(ByVal key As Integer) As Integer
#asm
            movea.l (sp)+, a0
            move.w (a0), d1
            andi.w #127, d1
            lea ntc_ami_held, a1
            tst.b 0(a1, d1.w)
            sne d0
            ext.w d0
            movea.l (sp)+, a0
            move.w d0, (a0)
#endasm
End Function

' Joystick(n): the Joy bits held. 0: the stick in the Amiga's port 2 (where a game's joystick
' goes); 1: the one in port 1 (the mouse's port)
Public Function Joystick(ByVal n As Integer) As Integer
#asm
            movea.l (sp)+, a0
            move.w (a0), d3
            move.w $DFF00C, d0          ; JOY1DAT: port 2
            moveq #7, d4                ; its fire button: CIA-A port A bit 7
            moveq #14, d5               ; its second button: POTGOR bit 14
            andi.w #1, d3
            beq kj_port
            move.w $DFF00A, d0          ; JOY0DAT: port 1
            moveq #6, d4
            moveq #10, d5
kj_port:
            move.w d0, d1
            lsr.w #1, d1
            eor.w d0, d1                ; bit 8: up, bit 0: down
            moveq #0, d2
            btst #8, d1
            beq kj_nu
            ori.w #1, d2
kj_nu:
            btst #0, d1
            beq kj_nd
            ori.w #2, d2
kj_nd:
            btst #9, d0
            beq kj_nl
            ori.w #4, d2
kj_nl:
            btst #1, d0
            beq kj_nr
            ori.w #8, d2
kj_nr:
            btst d4, $BFE001
            bne kj_nf
            ori.w #32, d2
kj_nf:
            move.w $DFF016, d0          ; POTGOR
            btst d5, d0
            bne kj_n2
            ori.w #16, d2
kj_n2:
            movea.l (sp)+, a0
            move.w d2, (a0)
#endasm
End Function
