' Pcm - music on the X68000's ADPCM (the MSM6258), played by the ROM's call (IOCS _ADPCMAOT: the
' DMA sends it in pieces while the program runs). NTC platform class: Sharp X68000 (first written
' for TIANLONG). (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'   Init data     nothing playing. data: the songs' address (a Long), made by tools/adpcm/okiadpcm.js
'   Have(n)       1 when song n (0-4) is there
'   Play n, lp    song n from its start; lp 1: round again at its end (Update starts it again)
'   Quiet         the music stopped
'   Update        once a frame: a song that went round, started again
' The songs' data: 5 x (a Long: the song's place from the data's start, a Long: its bytes; 0 for
' none; the 68000's byte order), then the songs: the MSM6258's 4-bit ADPCM at 7.8 kHz.
Option Explicit

Private mb As Long, cur As Integer, lpf As Integer
Private tbl(29) As Integer                 ' the DMA's pieces: up to 10 of (address, length)

' the long at address a
Private Function L(ByVal a As Long) As Long
#asm
            movea.l (sp)+, a0
            movea.l (a0), a1
            movea.l (sp)+, a0
            move.l (a1), (a0)
#endasm
End Function

Public Sub Init(ByVal data As Long)
    mb = data
    cur = -1
End Sub

Public Function Have(ByVal n As Integer) As Integer
    If L(mb + n * 8 + 4) <> 0 Then Have = 1 Else Have = 0
End Function

Public Sub Play(ByVal n As Integer, ByVal lp As Integer)
    Quiet
    If Have(n) = 0 Then Exit Sub
    cur = n : lpf = lp
    Start
End Sub

' the song's pieces (65280 bytes at most each) to tbl, then IOCS _ADPCMAOT
Private Sub Start()
    Dim lngA As Long, lngN As Long, lngP As Long, intK As Integer
    lngA = mb + L(mb + cur * 8)
    lngN = L(mb + cur * 8 + 4)
    intK = 0
    Do While lngN > 0 And intK < 10
        If lngN > 65280 Then lngP = 65280 Else lngP = lngN
        Piece intK, lngA, CInt(lngP And &H7FFF), CInt(lngP \ 32768)
        lngA = lngA + lngP : lngN = lngN - lngP
        intK = intK + 1
    Loop
    Send intK
End Sub

' Piece k, a, lo, hi: tbl's entry k = address a, length hi * 32768 + lo (big-endian, as the DMA's
' array wants: a long and a word)
Private Sub Piece(ByVal k As Integer, ByVal a As Long, ByVal lo As Integer, ByVal hi As Integer)
#asm
            movea.l (sp)+, a0
            move.w (a0), d0
            movea.l (sp)+, a0
            move.l (a0), d1
            movea.l (sp)+, a0
            move.w (a0), d2
            movea.l (sp)+, a0
            move.w (a0), d3
            lea {tbl}, a1
            mulu.w #6, d0
            adda.w d0, a1
            move.l d1, (a1)+
            moveq #15, d4
            lsl.w d4, d3
            or.w d3, d2
            move.w d2, (a1)
#endasm
End Sub

Private Sub Send(ByVal n As Integer)
#asm
            movea.l (sp)+, a0
            move.w (a0), d2
            ext.l d2
            lea {tbl}, a1
            move.w #$0203, d1           ; 7.8 kHz, both sides
            moveq #$62, d0              ; IOCS _ADPCMAOT
            trap #15
#endasm
End Sub

Public Sub Quiet()
    Halt
    cur = -1
End Sub

Private Sub Halt()
#asm
            moveq #0, d1
            moveq #$67, d0              ; IOCS _ADPCMMOD 0: stop
            trap #15
#endasm
End Sub

' Busy(): not 0 while the ADPCM plays (IOCS _ADPCMSNS)
Private Function Busy() As Integer
#asm
            moveq #$66, d0
            trap #15
            movea.l (sp)+, a0
            move.w d0, (a0)
#endasm
End Function

Public Sub Update()
    If cur >= 0 Then
        If Busy() = 0 Then
            If lpf Then Start Else cur = -1
        End If
    End If
End Sub
