' Sound - bytes to NTC's sound driver on the Neo Geo's Z80 (src/asm/neogeo_sound_z80.asm: the
' cartridge's M1 ROM, the CD's .Z80 file). NTC platform class: SNK Neo Geo (68000).
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' The Pcm, Psg, Fm and Cdda classes send their messages through here; a program's own messages
' (a driver of its own in the M1 ROM) can too.
'   Sound.Send b      a byte to the Z80, and its answer waited for (the driver counts each byte)
Option Explicit

Public Sub Send(ByVal b As Integer)
#asm
            movea.l (sp)+, a0
            move.w (a0), d2
            NTC_RS
            move.b d2, d0
            jsr ntc_ng_snd
            NTC_TS
#endasm
End Sub
