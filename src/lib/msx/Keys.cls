' Keys - the keyboard as keys held down, and the joysticks. NTC platform class: MSX
'
' Inkey / Inkey$ give characters typed; Keys tells whether a key is held down right now - for
' games: several at once, held keys, no auto repeat. A key number is the MSX keyboard matrix's:
' row * 8 + bit (rows 0-10, as the BIOS's SNSMAT and NEWKEY). Rows 6-8 (Shift, Ctrl, the
' function keys, Esc, Tab, Return, Space, the cursor keys) are the same on every MSX; the
' letters below are the international layout's (a Japanese or AZERTY keyboard differs).
' The matrix is read from the PPI at every call (turbo and normal mode).
'   If Keys.Down(Keys.KeyLeft) Then x = x - 1
'   j = Keys.Joystick(0) : If j And Keys.JoyFire1 Then ...

' ---- key numbers
Public Const KeyUp = 69
Public Const KeyRight = 71
Public Const KeyDown = 70
Public Const KeyLeft = 68
Public Const KeyReturn = 63
Public Const KeyShift = 48
Public Const KeyControl = 49
Public Const KeyGraph = 50
Public Const KeyCaps = 51
Public Const KeyCode = 52
Public Const KeySpace = 64
Public Const KeyEsc = 58
Public Const KeyTab = 59
Public Const KeyStop = 60
Public Const KeyBS = 61
Public Const KeySelect = 62
Public Const KeyHome = 65
Public Const KeyIns = 66
Public Const KeyDel = 67
Public Const KeyF1 = 53
Public Const KeyA = 22
Public Const KeyD = 25
Public Const KeyQ = 38
Public Const KeyS = 40
Public Const KeyW = 44
Public Const KeyX = 45
Public Const KeyZ = 47

' ---- Joystick bits
Public Const JoyUp = 1
Public Const JoyDown = 2
Public Const JoyLeft = 4
Public Const JoyRight = 8
Public Const JoyFire2 = 16
Public Const JoyFire1 = 32

' Down(key): True (-1) while that key is held down, else False (0; also for a number not 0-87)
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
            cp 88
            jr nc, done
            and 7
            ld b, a
            inc b
            ld a, e
            rrca
            rrca
            rrca
            and 31
            ld c, a
            in a, (#AA)         ; PPI port C: bits 0-3 the row
            and #F0
            or c
            out (#AA), a
            in a, (#A9)         ; the row: 0 = down
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

' Joystick(n): joystick port 1 (n = 0) or 2 (n = 1) - JoyUp + JoyDown + JoyLeft + JoyRight +
' JoyFire2 (trigger B) + JoyFire1 (trigger A), the ones held (0 = none). Read from the PSG
Public Function Joystick(ByVal n As Integer) As Integer
#asm
            pop hl
            ld c, (hl)
            ld a, 15            ; PSG register 15 bit 6: the port
            out (#A0), a
            in a, (#A2)
            and #BF
            bit 0, c
            jr z, port
            or #40
port:
            out (#A1), a
            ld a, 14            ; register 14: the port's pins (0 = on)
            out (#A0), a
            in a, (#A2)
            cpl
            ld c, a
            and #0F
            ld e, a
            bit 4, c
            jr z, trb
            set 5, e
trb:
            bit 5, c
            jr z, got
            set 4, e
got:
            ld d, 0
            pop hl
            ld (hl), e
            inc hl
            ld (hl), d
#endasm
End Function
