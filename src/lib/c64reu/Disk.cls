' Disk - files from the disc straight into the REU. NTC platform class: Commodore 64 with an
' REU (6502)
'
' The program's pictures, sprite shapes, music and levels stay on the disc as ordinary files
' and are read into the REU - not into the C64's memory - when wanted: at the start, or one
' level at a time. From the REU they come out with Reu.Fetch in a cycle a byte.
'
'     n = Disk.LoadReu("SHAPES", 1, 0)        ' the file SHAPES into bank 1 from address 0
'     If n = 0 Then Print "SHAPES is not on the disc"
'
' The KERNAL does the reading, from the drive the program was loaded from: a 1541, an SD card
' drive, an Ultimate's - whatever LOAD works with. While it reads, the frame's interrupt is
' off: Ticks stand still and a frame hook's music stops. On a real 1541 that is about 400
' bytes a second; an SD card drive or a fast loader cartridge is many times that.
' The file is read whole, every byte of it (a PRG file's first two bytes - its load address -
' are its first two bytes in the REU).

' LoadReu(name, bank, addr): the file into the REU from bank : addr on (over a bank's end into
' the next). The number of 128 byte blocks read, the last one counted whole; 0 = no such file
Public Function LoadReu(ByVal name As String, ByVal bank As Integer, ByVal addr As Integer) As Integer
#asm
            NTC_POP z_p0            ; the name
            NTC_POP z_p1
            NTC_POP z_p2
            NTC_POP z_p3
            ldy #0
            lda (z_p1),y
            sta ntc_c64_fbank
            lda (z_p2),y
            sta ntc_c64_faddr
            iny
            lda (z_p2),y
            sta ntc_c64_faddr+1
            lda z_p0
            sta $FB
            lda z_p0+1
            sta $FC
            ldy #0
len:
            lda (z_p0),y
            beq got
            iny
            cpy #16
            bne len
got:
            sty ntc_c64_fnlen
            NTC_RS
            jsr ntc_c64_fread_k
            ldy #0
            lda ntc_c64_fblk
            sta (z_p3),y
            iny
            lda ntc_c64_fblk+1
            sta (z_p3),y
            ; the KERNAL's stack may have gone over the windows: back to the thread by
            ; fetching the piece again (ntc_ip = where SP was in it)
            ldx ntc_ip
            inx
            txa
            and #$3F
            ora ntc_wb
            tax
            ldy ntc_wb+1
            jmp ntc_goxy
#endasm
End Function

' LastBytes(): how many bytes the last block of the file just read had (1-128), so its exact
' length is (LoadReu's answer - 1) * 128 + LastBytes()
Public Function LastBytes() As Integer
#asm
            NTC_POP z_p0
            ldy #0
            lda ntc_c64_flast
            sta (z_p0),y
            iny
            lda #0
            sta (z_p0),y
#endasm
End Function
