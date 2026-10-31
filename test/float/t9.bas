Dim lngR(2, 2) As Long, intM(2, 2) As Integer, lngP(2) As Long, lngQ(2) As Long, intI As Integer
Print Float.ToBinScaled(Float.FromText("0.5"), 14); " "; Float.ToBinScaled(Float.FromText("-0.75"), 14); " "; Float.ToBinScaled(Float.FromText("123.45"), 8); " "; Float.ToText(Float.FromBinScaled(8192, 14)); " "; Float.ToText(Float.FromBinScaled(-31604, 8))
lngR(0, 0) = Float.FromText("0.8660254") : lngR(0, 1) = 0 : lngR(0, 2) = Float.FromText("0.5")
lngR(1, 0) = 0 : lngR(1, 1) = Float.FromInt(1) : lngR(1, 2) = 0
lngR(2, 0) = Float.FromText("-0.5") : lngR(2, 1) = 0 : lngR(2, 2) = Float.FromText("0.8660254")
Float.MToBinScaled intM, lngR, 14
Print intM(0, 0); " "; intM(0, 2); " "; intM(1, 1); " "; intM(2, 0); " "; intM(2, 2); " "; Float.Overflow()
Float.MToBinScaled intM, lngR, 7
Print intM(0, 0); " "; intM(0, 2); " "; intM(1, 1); " "; intM(2, 0)
lngP(0) = Float.FromText("1000.5") : lngP(1) = Float.FromText("-2.25") : lngP(2) = Float.FromText("3")
Float.MToBinScaledL lngQ, lngP, 8
Print lngQ(0); " "; lngQ(1); " "; lngQ(2); " ";
lngR(0, 0) = Float.FromText("2.5")
Float.MToBinScaled intM, lngR, 14
Print intM(0, 0); " "; Float.Overflow()
