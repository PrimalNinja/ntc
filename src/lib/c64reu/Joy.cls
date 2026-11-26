' Joy - the C64's joystick ports. NTC platform class: Commodore 64 with an REU (6502)
'
' Joy.Read(2) / Joy.Read(1): the directions and fire held now, one bit each (And them with the
' constants). Port 2 is the usual game port. (Port 1 shares its lines with the keyboard: keys
' held show up on it.)

Public Const Up = 1
Public Const Down = 2
Public Const Left = 4
Public Const Right = 8
Public Const Fire = 16

' the bits held on port n (1 or 2)
Public Function Read(ByVal n As Integer) As Integer
#asm
            NTC_POP z_p0
            NTC_POP z_p1
            ldy #0
            lda (z_p0),y
            cmp #1
            beq one
            lda #$FF            ; port A's lines high: the joystick pulls them down
            sta $DC00
            lda $DC00
            jmp got
one:
            lda $DC01
got:
            eor #$FF
            and #$1F
            sta (z_p1),y
            iny
            lda #0
            sta (z_p1),y
#endasm
End Function
