Dim lngA(1, 2) As Long, lngB(2, 1) As Long, lngD(1, 1) As Long, lngV(2) As Long, lngW(2) As Long, lngS(2) As Long
Dim intI As Integer, intJ As Integer, intOk As Integer
For intI = 0 To 1
  For intJ = 0 To 2
    lngA(intI, intJ) = Float.FromInt(intI * 3 + intJ + 1)
    lngB(intJ, intI) = Float.FromInt(intJ * 2 + intI + 7)
  Next
Next
intOk = Float.MatMul(lngD, lngA, lngB)
Print intOk; " "; Float.ToText(lngD(0, 0)); " "; Float.ToText(lngD(0, 1)); " "; Float.ToText(lngD(1, 0)); " "; Float.ToText(lngD(1, 1))
For intI = 0 To 2
  lngV(intI) = Float.FromText("1.5") : lngW(intI) = Float.FromInt(intI + 1)
Next
Float.MAdd lngS, lngV, lngW
Print Float.ToText(lngS(0)); " "; Float.ToText(lngS(1)); " "; Float.ToText(lngS(2)); "  dot "; Float.ToText(Float.Dot(lngV, lngW))
Float.MScale lngS, lngW, Float.FromText("0.5")
Float.MDivide lngV, lngW, lngS
Print Float.ToText(lngS(2)); " "; Float.ToText(lngV(1)); " "; Float.MatMul(lngD, lngA, lngA)
