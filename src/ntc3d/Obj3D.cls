' Obj3D - NTC3D's objects: a table of up to 32 things in the world, each moved by itself every
' frame (in Z80) by its mover, tested for hits against the things its mask says it cares about,
' and drawn through E3 - so a game's BASIC only says what's what and answers what happened.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' An object (slot 0 .. NOBJ - 1): a model kind (E3Data's K_ constants) at a size (a model unit is
' 2^size world units), where it is (E3.obj: Pos / Move), its speed a 50th (ovx, ovy, ovz), its
' class (ocls: 0 = a free slot; CL_ constants, or your own 7 - 15) and its mask (omask: one bit per
' class it hits - bit c is 2^c, CL_PLAYER's bit is the camera), its hit box (ohw across and along,
' ohh up: half sizes, world units; the model's own from the model tool, times its size), its mover
' (omv, MV_ constants) with the mover's state (ost), timer (otm) and settings (opa, opb, ospd,
' odist: what each means is the mover's), flags (oflg, OF_ constants), a life (olife: 50ths to
' go, it's taken out at 0; 0 = for ever), a gun (ogun: 50ths till it's ready; ready with you in
' front of it, 700 - 8500 ahead: an EV_FIRE event), and two numbers of yours (otype, ouv).
'
' Each frame: Update dt (the 50ths gone) moves everything, then finds the hits and puts every
' happening on a queue the game reads with NextEvent; Draw draws them all (after the background).
' Update needs the camera's speed (pvx, pvy, pvz: a 50th's move, world units) and its lagging
' way ahead (hfx, hfy, hfz, s1.14) for the movers that keep station in front of you: Fly3D.Steer
' keeps them, or set them yourself.
Option Explicit

Public Const NOBJ = 32                           ' objects: 32, or game.json's nobj (the build sets it, E3's tables too)   ' @nobj   ' <--- CHANGED

' classes (ocls) and their mask bits (2 ^ class)
Public Const CL_PLAYER = 1, CL_ENEMY = 2, CL_EBOLT = 3, CL_PBOLT = 4, CL_SCENERY = 5, CL_DEBRIS = 6
Public Const M_PLAYER = 2, M_ENEMY = 4, M_EBOLT = 8, M_PBOLT = 16, M_SCENERY = 32, M_DEBRIS = 64

' movers (omv)
Public Const MV_STILL = 0       ' stays put (its spin still turns it)
Public Const MV_STRAIGHT = 1    ' on by its speed
Public Const MV_FALL = 2        ' on by its speed, the speed down growing by opa a 50th (debris)
Public Const MV_BLAST = 3       ' a fireball: still, one size bigger for its last 8 50ths of life
Public Const MV_HOLD = 4        ' keeps station ahead of you, weaving: odist ahead, opa across, opb
                                ' up (world x, y); held otm 50ths, then a run in (to 1500 ahead),
                                ' a break off up and out (5000 ahead), and back (ost: 0, 1, 2)
Public Const MV_HOLDONLY = 5    ' as MV_HOLD but never runs in (a big ship: always on station)
Public Const MV_CHARGE = 6      ' straight at you; within 2500 it goes on through (MV_PASS)
Public Const MV_PASS = 7        ' on through, facing its way; taken out 3000 behind you
Public Const MV_TURN = 8        ' turns after you and keeps after you, odist ahead of you (opa
                                ' across, opb up: 0s and it comes right at you)
Public Const MV_WEAVE = 9       ' on by its speed, swaying: opa across, opb up (amounts)
Public Const MV_ORBIT = 10      ' round (opa, opb) (world x, z) at odist, ospd 256ths of a turn a
                                ' second (its height stays)
' (NEW) on the ground (x and z only: its height stays), steered at up to opa a 50th each way,      ' <--- NEW
' turning to look along its way (or at you when it stands)                                       ' <--- NEW
Public Const MV_CIRCLE = 11     ' round you at odist, ospd 256ths of a turn a second (- the other   ' <--- NEW
                                ' way), looking at you: strafing                                 ' <--- NEW
Public Const MV_HUNT = 12       ' drives at you till it's odist off, then creeps round you facing you; every   ' <--- NEW
                                ' 3 s or so it falls back behind object opb (cover: -1 none) for   ' <--- NEW
                                ' 2 s (ost 0: hunting, 1: in cover)                              ' <--- NEW
Public Const MV_HOME = 13       ' homes in on you (in 3D: a missile), up to opa a 50th each way   ' <--- NEW
' (MV_HOLD .. MV_TURN: ospd is how much faster than you it may go, a 50th)

' flags (oflg)
Public Const OF_BEHIND = 1      ' taken out when 2500 behind you along the world's z (a run)
Public Const OF_WRAP = 2        ' put back 9000 ahead of you (at opa, opb) when 14000 away
Public Const OF_FACECAM = 4     ' turned to look at you
Public Const OF_FACEVEL = 8     ' turned to look along its way
Public Const OF_LAND = 16       ' (NEW) on reaching the ground (y down to gy): stopped there, an   ' <--- NEW
                                ' EV_LAND event, the flag cleared (a shell, a bomb)              ' <--- NEW
Public Const OF_GUNANY = 32     ' (NEW) its gun's ready with you anywhere within 8500 (not only   ' <--- NEW
                                ' in front of you: on the ground they come from all round)      ' <--- NEW

' events (NextEvent)
Public Const EV_FIRE = 1        ' ea's gun is ready, you're in front of it (re-arm: ogun(ea) = n)
Public Const EV_HIT = 2         ' ea hit eb (eb 255: you - the camera passed through it)
Public Const EV_LAND = 3        ' (NEW) ea (OF_LAND) has come down to the ground                  ' <--- NEW

Public ocls(31) As Integer, omask(31) As Integer, omv(31) As Integer, oflg(31) As Integer   ' @objarr   ' <--- CHANGED (the build sets the size: game.json nobj)
Public ost(31) As Integer, otm(31) As Integer, olife(31) As Integer, ogun(31) As Integer   ' @objarr   ' <--- CHANGED (the build sets the size: game.json nobj)
Public otype(31) As Integer, ouv(31) As Integer   ' @objarr   ' <--- CHANGED (the build sets the size: game.json nobj)
Public ovx(31) As Integer, ovy(31) As Integer, ovz(31) As Integer   ' @objarr   ' <--- CHANGED (the build sets the size: game.json nobj)
Public opa(31) As Integer, opb(31) As Integer, ospd(31) As Integer, odist(31) As Integer   ' @objarr   ' <--- CHANGED (the build sets the size: game.json nobj)
Public ohw(31) As Integer, ohh(31) As Integer   ' @objarr   ' <--- CHANGED (the build sets the size: game.json nobj)
Private olz(31) As Integer                       ' its view z last frame (passing through you)   ' @objarr   ' <--- CHANGED

Public pvx As Integer, pvy As Integer, pvz As Integer   ' your speed (a 50th's move)
Public hfx As Integer, hfy As Integer, hfz As Integer   ' your way ahead, lagging (s1.14)
Public lo As Integer, hi As Integer              ' Spawn takes the first free slot in lo .. hi - 1
Public gy As Integer                             ' (NEW) the ground's height for OF_LAND   ' <--- NEW
Public ea As Integer, eb As Integer              ' NextEvent: the objects
Public px As Integer, py As Integer, pz As Integer   ' Pos: where it is
Public avx As Integer, avy As Integer, avz As Integer   ' Aim's speed
Public pky As Integer                            ' (NEW) Pick: the gun's line up the view, 128ths of z (0: straight ahead; a gun raised)   ' <--- NEW
' bolts, debris and fireballs: their models (BoltModel, DebrisModel, BlastModel)
Public bkind As Integer, bsc As Integer, bdot As Integer, blife As Integer, pmask As Integer
Public dkind As Integer, dsc As Integer, ddot As Integer, dgrav As Integer
Public dflg As Integer                           ' (NEW) Burst's debris's flags (OF_LAND: they come down and lie on the ground)   ' <--- NEW
Public xkind As Integer, xdot As Integer
Private evq(31) As Integer, evb(31) As Integer, nev As Integer, rdq As Integer
Private pobj As Integer, pvwx As Integer, pvwy As Integer, pvwz As Integer, pcp As Integer
Private sps As Integer, six As Integer, t As Integer

' Init: after E3.Init - every slot free, the bolts' and the debris's models unset
Public Sub Init()
  pobj = VarPtr(E3.obj) : pcp = VarPtr(E3.cp)
  pvwx = VarPtr(E3.vwx) : pvwy = VarPtr(E3.vwy) : pvwz = VarPtr(E3.vwz)
  hfx = 0 : hfy = 0 : hfz = 16384 : lo = 0 : hi = NOBJ
  bkind = -1 : dkind = -1 : xkind = -1 : blife = 120 : pmask = M_ENEMY + M_SCENERY
  Lib
  Clear
End Sub

' Clear: every object taken out, the events forgotten
Public Sub Clear()
  For t = 0 To NOBJ - 1
    Kill t
  Next
  nev = 0 : rdq = 0
End Sub

' Kill i: object i taken out (its slot free)
Public Sub Kill(ByVal i As Integer)
  ocls(i) = 0
  E3.obj(i * 8 + 5) = 255
End Sub

' Spawn(kind, size, class, x, y, z, dot): a new object in the first free slot of lo .. hi - 1 (-1:
' none free). Its mover MV_STILL, no speed, flags, mask, life or gun; its hit box and radius from
' the model; dot: its colour when it's too small to draw (a dot)
Public Function Spawn(ByVal kind As Integer, ByVal sc As Integer, ByVal cls As Integer, ByVal x As Integer, ByVal y As Integer, ByVal z As Integer, ByVal dot As Integer) As Integer
#asm
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ld hl, -1
            ld ({t}), hl
            ld a, ({lo})            ; the first free slot
            ld b, a
            ld a, ({hi})
            sub b
            jp z, sp_end
            jp c, sp_end
            ld c, a
            ld a, b
            ld (fn_obj3d_lib_o3_i), a
sp_find:
            call fn_obj3d_lib_o3_cur
            ld hl, {ocls}
            call fn_obj3d_lib_o3_rdw
            ld a, h
            or l
            jr z, sp_got
            ld hl, fn_obj3d_lib_o3_i
            inc (hl)
            dec c
            jr nz, sp_find
            jp sp_end
sp_got:
            call fn_obj3d_lib_o3_zero   ; every one of its numbers 0
; @if ground
            ld bc, #7FFF                ; <--- NEW (its view z last frame: none yet - no hit on
            ld hl, {olz}                ; <--- NEW  its first frame from the either-way test)
            call fn_obj3d_lib_o3_wrw    ; <--- NEW
; @end
            ld bc, ({cls})
            ld hl, {ocls}
            call fn_obj3d_lib_o3_wrw
            call fn_obj3d_lib_o3_objp   ; its scene record: x, y, z, no turns or spins, kind, size
            ld de, ({x})
            ld (hl), e
            inc hl
            ld (hl), d
            inc hl
            ld de, ({y})
            ld (hl), e
            inc hl
            ld (hl), d
            inc hl
            ld de, ({z})
            ld (hl), e
            inc hl
            ld (hl), d
            inc hl
            xor a
            ld b, 4
sp_z4:
            ld (hl), a
            inc hl
            djnz sp_z4
            ld a, ({kind})
            ld (hl), a
            inc hl
            ld a, ({sc})
            and 7
            ld (sp_s), a
            ld (hl), a
            inc hl
            push hl
            ld a, ({kind})          ; the radius: the near model's (its byte 2) x 2^size
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            ld de, d_modeltab
            add hl, de
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld hl, d_modeldata + 2
            add hl, de
            ld l, (hl)
            ld h, 0
            call sp_sh
            ex de, hl
            pop hl
            ld (hl), e
            inc hl
            ld (hl), d
            inc hl
            ld a, ({dot})           ; the dot's colour, no scanner colour
            ld (hl), a
            inc hl
            ld (hl), 0
            ld a, ({kind})          ; the hit box: the model's (d_hittab: across, up) x 2^size
            ld l, a
            ld h, 0
            add hl, hl
            ld de, d_hittab
            add hl, de
            ld a, (hl)
            inc hl
            push hl
            ld l, a
            ld h, 0
            call sp_sh
            ld b, h
            ld c, l
            ld hl, {ohw}
            call fn_obj3d_lib_o3_wrw
            pop hl
            ld l, (hl)
            ld h, 0
            call sp_sh
            ld b, h
            ld c, l
            ld hl, {ohh}
            call fn_obj3d_lib_o3_wrw
            ld hl, ({pvwz})         ; not in the view till ViewAll sees it
            ld de, (fn_obj3d_lib_o3_o)
            add hl, de
            ld (hl), 0
            inc hl
            ld (hl), #80
            ld a, (fn_obj3d_lib_o3_i)
            ld ({t}), a
            xor a
            ld ({t} + 1), a
            jp sp_end
sp_sh:                              ; HL x 2^size
            ld a, (sp_s)
            or a
            ret z
            ld b, a
sp_shl:
            add hl, hl
            djnz sp_shl
            ret
sp_s:       db 0
sp_end:
            ld sp, ({sps})
#endasm
  Spawn = t
End Function

' SetVel i, vx, vy, vz: its speed (a 50th's move)
Public Sub SetVel(ByVal i As Integer, ByVal vx As Integer, ByVal vy As Integer, ByVal vz As Integer)
  ovx(i) = vx : ovy(i) = vy : ovz(i) = vz
End Sub

' SetMover i, mover, flags: what moves it (its state and timer back to 0)
Public Sub SetMover(ByVal i As Integer, ByVal mv As Integer, ByVal flg As Integer)
  omv(i) = mv : oflg(i) = flg : ost(i) = 0 : otm(i) = 0
End Sub

' Hold i, dist, across, up, faster, hold: (MV_HOLD) the station it keeps and how long it holds it
Public Sub Hold(ByVal i As Integer, ByVal dist As Integer, ByVal ax As Integer, ByVal ay As Integer, ByVal fast As Integer, ByVal tm As Integer)
  odist(i) = dist : opa(i) = ax : opb(i) = ay : ospd(i) = fast : otm(i) = tm
End Sub

' Spin i, a, b: it turns by a (about y) and b (about x) 256ths of a turn each picture
Public Sub Spin(ByVal i As Integer, ByVal a As Integer, ByVal b As Integer)
  E3.obj(i * 8 + 4) = (a And 255) + (b And 255) * 256
End Sub

' Mark i, c: its colour on the scanner (Hud3D.Scanner; 0: not shown)
Public Sub Mark(ByVal i As Integer, ByVal c As Integer)
  E3.obj(i * 8 + 7) = (E3.obj(i * 8 + 7) And 255) + c * 256
End Sub

' Pos i: where it is -> px, py, pz; Move i, x, y, z: put it there
Public Sub Pos(ByVal i As Integer)
  px = E3.obj(i * 8) : py = E3.obj(i * 8 + 1) : pz = E3.obj(i * 8 + 2)
End Sub

Public Sub Move(ByVal i As Integer, ByVal x As Integer, ByVal y As Integer, ByVal z As Integer)
  E3.obj(i * 8) = x : E3.obj(i * 8 + 1) = y : E3.obj(i * 8 + 2) = z
End Sub

' OnScreen(i): 1 when it's in the view (as the last Update found it)
Public Function OnScreen(ByVal i As Integer) As Integer
  t = E3.vwz(i)
  OnScreen = 0
  If ocls(i) And t > 100 And t < 30000 Then
    If Abs(E3.vwx(i)) < t And Abs(E3.vwy(i)) * 4 < t * 3 Then OnScreen = 1
  End If
End Function

' Aim i, x, y, z, speed: its speed set toward the point x, y, z, the biggest part of it speed
' (speed under 256)
Public Sub Aim(ByVal i As Integer, ByVal x As Integer, ByVal y As Integer, ByVal z As Integer, ByVal sp As Integer)
  Pos i
  AimAt x - px, y - py, z - pz, sp
  ovx(i) = avx : ovy(i) = avy : ovz(i) = avz
End Sub

' AimAt x, y, z, speed: (avx, avy, avz) along x, y, z, its biggest part speed
Public Sub AimAt(ByVal x As Integer, ByVal y As Integer, ByVal z As Integer, ByVal sp As Integer)
  Dim m As Integer, q As Integer
  m = Abs(x)
  If Abs(y) > m Then m = Abs(y)
  If Abs(z) > m Then m = Abs(z)
  If m = 0 Then
    avx = 0 : avy = 0 : avz = sp
    Exit Sub
  End If
  q = m \ 120 + 1
  m = m \ q
  If m = 0 Then m = 1
  avx = (x \ q) * sp \ m : avy = (y \ q) * sp \ m : avz = (z \ q) * sp \ m
End Sub

' BoltModel kind, size, dot / DebrisModel kind, size, dot, fall / BlastModel kind, dot: the models
' Fire, Burst and Boom use
Public Sub BoltModel(ByVal kind As Integer, ByVal sc As Integer, ByVal dot As Integer)
  bkind = kind : bsc = sc : bdot = dot
End Sub
Public Sub DebrisModel(ByVal kind As Integer, ByVal sc As Integer, ByVal dot As Integer, ByVal fall As Integer)
  dkind = kind : dsc = sc : ddot = dot : dgrav = fall
End Sub
Public Sub BlastModel(ByVal kind As Integer, ByVal dot As Integer)
  xkind = kind : xdot = dot
End Sub

' FireAt(from, x, y, z, speed): a bolt from object from toward x, y, z (class CL_EBOLT, hitting
' you); Fire(from, speed): at you - or, from -1, from you along your way (class CL_PBOLT, hitting
' the classes in pmask). Its life blife 50ths. The bolt's slot, -1 for none
Public Function FireAt(ByVal from As Integer, ByVal x As Integer, ByVal y As Integer, ByVal z As Integer, ByVal sp As Integer) As Integer
  Pos from
  AimAt x - px, y - py, z - pz, sp
  t = Spawn(bkind, bsc, CL_EBOLT, px + avx * 3, py + avy * 3, pz + avz * 3, bdot)
  FireAt = t
  If t < 0 Then Exit Function
  ovx(t) = avx : ovy(t) = avy : ovz(t) = avz
  omv(t) = MV_STRAIGHT : olife(t) = blife : omask(t) = M_PLAYER
  Spin t, 9, 13
End Function

Public Function Fire(ByVal from As Integer, ByVal sp As Integer) As Integer
  If from >= 0 Then
    Fire = FireAt(from, E3.CamGet(0), E3.CamGet(1), E3.CamGet(2), sp)
    Exit Function
  End If
  avx = (E3.cm(6) \ 128) * sp \ 128 : avy = (E3.cm(7) \ 128) * sp \ 128 : avz = (E3.cm(8) \ 128) * sp \ 128
  t = Spawn(bkind, bsc, CL_PBOLT, E3.CamGet(0) + avx * 2, E3.CamGet(1) + avy * 2 - 60, E3.CamGet(2) + avz * 2, bdot)
  Fire = t
  If t < 0 Then Exit Function
  ovx(t) = avx : ovy(t) = avy : ovz(t) = avz
  omv(t) = MV_STRAIGHT : olife(t) = blife : omask(t) = pmask
End Function

' Burst x, y, z, n: n bits of debris flying off x, y, z (DebrisModel), each living a second or so;
' vx, vy, vz: the speed they share (the thing that blew up's: SetVel's numbers, or 0s)
Public Sub Burst(ByVal x As Integer, ByVal y As Integer, ByVal z As Integer, ByVal n As Integer, ByVal vx As Integer, ByVal vy As Integer, ByVal vz As Integer)
  Dim k As Integer
  For k = 1 To n
    t = Spawn(dkind, dsc, CL_DEBRIS, x, y, z, ddot)
    If t >= 0 Then
      ovx(t) = vx + Rnd(120) - 60 : ovy(t) = vy + Rnd(120) - 50 : ovz(t) = vz + Rnd(120) - 60
      olife(t) = 30 + Rnd(20) : omv(t) = MV_FALL : opa(t) = dgrav : oflg(t) = dflg   ' <--- CHANGED
      Spin t, 5 + Rnd(8), 7 + Rnd(8)
    End If
  Next
End Sub

' Boom i, size: object i becomes a fireball (BlastModel) of that size, still, for 16 50ths, the
' last 8 a size bigger; it hits nothing
Public Sub Boom(ByVal i As Integer, ByVal sc As Integer)
  ocls(i) = CL_DEBRIS : omask(i) = 0 : omv(i) = MV_BLAST : oflg(i) = 0 : ost(i) = 0
  olife(i) = 16 : ogun(i) = 0 : ovx(i) = 0 : ovy(i) = 0 : ovz(i) = 0
  E3.obj(i * 8 + 5) = xkind + sc * 256
  E3.obj(i * 8 + 6) = 300 * sc
  E3.obj(i * 8 + 7) = xdot
  Spin i, 11, 7
End Sub

' Count(cls): how many objects of class cls there are
Public Function Count(ByVal cls As Integer) As Integer
  Dim n As Integer
  n = 0
  For t = 0 To NOBJ - 1
    If ocls(t) = cls Then n = n + 1
  Next
  Count = n
End Function

' NextEvent(): the next thing that happened in the last Update (EV_FIRE, EV_HIT; its objects in
' ea, eb), 0 when there are no more
Public Function NextEvent() As Integer
  If rdq >= nev Then
    NextEvent = 0
    Exit Function
  End If
  ea = evq(rdq) And 255 : eb = evb(rdq)
  NextEvent = evq(rdq) \ 256
  rdq = rdq + 1
End Function

' Update dt: every object moved on dt 50ths by its mover (lives and guns counted down, flags
' seen to), E3.ViewAll (each one's place in the view), then the hits found: the events queued
Public Sub Update(ByVal dt As Integer)
#asm
            ld a, ({dt})
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ld ({six}), ix
            push iy
            call fn_obj3d_lib_o3_step
            pop iy
            ld ix, ({six})
            ld sp, ({sps})
#endasm
  E3.scene0 = 0 : E3.nobj = NOBJ
  E3.ViewAll
#asm
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ld ({six}), ix
            push iy
            call fn_obj3d_lib_o3_hits
            pop iy
            ld ix, ({six})
            ld sp, ({sps})
#endasm
End Sub

' Draw: every object drawn (far to near, as Update last saw them) - after the background
Public Sub Draw()
  E3.scene0 = 0 : E3.nobj = NOBJ
  E3.scache = 1
  E3.Scene
  E3.scache = 0
End Sub

' Pick(mask, range): the nearest object whose class is in mask that's under the cross hairs (the
' view's middle, or pky / 128 of z up from it: a raised gun) and nearer than range: its slot, -1   ' <--- CHANGED
' for none. Half its radius, plus 60 and a little more with distance, is how near the line counts   ' <--- CHANGED
Public Function Pick(ByVal mask As Integer, ByVal rng As Integer) As Integer
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (pk_m), de
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (pk_bz), de
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ld a, #FF
            ld (pk_b), a
            xor a
            ld (fn_obj3d_lib_o3_i), a
pk_lp:
            call fn_obj3d_lib_o3_cur
            ld hl, {ocls}
            call fn_obj3d_lib_o3_rdw
            ld a, l
            or a
            jp z, pk_nx
            call fn_obj3d_lib_o3_bit    ; HL = 2 ^ class
            ld a, (pk_m)
            and l
            ld c, a
            ld a, (pk_m + 1)
            and h
            or c
            jp z, pk_nx
            ld hl, ({pvwz})         ; 150 < z < the best so far
            call fn_obj3d_lib_o3_rdw
            ld (pk_z), hl
            ld de, 151
            call fn_obj3d_lib_o3_scmp
            jp c, pk_nx
            ld hl, (pk_z)
            ld de, (pk_bz)
            call fn_obj3d_lib_o3_scmp
            jp nc, pk_nx
            ld hl, (pk_z)           ; the leeway: its width + 60 + z / 40 (about)
            srl h
            rr l
            srl h
            rr l
            srl h
            rr l
            srl h
            rr l
            srl h
            rr l
            ld d, h
            ld e, l
            srl d
            rr e
            srl d
            rr e
            or a
            sbc hl, de
            ld de, 60
            add hl, de
            push hl                 ; + its radius / 2
            ld a, 12
            call fn_obj3d_lib_o3_rpos
            srl h
            rr l
            pop de
            add hl, de
            ld (pk_t), hl
            ld hl, ({pvwx})
            call fn_obj3d_lib_o3_rdw
            bit 7, h
            call nz, fn_obj3d_lib_o3_neg
            ld de, (pk_t)
            or a
            sbc hl, de
            jp nc, pk_nx
            ld hl, ({pvwy})
            call fn_obj3d_lib_o3_rdw
            push hl                 ; <--- NEW (up: off the gun's line - y less z x pky / 128)
            ld de, (pk_z)           ; <--- NEW
            ld a, ({pky})           ; <--- NEW
            call fn_e3_lib_mt       ; <--- NEW
            ex de, hl               ; <--- NEW
            pop hl                  ; <--- NEW
            or a                    ; <--- NEW
            sbc hl, de              ; <--- NEW
            bit 7, h
            call nz, fn_obj3d_lib_o3_neg
            ld de, (pk_t)
            or a
            sbc hl, de
            jp nc, pk_nx
            ld a, (fn_obj3d_lib_o3_i)
            ld (pk_b), a
            ld hl, (pk_z)
            ld (pk_bz), hl
pk_nx:
            ld hl, fn_obj3d_lib_o3_i
            inc (hl)
            ld a, (hl)
            cp {NOBJ}
            jp c, pk_lp
            ld sp, ({sps})
            pop hl
            ld a, (pk_b)
            ld (hl), a
            inc hl
            ld (hl), 0
            cp #FF
            jr nz, pk_end
            ld (hl), a
            jr pk_end
pk_m:       dw 0
pk_bz:      dw 0
pk_z:       dw 0
pk_t:       dw 0
pk_b:       db 0
pk_end:
#endasm
End Function

' Shift dx, dy, dz: every object moved back by dx, dy, dz (with the camera: Fly3D.Rebase)
Public Sub Shift(ByVal dx As Integer, ByVal dy As Integer, ByVal dz As Integer)
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (sh_d), de
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (sh_d + 2), de
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (sh_d + 4), de
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ld hl, ({pobj})
            ld b, {NOBJ}
sh_lp:
            push bc
            ld de, sh_d
            ld b, 3
sh_ax:
            ld a, (de)
            ld c, a
            inc de
            ld a, (hl)
            sub c
            ld (hl), a
            inc hl
            ld a, (de)
            ld c, a
            inc de
            ld a, (hl)
            sbc a, c
            ld (hl), a
            inc hl
            djnz sh_ax
            ld de, 10
            add hl, de
            pop bc
            djnz sh_lp
            ld sp, ({sps})
            jr sh_end
sh_d:       ds 6
sh_end:
#endasm
End Sub

' Lib: the Z80 (Update's moves and hits, and what they share): one block, its labels
' fn_obj3d_lib_...; it runs on the real stack and calls E3's sums
Private Sub Lib()
#asm
            ret
; o3_step: every object moved on (o3_dt), the events queue emptied first
o3_step:
            ld (o3_dt), a
            or a
            jr nz, os_1
            inc a
            ld (o3_dt), a
os_1:
            ld hl, (o3_ph)          ; the weave's clock
            ld e, a
            ld d, 0
            add hl, de
            ld (o3_ph), hl
            xor a
            ld ({nev}), a
            ld ({nev} + 1), a
            ld ({rdq}), a
            ld ({rdq} + 1), a
            ld hl, ({pcp})          ; the camera (whole units) and your speed and way, as tables
            inc hl
            ld de, o3_cam
            ld b, 3
os_cam:
            ld a, (hl)
            ld (de), a
            inc hl
            inc de
            ld a, (hl)
            ld (de), a
            inc hl
            inc hl
            inc hl
            inc de
            djnz os_cam
            ld hl, ({pvx})
            ld (o3_pv), hl
            ld hl, ({pvy})
            ld (o3_pv + 2), hl
            ld hl, ({pvz})
            ld (o3_pv + 4), hl
            ld hl, ({hfx})
            ld (o3_hf), hl
            ld hl, ({hfy})
            ld (o3_hf + 2), hl
            ld hl, ({hfz})
            ld (o3_hf + 4), hl
            xor a
            ld (o3_i), a
os_lp:
            ld a, (o3_i)            ; <--- NEW (the frame count kept: a long stretch with no look at
            and 7                   ; <--- NEW  the raster misses a frame going by, and Sync waits
            call z, fn_e3_lib_vpoll ; <--- NEW  one more: a look every 8th object)
            call o3_cur
            ld hl, {ocls}
            call o3_rdw
            ld a, l
            or a
            jp z, os_nx
            ld hl, {olife}          ; its life
            call o3_rdw
            ld a, h
            or l
            jr z, os_2
            ld hl, {olife}
            call o3_tick
            or a
            jp nz, os_kill
os_2:
            ld hl, {oflg}           ; left behind on a run
            call o3_rdw
            ld a, l
            ld (o3_fl), a
            and 1
            jr z, os_3
            ld a, 4
            call o3_rpos
            ex de, hl
            ld hl, (o3_cam + 4)
            ld bc, -2500
            add hl, bc
            ex de, hl
            call o3_scmp
            jp c, os_kill
os_3:
            ld hl, {omv}            ; its mover
            call o3_rdw
            ld a, l
            ld (o3_mv), a
            cp 14                   ; <--- CHANGED (14 movers)
            jr nc, os_mvd
            add a, a
            ld l, a
            ld h, 0
            ld de, os_tab
            add hl, de
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            call o3_jp
os_mvd:
            ld hl, {ocls}           ; (taken out by its mover?)
            call o3_rdw
            ld a, l
            or a
            jp z, os_nx
; @if ground
            ld a, (o3_fl)           ; <--- NEW: OF_LAND: down to the ground?
            and 16                  ; <--- NEW
            jr z, os_nl             ; <--- NEW
            ld a, 2                 ; <--- NEW
            call o3_rpos            ; <--- NEW
            ld de, ({gy})           ; <--- NEW
            inc de                  ; <--- NEW (y <= gy)
            call o3_scmp            ; <--- NEW
            jr nc, os_nl            ; <--- NEW
            call os_land            ; <--- NEW
os_nl:                              ; <--- NEW
; @end
            ld a, (o3_fl)           ; facing
            and 12
            jr z, os_4
            and 8
            jr z, os_f
            ld a, 1
os_f:
            call o3_face
os_4:
            ld hl, {ogun}           ; its gun (not while a station keeper breaks off)
            call o3_rdw
            ld a, h
            or l
            jr z, os_5
            ld a, (o3_mv)
            cp 4
            jr c, os_g
            cp 6
            jr nc, os_g
            ld hl, {ost}
            call o3_rdw
            ld a, l
            cp 2
            jr z, os_5
os_g:
            ld hl, {ogun}
            call o3_tick
            or a
            jr z, os_5
; @if ground
            ld a, (o3_fl)           ; <--- NEW: OF_GUNANY: ready with you within 8500 any way
            and 32                  ; <--- NEW
            jr z, os_gv             ; <--- NEW
            call o3_far             ; <--- NEW
            ld hl, (o3_d)           ; <--- NEW
            ld de, 8500             ; <--- NEW
            or a                    ; <--- NEW
            sbc hl, de              ; <--- NEW
            ld bc, 1                ; <--- NEW
            jr nc, os_gn            ; <--- NEW
            jr os_gy                ; <--- NEW
os_gv:                              ; <--- NEW
; @end
            ld hl, ({pvwz})         ; ready: you 700 - 8500 in front of it?
            call o3_rdw
            ld (o3_t2), hl
            ld bc, 1                ; (not yet: try again next time)
            ld de, 700
            call o3_scmp
            jr c, os_gn
            ld hl, (o3_t2)
            ld de, 8500
            call o3_scmp
            jr nc, os_gn
os_gy:                              ; <--- NEW
            ld bc, 0
            ld hl, {ogun}
            call o3_wrw
            ld a, 1
            ld e, 0
            call o3_event
            jr os_5
os_gn:
            ld hl, {ogun}
            call o3_wrw
os_5:
; @if !noflyers
            ld a, (o3_fl)           ; too far off: back in front of you
            and 2
            jr z, os_nx
            call o3_far
            or a
            call nz, o3_ahead
; @end
            jr os_nx
os_kill:
            call o3_kill
os_nx:
            ld hl, o3_i
            inc (hl)
            ld a, (hl)
            cp {NOBJ}
            jp c, os_lp
            ret
o3_jp:      jp (hl)
; @if !noflyers
os_tab:     dw o3_ret, o3_move, mv_fall, mv_blast, mv_hold, mv_hold, mv_charge, mv_pass, mv_turn, mv_weave, mv_orbit
; @else
os_tab:     dw o3_ret, o3_move, mv_fall, mv_blast, mv_hold, mv_hold, o3_ret, o3_ret, o3_ret, o3_ret, o3_ret   ; <--- NEW ("noflyers": MV_CHARGE .. MV_ORBIT left out)
; @end
; @if ground
            dw mv_circle, mv_hunt, mv_home  ; <--- NEW
; @else
            dw o3_ret, o3_ret, o3_ret       ; <--- NEW (a game without the ground movers: their room saved)
; @end
o3_ret:     ret
; ---- the object now: o3_i, o3_o = o3_i x 2 (its words' offset)
o3_cur:
            ld a, (o3_i)
            add a, a
            ld l, a
            ld h, 0
            ld (o3_o), hl
            ret
; o3_rdw: HL = an array -> HL = its word for the object now (uses DE)
o3_rdw:
            ld de, (o3_o)
            add hl, de
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ret
; o3_wrw: HL = an array, BC = a value: the object now's word set (uses DE, keeps BC)
o3_wrw:
            ld de, (o3_o)
            add hl, de
            ld (hl), c
            inc hl
            ld (hl), b
            ret
; o3_objp: HL = the object now's scene record (E3.obj, 16 bytes; uses DE)
o3_objp:
            ld hl, (o3_o)
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, ({pobj})
            add hl, de
            ret
; o3_rpos: A = 0, 2, 4 -> HL = its x, y or z (o3_wpos: = BC; o3_wobj: any word of the record)
o3_rpos:
            push af
            call o3_objp
            pop af
            ld e, a
            ld d, 0
            add hl, de
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ret
o3_wpos:
o3_wobj:
            push af
            call o3_objp
            pop af
            ld e, a
            ld d, 0
            add hl, de
            ld (hl), c
            inc hl
            ld (hl), b
            ret
; o3_kill: the object now taken out
o3_kill:
            ld hl, {ocls}
            ld bc, 0
            call o3_wrw
            call o3_objp
            ld de, 10
            add hl, de
            ld (hl), 255
            ret
; o3_zero: every number of the object now 0 (Spawn)
o3_zero:
            ld hl, oz_tab
            ld b, 20
oz_lp:
            ld e, (hl)
            inc hl
            ld d, (hl)
            inc hl
            push hl
            ex de, hl
            ld de, (o3_o)
            add hl, de
            ld (hl), 0
            inc hl
            ld (hl), 0
            pop hl
            djnz oz_lp
            ret
oz_tab:     dw {ocls}, {omask}, {omv}, {oflg}, {ost}, {otm}, {olife}, {ogun}, {otype}, {ouv}
            dw {ovx}, {ovy}, {ovz}, {opa}, {opb}, {ospd}, {odist}, {ohw}, {ohh}, {olz}
; o3_tick: HL = an array of timers: its word - dt -> HL; A = 1 when run out (0 or under)
o3_tick:
            push hl
            call o3_rdw
            ld a, (o3_dt)
            ld e, a
            ld d, 0
            or a
            sbc hl, de
            ld b, h
            ld c, l
            pop hl
            push bc
            call o3_wrw
            pop hl
            ld a, 1
            bit 7, h
            ret nz
            ld a, h
            or l
            ld a, 1
            ret z
            xor a
            ret
; o3_move: the object now on by its speed x dt
o3_move:
            ld hl, {ovx}
            xor a
            call mv_1
            ld hl, {ovy}
            ld a, 2
            call mv_1
            ld hl, {ovz}
            ld a, 4
mv_1:
            ld (o3_k), a
            call o3_rdw
            ex de, hl
            ld a, (o3_dt)
            ld b, a
            ld hl, 0
mv_m:
            add hl, de
            djnz mv_m
            ex de, hl
            push de
            call o3_objp
            pop de
            ld a, (o3_k)
            ld c, a
            ld b, 0
            add hl, bc
            ld a, (hl)
            add a, e
            ld (hl), a
            inc hl
            ld a, (hl)
            adc a, d
            ld (hl), a
            ret
; mv_fall: on, and falling faster (opa a 50th)
mv_fall:
            call o3_move
            ld hl, {opa}
            call o3_rdw
            ex de, hl
            ld a, (o3_dt)
            ld b, a
            ld hl, 0
mf_m:
            add hl, de
            djnz mf_m
            ex de, hl
            push de
            ld hl, {ovy}
            call o3_rdw
            pop de
            or a
            sbc hl, de
            ld b, h
            ld c, l
            ld hl, {ovy}
            jp o3_wrw
; mv_blast: a size bigger for its last 8 50ths (once)
mv_blast:
            ld hl, {olife}
            call o3_rdw
            ld de, 9
            call o3_scmp
            ret nc
            ld hl, {ost}
            call o3_rdw
            ld a, l
            or a
            ret nz
            ld hl, {ost}
            ld bc, 1
            call o3_wrw
            call o3_objp
            ld de, 11
            add hl, de
            inc (hl)
            ret
; @if !noflyers                    ; <--- NEW
; mv_weave: on, swaying: its speed across gets sin x opa, up cos x opb (a 50th)
mv_weave:
            call o3_move
            call o3_phase
            call fn_e3_lib_trig     ; A = sin, C = cos (x 127)
            ld (mw_c), a
            ld a, c
            push af
            ld a, (mw_c)
            ld hl, {opa}
            ld e, 0
            call mw_one
            pop af
            ld hl, {opb}
            ld e, 2
mw_one:                             ; A = sin or cos, HL = the amount's array, E = the axis
            ld (o3_k), a
            ld a, e
            ld (mw_ax), a
            call o3_rdw
            ld b, h
            ld c, l
            ld a, (o3_k)
            call o3_s14
            call fn_e3_lib_m14      ; HL = the amount x sin
            ex de, hl
            ld a, (o3_dt)
            ld b, a
            ld hl, 0
mw_m:
            add hl, de
            djnz mw_m
            ld b, h
            ld c, l
            ld a, (mw_ax)
            push bc
            call o3_rpos
            pop bc
            add hl, bc
            ld b, h
            ld c, l
            ld a, (mw_ax)
            jp o3_wpos
mw_c:       db 0
mw_ax:      db 0
; @end                             ; <--- NEW
; o3_s14: DE = A (signed, x 127) x 128 (as s1.14)
o3_s14:
            ld l, a
            rla
            sbc a, a
            ld h, a
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ex de, hl
            ret
; @if !noflyers                    ; <--- NEW
; mv_orbit: round (opa, opb) at odist, ospd 256ths of a turn a second
mv_orbit:
            ld hl, {ospd}           ; the angle (ost, 8.8 of a 256th) on by ospd x dt x 256 / 50
            call o3_rdw
            ex de, hl
            ld a, (o3_dt)
            ld b, a
            ld hl, 0
mo_m:
            add hl, de
            djnz mo_m
            add hl, hl              ; (x 5: about x 256 / 50)
            add hl, hl
            add hl, de
            ex de, hl
            ld hl, {ost}
            call o3_rdw
            add hl, de
            ld b, h
            ld c, l
            ld hl, {ost}
            call o3_wrw
            ld a, b
            call fn_e3_lib_trig     ; A = sin, C = cos
            push af
            ld a, c
            ld hl, {opa}
            ld e, 0
            call mo_ax              ; x = opa + cos x odist
            pop af
            ld hl, {opb}
            ld e, 4                 ; z = opb + sin x odist
mo_ax:
            push de
            push hl
            call o3_s14             ; DE = sin or cos x 128 (s1.14 near enough)
            push de
            ld hl, {odist}
            call o3_rdw
            ld b, h
            ld c, l
            pop de
            call fn_e3_lib_m14      ; HL = odist x it
            ex de, hl
            pop hl
            push de
            call o3_rdw
            pop de
            add hl, de
            ld b, h
            ld c, l
            pop de
            ld a, e
            jp o3_wpos
; @end                             ; <--- NEW
; o3_phase: A = the weave's angle for the object now (the clock x 3 / 4 + i x 36)
o3_phase:
            ld hl, (o3_ph)
            ld d, h
            ld e, l
            srl d
            rr e
            add hl, de
            srl h
            rr l
            ld b, l
            ld a, (o3_i)
            ld c, a
            add a, a
            add a, a
            add a, a
            add a, c
            add a, a
            add a, a
            add a, b
            ret
; ---- the station keepers (MV_HOLD, MV_HOLDONLY), MV_CHARGE, MV_PASS, MV_TURN
mv_hold:
            call o3_far
            call o3_prm
            ld hl, {ost}
            call o3_rdw
            ld a, l
            ld (o3_st), a
            cp 1
            jp z, fs_run
            cp 2
            jp z, fs_brk
            ; -- 0: holding station, weaving
            call o3_phase
            call fn_e3_lib_trig     ; A = sin, C = cos (x 127)
            push bc
            ld e, a
            call fi_s5              ; across + sin x 5
            ld hl, (o3_ox)
            add hl, de
            ld (o3_ox), hl
            pop bc
            ld e, c
            call fi_s4              ; up + cos x 4
            ld hl, (o3_oy)
            add hl, de
            ld (o3_oy), hl
            ld hl, {otm}
            call o3_tick
            or a
            jp z, fs_go
            ld a, (o3_mv)
            cp 5
            jr nz, fh_2
            ld hl, {otm}            ; (MV_HOLDONLY stays: its time again)
            ld bc, 100
            call o3_wrw
            jp fs_go
fh_2:
            ld bc, 1                ; on to a run in
            ld de, 70
            call fi_set
            jp fs_go
fs_run:     ; -- 1: in at you, to 1500 in front
            ld hl, 1500
            ld (o3_dd), hl
            ld hl, (o3_ox)
            sra h
            rr l
            ld (o3_ox), hl
            ld hl, (o3_oy)
            sra h
            rr l
            ld (o3_oy), hl
            ld hl, {otm}
            call o3_tick
            or a
            jr nz, fr_brk
            ld hl, (o3_d)
            ld de, 1300
            or a
            sbc hl, de
            jp nc, fs_go
fr_brk:
            ld bc, 2                ; break off: up and to its side, at once
            ld de, 40
            call fi_set
            ld hl, {ovy}
            call o3_rdw
            ld de, 130
            add hl, de
            ld b, h
            ld c, l
            ld hl, {ovy}
            call o3_wrw
            ld hl, {ovx}
            call o3_rdw
            ld de, 110
            ld a, (o3_i)
            rra
            jr c, fr_1
            ld de, -110
fr_1:
            add hl, de
            ld b, h
            ld c, l
            ld hl, {ovx}
            call o3_wrw
            jp fs_go
fs_brk:     ; -- 2: away up and out to its side, still in front
            ld hl, 5000
            ld (o3_dd), hl
            ld hl, 1800
            ld (o3_oy), hl
            ld hl, 2500
            ld a, (o3_i)
            rra
            jr c, fb_1
            ld hl, -2500
fb_1:
            ld (o3_ox), hl
            ld hl, {otm}
            call o3_tick
            or a
            jp z, fs_go
            ld a, (o3_i)            ; back to holding station
            ld e, a
            add a, a
            add a, a
            add a, a
            add a, e
            and 63
            add a, 90
            ld e, a
            ld d, 0
            ld bc, 0
            call fi_set
            jp fs_go
; @if !noflyers                    ; <--- NEW
mv_turn:    ; -- after you, odist ahead of you (opa across, opb up)
            call o3_far
            call o3_prm
            xor a
            ld (o3_st), a
            jp fs_go
mv_charge:  ; -- straight at you
            call o3_far
            call o3_prm
            xor a
            ld (o3_st), a
            ld hl, 0
            ld (o3_dd), hl
            ld (o3_ox), hl
            ld (o3_oy), hl
            ld hl, (o3_d)           ; within 2500: on through
            ld de, 2500
            or a
            sbc hl, de
            jr nc, fs_go
            ld hl, {omv}
            ld bc, 7
            call o3_wrw
            jr fs_go
mv_pass:    ; -- on through; gone when well behind you
            call o3_move
            ld a, 1
            call o3_face
            ld hl, ({pvwz})
            call o3_rdw
            ld de, -3000
            call o3_scmp
            jp c, o3_kill
            ret
; @end                             ; <--- NEW
fs_go:      ; steer: the speed wanted = yours + (the point - it) / 8, within yours +- ospd;
            ; its speed goes (dt / 8 of the way) to that
            call o3_tgt
            ld hl, 0
            ld (o3_cc), hl
            ld b, 3
fg_lp:
            push bc
            ld a, (o3_cc)
            call o3_rpos            ; HL = its place
            ex de, hl
            ld hl, o3_tx
            ld bc, (o3_cc)
            add hl, bc
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            or a
            sbc hl, de              ; the point - it
            sra h
            rr l
            sra h
            rr l
            sra h
            rr l
            ex de, hl
            ld hl, o3_pv
            add hl, bc
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (o3_t2), hl          ; your speed this way
            add hl, de
            ld (o3_t3), hl          ; wanted
            ld hl, (o3_t2)          ; within yours - vm .. yours + vm
            ld de, (o3_vm)
            or a
            sbc hl, de
            ex de, hl
            ld hl, (o3_t3)
            push de
            call o3_scmp
            pop de
            jr nc, fg_1
            ld (o3_t3), de
fg_1:
            ld hl, (o3_t2)
            ld de, (o3_vm)
            add hl, de
            ex de, hl
            ld hl, (o3_t3)
            push de
            ex de, hl
            call o3_scmp            ; (vm + yours) < wanted?
            pop de
            jr nc, fg_2
            ld (o3_t3), de
fg_2:
            ld hl, o3_vb
            ld de, (o3_cc)
            add hl, de
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (o3_t2), hl          ; (the speed's array)
            call o3_rdw
            ld (o3_t4), hl          ; its speed
            ex de, hl
            ld hl, (o3_t3)
            or a
            sbc hl, de              ; wanted - it
            ex de, hl
            ld a, (o3_dt)
            ld b, a
            ld hl, 0
fg_m:
            add hl, de
            djnz fg_m
            sra h
            rr l
            sra h
            rr l
            sra h
            rr l
            ld de, (o3_t4)
            add hl, de
            ld b, h
            ld c, l
            ld hl, (o3_t2)
            call o3_wrw
            ld hl, (o3_cc)
            inc hl
            inc hl
            ld (o3_cc), hl
            pop bc
            dec b
            jp nz, fg_lp
            call o3_move
            ld a, (o3_st)           ; facing: you, but along its way when breaking off
            cp 2
            ld a, 0
            jr nz, fg_3
            inc a
fg_3:
            jp o3_face
; o3_prm: the station keeper's numbers: o3_vm = ospd, o3_dd = odist, o3_ox, o3_oy = opa, opb
o3_prm:
            ld hl, {ospd}
            call o3_rdw
            ld (o3_vm), hl
            ld hl, {odist}
            call o3_rdw
            ld (o3_dd), hl
            ld hl, {opa}
            call o3_rdw
            ld (o3_ox), hl
            ld hl, {opb}
            call o3_rdw
            ld (o3_oy), hl
            ret
; fi_set: ost = BC, otm = DE
fi_set:
            push de
            ld hl, {ost}
            call o3_wrw
            pop bc
            ld hl, {otm}
            jp o3_wrw
; fi_s5, fi_s4: DE = E (signed) x 5, x 4
fi_s5:
            ld a, e
            ld l, a
            rla
            sbc a, a
            ld h, a
            ld d, h
            ld e, l
            add hl, hl
            add hl, hl
            add hl, de
            ex de, hl
            ret
fi_s4:
            ld a, e
            ld l, a
            rla
            sbc a, a
            ld h, a
            add hl, hl
            add hl, hl
            ex de, hl
            ret
; @if ground
; ---- (NEW) the ground movers and the homer                                  ; <--- NEW (to the @end)
; os_land: the object now landed: at gy, still, the flag off, EV_LAND
os_land:
            call o3_objp            ; <--- NEW (its spin stopped: it lies still)
            ld de, 8                ; <--- NEW
            add hl, de              ; <--- NEW
            xor a                   ; <--- NEW
            ld (hl), a              ; <--- NEW
            inc hl                  ; <--- NEW
            ld (hl), a              ; <--- NEW
            ld bc, ({gy})
            ld a, 2
            call o3_wpos
            ld bc, 0
            ld hl, {ovx}
            call o3_wrw
            ld hl, {ovy}
            call o3_wrw
            ld hl, {ovz}
            call o3_wrw
            ld hl, {oflg}
            call o3_rdw
            ld a, l
            and #EF
            ld (o3_fl), a
            ld c, a
            ld b, h
            ld hl, {oflg}
            call o3_wrw
            ld a, 3
            ld e, 0
            jp o3_event
; mv_circle: round you at odist (the angle in ost, 8.8 of a 256th, on by ospd a second)
mv_circle:
            ld hl, {ospd}
            call o3_rdw
            ex de, hl
            ld a, (o3_dt)
            ld b, a
            ld hl, 0
mc_m:
            add hl, de
            djnz mc_m
            add hl, hl              ; (x 5: about x 256 / 50)
            add hl, hl
            add hl, de
            ex de, hl
            ld hl, {ost}
            call o3_rdw
            add hl, de
            ld b, h
            ld c, l
            ld hl, {ost}
            call o3_wrw
            ld a, b
            call fn_e3_lib_trig     ; A = sin, C = cos
            ld (mc_s), a
            ld a, c
            ld (mc_c), a
            ld hl, {odist}          ; the point: you + (cos, sin) x odist
            call o3_rdw
            push hl
            ld a, (mc_c)
            call o3_s14
            pop bc
            push bc
            call fn_e3_lib_m14
            ld de, (o3_cam)
            add hl, de
            ld (o3_tx), hl
            pop bc
            ld a, (mc_s)
            call o3_s14
            call fn_e3_lib_m14
            ld de, (o3_cam + 4)
            add hl, de
            ld (o3_tx + 4), hl
            call o3_gsteer
            xor a                   ; looking at you
            jp o3_face
mc_s:       db 0
mc_c:       db 0
; mv_hunt: at you to odist off; now and then back behind its cover (object opb)
mv_hunt:
            ld hl, {otm}
            call o3_tick
            ld (mh_t), a
            ld hl, {ost}
            call o3_rdw
            ld a, l
            or a
            jp nz, mh_hide           ; <--- CHANGED (jp: further now)
            call o3_far             ; hunting: within odist (the biggest way)? it stands
            ld hl, {odist}
            call o3_rdw
            ex de, hl
            ld hl, (o3_d)
            or a
            sbc hl, de
            jr c, mh_near
            ld hl, (o3_cam)
            ld (o3_tx), hl
            ld hl, (o3_cam + 4)
            ld (o3_tx + 4), hl
            ld a, 1
            jr mh_go
mh_near:                            ; near enough: it creeps round you (a sixteenth of the way
            ld a, 4                 ; across: out from behind its cover in time), facing you
            call o3_rpos
            ex de, hl
            ld hl, (o3_cam + 4)
            or a
            sbc hl, de              ; cz - z
            call mh_q
            push hl
            xor a
            call o3_rpos
            pop de
            add hl, de
            ld (o3_tx), hl          ; x + (cz - z) / 16
            xor a
            call o3_rpos
            ex de, hl
            ld hl, (o3_cam)
            or a
            sbc hl, de              ; cx - x
            call mh_q
            push hl
            ld a, 4
            call o3_rpos
            pop de
            or a
            sbc hl, de
            ld (o3_tx + 4), hl      ; z - (cx - x) / 16
            xor a
mh_go:
            ld (mh_f), a
            ld a, (mh_t)            ; time to take cover?
            or a
            jr z, mh_st
            ld bc, 90
            call mh_cov             ; (no cover: hunt on)
            jr nc, mh_c1
            ld bc, 150
            ld de, 0
            jr mh_set
mh_c1:
            ld bc, 90
            ld de, 1
mh_set:
            push de                 ; (o3_wrw uses DE)
            ld hl, {otm}
            call o3_wrw
            pop bc
            ld hl, {ost}
            call o3_wrw
mh_st:
            call o3_gsteer
            ld a, (mh_f)
            jp o3_face
mh_hide:                            ; in cover: behind object opb from you
            call mh_cov
            jr c, mh_out
            ld a, b                 ; its slot
            ld (mh_o), a
            ld e, 0
            call mh_pt
            ld (o3_tx), hl
            ld e, 4
            call mh_pt
            ld (o3_tx + 4), hl
            ld a, (mh_t)
            or a
            jr z, mh_h1
mh_out:
            ld bc, 150              ; out again: hunting
            ld hl, {otm}
            call o3_wrw
            ld bc, 0
            ld hl, {ost}
            call o3_wrw
            ld hl, (o3_cam)
            ld (o3_tx), hl
            ld hl, (o3_cam + 4)
            ld (o3_tx + 4), hl
mh_h1:
            call o3_gsteer
            ld a, 1
            jp o3_face
; mh_q: HL / 16, the other way round for an odd slot
mh_q:
            sra h
            rr l
            sra h
            rr l
            sra h
            rr l
            sra h
            rr l
            ld a, (o3_i)
            and 1
            ret z
            jp o3_neg
; mh_cov: carry when there's no cover (opb under 0, or its object gone); else B = its slot
mh_cov:
            push bc
            ld hl, {opb}
            call o3_rdw
            pop bc
            bit 7, h
            scf
            ret nz
            ld a, l
            cp {NOBJ}
            ccf
            ret c
            ld b, a
            push bc
            add a, a
            ld e, a
            ld d, 0
            ld hl, {ocls}
            add hl, de
            ld a, (hl)
            pop bc
            or a
            ret nz                  ; (nc: there)
            scf
            ret
; mh_pt: HL = the cover's x or z (E: 0, 4) + (it - you) / 8: the far side of it from you
mh_pt:
            ld a, (mh_o)
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld d, 0
            add hl, de
            push de
            ld de, ({pobj})
            add hl, de
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            pop de
            push hl
            ld hl, o3_cam
            add hl, de
            ld a, (hl)
            inc hl
            ld d, (hl)
            ld e, a
            pop hl
            push hl
            or a
            sbc hl, de
            sra h
            rr l
            sra h
            rr l
            sra h
            rr l
            pop de
            add hl, de
            ret
mh_t:       db 0
mh_f:       db 0
mh_o:       db 0
; mv_home: in on you, up to opa a 50th each way, turning fast; facing its way
mv_home:
            ld hl, (o3_cam)
            ld (o3_tx), hl
            ld hl, (o3_cam + 2)
            ld (o3_tx + 2), hl
            ld hl, (o3_cam + 4)
            ld (o3_tx + 4), hl
            ld a, 2
            ld (gs_r), a
            ld hl, {opa}
            call o3_rdw
            ld (o3_vm), hl
            ld a, 2                 ; (y too)
            call gs_ax
            call gs_two
            ld a, 1
            jp o3_face
; o3_gsteer: steered on the ground to (o3_tx, o3_tz), up to opa a 50th each way, then moved
o3_gsteer:
            ld a, 3
            ld (gs_r), a
            ld bc, 0
            ld hl, {ovy}
            call o3_wrw
gs_two:
            ld hl, {opa}
            call o3_rdw
            ld (o3_vm), hl
            xor a
            call gs_ax
            ld a, 4
            call gs_ax
            jp o3_move
; gs_ax: axis A (0, 2, 4): its speed goes dt / 2^gs_r of the way to (the point - it) / 8, kept
; within +- o3_vm
gs_ax:
            ld (o3_k), a
            call o3_rpos
            ex de, hl
            ld a, (o3_k)
            ld l, a
            ld h, 0
            ld bc, o3_tx
            add hl, bc
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            or a
            sbc hl, de
            sra h
            rr l
            sra h
            rr l
            sra h
            rr l
            ld (o3_t3), hl          ; wanted
            ld de, (o3_vm)
            call o3_scmp
            jr c, ga_1
            ld (o3_t3), de
ga_1:
            ld hl, (o3_vm)
            call o3_neg
            ex de, hl
            ld hl, (o3_t3)
            call o3_scmp
            jr nc, ga_2
            ld (o3_t3), de
ga_2:
            ld a, (o3_k)            ; its speed's array
            ld l, a
            ld h, 0
            ld bc, o3_vb
            add hl, bc
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (o3_t2), hl
            call o3_rdw
            ld (o3_t4), hl
            ex de, hl
            ld hl, (o3_t3)
            or a
            sbc hl, de              ; wanted - it
            ex de, hl
            ld a, (o3_dt)
            ld b, a
            ld hl, 0
ga_m:
            add hl, de
            djnz ga_m
            ld a, (gs_r)
            ld b, a
ga_sh:
            sra h
            rr l
            djnz ga_sh
            ld de, (o3_t4)
            add hl, de
            ld b, h
            ld c, l
            ld hl, (o3_t2)
            jp o3_wrw
gs_r:       db 3
; @end
; o3_scmp: carry when HL < DE (signed)
o3_scmp:
            ld a, h
            xor d
            jp m, sc_ds
            or a
            sbc hl, de
            ret
sc_ds:
            ld a, h
            rla
            ret
; o3_neg: HL = -HL
o3_neg:
            xor a
            sub l
            ld l, a
            sbc a, a
            sub h
            ld h, a
            ret
; o3_absd: HL = |HL - DE| (unsigned: to 65535)
o3_absd:
            or a
            sbc hl, de
            jp po, ab_1
            bit 7, h
            ret nz
            jr o3_neg
ab_1:
            bit 7, h
            ret z
            jr o3_neg
; o3_far: o3_d = how far from you (the biggest way); A = 1 when over 14000
o3_far:
            xor a
            call o3_rpos
            ld de, (o3_cam)
            call o3_absd
            ld (o3_d), hl
            ld a, 2
            call o3_rpos
            ld de, (o3_cam + 2)
            call o3_absd
            call fa_mx
            ld a, 4
            call o3_rpos
            ld de, (o3_cam + 4)
            call o3_absd
            call fa_mx
            ld hl, (o3_d)
            ld de, 14001
            or a
            sbc hl, de
            ld a, 0
            ret c
            inc a
            ret
fa_mx:
            ld de, (o3_d)
            push hl
            or a
            sbc hl, de
            pop hl
            ret c
            ld (o3_d), hl
            ret
; o3_event: A = the event, E = its other object: onto the queue (the object now its first)
o3_event:
            ld c, a
            ld a, ({nev})
            cp 32
            ret nc
            ld b, a
            inc a
            ld ({nev}), a
            push de
            ld l, b
            ld h, 0
            add hl, hl
            push hl
            ld de, {evq}
            add hl, de
            ld a, (o3_i)
            ld (hl), a
            inc hl
            ld (hl), c
            pop hl
            pop de
            ld bc, {evb}
            add hl, bc
            ld (hl), e
            inc hl
            ld (hl), 0
            ret
; o3_tgt: (o3_tx, ty, tz) = you + the lagging way ahead (hf) x o3_dd, + o3_ox along the world's x,
; o3_oy up (world y): the offsets don't turn with you, so rolling moves it round the screen
o3_tgt:
            ld hl, 0
            ld (o3_cc), hl
            ld b, 3
tg_lp:
            push bc
            ld hl, o3_hf
            ld de, (o3_cc)
            add hl, de
            ld c, (hl)
            inc hl
            ld b, (hl)
            ld de, (o3_dd)
            call fn_e3_lib_m14
            ld a, (o3_cc)
            or a
            ld de, (o3_ox)
            jr z, tg_o
            cp 2
            ld de, (o3_oy)
            jr z, tg_o
            ld de, 0
tg_o:
            add hl, de
            ex de, hl
            ld hl, o3_cam
            ld bc, (o3_cc)
            add hl, bc
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            add hl, de
            ex de, hl
            ld hl, o3_tx
            add hl, bc
            ld (hl), e
            inc hl
            ld (hl), d
            inc bc
            inc bc
            ld (o3_cc), bc
            pop bc
            djnz tg_lp
            ret
; @if !noflyers                    ; <--- NEW (OF_WRAP: left out with the flyers)
; o3_ahead: the object now put 9000 in front of you (at opa across, opb up), standing still
o3_ahead:
            ld hl, 9000
            ld (o3_dd), hl
            ld hl, {opa}
            call o3_rdw
            ld (o3_ox), hl
            ld hl, {opb}
            call o3_rdw
            ld (o3_oy), hl
            call o3_tgt
            ld hl, (o3_tx)
            ld b, h
            ld c, l
            xor a
            call o3_wpos
            ld hl, (o3_tx + 2)
            ld b, h
            ld c, l
            ld a, 2
            call o3_wpos
            ld hl, (o3_tx + 4)
            ld b, h
            ld c, l
            ld a, 4
            call o3_wpos
            ld bc, 0
            ld hl, {ovx}
            call o3_wrw
            ld hl, {ovy}
            call o3_wrw
            ld hl, {ovz}
            call o3_wrw
            ld hl, {olz}
            jp o3_wrw
; @end                             ; <--- NEW
; o3_face: the object now turned: A = 0 to look at you, 1 along its speed
o3_face:
            or a
            jr nz, fc_v
            ld b, 0
fc_c:
            ld a, b
            push bc
            call o3_rpos
            ex de, hl
            ld hl, o3_cam
            pop bc
            push bc
            ld c, b
            ld b, 0
            add hl, bc
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            or a
            sbc hl, de
            ex de, hl
            ld hl, o3_f
            add hl, bc
            ld (hl), e
            inc hl
            ld (hl), d
            pop bc
            inc b
            inc b
            ld a, b
            cp 6
            jr c, fc_c
            jr fc_go
fc_v:
            ld hl, {ovx}
            call o3_rdw
            ld (o3_f), hl
            ld hl, {ovy}
            call o3_rdw
            ld (o3_f + 2), hl
            ld hl, {ovz}
            call o3_rdw
            ld (o3_f + 4), hl
fc_go:
            ld hl, (o3_f + 4)       ; the turn about y: angle (z, x)
            ld de, (o3_f)
            call o3_ang
            ld (o3_fa), a
            ld hl, (o3_f)           ; h = the biggest of |x|, |z| + half the other
            bit 7, h
            call nz, o3_neg
            ex de, hl
            ld hl, (o3_f + 4)
            bit 7, h
            call nz, o3_neg
            push hl
            or a
            sbc hl, de
            pop hl
            jr nc, fc_1
            ex de, hl               ; HL = the bigger, DE = the smaller
fc_1:
            srl d
            rr e
            add hl, de
            jr nc, fc_2
            ld hl, #FFFF
fc_2:
            srl h                   ; (halved with -y below: in range)
            rr l
            push hl
            ld hl, (o3_f + 2)
            call o3_neg
            sra h
            rr l
            ex de, hl
            pop hl
            call o3_ang             ; the turn about x: angle (h, -y)
            ld b, a
            ld a, (o3_fa)
            ld c, a
            ld a, 6
            jp o3_wobj
; o3_ang: HL = x, DE = y -> A = the angle of (x, y), 256 to the turn (0 along x, 64 along y)
o3_ang:
            ld (an_x), hl
            ld (an_y), de
            bit 7, h
            call nz, o3_neg
            ex de, hl
            bit 7, h
            call nz, o3_neg
            ex de, hl               ; HL = |x|, DE = |y|
an_s:
            ld a, h
            or d
            jr z, an_8
            srl h
            rr l
            srl d
            rr e
            jr an_s
an_8:
            ld a, l
            or e
            ret z                   ; (0, 0): 0
            ld a, e
            cp l
            jr z, an_eq
            jr nc, an_hi
an_eq:
            ld c, l                 ; |y| <= |x|: at(|y| 32 / |x|)
            ld l, e
            call an_div
            jr an_q
an_hi:
            ld c, e                 ; |y| > |x|: 64 - at(|x| 32 / |y|)
            call an_div
            neg
            add a, 64
an_q:
            ld e, a
            ld a, (an_x + 1)
            bit 7, a
            jr z, an_q1
            ld a, 128
            sub e
            ld e, a
an_q1:
            ld a, (an_y + 1)
            bit 7, a
            ld a, e
            ret z
            neg
            ret
an_div:     ; A = at(L x 32 / C)
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld b, 0
            ld a, -1
an_dl:
            inc a
            or a
            sbc hl, bc
            jr nc, an_dl
            ld hl, an_at
            ld e, a
            ld d, 0
            add hl, de
            ld a, (hl)
            ret
an_at:      db 0, 1, 3, 4, 5, 6, 8, 9, 10, 11, 12, 13, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 25, 26, 27, 28, 29, 29, 30, 31, 31, 32
; o3_bit: HL = 2 ^ L (L: a class, 0 - 15)
o3_bit:
            ld b, l
            ld hl, 1
            inc b
ob_lp:
            dec b
            ret z
            add hl, hl
            jr ob_lp
; o3_hits: after ViewAll - each object whose mask has CL_PLAYER that has just come past you
; (through the view's plane: last z over -60, now 60 or under, both within 9000) within its hit
; box across and up: EV_HIT (it, 255); each one whose mask has other classes against every object
; of those classes: hit boxes overlapping, EV_HIT (it, the other)
o3_hits:
            xor a
            ld (o3_i), a
oh_lp:
            ld a, (o3_i)            ; <--- NEW (as in the step's loop)
            and 7                   ; <--- NEW
            call z, fn_e3_lib_vpoll ; <--- NEW
            call o3_cur
            ld hl, {ocls}
            call o3_rdw
            ld a, l
            or a
            jp z, oh_nx
            ld hl, ({pvwz})
            call o3_rdw
            ld (oh_z), hl
            ld hl, {omask}
            call o3_rdw
            ld (oh_m), hl
            ld a, l
            and 2
            jp z, oh_lz
            ld hl, {olz}            ; lz > -60, z <= 60, lz < 9000, z > -9000
            call o3_rdw
            ld (oh_l), hl
; @if ground
            ld de, (oh_z)           ; <--- NEW: (on the ground: through you either way - from behind
            call o3_scmp            ; <--- NEW  too, backing into it - or in you now) the lower of
            ld hl, (oh_l)           ; <--- NEW  lz and z under 61 and over -9000, the higher over
            ld de, (oh_z)           ; <--- NEW  -60 and under 9000
            jr c, oh_g1             ; <--- NEW
            ex de, hl               ; <--- NEW
oh_g1:                              ; <--- NEW
            ld (oh_mn), hl          ; <--- NEW
            ld (oh_mx), de          ; <--- NEW
            ld de, 61               ; <--- NEW
            call o3_scmp            ; <--- NEW
            jp nc, oh_lz            ; <--- NEW
            ld hl, (oh_mn)          ; <--- NEW
            ld de, -8999            ; <--- NEW
            call o3_scmp            ; <--- NEW
            jp c, oh_lz             ; <--- NEW
            ld hl, (oh_mx)          ; <--- NEW
            ld de, -59              ; <--- NEW
            call o3_scmp            ; <--- NEW
            jp c, oh_lz             ; <--- NEW
            ld hl, (oh_mx)          ; <--- NEW
            ld de, 9000             ; <--- NEW
            call o3_scmp            ; <--- NEW
            jp nc, oh_lz            ; <--- NEW
            jr oh_xy                ; <--- NEW
; @end
            ld de, -59
            call o3_scmp
            jr c, oh_lz
            ld hl, (oh_z)
            ld de, 61
            call o3_scmp
            jr nc, oh_lz
            ld hl, (oh_l)
            ld de, 9000
            call o3_scmp
            jr nc, oh_lz
            ld hl, (oh_z)
            ld de, -8999
            call o3_scmp
            jr c, oh_lz
oh_xy:                              ; <--- NEW
            ld hl, ({pvwx})         ; |x| < w, |y| < h
            call o3_rdw
            bit 7, h
            call nz, o3_neg
            push hl
            ld hl, {ohw}
            call o3_rdw
            ex de, hl
            pop hl
            or a
            sbc hl, de
            jr nc, oh_lz
            ld hl, ({pvwy})
            call o3_rdw
            bit 7, h
            call nz, o3_neg
            push hl
            ld hl, {ohh}
            call o3_rdw
            ex de, hl
            pop hl
            or a
            sbc hl, de
            jr nc, oh_lz
            ld a, 2
            ld e, 255
            call o3_event
oh_lz:
            ld hl, (oh_z)
            ld b, h
            ld c, l
            ld hl, {olz}
            call o3_wrw
            ld hl, (oh_m)           ; other classes
            ld a, l
            and #FC
            or h
            jp z, oh_nx
            call oh_two
oh_nx:
            ld hl, o3_i
            inc (hl)
            ld a, (hl)
            cp {NOBJ}
            jp c, oh_lp
            ret
; oh_two: the object now against every object of a class in its mask (oh_m)
oh_two:
            ld a, (o3_i)
            ld (oh_a), a
            xor a
            call o3_rpos            ; its place and box
            ld (oh_p), hl
            ld a, 2
            call o3_rpos
            ld (oh_p + 2), hl
            ld a, 4
            call o3_rpos
            ld (oh_p + 4), hl
            ld hl, {ohw}
            call o3_rdw
            ld (oh_w), hl
            ld hl, {ohh}
            call o3_rdw
            ld (oh_h), hl
            xor a
            ld (o3_i), a
            ld hl, {ocls}           ; <--- CHANGED (a pointer along ocls, the class's bit from a
            ld (ot_p), hl           ; <--- CHANGED  table: a third of the time it took)
ot_lp:
            ld hl, (ot_p)           ; <--- CHANGED
            ld a, (hl)              ; <--- CHANGED (its class: 0 a free slot)
            inc hl                  ; <--- CHANGED
            inc hl                  ; <--- CHANGED
            ld (ot_p), hl           ; <--- CHANGED
            or a                    ; <--- CHANGED
            jr z, ot_nx             ; <--- CHANGED
            ld c, a                 ; <--- NEW (in the mask? bit c of oh_m)
            and 7                   ; <--- NEW
            ld e, a                 ; <--- NEW
            ld d, 0                 ; <--- NEW
            ld hl, ot_bits          ; <--- NEW
            add hl, de              ; <--- NEW
            ld b, (hl)              ; <--- NEW
            ld a, c                 ; <--- NEW
            and 8                   ; <--- NEW
            ld a, (oh_m)            ; <--- NEW
            jr z, ot_lo             ; <--- NEW
            ld a, (oh_m + 1)        ; <--- NEW
ot_lo:                              ; <--- NEW
            and b                   ; <--- NEW
            jr z, ot_nx             ; <--- NEW
            ld a, (oh_a)            ; <--- CHANGED (not itself)
            ld b, a                 ; <--- CHANGED
            ld a, (o3_i)            ; <--- CHANGED
            cp b                    ; <--- CHANGED
            jr z, ot_nx             ; <--- CHANGED
            call o3_cur             ; <--- CHANGED
            ld hl, {ohw}            ; across: |dx| < w + w'
            call o3_rdw
            ld de, (oh_w)
            add hl, de
            ld (oh_s), hl
            xor a
            call ot_ax
            jr nc, ot_nx
            ld a, 4                 ; along: |dz| < w + w'
            call ot_ax
            jr nc, ot_nx
            ld hl, {ohh}            ; up: |dy| < h + h'
            call o3_rdw
            ld de, (oh_h)
            add hl, de
            ld (oh_s), hl
            ld a, 2
            call ot_ax
            jr nc, ot_nx
            ld a, (o3_i)            ; a hit: (the first object, this one)
            ld e, a
            ld a, (oh_a)
            ld (o3_i), a
            ld a, 2
            call o3_event
            ld a, e
            ld (o3_i), a
ot_nx:
            ld hl, o3_i
            inc (hl)
            ld a, (hl)
            cp {NOBJ}
            jp c, ot_lp
            ld a, (oh_a)
            ld (o3_i), a
            jp o3_cur
ot_bits:    db 1, 2, 4, 8, 16, 32, 64, 128   ; <--- NEW
ot_p:       dw 0                    ; <--- NEW
ot_ax:      ; A = 0, 2, 4: carry when |its - the first's| < oh_s
            push af
            call o3_rpos
            pop af
            push hl
            ld hl, oh_p
            ld e, a
            ld d, 0
            add hl, de
            ld e, (hl)
            inc hl
            ld d, (hl)
            pop hl
            call o3_absd
            ld de, (oh_s)
            or a
            sbc hl, de
            ret
oh_z:       dw 0
oh_m:       dw 0
oh_l:       dw 0
oh_a:       db 0
oh_p:       ds 6
oh_w:       dw 0
oh_h:       dw 0
oh_s:       dw 0
oh_mn:      dw 0                    ; <--- NEW
oh_mx:      dw 0                    ; <--- NEW
an_x:       dw 0
an_y:       dw 0
o3_vb:      dw {ovx}, {ovy}, {ovz}
o3_i:       db 0
o3_o:       dw 0
o3_k:       db 0
o3_dt:      db 0
o3_mv:      db 0
o3_fl:      db 0
o3_st:      db 0
o3_ph:      dw 0
o3_cam:     ds 6
o3_pv:      ds 6
o3_hf:      ds 6
o3_d:       dw 0
o3_dd:      dw 0
o3_ox:      dw 0
o3_oy:      dw 0
o3_cc:      dw 0
o3_tx:      ds 6
o3_f:       ds 6
o3_fa:      db 0
o3_vm:      dw 0
o3_t2:      dw 0
o3_t3:      dw 0
o3_t4:      dw 0
#endasm
End Sub
