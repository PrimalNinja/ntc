' POLY - a polygon engine for the ZX Spectrum Next: fly through an asteroid field to a planet and
' down to a city on it. (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' A demo: the keys are ignored and the autopilot flies the whole loop - the asteroids, the planet,
' down to the city, across it, up and back. (Fly reads none; Ctl.cls, the keys it had, is kept.)
Option Explicit
Option Turbo

Const NA = 28                            ' the asteroids
Const HUD = 15 * 16 + 13                 ' the panel's colour

Dim k As Integer, kd As Integer, sc As Integer
Dim speed As Integer, smax As Integer, keys As Integer, idle As Integer, auto As Integer
Dim pt As Integer, yw As Integer, rl As Integer, wp As Integer, wps As Integer
Dim vx As Integer, vy As Integer, vz As Integer, mx As Integer
Dim sky As Integer, alt As Integer, frames As Integer, blink As Integer
' the autopilot's way: points (world / 256), how fast, how near is there (aimk 0 and under this)
Dim wx(7) As Integer, wy(7) As Integer, wz(7) As Integer, ws(7) As Integer, wr(7) As Integer

E3.Init
SetUp
Do
  Fly
  E3.CamTurn pt, yw, rl
  E3.CamMove speed
  ' the sky: black in space, blue lower down (from the last frame's height)
  alt = E3.palt
  sky = 0
  If alt < 24000 Then sky = 4 * 16 + (24000 - alt) \ 2400
  If sky > 4 * 16 + 9 Then sky = 4 * 16 + 9
  E3.Begin sky
  If sky < 4 * 16 + 3 Then E3.Stars
  E3.Planet
  E3.City
  E3.Scene
  Panel
  Frame
  E3.Flip
  frames = frames + 1
Loop

' SetUp: the asteroids, the planet, the camera at the start, the autopilot's way
Sub SetUp()
  For k = 0 To NA - 1
    sc = 1 + Rnd(3) : kd = k And 3
    E3.ObjSet k, Rnd(10000) - 5000, Rnd(5000) - 2500, Rnd(14000), kd, sc, 130 * Pow2(sc), Rnd(5) - 2, Rnd(5) - 2, 8 + 16 * (kd And 1)
  Next
  E3.nobj = NA
  E3.ppos(0) = E3Data.PlanetX : E3.ppos(1) = E3Data.PlanetY : E3.ppos(2) = E3Data.PlanetZ
  E3.prad = E3Data.PlanetR : E3.pcol = 2
  E3.CamPos 0, 0, -3000
  speed = 2000
  ' the way: through the asteroids, to the city, across it low, up, back
  Way 0, 6, 2, 20, 3000, 12
  Way 1, -10, -4, 40, 3000, 12
  Way 2, 104, -233, 777, 32000, 6
  Way 3, 110, -247, 787, 1400, 6
  Way 4, 101, -227, 795, 1200, 6
  Way 5, 86, -193, 643, 24000, 30
  Way 6, 0, 0, -8, 32000, 20
  wps = 7 : wp = 0 : auto = 1
End Sub

Sub Way(ByVal n As Integer, ByVal x As Integer, ByVal y As Integer, ByVal z As Integer, ByVal s As Integer, ByVal r As Integer)
  wx(n) = x : wy(n) = y : wz(n) = z : ws(n) = s : wr(n) = r
End Sub

' Fly: the keys (or the autopilot) to the turns (pt, yw, rl) and the speed
Sub Fly()
  keys = 0                               ' the keys are ignored: it's a demo, flown by the autopilot (flying it
                                         ' by hand into the planet could crash it)
  pt = 0 : yw = 0 : rl = 0
  If keys = Ctl.Auto Then
    auto = 1 : idle = 0
  ElseIf keys <> 0 Then
    auto = 0 : idle = 0
  Else
    idle = idle + 1
    If idle > 400 Then auto = 1
  End If
  If auto <> 0 Then
    Autopilot
  Else
    If keys And Ctl.Dive Then pt = -260
    If keys And Ctl.Climb Then pt = 260
    If keys And Ctl.RollL Then rl = -320
    If keys And Ctl.RollR Then rl = 320
    If keys And Ctl.YawL Then yw = -220
    If keys And Ctl.YawR Then yw = 220
    If keys And Ctl.Faster Then speed = speed + speed \ 16 + 40
    If keys And Ctl.Slower Then speed = speed - speed \ 16 - 40
    ' in the air a bank turns you
    If E3.palt < 20000 Then yw = yw - E3.pup(0) \ 48
  End If
  ' slower near the ground: you come down gently; never into it
  If speed < 0 Then speed = 0
  If speed > 32000 Then speed = 32000
  If E3.palt < 15000 Then
    smax = 300 + E3.palt * 2
    If speed > smax Then speed = smax
  End If
  If E3.palt < 40 And pt < 300 Then pt = 300
End Sub

' Autopilot: toward the way's point wp, levelled to the planet; on to the next when there
Sub Autopilot()
  E3.aimp(0) = wx(wp) : E3.aimp(1) = wy(wp) : E3.aimp(2) = wz(wp)
  E3.Aim
  vx = E3.aimv(0) : vy = E3.aimv(1) : vz = E3.aimv(2)
  ' (-32768 has no positive: kept off it, or Abs gives -32768 and the doubling below never ends)
  If vx = -32768 Then vx = -32767
  If vy = -32768 Then vy = -32767
  If vz = -32768 Then vz = -32767
  mx = Abs(vx)
  If Abs(vy) > mx Then mx = Abs(vy)
  If Abs(vz) > mx Then mx = Abs(vz)
  If E3.aimk = 0 And mx < wr(wp) * 256 Then
    wp = wp + 1
    If wp >= wps Then wp = 0
    Exit Sub
  End If
  If mx > 0 Then
    Do While mx > 0 And mx < 8192
      vx = vx * 2 : vy = vy * 2 : vz = vz * 2 : mx = mx * 2
    Loop
  End If
  yw = vx \ 12 : pt = vy \ 12
  If vz < 0 Then
    If vx < 0 Then yw = -700 Else yw = 700
  End If
  ' over the city (its way points): hold 300 up, nose level, not at the point's height
  If wp >= 3 And wp <= 4 And E3.palt < 3000 Then
    mx = (300 - E3.palt) * 4
    If mx > 3000 Then mx = 3000
    If mx < -3000 Then mx = -3000
    pt = (mx - E3.pup(2)) \ 6
  End If
  If yw > 700 Then yw = 700
  If yw < -700 Then yw = -700
  If pt > 500 Then pt = 500
  If pt < -500 Then pt = -500
  rl = E3.pup(0) \ 12
  If rl > 600 Then rl = 600
  If rl < -600 Then rl = -600
  ' (slower while turning hard)
  smax = ws(wp)
  If vz < Abs(vx) * 2 Or vz < Abs(vy) * 2 Then smax = smax \ 2
  If speed < smax Then speed = speed + speed \ 16 + 40
  If speed > smax Then speed = speed - speed \ 8 - 40
End Sub

' Panel: the speed, the height, the autopilot
Sub Panel()
  E3.Text 4, 3, "SPD", HUD
  E3.Num 26, 3, speed \ 16, 4, HUD
  If E3.palt < 32767 Then
    E3.Text 182, 3, "ALT", HUD
    E3.Num 204, 3, E3.palt, 5, HUD
  End If
  If auto <> 0 Then
    blink = blink + 1
    If blink And 8 Then E3.Text 101, 182, "AUTOPILOT", HUD
  End If
End Sub

Function Pow2(ByVal n As Integer) As Integer
  Pow2 = 1
  Do While n > 0
    Pow2 = Pow2 * 2 : n = n - 1
  Loop
End Function
