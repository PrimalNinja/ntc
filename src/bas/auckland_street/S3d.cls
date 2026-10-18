' S3d: STATE3D's engine - a real place to fly over, from an S3D data file (tools/s3dmake: OSM
' data cut into 384 m tiles, packed in 16K blocks) held in the expansion RAM: its buildings (their
' outlines pushed up to their heights), roads (major ones as two lines), railways, coast, water,
' piers, trees (a trunk and a crown), and landmarks as 3D lines (the Sky Tower, the Harbour
' Bridge, the volcanoes) seen from further away. Freescape-style lines - THIS COPY (auckland_street,
' from auckland_mask - walking at street level: no roll, its height kept, looking up / down):
' the walls' masks (S3D2 data, s3dmake's masks): a wall facing away from the camera isn't drawn;
' as CITY3D (bas/city3d: the camera, the clipping and the projection are its, unchanged).
' The tiles round the camera (7 x 7, nearest first) are drawn: big buildings to 1.9 km, middle
' ones to 1 km, small ones to 400 m (all their edges to 200 m, the top and the uprights to 600
' m, then the top), minor roads to 800 m, trees to 350 m - and no more than the line budget
' (SetBudget) in a frame; the landmark tiles to 3.5 km (Rangitoto, the Sky Tower, the Harbour Bridge to 11 km). Each tile's block is put in the window (#4000) while
' it is read; the Graphics class puts main RAM back there while it draws (the second screen).
' World units: 0.5 m (x east, z north, y up). Main RAM #8F50-#A2EF: its tables (Option Reserve
' &H8F50, &H13A0 - under the ROMs' RAM: UniDOS with an IDE node takes #A309 up, its event block
' 16 below); the program goes on at #8000 when it is past #4000, the Memory class's tables
' after it).
' All the work is Z80 (#asm). Platform: cpcfw (the Graphics class, the firmware's file calls);
' zxn, the ZX Spectrum Next (IFDEF NTC_ZXN / #If NTC_ZXN): the blocks are 16K banks the NEX file
' loaded (Option NexData), put in #4000 by zxn_sel; the Graphics class draws on Layer 2.
Option Explicit
Private bas(8) As Integer                     ' right (0-2), up (3-5), forward (6-8): 16384 = 1.0
Private qx As Long, qy As Long, qz As Long    ' where the camera is: world units * 16384
Private camx As Integer, camy As Integer, camz As Integer
Private rp As Integer, rr As Integer, ry As Integer, spd As Integer
Private sps As Integer
Private pg(255) As Integer                    ' the data's pages: 0 block 0 (the directory), b block b
Private nx As Integer, nz As Integer, x0 As Integer, z0 As Integer, x1 As Integer, z1 As Integer
Private lmf As Integer
Private mvo As Integer                        ' 1: Render only moves the camera (Move)
Private cnx As Integer, cnz As Integer        ' the city's centre (world units): the compass points there
Private dro As Integer, nlm As Integer, lmax As Integer, nlines As Integer, cjf As Integer
Private Const TX = &H8F50           ' 256 x 6: a local x's (2 m steps, signed) camera X, Y, Z
Private Const TZ = &H9550           ' ... a local z's
Private Const TH = &H9B50           ' 192 x 6: a height's (2 m steps, 0-191: 382 m)
Private Const LMT = &H9FD0          ' the landmark tiles: ti, tj (a byte each), up to 256
Private Const VTX = &HA1D0          ' vertices, 12 bytes each: 12 a building's ground, 12 its top (12 points at most)
Public Const LANDMARKS = 256

' SetPage(i, page): block i of the data is in RAM page page
Public Sub SetPage(ByVal i As Integer, ByVal page As Integer)
  pg(i) = page
End Sub

' SetLandmark(i, ti, tj): landmark tile i (ti + 128: a far one - drawn to 11 km, not 3.5)
Public Sub SetLandmark(ByVal i As Integer, ByVal ti As Integer, ByVal tj As Integer)
  Poke LMT + i * 2, ti
  Poke LMT + i * 2 + 1, tj
End Sub

' Setup: the world (tiles across, north; its south-west corner in world units; block 0's
' directory offset; landmark tiles), the camera at sx, sz, 120 m up, looking north
Public Sub Setup(ByVal ntx As Integer, ByVal ntz As Integer, ByVal wx As Integer, ByVal wz As Integer, ByVal doff As Integer, ByVal lms As Integer, ByVal sx As Integer, ByVal sz As Integer)
  nx = ntx : nz = ntz : x0 = wx : z0 = wz : dro = doff : nlm = lms
  x1 = x0 + nx * 768 : z1 = z0 + nz * 768
  bas(0) = 16384 : bas(4) = 16384 : bas(8) = 16384
  qx = CLng(sx) * 16384
  qy = CLng(240) * 16384
  qz = CLng(sz) * 16384
  lmax = 1800
End Sub

' Place x, z, height (world units), fx, fz (the way to look, level: 16384 = 1): the camera there
Public Sub Place(ByVal px As Integer, ByVal pz As Integer, ByVal ph As Integer, ByVal fx As Integer, ByVal fz As Integer)
  bas(0) = fz : bas(1) = 0 : bas(2) = -fx
  bas(3) = 0 : bas(4) = 16384 : bas(5) = 0
  bas(6) = fx : bas(7) = 0 : bas(8) = fz
  qx = CLng(px) * 16384
  qy = CLng(ph) * 16384
  qz = CLng(pz) * 16384
End Sub

' SetBudget(n): lines tried a frame at most (1800 to start with)
Public Sub SetBudget(ByVal n As Integer)
  lmax = n
End Sub

' Steer pitch, roll, yaw, speed: for the next Render. pitch 1 = climb, -1 = dive; roll 1 =
' right wing down; yaw 1 = right (each 2 degrees a frame, 0 = none); speed in units a frame
Public Sub Steer(ByVal pitch As Integer, ByVal roll As Integer, ByVal yaw As Integer, ByVal speed As Integer)
  rp = pitch : rr = roll : ry = yaw : spd = speed
End Sub

' Level(): looking straight ahead again (level: up straight up, forward the way it faces)
Public Sub Level()
  bas(6) = -bas(2) : bas(7) = 0 : bas(8) = bas(0)
  bas(3) = 0 : bas(4) = 16384 : bas(5) = 0
End Sub

' Move(): the camera turned and moved as a frame does (Steer's turns, its speed) - for frames
' skipped (Render does it once itself)
Public Sub Move()
  mvo = 1 : Render : mvo = 0
End Sub

' SetCentre(x, z): the city's centre (world units) - the compass points there
Public Sub SetCentre(ByVal x As Integer, ByVal z As Integer)
  cnx = x : cnz = z
End Sub

' Basis(i): the camera's axes, 16384 = 1: right x, y, z (0-2), up (3-5), forward (6-8) - z north
Public Function Basis(ByVal i As Integer) As Integer
  Basis = bas(i)
End Function

' Altitude(): metres
Public Function Altitude() As Integer
  Altitude = camy \ 2
End Function

' Lines(): the lines the last frame tried
Public Function Lines() As Integer
  Lines = nlines
End Function

' Fast(): True when the data is read with UniDOS's block read (else a byte at a time)
Public Function Fast() As Integer
  Fast = (cjf = 1)
End Function

' Load(page): the next 16K of the file being read (FileSystem.Open ForReadRaw) into RAM page
' page: the bytes read. UniDOS: its block read (Ctrl J 5), else CAS IN CHAR a byte at a time
Public Function Load(ByVal page As Integer) As Integer
#asm
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ld hl, ({page})
            call mem_sel
            ei
            ld a, ({cjf})
            or a
            jr nz, ld_have
            ld hl, ld_cjn               ; UniDOS's Ctrl J (once)
            call #BCD4                  ; KL FIND COMMAND
            ld a, 2
            jr nc, ld_set
            ld (ld_cj), hl
            ld a, c
            ld (ld_cj + 2), a
            ld a, 1
ld_set:
            ld ({cjf}), a
ld_have:
            cp 1
            jr nz, ld_char
            ld hl, #4000
            ld de, 16384
            ld c, 5                     ; cmd_cas_in_read
            rst #18
            dw ld_cj
            jr nc, ld_char0             ; (not done: a byte at a time)
            jr nz, ld_zero
            ex de, hl
            jr ld_done
ld_char0:
            ld a, 2
            ld ({cjf}), a
ld_char:
            ld hl, #4000
            ld bc, 0
ld_ch_lp:
            push hl
            push bc
            call #BC80                  ; CAS IN CHAR
            pop bc
            pop hl
            jr c, ld_ch_put
            cp #1A                      ; (a #1A: the soft end of file - a byte, read on)
            jr nz, ld_ch_end
ld_ch_put:
            ld (hl), a
            inc hl
            inc bc
            bit 7, h
            jr z, ld_ch_lp              ; to #8000
ld_ch_end:
            ld h, b
            ld l, c
            jr ld_done
ld_zero:
            ld hl, 0
ld_done:
            di
            ld ({result}), hl
            ld sp, ({sps})
            ret
ld_cjn:     db #8A
ld_cj:      ds 3                        ; (cjf: 0 not looked for, 1 UniDOS, 2 a byte at a time)
#endasm
End Function

' Inks: pen 1 white (buildings, roads, the landmarks), 2 green (trees, volcanoes), 3 cyan
' (coast, water), black paper and border
Public Sub Inks()
#If NTC_ZXN Then
#asm
            ld bc, #243B            ; the Next: Layer 2's first palette, entries 0-3 (RRRGGGBB)
            ld a, #43
            out (c), a
            inc b
            ld a, #10               ; (writes go to Layer 2's first palette, the index moving on)
            out (c), a
            dec b
            ld a, #40
            out (c), a
            inc b
            xor a
            out (c), a
            dec b
            ld a, #41
            out (c), a
            inc b
            xor a                   ; 0 black
            out (c), a
            ld a, #FF               ; 1 white
            out (c), a
            ld a, #1C               ; 2 green
            out (c), a
            ld a, #1F               ; 3 cyan
            out (c), a
#endasm
#Else
#asm
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ei
            xor a
            ld bc, 0
            call #BC32                  ; SCR SET INK
            ld a, 1
            ld bc, #1A1A
            call #BC32
            ld a, 2
            ld bc, #1212
            call #BC32
            ld a, 3
            ld bc, #1414
            call #BC32
            ld bc, 0
            call #BC38                  ; SCR SET BORDER
            di
            ld sp, ({sps})
#endasm
#End If
End Sub

' Window(page): block page's RAM page in the window (#4000-#7FFF) - the Next: its 16K bank
Public Sub Window(ByVal page As Integer)
#asm
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ld hl, ({page})
    IFDEF NTC_ZXN
            call zxn_sel
    ELSE
            call mem_sel
    ENDIF
            ld sp, ({sps})
#endasm
End Sub

' ProgramEnd(): the first byte after the program and its variables
Public Function ProgramEnd() As Integer
#asm
            pop hl
            ld de, ntc_free
            ld (hl), e
            inc hl
            ld (hl), d
#endasm
End Function

Public Sub Render()
#asm
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ei                      ; interrupts in while it works (the real stack): the
                                    ; clock keeps counting, in turbo too
            call r_turn
            call r_tidy
            call r_fly
            ld a, ({mvo})           ; (Move: no more)
            or a
            jr nz, rn_end
            call r_tabs
            call r_clear
            call r_world
            ld hl, (w_nl)
            ld de, (w_nlm)
            add hl, de
            ld ({nlines}), hl
            ld hl, 0
    IFDEF NTC_ZXN
            call zxn_sel            ; (the Next: the program's own pages back in the window)
    ELSE
            call mem_sel            ; main RAM back in the window
    ENDIF
            call r_comp
rn_end:
            di
            ld sp, ({sps})
            ret

; ---- the compass: an arrow at (296, 182) pointing to the city's centre (SetCentre) as seen
; from above (up the screen: ahead). The way there (centre - camera, scaled up to 8192-16383)
; across (on the right axis) and ahead (on the forward axis), scaled so the larger is 64-127,
; then / 8: the arrow's half length 8-15 pixels. Pen 3. None at the centre itself
r_comp:
            ld hl, ({cnx})
            ld de, ({camx})
            or a
            sbc hl, de
            ld (w_dx), hl
            ld hl, ({cnz})
            ld de, ({camz})
            or a
            sbc hl, de
            ld (w_dz), hl
            ld b, 15
cp_vn:
            ld hl, (w_dx)           ; both under 8192: doubled
            call cp_ab16
            ld c, h
            ld hl, (w_dz)
            call cp_ab16
            ld a, h
            or c
            and #E0
            jr nz, cp_vk
            ld hl, (w_dx)
            add hl, hl
            ld (w_dx), hl
            ld hl, (w_dz)
            add hl, hl
            ld (w_dz), hl
            djnz cp_vn
            ret                     ; (there: no arrow)
cp_vk:
            ld de, ({bas})          ; across: right x * dx + right z * dz, / 65536
            ld bc, ({bas} + 4)
            call cp_dot
            call cp_s7
            ld (w_va), a
            ld de, ({bas} + 12)     ; ahead: forward x * dx + forward z * dz
            ld bc, ({bas} + 16)
            call cp_dot
            call cp_s7
            ld (w_vb), a
            ld b, 6
cp_nm:
            ld a, (w_va)
            call cp_abs
            ld c, a
            ld a, (w_vb)
            call cp_abs
            or c
            and #C0
            jr nz, cp_go            ; (the larger is 64 or more)
            ld a, (w_va)
            add a, a
            ld (w_va), a
            ld a, (w_vb)
            add a, a
            ld (w_vb), a
            djnz cp_nm
            ret                     ; (both 0: looking straight up or down)
cp_go:
            ld a, (w_va)
            sra a
            sra a
            sra a
            ld (w_va), a            ; dx
            ld a, (w_vb)
            sra a
            sra a
            sra a
            ld (w_vb), a            ; dz
            ld a, 3
            ld (gfx_pen), a
            ld a, (w_va)            ; the shaft: (296 - dx, 182 + dz) - (296 + dx, 182 - dz)
            neg
            call cp_x
            ld (gfx_x0), hl
            ld a, (w_vb)
            call cp_y
            ld (gfx_y0), hl
            call cp_tip
            call gfx_line
            ld a, (w_vb)            ; the head: the tip to (296 + dx/2 -+ dz/2, 182 - dz/2 -+ dx/2)
            sra a
            ld c, a
            ld a, (w_va)
            sra a
            ld b, a
            push bc
            sub c
            call cp_x
            ld (gfx_x0), hl
            pop bc
            push bc
            ld a, c
            add a, b
            neg
            call cp_y
            ld (gfx_y0), hl
            call cp_tip
            call gfx_line
            pop bc
            ld a, b
            add a, c
            call cp_x
            ld (gfx_x0), hl
            ld a, b
            sub c
            call cp_y
            ld (gfx_y0), hl
            call cp_tip
            jp gfx_line
; cp_tip - the line's other end: the tip (296 + dx, 182 - dz)
cp_tip:
            ld a, (w_va)
            call cp_x
            ld (gfx_x1), hl
            ld a, (w_vb)
            neg
            call cp_y
            ld (gfx_y1), hl
            ret
; cp_x / cp_y - HL = 296 / 182 + A (signed)
cp_x:
            ld hl, 296
            jr cp_add
cp_y:
            ld hl, 182
cp_add:
            ld e, a
            rlca
            sbc a, a
            ld d, a
            add hl, de
            ret
; cp_s7 - A = HL / 128 (signed), kept to -127 .. 127
cp_s7:
            bit 7, h                ; (Z: positive - add hl, hl keeps Z)
            add hl, hl              ; H = HL / 128
            ld a, h
            jr nz, cs_neg
            cp 128
            ret nz
            ld a, 127               ; (+16384: 127)
            ret
cs_neg:
            cp 128
            ret nz
            ld a, 129               ; (-16384: -127)
            ret
; cp_dot - HL = (DE * dx + BC * dz) / 65536
cp_dot:
            push bc
            ld bc, (w_dx)
            call mul16s
            pop bc
            push de
            push hl
            ld de, (w_dz)
            call mul16s
            pop bc
            add hl, bc
            pop bc
            ex de, hl
            adc hl, bc
            ret
; cp_ab16 - HL = |HL|
cp_ab16:
            bit 7, h
            ret z
            xor a
            sub l
            ld l, a
            sbc a, a
            sub h
            ld h, a
            ret
; cp_abs - A = |A|
cp_abs:
            or a
            ret p
            neg
            ret

; ---- the camera

; r_turn - the turns asked for, 2 degrees each (AUCKLAND_STREET: no roll; looking up / down -
; rp, forward towards up, to 78 degrees either way; turning - ry - round the world's up, not the
; camera's: the right axis stays level)
r_turn:
            ld a, ({rp})
            or a
            jr z, rt_y
            ld hl, ({bas} + 14)     ; (forward's height: 78 degrees up or down at most)
            bit 7, a
            jr nz, rt_dn
            ld de, 16000
            call cmps
            jr nc, rt_y
            jr rt_p
rt_dn:
            ld de, -16000
            ex de, hl
            call cmps
            jr nc, rt_y
rt_p:
            ld a, ({rp})
            ld ix, {bas} + 12       ; look up: forward towards up
            ld iy, {bas} + 6
            call rt_s
            call r_pair
rt_y:
            ld a, ({ry})
            or a
            ret z
            call rt_s               ; turn right: each axis's x, z turned (x cos + z sin, z cos - x sin)
            ld ix, {bas}
            call ry_v
            ld ix, {bas} + 6
            call ry_v
            ld ix, {bas} + 12
ry_v:
            ld e, (ix + 0)
            ld d, (ix + 1)
            ld (w_a), de
            ld e, (ix + 4)
            ld d, (ix + 5)
            ld (w_b), de
            ld de, (w_a)
            ld bc, 16374            ; cos 2 degrees
            call mulfix
            ld (w_t), hl
            ld de, (w_b)
            ld bc, (w_rs)
            call mulfix
            ld de, (w_t)
            add hl, de
            ld (ix + 0), l
            ld (ix + 1), h
            ld de, (w_b)
            ld bc, 16374
            call mulfix
            ld (w_t), hl
            ld de, (w_a)
            ld bc, (w_rs)
            call mulfix
            ex de, hl
            ld hl, (w_t)
            or a
            sbc hl, de
            ld (ix + 4), l
            ld (ix + 5), h
            ret
rt_s:
            ld hl, 572              ; sin 2 degrees
            bit 7, a
            jr z, rt_s1
            ld hl, -572
rt_s1:
            ld (w_rs), hl
            ret
; r_pair - IX = A, IY = B (vectors): A = A cos + B sin, B = B cos - A sin
r_pair:
            ld b, 3
rp_lp:
            push bc
            ld e, (ix + 0)
            ld d, (ix + 1)
            ld (w_a), de
            ld e, (iy + 0)
            ld d, (iy + 1)
            ld (w_b), de
            ld de, (w_a)
            ld bc, 16374            ; cos 2 degrees
            call mulfix
            ld (w_t), hl
            ld de, (w_b)
            ld bc, (w_rs)
            call mulfix
            ld de, (w_t)
            add hl, de
            ld (ix + 0), l
            ld (ix + 1), h
            ld de, (w_b)
            ld bc, 16374
            call mulfix
            ld (w_t), hl
            ld de, (w_a)
            ld bc, (w_rs)
            call mulfix
            ex de, hl
            ld hl, (w_t)
            or a
            sbc hl, de
            ld (iy + 0), l
            ld (iy + 1), h
            inc ix
            inc ix
            inc iy
            inc iy
            pop bc
            djnz rp_lp
            ret

; r_tidy - right level and of length 1, forward square to it and of length 1, up = forward x
; right (AUCKLAND_STREET: right first - it stays level, no roll)
r_tidy:
            ld hl, 0
            ld ({bas} + 2), hl
            ld ix, {bas}
            call r_unit
            ld ix, {bas} + 12
            ld iy, {bas}
            call r_dot
            ld (w_t), hl            ; forward . right
            ld b, 3
td_lp:
            push bc
            ld e, (iy + 0)
            ld d, (iy + 1)
            ld bc, (w_t)
            call mulfix
            ex de, hl
            ld l, (ix + 0)
            ld h, (ix + 1)
            or a
            sbc hl, de
            ld (ix + 0), l
            ld (ix + 1), h
            inc ix
            inc ix
            inc iy
            inc iy
            pop bc
            djnz td_lp
            ld ix, {bas} + 12
            call r_unit
            ld de, ({bas} + 14)     ; up x = Fy Rz - Fz Ry
            ld bc, ({bas} + 4)
            call mulfix
            ld (w_t), hl
            ld de, ({bas} + 16)
            ld bc, ({bas} + 2)
            call mulfix
            ex de, hl
            ld hl, (w_t)
            or a
            sbc hl, de
            ld ({bas} + 6), hl
            ld de, ({bas} + 16)     ; up y = Fz Rx - Fx Rz
            ld bc, ({bas})
            call mulfix
            ld (w_t), hl
            ld de, ({bas} + 12)
            ld bc, ({bas} + 4)
            call mulfix
            ex de, hl
            ld hl, (w_t)
            or a
            sbc hl, de
            ld ({bas} + 8), hl
            ld de, ({bas} + 12)     ; up z = Fx Ry - Fy Rx
            ld bc, ({bas} + 2)
            call mulfix
            ld (w_t), hl
            ld de, ({bas} + 14)
            ld bc, ({bas})
            call mulfix
            ex de, hl
            ld hl, (w_t)
            or a
            sbc hl, de
            ld ({bas} + 10), hl
            ret
; r_dot - HL = (IX) . (IY), vectors of 3
r_dot:
            ld e, (ix + 0)
            ld d, (ix + 1)
            ld c, (iy + 0)
            ld b, (iy + 1)
            call mulfix
            ld (w_d), hl
            ld e, (ix + 2)
            ld d, (ix + 3)
            ld c, (iy + 2)
            ld b, (iy + 3)
            call mulfix
            ld de, (w_d)
            add hl, de
            ld (w_d), hl
            ld e, (ix + 4)
            ld d, (ix + 5)
            ld c, (iy + 4)
            ld b, (iy + 5)
            call mulfix
            ld de, (w_d)
            add hl, de
            ret
; r_unit - (IX) scaled to length 1: times (3 - |v|^2) / 2 (close to 1 already)
r_unit:
            push ix
            pop iy
            call r_dot
            sra h
            rr l
            ex de, hl
            ld hl, 24576
            or a
            sbc hl, de
            ld (w_k), hl
            ld b, 3
ru_lp:
            push bc
            ld e, (ix + 0)
            ld d, (ix + 1)
            ld bc, (w_k)
            call mulfix
            ld (ix + 0), l
            ld (ix + 1), h
            inc ix
            inc ix
            pop bc
            djnz ru_lp
            ret


; r_fly - the camera moved ahead by spd - level, the way it faces (right turned: -right z, right
; x), whichever way it looks (AUCKLAND_STREET walks: its height stays); kept inside the world
r_fly:
            ld ix, {qx}
            ld hl, ({bas} + 4)
            call hneg
            ex de, hl
            call fl_add
            ld ix, {qz}
            ld de, ({bas})
            call fl_add
            ld ix, {qx}
            ld hl, ({x0})
            ld de, 64
            add hl, de
            ex de, hl
            ld hl, ({x1})
            ld bc, -64
            add hl, bc
            call fl_clamp
            ld ({camx}), de
            ld ix, {qz}
            ld hl, ({z0})
            ld de, 64
            add hl, de
            ex de, hl
            ld hl, ({z1})
            ld bc, -64
            add hl, bc
            call fl_clamp
            ld ({camz}), de
            ld ix, {qy}
            ld de, 2
            ld hl, 4000
            call fl_clamp
            ld ({camy}), de
            ret
; fl_clamp - (IX), a Long, / 16384 kept from DE to HL (signed): DE = it, (IX) set to it * 16384
; when it was outside
fl_clamp:
            ld (w_lo), de
            ld (w_hi), hl
            call fl_w
            push de
            ex de, hl
            ld de, (w_lo)
            call cmps
            pop de
            jr c, fc_set0
            push de
            ld hl, (w_hi)
            call cmps                 ; hi < it?
            pop de
            ret nc
            ld de, (w_hi)
            jr fc_set
fc_set0:
            ld de, (w_lo)
fc_set:
            ld (ix + 0), 0            ; it * 16384: low word (it & 3) << 14, high word it >> 2
            ld a, e
            rrca
            rrca
            and #C0
            ld (ix + 1), a
            ld l, e
            ld h, d
            sra h
            rr l
            sra h
            rr l
            ld (ix + 2), l
            ld (ix + 3), h
            ret
; fl_add - (IX), a Long, + DE * spd
fl_add:
            ld bc, ({spd})
            call mul16s
            ld a, (ix + 0)
            add a, l
            ld (ix + 0), a
            ld a, (ix + 1)
            adc a, h
            ld (ix + 1), a
            ld a, (ix + 2)
            adc a, e
            ld (ix + 2), a
            ld a, (ix + 3)
            adc a, d
            ld (ix + 3), a
            ret
; fl_w - DE = (IX), a Long, / 16384
fl_w:
            ld l, (ix + 0)
            ld h, (ix + 1)
            ld e, (ix + 2)
            ld d, (ix + 3)
            add hl, hl
            rl e
            rl d
            add hl, hl
            rl e
            rl d
            ret

; ---- the frame's tables: a local x's, z's and height's camera X, Y, Z (a vertex is then
; six additions). Each step is 2 m (4 units): its number = basis * k / 4096, built by adding
; basis / 16 (in 1/256 units, 24 bits) each step

r_tabs:
            ld iy, {bas}            ; {TX}: x - R.x, U.x, F.x (bas + 0, 6, 12)
            ld ix, {TX}
            ld a, 1
            call tb_three
            ld iy, {bas} + 4        ; {TZ}: z
            ld ix, {TZ}
            ld a, 1
            call tb_three
            ld iy, {bas} + 2        ; {TH}: y (heights: 0 - 191)
            ld ix, {TH}
            xor a
; tb_three - the three numbers of each entry from IX: the basis at IY, IY + 6, IY + 12; A = 1
; signed (entry 128 is -128)
tb_three:
            ld (w_sgn), a
            ld b, 3
t3_lp:
            push bc
            push ix
            ld e, (iy + 0)
            ld d, (iy + 1)
            call tb_one
            pop ix
            inc ix
            inc ix
            ld de, 6
            add iy, de
            pop bc
            djnz t3_lp
            ret
; tb_one - DE = the basis number: 256 entries from IX (6 bytes apart)
tb_one:
            ld l, e                 ; v = basis / 16
            ld h, d
            sra h
            rr l
            sra h
            rr l
            sra h
            rr l
            sra h
            rr l
            ld (w_v), hl
            ld a, (w_sgn)
            or a
            jr z, to_u
            push ix                 ; signed: entries 128-255 (k = -128 .. -1) from -128 v
            ld de, 768
            add ix, de
            ld de, (w_v)
            ld bc, -128
            call mul16s             ; DEHL = -128 v: its low 24 bits
            ld (w_acc), hl
            ld a, e
            ld (w_acc + 2), a
            ld a, 128
            call tb_run
            pop ix
            ld hl, 0
            ld (w_acc), hl
            xor a
            ld (w_acc + 2), a
            ld a, 128
            jp tb_run
to_u:
            ld hl, 0
            ld (w_acc), hl
            ld (w_acc + 2), a
            ld a, 128
            call tb_run
            ld a, 64                ; (heights: 192 entries)
; tb_run - A entries from IX: (acc >> 8), acc + v each
tb_run:
            ld (w_cnt), a
            ld de, (w_v)
            ld a, d
            rlca
            sbc a, a
            ld c, a                 ; C = v's sign (its top 8 bits)
            ld hl, (w_acc)
            ld a, (w_acc + 2)
            ld b, a
tr_lp:
            ld (ix + 0), h
            ld (ix + 1), b
            add hl, de
            ld a, b
            adc a, c
            ld b, a
            push de
            ld de, 6
            add ix, de
            pop de
            ld a, (w_cnt)
            dec a
            ld (w_cnt), a
            jr nz, tr_lp
            ld (w_acc), hl
            ld a, b
            ld (w_acc + 2), a
            ret

; r_clear - rows 1-24 of the screen being drawn on cleared (row 0 is the text line)
r_clear:
    IFDEF NTC_ZXN
            jp zxn_gclr             ; (the Next: the Layer 2 buffer drawn on - all of it: the text is on
    ENDIF                           ; the tilemap, over it)
            di                      ; SP goes through the screen: no interrupts meanwhile
            call gfx_begin
            ld (w_csp), sp
            ld a, (gfx_base)
            add a, #3F
            ld h, a
            ld l, #D0               ; the end of the last 2K block's 25 rows
            ld c, 8
cl_blk:
            ld (w_crp), hl
            ld sp, (w_crp)
            ld de, 0
            ld b, 60                ; 60 x 32 bytes = 1920: rows 1-24
cl_lp:
            push de
            push de
            push de
            push de
            push de
            push de
            push de
            push de
            push de
            push de
            push de
            push de
            push de
            push de
            push de
            push de
            djnz cl_lp
            ld a, h
            sub 8
            ld h, a
            dec c
            jr nz, cl_blk
            ld sp, (w_csp)
            call gfx_end
            ei
            ret


; ---- the world: the landmark tiles further away (only their 3D lines), then the tiles round
; the camera, nearest first

r_world:
            ld hl, 0
            ld (w_nl), hl
            xor a
            ld (w_stop), a
            ld hl, ({camx})         ; the camera's tile
            ld de, ({x0})
            or a
            sbc hl, de
            call d768
            ld (w_ci), a
            ld hl, ({camz})
            ld de, ({z0})
            or a
            sbc hl, de
            call d768
            ld (w_cj), a
            ld a, 1                 ; the landmarks: 4 to 9 tiles away (the far ones to 29)
            ld (w_mode), a
            ld hl, {LMT}
            ld bc, ({nlm})
rw_lm:
            ld a, b
            or c
            jr z, rw_near
            push bc
            ld a, (hl)
            and 128
            ld ({lmf}), a           ; (bit 7: a far one - to 29 tiles)
            ld a, (hl)
            and 127
            ld (w_ti), a
            inc hl
            ld a, (hl)
            ld (w_tj), a
            inc hl
            push hl
            ld a, (w_ti)
            ld hl, w_ci
            call rw_far             ; A = how far (tiles), the most of the two
            ld b, a
            ld a, (w_tj)
            ld hl, w_cj
            call rw_far
            cp b
            jr nc, rw_lm1
            ld a, b
rw_lm1:
            cp 4
            jr c, rw_lm2
            ld c, a
            ld a, ({lmf})
            or a
            ld a, c
            jr z, rw_lm3
            cp 30                   ; far: to 29 tiles (11 km: the tile's middle stays in 16 bits)
            call c, tl_one
            jr rw_lm2
rw_lm3:
            cp 10
            call c, tl_one
rw_lm2:
            pop hl
            pop bc
            dec bc
            jr rw_lm
rw_near:
            ld hl, (w_nl)           ; (the landmarks' lines: not in the budget)
            ld (w_nlm), hl
            ld hl, 0
            ld (w_nl), hl
            xor a
            ld (w_mode), a
            ld hl, rw_ring
            ld b, 49
rw_lp:
            push bc
            ld a, (w_ci)
            add a, (hl)
            ld (w_ti), a
            inc hl
            ld a, (w_cj)
            add a, (hl)
            ld (w_tj), a
            inc hl
            push hl
            call tl_one
            pop hl
            pop bc
            ld a, (w_stop)
            or a
            ret nz
            djnz rw_lp
            ret
; rw_far - A = |A - (HL)|
rw_far:
            sub (hl)
            ret nc
            neg
            ret
; d768 - A = HL / 768 (HL 0 - 32767)
d768:
            ld a, h
            ld c, 0
dv3_lp:
            sub 3
            jr c, dv3_e
            inc c
            jr dv3_lp
dv3_e:
            ld a, c
            ret
; the 7 x 7 tiles round the camera's, nearest first (di, dj)
rw_ring:    db 0, 0, 255, 0, 0, 255, 0, 1, 1, 0, 255, 255, 255, 1, 1, 255, 1, 1, 254, 0, 0, 254, 0, 2, 2, 0, 254, 255, 254, 1, 255, 254, 255, 2, 1, 254, 1, 2, 2, 255, 2, 1, 254, 254, 254, 2, 2, 254, 2, 2
            db 253, 0, 0, 253, 0, 3, 3, 0, 253, 255, 253, 1, 255, 253, 255, 3, 1, 253, 1, 3, 3, 255, 3, 1, 253, 254, 253, 2, 254, 253, 254, 3, 2, 253, 2, 3, 3, 254, 3, 2, 253, 253, 253, 3, 3, 253, 3, 3

; tl_one - the tile (w_ti, w_tj): w_mode 0 all of it that its distance allows, 1 its 3D lines
tl_one:
            ld a, (w_ti)            ; in the world?
            ld hl, {nx}
            cp (hl)
            ret nc
            ld a, (w_tj)
            ld hl, {nz}
            cp (hl)
            ret nc
            ld a, (w_ti)            ; its middle from the camera: dx, dy, dz
            ld de, ({x0})
            call tl_mid
            ld de, ({camx})
            or a
            sbc hl, de
            ld (w_dx), hl
            ld a, (w_tj)
            ld de, ({z0})
            call tl_mid
            ld de, ({camz})
            or a
            sbc hl, de
            ld (w_dz), hl
            ld hl, ({camy})
            call hneg
            ld (w_dy), hl
            ld iy, {bas} + 12       ; Z (forward)
            call tl_dot
            ld (w_tz), hl
            ld de, -600             ; behind
            call cmps
            ret c
            ld a, (w_mode)
            or a
            jr nz, tl_z1
            ld hl, (w_tz)
            ld de, 3800             ; too far (1.9 km)
            call cmps
            ret nc
tl_z1:
            ld iy, {bas}            ; X (right)
            call tl_dot
            ld (w_tx), hl
            call habs               ; off to the side: |X| - Z > 900
            ld de, (w_tz)
            or a
            sbc hl, de
            ld de, 900
            call cmps
            ret nc
            ld iy, {bas} + 6        ; Y (up)
            call tl_dot
            ld (w_ty), hl
            ld a, (w_tj)            ; the directory: block, offset
            ld l, a
            ld h, 0
            ld de, ({nx})
            call mul8x16            ; HL = tj * nx
            ld a, (w_ti)
            ld e, a
            ld d, 0
            add hl, de
            ld e, l
            ld d, h
            add hl, hl
            add hl, de              ; * 3
            ld de, ({dro})
            add hl, de
            ld de, #4000
            add hl, de
            push hl
            ld hl, ({pg})
    IFDEF NTC_ZXN
            call zxn_sel            ; (the Next: its 16K bank in #4000-#7FFF)
    ELSE
            call mem_sel
    ENDIF
            pop hl
            ld a, (hl)
            or a
            ret z                   ; nothing there
            inc hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld hl, #4000
            add hl, de
            ld (w_tb), hl
            ld l, a                 ; (its page: pg(block) - a word each, blocks up to 255)
            ld h, 0
            add hl, hl
            ld de, {pg}
            add hl, de
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
    IFDEF NTC_ZXN
            call zxn_sel            ; its block in the window (the Next: its 16K bank)
    ELSE
            call mem_sel            ; its block in the window
    ENDIF
            ld hl, (w_nl)           ; the tile's share of the frame's lines: a quarter of the budget
            ld de, ({lmax})
            srl d
            rr e
            srl d
            rr e
            add hl, de
            ld (w_tcap), hl
            ld a, (w_mode)
            or a
            jp nz, tl_3d
            ; the buildings: big ones always, middle ones nearer than 1.2 km, small than 650 m
            ld ix, (w_tb)
            ld l, (ix + 0)
            ld h, (ix + 1)
            ld de, (w_tz)
            push hl
            ld hl, 2000
            call cmps
            pop hl
            jr c, tl_bn             ; (2000 < Z: big ones only)
            ld e, (ix + 2)
            ld d, (ix + 3)
            add hl, de
            push hl
            ld hl, (w_tz)
            ld de, 800
            call cmps
            pop hl
            jr nc, tl_bn
            ld e, (ix + 4)
            ld d, (ix + 5)
            add hl, de
tl_bn:
            ld (w_cnt2), hl
            ld hl, (w_tz)           ; the buildings' edges: all nearer than 300 m; the top and the
            ld de, 400              ; uprights to 600 m; further only the top
            call cmps
            ld a, 3
            jr c, tl_lod
            ld hl, (w_tz)
            ld de, 1200
            call cmps
            ld a, 2
            jr c, tl_lod
            xor a
tl_lod:
            ld (w_lod), a
            ld hl, (w_tb)
            ld de, 16
            add hl, de
            ld (w_p), hl
            ld a, 1
            ld (gfx_pen), a
tl_b_lp:
            ld hl, (w_cnt2)
            ld a, h
            or l
            jr z, tl_lines
            dec hl
            ld (w_cnt2), hl
            call tl_budget
            jr c, tl_bcap
            call b_one
            jr tl_b_lp
tl_bcap:
            ld a, (w_stop)          ; the frame's lines used up: done; the tile's share: on to
            or a                    ; its lines (and its 3D lines)
            ret nz
            ; the ground lines: all nearer than 800 m, else not the minor roads; none past 1.5 km
tl_lines:
            ld hl, (w_tz)
            ld de, 3000
            call cmps
            jp nc, tl_3d
            ld ix, (w_tb)
            ld l, (ix + 0)          ; the start of the lines: past all the buildings
            ld h, (ix + 1)
            ld e, (ix + 2)
            ld d, (ix + 3)
            add hl, de
            ld e, (ix + 4)
            ld d, (ix + 5)
            add hl, de
            ld (w_cnt2), hl
            ld hl, (w_tb)
            ld de, 16
            add hl, de
            ld (w_p), hl
tl_skb:
            ld hl, (w_cnt2)         ; (the buildings not drawn: skipped)
            ld a, h
            or l
            jr z, tl_l0
            dec hl
            ld (w_cnt2), hl
            ld hl, (w_p)
            ld a, (hl)
            ld e, a
            add a, a
            add a, e
            add a, 2                ; (n, the height, n points, n masks)
            ld e, a
            ld d, 0
            add hl, de
            ld (w_p), hl
            jr tl_skb
tl_l0:
            ld hl, (w_nl)           ; the lines' own share: an eighth of the budget
            ld de, ({lmax})
            srl d
            rr e
            srl d
            rr e
            srl d
            rr e
            add hl, de
            ld (w_tcap), hl
            ld ix, (w_tb)
            ld l, (ix + 6)
            ld h, (ix + 7)
            ld (w_cnt2), hl
            ld hl, (w_tz)
            ld de, 1600
            call cmps
            ld a, 0
            jr c, tl_l1
            inc a                   ; far: no minor roads
tl_l1:
            ld (w_far), a
tl_l_lp:
            ld hl, (w_cnt2)
            ld a, h
            or l
            jp z, tl_3d
            dec hl
            ld (w_cnt2), hl
            call tl_budget
            jr c, tl_lcap
            call l_one
            jr tl_l_lp
tl_lcap:
            ld a, (w_stop)
            or a
            ret nz
            jp tl_3d
            ; the 3D lines (landmarks, bridges)
tl_3d:
            ld ix, (w_tb)
            ld l, (ix + 12)
            ld h, (ix + 13)
            ld de, (w_tb)
            add hl, de
            ld (w_p), hl
            ld l, (ix + 8)
            ld h, (ix + 9)
            ld (w_cnt2), hl
tl_3_lp:
            ld hl, (w_cnt2)
            ld a, h
            or l
            jr z, tl_trees
            dec hl
            ld (w_cnt2), hl
            call l3_one
            jr tl_3_lp
            ; the trees, nearer than 350 m
tl_trees:
            ld a, (w_mode)
            or a
            ret nz
            ld hl, (w_tz)
            ld de, 700
            call cmps
            ret nc
            ld ix, (w_tb)
            ld l, (ix + 14)
            ld h, (ix + 15)
            ld de, (w_tb)
            add hl, de
            ld (w_p), hl
            ld l, (ix + 10)
            ld h, (ix + 11)
            ld (w_cnt2), hl
            ld a, 3
            ld (gfx_pen), a
tl_t_lp:
            ld hl, (w_cnt2)
            ld a, h
            or l
            ret z
            dec hl
            ld (w_cnt2), hl
            call tl_budget
            ret c
            call t_one
            jr tl_t_lp
; tl_budget - carry (and w_stop) when the frame's lines are used up; carry alone when the
; tile's share is (w_tcap)
tl_budget:
            ld hl, (w_nl)
            ld de, ({lmax})
            call cmps
            jr nc, tb_stop
            ld hl, (w_nl)
            ld de, (w_tcap)
            call cmps               ; carry: still room
            ccf
            ret
tb_stop:
            ld a, 1
            ld (w_stop), a
            scf
            ret
; tl_mid - HL = DE + A * 768 + 384 (a tile's middle in world units)
tl_mid:
            ld l, a
            add a, a
            add a, l                ; A * 3 (< 256)
            ld h, a
            ld l, 0
            add hl, de
            ld de, 384
            add hl, de
            ret
; tl_dot - HL = (w_dx, w_dy, w_dz) . the basis numbers at IY, IY + 2, IY + 4
tl_dot:
            ld de, (w_dx)
            ld c, (iy + 0)
            ld b, (iy + 1)
            call mulfix
            ld (w_d), hl
            ld de, (w_dy)
            ld c, (iy + 2)
            ld b, (iy + 3)
            call mulfix
            ld de, (w_d)
            add hl, de
            ld (w_d), hl
            ld de, (w_dz)
            ld c, (iy + 4)
            ld b, (iy + 5)
            call mulfix
            ld de, (w_d)
            add hl, de
            ret
; mul8x16 - HL = L * DE (L < 256)
mul8x16:
            ld b, 8
            ld a, l
            ld hl, 0
m8_lp:
            add hl, hl
            rlca
            jr nc, m8_n
            add hl, de
m8_n:
            djnz m8_lp
            ret

; ---- a vertex: the tile's middle (w_tx, w_ty, w_tz) + {TX}[x] + {TZ}[z] (+ the height's, w_hx ..)
; vx_xz - B = local x, C = local z: (w_gx, w_gy, w_gz)
vx_xz:
            ld l, b
            ld h, 0
            add hl, hl
            ld e, l
            ld d, h
            add hl, hl
            add hl, de
            ld de, {TX}
            add hl, de
            push hl
            ld l, c
            ld h, 0
            add hl, hl
            ld e, l
            ld d, h
            add hl, hl
            add hl, de
            ld de, {TZ}
            add hl, de
            ex de, hl               ; DE = {TZ} entry
            pop hl                  ; HL = {TX} entry
            ld a, (de)              ; x
            add a, (hl)
            ld c, a
            inc hl
            inc de
            ld a, (de)
            adc a, (hl)
            ld b, a
            inc hl
            inc de
            push hl
            ld hl, (w_tx)
            add hl, bc
            ld (w_gx), hl
            pop hl
            ld a, (de)              ; y
            add a, (hl)
            ld c, a
            inc hl
            inc de
            ld a, (de)
            adc a, (hl)
            ld b, a
            inc hl
            inc de
            push hl
            ld hl, (w_ty)
            add hl, bc
            ld (w_gy), hl
            pop hl
            ld a, (de)              ; z
            add a, (hl)
            ld c, a
            inc hl
            inc de
            ld a, (de)
            adc a, (hl)
            ld b, a
            inc hl
            inc de
            push hl
            ld hl, (w_tz)
            add hl, bc
            ld (w_gz), hl
            pop hl
            ret
; vx_h - A = a height (2 m steps): (w_hx, w_hy, w_hz) its {TH} entry
vx_h:
            cp 192
            jr c, vh_ok
            ld a, 191               ; (the table's last)
vh_ok:
            ld l, a
            ld h, 0
            add hl, hl
            ld e, l
            ld d, h
            add hl, hl
            add hl, de
            ld de, {TH}
            add hl, de
            ld de, w_hx
            ld bc, 6
            ldir
            ret
; vx_put - the vertex at IX = (w_gx ..) + (w_hx ..) when A <> 0, else (w_gx ..); its outcode,
; its place on the screen when it is in view
vx_put:
            or a
            jr z, vp_g
            ld hl, (w_gx)
            ld de, (w_hx)
            add hl, de
            ld (ix + 0), l
            ld (ix + 1), h
            ld hl, (w_gy)
            ld de, (w_hy)
            add hl, de
            ld (ix + 2), l
            ld (ix + 3), h
            ld hl, (w_gz)
            ld de, (w_hz)
            add hl, de
            ld (ix + 4), l
            ld (ix + 5), h
            jr vp_oc
vp_g:
            ld hl, (w_gx)
            ld (ix + 0), l
            ld (ix + 1), h
            ld hl, (w_gy)
            ld (ix + 2), l
            ld (ix + 3), h
            ld hl, (w_gz)
            ld (ix + 4), l
            ld (ix + 5), h
vp_oc:
            call ve_oc
            ld (ix + 6), a
            ld hl, w_and
            and (hl)
            ld (hl), a              ; (all the vertices' outcodes ANDed: a building wholly off
            ld a, (w_noproj)        ; one side is left out)
            or a
            ret nz
            ld a, (ix + 6)
            or a
            ret nz
            jp ve_proj

; ---- a building at (w_p): n, height, n points - its ground and its top (n each), 3n edges
b_one:
            ld hl, (w_p)
            ld a, (hl)
            ld (w_n), a
            inc hl
            ld a, (hl)
            inc hl
            ld (w_q), hl
            push af
            cp 10
            jr nc, bo_go            ; (20 m or more: no quick look)
            ld b, (hl)              ; a quick look at its first corner: more than 75 m behind,
            inc hl                  ; or 75 m off the side of the view - left out
            ld c, (hl)
            call vx_xz
            ld hl, (w_gz)
            ld de, -150
            call cmps
            jr c, bo_skip
            ld hl, (w_gx)
            call habs
            ld de, (w_gz)
            or a
            sbc hl, de
            ld de, 150
            call cmps
            jr nc, bo_skip
            pop af                  ; below the view: its top (the height's Y added) under the
            push af                 ; bottom edge by more than 37 m (-4Y - 3Z > 600)
            call vx_h
            ld hl, (w_gy)
            ld de, (w_hy)
            add hl, de
            call hneg
            add hl, hl
            add hl, hl
            push hl
            ld hl, (w_gz)
            ld e, l
            ld d, h
            add hl, hl
            add hl, de
            ex de, hl
            pop hl
            or a
            sbc hl, de
            ld de, 600
            call cmps
            jr c, bo_go
bo_skip:
            pop af
            ld a, (w_n)             ; past it (its points and its walls' masks: 3n)
            ld e, a
            add a, a
            add a, e
            ld e, a
            ld d, 0
            ld hl, (w_q)
            add hl, de
            ld (w_p), hl
            ret
bo_go:
            pop af
            ld hl, (w_q)            ; (its points: mk_cam reads the first)
            ld (w_pts), hl
            call vx_h
            ld hl, (w_pts)          ; its walls' masks (after the points), the camera's direction:
            ld a, (w_n)             ; a ground corner no wall beside it shows is not worked out
            add a, a
            ld e, a
            ld d, 0
            add hl, de
            ld (w_msk), hl
            call mk_cam
            xor a
            ld (w_vi), a
            ld a, #FF
            ld (w_and), a
            ld (w_noproj), a        ; (first the outcodes only)
            ld ix, {VTX}
            ld a, (w_n)
            ld b, a
bo_v:
            push bc
            ld hl, (w_q)
            ld b, (hl)
            inc hl
            ld c, (hl)
            inc hl
            ld (w_q), hl
            push ix
            call vx_xz
            pop ix
            ld a, (w_lod)
            or a
            jr z, bo_ng             ; (the top only: the ground not needed on the screen)
            call mk_need
            jr z, bo_ng             ; (no wall beside it to be seen: not needed)
            xor a
            call vx_put             ; the ground
bo_ng:
            push ix
            ld de, 144
            add ix, de
            ld a, 1
            call vx_put             ; the top (12 vertices on)
            pop ix
            ld de, 12
            add ix, de
            pop bc
            ld hl, w_vi
            inc (hl)
            djnz bo_v
            ld hl, (w_q)            ; its walls' masks: after the points
            ld (w_msk), hl
            ld a, (w_n)
            ld e, a
            ld d, 0
            add hl, de
            ld (w_p), hl
            xor a
            ld (w_noproj), a
            ld a, (w_and)
            or a
            ret nz                  ; wholly off one side of the view: nothing to draw
            xor a
            ld (w_vi), a
            ld ix, {VTX}              ; the vertices in view onto the screen
            ld a, (w_n)
            ld b, a
bo_pj:
            push bc
            ld a, (w_lod)
            or a
            jr z, bo_pj1
            call mk_need
            jr z, bo_pj1
            ld a, (ix + 6)
            or a
            call z, ve_proj
bo_pj1:
            push ix
            ld de, 144
            add ix, de
            ld a, (ix + 6)
            or a
            call z, ve_proj
            pop ix
            ld de, 12
            add ix, de
            pop bc
            ld hl, w_vi
            inc (hl)
            djnz bo_pj
            xor a                   ; the edges
            ld (w_i), a
bo_e:
            ld a, (w_i)
            call vx12               ; HL = ground i
            ld (w_ea), hl
            ld (w_va), hl
            ld a, (w_i)
            inc a
            ld hl, w_n
            cp (hl)
            jr c, bo_e1
            xor a
bo_e1:
            call vx12
            ld (w_eb), hl
            ld (w_vb), hl
            ld a, (w_lod)
            bit 0, a
            call nz, mk_gnd         ; ground i - ground i+1: when wall i can be seen from the camera
            ld hl, (w_va)
            ld de, 144
            add hl, de
            ld (w_ea), hl
            ld hl, (w_vb)
            add hl, de
            ld (w_eb), hl
            call ed_cnt             ; top i - top i+1
            ld a, (w_lod)
            bit 1, a
            jr z, bo_nv
            call mk_up              ; (an upright: when a wall either side of it can be seen)
            jr nz, bo_up
            call mk_cut
            jr bo_nv
bo_up:
            ld hl, (w_va)
            ld (w_ea), hl
            ld de, 144
            add hl, de
            ld (w_eb), hl
            call ed_cnt             ; ground i - top i
bo_nv:
            ld a, (w_i)
            inc a
            ld (w_i), a
            ld hl, w_n
            cp (hl)
            jr c, bo_e
            ret
; ---- the wall masks (AUCKLAND_MASK: S3D2 data): s3dmake keeps a byte for each wall - bit k set when
; it can be seen from direction k (0 north ... 7 north-west, 45 degrees apart). The camera's
; direction from the building (its first corner) is found once (mk_cam: two trits, a table), and a
; wall is drawn when its byte has that bit: an AND, nothing worked out per wall
mk_cam:
            ld a, (w_ti)            ; the camera from the tile's middle (0.5 m units)
            ld de, ({x0})
            call tl_mid
            ex de, hl
            ld hl, ({camx})
            or a
            sbc hl, de
            push hl
            ld hl, (w_pts)          ; less the first corner (2 m steps: x 4)
            ld a, (hl)
            call sx8
            add hl, hl
            add hl, hl
            ex de, hl
            pop hl
            or a
            sbc hl, de
            ld (w_vx), hl
            ld a, (w_tj)
            ld de, ({z0})
            call tl_mid
            ex de, hl
            ld hl, ({camz})
            or a
            sbc hl, de
            push hl
            ld hl, (w_pts)
            inc hl
            ld a, (hl)
            call sx8
            add hl, hl
            add hl, hl
            ex de, hl
            pop hl
            or a
            sbc hl, de
            ld (w_vz2), hl
            ld de, (w_vx)           ; its trits: z against x, x against z
            call trit
            inc a                   ; (0, 1, 2)
            ld c, a
            ld hl, (w_vx)
            ld de, (w_vz2)
            call trit
            inc a
            ld b, a
            add a, a
            add a, b
            add a, c                ; 3 tx + tz
            ld e, a
            ld d, 0
            ld hl, mk_dir
            add hl, de
            ld a, (hl)
            ld (w_cb), a
            ret
; (-1,-1) SW, (-1,0) W, (-1,1) NW, (0,-1) S, (0,0) on it: all, (0,1) N, (1,-1) SE, (1,0) E, (1,1) NE
mk_dir:     db 32, 64, 128, 16, 255, 1, 8, 4, 2
; sx8 - HL = A, sign extended
sx8:
            ld l, a
            add a, a
            sbc a, a
            ld h, a
            ret
; trit - A = the trit of HL beside DE: its sign (1, 255) when 2|HL| > |DE|, else 0
trit:
            ld a, h
            or l
            ret z
            push hl
            call habs
            add hl, hl
            push hl
            ex de, hl
            call habs
            ex de, hl
            pop hl
            or a
            sbc hl, de
            pop hl
            jr c, mk_t0
            jr z, mk_t0
            bit 7, h
            ld a, 1
            ret z
            ld a, 255
            ret
mk_t0:
            xor a
            ret
; mk_wall - A = wall A's mask AND the camera's bit
mk_wall:
            ld e, a
            ld d, 0
            ld hl, (w_msk)
            add hl, de
            ld a, (w_cb)
            and (hl)
            ret
; mk_gnd - ground edge i, when wall i can be seen
mk_gnd:
            ld a, (w_i)
            call mk_wall
            jp nz, ed_cnt
; mk_need - NZ: ground corner w_vi is needed (wall w_vi or the one before it can be seen)
mk_need:
            ld a, (w_vi)
            call mk_wall
            ret nz
            ld a, (w_vi)
            or a
            jr nz, mn_1
            ld a, (w_n)
mn_1:
            dec a
            jp mk_wall
; mk_cut - an edge left out: counted (and in the frame's budget, as if drawn)
mk_cut:
            ld hl, (w_cull)
            inc hl
            ld (w_cull), hl
            ld hl, (w_nl)
            inc hl
            ld (w_nl), hl
            ret
; mk_up - NZ: upright i is drawn (wall i or wall i-1 can be seen)
mk_up:
            ld a, (w_i)
            call mk_wall
            ret nz
            ld a, (w_i)
            or a
            jr nz, mu_1
            ld a, (w_n)
mu_1:
            dec a
            jp mk_wall
; ed_cnt - ed_one, counted
ed_cnt:
            ld hl, (w_nl)
            inc hl
            ld (w_nl), hl
            jp ed_one

; ---- a ground line at (w_p): n, type, n points (minor roads, type 2, left out when w_far)
l_one:
            ld hl, (w_p)
            ld a, (hl)
            ld (w_n), a
            inc hl
            ld a, (hl)
            inc hl
            ld (w_q), hl
            ld c, a                 ; the pen: 1 roads, railways, piers; 3 coast, water
            ld a, 1
            ld b, a
            ld a, c
            cp 4
            jr c, lo_p
            cp 7
            jr nc, lo_p
            ld b, 3
lo_p:
            ld a, b
            ld (gfx_pen), a
            ld a, (w_n)             ; past it (for the next one)
            add a, a
            ld e, a
            ld d, 0
            ld hl, (w_q)
            add hl, de
            ld (w_p), hl
            ld a, c
            cp 2
            jr nz, lo_go
            ld a, (w_far)
            or a
            ret nz
lo_go:
            xor a
            ld (w_3d), a
            jr ln_pts
; ---- a 3D line at (w_p): n, type, n points with heights
l3_one:
            ld hl, (w_p)
            ld a, (hl)
            ld (w_n), a
            inc hl
            ld a, (hl)
            inc hl
            ld (w_q), hl
            cp 10                   ; the pen: 2 the volcanoes, 1 the rest
            ld a, 1
            jr nz, l3_p
            inc a
l3_p:
            ld (gfx_pen), a
            ld a, (w_n)             ; past it: 3 bytes a point
            ld e, a
            add a, a
            add a, e
            ld e, a
            ld d, 0
            ld hl, (w_q)
            add hl, de
            ld (w_p), hl
            ld a, 1
            ld (w_3d), a
; ln_pts - the points from (w_q): each to the one before, two vertices taking turns
ln_pts:
            xor a
            ld (w_i), a
ln_lp:
            ld hl, (w_q)
            ld b, (hl)
            inc hl
            ld c, (hl)
            inc hl
            ld a, (w_3d)
            or a
            jr z, ln_h0
            ld a, (hl)
            inc hl
ln_h0:
            ld (w_q), hl
            push af
            call vx_xz
            pop af
            or a
            call nz, vx_h
            ld a, (w_i)             ; vertex 0, 1, 0, 1 ...
            and 1
            call vx12
            push hl
            pop ix
            ld a, (w_3d)
            or a
            jr z, ln_g
            ld hl, (w_q)            ; (the height: again from the point just read)
            dec hl
            ld a, (hl)
ln_g:
            call vx_put
            ld a, (w_i)
            or a
            jr z, ln_n
            and 1
            call vx12
            ld (w_eb), hl
            ld a, (w_i)
            inc a
            and 1
            call vx12
            ld (w_ea), hl
            call ed_cnt
ln_n:
            ld a, (w_i)
            inc a
            ld (w_i), a
            ld hl, w_n
            cp (hl)
            jr c, ln_lp
            ret

; ---- a tree at (w_p): its foot and 8 m up; on the screen a trunk and a crown (a triangle)
t_one:
            ld hl, (w_p)
            ld b, (hl)
            inc hl
            ld c, (hl)
            inc hl
            ld (w_p), hl
            call vx_xz
            ld ix, {VTX}
            xor a
            call vx_put
            ld a, (ix + 6)
            or a
            ret nz
            ld a, 4
            call vx_h
            ld ix, {VTX} + 12
            ld a, 1
            call vx_put
            ld a, (ix + 6)
            or a
            ret nz
            ld hl, ({VTX} + 12 + 8)   ; dx, dy: the top from the foot
            ld de, ({VTX} + 8)
            or a
            sbc hl, de
            ld (w_tdx), hl
            ld hl, ({VTX} + 12 + 10)
            ld de, ({VTX} + 10)
            or a
            sbc hl, de
            ld (w_tdy), hl
            call habs
            ld de, 4
            call cmps
            ret c                   ; too small to see
            ld hl, (w_tdx)          ; the crown's foot: a third of the way up
            call div3
            ld de, ({VTX} + 8)
            add hl, de
            ld (w_mx), hl
            ld hl, (w_tdy)
            call div3
            ld de, ({VTX} + 10)
            add hl, de
            ld (w_my), hl
            ld hl, (w_tdy)          ; half its width: (-dy, dx) / 4
            call hneg
            sra h
            rr l
            sra h
            rr l
            ld (w_px), hl
            ld hl, (w_tdx)
            sra h
            rr l
            sra h
            rr l
            ld (w_py), hl
            ld hl, (w_mx)           ; the crown's corners, on the screen or no tree
            ld de, (w_px)
            add hl, de
            ld (w_lx), hl
            call t_inx
            ret c
            ld hl, (w_mx)
            ld de, (w_px)
            or a
            sbc hl, de
            ld (w_rx), hl
            call t_inx
            ret c
            ld hl, (w_my)
            ld de, (w_py)
            add hl, de
            ld (w_ly), hl
            call t_iny
            ret c
            ld hl, (w_my)
            ld de, (w_py)
            or a
            sbc hl, de
            ld (w_ry), hl
            call t_iny
            ret c
            ld hl, (w_nl)
            inc hl
            inc hl
            inc hl
            inc hl
            ld (w_nl), hl
            ld hl, ({VTX} + 8)        ; the trunk
            ld de, ({VTX} + 10)
            ld bc, (w_mx)
            ld ix, (w_my)
            call t_line
            ld hl, (w_lx)           ; the crown
            ld de, (w_ly)
            ld bc, ({VTX} + 12 + 8)
            ld ix, ({VTX} + 12 + 10)
            call t_line
            ld hl, (w_rx)
            ld de, (w_ry)
            ld bc, ({VTX} + 12 + 8)
            ld ix, ({VTX} + 12 + 10)
            call t_line
            ld hl, (w_lx)
            ld de, (w_ly)
            ld bc, (w_rx)
            ld ix, (w_ry)
; t_line - a line HL, DE - BC, IX
t_line:
            ld (gfx_x0), hl
            ld (gfx_y0), de
            ld (gfx_x1), bc
            ld (gfx_y1), ix
            jp gfx_line
; t_inx / t_iny - carry when HL is off the screen (0-319 / 0-199)
t_inx:
            ld de, 320
            jr t_in
t_iny:
            ld de, 200
t_in:
            bit 7, h
            scf
            ret nz
            or a
            sbc hl, de
            ccf
            ret
; div3 - HL = HL / 3 (signed, about)
div3:
            bit 7, h
            jr z, d3_p
            call hneg
            call d3_u
            jp hneg
d3_p:
d3_u:
            ld c, l                 ; (HL * 85) / 256
            ld b, h
            ld de, 85
            push bc
            pop de
            ld bc, 85
            call mulu16
            ld l, h
            ld h, e
            ret

; ve_oc - A = the outcode of the corner at IX: bit 0 nearer than 16, 1 right (X > Z),
; 2 left (-X > Z), 3 above (4Y > 3Z), 4 below (-4Y > 3Z)
ve_oc:
            ld c, 0
            ld l, (ix + 4)
            ld h, (ix + 5)
            ld (w_vz), hl
            ld de, 16
            call cmps
            jr nc, oc1
            set 0, c
oc1:
            ld e, (ix + 0)
            ld d, (ix + 1)
            ld hl, (w_vz)
            call cmps
            jr nc, oc2
            set 1, c
oc2:
            ld l, (ix + 0)
            ld h, (ix + 1)
            call hneg
            ex de, hl
            ld hl, (w_vz)
            call cmps
            jr nc, oc3
            set 2, c
oc3:
            ld l, (ix + 2)
            ld h, (ix + 3)
            add hl, hl
            add hl, hl
            ld (w_v4y), hl
            ld hl, (w_vz)
            ld e, l
            ld d, h
            add hl, hl
            add hl, de
            ld (w_v3z), hl
            ld de, (w_v4y)
            call cmps
            jr nc, oc4
            set 3, c
oc4:
            ld hl, (w_v4y)
            call hneg
            ex de, hl
            ld hl, (w_v3z)
            call cmps
            jr nc, oc5
            set 4, c
oc5:
            ld a, c
            ret
; ve_proj - the corner at IX onto the screen: sx = 160 + X * 160 / Z (0-319),
; sy = 100 - Y * 133 / Z (0-199), at IX + 8, IX + 10
ve_proj:
            ld l, (ix + 4)
            ld h, (ix + 5)
            bit 7, h
            jr nz, pj_z1
            ld a, h
            or l
            jr nz, pj_z
pj_z1:
            ld hl, 1
pj_z:
            ld (w_pzv), hl
            ld l, (ix + 0)
            ld h, (ix + 1)
            ld a, h
            ld (w_psg), a
            call habs
            ld de, (w_pzv)
            call ucap
            call pj_160
            call pj_div
            ex de, hl
            ld hl, 160
            ld a, (w_psg)
            bit 7, a
            jr nz, pj_xn
            add hl, de
            jr pj_xs
pj_xn:
            or a
            sbc hl, de
pj_xs:
            ld de, 319
            call ucap
            ld (ix + 8), l
            ld (ix + 9), h
            ld l, (ix + 2)
            ld h, (ix + 3)
            ld a, h
            ld (w_psg), a
            call habs
            push hl
            ld hl, (w_pzv)
            ld e, l
            ld d, h
            add hl, hl
            add hl, de
            srl h
            rr l
            srl h
            rr l
            ex de, hl
            pop hl
            call ucap
            call pj_133
            call pj_div
            ex de, hl
            ld hl, 100
            ld a, (w_psg)
            bit 7, a
            jr nz, pj_yn
            or a
            sbc hl, de
            jr pj_ys
pj_yn:
            add hl, de
pj_ys:
            ld de, 199
            call ucap
            ld (ix + 10), l
            ld (ix + 11), h
            ret
; pj_160 / pj_133 - C:HL = HL * 160 / * 133 (24 bits), by shifts
pj_160:
            ld c, 0
            add hl, hl
            rl c
            add hl, hl
            rl c
            add hl, hl
            rl c
            add hl, hl
            rl c
            add hl, hl
            rl c                    ; * 32
            ld d, h
            ld e, l
            ld b, c
            add hl, hl
            rl c
            add hl, hl
            rl c                    ; * 128
            add hl, de
            ld a, c
            adc a, b
            ld c, a                 ; * 160
            ret
pj_133:
            ld c, 0
            push hl                 ; n
            add hl, hl
            rl c
            add hl, hl
            rl c                    ; * 4
            ld d, h
            ld e, l
            ld b, c
            add hl, hl
            rl c
            add hl, hl
            rl c
            add hl, hl
            rl c
            add hl, hl
            rl c
            add hl, hl
            rl c                    ; * 128
            add hl, de
            ld a, c
            adc a, b
            ld c, a                 ; * 132
            pop de
            add hl, de
            ld a, c
            adc a, 0
            ld c, a                 ; * 133
            ret
; pj_div - HL = C:HL / (w_pzv): the quotient is under 256 (8 steps)
pj_div:
            ld b, l
            ld l, h
            ld h, c                 ; HL = the top 16 bits, B = the low 8
            ld de, (w_pzv)
            ld c, 0
            sla b
            adc hl, hl
            sla c
            or a
            sbc hl, de
            jr nc, pd_y0
            add hl, de
            jr pd_n0
pd_y0:
            inc c
pd_n0:
            sla b
            adc hl, hl
            sla c
            or a
            sbc hl, de
            jr nc, pd_y1
            add hl, de
            jr pd_n1
pd_y1:
            inc c
pd_n1:
            sla b
            adc hl, hl
            sla c
            or a
            sbc hl, de
            jr nc, pd_y2
            add hl, de
            jr pd_n2
pd_y2:
            inc c
pd_n2:
            sla b
            adc hl, hl
            sla c
            or a
            sbc hl, de
            jr nc, pd_y3
            add hl, de
            jr pd_n3
pd_y3:
            inc c
pd_n3:
            sla b
            adc hl, hl
            sla c
            or a
            sbc hl, de
            jr nc, pd_y4
            add hl, de
            jr pd_n4
pd_y4:
            inc c
pd_n4:
            sla b
            adc hl, hl
            sla c
            or a
            sbc hl, de
            jr nc, pd_y5
            add hl, de
            jr pd_n5
pd_y5:
            inc c
pd_n5:
            sla b
            adc hl, hl
            sla c
            or a
            sbc hl, de
            jr nc, pd_y6
            add hl, de
            jr pd_n6
pd_y6:
            inc c
pd_n6:
            sla b
            adc hl, hl
            sla c
            or a
            sbc hl, de
            jr nc, pd_y7
            add hl, de
            jr pd_n7
pd_y7:
            inc c
pd_n7:
            ld l, c
            ld h, 0
            ret
; vx12 - HL = the corner table + A * 12
vx12:
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            ld e, l
            ld d, h
            add hl, hl
            add hl, de
            ld de, {VTX}
            add hl, de
            ret
; ed_one - the edge (w_ea) - (w_eb): drawn as it is, clipped, or not at all
ed_one:
            ld ix, (w_ea)
            ld iy, (w_eb)
            ld a, (ix + 6)
            and (iy + 6)
            ret nz                  ; both ends outside the same side
            ld a, (ix + 6)
            or (iy + 6)
            jr z, ed_set
            ld (w_mask), a
            push ix
            pop hl
            ld de, w_e0
            ld bc, 6
            ldir
            push iy
            pop hl
            ld de, w_e1
            ld bc, 6
            ldir
            call clip3d
            ret nc                  ; nothing of it in view
            ld ix, w_e0
            call ve_proj
            ld ix, w_e1
            call ve_proj
            ld ix, w_e0
            ld iy, w_e1
ed_set:
            ld l, (ix + 8)
            ld h, (ix + 9)
            ld (gfx_x0), hl
            ld l, (ix + 10)
            ld h, (ix + 11)
            ld (gfx_y0), hl
            ld l, (iy + 8)
            ld h, (iy + 9)
            ld (gfx_x1), hl
            ld l, (iy + 10)
            ld h, (iy + 11)
            ld (gfx_y1), hl
            jp gfx_line
; clip3d - w_e0 - w_e1 cut against the sides in w_mask (near, right, left, top, bottom);
; carry: something is left
clip3d:
            xor a
            ld (w_pl), a
cp_lp:
            ld a, (w_mask)
            rrca
            ld (w_mask), a
            jr nc, cp_next
            ld ix, w_e0
            call cp_dist
            ld (w_d0), hl
            ld ix, w_e1
            call cp_dist
            ld (w_d1), hl
            ld a, (w_d0 + 1)
            ld b, a
            ld a, (w_d1 + 1)
            and b
            jp m, cp_rej            ; both outside
            bit 7, b
            jr z, cp_e1
            ld ix, w_e0             ; end 0 outside: moved to the side
            ld iy, w_e1
            ld hl, (w_d0)
            ld (w_dn), hl
            ld de, (w_d1)
            or a
            sbc hl, de
            ld (w_dd), hl
            call cp_lerp
            jr cp_next
cp_e1:
            ld a, (w_d1 + 1)
            bit 7, a
            jr z, cp_next
            ld ix, w_e1             ; end 1 outside
            ld iy, w_e0
            ld hl, (w_d1)
            ld (w_dn), hl
            ld de, (w_d0)
            or a
            sbc hl, de
            ld (w_dd), hl
            call cp_lerp
cp_next:
            ld a, (w_pl)
            inc a
            ld (w_pl), a
            cp 5
            jr nz, cp_lp
            scf
            ret
cp_rej:
            or a
            ret
; cp_dist - HL = how far the point at IX is inside side w_pl (negative: outside)
cp_dist:
            ld e, (ix + 4)
            ld d, (ix + 5)
            ld a, (w_pl)
            or a
            jr nz, cd1
            ld hl, -16
            add hl, de              ; Z - 16
            ret
cd1:
            dec a
            jr nz, cd2
            ld l, (ix + 0)
            ld h, (ix + 1)
            ex de, hl
            or a
            sbc hl, de              ; Z - X
            ret
cd2:
            dec a
            jr nz, cd3
            ld l, (ix + 0)
            ld h, (ix + 1)
            add hl, de              ; Z + X
            ret
cd3:
            push af
            ld l, e
            ld h, d
            add hl, hl
            add hl, de
            ex de, hl               ; DE = 3Z
            ld l, (ix + 2)
            ld h, (ix + 3)
            add hl, hl
            add hl, hl              ; HL = 4Y
            pop af
            dec a
            jr nz, cd4
            ex de, hl
            or a
            sbc hl, de              ; (3Z - 4Y) / 2
            sra h
            rr l
            ret
cd4:
            add hl, de              ; (3Z + 4Y) / 2
            sra h
            rr l
            ret
; cp_lerp - the point at IX moved towards IY's: + (IY - IX) * w_dn / w_dd
cp_lerp:
            ld b, 3
cl_lp2:
            push bc
            ld l, (iy + 0)
            ld h, (iy + 1)
            ld e, (ix + 0)
            ld d, (ix + 1)
            or a
            sbc hl, de
            ex de, hl
            ld bc, (w_dn)
            call mul16s
            ld bc, (w_dd)
            call div32s16
            ld e, (ix + 0)
            ld d, (ix + 1)
            add hl, de
            ld (ix + 0), l
            ld (ix + 1), h
            inc ix
            inc ix
            inc iy
            inc iy
            pop bc
            djnz cl_lp2
            ret

; ---- arithmetic

; mulfix - HL = DE * BC / 16384, signed
mulfix:
            call mul16s
            add hl, hl
            rl e
            rl d
            add hl, hl
            rl e
            rl d
            ex de, hl
            ret
; mul16s - DEHL = DE * BC, signed
mul16s:
            ld a, d
            xor b
            push af
            bit 7, d
            jr z, ms1
            xor a
            sub e
            ld e, a
            sbc a, a
            sub d
            ld d, a
ms1:
            bit 7, b
            jr z, ms2
            xor a
            sub c
            ld c, a
            sbc a, a
            sub b
            ld b, a
ms2:
            call mulu16
            pop af
            ret p
neg32:
            xor a
            sub l
            ld l, a
            ld a, 0
            sbc a, h
            ld h, a
            ld a, 0
            sbc a, e
            ld e, a
            ld a, 0
            sbc a, d
            ld d, a
            ret
; mulu16 - DEHL = DE * BC, unsigned
mulu16:
            ld hl, 0
            ld a, 16
mu_lp:
            add hl, hl
            rl e
            rl d
            jr nc, mu_n
            add hl, bc
            jr nc, mu_n
            inc de
mu_n:
            dec a
            jr nz, mu_lp
            ret
; div32s16 - HL = DEHL / BC, signed (kept to 32767 if it would be more)
div32s16:
            ld a, d
            xor b
            push af
            bit 7, d
            call nz, neg32
            bit 7, b
            jr z, ds1
            xor a
            sub c
            ld c, a
            sbc a, a
            sub b
            ld b, a
ds1:
            ex de, hl
            or a
            sbc hl, bc
            add hl, bc
            jr c, ds2
            ld de, #7FFF
            jr ds3
ds2:
            call divu
ds3:
            ex de, hl
            pop af
            ret p
hneg:
            xor a
            sub l
            ld l, a
            sbc a, a
            sub h
            ld h, a
            ret
; divu - DE = HL:DE / BC, unsigned, HL < BC (HL = the remainder)
divu:
            ld a, 16
dv_lp:
            sla e
            rl d
            adc hl, hl
            jr c, dv_s
            sbc hl, bc
            jr nc, dv_ok
            add hl, bc
            dec a
            jr nz, dv_lp
            ret
dv_s:
            or a
            sbc hl, bc
dv_ok:
            inc e
            dec a
            jr nz, dv_lp
            ret
; habs - HL = |HL|
habs:
            bit 7, h
            ret z
            jr hneg
; ucap - HL = the smaller of HL and DE, unsigned
ucap:
            or a
            sbc hl, de
            add hl, de
            ret c
            ld h, d
            ld l, e
            ret
; cmps - carry when HL < DE, signed (HL lost)
cmps:
            ld a, h
            xor d
            jp m, cm_d
            or a
            sbc hl, de
            ret
cm_d:
            bit 7, h
            scf
            ret nz
            or a
            ret
; x6 - HL = A * 6
x6:
            ld l, a
            ld h, 0
            add hl, hl
            ld e, l
            ld d, h
            add hl, hl
            add hl, de
            ret

w_rs:       dw 0
w_a:        dw 0
w_b:        dw 0
w_t:        dw 0
w_d:        dw 0
w_k:        dw 0
w_cbx:      db 0
w_cbz:      db 0
w_ci:       db 0
w_cj:       db 0
w_lvl:      db 0
w_var:      db 0
w_vk:       db 0
w_psg:      db 0
w_mask:     db 0
w_pl:       db 0
w_px0:      dw 0
w_px1:      dw 0
w_pz0:      dw 0
w_pz1:      dw 0
w_phl:      dw 0
w_sum:      dw 0
w_cx:       dw 0
w_cy:       dw 0
w_cz:       dw 0
w_pa:       dw 0
w_pb:       dw 0
w_pc:       dw 0
w_vz:       dw 0
w_v4y:      dw 0
w_v3z:      dw 0
w_pzv:      dw 0
w_ea:       dw 0
w_eb:       dw 0
w_d0:       dw 0
w_d1:       dw 0
w_dn:       dw 0
w_dd:       dw 0
w_csp:      dw 0
w_crp:      dw 0
w_e0:       ds 12
w_e1:       ds 12
w_nl:       dw 0
w_nlm:      dw 0
w_lod:      db 0
w_and:      db 0
w_noproj:   db 0
w_stop:     db 0
w_mode:     db 0
w_ti:       db 0
w_tj:       db 0
w_far:      db 0
w_3d:       db 0
w_n:        db 0
w_i:        db 0
w_sgn:      db 0
w_cnt:      db 0
w_acc:      ds 3
w_tcap:     dw 0
w_v:        dw 0
w_lo:       dw 0
w_hi:       dw 0
w_dx:       dw 0
w_dy:       dw 0
w_dz:       dw 0
w_tx:       dw 0
w_ty:       dw 0
w_tz:       dw 0
w_gx:       dw 0
w_gy:       dw 0
w_gz:       dw 0
w_hx:       dw 0
w_hy:       dw 0
w_hz:       dw 0
w_tb:       dw 0
w_cnt2:     dw 0
w_p:        dw 0
w_pts:      dw 0
w_msk:      dw 0
w_vx:       dw 0
w_vz2:      dw 0
w_cb:       db 0
w_vi:       db 0
w_cull:     dw 0                    ; (the edges left out, all told)
w_q:        dw 0
w_va:       dw 0
w_vb:       dw 0
w_tdx:      dw 0
w_tdy:      dw 0
w_mx:       dw 0
w_my:       dw 0
w_px:       dw 0
w_py:       dw 0
w_lx:       dw 0
w_ly:       dw 0
w_rx:       dw 0
w_ry:       dw 0
#endasm
End Sub
