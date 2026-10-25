' Keys - the keyboard as keys held down, and the joypads. NTC platform class: Sega SC-3000
'
' Inkey / Inkey$ give characters typed; Keys tells whether a key is held down right now - for
' games: several at once, held keys, no auto repeat. A key number is the keyboard matrix's:
' row * 16 + bit, port A's bits 0-7, port B's 8-11 (rows 0-6; the PPI's port C picks the
' row). The matrix is read at every call (turbo and normal mode).
'   If Keys.Down(Keys.KeyLeft) Then x = x - 1
'   j = Keys.Joystick(0) : If j And Keys.JoyFire1 Then ...

' ---- key numbers
Public Const KeyUp = 102
Public Const KeyRight = 101
Public Const KeyDown = 69
Public Const KeyLeft = 85
Public Const KeyReturn = 86
Public Const KeyShift = 107
Public Const KeyControl = 106
Public Const KeyGraph = 105
Public Const KeyFunc = 91
Public Const KeyBreak = 104
Public Const KeySpace = 20
Public Const KeyDel = 52
Public Const KeyHome = 36
Public Const KeyEng = 4
Public Const KeyA = 2
Public Const KeyD = 34
Public Const KeyQ = 1
Public Const KeyS = 18
Public Const KeyW = 17
Public Const KeyX = 19
Public Const KeyZ = 3

' ---- Joystick bits
Public Const JoyUp = 1
Public Const JoyDown = 2
Public Const JoyLeft = 4
Public Const JoyRight = 8
Public Const JoyFire2 = 16
Public Const JoyFire1 = 32

' Down(key): True (-1) while that key is held down, else False (0; also for a number not 0-111)
Public Function Down(ByVal key As Integer) As Integer
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld a, (hl)
            ld hl, 0
            or a
            jr nz, done
            ld a, e
            cp 112
            jr nc, done
            and 7
            ld b, a
            inc b
            ld a, e
            rrca
            rrca
            rrca
            rrca
            and 7
            out (#DE), a        ; PPI port C: the row
            bit 3, e
            jr nz, pb
            in a, (#DC)         ; port A: bits 0-7
            jr rot
pb:
            in a, (#DD)         ; port B: bits 8-11
rot:
            rrca
            djnz rot
            jr c, done
            dec hl
done:
            ex de, hl
            pop hl
            ld (hl), e
            inc hl
            ld (hl), d
#endasm
End Function

' Joystick(n): joypad 1 (n = 0) or 2 (n = 1) - JoyUp + JoyDown + JoyLeft + JoyRight + JoyFire2
' (button 2) + JoyFire1 (button 1), the ones held (0 = none). Row 7 of the matrix
Public Function Joystick(ByVal n As Integer) As Integer
#asm
            pop hl
            ld c, (hl)
            ld a, 7
            out (#DE), a
            in a, (#DC)
            cpl
            ld e, a             ; pad 1: bits 0-5, pad 2's up / down: bits 6-7
            in a, (#DD)
            cpl
            ld d, a             ; pad 2's left, right, 1, 2: bits 0-3
            bit 0, c
            jr z, pad
            ld a, e
            rlca
            rlca
            and 3               ; up, down
            ld e, a
            ld a, d
            add a, a
            add a, a
            and #3C             ; left, right, 1, 2
            or e
            ld e, a
pad:
            ld a, e
            and #0F
            bit 4, e
            jr z, b2
            or 32
b2:
            bit 5, e
            jr z, got
            or 16
got:
            ld e, a
            ld d, 0
            pop hl
            ld (hl), e
            inc hl
            ld (hl), d
#endasm
End Function
