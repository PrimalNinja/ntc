' AtkW - the attacker's work on the scratch block (window #4000). Resident: code in a page runs in the window itself, so it can't select a block.
' The tables live in the scratch block: nx chains (Integer) at 4096, the address bytes lo at 8192 and hi at 10240, heads (Integer) at 12288
' (c) 2026 Cyborg Unicorn Pty Ltd
Option Explicit

Private Const NXO = 4096, ALO = 8192, AHO = 10240, HDO = 12288

' Build rd: the addresses of reading rd (0: start at byte 0, 1: start at byte 1) from the file into the scratch block; returns how many
Public Function Build(ByVal rd As Integer) As Integer
  Dim i As Integer, n As Integer, s As Integer
  s = rd And 1
  n = (Rom.Wn - s) \ 2
  If n > 1280 Then n = 1280
  Vid.SelBlock Data.SCRB
  For i = 0 To n - 1
    Poke &H4000 + ALO + i, Rom.Wg(s + i * 2)
    Poke &H4000 + AHO + i, Rom.Wg(s + i * 2 + 1)
  Next
  Vid.SelBlock -1
  Build = n
End Function

' Pairs n: the number of pairs of equal addresses among the first n, by chains on the low byte (a chain link is an index + 1, 0 = none)
Public Function Pairs(ByVal n As Integer) As Integer
  Dim i As Integer, j As Integer, c As Integer, lo As Integer, hi As Integer, h As Integer
  Vid.SelBlock Data.SCRB
  For i = 0 To 511
    Poke &H4000 + HDO + i, 0
  Next
  c = 0
  For i = 0 To n - 1
    lo = Peek(&H4000 + ALO + i)
    hi = Peek(&H4000 + AHO + i)
    h = Peek(&H4000 + HDO + lo * 2) + Peek(&H4000 + HDO + lo * 2 + 1) * 256
    j = h
    Do While j > 0
      If Peek(&H4000 + AHO + j - 1) = hi Then c = c + 1
      j = Peek(&H4000 + NXO + (j - 1) * 2) + Peek(&H4000 + NXO + (j - 1) * 2 + 1) * 256
    Loop
    Poke &H4000 + NXO + i * 2, h And 255
    Poke &H4000 + NXO + i * 2 + 1, h \ 256
    Poke &H4000 + HDO + lo * 2, (i + 1) And 255
    Poke &H4000 + HDO + lo * 2 + 1, (i + 1) \ 256
  Next
  Vid.SelBlock -1
  Pairs = c
End Function

' Crib m, n: slide the crib (m reading positions, Attack.cb) over the n addresses of the reading in the scratch block; Tried positions, Outc ruled out, Best equal pairs of a consistent one
Public Tried As Integer, Outc As Integer, Best As Integer
Public Sub Crib(ByVal m As Integer, ByVal n As Integer)
  Dim p As Integer, i As Integer, j As Integer, k As Integer, ok As Integer
  Tried = 0 : Outc = 0 : Best = 0
  Vid.SelBlock Data.SCRB
  For p = 0 To n - m
    Tried = Tried + 1
    ok = 1
    k = 0
    For i = 0 To m - 2
      For j = i + 1 To m - 1
        If Peek(&H4000 + ALO + p + i) = Peek(&H4000 + ALO + p + j) And Peek(&H4000 + AHO + p + i) = Peek(&H4000 + AHO + p + j) Then
          If Attack.cb(i) <> Attack.cb(j) Then
            ok = 0
          Else
            k = k + 1
          End If
        End If
      Next
    Next
    If ok = 0 Then
      Outc = Outc + 1
    Else
      If k > Best Then Best = k
    End If
  Next
  Vid.SelBlock -1
End Sub
