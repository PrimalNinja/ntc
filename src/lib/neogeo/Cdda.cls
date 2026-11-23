' Cdda - CD audio on the Neo Geo CD (NTC's neocd platform): the disc's audio tracks, played by the
' CD BIOS (NTC's sound driver on the Z80 puts the request where the BIOS takes it each frame).
' NTC platform class: SNK Neo Geo CD (68000). (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'   Cdda.Play t     track t (2-99: track 1 is the data) from its start, and again at its end
'   Cdda.Quiet      stopped
' On a cartridge these do nothing (the driver's request is never taken).
Option Explicit

Public Sub Play(ByVal t As Integer)
    Sound.Send &H40
    Sound.Send (t \ 10) * 16 + (t Mod 10)        ' the track in BCD
End Sub

Public Sub Quiet()
    Sound.Send &H41
End Sub
