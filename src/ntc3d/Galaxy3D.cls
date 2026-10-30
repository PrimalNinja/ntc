' Galaxy3D - NTC3D's wraparound galaxy: a cube of 2^bits cells a side (a cell is 256 world units: with
' 10 bits the cube is 262,144 units across, about 21 s at Fly3D's top speed) that wraps on all three
' axes. The engine's world is 16 bit (65536 units across, kept near the middle by Fly3D.Rebase), so
' the game keeps WHERE THINGS ARE in cells and only what's near you (a hundred cells or so) as
' objects in local units: x * 256. This class keeps the cell the local frame's middle is at (gx, gy,
' gz) as Rebase moves the world, and does the wrapping sums.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'   Galaxy3D.Init 10 : Galaxy3D.At 100, 200, 300          ' the cube, you in it
'   k = Galaxy3D.Rebase()                                 ' instead of Fly3D.Rebase each picture
'   d = Galaxy3D.Rel(px, py, pz)                          ' a planet's cell: dx, dy, dz and how far
'   If Galaxy3D.Near(100) Then ...                        ' (all of dx, dy, dz within 100 cells)
'   Obj3D.Spawn kind, size, cls, Galaxy3D.dx * 256, Galaxy3D.dy * 256, Galaxy3D.dz * 256, c
Option Explicit

Public gx As Integer, gy As Integer, gz As Integer     ' the cell at the local frame's middle (0 .. mask)
Public mask As Integer, half As Integer                ' 2^bits - 1, 2^bits / 2
Public dx As Integer, dy As Integer, dz As Integer     ' Rel: a cell's offset from the middle, in cells (- half .. half - 1)

' Init bits: the cube 2^bits cells a side (up to 11: the offsets must stay 16 bit as local units / 256 allow)
Public Sub Init(ByVal bits As Integer)
  mask = 1
  Do While bits > 0
    mask = mask * 2 : bits = bits - 1
  Loop
  half = mask \ 2 : mask = mask - 1
  gx = 0 : gy = 0 : gz = 0
End Sub

' Wrap(d): a difference of cells brought into - half .. half - 1 (the short way round)
Public Function Wrap(ByVal d As Integer) As Integer
  Wrap = ((d + half) And mask) - half
End Function

' Rel(x, y, z): a cell's offset from the middle into dx, dy, dz; the sum of their sizes (how far)
Public Function Rel(ByVal x As Integer, ByVal y As Integer, ByVal z As Integer) As Integer
  dx = Wrap(x - gx) : dy = Wrap(y - gy) : dz = Wrap(z - gz)
  Rel = Abs(dx) + Abs(dy) + Abs(dz)
End Function

' Near(r): 1 when the cell last given to Rel is within r cells on every axis (r 127 at most: local units x 256 are 16 bit)
Public Function Near(ByVal r As Integer) As Integer
  Near = 0
  If Abs(dx) <= r And Abs(dy) <= r And Abs(dz) <= r Then Near = 1
End Function

' At x, y, z: you're in that cell: the camera at the local middle, no objects moved (Obj3D.Clear first)
Public Sub At(ByVal x As Integer, ByVal y As Integer, ByVal z As Integer)
  gx = x And mask : gy = y And mask : gz = z And mask
  E3.CamPos 0, 0, 0
  Fly3D.GetCam
End Sub

' Rebase(): Fly3D.Rebase, and the middle's cell follows it. 1 when it moved
Public Function Rebase() As Integer
  Rebase = Fly3D.Rebase()
  If Rebase Then
    gx = (gx + Fly3D.dx \ 256) And mask : gy = (gy + Fly3D.dy \ 256) And mask : gz = (gz + Fly3D.dz \ 256) And mask
  End If
End Function
