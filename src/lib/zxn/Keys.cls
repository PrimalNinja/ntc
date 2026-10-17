' Keys - the keyboard as keys held down, and the joysticks. NTC platform class: ZX Spectrum Next
'
' Inkey / Inkey$ give characters typed; Keys tells whether a key is held down right now - for
' games: several at once, held keys, no auto repeat. Key numbers: half row * 8 + bit, for the
' Spectrum's 8 x 5 keyboard (ports #FEFE ... #7FFE, bits 0-4) - the constants below name them.
' The Next's own keys (cursor keys, Delete, Break ...) press Caps Shift with a key: the cursor
' keys are Caps + 5 6 7 8, so KeyLeft ... are 5, 6, 7, 8 (as the Spectrum's cursor joystick).
' Read from the hardware at every call (turbo and normal mode).
'   If Keys.Down(Keys.KeyLeft) Then x = x - 1
'   j = Keys.Joystick(0) : If j And Keys.JoyFire1 Then ...

' ---- key numbers (half row * 8 + bit)
Public Const KeyCaps = 0          ' Caps Shift
Public Const KeyZ = 1
Public Const KeyX = 2
Public Const KeyC = 3
Public Const KeyV = 4
Public Const KeyA = 8
Public Const KeyS = 9
Public Const KeyD = 10
Public Const KeyF = 11
Public Const KeyG = 12
Public Const KeyQ = 16
Public Const KeyW = 17
Public Const KeyE = 18
Public Const KeyR = 19
Public Const KeyT = 20
Public Const Key1 = 24
Public Const Key2 = 25
Public Const Key3 = 26
Public Const Key4 = 27
Public Const Key5 = 28
Public Const Key0 = 32
Public Const Key9 = 33
Public Const Key8 = 34
Public Const Key7 = 35
Public Const Key6 = 36
Public Const KeyP = 40
Public Const KeyO = 41
Public Const KeyI = 42
Public Const KeyU = 43
Public Const KeyY = 44
Public Const KeyEnter = 48
Public Const KeyL = 49
Public Const KeyK = 50
Public Const KeyJ = 51
Public Const KeyH = 52
Public Const KeySpace = 56
Public Const KeySymbol = 57       ' Symbol Shift
Public Const KeyM = 58
Public Const KeyN = 59
Public Const KeyB = 60
' the CPC names, for programs that use them
Public Const KeyLeft = 28         ' 5 (the cursor key: Caps + 5)
Public Const KeyDown = 36         ' 6
Public Const KeyUp = 35           ' 7
Public Const KeyRight = 34        ' 8
Public Const KeyReturn = 48       ' Enter
Public Const KeyShift = 0         ' Caps Shift
Public Const KeyControl = 57      ' Symbol Shift
Public Const KeyCopy = 57         ' (no Copy: Symbol Shift)
Public Const KeyEsc = 56          ' Space (Break is Caps + Space)
Public Const KeyDel = 32          ' 0 (Delete is Caps + 0)
Public Const KeyTab = 0           ' (no Tab: Caps Shift)

' ---- Joystick bits
Public Const JoyUp = 1
Public Const JoyDown = 2
Public Const JoyLeft = 4
Public Const JoyRight = 8
Public Const JoyFire2 = 16
Public Const JoyFire1 = 32

' Down(key): True (-1) while that key is held down, else False (0; also for a number not 0-63
' or a bit 5-7)
Public Function Down(ByVal key As Integer) As Integer
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld a, d
            or a
            jr nz, kdno
            ld a, e
            cp 64
            jr nc, kdno
            and 7
            cp 5
            jr nc, kdno
            inc a
            ld d, a                 ; D = bit + 1
            ld a, e
            rrca
            rrca
            rrca
            and 7
            inc a                   ; A = half row + 1
            ld b, a
            ld a, #7F
kdrow:
            rlca                    ; #FE for half row 0, #FD 1 ... #7F 7
            djnz kdrow
            ld b, a
            ld c, #FE
            in a, (c)
            ld b, d
kdbit:
            rrca
            djnz kdbit
            ld de, 0
            jr c, kdset               ; 1 = not pressed
            dec de
            jr kdset
kdno:
            ld de, 0
kdset:
            pop hl
            ld (hl), e
            inc hl
            ld (hl), d
#endasm
End Function

' Joystick(n): joystick 0 (Kempston 1, port #1F) or 1 (Kempston 2, port #37) - JoyUp + JoyDown +
' JoyLeft + JoyRight + JoyFire2 + JoyFire1, the ones held (0 = none). The Next's joystick ports
' set to Kempston (its menu, or NextReg 5)
Public Function Joystick(ByVal n As Integer) As Integer
#asm
            pop hl
            ld a, (hl)
            and 1
            ld bc, #001F
            jr z, kjport
            ld c, #37
kjport:
            in a, (c)               ; Kempston: bit 0 right, 1 left, 2 down, 3 up, 4 fire 1, 5 fire 2
            ld c, a
            ld e, 0
            rrca
            jr nc, kjnr
            set 3, e                ; right
kjnr:
            rrca
            jr nc, kjnl
            set 2, e                ; left
kjnl:
            rrca
            jr nc, kjnd
            set 1, e                ; down
kjnd:
            rrca
            jr nc, kjnu
            set 0, e                ; up
kjnu:
            rrca
            jr nc, kjn1
            set 5, e                ; fire 1
kjn1:
            rrca
            jr nc, kjn2
            set 4, e                ; fire 2
kjn2:
            ld d, 0
            pop hl
            ld (hl), e
            inc hl
            ld (hl), d
#endasm
End Function
