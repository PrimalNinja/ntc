' C64 + REU: a program in lots. The REU past the kernel's 32K is lots of 96K. A lot named by
' Option Lot is a code lot: up to 64K of its classes' compiled code, and up to 32K of workspace
' - their variables, strings and call stubs - which is in the C64's memory only while that lot
' is running. Any other lot is 96K for data.
'
' Here: the title screen is one lot, each stage another, and a fourth lot holds data. Game is
' in no lot: it is the kernel's, always in memory, and every lot calls it.
' A lot's Sub called from outside its lot takes no parameters: what is shared goes through Game.
' (An REU of 512K.)
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Option Explicit

Option Lot Front = Title
Option Lot First = Stage1
Option Lot Second = Stage2

Const DATALOT = 4               ' a lot for data: 96K from Reu.LotBank(4) : Reu.LotAddr(4)

Dim round As Integer

Cls
If System.Lots() < 4 Then
  Print "this needs an REU of 512K or more"
  End
End If
' something in the data lot for the stages to read: 96 bytes, a letter each
For round = 0 To 95
  Reu.Poke Reu.LotBank(DATALOT), Reu.LotAddr(DATALOT) + round, 65 + (round Mod 26)
Next
Title.Show
For round = 1 To 3
  Game.SetRound round
  Stage1.Play
  Stage2.Play
Next
Title.Finish
End
