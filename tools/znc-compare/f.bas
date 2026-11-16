Option Explicit
Dim x As Integer, y As Integer, r As Integer, acc As Integer, i As Integer
Dim lx As Long, ly As Long, lr As Long, lacc As Long
Dim fx As Long, fy As Long, fr As Long
Fixed.SetPlaces 2
x = 350 : y = 125
lx = 350 : ly = 125
r = Fixed.Mul16(x, y) : lr = Fixed.Mul32(lx, ly)
fx = Float.FromText("3.5") : fy = Float.FromText("1.25") : fr = Float.Multiply(fx, fy)
Out &HFE, 1
For i = 1 To 2000 : r = Fixed.Mul16(x, y) : acc = acc + r : Next
Out &HFE, 2
For i = 1 To 2000 : r = Fixed.Div16(x, y) : acc = acc + r : Next
Out &HFE, 3
For i = 1 To 2000 : lr = Fixed.Mul32(lx, ly) : lacc = lacc + lr : Next
Out &HFE, 4
For i = 1 To 2000 : lr = Fixed.Div32(lx, ly) : lacc = lacc + lr : Next
Out &HFE, 5
x = 56 : y = 20
For i = 1 To 2000 : r = (CLng(x) * CLng(y)) \ 16 : acc = acc + r : Next
Out &HFE, 6
For i = 1 To 2000 : r = (CLng(x) * 16) \ CLng(y) : acc = acc + r : Next
Out &HFE, 7
For i = 1 To 2000 : fr = Float.Multiply(fx, fy) : Next
Out &HFE, 8
For i = 1 To 2000 : fr = Float.Divide(fx, fy) : Next
Out &HFE, 9
Print Fixed.Text16(Fixed.Mul16(350, 125)); " "; Fixed.Text16(Fixed.Div16(350, 125)); " "; Fixed.Text32(Fixed.Mul32(lx, ly)); " "; r; " "; Float.ToText(fr)
End
