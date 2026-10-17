' ZX CRAFT - step 1: the filled voxel renderer on its own. A 16 x 16 x 16 chunk of blocks drawn
' as filled faces (Starstrike II style) on Layer 2, front to back, every pixel written once.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' Keys: Q A forward / back, O P turn, K M look up / down, Space up, Z down. Left alone at the
' start it turns slowly round (any key stops that).
Option Explicit
Option Turbo

Dim cx As Integer, cy As Integer, cz As Integer, yaw As Integer, pitch As Integer
Dim loops As Integer, sp As Integer, demo As Integer
Dim t As Integer, t0 As Integer, l0 As Integer, fps10 As Integer

Nx.Border 0
Locate 4, 4 : Print "ZX CRAFT  STEP 1"
Locate 4, 27 : Print "QA MOVE  OP TURN  KM LOOK  SPC/Z UP"
Vox.Screen &HE3                   ' see-through outside the view (rows 0-15, 176-191: the text)
Vox.Load World.Base()
Vox.Colours World.Colours()
Vox.Build
cx = 14 * 256 : cy = 10 * 256 : cz = 2 * 256 : yaw = 216 : pitch = -12
demo = 1
t0 = Vox.Ticks()
Do
  sp = 0
  If Keys.Down(Keys.KeyQ) Then sp = 48 : demo = 0
  If Keys.Down(Keys.KeyA) Then sp = -48 : demo = 0
  If Keys.Down(Keys.KeyO) Then yaw = (yaw - 3) And 255 : demo = 0
  If Keys.Down(Keys.KeyP) Then yaw = (yaw + 3) And 255 : demo = 0
  If Keys.Down(Keys.KeyK) And pitch < 56 Then pitch = pitch + 3 : demo = 0
  If Keys.Down(Keys.KeyM) And pitch > -56 Then pitch = pitch - 3 : demo = 0
  If Keys.Down(Keys.KeySpace) And cy < 24 * 256 Then cy = cy + 32 : demo = 0
  If Keys.Down(Keys.KeyZ) And cy > 32 Then cy = cy - 32 : demo = 0
  If demo Then yaw = (yaw + 1) And 255
  If sp Then
    cx = cx + Vox.Sine(yaw) * sp / 128
    cz = cz + Vox.Sine(yaw + 64) * sp / 128
    If cx < -8 * 256 Then cx = -8 * 256
    If cx > 24 * 256 Then cx = 24 * 256
    If cz < -8 * 256 Then cz = -8 * 256
    If cz > 24 * 256 Then cz = 24 * 256
  End If
  Vox.Render cx, cy, cz, yaw, pitch, Vox.Page()
  Frame : Vox.Flip
  loops = loops + 1
  ' frames a second (in tenths), every second or so
  t = Vox.Ticks()
  If t - t0 >= 50 Then
    fps10 = (loops - l0) * 500 / (t - t0)
    Locate 26, 4 : Print fps10 \ 10; "."; fps10 Mod 10; " FPS "
    t0 = t : l0 = loops
  End If
Loop
