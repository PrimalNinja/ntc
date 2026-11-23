' Fm - the YM2610's four FM channels on the Neo Geo (four operators each, as the Mega Drive's
' YM2612 has six). The registers are written through NTC's sound driver on the Z80. NTC platform
' class: SNK Neo Geo (68000). (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'   Fm.Reg port, r, v    register r = v. port 0: the chip's first port (the LFO $22, the timers'
'                        mode $27, key on / off $28, channels 1 and 2: $30-$B6); port 1: its
'                        second (channels 3 and 4: $30-$B6). Registers below $20 are not FM's
'                        (the SSG, the ADPCM): not written
'   Fm.Key ch, ops       channel ch (1-4): its operators on (ops: bit 0-3 = operator 1-4; 15 all,
'                        0 the key off)
'   Fm.Quiet             every channel's key off
' Within a port a channel's registers are the YM2612's: the first channel of a port at the
' register's number + 1, the second at + 2 (so channel 1's algorithm is port 0's $B1, channel 4's
' is port 1's $B2).
Option Explicit

Public Sub Reg(ByVal port As Integer, ByVal r As Integer, ByVal v As Integer)
    If port = 0 Then Sound.Send &H50 Else Sound.Send &H51
    Sound.Send r : Sound.Send v
End Sub

Public Sub Key(ByVal ch As Integer, ByVal ops As Integer)
    Dim k As Integer
    Select Case ch
        Case 1: k = 1
        Case 2: k = 2
        Case 3: k = 5
        Case Else: k = 6
    End Select
    Sound.Send &H50 : Sound.Send &H28 : Sound.Send (ops And 15) * 16 + k
End Sub

Public Sub Quiet()
    Key 1, 0 : Key 2, 0 : Key 3, 0 : Key 4, 0
End Sub
