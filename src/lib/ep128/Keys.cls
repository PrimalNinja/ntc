' Keys - the keyboard as keys held down, and the joysticks. NTC platform class: Enterprise 128
'
' Inkey / Inkey$ give characters typed; Keys tells whether a key is held down right now - for
' games: several at once, held keys, no auto repeat. Key numbers are the keyboard matrix's:
' row * 8 + bit (rows 0-9, read through port &HB5); the constants below name the usual ones.
' The matrix is read from the hardware at every call (turbo and normal mode).
'   If Keys.Down(Keys.KeyLeft) Then x = x - 1
'   j = Keys.Joystick(0) : If j And Keys.JoyFire1 Then ...

' ---- key numbers
Public Const KeyUp = 59
Public Const KeyRight = 58
Public Const KeyDown = 57
Public Const KeyLeft = 61
Public Const KeyEnter = 62
Public Const KeyReturn = 62
Public Const KeyShift = 7         ' the left one (the right one: 69)
Public Const KeyControl = 15
Public Const KeyAlt = 63
Public Const KeySpace = 70
Public Const KeyEsc = 31
Public Const KeyTab = 23
Public Const KeyCaps = 9          ' LOCK
Public Const KeyDel = 46          ' ERASE (DEL: 65, INS: 71)
Public Const KeyStop = 56
Public Const KeyHold = 60
Public Const KeyF1 = 39
Public Const KeyF2 = 38
Public Const KeyF3 = 34
Public Const KeyF4 = 32
Public Const KeyF5 = 36
Public Const KeyF6 = 35
Public Const KeyF7 = 37
Public Const KeyF8 = 33
Public Const KeyA = 14
Public Const KeyD = 11
Public Const KeyO = 74
Public Const KeyP = 76
Public Const KeyQ = 17
Public Const KeyS = 13
Public Const KeyW = 22
Public Const KeyX = 5
Public Const KeyZ = 6

' ---- Joystick bits
Public Const JoyUp = 1
Public Const JoyDown = 2
Public Const JoyLeft = 4
Public Const JoyRight = 8
Public Const JoyFire2 = 16        ' (never set here: one fire button)
Public Const JoyFire1 = 32

' Down(key): True (-1) while that key is held down, else False (0; also for a number not 0-79)
Public Function Down(ByVal key As Integer) As Integer
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ex de, hl
            jp ep_kdown
#endasm
End Function

' Joystick(n): JoyUp + JoyDown + JoyLeft + JoyRight + JoyFire1, the ones held (0 = none).
' 0 = the built in joystick (it is the cursor keys; fire = Space), 1 / 2 = the control ports'
Public Function Joystick(ByVal n As Integer) As Integer
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ex de, hl
            jp ep_kjoy
#endasm
End Function
