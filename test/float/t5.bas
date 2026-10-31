Dim intA As Integer, intB As Integer, lngA As Long, lngB As Long
Fixed.SetPlaces 2
intA = Fixed.Val16("12.34") : intB = Fixed.Val16("-0.5")
Print intA; " "; intB; " "; Fixed.Text16(Fixed.Mul16(intA, intB)); " "; Fixed.Text16(Fixed.Div16(intA, intB)); " "; Fixed.Text16(intA + intB)
Print Fixed.Text16(Fixed.Mul16(Fixed.Val16("300"), Fixed.Val16("2"))); " "; Fixed.Ok(); " "; Fixed.Text16(Fixed.FromInt16(5)); " "; Fixed.Round16(Fixed.Val16("2.5")); " "; Fixed.ToInt16(Fixed.Val16("-2.7"))
Fixed.SetPlaces 3
lngA = Fixed.Val32("1234.5678") : lngB = Fixed.Val32("-3.2")
Print lngA; " "; Fixed.Text32(Fixed.Mul32(lngA, lngB)); " "; Fixed.Text32(Fixed.Div32(lngA, lngB)); " "; Fixed.Ok()
Print Fixed.Text32(Fixed.Div32(Fixed.FromInt32(1), Fixed.FromInt32(3))); " "; Fixed.Text32(Fixed.Mul32(Fixed.Val32("2000000"), Fixed.Val32("2000"))); " "; Fixed.Ok()
Fixed.SetPlaces 5
Print Fixed.Text16(Fixed.FromInt16(1)); " "; Fixed.Ok(); " "; Fixed.Text32(Fixed.Val32("21474.83647")); " "; Fixed.Text32(Fixed.Add32(Fixed.Val32("21474"), Fixed.Val32("1"))); " "; Fixed.Ok()
Fixed.SetPlaces 2
Print Float.ToText(Fixed.Float32(Fixed.Val32("-12.34"))); " "; Fixed.Text32(Fixed.FromFloat32(Float.FromText("3.14159"))); " "; Fixed.Text16(Fixed.FromFloat16(Float.FromText("-1.005")))
