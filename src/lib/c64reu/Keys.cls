' Keys - keys held down now. NTC platform class: Commodore 64 with an REU (6502)
'
' Keys.Down(key): True (-1) while that key is held - for games, where Inkey's "a key was
' pressed" is not enough. Any number of keys at once (the C64's keyboard can show keys that are
' not down when three or more are held in some patterns, as on any C64).
' The key numbers are the keyboard matrix's: column * 8 + row.
' A joystick in port 2 pulls on the same lines: while it is held, some keys read as down.

Public Const KeyQ = 62
Public Const KeyA = 10
Public Const KeyO = 38
Public Const KeyP = 41
Public Const KeySpace = 60
Public Const KeyZ = 12
Public Const KeyW = 9
Public Const KeyS = 13
Public Const KeyX = 23
Public Const KeyEnter = 1
Public Const KeyStop = 63
Public Const KeyShift = 15
Public Const KeyControl = 58
Public Const KeyCommodore = 61
Public Const KeyDel = 0
Public Const KeyDown = 7            ' the cursor down / up key
Public Const KeyRight = 2           ' the cursor right / left key
Public Const KeyF1 = 4
Public Const KeyF3 = 5
Public Const KeyF5 = 6
Public Const KeyF7 = 3

' Down(key): True while the key is held
Public Function Down(ByVal key As Integer) As Integer
#asm
            NTC_POP z_p0
            NTC_POP z_p1
            ldy #0
            lda (z_p0),y
            and #63
            sta z_t0
            lsr
            lsr
            lsr
            tax
            lda ntc_c64_bit,x
            eor #$FF
            sta $DC00               ; the key's column
            lda z_t0
            and #7
            tax
settle:
            lda $DC01
            cmp $DC01
            bne settle
            and ntc_c64_bit,x
            beq held
            lda #0
            beq put
held:
            lda #$FF
put:
            ldy #0
            sta (z_p1),y
            iny
            sta (z_p1),y
            lda #$FF
            sta $DC00
#endasm
End Function
