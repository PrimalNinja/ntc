' city test: the camera over the city, looking at it, turning slowly
Option Explicit
Option Turbo
Dim frames As Integer, r0 As Integer, ls As Integer
E3.Init
E3.ppos(0) = E3Data.PlanetX : E3.ppos(1) = E3Data.PlanetY : E3.ppos(2) = E3Data.PlanetZ : E3.prad = E3Data.PlanetR : E3.pcol = 3
' the site is (27028, -60813, 202709) at about; up (-0.127, 0.285, -0.950): the camera 600 up from it
E3.CamAt 0, 108, 140 : E3.CamAt 1, -245, 196 : E3.CamAt 2, 786, 142
E3.cm(0) = 14972 : E3.cm(1) = 6654 : E3.cm(2) = 0 : E3.cm(3) = -2076 : E3.cm(4) = 4670 : E3.cm(5) = -15567 : E3.cm(6) = -6322 : E3.cm(7) = 14225 : E3.cm(8) = 5110
E3.CamTurn -2500, 0, 0
Do
  r0 = Nx.Raster()
  E3.CamTurn 0, 0, 0
  E3.Begin 4 * 16 + 9
  E3.Planet
  E3.City
  ls = Nx.Raster() - r0
  If ls < 0 Then ls = ls + 311
  Frame
  E3.Flip
  frames = frames + 1
Loop
