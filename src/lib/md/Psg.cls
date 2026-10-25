' Psg - the Mega Drive's PSG (the SN76489: 3 square wave tones and a noise) as sound effects
' that move on a frame at a time. NTC platform class: Sega Mega Drive / Genesis
'
' Psg.Play channel, period, slide, volume, frames: channel 0-2 a tone, 3 the noise. A tone's
' period is 1-1023 (the note is 3579545 / (32 * period) Hz: 254 is middle C), slide is added
' to it every frame; the noise's period is its kind: 0-3 periodic, 4-7 white (3 / 7: at
' tone channel 2's pitch). Volume 0-15 (15 the loudest) fades to nothing over frames (0: held
' until Psg.Stop). Call Psg.Update once a frame.

' a sound on a channel
Public Sub Play(ByVal channel As Integer, ByVal period As Integer, ByVal slide As Integer, ByVal volume As Integer, ByVal frames As Integer)
#asm
            movea.l (sp)+, a0
            move.w (a0), d3
            andi.w #3, d3
            move.w d3, d0
            mulu.w #12, d0
            lea ntc_psgch, a1
            adda.w d0, a1
            move.w #1, (a1)             ; active
            movea.l (sp)+, a0
            move.w (a0), 2(a1)          ; period
            movea.l (sp)+, a0
            move.w (a0), 4(a1)          ; slide
            movea.l (sp)+, a0
            move.w (a0), d0
            andi.w #15, d0
            move.w d0, 6(a1)            ; volume
            movea.l (sp)+, a0
            move.w (a0), 8(a1)          ; frames
            move.w (a0), 10(a1)         ; left
            movea.l a1, a0
            NTC_RS
            jsr ntc_md_psgout
            NTC_TS
#endasm
End Sub

' a channel quiet
Public Sub Stop(ByVal channel As Integer)
#asm
            movea.l (sp)+, a0
            move.w (a0), d3
            andi.w #3, d3
            NTC_RS
            jsr ntc_md_psgoff
            NTC_TS
#endasm
End Sub

' every channel quiet
Public Sub Quiet()
#asm
            NTC_RS
            moveq #3, d3
lp:
            jsr ntc_md_psgoff
            dbra d3, lp
            NTC_TS
#endasm
End Sub

' True when the channel is playing
Public Function Busy(ByVal channel As Integer) As Integer
#asm
            movea.l (sp)+, a0
            move.w (a0), d0
            andi.w #3, d0
            mulu.w #12, d0
            lea ntc_psgch, a1
            movea.l (sp)+, a0
            tst.w 0(a1, d0.w)
            sne d0
            ext.w d0
            move.w d0, (a0)
#endasm
End Function

' every channel a frame on: once a frame
Public Sub Update()
#asm
            NTC_RS
            jsr ntc_md_psgupd
            NTC_TS
#endasm
End Sub
