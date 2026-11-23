' Pcm - music and sampled sounds on the Neo Geo: the YM2610's ADPCM-B (one channel, any rate: the
' songs, played round and round) and ADPCM-A (six channels at 18.5 kHz: sounds played once),
' straight from the cartridge's V ROM by NTC's sound driver on the Z80. NTC platform class: SNK
' Neo Geo (68000; first written for TIANLONG and SILK TO STEEL). (c) 2026 Cyborg Unicorn Pty Ltd -
' MIT License
'   Pcm.Init data       nothing playing (data is not used here: the songs are in the V ROM. It is
'                       there so the line is the same as on NTC's other machines)
'   Pcm.Have(n)         1: every song is in the cartridge
'   Pcm.Play n, lp      song n (0-31) from its start, round and round (lp: always)
'   Pcm.Quiet           the music stopped
'   Pcm.Volume v        the music's loudness (0-255)
'   Pcm.Update          (nothing to do: the chip plays by itself)
'   Pcm.Sample n, c, l  sample n (0-63) once on channel c (0-5) at loudness l (0-31)
'   Pcm.SampleOff c     channel c stopped
'   Pcm.SampleVolume c, l   channel c's loudness (0-31)
' The V ROM and the driver's two tables (the songs, the samples) are made by tools/neogeo/ngpcm.js;
' test/ngbuild.js --vrom --songs --samples puts them in the cartridge. (The Neo Geo CD has no V
' ROM: its music is the disc's audio tracks - the Cdda class.)
Option Explicit

Public Sub Init(ByVal data As Long)
    Sound.Send &H21
End Sub

Public Function Have(ByVal n As Integer) As Integer
    Have = 1
End Function

Public Sub Play(ByVal n As Integer, ByVal lp As Integer)
    Sound.Send &H20 : Sound.Send n
End Sub

Public Sub Quiet()
    Sound.Send &H21
End Sub

Public Sub Volume(ByVal v As Integer)
    Sound.Send &H22 : Sound.Send v
End Sub

Public Sub Update()
End Sub

Public Sub Sample(ByVal n As Integer, ByVal c As Integer, ByVal l As Integer)
    Sound.Send &H30 : Sound.Send n : Sound.Send c : Sound.Send l
End Sub

Public Sub SampleOff(ByVal c As Integer)
    Sound.Send &H31 : Sound.Send c
End Sub

Public Sub SampleVolume(ByVal c As Integer, ByVal l As Integer)
    Sound.Send &H32 : Sound.Send c : Sound.Send l
End Sub
