' Sid - the C64's sound chip: three voices. NTC platform class: Commodore 64 with an REU (6502)
'
'     Sid.Volume 15
'     Sid.Voice 0, Sid.Saw, 0, 9, 0, 0        ' voice 0: a sawtooth that dies away by itself
'     Sid.Tone 0, 440                          ' an A, started
'     ...
'     Sid.Off 0                                ' its release starts
'
' Voices are 0, 1, 2. Attack, decay and release are 0-15 (0 the quickest), sustain 0-15 (how
' loud it holds while the note is on). For music played from the frame's interrupt, hand a
' player's routine to System.FrameHook.

Public Const Triangle = 16
Public Const Saw = 32
Public Const Pulse = 64
Public Const Noise = 128

Private mWave(2) As Integer

' Volume v: 0-15, for all three voices
Public Sub Volume(ByVal v As Integer)
    Poke &HD418, v And 15
End Sub

' Voice v, wave, attack, decay, sustain, release: what voice v sounds like
Public Sub Voice(ByVal v As Integer, ByVal wave As Integer, ByVal attack As Integer, ByVal decay As Integer, ByVal sustain As Integer, ByVal release As Integer)
    Dim r As Integer
    r = &HD400 + (v Mod 3) * 7
    mWave(v Mod 3) = wave
    Poke r + 2, 0
    Poke r + 3, 8                      ' a pulse wave: half and half
    Poke r + 5, (attack And 15) * 16 + (decay And 15)
    Poke r + 6, (sustain And 15) * 16 + (release And 15)
End Sub

' Note v, value: voice v starts a note at the SID's own frequency value (0-65535)
Public Sub Note(ByVal v As Integer, ByVal value As Integer)
    Dim r As Integer
    r = &HD400 + (v Mod 3) * 7
    Poke r + 4, mWave(v Mod 3)
    Doke r, value
    Poke r + 4, mWave(v Mod 3) + 1
End Sub

' Tone v, hz: voice v starts a note of hz cycles a second (to about 3800)
Public Sub Tone(ByVal v As Integer, ByVal hz As Integer)
    Note v, hz * 17 + hz \ 32
End Sub

' Off v: voice v's note ends (its release starts)
Public Sub Off(ByVal v As Integer)
    Poke &HD404 + (v Mod 3) * 7, mWave(v Mod 3)
End Sub

' Quiet: all three off at once
Public Sub Quiet()
    Poke &HD404, 0
    Poke &HD40B, 0
    Poke &HD412, 0
End Sub
