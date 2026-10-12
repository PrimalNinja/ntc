' CUBE3D: wireframe shapes turning in 3D - a cube, a pyramid and Elite's Cobra Mk III.
' Vector3D.cls does the maths and draws the lines (Z80); Spin.cls is the demo, an overlay
' class on cpcmin (SPIN.PAG in a RAM page - keep it on the disc with CUBE3D.BIN).
' cpc and cpcmin (they draw to the screen at #C000 themselves).
Option Explicit
#If NTC_CPCMIN Then
Option RomEnable 7                ' AMSDOS, for SPIN.PAG
Option Reserve &H4000, &H4000     ' out of the window the overlay runs in
#End If
Spin.Run
Cls
Print "Bye"
End
