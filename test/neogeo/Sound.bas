' Sound.bas - one of the Neo Geo's sound sources for about 1.7 seconds, then quiet
' (test/ngregress.sh builds it once for each and listens). (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Option Explicit
Const ONLY = "psg"
Dim i As Integer

For i = 1 To 20
    Frame
Next i
Select Case ONLY
    Case "psg"
        Psg.Tone 0, 284, 12
    Case "fm"
        ' channel 1: algorithm 7 (each operator heard), operator 1 only: full level, fast attack
        Fm.Reg 0, &HB1, &H07 : Fm.Reg 0, &HB5, &HC0
        Fm.Reg 0, &H31, &H01 : Fm.Reg 0, &H41, &H00 : Fm.Reg 0, &H51, &H1F
        Fm.Reg 0, &H61, &H00 : Fm.Reg 0, &H71, &H00 : Fm.Reg 0, &H81, &H0F
        Fm.Reg 0, &HA5, &H22 : Fm.Reg 0, &HA1, &H69
        Fm.Key 1, 1
    Case "song"
        Pcm.Init 0
        Pcm.Play 0, 1
    Case Else
        ' the sample is a tenth of a second: played again every 6 frames
End Select
For i = 1 To 100
    If ONLY = "sample" Then
        If (i Mod 6) = 1 Then Pcm.Sample 0, 0, 31
    End If
    Frame
Next i
Psg.Quiet : Fm.Quiet : Pcm.Quiet : Pcm.SampleOff 0
Fm.Reg 0, &H81, &HFF
Print "end"
Do
    Frame
Loop
