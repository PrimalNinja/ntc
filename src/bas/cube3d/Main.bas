' CUBE3D: wireframe shapes turning in 3D - a cube, a pyramid and Elite's Cobra Mk III, in
' screen mode 0, 1 or 2, on one screen or two (double buffering), in normal or turbo mode.
' Keys: 1-4 shape, A/B/C mode 0/1/2, D double buffering, T turbo, + - size, P pause, X exit.
' Vector3D.cls does the maths (Z80), the Graphics class draws; Spin.cls is the demo - an
' overlay class on cpcmin and cpcfw (SPIN.PAG in a RAM page: keep it on the disc with
' CUBE3D.BIN; needs a 6128). cpc, cpcmin and cpcfw.
Option Explicit
#If NTC_CPCMIN Then
Option RomEnable 7                ' AMSDOS, for SPIN.PAG
Option Reserve &H4000, &H4000     ' out of the window the overlay runs in
Dim scr As Integer
' main RAM's #4000 (page 1) is the second screen: take it before the overlay loads, so
' SPIN.PAG goes into another page
scr = Memory.AllocPage(Memory.TypeUser)
If scr <> 1 Then Print "Page 1 is taken - no double buffering" : End
#End If
#If NTC_CPCFW Then
Option RomEnable 7                ' AMSDOS, for SPIN.PAG
Option Reserve &H4000, &H4000     ' out of the window the overlay runs in
Dim scr As Integer
' main RAM's #4000 (page 1) is the second screen: take it before the overlay loads, so
' SPIN.PAG goes into another page
scr = Memory.AllocPage(Memory.TypeUser)
If scr <> 1 Then Print "Page 1 is taken - no double buffering" : End
#End If
Spin.Run
Mode 1
Print "Bye"
End
