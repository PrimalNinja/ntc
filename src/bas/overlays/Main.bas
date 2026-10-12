' Overlays: two classes built into their own files (LEVEL1.PAG, LEVEL2.PAG) in the same
' compile. Each runs at #4000. Keep LEVEL1.PAG and LEVEL2.PAG on the disc with the program.
' cpcmin / cpcfw (Option Memory CPCExpansion, needs a 6128 or more RAM): each class gets its
' own RAM page, loaded by its first call, and stays there.
' cpm (and Option Memory Small): one overlay area at #4000-#7FFF - a call loads its class
' there over the one that was, a return loads the caller's class again if it was swapped out.
Option Explicit
#If NTC_CPCMIN Then
Option RomEnable 7                ' RUN" drops AMSDOS: start it again, the overlays load from disc
#End If
#If NTC_CPCFW Then
Option RomEnable 7
#End If
Option Reserve &H4000, &H4000     ' the program stays out of the window the overlays run in
Dim lvl As Integer, score As Integer

#If NTC_MEM_SMALL Then
Print "Overlays on "; System.Platform; ": one overlay area at &4000"
#Else
Print "Overlays on "; System.Platform; ", "; Memory.RamSize(); "K"
#End If
Print "Level 1 loaded: "; Level1.Loaded()
For lvl = 1 To 2
  If lvl = 1 Then score = score + Level1.Play(score)
  If lvl = 2 Then score = score + Level2.Play(score)
Next
Print "Score "; score
#If NTC_MEM_SMALL Then
Print "In the area: level 1 "; Level1.Loaded(); ", level 2 "; Level2.Loaded()
Print "Unload level 2: "; Level2.Unload(); " - level 2 "; Level2.Loaded()
#Else
Print "Level 1 in page "; Level1.Page(); ", level 2 in page "; Level2.Page()
Print "Pages "; Memory.Map(1, Memory.Pages())
Print "Unload level 1: "; Level1.Unload(); " - pages "; Memory.Map(1, Memory.Pages())
#End If
Print "Press a key";
Do While Inkey <> 0 : Loop
Do : Frame : Loop Until Inkey <> 0
Print
End

' the main program's own routines: overlays can call them
Sub Banner(ByVal text As String)
  Print "== "; text; " =="
End Sub
