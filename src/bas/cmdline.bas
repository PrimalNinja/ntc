' Command line: on CP/M, what was typed after the program's name (A>CMDLINE HELLO THERE);
' where there is no command line (the CPC), the program asks for it instead.
Option Explicit
Dim cl As String, i As Integer, w As Integer

If System.HasCapability("COMMANDLINE") Then
  cl = System.CommandLine
  Print "Command line: ["; cl; "]"
Else
  Input "No command line here - type one"; cl
End If
' the words in it, one per line
w = 0
For i = 1 To Len(cl)
  If Mid$(cl, i, 1) <> " " Then
    If (i = 1) Or (Mid$(cl, i - 1, 1) = " ") Then w = w + 1 : Print w; ": ";
    Print Mid$(cl, i, 1);
    If (i = Len(cl)) Or (Mid$(cl, i + 1, 1) = " ") Then Print
  End If
Next
Print w; " words"
Print "Files: "; IIf(System.HasCapability("FILES"), "yes", "no"); ", pages: "; IIf(System.HasCapability("PAGES"), "yes", "no")
End
