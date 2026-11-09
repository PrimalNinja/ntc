' Intro - INTRODUCTION TO ZOSCII: the title, the contents and the pages. (c) 2026 Cyborg Unicorn Pty Ltd
Option Explicit

Private sel As Integer

Private Function MenuTx(ByVal i As Integer) As Integer
  Select Case i
    Case 0
      MenuTx = Data.TX_M1
    Case 1
      MenuTx = Data.TX_M2
    Case 2
      MenuTx = Data.TX_MA
    Case 3
      MenuTx = Data.TX_M3
    Case 4
      MenuTx = Data.TX_M4
    Case 5
      MenuTx = Data.TX_M5
    Case 6
      MenuTx = Data.TX_M6
    Case 7
      MenuTx = Data.TX_M7
    Case 8
      MenuTx = Data.TX_MB
    Case 9
      MenuTx = Data.TX_M8
    Case 10
      MenuTx = Data.TX_M9
    Case 11
      MenuTx = Data.TX_M11
    Case 12
      MenuTx = Data.TX_M12
    Case 13
      MenuTx = Data.TX_MD
    Case 14
      MenuTx = Data.TX_MC
    Case Else
      MenuTx = Data.TX_M10
  End Select
End Function

Private Sub Title()
  Dim k As Integer, t As Integer, i As Integer, j As Integer
  Vid.Fill 0, 0, 320, 256, 5
  Vid.BigC 36, Data.TX_TITLE, 8, 2
  Vid.BigC 70, Data.TX_ZOSCII, 10, 8
  Vid.TxtC 140, Data.TX_SUBTITLE, 2
  Vid.TxtC 228, Data.TX_BY, 2
  Vid.TxtC 242, Data.TX_COPY, 3
  t = 0
  k = 0
  Do While (k And 16) = 0
    Vid.Sync
    k = Vid.Edge()
    t = t + 1
    If (t And 7) = 0 Then
      For j = 0 To 3
        For i = 0 To 6
          Vid.Hex4(20 + i * 42, 170 + j * 10, Rng.Pick(256), Rng.Pick(256), 4)
        Next
      Next
    End If
    If (t And 32) <> 0 Then
      Vid.TxtC 214, Data.TX_PRESS, 1
    Else
      Vid.Fill 100, 214, 120, 8, 5
    End If
  Loop
  Snd.Beep 1
End Sub

Private Sub Menu()
  Dim i As Integer, c As Integer
  Vid.Page Data.TX_MENU, Data.TX_K_MENU
  For i = 0 To 15
    c = 2
    If i = sel Then
      c = 10
      Vid.Fill 20, 34 + i * 12 - 3, 280, 11, 6
    End If
    Vid.Txt 30, 34 + i * 12, MenuTx(i), c
  Next
End Sub

Public Sub Run()
  Dim k As Integer, go As Integer
  Title
  Rng.Reseed
  sel = 0
  Do
    Menu
    go = 0
    Do While go = 0
      Vid.Sync
      k = Vid.Edge()
      If (k And 1) <> 0 And sel > 0 Then sel = sel - 1 : Menu
      If (k And 2) <> 0 And sel < 15 Then sel = sel + 1 : Menu
      If (k And 16) <> 0 Then go = 1
    Loop
    Select Case sel
      Case 0
        Screens.Story
      Case 1
        Screens.Ntc
      Case 2
        Screens.Pages 3, 2
      Case 3
        Screens.Letter
      Case 4
        Screens.Plaus
      Case 5
        Screens.Anatomy
      Case 6
        Screens.Pages 0, 5
      Case 7
        Screens.Pages 1, 4
      Case 8
        Screens.Pages 4, 5
      Case 9
        Screens.Pages 2, 2
      Case 10
        Play.Screen
      Case 11
        Demo.Run 0
      Case 12
        Demo.Run 1
      Case 13
        Screens.Pages 6, 4
      Case 14
        Screens.Pages 5, 4
      Case Else
        Screens.Fine
    End Select
  Loop
End Sub
