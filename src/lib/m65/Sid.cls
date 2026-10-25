' Sid - the MEGA65's SIDs as sound effects that move on a frame at a time (the same as the Mega
' Drive's Psg class). NTC platform class: MEGA65 (45GS02)
'
' Sid.Play channel, period, slide, volume, frames: channel 0-2 a tone (SID 1's voices, a square
' wave), 3 a noise (SID 2's voice 1). A tone's period is 1-1023 as the Mega Drive's PSG has it
' (the note is 3579545 / (32 * period) Hz: 254 is middle C), slide is added to it every frame;
' the noise's period is its kind: 0-3 / 4-7 high, middle, low, at channel 2's pitch. Volume
' 0-15 (15 the loudest) fades to nothing over frames (0: held until Sid.Stop). Call
' Sid.Update once a frame.

' a sound on a channel
Public Sub Play(ByVal channel As Integer, ByVal period As Integer, ByVal slide As Integer, ByVal volume As Integer, ByVal frames As Integer)
#asm
            NTC_POP z_p0
            ldy #0
            lda (z_p0),y
            and #3
            sta z_t0                    ; the channel
            asl                         ; * 12
            asl
            sta z_t1
            asl
            clc
            adc z_t1
            tax                         ; its state
            lda #1
            sta ntc_sidch,x             ; active
            NTC_POP z_p0
            ldy #0
            lda (z_p0),y
            sta ntc_sidch+2,x           ; period
            iny
            lda (z_p0),y
            sta ntc_sidch+3,x
            NTC_POP z_p0
            ldy #0
            lda (z_p0),y
            sta ntc_sidch+4,x           ; slide
            iny
            lda (z_p0),y
            sta ntc_sidch+5,x
            NTC_POP z_p0
            ldy #0
            lda (z_p0),y
            and #15
            sta ntc_sidch+6,x           ; volume
            NTC_POP z_p0
            ldy #0
            lda (z_p0),y
            sta ntc_sidch+8,x           ; frames
            sta ntc_sidch+10,x          ; left
            iny
            lda (z_p0),y
            sta ntc_sidch+9,x
            sta ntc_sidch+11,x
            stx z_t1
            NTC_RS
            ldx z_t1
            lda z_t0
            jsr ntc_sid_on
            NTC_TS
#endasm
End Sub

' a channel quiet
Public Sub Stop(ByVal channel As Integer)
#asm
            NTC_POP z_p0
            ldy #0
            lda (z_p0),y
            and #3
            sta z_t0
            NTC_RS
            lda z_t0
            jsr ntc_sid_off
            NTC_TS
#endasm
End Sub

' every channel quiet
Public Sub Quiet()
#asm
            NTC_RS
            lda #0
            jsr ntc_sid_off
            lda #1
            jsr ntc_sid_off
            lda #2
            jsr ntc_sid_off
            lda #3
            jsr ntc_sid_off
            NTC_TS
#endasm
End Sub

' True when the channel is playing
Public Function Busy(ByVal channel As Integer) As Integer
#asm
            NTC_POP z_p0
            NTC_POP z_p1
            ldy #0
            lda (z_p0),y
            and #3
            asl
            asl
            sta z_t1
            asl
            clc
            adc z_t1
            tax
            lda ntc_sidch,x
            beq no
            lda #$FF
no:
            sta (z_p1),y
            iny
            sta (z_p1),y
#endasm
End Function

' every channel a frame on: once a frame
Public Sub Update()
#asm
            NTC_RS
            jsr ntc_sid_update
            NTC_TS
#endasm
End Sub
