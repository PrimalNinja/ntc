' Reu - the REU as the program's own memory. NTC platform class: Commodore 64 with an REU (6502)
'
' The REU is banks of 64K: a place in it is a bank (0-255) and an address in the bank (0-65535,
' written &H0000-&HFFFF). A 1750 has 8 banks (512K), a 1764 4, a 1700 2; an Ultimate or an
' emulator can have 256 (16 MB).
'
' Bank 0 is NTC's: the program's thread runs from it. Banks 1 on are the program's, for
' anything: screens, sprite shapes, music, levels, tables too big for the C64's memory. The REU
' moves a byte in one cycle - about fifteen times what a 6502 loop does - so a whole text
' screen comes or goes in a twentieth of a frame.
'
' A transfer stops the 6502 until it is done (the frame's interrupt waits too): 1,000 bytes are
' a sixteenth of a frame, 8,000 under half.

' Banks(): how many 64K banks the REU has. Nothing in the REU is changed by asking (a byte in
' each bank is tried and put back). Uses $0400-$04FF while it works.
Public Function Banks() As Integer
#asm
            NTC_POP z_p2
            NTC_RS
            lda #$7F
            sta $52
            lda #$FF
            sta $53
            lda #0
            sta $57
            sta $51
            ldx #0                  ; what is there now, bank by bank -> $0400-$04FF
keep:
            stx $54
            stx $50
            lda #$04
            sta $51
            lda #1
            sta $55
            lda #0
            sta $56
            lda #$91
            jsr ntc_reu_do
            ldx $54
            inx
            bne keep
            lda #<ntc_reu_byte      ; each bank's own number, from 255 down to 0
            sta $50
            lda #>ntc_reu_byte
            sta $51
            ldx #255
wr:
            stx ntc_reu_byte
            stx $54
            lda #1
            sta $55
            lda #0
            sta $56
            lda #$90
            jsr ntc_reu_do
            ldx $54
            dex
            cpx #255
            bne wr
            ldx #0                  ; read back up: the first that is not its own number ends it
rd:
            stx $54
            lda #1
            sta $55
            lda #0
            sta $56
            lda #$91
            jsr ntc_reu_do
            ldx $54
            cpx ntc_reu_byte
            bne got
            inx
            bne rd
            lda #0                  ; all 256
            sta z_t0
            lda #1
            sta z_t1
            bne back
got:
            stx z_t0
            lda #0
            sta z_t1
back:
            ldx #0                  ; what was there, back
put:
            stx $54
            stx $50
            lda #$04
            sta $51
            lda #1
            sta $55
            lda #0
            sta $56
            lda #$90
            jsr ntc_reu_do
            ldx $54
            inx
            bne put
            NTC_TS
            ldy #0
            lda z_t0
            sta (z_p2),y
            iny
            lda z_t1
            sta (z_p2),y
#endasm
End Function

' LotBank(n), LotAddr(n): where lot n (1 on) starts in the REU - its bank and its address in
' the bank. (Option Lot: the REU past the kernel's 32K is lots of 96K; the ones not named by
' an Option Lot line are the program's for data.) A lot is a bank and a half: its 96K run on
' from there through the next bank or two.
Public Function LotBank(ByVal n As Integer) As Integer
    LotBank = (1 + (n - 1) * 3) \ 2
End Function

Public Function LotAddr(ByVal n As Integer) As Integer
    If (n And 1) = 1 Then
        LotAddr = &H8000
    Else
        LotAddr = 0
    End If
End Function

' Size(): the REU's size in K (Banks() * 64). 16 MB gives 16384
Public Function Size() As Integer
    Size = Banks() * 64
End Function

' Stash: bytes of the C64's memory at mem into the REU at bank : addr
Public Sub Stash(ByVal bank As Integer, ByVal addr As Integer, ByVal mem As Integer, ByVal bytes As Integer)
#asm
            lda #$90
            jmp ntc_reu_m4
#endasm
End Sub

' Fetch: bytes of the REU at bank : addr into the C64's memory at mem
Public Sub Fetch(ByVal bank As Integer, ByVal addr As Integer, ByVal mem As Integer, ByVal bytes As Integer)
#asm
            lda #$91
            jmp ntc_reu_m4
#endasm
End Sub

' FetchRect: a block of rows out of the REU - a piece of a map onto the screen, a picture, a
' sheet of shapes. rows (1-255) transfers of width bytes: the first from bank : addr to mem, and
' after each one addr goes on by pitch and mem by mempitch.
'     Reu.FetchRect 1, y * 256 + x, 256, &HE000, 40, 40, 24      ' 40 x 24 of a 256 wide map
Public Sub FetchRect(ByVal bank As Integer, ByVal addr As Integer, ByVal pitch As Integer, ByVal mem As Integer, ByVal mempitch As Integer, ByVal width As Integer, ByVal rows As Integer)
#asm
            lda #$91
            jmp ntc_reu_rect
#endasm
End Sub

' StashRect: the same, into the REU
Public Sub StashRect(ByVal bank As Integer, ByVal addr As Integer, ByVal pitch As Integer, ByVal mem As Integer, ByVal mempitch As Integer, ByVal width As Integer, ByVal rows As Integer)
#asm
            lda #$90
            jmp ntc_reu_rect
#endasm
End Sub

' Swap: the two exchanged (two cycles a byte)
Public Sub Swap(ByVal bank As Integer, ByVal addr As Integer, ByVal mem As Integer, ByVal bytes As Integer)
#asm
            lda #$92
            jmp ntc_reu_m4
#endasm
End Sub

' Fill: bytes of the REU at bank : addr set to value
Public Sub Fill(ByVal bank As Integer, ByVal addr As Integer, ByVal value As Integer, ByVal bytes As Integer)
#asm
            NTC_POP z_p1
            NTC_POP z_p2
            NTC_POP z_p0
            ldy #0
            lda (z_p0),y
            sta ntc_reu_byte
            lda (z_p1),y
            sta $54
            lda (z_p2),y
            sta $52
            iny
            lda (z_p2),y
            sta $53
            lda #<ntc_reu_byte
            sta $50
            lda #>ntc_reu_byte
            sta $51
            lda #$80                ; the C64 address stays: the one byte, over and over
            sta $57
            lda #$90
            sta $58
            jmp ntc_reu_len
#endasm
End Sub

' MemFill: bytes of the C64's memory at mem set to value, by the REU (a cycle a byte: a screen
' cleared in a twentieth of a frame). Uses one byte of the REU, in NTC's own notes
Public Sub MemFill(ByVal mem As Integer, ByVal value As Integer, ByVal bytes As Integer)
#asm
            NTC_POP z_p1
            NTC_POP z_p0
            ldy #0
            lda (z_p0),y
            sta ntc_reu_byte
            lda (z_p1),y
            sta z_a
            iny
            lda (z_p1),y
            sta z_a+1
            NTC_POP z_p0
            ldy #0
            lda (z_p0),y
            sta z_b
            iny
            lda (z_p0),y
            sta z_b+1
            ora z_b
            beq none
            NTC_RS
            lda #<ntc_reu_byte      ; the byte into the REU
            sta $50
            lda #>ntc_reu_byte
            sta $51
            lda #$E0
            sta $52
            lda #NTC_NOTEH
            sta $53
            lda #0
            sta $54
            sta $56
            sta $57
            lda #1
            sta $55
            lda #$90
            jsr ntc_reu_do
            lda z_a                 ; and out again, the REU address staying
            sta $50
            lda z_a+1
            sta $51
            lda z_b
            sta $55
            lda z_b+1
            sta $56
            lda #$40
            sta $57
            lda #$91
            jsr ntc_reu_do
            NTC_TS
none:
#endasm
End Sub

' Peek: the byte at bank : addr
Public Function Peek(ByVal bank As Integer, ByVal addr As Integer) As Integer
#asm
            NTC_POP z_p1
            NTC_POP z_p2
            NTC_POP z_p3
            ldy #0
            lda (z_p1),y
            sta $54
            lda (z_p2),y
            sta $52
            iny
            lda (z_p2),y
            sta $53
            lda #<ntc_reu_byte
            sta $50
            lda #>ntc_reu_byte
            sta $51
            lda #1
            sta $55
            lda #0
            sta $56
            sta $57
            NTC_RS
            lda #$91
            jsr ntc_reu_do
            NTC_TS
            ldy #0
            lda ntc_reu_byte
            sta (z_p3),y
            iny
            lda #0
            sta (z_p3),y
#endasm
End Function

' Poke: the byte at bank : addr set to value
Public Sub Poke(ByVal bank As Integer, ByVal addr As Integer, ByVal value As Integer)
#asm
            NTC_POP z_p1
            NTC_POP z_p2
            NTC_POP z_p0
            ldy #0
            lda (z_p0),y
            sta ntc_reu_byte
            lda (z_p1),y
            sta $54
            lda (z_p2),y
            sta $52
            iny
            lda (z_p2),y
            sta $53
            lda #<ntc_reu_byte
            sta $50
            lda #>ntc_reu_byte
            sta $51
            lda #1
            sta $55
            lda #0
            sta $56
            sta $57
            NTC_RS
            lda #$90
            jsr ntc_reu_do
            NTC_TS
#endasm
End Sub

' Deek: the word (low byte first) at bank : addr
Public Function Deek(ByVal bank As Integer, ByVal addr As Integer) As Integer
#asm
            NTC_POP z_p1
            NTC_POP z_p2
            NTC_POP z_p3
            ldy #0
            lda (z_p1),y
            sta $54
            lda (z_p2),y
            sta $52
            iny
            lda (z_p2),y
            sta $53
            lda #<ntc_reu_byte
            sta $50
            lda #>ntc_reu_byte
            sta $51
            lda #2
            sta $55
            lda #0
            sta $56
            sta $57
            NTC_RS
            lda #$91
            jsr ntc_reu_do
            NTC_TS
            ldy #0
            lda ntc_reu_byte
            sta (z_p3),y
            iny
            lda ntc_reu_byte+1
            sta (z_p3),y
#endasm
End Function

' Doke: the word at bank : addr set to value
Public Sub Doke(ByVal bank As Integer, ByVal addr As Integer, ByVal value As Integer)
#asm
            NTC_POP z_p1
            NTC_POP z_p2
            NTC_POP z_p0
            ldy #0
            lda (z_p0),y
            sta ntc_reu_byte
            lda (z_p1),y
            sta $54
            lda (z_p2),y
            sta $52
            iny
            lda (z_p0),y
            sta ntc_reu_byte+1
            lda (z_p2),y
            sta $53
            lda #<ntc_reu_byte
            sta $50
            lda #>ntc_reu_byte
            sta $51
            lda #2
            sta $55
            lda #0
            sta $56
            sta $57
            NTC_RS
            lda #$90
            jsr ntc_reu_do
            NTC_TS
#endasm
End Sub
