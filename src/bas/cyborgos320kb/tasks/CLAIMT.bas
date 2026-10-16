' CLAIMT: the claims tried (regress): SOUND 0 claimed - or who has it -, held until it is taken
' (CLAIMS TAKE SOUND 0) or the program killed
Option Explicit
Dim r As Integer
r = CybSys.Claim("sound", 0)
If r <> 0 Then Print "SOUND 0 busy: slot "; Trim$(Str$(r)) : End
Print "SOUND 0 claimed"
Do
  r = CybSys.Held("SOUND", 0)
Loop While r = 0
Print "SOUND 0 lost to slot "; Trim$(Str$(r))
