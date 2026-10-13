' Keys - the keyboard as keys held down, and the joysticks. NTC platform class: Amstrad CPC (firmware)
'
' Inkey / Inkey$ give characters typed; Keys tells whether a key is held down right now - for
' games: several at once, held keys, no auto repeat. Key numbers are the CPC's own (the same
' as Locomotive BASIC's INKEY(n) and the firmware's: the manual's key number chart): the
' constants below name the usual ones. The keyboard matrix is read from the hardware at every
' call (works with and without the firmware, turbo and normal mode).
'   If Keys.Down(Keys.KeyLeft) Then x = x - 1
'   j = Keys.Joystick(0) : If j And Keys.JoyFire1 Then ...

' ---- key numbers
Public Const KeyUp = 0
Public Const KeyRight = 1
Public Const KeyDown = 2
Public Const KeyLeft = 8
Public Const KeyCopy = 9
Public Const KeyEnter = 6         ' the small Enter on the number pad
Public Const KeyReturn = 18
Public Const KeyShift = 21
Public Const KeyControl = 23
Public Const KeySpace = 47
Public Const KeyEsc = 66
Public Const KeyTab = 68
Public Const KeyCaps = 70
Public Const KeyDel = 79
Public Const KeyA = 69
Public Const KeyD = 61
Public Const KeyQ = 67
Public Const KeyS = 60
Public Const KeyW = 59
Public Const KeyX = 63
Public Const KeyZ = 71

' ---- Joystick bits
Public Const JoyUp = 1
Public Const JoyDown = 2
Public Const JoyLeft = 4
Public Const JoyRight = 8
Public Const JoyFire2 = 16
Public Const JoyFire1 = 32

' Down(key): True (-1) while that key is held down, else False (0; also for a number not 0-79)
Public Function Down(ByVal key As Integer) As Integer
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ex de, hl
            jp ntc_kdown
#endasm
End Function

' Joystick(n): joystick 0 or 1 - JoyUp + JoyDown + JoyLeft + JoyRight + JoyFire2 + JoyFire1,
' the ones held (0 = none). Joystick 1 shares its keys with 6, 5, R, T, G, F (key numbers
' 48-53), as on any CPC
Public Function Joystick(ByVal n As Integer) As Integer
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ex de, hl
            jp ntc_kjoy
#endasm
End Function
