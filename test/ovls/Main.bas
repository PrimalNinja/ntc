' Overlay classes with one overlay area (Option Memory Small / CP/M) - regress.sh
' A and B take turns in #4000-#7FFF: a call loads its class there, a return
' loads the caller's class again when another took its place.
Option Memory Small
Option Reserve &H4000, &H4000
#If NTC_CPCMIN Then
Option RomEnable 7                ' AMSDOS for the overlay files
#End If
#If NTC_CPCFW Then
Option RomEnable 7
#End If
Print "in"; A.Loaded(); B.Loaded(); " page"; A.Page()
Print "a"; A.Twice(4); A.Loaded(); B.Loaded()
Print "b"; B.Chain(5); A.Loaded(); B.Loaded()
Print "deep"; A.Deep(3); A.Loaded(); B.Loaded()
Print "busy"; A.TryLoad()
Print "local"; A.Local()
Print "paged"; A.Count(); B.Chain(1); A.Count()
Print "unload"; B.Unload(); B.Loaded(); A.Unload(); A.Loaded(); " again"; A.Unload()
Print "load"; B.Load(); B.Loaded(); A.Loaded(); " twice"; B.Load()
Print "main"; B.Chain(2)
Print "done"
End

Sub Note(ByVal t As String)
  Print " ("; t; ")";
End Sub
