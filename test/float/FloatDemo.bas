' FloatDemo: Float and Fixed side by side (add Float.cls and Fixed.cls to the project)
Option Explicit
Dim lngPi As Long, lngR As Long, lngArea As Long, intI As Integer
Dim lngPrice As Long, lngTotal As Long, intH As Integer

Print "Float (single):"
lngPi = Float.FromText("3.14159265")
For intI = 1 To 3
  lngR = Float.FromInt(intI * 10)
  lngArea = Float.Multiply(lngPi, Float.Multiply(lngR, lngR))
  Print "  radius "; intI * 10; " area "; Float.ToText(lngArea)
Next
Print "  1/3 = "; Float.ToText(Float.Divide(Float.FromInt(1), Float.FromInt(3)))
Print "  1E30 * 1E30 = "; Float.ToText(Float.Multiply(Float.FromText("1E30"), Float.FromText("1E30"))); "  overflow: "; Float.Overflow()

Print "Float (half):"
intH = Float.HFromText("1.5")
Print "  1.5 * 1.5 = "; Float.HToText(Float.HMultiply(intH, intH)); "  (bits &H"; Hex$(intH); ")"

Print "Fixed (32 bit, 2 places):"
Fixed.SetPlaces 2
lngPrice = Fixed.Val32("19.99")
lngTotal = Fixed.Mul32(lngPrice, Fixed.FromInt32(3))
Print "  3 x 19.99 = "; Fixed.Text32(lngTotal)
Print "  + 8% = "; Fixed.Text32(Fixed.Mul32(lngTotal, Fixed.Val32("1.08")))
Print "  / 7 = "; Fixed.Text32(Fixed.Div32(lngTotal, Fixed.FromInt32(7)))

Print "Matrix product (single), one call:"
Dim lngM(1, 1) As Long, lngQ(1, 1) As Long, intOk As Integer
lngM(0, 0) = Float.FromText("0.5") : lngM(0, 1) = Float.FromInt(2)
lngM(1, 0) = Float.FromInt(-1) : lngM(1, 1) = Float.FromText("1.5")
intOk = Float.MatMul(lngQ, lngM, lngM)
Print "  [0.5 2; -1 1.5]^2 = ["; Float.ToText(lngQ(0, 0)); " "; Float.ToText(lngQ(0, 1)); "; "; Float.ToText(lngQ(1, 0)); " "; Float.ToText(lngQ(1, 1)); "]"
Print "Integer arrays (Fixed with 0 places):"
Dim lngX(3) As Long, lngY(3) As Long
Fixed.SetPlaces 0
lngX(0) = 1 : lngX(1) = 2 : lngX(2) = 3 : lngX(3) = 4
Fixed.MScale32 lngY, lngX, 1000
Print "  x * 1000 = "; lngY(0); " "; lngY(3); "   dot(x, x) = "; Fixed.Dot32(lngX, lngX)
