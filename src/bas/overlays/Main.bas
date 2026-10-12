' Overlays: two classes built into their own files (LEVEL1.PAG, LEVEL2.PAG) in the same
' compile. Each runs at #4000 in a RAM page; a call loads its file the first time.
' Needs a 6128 (or more RAM) and AMSDOS: cpcmin or cpcfw. Keep LEVEL1.PAG and LEVEL2.PAG on
' the disc with OVERLAYS.BIN.
Option Explicit
Option RomEnable 7                ' RUN" drops AMSDOS: start it again, the overlays load from disc
Option Reserve &H4000, &H4000     ' the program stays out of the window the overlays run in
Dim lvl As Integer, score As Integer

Print "Overlays on "; System.Platform; ", "; Memory.RamSize(); "K"
Print "Level 1 loaded: "; Level1.Loaded()
For lvl = 1 To 2
  If lvl = 1 Then score = score + Level1.Play(score)
  If lvl = 2 Then score = score + Level2.Play(score)
Next
Print "Score "; score
Print "Level 1 in page "; Level1.Page(); ", level 2 in page "; Level2.Page()
Print "Pages "; Memory.Map(1, Memory.Pages())
Print "Unload level 1: "; Level1.Unload(); " - pages "; Memory.Map(1, Memory.Pages())
Print "Press a key";
Do While Inkey <> 0 : Loop
Do : Frame : Loop Until Inkey <> 0
Print
End

' the main program's own routines: overlays can call them
Sub Banner(ByVal text As String)
  Print "== "; text; " =="
End Sub
