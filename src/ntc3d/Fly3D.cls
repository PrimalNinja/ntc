' Fly3D - NTC3D's flying: the camera flown from a set of control bits. Roll and pitch build up
' while a control's held and ease off when it's let go, the speed goes up and down, the camera's
' turned and moved, and Obj3D is told your speed and your (lagging) way ahead. Rebase keeps the
' 16 bit world near the middle.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Option Explicit

' the controls (Steer's keys): any you like may come from the keys, a stick or the game itself
Public Const K_DIVE = 1, K_CLIMB = 2, K_ROLLL = 4, K_ROLLR = 8, K_FASTER = 16, K_SLOWER = 32
' assist: 0 none; 1 a run along the world's +z (a bank turns you, the nose comes back round to
' +z and the wings level when roll's let go); 2 as 1, and the pitch levels too, the roll limited
' (a trench)
Public Const AS_NONE = 0, AS_RUN = 1, AS_TRENCH = 2
' (NEW) Drive's controls: a ground vehicle (the same bits as K_DIVE .. K_ROLLR)                  ' <--- NEW
Public Const K_FWD = 1, K_BACK = 2, K_LEFT = 4, K_RIGHT = 8                       ' <--- NEW

Public rmax As Integer, pmax As Integer          ' the roll and pitch rates held (16384ths of a radian a 50th)
Public ease As Integer                           ' how slowly they build and ease (5: about a tenth of a second)
Public acc As Integer                            ' the speed's change a 50th held
Public smin As Integer, smax As Integer, spd As Integer   ' the speed: least, most, now (a 50th's move x 16)
Public assist As Integer
Public tmax As Integer                           ' (NEW) Drive: the turn rate held (16384ths of a radian a 50th)   ' <--- NEW
Public cx As Integer, cy As Integer, cz As Integer   ' where the camera is (GetCam)
Public rlim As Integer, rbx As Integer, rby As Integer, rbz As Integer   ' Rebase: past rlim, which ways
Public dx As Integer, dy As Integer, dz As Integer   ' Rebase: how far it moved everything back
Private rr As Integer, pr As Integer, t As Integer

' Init: the settings to their starting values (the camera as it is)
Public Sub Init()
  rmax = 380 : pmax = 280 : ease = 5 : acc = 50 : smin = 400 : smax = 4000 : spd = 1600
  assist = AS_NONE : rlim = 8000 : rbx = 1 : rby = 1 : rbz = 1 : tmax = 300      ' <--- CHANGED
  Reset
End Sub

' Reset: no roll or pitch going on; your way ahead is where the camera looks now
Public Sub Reset()
  rr = 0 : pr = 0
  Obj3D.hfx = E3.cm(6) : Obj3D.hfy = E3.cm(7) : Obj3D.hfz = E3.cm(8)
  GetCam
End Sub

' GetCam: cx, cy, cz from the camera
Public Sub GetCam()
  cx = E3.CamGet(0) : cy = E3.CamGet(1) : cz = E3.CamGet(2)
End Sub

' Steer keys, dt: dt 50ths of flying with the controls in keys (K_ bits)
Public Sub Steer(ByVal keys As Integer, ByVal dt As Integer)
  Dim tr As Integer, tp As Integer, rl As Integer, pt As Integer, yw As Integer
  tr = 0 : tp = 0
  If keys And K_ROLLL Then tr = -rmax
  If keys And K_ROLLR Then tr = rmax
  If keys And K_DIVE Then tp = -pmax
  If keys And K_CLIMB Then tp = pmax
  rr = rr + (tr - rr) * dt \ ease
  pr = pr + (tp - pr) * dt \ ease
  If Abs(rr) < 8 Then rr = 0
  If Abs(pr) < 8 Then pr = 0
  rl = rr : pt = pr : yw = 0
  If assist Then
    yw = -E3.cm(1) \ 40 - E3.cm(6) \ 20
    If tr = 0 Then rl = rl + E3.cm(1) \ 24
    If assist = AS_TRENCH Then
      If tp = 0 Then pt = pt - E3.cm(7) \ 12
      If E3.cm(1) < -9000 And rl > 0 Then rl = 0
      If E3.cm(1) > 9000 And rl < 0 Then rl = 0
    End If
    If yw > 400 Then yw = 400
    If yw < -400 Then yw = -400
  End If
  E3.CamTurn pt * dt, yw * dt, rl * dt
  If keys And K_FASTER Then spd = spd + acc * dt
  If keys And K_SLOWER Then spd = spd - acc * dt
  If spd < smin Then spd = smin
  If spd > smax Then spd = smax
  E3.CamMove spd * dt
  GetCam
  Track dt                                                                      ' <--- CHANGED (moved into Track: Drive does it too)
End Sub

' Drive keys, dt: (NEW) a ground vehicle for dt 50ths: K_LEFT / K_RIGHT turn it (building up and      ' <--- NEW
' easing off as roll does), K_FWD / K_BACK drive it (up to smax ahead, smax / 2 back; it rolls to a  ' <--- NEW
' stop with neither); no roll or pitch: the camera's kept level. The height is yours (E3.CamPos)    ' <--- NEW
Public Sub Drive(ByVal keys As Integer, ByVal dt As Integer)                     ' <--- NEW
  Dim ty As Integer                                                             ' <--- NEW
  ty = 0                                                                        ' <--- NEW
  If keys And K_LEFT Then ty = -tmax                                            ' <--- NEW
  If keys And K_RIGHT Then ty = tmax                                            ' <--- NEW
  rr = rr + (ty - rr) * dt \ ease                                               ' <--- NEW
  If Abs(rr) < 8 Then rr = 0                                                    ' <--- NEW
  E3.CamTurn -E3.cm(7) \ 4, rr * dt, E3.cm(1) \ 4                               ' <--- NEW (any tilt put back: level)
  If keys And K_FWD Then                                                        ' <--- NEW
    spd = spd + acc * dt                                                        ' <--- NEW
    If spd > smax Then spd = smax                                               ' <--- NEW
  ElseIf keys And K_BACK Then                                                   ' <--- NEW
    spd = spd - acc * dt                                                        ' <--- NEW
    If spd < -smax \ 2 Then spd = -smax \ 2                                     ' <--- NEW
  Else                                                                          ' <--- NEW
    t = acc * dt                                                                ' <--- NEW (rolling to a stop)
    If spd > t Then                                                             ' <--- NEW
      spd = spd - t                                                             ' <--- NEW
    ElseIf spd < -t Then                                                        ' <--- NEW
      spd = spd + t                                                             ' <--- NEW
    Else                                                                        ' <--- NEW
      spd = 0                                                                   ' <--- NEW
    End If                                                                      ' <--- NEW
  End If                                                                        ' <--- NEW
  E3.CamMove spd * dt                                                           ' <--- NEW
  GetCam                                                                        ' <--- NEW
  Track dt                                                                      ' <--- NEW
End Sub                                                                         ' <--- NEW

' Track dt: (NEW) your speed in the world (a 50th's move: forward x spd / 16) and your way ahead,   ' <--- CHANGED
' lagging (catching up over a second or so) into Obj3D: the station keepers' movers use them
Private Sub Track(ByVal dt As Integer)                                           ' <--- NEW
  Obj3D.pvx = (E3.cm(6) \ 64) * (spd \ 64) \ 64
  Obj3D.pvy = (E3.cm(7) \ 64) * (spd \ 64) \ 64
  Obj3D.pvz = (E3.cm(8) \ 64) * (spd \ 64) \ 64
  Obj3D.hfx = Obj3D.hfx + (E3.cm(6) - Obj3D.hfx) \ 64 * dt
  Obj3D.hfy = Obj3D.hfy + (E3.cm(7) - Obj3D.hfy) \ 64 * dt
  Obj3D.hfz = Obj3D.hfz + (E3.cm(8) - Obj3D.hfz) \ 64 * dt
End Sub

' Rebase(): when the camera's past rlim from the middle on a way that's on (rbx, rby, rbz), it and
' every object (and E3's planet) are moved back by whole 256s: dx, dy, dz say how far (move your own
' world numbers by them too). 1 when it moved, else 0
Public Function Rebase() As Integer
  dx = 0 : dy = 0 : dz = 0 : Rebase = 0
  If rbx And Abs(cx) > rlim Then dx = (cx \ 256) * 256
  If rby And Abs(cy) > rlim Then dy = (cy \ 256) * 256
  If rbz And Abs(cz) > rlim Then dz = (cz \ 256) * 256
  If dx = 0 And dy = 0 And dz = 0 Then Exit Function
  E3.CamPos cx - dx, cy - dy, cz - dz
  E3.ppos(0) = E3.ppos(0) - dx \ 256 : E3.ppos(1) = E3.ppos(1) - dy \ 256 : E3.ppos(2) = E3.ppos(2) - dz \ 256
  Obj3D.Shift dx, dy, dz
  GetCam
  Rebase = 1
End Function
