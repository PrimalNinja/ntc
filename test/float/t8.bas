Dim lngA(1, 1) As Long, lngB(1, 1) As Long, lngD(1, 1) As Long
Dim intA(3) As Integer, intB(3) As Integer, intD(3) As Integer, intM(1, 1) As Integer, intN(1, 1) As Integer, intP(1, 1) As Integer
Dim intI As Integer, intOk As Integer
Fixed.SetPlaces 0
lngA(0, 0) = 2 : lngA(0, 1) = 3 : lngA(1, 0) = -4 : lngA(1, 1) = 5
lngB(0, 0) = 100000 : lngB(0, 1) = 1 : lngB(1, 0) = 7 : lngB(1, 1) = -2
intOk = Fixed.MatMul32(lngD, lngA, lngB)
Print "int: "; lngD(0, 0); " "; lngD(0, 1); " "; lngD(1, 0); " "; lngD(1, 1); "  dot "; Fixed.Dot32(lngA, lngB)
Fixed.SetPlaces 2
For intI = 0 To 3
  intA(intI) = Fixed.Val16("1.25") * (intI + 1) : intB(intI) = Fixed.Val16("0.5")
Next
Fixed.MMul16 intD, intA, intB
Print "16: "; Fixed.Text16(intD(0)); " "; Fixed.Text16(intD(3)); " ";
Fixed.MDiv16 intD, intA, intB
Print Fixed.Text16(intD(3)); " "; Fixed.Ok(); " ";
Fixed.MScale16 intD, intA, Fixed.Val16("300")
Print Fixed.Text16(intD(0)); " "; Fixed.Ok()
intM(0, 0) = Fixed.Val16("1.5") : intM(0, 1) = Fixed.Val16("-2") : intM(1, 0) = Fixed.Val16("0.25") : intM(1, 1) = Fixed.Val16("4")
intOk = Fixed.MatMul16(intP, intM, intM)
Print "m16: "; Fixed.Text16(intP(0, 0)); " "; Fixed.Text16(intP(0, 1)); " "; Fixed.Text16(intP(1, 0)); " "; Fixed.Text16(intP(1, 1)); " dot "; Fixed.Text16(Fixed.Dot16(intA, intB))
lngA(0, 0) = Fixed.Val32("19.99") : lngA(0, 1) = Fixed.Val32("5.25") : lngA(1, 0) = Fixed.Val32("-1") : lngA(1, 1) = Fixed.Val32("100")
Fixed.MOffset32 lngD, lngA, Fixed.Val32("0.01")
Print "32: "; Fixed.Text32(lngD(0, 0)); " "; Fixed.Text32(lngD(1, 0));
Fixed.MSub32 lngD, lngA, lngD
Print " "; Fixed.Text32(lngD(1, 1)); " "; Fixed.Ok()
