' MEM: the memory, in CyborgOS (build for cpm, with CybSys.cls): main RAM as a table, the map of
' the banks' 16K pages (32 a group, two groups a line), the totals
Option Explicit
Dim j As Integer, te As Integer, tp As Integer, pg As Integer, a As String Max 60
If CybSys.Ask(7, 0) = 255 Then Print "MEM: not in this CyborgOS" : End
te = CybSys.WordAt(2) : tp = CybSys.WordAt(4) : pg = CybSys.WordAt(6)
a = CybSys.TextAt(8)
Print "#0000-#003F  firmware restarts"
Print "#0040-#3FFF  CyborgOS"
Print "#4000-#7FFF  the window (the banks' pages); main RAM's own: kept, a 2nd screen"
Print "#8000-#"; H4(te - 1); "  CyborgOS, its arrays, the memory tables"
Print "#"; H4(te); "-#"; H4(tp - 1); "  free"
Print "#"; H4(tp); "-#BFFF  firmware and ROMs"
Print "#C000-#FFFF  screen"
Print
Print "Banks (B slot, U the hypervisor's: disc buffers, RAM discs; - free):"
For j = 2 To pg Step 64
  Print Map(j); "  "; Map(j + 32)
Next
Print
Print a

' 32 pages of the map from page p
Function Map(ByVal p As Integer) As String
  Dim r As Integer
  CybSys.SetWord 2, p
  r = CybSys.Ask(8, 0)
  Map = CybSys.TextAt(4)
End Function

' v as 4 hex digits
Function H4(ByVal v As Integer) As String
  H4 = Right$("000" + Hex$(v), 4)
End Function
