' Vox - ZX Craft's renderer: a 16 x 16 x 16 chunk of blocks drawn as filled faces on Layer 2.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
' Made by gen_vox.py (all of the drawing is Z80, in Render's #asm block: its labels are its own).
'
' How a frame is drawn (Render):
'  - the camera's basis from yaw and pitch, then three small tables (TX, TY, TZ: each grid line
'    along right, up and forward), so a block corner in camera space is three adds
'  - the chunk is 64 groups of 4 x 4 x 4 cells; a group outside the view is skipped (one on its
'    edge has its cells tested one by one), the rest are taken nearest first by Manhattan
'    distance (|dx| + |dy| + |dz|, in groups, then in cells within a group). Along any line of
'    sight that distance only goes up, so this is front to back
'  - only a block's open faces that face the camera are drawn (a face list made by Build)
'  - a corner is projected once a frame (a cache of 2048 in RAM page 44, slot 7 while drawing);
'    the projection is a reciprocal table and the Next's MUL D,E. A face cut by the near plane,
'    or too far off to the side, goes the slow way: cut in 3D, projected in 16 bits, dropped when
'    off the screen, cut to a guard band
'  - each row of the screen keeps a list of what is drawn already: a face's span only fills the
'    parts that are still empty, so every pixel is written once and nothing is cleared. What is
'    left at the end is the sky
'  - the screen is 128 x 80 pixels of 2 x 2 (Layer 2 rows 16 to 175), filled with PUSH
Option Explicit

Private blk(4095) As Byte         ' the chunk: x + 16 z + 256 y (y up), 0 = air
Private cells(3599) As Byte       ' the open blocks, by group: x | z << 4, y, open faces, type
Private gstart(63) As Integer     ' each group's first in cells (in 4s)
Private gcnt(63) As Byte
Private tab(305) As Byte          ' TX, TY, TZ: 17 x (x, y, z) words each
Private sps As Integer
Private bufNo As Integer, wipeColour As Integer
Private projX As Integer, projY As Integer, projZ As Integer

' Screen colour: Layer 2 on, 256 x 192, both buffers (banks 16-18, 19-21) wiped to colour; the
' first shown, the second drawn on. (#E3 is see-through: the ULA shows there.)
Public Sub Screen(ByVal colour As Integer)
  Nx.Reg &H70, 0
  Nx.Reg &H1C, 1
  Nx.Reg &H18, 0 : Nx.Reg &H18, 255 : Nx.Reg &H18, 0 : Nx.Reg &H18, 191
  Nx.Reg &H16, 0 : Nx.Reg &H17, 0
  Nx.Reg &H15, Nx.RegGet(&H15) And 3      ' Layer 2 over the tilemap (sprites over both)
  wipeColour = colour
  Wipe
  bufNo = 1
  Nx.Reg &H12, 16
  Out &H123B, 2
End Sub

' Back(): the buffer to draw on (0 or 1); Page(): its first 8K page (for Render)
Public Function Back() As Integer
  Back = bufNo
End Function
Public Function Page() As Integer
  Page = 32 + 6 * bufNo
End Function

' Flip: show the buffer just drawn (call it straight after Frame), draw on the other
Public Sub Flip()
  Nx.Reg &H12, 16 + 3 * bufNo
  bufNo = 1 - bufNo
End Sub

Private Sub Wipe()
#asm
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ld a, 32
wp_lp:
            push af
            ld bc, #243B
            ld e, a
            ld a, #56
            out (c), a
            inc b
            out (c), e
            ld hl, #C000
            ld de, #C001
            ld bc, #1FFF
            ld a, ({wipeColour})
            ld (hl), a
            ldir
            pop af
            inc a
            cp 44
            jr nz, wp_lp
            ld bc, #243B
            ld a, #56
            out (c), a
            inc b
            ld a, 10
            out (c), a
            ld sp, ({sps})
#endasm
End Sub

' Load address: the chunk from run-length data (pairs: count, block)
Public Sub Load(ByVal address As Integer)
#asm

; Load address: the chunk from run-length data (count, block; a count of 0 is 256) - 4096 blocks
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ld de, {blk}
            ld bc, 4096
ld_lp:
            ld a, (hl)
            inc hl
            push bc
            ld b, a
            ld a, (hl)
            inc hl
ld_r:
            ld (de), a
            inc de
            djnz ld_r
            pop bc
            ; bc -= count (the byte before the block)
            dec hl
            dec hl
            ld a, (hl)
            inc hl
            inc hl
            push hl
            push de
            ld h, b
            ld l, c
            ld e, a
            ld d, 0
            or a
            jr nz, ld_c
            inc d
ld_c:
            or a
            sbc hl, de
            ld b, h
            ld c, l
            pop de
            pop hl
            ld a, b
            or c
            jr nz, ld_lp
            ld sp, ({sps})
            ret
#endasm
End Sub

' Colours address: the block colours (16 types x 8: -X, +X, bottom, top, -Z, +Z, the top's other
' square, spare) then the sky's (80 rows), Layer 2 colours (RRRGGGBB) - World.Colours() has them
Public Sub Colours(ByVal address As Integer)
#asm
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld de, fn_vox_render_rd_col     ; (Render's table: its labels are fn_vox_render_ ...)
            ld bc, 592
            ldir
#endasm
End Sub

' SetBlock x, y, z, block / GetBlock(x, y, z) (call Build after changes)
Public Sub SetBlock(ByVal x As Integer, ByVal y As Integer, ByVal z As Integer, ByVal b As Integer)
  blk(x + z * 16 + y * 256) = b
End Sub
Public Function GetBlock(ByVal x As Integer, ByVal y As Integer, ByVal z As Integer) As Integer
  GetBlock = blk(x + z * 16 + y * 256)
End Function

' Build: the faces that can be seen (a block's sides next to air), a list a group
Public Sub Build()
#asm

; Build: the open faces of every block, a list a group (4 x 4 x 4 cells)
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ld hl, 0
            ld (bd_tot), hl
            ld hl, {cells}
            ld (bd_p), hl
            xor a
bd_g:
            ld (bd_g0), a
            ; gstart(g) = the total so far
            ld l, a
            ld h, 0
            add hl, hl
            ld de, {gstart}
            add hl, de
            ld de, (bd_tot)
            ld (hl), e
            inc hl
            ld (hl), d
            xor a
            ld (bd_cnt), a
            ld a, (bd_g0)
            and 3
            add a, a
            add a, a
            ld (bd_x0), a
            ld a, (bd_g0)
            and 12
            ld (bd_z0), a
            ld a, (bd_g0)
            rrca
            rrca
            and #3C
            ld (bd_y0), a
            ld (bd_y), a
bd_y1:
            ld a, (bd_z0)
            ld (bd_z), a
bd_z1:
            ld a, (bd_x0)
            ld (bd_x), a
bd_x1:
            ; HL = blk + x + 16 z + 256 y
            ld a, (bd_z)
            add a, a
            add a, a
            add a, a
            add a, a
            ld hl, bd_x
            add a, (hl)
            ld l, a
            ld a, (bd_y)
            ld h, a
            ld de, {blk}
            add hl, de
            ld a, (hl)
            or a
            jp z, bd_xn
            ld (bd_t), a
            ld c, 0
            ; -X
            ld a, (bd_x)
            or a
            jr z, bd_f0
            dec hl
            ld a, (hl)
            inc hl
            or a
            jr nz, bd_f1
bd_f0:
            set 0, c
bd_f1:
            ld a, (bd_x)
            cp 15
            jr z, bd_f2
            inc hl
            ld a, (hl)
            dec hl
            or a
            jr nz, bd_f3
bd_f2:
            set 1, c
bd_f3:
            ld a, (bd_y)
            or a
            jr z, bd_f4
            dec h
            ld a, (hl)
            inc h
            or a
            jr nz, bd_f5
bd_f4:
            set 2, c
bd_f5:
            ld a, (bd_y)
            cp 15
            jr z, bd_f6
            inc h
            ld a, (hl)
            dec h
            or a
            jr nz, bd_f7
bd_f6:
            set 3, c
bd_f7:
            ld de, 16
            ld a, (bd_z)
            or a
            jr z, bd_f8
            or a
            sbc hl, de
            ld a, (hl)
            add hl, de
            or a
            jr nz, bd_f9
bd_f8:
            set 4, c
bd_f9:
            ld a, (bd_z)
            cp 15
            jr z, bd_fa
            add hl, de
            ld a, (hl)
            or a
            sbc hl, de
            or a
            jr nz, bd_fb
bd_fa:
            set 5, c
bd_fb:
            ld a, c
            or a
            jr z, bd_xn
            ld hl, (bd_tot)
            ld de, 900
            or a
            sbc hl, de
            jr nc, bd_xn            ; (the list is full)
            ld hl, (bd_p)
            ld a, (bd_z)
            add a, a
            add a, a
            add a, a
            add a, a
            ld de, bd_x
            ex de, hl
            or (hl)
            ex de, hl
            ld (hl), a
            inc hl
            ld a, (bd_y)
            ld (hl), a
            inc hl
            ld (hl), c
            inc hl
            ld a, (bd_t)
            ld (hl), a
            inc hl
            ld (bd_p), hl
            ld hl, (bd_tot)
            inc hl
            ld (bd_tot), hl
            ld hl, bd_cnt
            inc (hl)
bd_xn:
            ld hl, bd_x
            inc (hl)
            ld a, (bd_x0)
            add a, 4
            cp (hl)
            jp nz, bd_x1
            ld hl, bd_z
            inc (hl)
            ld a, (bd_z0)
            add a, 4
            cp (hl)
            jp nz, bd_z1
            ld hl, bd_y
            inc (hl)
            ld a, (bd_y0)
            add a, 4
            cp (hl)
            jp nz, bd_y1
            ; gcnt(g)
            ld a, (bd_g0)
            ld e, a
            ld d, 0
            ld hl, {gcnt}
            add hl, de
            ld a, (bd_cnt)
            ld (hl), a
            ld a, (bd_g0)
            inc a
            cp 64
            jp nz, bd_g
            ld sp, ({sps})
            ret
bd_tot:     dw 0
bd_p:       dw 0
bd_g0:      db 0
bd_cnt:     db 0
bd_x0:      db 0
bd_y0:      db 0
bd_z0:      db 0
bd_x:       db 0
bd_y:       db 0
bd_z:       db 0
bd_t:       db 0
#endasm
End Sub

' Ticks(): frames gone by (the raster line watched while drawing, and at each call)
Public Function Ticks() As Integer
#asm
            ld ({sps}), sp
            ld sp, (ntc_csp)
            call fn_vox_render_tk_poll
            ld hl, (fn_vox_render_tk_n)
            ld sp, ({sps})
            ex de, hl
            pop hl
            ld (hl), e
            inc hl
            ld (hl), d
            ret
#endasm
End Function

' Sine(a): the sine of a (256 a turn), -127 .. 127
Public Function Sine(ByVal a As Integer) As Integer
#asm
            pop hl
            ld a, (hl)
            pop de
            ld l, a
            ld h, 0
            ld bc, sn_t
            add hl, bc
            ld a, (hl)
            ld l, a
            add a, a
            sbc a, a
            ld h, a
            ex de, hl
            ld (hl), e
            inc hl
            ld (hl), d
            ret
sn_t:
            db 0, 3, 6, 9, 12, 16, 19, 22, 25, 28, 31, 34, 37, 40, 43, 46
            db 49, 51, 54, 57, 60, 63, 65, 68, 71, 73, 76, 78, 81, 83, 85, 88
            db 90, 92, 94, 96, 98, 100, 102, 104, 106, 107, 109, 111, 112, 113, 115, 116
            db 117, 118, 120, 121, 122, 122, 123, 124, 125, 125, 126, 126, 126, 127, 127, 127
            db 127, 127, 127, 127, 126, 126, 126, 125, 125, 124, 123, 122, 122, 121, 120, 118
            db 117, 116, 115, 113, 112, 111, 109, 107, 106, 104, 102, 100, 98, 96, 94, 92
            db 90, 88, 85, 83, 81, 78, 76, 73, 71, 68, 65, 63, 60, 57, 54, 51
            db 49, 46, 43, 40, 37, 34, 31, 28, 25, 22, 19, 16, 12, 9, 6, 3
            db 0, 253, 250, 247, 244, 240, 237, 234, 231, 228, 225, 222, 219, 216, 213, 210
            db 207, 205, 202, 199, 196, 193, 191, 188, 185, 183, 180, 178, 175, 173, 171, 168
            db 166, 164, 162, 160, 158, 156, 154, 152, 150, 149, 147, 145, 144, 143, 141, 140
            db 139, 138, 136, 135, 134, 134, 133, 132, 131, 131, 130, 130, 130, 129, 129, 129
            db 129, 129, 129, 129, 130, 130, 130, 131, 131, 132, 133, 134, 134, 135, 136, 138
            db 139, 140, 141, 143, 144, 145, 147, 149, 150, 152, 154, 156, 158, 160, 162, 164
            db 166, 168, 171, 173, 175, 178, 180, 183, 185, 188, 191, 193, 196, 199, 202, 205
            db 207, 210, 213, 216, 219, 222, 225, 228, 231, 234, 237, 240, 244, 247, 250, 253
#endasm
End Function


' Project(x, y, z): where a point (world units) is on the screen, by the last Render's camera:
' True when it's ahead (then SX(), SY(): its pixel, 0-95 and 0-79 on the screen - it may be off
' it; SZ(): how far ahead, world units)
Public Function Project(ByVal x As Integer, ByVal y As Integer, ByVal z As Integer) As Integer
#asm
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (pj_x), hl
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (pj_y), hl
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (pj_z), hl
            pop hl
            ld (pj_res), hl
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ld hl, (pj_x)
            ld de, (fn_vox_render_rd_cx)
            or a
            sbc hl, de
            ld (pj_x), hl
            ld hl, (pj_y)
            ld de, (fn_vox_render_rd_cy)
            or a
            sbc hl, de
            ld (pj_y), hl
            ld hl, (pj_z)
            ld de, (fn_vox_render_rd_cz)
            or a
            sbc hl, de
            ld (pj_z), hl
            ; along forward: Z
            ld de, (pj_x)
            ld bc, (fn_vox_render_b_fx)
            call fn_vox_render_vx_fix
            ld (pj_a), hl
            ld de, (pj_y)
            ld bc, (fn_vox_render_b_fy)
            call fn_vox_render_vx_fix
            ld de, (pj_a)
            add hl, de
            ld (pj_a), hl
            ld de, (pj_z)
            ld bc, (fn_vox_render_b_fz)
            call fn_vox_render_vx_fix
            ld de, (pj_a)
            add hl, de
            ld ({projZ}), hl
            ld de, 32
            call pj_cmp
            jp c, pj_no             ; Z < 32: behind
            ; along right: X
            ld de, (pj_x)
            ld bc, (fn_vox_render_b_rx)
            call fn_vox_render_vx_fix
            ld (pj_a), hl
            ld de, (pj_z)
            ld bc, (fn_vox_render_b_rz)
            call fn_vox_render_vx_fix
            ld de, (pj_a)
            add hl, de
            ex de, hl
            ld bc, 64
            call fn_vox_render_vx_muls
            ld bc, ({projZ})
            call fn_vox_render_vx_divs
            ld de, 48
            add hl, de
            ld ({projX}), hl
            ; along up: Y
            ld de, (pj_x)
            ld bc, (fn_vox_render_b_ux)
            call fn_vox_render_vx_fix
            ld (pj_a), hl
            ld de, (pj_y)
            ld bc, (fn_vox_render_b_uy)
            call fn_vox_render_vx_fix
            ld de, (pj_a)
            add hl, de
            ld (pj_a), hl
            ld de, (pj_z)
            ld bc, (fn_vox_render_b_uz)
            call fn_vox_render_vx_fix
            ld de, (pj_a)
            add hl, de
            ex de, hl
            ld bc, 64
            call fn_vox_render_vx_muls
            ld bc, ({projZ})
            call fn_vox_render_vx_divs
            ex de, hl
            ld hl, 40
            or a
            sbc hl, de
            ld ({projY}), hl
            ld hl, 1
            jr pj_out
pj_no:
            ld hl, 0
pj_out:
            ld sp, ({sps})
            ex de, hl
            ld hl, (pj_res)
            ld (hl), e
            inc hl
            ld (hl), d
            ret
; carry if HL < DE (signed)
pj_cmp:
            ld a, h
            xor #80
            ld h, a
            ld a, d
            xor #80
            ld d, a
            or a
            sbc hl, de
            ret
pj_x:       dw 0
pj_y:       dw 0
pj_z:       dw 0
pj_a:       dw 0
pj_res:     dw 0
#endasm
End Function
Public Function SX() As Integer
  SX = projX
End Function
Public Function SY() As Integer
  SY = projY
End Function
Public Function SZ() As Integer
  SZ = projZ
End Function

' Solid(x, y, z): not 0 when the point (world units, 256 a block) is in a block or off the map
Public Function Solid(ByVal x As Integer, ByVal y As Integer, ByVal z As Integer) As Integer
#asm
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (so_x), hl
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (so_y), hl
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (so_z), hl
            pop hl
            ld (so_res), hl
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ld a, (so_x + 1)
            ld b, a
            ld a, (so_y + 1)
            ld c, a
            ld a, (so_z + 1)
            call so_blk
            ld sp, ({sps})
            ld hl, (so_res)
            ld (hl), a
            inc hl
            ld (hl), 0
            ret
; A = the block at cell B (x), C (y), A (z): 255 off the map
so_blk:
            ld e, a
            or b
            or c
            and #F0
            ld a, 255
            ret nz
            ld a, e
            add a, a
            add a, a
            add a, a
            add a, a
            or b
            ld l, a
            ld h, c
            ld de, {blk}
            add hl, de
            ld a, (hl)
            ret
so_x:       dw 0
so_y:       dw 0
so_z:       dw 0
so_res:     dw 0
#endasm
End Function

' Sight(x0, y0, z0, x1, y1, z1): True when nothing solid is on the line between (16 steps)
Public Function Sight(ByVal x0 As Integer, ByVal y0 As Integer, ByVal z0 As Integer, ByVal x1 As Integer, ByVal y1 As Integer, ByVal z1 As Integer) As Integer
#asm
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (si_x), hl
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (si_y), hl
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (si_z), hl
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (si_dx), hl
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (si_dy), hl
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (si_dz), hl
            pop hl
            ld (si_res), hl
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ; the step: (p1 - p0) / 16
            ld hl, (si_dx)
            ld de, (si_x)
            call si_d
            ld (si_dx), hl
            ld hl, (si_dy)
            ld de, (si_y)
            call si_d
            ld (si_dy), hl
            ld hl, (si_dz)
            ld de, (si_z)
            call si_d
            ld (si_dz), hl
            ld b, 15
si_lp:
            ld hl, (si_x)
            ld de, (si_dx)
            add hl, de
            ld (si_x), hl
            ld hl, (si_y)
            ld de, (si_dy)
            add hl, de
            ld (si_y), hl
            ld hl, (si_z)
            ld de, (si_dz)
            add hl, de
            ld (si_z), hl
            ; the cell
            ld a, (si_x + 1)
            ld c, a
            ld a, (si_y + 1)
            ld e, a
            ld a, (si_z + 1)
            ld d, a
            or c
            or e
            and #F0
            jr nz, si_next          ; off the map: open
            ld a, d
            add a, a
            add a, a
            add a, a
            add a, a
            or c
            ld l, a
            ld h, e
            push de
            ld de, {blk}
            add hl, de
            pop de
            ld a, (hl)
            or a
            jr nz, si_no
si_next:
            djnz si_lp
            ld de, 1
            jr si_out
si_no:
            ld de, 0
si_out:
            ld sp, ({sps})
            ld hl, (si_res)
            ld (hl), e
            inc hl
            ld (hl), d
            ret
; HL = (HL - DE) / 16 (signed)
si_d:
            or a
            sbc hl, de
            sra h
            rr l
            sra h
            rr l
            sra h
            rr l
            sra h
            rr l
            ret
si_x:       dw 0
si_y:       dw 0
si_z:       dw 0
si_dx:      dw 0
si_dy:      dw 0
si_dz:      dw 0
si_res:     dw 0
#endasm
End Function

' Render x, y, z, yaw, pitch, page: the view from x, y, z (256 a block) turned yaw (256 a turn)
' and pitch (+ up), drawn on the Layer 2 buffer whose first 8K page is page (32 or 38)
Public Sub Render(ByVal x As Integer, ByVal y As Integer, ByVal z As Integer, ByVal yaw As Integer, ByVal pitch As Integer, ByVal page As Integer)
#asm
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (rd_cx), hl
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (rd_cy), hl
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (rd_cz), hl
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (rd_yaw), hl
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (rd_pit), hl
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (rd_page), hl
            ld ({sps}), sp          ; the real stack (call / ret inside)
            ld sp, (ntc_csp)
            call rd_frame
            ld sp, ({sps})
            ret

; ================================================================ a frame
rd_frame:
            ; the corner cache: 8K page 44 in slot 7 while drawing (the tilemap's page goes
            ; back after - the display reads bank 5 whatever is in the slot)
            ld bc, #243B
            ld a, #57
            out (c), a
            inc b
            ld a, 44
            out (c), a
            ; its stamp (1 .. 7, a new one each frame; round to 1 again: every tag wiped)
            ld a, (rd_fr)
            inc a
            cp 8
            jr c, rf_s1
            ld hl, #E001
            ld de, 4
            ld c, 8
rf_w1:
            ld b, 0
rf_w2:
            ld (hl), 0
            add hl, de
            djnz rf_w2
            dec c
            jr nz, rf_w1
            ld a, 1
rf_s1:
            ld (rd_fr), a
            rrca
            rrca
            rrca
            ld (rd_fr5), a          ; << 5
            ld a, #FF
            ld (rd_cpage), a
            xor a
            ld (rd_full), a
            ld hl, iv_blk
            ld de, 32
            ld b, 80
rf_cl:
            ld (hl), 0
            add hl, de
            djnz rf_cl
            call rd_basis
            call rd_tables
            ld ix, {tab}
            call hdc
            ld (hd_x), hl
            ld ix, {tab} + 2
            call hdc
            ld (hd_y), hl
            ld ix, {tab} + 4
            call hdc
            ld (hd_z), hl
            ld a, (rd_cx + 1)       ; the camera's cell (floor of / 256: the high byte)
            ld (rd_ccx), a
            ld a, (rd_cy + 1)
            ld (rd_ccy), a
            ld a, (rd_cz + 1)
            ld (rd_ccz), a
            call tk_poll
            call rd_groups
            call rd_sky
            call tk_poll
            ld bc, #243B            ; slot 7 back to bank 5's second half (the tilemap)
            ld a, #57
            out (c), a
            inc b
            ld a, 11
            out (c), a
            ld bc, #243B            ; slot 6 back to bank 5's first half (the tiles)
            ld a, #56
            out (c), a
            inc b
            ld a, 10
            out (c), a
            ret

; ---- HL = half of (TX(1) - TX(0)) + (TY(1) - TY(0)) + (TZ(1) - TZ(0)), the component at IX
hdc:
            ld hl, 0
            ld b, 3
hd_lp:
            ld e, (ix + 6)
            ld d, (ix + 7)
            add hl, de
            ld e, (ix + 0)
            ld d, (ix + 1)
            or a
            sbc hl, de
            ld de, 102
            add ix, de
            djnz hd_lp
            sra h
            rr l
            ret

; ---- tk_poll: the frame count goes up when the raster line has gone round (called often
; enough - more than once a frame - it counts every frame; Ticks() reads it)
tk_poll:
            ld bc, #243B
            ld a, #1E
            out (c), a
            inc b
            in a, (c)
            ld h, a
            dec b
            ld a, #1F
            out (c), a
            inc b
            in a, (c)
            ld l, a
            ld de, (tk_last)
            ld (tk_last), hl
            or a
            sbc hl, de
            ret nc
            ld hl, (tk_n)
            inc hl
            ld (tk_n), hl
            ret
tk_last:    dw 0
tk_n:       dw 0

; ---- HL = sine (2.14) of A
rd_sin:
            ld l, a
            ld h, 0
            add hl, hl
            ld de, rd_sint
            add hl, de
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ret
rd_neg:
            xor a
            sub l
            ld l, a
            sbc a, a
            sub h
            ld h, a
            ret

; ---- the camera's basis from yaw and pitch: right (cy, 0, -sy), up, forward
rd_basis:
            ld a, (rd_yaw)
            call rd_sin
            ld (b_sy), hl
            ld a, (rd_yaw)
            add a, 64
            call rd_sin
            ld (b_cy), hl
            ld a, (rd_pit)
            call rd_sin
            ld (b_sp), hl
            ld a, (rd_pit)
            add a, 64
            call rd_sin
            ld (b_cp), hl
            ld de, (b_sy)
            ld bc, (b_cp)
            call vx_fix
            ld (b_fx), hl
            ld hl, (b_sp)
            ld (b_fy), hl
            ld de, (b_cy)
            ld bc, (b_cp)
            call vx_fix
            ld (b_fz), hl
            ld hl, (b_cy)
            ld (b_rx), hl
            ld hl, (b_sy)
            call rd_neg
            ld (b_rz), hl
            ld de, (b_sy)
            ld bc, (b_sp)
            call vx_fix
            call rd_neg
            ld (b_ux), hl
            ld hl, (b_cp)
            ld (b_uy), hl
            ld de, (b_cy)
            ld bc, (b_sp)
            call vx_fix
            call rd_neg
            ld (b_uz), hl
            ret

; ---- the tables: TX(i) = (i * 256 - cx) along right, up, forward; TY(j), TZ(k) the same
rd_tables:
            ld hl, (b_rx)
            ld (mk_b1), hl
            ld hl, (b_ux)
            ld (mk_b2), hl
            ld hl, (b_fx)
            ld (mk_b3), hl
            ld hl, {tab}
            ld de, (rd_cx)
            call mk
            ld hl, 0
            ld (mk_b1), hl
            ld hl, (b_uy)
            ld (mk_b2), hl
            ld hl, (b_fy)
            ld (mk_b3), hl
            ld hl, {tab} + 102
            ld de, (rd_cy)
            call mk
            ld hl, (b_rz)
            ld (mk_b1), hl
            ld hl, (b_uz)
            ld (mk_b2), hl
            ld hl, (b_fz)
            ld (mk_b3), hl
            ld hl, {tab} + 204
            ld de, (rd_cz)
            call mk
            ret
mk:
            ld (mk_p), hl
            ld hl, 0
            or a
            sbc hl, de
            ld (mk_d), hl
            ld b, 17
mk_lp:
            push bc
            ld de, (mk_d)
            ld bc, (mk_b1)
            call vx_fix
            call mk_put
            ld de, (mk_d)
            ld bc, (mk_b2)
            call vx_fix
            call mk_put
            ld de, (mk_d)
            ld bc, (mk_b3)
            call vx_fix
            call mk_put
            ld hl, (mk_d)
            inc h
            ld (mk_d), hl
            pop bc
            djnz mk_lp
            ret
mk_put:
            ex de, hl
            ld hl, (mk_p)
            ld (hl), e
            inc hl
            ld (hl), d
            inc hl
            ld (mk_p), hl
            ret

; ---- cc: the camera space of grid point (cn_i, cn_j, cn_k) -> cc_x, cc_y, cc_z
cc:
            ld a, (cn_i)
            ld c, a
            add a, a
            add a, c
            add a, a
            ld e, a
            ld d, 0
            ld ix, {tab}
            add ix, de
            ld a, (cn_j)
            ld c, a
            add a, a
            add a, c
            add a, a
            ld e, a
            ld iy, {tab} + 102
            add iy, de
            ld a, (cn_k)
            ld c, a
            add a, a
            add a, c
            add a, a
            ld e, a
            ld hl, {tab} + 204
            add hl, de
            ; x = TX.x + TZ.x (TY.x is 0)
            ld e, (hl)
            inc hl
            ld d, (hl)
            inc hl
            push hl
            ld l, (ix + 0)
            ld h, (ix + 1)
            add hl, de
            ld (cc_x), hl
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            inc hl
            push hl
            ld l, (ix + 2)
            ld h, (ix + 3)
            add hl, de
            ld e, (iy + 2)
            ld d, (iy + 3)
            add hl, de
            ld (cc_y), hl
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld l, (ix + 4)
            ld h, (ix + 5)
            add hl, de
            ld e, (iy + 4)
            ld d, (iy + 5)
            add hl, de
            ld (cc_z), hl
            ret

; ---- cproj: cc_x, cc_y, cc_z to the screen: B = x', C = y' (255, 255 when not on the fast path)
; x' = 128 + 64 x / z, y' = 128 - 64 y / z, by a reciprocal (3 ranges of z) and 3 MUL D,E
cproj:
            ld hl, (cc_z)
            ld a, h
            cp #10
            jp nc, cp_bad           ; z < 0 or z >= 4096 (past the murk)
            ld de, 32
            or a
            sbc hl, de
            jp c, cp_bad            ; z < 32
            add hl, de
            add hl, hl
            ld (cp_2z), hl
            ; |x| <= 2z, |y| <= 2z
            ld hl, (cc_x)
            ld a, h
            ld (cp_sx), a
            or a
            jp p, cp_1
            xor a
            sub l
            ld l, a
            sbc a, a
            sub h
            ld h, a
cp_1:
            ld (cp_ax), hl
            ex de, hl
            ld hl, (cp_2z)
            or a
            sbc hl, de
            jp c, cp_bad
            ld hl, (cc_y)
            ld a, h
            ld (cp_sy), a
            or a
            jp p, cp_2
            xor a
            sub l
            ld l, a
            sbc a, a
            sub h
            ld h, a
cp_2:
            ld (cp_ay), hl
            ex de, hl
            ld hl, (cp_2z)
            or a
            sbc hl, de
            jp c, cp_bad
            call cp_rec
            jp cp_xy
; ---- cp16: cc_x, cc_y, cc_z (z NEAR .. 16383) to the screen in 16 bits: HL = x', DE = y'
cp16:
            ld hl, (cc_x)
            ld a, h
            ld (cp_sx), a
            or a
            jp p, c6_1
            xor a
            sub l
            ld l, a
            sbc a, a
            sub h
            ld h, a
c6_1:
            ld (cp_ax), hl
            ld hl, (cc_y)
            ld a, h
            ld (cp_sy), a
            or a
            jp p, c6_2
            xor a
            sub l
            ld l, a
            sbc a, a
            sub h
            ld h, a
c6_2:
            ld (cp_ay), hl
            call cp_rec
            ld de, (cp_ax)
            call cp_mq
            ld a, (cp_sx)
            or a
            jp m, c6_xn
            ld de, 112
            add hl, de
            jr c6_xc
c6_xn:
            ex de, hl
            ld hl, 112
            or a
            sbc hl, de
c6_xc:
            ld (cp_wx), hl
            ld de, (cp_ay)
            call cp_mq
            ld a, (cp_sy)
            or a
            jp p, c6_yn
            ld de, 128
            add hl, de
            jr c6_yc
c6_yn:
            ex de, hl
            ld hl, 128
            or a
            sbc hl, de
c6_yc:
            ex de, hl
            ld hl, (cp_wx)
            ret
; ---- cp_rec: the reciprocal of cc_z: z < 1024 RA(z); < 4096 RB((z - 1024) / 4); else RC((z - 4096) / 16)
cp_rec:
            ld hl, (cc_z)
            ld a, h
            cp 4
            jr nc, cp_r2
            add hl, hl
            ld de, rd_ra
            add hl, de
            xor a
            jr cp_r4
cp_r2:
            cp 16
            jr nc, cp_r3
            ld de, -1024
            add hl, de
            srl h
            rr l
            res 0, l                ; (/ 4 * 2)
            ld de, rd_rb
            add hl, de
            ld a, 1
            jr cp_r4
cp_r3:
cp_r4:
            ld (cp_mode), a
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (cp_r), hl
            ret
cp_xy:
            ; x' = 128 +- q
            ld de, (cp_ax)
            call cp_mq
            ld a, (cp_sx)
            or a
            jp m, cp_xn
            ld de, 112
            add hl, de
            jr cp_xc
cp_xn:
            ex de, hl
            ld hl, 112
            or a
            sbc hl, de
cp_xc:
            ld a, h
            or a
            jr nz, cp_bad
            ld a, l
            cp 255
            jr z, cp_bad
            ld (cp_X), a
            ; y' = 128 -+ q
            ld de, (cp_ay)
            call cp_mq
            ld a, (cp_sy)
            or a
            jp p, cp_yn
            ld de, 128
            add hl, de
            jr cp_yc
cp_yn:
            ex de, hl
            ld hl, 128
            or a
            sbc hl, de
cp_yc:
            ld a, h
            or a
            jr nz, cp_bad
            ld a, l
            cp 255
            jr z, cp_bad
            ld c, a
            ld a, (cp_X)
            ld b, a
            ret
cp_bad:
            ld bc, #FFFF
            ret
; HL = q: the product a (DE) x R (cp_r) as ah rh << 8 + ah rl + al rh (al rl left out), then
; >> 7 (z < 1024), >> 12 (< 4096), >> 14
cp_mq:
            ld a, d
            ld (cp_ah), a
            ld a, e
            ld (cp_al), a
            ld bc, (cp_r)
            ld e, b                 ; D = ah, E = rh
cp_zm1:
            db #ED, #30             ; mul d, e: ah rh
            ld h, d
            ld l, e
            ld a, (cp_ah)
            ld d, a
            ld e, c
cp_zm2:
            db #ED, #30             ; ah rl
            push de
            ld a, (cp_al)
            ld d, a
            ld e, b
cp_zm3:
            db #ED, #30             ; al rh
            ex de, hl               ; HL = al rh, DE = ah rh
            pop bc
            add hl, bc              ; HL = ah rl + al rh (a carry is 256 in DE)
            jr nc, cp_m1
            inc d
cp_m1:
            ld a, h                 ; U = DE + H, the low byte L
            add a, e
            ld e, a
            jr nc, cp_m2
            inc d
cp_m2:
            ex de, hl               ; HL = U, E = the low byte
            ld a, (cp_mode)
            or a
            jr nz, cp_m3
            sla e
            adc hl, hl
            ret
cp_m3:
            ld b, 4
            dec a
            jr z, cp_m4
            ld b, 6
cp_m4:
            srl h
            rr l
            djnz cp_m4
            ret

; ================================================================ groups, front to back
rd_groups:
            ld hl, gh
            ld de, gh + 1
            ld bc, 15
            ld (hl), #FF
            ldir
            ; the camera's group: cell / 4, kept to -1 .. 4
            ld a, (rd_ccx)
            call gq
            ld (rd_cgx), a
            ld a, (rd_ccy)
            call gq
            ld (rd_cgy), a
            ld a, (rd_ccz)
            call gq
            ld (rd_cgz), a
            xor a
gr_lp:
            ld (gr_g), a
            ld l, a
            ld h, 0
            ld de, {gcnt}
            add hl, de
            ld a, (hl)
            or a
            jp z, gr_next
            ; its middle, in camera space
            ld a, (gr_g)
            and 3
            add a, a
            add a, a
            add a, 2
            ld (cn_i), a
            ld a, (gr_g)
            and 12
            add a, 2
            ld (cn_k), a
            ld a, (gr_g)
            rrca
            rrca
            and #3C
            add a, 2
            ld (cn_j), a
            call cc
            ; z < -887: behind
            ld hl, (cc_z)
            ld de, -887
            call cmps
            jp c, gr_next
            ; x - z > 1254, -x - z > 1254
            ld hl, (cc_x)
            ld de, (cc_z)
            or a
            sbc hl, de
            ld de, 1254
            call cmpgt
            jp c, gr_next
            ld hl, (cc_x)
            call rd_neg
            ld de, (cc_z)
            or a
            sbc hl, de
            ld de, 1254
            call cmpgt
            jp c, gr_next
            ; t = z >> 1 + z >> 3: y - t > 1046, -y - t > 1046
            ld hl, (cc_z)
            sra h
            rr l
            ld d, h
            ld e, l
            sra h
            rr l
            sra h
            rr l
            add hl, de
            ld (gr_t), hl
            ex de, hl
            ld hl, (cc_y)
            or a
            sbc hl, de
            ld de, 1046
            call cmpgt
            jp c, gr_next
            ld hl, (cc_y)
            call rd_neg
            ld de, (gr_t)
            or a
            sbc hl, de
            ld de, 1046
            call cmpgt
            jp c, gr_next
            ; inside the view altogether? then its cells needn't be tested one by one
            ld b, 1
            ld hl, (cc_z)
            ld de, 887
            call cmpgt
            jr nc, gr_i9
            ld hl, (cc_x)
            ld de, (cc_z)
            or a
            sbc hl, de
            ld de, -1254
            call cmps
            jr nc, gr_i9
            ld hl, (cc_x)
            call rd_neg
            ld de, (cc_z)
            or a
            sbc hl, de
            ld de, -1254
            call cmps
            jr nc, gr_i9
            ld hl, (cc_y)
            ld de, (gr_t)
            or a
            sbc hl, de
            ld de, -1046
            call cmps
            jr nc, gr_i9
            ld hl, (cc_y)
            call rd_neg
            ld de, (gr_t)
            or a
            sbc hl, de
            ld de, -1046
            call cmps
            jr nc, gr_i9
            ld b, 0
gr_i9:
            ld a, (gr_g)
            ld e, a
            ld d, 0
            ld hl, gst
            add hl, de
            ld (hl), b
            ; d = |gx - cgx| + |gy - cgy| + |gz - cgz|
            ld a, (gr_g)
            and 3
            ld hl, rd_cgx
            call absd
            ld c, a
            ld a, (gr_g)
            rrca
            rrca
            rrca
            rrca
            and 3
            ld hl, rd_cgy
            call absd
            add a, c
            ld c, a
            ld a, (gr_g)
            rrca
            rrca
            and 3
            ld hl, rd_cgz
            call absd
            add a, c
            ; gnext(g) = gh(d), gh(d) = g
            ld e, a
            ld d, 0
            ld hl, gh
            add hl, de
            ld b, (hl)
            ld a, (gr_g)
            ld (hl), a
            ld e, a
            ld hl, gnext
            add hl, de
            ld (hl), b
gr_next:
            ld a, (gr_g)
            inc a
            cp 64
            jp nz, gr_lp
            ; the groups, nearest first
            xor a
gr_d:
            ld (gr_dd), a
            ld e, a
            ld d, 0
            ld hl, gh
            add hl, de
            ld a, (hl)
gr_w:
            cp #FF
            jr z, gr_dn
            ld (gr_g), a
            ld e, a
            ld d, 0
            ld hl, gst
            add hl, de
            ld a, (hl)
            ld (dg_st), a
            ld a, (rd_full)
            cp 80
            ret z
            call do_group
            call tk_poll
            ld a, (gr_g)
            ld e, a
            ld d, 0
            ld hl, gnext
            add hl, de
            ld a, (hl)
            jr gr_w
gr_dn:
            ld a, (gr_dd)
            inc a
            cp 16
            jr nz, gr_d
            ret
; A = cell / 4 (arithmetic), kept to -1 .. 4
gq:
            sra a
            sra a
            bit 7, a
            jr z, gq1
            cp #FF
            ret nc
            ld a, #FF
            ret
gq1:
            cp 5
            ret c
            ld a, 4
            ret
; A = |A - (HL)| (signed bytes, small)
absd:
            sub (hl)
            ret p
            neg
            ret
; carry if HL < DE (signed)
cmps:
            ld a, h
            xor #80
            ld h, a
            ld a, d
            xor #80
            ld d, a
            or a
            sbc hl, de
            ret
; carry if HL > DE (signed)
cmpgt:
            ex de, hl
            jr cmps

; ---- a group: its cells by Manhattan distance from the camera's cell, nearest first
do_group:
            ld a, (gr_g)
            and 3
            add a, a
            add a, a
            ld hl, rd_ccx
            call mind
            ld c, a
            ld a, (gr_g)
            rrca
            rrca
            and #3C
            ld hl, rd_ccy
            call mind
            add a, c
            ld c, a
            ld a, (gr_g)
            and 12
            ld hl, rd_ccz
            call mind
            add a, c
            ld (dg_min), a
            cp 13
            ret nc                  ; all of it past the draw distance
            ld hl, hb
            ld de, hb + 1
            ld bc, 9
            ld (hl), #FF
            ldir
            ; the cells: {cells} + gstart(g) * 4
            ld a, (gr_g)
            ld l, a
            ld h, 0
            add hl, hl
            ld de, {gstart}
            add hl, de
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            add hl, hl
            add hl, hl
            ld de, {cells}
            add hl, de
            ld (dg_p), hl
            ld a, (gr_g)
            ld e, a
            ld d, 0
            ld hl, {gcnt}
            add hl, de
            ld a, (hl)
            ld (dg_n), a
            ld ix, (dg_p)
            ld c, 0
dg_b:
            ; d = |x - ccx| + |y - ccy| + |z - ccz| - dmin
            ld a, (ix + 0)
            and 15
            ld hl, rd_ccx
            call absd
            ld b, a
            ld a, (ix + 1)
            ld hl, rd_ccy
            call absd
            add a, b
            ld b, a
            ld a, (ix + 0)
            rrca
            rrca
            rrca
            rrca
            and 15
            ld hl, rd_ccz
            call absd
            add a, b
            ld hl, dg_min
            sub (hl)
            ld e, a
            ld d, 0
            ld hl, hb
            add hl, de
            ld b, (hl)
            ld (hl), c
            ld e, c
            ld hl, cnext
            add hl, de
            ld (hl), b
            ld de, 4
            add ix, de
            inc c
            ld a, (dg_n)
            cp c
            jr nz, dg_b
            ; nearest first
            xor a
dg_k:
            ld (dg_bk), a
            ld hl, dg_min
            add a, (hl)
            ld (dc_d), a            ; the cells' distance
            cp 13
            ret nc
            ld a, (dg_bk)
            ld e, a
            ld d, 0
            ld hl, hb
            add hl, de
            ld a, (hl)
dg_w:
            cp #FF
            jr z, dg_kn
            ld (dg_c), a
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            ld de, (dg_p)
            add hl, de
            call do_cell
            ld a, (dg_c)
            ld e, a
            ld d, 0
            ld hl, cnext
            add hl, de
            ld a, (hl)
            jr dg_w
dg_kn:
            ld a, (dg_bk)
            inc a
            cp 10
            jr nz, dg_k
            ret
; A = how far (HL) (a cell) is from the span A .. A + 3 along one axis
mind:
            ld b, a
            ld a, (hl)
            sub b
            jp m, md_lo             ; camera below the span: lo - c
            sub 3
            ret nc                  ; above: c - lo - 3
            xor a
            ret
md_lo:
            neg
            ret

; ---- a cell (HL = its record: x | z << 4, y, faces open, type): its faces towards the camera
do_cell:
            ld a, (hl)
            ld e, a
            and 15
            ld (fc_x), a
            ld d, a                 ; D = x
            ld a, e
            rrca
            rrca
            rrca
            rrca
            and 15
            ld (fc_z), a
            ld e, a                 ; E = z
            inc hl
            ld b, (hl)              ; B = y
            ld a, b
            ld (fc_y), a
            inc hl
            ld c, (hl)              ; C = the open faces
            inc hl
            ld a, (hl)
            ld (fc_t), a
            ; the sides towards the camera: -X when the camera's x cell is less, +X more ...
            ld a, (rd_ccx)
            ld h, a
            ld a, d
            sub h
            ld l, 0
            jr z, dc_1
            ld l, 1
            jp p, dc_1
            ld l, 2
dc_1:
            ld a, (rd_ccy)
            ld h, a
            ld a, b
            sub h
            jr z, dc_2
            ld a, 4
            jp p, dc_2a
            ld a, 8
dc_2a:
            or l
            ld l, a
dc_2:
            ld a, (rd_ccz)
            ld h, a
            ld a, e
            sub h
            jr z, dc_3
            ld a, 16
            jp p, dc_3a
            ld a, 32
dc_3a:
            or l
            ld l, a
dc_3:
            ld a, l
            and c
            ret z
            ld (dc_m), a
            ; in a group on the edge of the view: is the cell in it? (its middle, 224 round)
            ld a, (dg_st)
            or a
            jp z, dc_in
            ld a, (fc_x)
            ld (cn_i), a
            ld a, (fc_y)
            ld (cn_j), a
            ld a, (fc_z)
            ld (cn_k), a
            call cc
            ld hl, (cc_x)
            ld de, (hd_x)
            add hl, de
            ld (cc_x), hl
            ld hl, (cc_y)
            ld de, (hd_y)
            add hl, de
            ld (cc_y), hl
            ld hl, (cc_z)
            ld de, (hd_z)
            add hl, de
            ld (cc_z), hl
            ld de, -224
            call cmps
            ret c
            ld hl, (cc_x)
            ld de, (cc_z)
            or a
            sbc hl, de
            ld de, 316
            call cmpgt
            ret c
            ld hl, (cc_x)
            call rd_neg
            ld de, (cc_z)
            or a
            sbc hl, de
            ld de, 316
            call cmpgt
            ret c
            ld hl, (cc_z)
            sra h
            rr l
            ld d, h
            ld e, l
            sra h
            rr l
            sra h
            rr l
            add hl, de
            ld (dc_t), hl
            ex de, hl
            ld hl, (cc_y)
            or a
            sbc hl, de
            ld de, 264
            call cmpgt
            ret c
            ld hl, (cc_y)
            call rd_neg
            ld de, (dc_t)
            or a
            sbc hl, de
            ld de, 264
            call cmpgt
            ret c
            ld a, (fc_x)
            ld d, a
            ld a, (fc_z)
            ld e, a
            ld a, (fc_y)
            ld b, a
dc_in:
            ; the cell's grid number: x + 17 z + 289 y (289 y = 256 y + 33 y)
            ld a, d
            ld d, e
            ld e, 17
            ld c, a
dc_zm1:
            db #ED, #30             ; 17 z
            ld h, 0
            ld l, c
            add hl, de
            ld d, b
            ld e, 33
dc_zm2:
            db #ED, #30             ; 33 y
            add hl, de
            ld a, h
            add a, b
            ld h, a                 ; + 256 y
            ld (fc_gid), hl
            ; the colours: type * 8 + face (the top's other square: 6)
            ld a, (fc_t)
            add a, a
            add a, a
            add a, a
            ld (dc_cb), a
            xor a
dc_f:
            ld (fc_f), a
            ld hl, dc_m
            rrc (hl)
            jr nc, dc_fn
            ld hl, dc_cb
            add a, (hl)
            ld e, a
            ld a, (fc_f)
            cp 3
            jr nz, dc_c
            ld a, (fc_x)
            ld hl, fc_z
            add a, (hl)
            rrca
            jr nc, dc_c
            inc e
            inc e
            inc e
dc_c:
            ld d, 0
            ld hl, rd_col
            add hl, de
            ; the fog: the colour set for the distance (128 a set)
            push hl
            ld a, (dc_d)
            ld e, a
            ld hl, fogt
            add hl, de
            ld a, (hl)
            pop hl
            rrca
            ld e, a
            and #80
            ld d, a
            ld a, e
            and #7F
            ld e, d
            ld d, a
            add hl, de
            ld a, (hl)
            ld (fl_col), a
            ld (fl_col + 1), a
            call face
dc_fn:
            ld a, (fc_f)
            inc a
            cp 6
            jr nz, dc_f
            ret

; ---- a face (fc_x, fc_y, fc_z, fc_f, fc_gid; fl_col): its corners (from the cache, or worked
; out and kept), then filled; the slow way when a corner is too near or far off to the side
face:
            ld a, (fc_f)
            add a, a
            add a, a
            ld b, a
            add a, a
            add a, a
            add a, b                ; 20 f
            ld e, a
            ld d, 0
            ld iy, rd_ft
            add iy, de
            xor a
            ld (fc_k), a
fc_lp:
            ld hl, (fc_gid)
            ld e, (iy + 3)
            ld d, (iy + 4)
            add hl, de              ; the corner's grid number
            ; the cache: 2048 entries of 4 at #E000 + (number and 2047) * 4: the tag (the number,
            ; the stamp in its top 3 bits), x', y'
            ld b, l
            ld a, (rd_fr5)
            or h
            ld c, a                 ; BC = the tag
            ld a, h
            and 7
            ld h, a
            add hl, hl
            add hl, hl
            ld a, h
            or #E0
            ld h, a
            ld a, (hl)
            cp b
            jr nz, fc_miss
            inc hl
            ld a, (hl)
            cp c
            jr nz, fc_m1
            inc hl
            ld b, (hl)
            inc hl
            ld c, (hl)
            jr fc_got
fc_m1:
            dec hl
fc_miss:
            ld (hl), b
            inc hl
            ld (hl), c
            inc hl
            push hl
            ld a, (fc_x)
            add a, (iy + 0)
            ld (cn_i), a
            ld a, (fc_y)
            add a, (iy + 1)
            ld (cn_j), a
            ld a, (fc_z)
            add a, (iy + 2)
            ld (cn_k), a
            push iy
            call cc
            call cproj
            pop iy
            pop hl
            ld (hl), b
            inc hl
            ld (hl), c
fc_got:
            ld a, c
            cp 255
            jp z, slow
            ld a, (fc_k)
            ld e, a
            ld d, 0
            ld hl, px
            add hl, de
            ld (hl), b
            ld e, 16
            add hl, de
            ld (hl), c
            ld de, 5
            add iy, de
            inc a
            ld (fc_k), a
            cp 4
            jp nz, fc_lp
            ld (rs_n), a
            jp raster

; ---- the slow way: cut at the near plane, project, cut to the screen
slow:
            ld a, (fc_f)
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            ld d, h
            ld e, l
            add hl, hl
            add hl, hl
            add hl, de
            ld de, rd_ft
            add hl, de
            ld (fc_tp), hl
            ld hl, s1
            ld (sl_q), hl
            xor a
            ld (sl_nr), a
            ld b, 4
sl_lp:
            push bc
            ld hl, (fc_tp)
            ld a, (fc_x)
            add a, (hl)
            ld (cn_i), a
            inc hl
            ld a, (fc_y)
            add a, (hl)
            ld (cn_j), a
            inc hl
            ld a, (fc_z)
            add a, (hl)
            ld (cn_k), a
            inc hl
            inc hl
            inc hl
            ld (fc_tp), hl
            call cc
            ld hl, (sl_q)
            ld de, (cc_x)
            ld (hl), e
            inc hl
            ld (hl), d
            inc hl
            ld de, (cc_y)
            ld (hl), e
            inc hl
            ld (hl), d
            inc hl
            ld de, (cc_z)
            ld (hl), e
            inc hl
            ld (hl), d
            inc hl
            ld (sl_q), hl
            ; z: too near? too far (16384 on: dropped)?
            ld hl, (cc_z)
            ld a, h
            or a
            jp m, sl_nr1
            cp #10
            jp nc, sl_far
            ld de, 32
            or a
            sbc hl, de
            jr nc, sl_nx
sl_nr1:
            ld hl, sl_nr
            inc (hl)
sl_nx:
            pop bc
            djnz sl_lp
            ld a, 4
            ld (sl_n), a
            ld a, (sl_nr)
            or a
            ld hl, s1
            jp z, sl_proj
            cp 4
            ret z                   ; all too near
            ; z >= NEAR: s1 (4) -> s2
            ld hl, s2
            ld (sl_q), hl
            xor a
            ld (sl_m), a
            ld (sl_i), a
sz_lp:
            ld a, (sl_i)
            call sl_ab6             ; IX = a, IY = b (6 byte points from s1)
            ld l, (ix + 4)
            ld h, (ix + 5)
            ld de, 32
            call cmps
            ccf
            sbc a, a
            ld (sl_ain), a          ; #FF in
            ld l, (iy + 4)
            ld h, (iy + 5)
            ld de, 32
            call cmps
            ccf
            sbc a, a
            ld (sl_bin), a
            ld a, (sl_ain)
            or a
            jr z, sz_1
            ld b, 6
            push ix
            pop hl
            call sl_put
sz_1:
            ld a, (sl_ain)
            ld hl, sl_bin
            cp (hl)
            jp z, sz_n
            ; t0 = NEAR - a.z, dz = b.z - a.z
            ld l, (ix + 4)
            ld h, (ix + 5)
            ex de, hl
            ld hl, 32
            or a
            sbc hl, de
            ld (sl_t0), hl
            ld l, (iy + 4)
            ld h, (iy + 5)
            or a
            sbc hl, de
            ld (sl_dz), hl
            ld l, (ix + 0)          ; x
            ld h, (ix + 1)
            ld e, (iy + 0)
            ld d, (iy + 1)
            call sl_lerp
            ld (sl_v), hl
            ld l, (ix + 2)          ; y
            ld h, (ix + 3)
            ld e, (iy + 2)
            ld d, (iy + 3)
            call sl_lerp
            ld (sl_v + 2), hl
            ld hl, 32
            ld (sl_v + 4), hl
            ld hl, sl_v
            ld b, 6
            call sl_put
sz_n:
            ld a, (sl_i)
            inc a
            ld (sl_i), a
            cp 4
            jp nz, sz_lp
            ld a, (sl_m)
            cp 3
            ret c
            ld (sl_n), a
            ld hl, s2
sl_proj:
            ; HL = the points (x, y, z), sl_n of them: projected (16 bits) into s3
            ld (sl_src), hl
            ld hl, s3
            ld (sl_q), hl
            ld a, (sl_n)
            ld b, a
sp_lp:
            push bc
            ld hl, (sl_src)
            ld de, cc_x
            ld bc, 6
            ldir
            ld (sl_src), hl
            call cp16
            push de
            ex de, hl
            ld hl, (sl_q)
            ld (hl), e
            inc hl
            ld (hl), d
            inc hl
            pop de
            ld (hl), e
            inc hl
            ld (hl), d
            inc hl
            ld (sl_q), hl
            pop bc
            djnz sp_lp
            ; the box round it: all off one side of the screen, nothing
            ld ix, s3
            ld hl, 32767
            ld (bx_x0), hl
            ld (bx_y0), hl
            ld hl, -32768
            ld (bx_x1), hl
            ld (bx_y1), hl
            ld a, (sl_n)
            ld b, a
bx_lp:
            push bc
            ld l, (ix + 0)
            ld h, (ix + 1)
            ld de, bx_x0
            call bx_mm
            ld l, (ix + 2)
            ld h, (ix + 3)
            ld de, bx_y0
            call bx_mm
            ld de, 4
            add ix, de
            pop bc
            djnz bx_lp
            ld hl, (bx_x1)
            ld de, 64
            call cmps
            ret c
            ld hl, (bx_x0)
            ld de, 160 - 1
            call cmpgt
            ret c
            ld hl, (bx_y1)
            ld de, 88
            call cmps
            ret c
            ld hl, (bx_y0)
            ld de, 167
            call cmpgt
            ret c
            ; cut to 0 .. 254 where it goes past
            ld hl, s3
            ld (sl_cur), hl
            ld hl, (bx_x0)
            bit 7, h
            jr z, sg_1
            xor a
            ld (c2_ax), a
            ld (c2_ge), a
            ld hl, 0
            call sg_cut
            ret c
sg_1:
            ld hl, (bx_x1)
            ld de, 254
            call cmpgt
            jr nc, sg_2
            xor a
            ld (c2_ax), a
            inc a
            ld (c2_ge), a
            ld hl, 254
            call sg_cut
            ret c
sg_2:
            ld hl, (bx_y0)
            bit 7, h
            jr z, sg_3
            ld a, 2
            ld (c2_ax), a
            xor a
            ld (c2_ge), a
            ld hl, 0
            call sg_cut
            ret c
sg_3:
            ld hl, (bx_y1)
            ld de, 254
            call cmpgt
            jr nc, sg_4
            ld a, 2
            ld (c2_ax), a
            ld a, 1
            ld (c2_ge), a
            ld hl, 254
            call sg_cut
            ret c
sg_4:
            ld hl, (sl_cur)
            jr sl_bytes
sl_far:
            pop bc
            ret
; one cut: c2_lim = HL; (sl_cur) -> the other buffer, which is then current. C = too few left
sg_cut:
            ld (c2_lim), hl
            ld hl, (sl_cur)
            ld de, s3
            or a
            sbc hl, de
            ld hl, s3
            ld de, s4
            jr z, sg_c1
            ex de, hl
sg_c1:
            ld (sl_cur), de
            jp clip2
; the box: (DE) = min(HL, (DE)), (DE + 4) = max
bx_mm:
            push hl
            push de
            ex de, hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ex de, hl               ; DE = min so far
            call cmps
            pop de
            pop hl
            jr nc, bx_1
            ex de, hl
            ld (hl), e
            inc hl
            ld (hl), d
            dec hl
            ex de, hl
bx_1:
            inc de
            inc de
            inc de
            inc de
            push hl
            push de
            ex de, hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ex de, hl
            call cmpgt
            pop de
            pop hl
            ret nc
            ex de, hl
            ld (hl), e
            inc hl
            ld (hl), d
            ret
sl_bytes:
            ; the points -> px, py (bytes now)
            ld a, (sl_n)
            ld (rs_n), a
            ld b, a
            ld de, 0
sb_lp:
            ld a, (hl)
            push hl
            ld hl, px
            add hl, de
            ld (hl), a
            pop hl
            inc hl
            inc hl
            ld a, (hl)
            push hl
            ld hl, py
            add hl, de
            ld (hl), a
            pop hl
            inc hl
            inc hl
            inc e
            djnz sb_lp
            jp raster
; IX = point A of s1, IY = point (A + 1) mod sl_n (6 bytes each)
sl_ab6:
            ld b, a
            add a, a
            add a, b
            add a, a
            ld e, a
            ld d, 0
            ld ix, s1
            add ix, de
            ld a, b
            inc a
            ld hl, sl_n
            cp (hl)
            jr c, sl_ab1
            xor a
sl_ab1:
            ld b, a
            add a, a
            add a, b
            add a, a
            ld e, a
            ld iy, s1
            add iy, de
            ret
; copy B bytes from HL to (sl_q), one more point
sl_put:
            ld de, (sl_q)
            ld c, b
            ld b, 0
            ldir
            ld (sl_q), de
            ld hl, sl_m
            inc (hl)
            ret
; HL = a + (b - a) * sl_t0 / sl_dz, a = HL, b = DE
sl_lerp:
            push hl
            ex de, hl
            pop de
            push de
            or a
            sbc hl, de
            ex de, hl
            ld bc, (sl_t0)
            call vx_muls
            ld bc, (sl_dz)
            call vx_divs
            pop de
            add hl, de
            ret
; HL = DE * 64 / BC, kept to +-12000
div64:
            push bc
            ld bc, 64
            call vx_muls
            pop bc
            call vx_divs
            ld de, 12000
            push hl
            call cmpgt
            pop hl
            jr nc, dv_1
            ld hl, 12000
            ret
dv_1:
            ld de, -12000
            push hl
            call cmps
            pop hl
            ret nc
            ld hl, -12000
            ret
; clip2: the polygon at HL (sl_n points, x, y words) cut by c2_ax (0 x, 2 y) >= / <= c2_lim
; (c2_ge 0: keep >=, 1: keep <=) into DE; C = fewer than 3 left
clip2:
            ld (c2_src), hl
            ld (sl_q), de
            xor a
            ld (sl_m), a
            ld (sl_i), a
c2_lp:
            ; IX = point i, IY = point i + 1 mod n
            ld a, (sl_i)
            add a, a
            add a, a
            ld e, a
            ld d, 0
            ld ix, (c2_src)
            add ix, de
            ld a, (sl_i)
            inc a
            ld hl, sl_n
            cp (hl)
            jr c, c2_a
            xor a
c2_a:
            add a, a
            add a, a
            ld e, a
            ld iy, (c2_src)
            add iy, de
            push ix
            pop hl
            call c2_in
            ld (sl_ain), a
            push iy
            pop hl
            call c2_in
            ld (sl_bin), a
            ld a, (sl_ain)
            or a
            jr z, c2_1
            push ix
            pop hl
            ld b, 4
            call sl_put
c2_1:
            ld a, (sl_ain)
            ld hl, sl_bin
            cp (hl)
            jp z, c2_n
            ; t = a.o + (b.o - a.o) * (lim - a.ax) / (b.ax - a.ax)
            ld a, (c2_ax)
            ld e, a
            ld d, 0
            push ix
            pop hl
            add hl, de
            ld e, (hl)
            inc hl
            ld d, (hl)              ; a.ax
            ld hl, (c2_lim)
            or a
            sbc hl, de
            ld (sl_t0), hl
            push de
            ld a, (c2_ax)
            ld e, a
            ld d, 0
            push iy
            pop hl
            add hl, de
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            pop de
            or a
            sbc hl, de
            ld (sl_dz), hl
            ld a, (c2_ax)
            xor 2
            ld e, a
            ld d, 0
            push iy
            pop hl
            add hl, de
            ld c, (hl)
            inc hl
            ld b, (hl)
            push ix
            pop hl
            add hl, de
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld d, b
            ld e, c
            call sl_lerp            ; the other coordinate
            ld a, (c2_ax)
            or a
            jr nz, c2_y
            ld (sl_v + 2), hl
            ld hl, (c2_lim)
            ld (sl_v), hl
            jr c2_p
c2_y:
            ld (sl_v), hl
            ld hl, (c2_lim)
            ld (sl_v + 2), hl
c2_p:
            ld hl, sl_v
            ld b, 4
            call sl_put
c2_n:
            ld a, (sl_i)
            inc a
            ld (sl_i), a
            ld hl, sl_n
            cp (hl)
            jp nz, c2_lp
            ld a, (sl_m)
            ld (sl_n), a
            cp 3
            ret
; A = #FF if the point at HL is kept
c2_in:
            ld a, (c2_ax)
            ld e, a
            ld d, 0
            add hl, de
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld de, (c2_lim)
            ld a, (c2_ge)
            or a
            jr nz, c2_le
            call cmps               ; keep a >= lim: C = a < lim
            ccf
            sbc a, a
            ret
c2_le:
            call cmpgt              ; keep a <= lim: C = a > lim
            ccf
            sbc a, a
            ret

; ================================================================ filling a polygon
; raster: px, py (rs_n points, bytes: x' 64 .. 191 and y' 88 .. 167 are on the screen), colour
; fl_col: the left and right edge of each row (ed_u, ed_d), then each row's span to cover
raster:
            ld ix, px
            ld a, (rs_n)
            ld b, a
            ld hl, #00FF            ; H = max x, L = min x
            ld de, #00FF            ; D = max y, E = min y
rs_mm:
            ld a, (ix + 0)
            cp l
            jr nc, rs_m1
            ld l, a
rs_m1:
            cp h
            jr c, rs_m2
            ld h, a
rs_m2:
            ld a, (ix + 16)
            cp e
            jr nc, rs_m3
            ld e, a
rs_m3:
            cp d
            jr c, rs_m4
            ld d, a
rs_m4:
            inc ix
            djnz rs_mm
            ; all off one side of the screen: nothing
            ld a, h
            cp 64
            ret c
            ld a, l
            cp 160
            ret nc
            ld a, d
            cp 88
            ret c
            ld a, e
            cp 168
            ret nc
            ; the rows: ytop = max(min y, 88) .. ybot = min(max y, 168)
            cp 88
            jr nc, rs_t
            ld a, 88
rs_t:
            ld (rs_top), a
            ld e, a
            ld a, d
            cp 168
            jr c, rs_b
            ld a, 168
rs_b:
            ld (rs_bot), a
            sub e
            ret c
            ret z
            ; the rows' edges to start with: left 255, right 0 (no span)
            ld b, a
            ld l, e
            ld h, ed_u / 256
rs_df:
            ld (hl), 255
            inc h
            ld (hl), 0
            dec h
            inc l
            djnz rs_df
            ; the edges (the first point again after the last)
            ld a, (px)
            ld (ix + 0), a
            ld a, (py)
            ld (ix + 16), a
            ld ix, px
            ld a, (rs_n)
rs_e:
            ld (rs_i), a
            ld d, (ix + 0)
            ld e, (ix + 16)
            ld b, (ix + 1)
            ld c, (ix + 17)
            call edge
            inc ix
            ld a, (rs_i)
            dec a
            jr nz, rs_e
            ; the spans, row by row: the row's list and Layer 2 line moved on as it goes
            ld a, (rs_top)
            ld (rs_y), a
            sub 88
            call rowcalc
            ld (rs_lp), hl
rs_s:
            ld a, (rs_y)
            ld l, a
            ld h, ed_u / 256
            ld a, (hl)
            cp 64
            jr nc, rs_s1
            ld a, 64
rs_s1:
            cp 160
            jr c, rs_s2
            ld a, 160
rs_s2:
            ld b, a
            inc h
            ld a, (hl)
            cp 64
            jr nc, rs_s3
            ld a, 64
rs_s3:
            cp 160
            jr c, rs_s4
            ld a, 160
rs_s4:
            cp b
            jr z, rs_sn
            jr c, rs_sn
            sub 64
            ld c, a
            ld a, b
            sub 64
            ld b, a
            ld a, (rs_pg)
            ld hl, rd_cpage
            cp (hl)
            call nz, rowmap
            ld hl, (rs_lp)
            call cover
rs_sn:
            ld a, (rs_y)
            inc a
            ld hl, rs_bot
            cp (hl)
            ret z
            ld (rs_y), a
            ld hl, (rs_lp)
            ld de, 32
            add hl, de
            ld (rs_lp), hl
            ld a, (fl_h)
            add a, 2
            cp #E0
            jr c, rs_s5
            ld hl, rs_pg
            inc (hl)
            ld a, #C0
rs_s5:
            ld (fl_h), a
            jp rs_s

; ---- rowcalc: A = a row (0 .. 79): HL = its list; fl_h = its Layer 2 line's high byte in
; slot 6, rs_pg the 8K page that line is in. rowsel: the same, and that page put in slot 6
rowsel:
            call rowcalc
            ld a, (rs_pg)
            ld de, rd_cpage
            ex de, hl
            cp (hl)
            ex de, hl
            ret z
rowmap:
            ; slot 6 = page A (keeps BC, HL)
            ld (rd_cpage), a
            push bc
            ld bc, #243B
            ld e, a
            ld a, #56
            out (c), a
            inc b
            out (c), e
            pop bc
            ret
rowcalc:
            ld e, a
            add a, a
            add a, 16               ; the Layer 2 line
            ld d, a
            and 31
            add a, #C0
            ld (fl_h), a
            ld a, d
            rlca
            rlca
            rlca
            and 7
            ld hl, rd_page
            add a, (hl)
            ld (rs_pg), a
            ld a, e
            and 7
            rrca
            rrca
            rrca
            ld l, a
            ld a, e
            rrca
            rrca
            rrca
            and #1F
            add a, iv_blk / 256
            ld h, a
            ret

; ---- an edge D = xa, E = ya to B = xb, C = yb: x' for each of its rows on the screen, into
; ed_d (going down: the right side) or ed_u (going up: the left). Keeps IX
edge:
            ld a, e
            cp c
            ret z
            ld h, ed_d / 256
            jr c, eg_1
            ld a, d                 ; going up: the ends swapped
            ld d, b
            ld b, a
            ld a, e
            ld e, c
            ld c, a
            ld h, ed_u / 256
eg_1:
            ; rows y0 = max(ya, 88) .. y1 = min(yb, 168)
            ld a, e
            cp 88
            jr nc, eg_2
            ld a, 88
eg_2:
            ld l, a
            ld a, c
            cp 168
            jr c, eg_3
            ld a, 168
eg_3:
            ld (eg_end + 1), a
            cp l
            ret c
            ret z
            ld (eg_ptr), hl
            ld a, l
            sub e
            ld (eg_k), a            ; rows skipped
            ld a, d
            ld (eg_xa), a
            ld a, c
            sub e
            ld l, a                 ; dy
            ld a, b
            sub d                   ; dx
            ld c, 0
            jr nc, eg_4
            neg
            dec c
eg_4:
            ; step (8.8) = |dx| * RY(dy) >> 8, RY = 65536 / dy
            ld (eg_adx), a
            ld h, ry_l / 256
            ld e, (hl)
            inc h
            ld b, (hl)
            ld d, a
eg_zm1:
            db #ED, #30             ; mul d, e: |dx| * RY low
            ld l, d
            ld a, (eg_adx)
            ld d, a
            ld e, b
eg_zm2:
            db #ED, #30             ; |dx| * RY high
            ld h, 0
            add hl, de
            ld a, c
            or a
            jr z, eg_5
            xor a
            sub l
            ld l, a
            sbc a, a
            sub h
            ld h, a
eg_5:
            ld (eg_st), hl
            ; x = xa * 256 + 128 + k * step (16 bits)
            ld a, (eg_xa)
            ld d, a
            ld e, 128
            ld a, (eg_k)
            or a
            jr z, eg_6
            push de
            ld b, a
            ld d, a
            ld e, l
eg_zm3:
            db #ED, #30             ; k * step low
            push de
            ld d, b
            ld e, h
eg_zm4:
            db #ED, #30             ; k * step high: its low byte goes in the high byte
            pop hl
            ld a, h
            add a, e
            ld h, a
            pop de
            add hl, de
            ex de, hl
eg_6:
            ex de, hl               ; HL = x (8.8)
            ld de, (eg_st)
            ld bc, (eg_ptr)
eg_lp:
            ld a, h
            ld (bc), a
            inc c
            add hl, de
            ld a, c
eg_end:
            cp 0                    ; (y1: written above)
            jr nz, eg_lp
            ret

; ================================================================ the coverage of a row
; cover: HL = the row's list (n, then n pairs start, end - in order, apart), B = a, C = b
; (a < b): fills the parts of a .. b not filled yet this frame, and puts a .. b in the list
cover:
            ld a, (hl)
            or a
            jr nz, cv_some
            ; an empty row
            inc (hl)
            inc hl
            ld (hl), b
            inc hl
            ld (hl), c
            ld a, b
            or a
            jp nz, fill
            ld a, c
            cp 96
            jp nz, fill
            ld hl, rd_full
            inc (hl)
            jp fill
cv_some:
            cp 1
            jr nz, cv_n1
            ; one pair: 0 .. 128 is a full row
            inc hl
            ld a, (hl)
            inc hl
            or a
            jr nz, cv_n0
            ld a, (hl)
            cp 96
            ret z
cv_n0:
            dec hl
            dec hl
            ld a, 1
cv_n1:
            ld (cv_blk), hl
            ld e, a                 ; pairs left
            inc hl
cv_s1:
            inc hl
            ld a, (hl)              ; end(i)
            cp b
            jr nc, cv_s2            ; end(i) >= a: from this one
            inc hl
            dec e
            jr nz, cv_s1
            ; every pair ends before a: a .. b goes on the end
            ld hl, (cv_blk)
            ld a, (hl)
            cp 15
            jp nc, fill
            inc (hl)
            add a, a
            inc a
            ld e, a
            ld d, 0
            add hl, de
            ld (hl), b
            inc hl
            ld (hl), c
            jp fill
cv_s2:
            dec hl                  ; HL = start(i), E = the pairs from i on
            ld a, (hl)
            cp c
            jr z, cv_ov
            jr c, cv_ov
            ; start(i) > b: a .. b goes in before it
            push hl
            ld hl, (cv_blk)
            ld a, (hl)
            cp 15
            jr nc, cv_i0
            inc (hl)
            pop hl
            push bc
            ld a, e
            add a, a
            ld c, a
            ld b, 0
            add hl, bc
            dec hl
            ld d, h
            ld e, l
            inc de
            inc de
            lddr
            inc hl
            pop bc
            ld (hl), b
            inc hl
            ld (hl), c
            jp fill
cv_i0:
            pop hl
            jp fill
; ---- fill: B .. C (B < C) of the row at fl_h, colour fl_col: two Layer 2 lines, by PUSH
fill:
            ld a, c
            sub b
            ld e, a
            ld d, 0
            ld hl, pf_end
            sbc hl, de
            ld (fl_j1 + 1), hl
            ld (fl_j2 + 1), hl
            ld a, (fl_h)
            ld h, a
            ld a, c
            add a, a
            ld l, a
            jr nc, fl_1
            inc h
fl_1:
            ld de, (fl_col)
            ld (fl_sp), sp
            ld ix, fl_r1
            db #F9                  ; ld sp, hl (as a byte: NTC takes a "ld sp, hl" for a branch)
fl_j1:
            jp 0
fl_r1:
            inc h
            db #F9                  ; ld sp, hl
            ld ix, fl_r2
fl_j2:
            jp 0
fl_r2:
            ld sp, (fl_sp)
            ret
cv_ov:
            ; it meets pair i: merge from there. ns = min(a, start(i)), D = filled up to
            ld (cv_ip), hl
            cp b
            jr c, cv_o1
            ld a, b
cv_o1:
            ld (cv_ns), a
            ld d, b
cv_m:
            ld a, (hl)              ; start(j)
            cp d
            jr z, cv_m1
            jr c, cv_m1
            push bc
            push de
            push hl
            ld c, a
            ld b, d
            call fill               ; the gap before it
            pop hl
            pop de
            pop bc
cv_m1:
            inc hl
            ld a, (hl)              ; end(j)
            cp d
            jr c, cv_m2
            ld d, a
cv_m2:
            inc hl
            dec e
            jr z, cv_m3
            ld a, (hl)
            cp c
            jr z, cv_m
            jr c, cv_m
cv_m3:
            ; the rest: D .. b
            ld a, d
            cp c
            jr nc, cv_m4
            push de
            push hl
            ld b, d
            call fill
            pop hl
            pop de
            ld d, c
cv_m4:
            ; the merged pairs become ns .. D; E pairs after them (from HL) move down
            push hl
            ld hl, (cv_ip)
            ld a, (cv_ns)
            ld (hl), a
            inc hl
            ld (hl), d
            inc hl
            pop bc
            ld a, c
            sub l
            jr z, cv_m6             ; one pair merged: nothing moves
            rrca
            ld d, a                 ; pairs gone
            ld a, e
            or a
            jr z, cv_m5
            push de
            ex de, hl
            ld h, b
            ld l, c
            add a, a
            ld c, a
            ld b, 0
            ldir
            pop de
cv_m5:
            ld hl, (cv_blk)
            ld a, (hl)
            sub d
            ld (hl), a
cv_m6:
            ; full now?
            ld hl, (cv_blk)
            ld a, (hl)
            dec a
            ret nz
            inc hl
            ld a, (hl)
            or a
            ret nz
            inc hl
            ld a, (hl)
            cp 96
            ret nz
            ld hl, rd_full
            inc (hl)
            ret

; ---- the sky in what's left, row by row (and the lists emptied for the next frame)
rd_sky:
            xor a
sk_lp:
            ld (sk_r), a
            ld e, a
            ld d, 0
            ld hl, rd_skyc
            add hl, de
            ld a, (hl)
            ld (fl_col), a
            ld (fl_col + 1), a
            ld a, e
            call rowsel
            push hl
            ld bc, 96
            call cover
            pop hl
            ld (hl), 0
            ld a, (sk_r)
            inc a
            cp 80
            jr nz, sk_lp
            ret

pf_blk:
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
pf_end:
            jp (ix)
; vx_math.asm - signed 16 x 16 multiply and 32 / 16 divide (the multiply on the Next's MUL D,E),
; 2.14 fixed point: from SOLAR / SOL UNICORN's View.cls, for gen_vox.py
; DEHL = DE * BC, signed
vx_muls:
            ld a, d
            xor b
            ld (vx_sg), a
            bit 7, d
            jr z, vx_m1
            xor a
            sub e
            ld e, a
            sbc a, a
            sub d
            ld d, a
vx_m1:
            bit 7, b
            jr z, vx_m2
            xor a
            sub c
            ld c, a
            sbc a, a
            sub b
            ld b, a
vx_m2:
            call vx_umul            ; DEHL = DE * BC, unsigned
            ld a, (vx_sg)
            bit 7, a
            ret z
            ; negate DEHL
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
; HL = DEHL / BC, signed (the quotient's low 16 bits; |divisor| > 0)
vx_divs:
            ld a, d
            xor b
            ld (vx_sg), a
            bit 7, d
            jr z, vx_d1
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
vx_d1:
            bit 7, b
            jr z, vx_d2
            xor a
            sub c
            ld c, a
            sbc a, a
            sub b
            ld b, a
vx_d2:
            ld a, b
            or c
            jr nz, vx_d3
            ld hl, 0
            ret
vx_d3:
            ; DEHL / BC: the remainder in DE as the dividend's bits come in from HL
            ; first make sure the high word is below the divisor (else the quotient is > 16 bits): clamp
            ex de, hl               ; HL = high, DE = low
            or a
            sbc hl, bc
            jr c, vx_d4
            ld hl, 32767
            jr vx_d7
vx_d4:
            add hl, bc
            ld a, 16
vx_d5:
            sla e
            rl d
            adc hl, hl
            jr c, vx_d5b
            or a
            sbc hl, bc
            jr nc, vx_d6
            add hl, bc
            jr vx_d6n
vx_d5b:
            or a
            sbc hl, bc
vx_d6:
            inc e
vx_d6n:
            dec a
            jr nz, vx_d5
            ex de, hl               ; HL = quotient
vx_d7:
            ld a, (vx_sg)
            bit 7, a
            ret z
            xor a
            sub l
            ld l, a
            sbc a, a
            sub h
            ld h, a
            ret

; DEHL = DE * BC, unsigned: four 8 x 8 products on the Next's multiplier
vx_umul:
            ld (vx_ua), de
            ld (vx_ub), bc
            ld d, e                 ; a low x b low
            ld e, c
vx_zm1:
            db #ED, #30             ; mul d, e
            ld (vx_lo), de
            ld a, (vx_ua + 1)       ; a high x b high
            ld d, a
            ld a, (vx_ub + 1)
            ld e, a
vx_zm2:
            db #ED, #30
            ld (vx_hi), de
            ld a, (vx_ua)           ; a low x b high
            ld d, a
            ld e, b
vx_zm3:
            db #ED, #30
            ex de, hl
            ld a, (vx_ua + 1)       ; a high x b low
            ld d, a
            ld e, c
vx_zm4:
            db #ED, #30
            add hl, de              ; the middle: 17 bits (A = its top bit)
            ld a, 0
            adc a, a
            ld b, a
            ld de, (vx_lo)
            ld a, d
            add a, l
            ld d, a
            ld a, h
            ld hl, (vx_hi)
            adc a, l
            ld l, a
            ld a, b
            adc a, h
            ld h, a
            ex de, hl               ; DE = the high word, HL = the low
            ret
vx_ua:      dw 0
vx_ub:      dw 0
vx_lo:      dw 0
vx_hi:      dw 0

; HL = DE * BC >> 14 (2.14 fixed point, signed)
vx_fix:
            call vx_muls
            add hl, hl
            rl e
            rl d
            add hl, hl
            rl e
            rl d
            ex de, hl
            ret
; HL = DE * BC >> 12 (a model's byte coordinates are 4 world units)
vx_f12:
            call vx_muls
            ld a, 4
vx_f12a:
            add hl, hl
            rl e
            rl d
            dec a
            jr nz, vx_f12a
            ex de, hl
            ret
; HL = vx_v . (IY), 3 words each, >> 14
vx_dot:
            ld e, (iy + 0)
            ld d, (iy + 1)
            ld bc, (vx_v)
            call vx_fix
            ld (vx_acc), hl
            ld e, (iy + 2)
            ld d, (iy + 3)
            ld bc, (vx_v + 2)
            call vx_fix
            ld de, (vx_acc)
            add hl, de
            ld (vx_acc), hl
            ld e, (iy + 4)
            ld d, (iy + 5)
            ld bc, (vx_v + 4)
            call vx_fix
            ld de, (vx_acc)
            add hl, de
            ret
; HL = HL * 128 / BC (BC > 0), kept within +-12000
vx_proj:
            ld a, h                 ; DEHL = HL sign extended, times 128
            rla
            sbc a, a
            ld e, a
            ld d, a
            ld a, 7
vx_pr1:
            add hl, hl
            rl e
            rl d
            dec a
            jr nz, vx_pr1
            call vx_divs
vx_clamp:
            ld de, 12000
            bit 7, h
            jr nz, vx_cneg
            push hl
            or a
            sbc hl, de
            pop hl
            ret c
            ex de, hl
            ret
vx_cneg:
            push hl
            add hl, de
            pop hl
            ret c
            ld hl, -12000
            ret
vx_v:       dw 0, 0, 0
vx_acc:     dw 0
vx_sg:      db 0
vx_n:       db 0
rd_sint:
            dw 0, 402, 804, 1205, 1606, 2006, 2404, 2801
            dw 3196, 3590, 3981, 4370, 4756, 5139, 5520, 5897
            dw 6270, 6639, 7005, 7366, 7723, 8076, 8423, 8765
            dw 9102, 9434, 9760, 10080, 10394, 10702, 11003, 11297
            dw 11585, 11866, 12140, 12406, 12665, 12916, 13160, 13395
            dw 13623, 13842, 14053, 14256, 14449, 14635, 14811, 14978
            dw 15137, 15286, 15426, 15557, 15679, 15791, 15893, 15986
            dw 16069, 16143, 16207, 16261, 16305, 16340, 16364, 16379
            dw 16384, 16379, 16364, 16340, 16305, 16261, 16207, 16143
            dw 16069, 15986, 15893, 15791, 15679, 15557, 15426, 15286
            dw 15137, 14978, 14811, 14635, 14449, 14256, 14053, 13842
            dw 13623, 13395, 13160, 12916, 12665, 12406, 12140, 11866
            dw 11585, 11297, 11003, 10702, 10394, 10080, 9760, 9434
            dw 9102, 8765, 8423, 8076, 7723, 7366, 7005, 6639
            dw 6270, 5897, 5520, 5139, 4756, 4370, 3981, 3590
            dw 3196, 2801, 2404, 2006, 1606, 1205, 804, 402
            dw 0, 65134, 64732, 64331, 63930, 63530, 63132, 62735
            dw 62340, 61946, 61555, 61166, 60780, 60397, 60016, 59639
            dw 59266, 58897, 58531, 58170, 57813, 57460, 57113, 56771
            dw 56434, 56102, 55776, 55456, 55142, 54834, 54533, 54239
            dw 53951, 53670, 53396, 53130, 52871, 52620, 52376, 52141
            dw 51913, 51694, 51483, 51280, 51087, 50901, 50725, 50558
            dw 50399, 50250, 50110, 49979, 49857, 49745, 49643, 49550
            dw 49467, 49393, 49329, 49275, 49231, 49196, 49172, 49157
            dw 49152, 49157, 49172, 49196, 49231, 49275, 49329, 49393
            dw 49467, 49550, 49643, 49745, 49857, 49979, 50110, 50250
            dw 50399, 50558, 50725, 50901, 51087, 51280, 51483, 51694
            dw 51913, 52141, 52376, 52620, 52871, 53130, 53396, 53670
            dw 53951, 54239, 54533, 54834, 55142, 55456, 55776, 56102
            dw 56434, 56771, 57113, 57460, 57813, 58170, 58531, 58897
            dw 59266, 59639, 60016, 60397, 60780, 61166, 61555, 61946
            dw 62340, 62735, 63132, 63530, 63930, 64331, 64732, 65134
rd_ra:
            dw 0, 65535, 65535, 65535, 65535, 65535, 65535, 65535
            dw 65535, 65535, 65535, 65535, 65535, 65535, 65535, 65535
            dw 65535, 65535, 65535, 65535, 65535, 65535, 65535, 65535
            dw 65535, 65535, 65535, 65535, 65535, 65535, 65535, 65535
            dw 65535, 63550, 61681, 59919, 58254, 56680, 55188, 53773
            dw 52429, 51150, 49932, 48771, 47663, 46603, 45590, 44620
            dw 43691, 42799, 41943, 41121, 40330, 39569, 38836, 38130
            dw 37449, 36792, 36158, 35545, 34953, 34380, 33825, 33288
            dw 32768, 32264, 31775, 31301, 30840, 30394, 29959, 29537
            dw 29127, 28728, 28340, 27962, 27594, 27236, 26887, 26546
            dw 26214, 25891, 25575, 25267, 24966, 24672, 24385, 24105
            dw 23831, 23564, 23302, 23046, 22795, 22550, 22310, 22075
            dw 21845, 21620, 21400, 21183, 20972, 20764, 20560, 20361
            dw 20165, 19973, 19784, 19600, 19418, 19240, 19065, 18893
            dw 18725, 18559, 18396, 18236, 18079, 17924, 17772, 17623
            dw 17476, 17332, 17190, 17050, 16913, 16777, 16644, 16513
            dw 16384, 16257, 16132, 16009, 15888, 15768, 15650, 15534
            dw 15420, 15308, 15197, 15087, 14980, 14873, 14769, 14665
            dw 14564, 14463, 14364, 14266, 14170, 14075, 13981, 13888
            dw 13797, 13707, 13618, 13530, 13443, 13358, 13273, 13190
            dw 13107, 13026, 12945, 12866, 12788, 12710, 12633, 12558
            dw 12483, 12409, 12336, 12264, 12193, 12122, 12053, 11984
            dw 11916, 11848, 11782, 11716, 11651, 11586, 11523, 11460
            dw 11398, 11336, 11275, 11215, 11155, 11096, 11038, 10980
            dw 10923, 10866, 10810, 10755, 10700, 10645, 10592, 10538
            dw 10486, 10434, 10382, 10331, 10280, 10230, 10180, 10131
            dw 10082, 10034, 9986, 9939, 9892, 9846, 9800, 9754
            dw 9709, 9664, 9620, 9576, 9533, 9489, 9447, 9404
            dw 9362, 9321, 9279, 9239, 9198, 9158, 9118, 9079
            dw 9039, 9001, 8962, 8924, 8886, 8849, 8812, 8775
            dw 8738, 8702, 8666, 8630, 8595, 8560, 8525, 8490
            dw 8456, 8422, 8389, 8355, 8322, 8289, 8257, 8224
            dw 8192, 8160, 8128, 8097, 8066, 8035, 8004, 7974
            dw 7944, 7914, 7884, 7855, 7825, 7796, 7767, 7739
            dw 7710, 7682, 7654, 7626, 7598, 7571, 7544, 7517
            dw 7490, 7463, 7437, 7410, 7384, 7358, 7333, 7307
            dw 7282, 7257, 7232, 7207, 7182, 7158, 7133, 7109
            dw 7085, 7061, 7037, 7014, 6991, 6967, 6944, 6921
            dw 6899, 6876, 6853, 6831, 6809, 6787, 6765, 6743
            dw 6722, 6700, 6679, 6658, 6637, 6616, 6595, 6574
            dw 6554, 6533, 6513, 6493, 6473, 6453, 6433, 6413
            dw 6394, 6374, 6355, 6336, 6317, 6298, 6279, 6260
            dw 6242, 6223, 6205, 6186, 6168, 6150, 6132, 6114
            dw 6096, 6079, 6061, 6044, 6026, 6009, 5992, 5975
            dw 5958, 5941, 5924, 5907, 5891, 5874, 5858, 5842
            dw 5825, 5809, 5793, 5777, 5761, 5746, 5730, 5714
            dw 5699, 5683, 5668, 5653, 5638, 5622, 5607, 5592
            dw 5578, 5563, 5548, 5533, 5519, 5504, 5490, 5476
            dw 5461, 5447, 5433, 5419, 5405, 5391, 5377, 5364
            dw 5350, 5336, 5323, 5309, 5296, 5282, 5269, 5256
            dw 5243, 5230, 5217, 5204, 5191, 5178, 5165, 5153
            dw 5140, 5128, 5115, 5103, 5090, 5078, 5066, 5053
            dw 5041, 5029, 5017, 5005, 4993, 4981, 4970, 4958
            dw 4946, 4934, 4923, 4911, 4900, 4888, 4877, 4866
            dw 4855, 4843, 4832, 4821, 4810, 4799, 4788, 4777
            dw 4766, 4755, 4745, 4734, 4723, 4713, 4702, 4692
            dw 4681, 4671, 4660, 4650, 4640, 4629, 4619, 4609
            dw 4599, 4589, 4579, 4569, 4559, 4549, 4539, 4529
            dw 4520, 4510, 4500, 4491, 4481, 4472, 4462, 4453
            dw 4443, 4434, 4424, 4415, 4406, 4397, 4387, 4378
            dw 4369, 4360, 4351, 4342, 4333, 4324, 4315, 4306
            dw 4297, 4289, 4280, 4271, 4263, 4254, 4245, 4237
            dw 4228, 4220, 4211, 4203, 4194, 4186, 4178, 4169
            dw 4161, 4153, 4145, 4136, 4128, 4120, 4112, 4104
            dw 4096, 4088, 4080, 4072, 4064, 4056, 4049, 4041
            dw 4033, 4025, 4018, 4010, 4002, 3995, 3987, 3979
            dw 3972, 3964, 3957, 3949, 3942, 3935, 3927, 3920
            dw 3913, 3905, 3898, 3891, 3884, 3876, 3869, 3862
            dw 3855, 3848, 3841, 3834, 3827, 3820, 3813, 3806
            dw 3799, 3792, 3785, 3779, 3772, 3765, 3758, 3752
            dw 3745, 3738, 3732, 3725, 3718, 3712, 3705, 3699
            dw 3692, 3686, 3679, 3673, 3666, 3660, 3654, 3647
            dw 3641, 3635, 3628, 3622, 3616, 3610, 3603, 3597
            dw 3591, 3585, 3579, 3573, 3567, 3561, 3554, 3548
            dw 3542, 3537, 3531, 3525, 3519, 3513, 3507, 3501
            dw 3495, 3489, 3484, 3478, 3472, 3466, 3461, 3455
            dw 3449, 3444, 3438, 3432, 3427, 3421, 3416, 3410
            dw 3404, 3399, 3393, 3388, 3383, 3377, 3372, 3366
            dw 3361, 3355, 3350, 3345, 3339, 3334, 3329, 3324
            dw 3318, 3313, 3308, 3303, 3297, 3292, 3287, 3282
            dw 3277, 3272, 3267, 3262, 3256, 3251, 3246, 3241
            dw 3236, 3231, 3226, 3221, 3216, 3212, 3207, 3202
            dw 3197, 3192, 3187, 3182, 3178, 3173, 3168, 3163
            dw 3158, 3154, 3149, 3144, 3139, 3135, 3130, 3125
            dw 3121, 3116, 3112, 3107, 3102, 3098, 3093, 3089
            dw 3084, 3080, 3075, 3071, 3066, 3062, 3057, 3053
            dw 3048, 3044, 3039, 3035, 3031, 3026, 3022, 3017
            dw 3013, 3009, 3005, 3000, 2996, 2992, 2987, 2983
            dw 2979, 2975, 2970, 2966, 2962, 2958, 2954, 2950
            dw 2945, 2941, 2937, 2933, 2929, 2925, 2921, 2917
            dw 2913, 2909, 2905, 2901, 2897, 2893, 2889, 2885
            dw 2881, 2877, 2873, 2869, 2865, 2861, 2857, 2853
            dw 2849, 2846, 2842, 2838, 2834, 2830, 2826, 2823
            dw 2819, 2815, 2811, 2807, 2804, 2800, 2796, 2792
            dw 2789, 2785, 2781, 2778, 2774, 2770, 2767, 2763
            dw 2759, 2756, 2752, 2749, 2745, 2741, 2738, 2734
            dw 2731, 2727, 2724, 2720, 2717, 2713, 2709, 2706
            dw 2703, 2699, 2696, 2692, 2689, 2685, 2682, 2678
            dw 2675, 2672, 2668, 2665, 2661, 2658, 2655, 2651
            dw 2648, 2645, 2641, 2638, 2635, 2631, 2628, 2625
            dw 2621, 2618, 2615, 2612, 2608, 2605, 2602, 2599
            dw 2595, 2592, 2589, 2586, 2583, 2580, 2576, 2573
            dw 2570, 2567, 2564, 2561, 2558, 2554, 2551, 2548
            dw 2545, 2542, 2539, 2536, 2533, 2530, 2527, 2524
            dw 2521, 2518, 2515, 2512, 2509, 2506, 2503, 2500
            dw 2497, 2494, 2491, 2488, 2485, 2482, 2479, 2476
            dw 2473, 2470, 2467, 2464, 2461, 2459, 2456, 2453
            dw 2450, 2447, 2444, 2441, 2439, 2436, 2433, 2430
            dw 2427, 2424, 2422, 2419, 2416, 2413, 2411, 2408
            dw 2405, 2402, 2399, 2397, 2394, 2391, 2389, 2386
            dw 2383, 2380, 2378, 2375, 2372, 2370, 2367, 2364
            dw 2362, 2359, 2356, 2354, 2351, 2348, 2346, 2343
            dw 2341, 2338, 2335, 2333, 2330, 2328, 2325, 2322
            dw 2320, 2317, 2315, 2312, 2310, 2307, 2305, 2302
            dw 2300, 2297, 2294, 2292, 2289, 2287, 2284, 2282
            dw 2280, 2277, 2275, 2272, 2270, 2267, 2265, 2262
            dw 2260, 2257, 2255, 2253, 2250, 2248, 2245, 2243
            dw 2241, 2238, 2236, 2233, 2231, 2229, 2226, 2224
            dw 2222, 2219, 2217, 2215, 2212, 2210, 2208, 2205
            dw 2203, 2201, 2198, 2196, 2194, 2191, 2189, 2187
            dw 2185, 2182, 2180, 2178, 2175, 2173, 2171, 2169
            dw 2166, 2164, 2162, 2160, 2158, 2155, 2153, 2151
            dw 2149, 2147, 2144, 2142, 2140, 2138, 2136, 2133
            dw 2131, 2129, 2127, 2125, 2123, 2120, 2118, 2116
            dw 2114, 2112, 2110, 2108, 2106, 2103, 2101, 2099
            dw 2097, 2095, 2093, 2091, 2089, 2087, 2085, 2083
            dw 2081, 2078, 2076, 2074, 2072, 2070, 2068, 2066
            dw 2064, 2062, 2060, 2058, 2056, 2054, 2052, 2050
rd_rb:
            dw 65408, 65154, 64902, 64652, 64404, 64158, 63913, 63671
            dw 63430, 63191, 62954, 62719, 62485, 62253, 62023, 61795
            dw 61568, 61343, 61119, 60897, 60677, 60458, 60241, 60026
            dw 59812, 59599, 59388, 59179, 58971, 58764, 58559, 58356
            dw 58153, 57952, 57753, 57555, 57358, 57163, 56968, 56776
            dw 56584, 56394, 56205, 56017, 55831, 55646, 55462, 55279
            dw 55098, 54917, 54738, 54560, 54383, 54207, 54033, 53859
            dw 53687, 53516, 53346, 53177, 53009, 52842, 52676, 52511
            dw 52347, 52184, 52022, 51862, 51702, 51543, 51385, 51228
            dw 51072, 50917, 50763, 50610, 50458, 50306, 50156, 50007
            dw 49858, 49710, 49563, 49417, 49272, 49128, 48985, 48842
            dw 48700, 48559, 48419, 48280, 48141, 48003, 47867, 47730
            dw 47595, 47460, 47326, 47193, 47061, 46929, 46798, 46668
            dw 46539, 46410, 46282, 46155, 46028, 45902, 45777, 45652
            dw 45528, 45405, 45283, 45161, 45040, 44919, 44799, 44680
            dw 44561, 44443, 44326, 44209, 44093, 43977, 43862, 43748
            dw 43634, 43521, 43408, 43296, 43185, 43074, 42963, 42854
            dw 42744, 42636, 42528, 42420, 42313, 42207, 42101, 41996
            dw 41891, 41786, 41683, 41579, 41476, 41374, 41272, 41171
            dw 41070, 40970, 40870, 40771, 40672, 40574, 40476, 40378
            dw 40281, 40185, 40089, 39993, 39898, 39804, 39709, 39616
            dw 39522, 39429, 39337, 39245, 39153, 39062, 38971, 38881
            dw 38791, 38702, 38613, 38524, 38436, 38348, 38260, 38173
            dw 38087, 38000, 37915, 37829, 37744, 37659, 37575, 37491
            dw 37407, 37324, 37241, 37159, 37077, 36995, 36914, 36833
            dw 36752, 36672, 36592, 36512, 36433, 36354, 36275, 36197
            dw 36119, 36041, 35964, 35887, 35810, 35734, 35658, 35583
            dw 35507, 35432, 35358, 35283, 35209, 35136, 35062, 34989
            dw 34916, 34844, 34771, 34700, 34628, 34557, 34486, 34415
            dw 34344, 34274, 34204, 34135, 34065, 33996, 33928, 33859
            dw 33791, 33723, 33655, 33588, 33521, 33454, 33387, 33321
            dw 33255, 33189, 33124, 33059, 32994, 32929, 32864, 32800
            dw 32736, 32672, 32609, 32546, 32483, 32420, 32357, 32295
            dw 32233, 32171, 32110, 32048, 31987, 31926, 31866, 31805
            dw 31745, 31685, 31625, 31566, 31507, 31447, 31389, 31330
            dw 31272, 31213, 31155, 31098, 31040, 30983, 30926, 30869
            dw 30812, 30756, 30699, 30643, 30587, 30532, 30476, 30421
            dw 30366, 30311, 30256, 30202, 30148, 30094, 30040, 29986
            dw 29933, 29879, 29826, 29773, 29720, 29668, 29616, 29563
            dw 29511, 29460, 29408, 29356, 29305, 29254, 29203, 29152
            dw 29102, 29051, 29001, 28951, 28901, 28852, 28802, 28753
            dw 28704, 28655, 28606, 28557, 28508, 28460, 28412, 28364
            dw 28316, 28268, 28221, 28173, 28126, 28079, 28032, 27985
            dw 27939, 27892, 27846, 27800, 27754, 27708, 27662, 27617
            dw 27571, 27526, 27481, 27436, 27391, 27347, 27302, 27258
            dw 27214, 27170, 27126, 27082, 27038, 26995, 26951, 26908
            dw 26865, 26822, 26779, 26737, 26694, 26652, 26609, 26567
            dw 26525, 26483, 26442, 26400, 26359, 26317, 26276, 26235
            dw 26194, 26153, 26112, 26072, 26031, 25991, 25951, 25911
            dw 25871, 25831, 25791, 25752, 25712, 25673, 25634, 25595
            dw 25556, 25517, 25478, 25439, 25401, 25362, 25324, 25286
            dw 25248, 25210, 25172, 25134, 25097, 25059, 25022, 24985
            dw 24948, 24910, 24874, 24837, 24800, 24763, 24727, 24691
            dw 24654, 24618, 24582, 24546, 24510, 24474, 24439, 24403
            dw 24368, 24332, 24297, 24262, 24227, 24192, 24157, 24123
            dw 24088, 24053, 24019, 23985, 23950, 23916, 23882, 23848
            dw 23814, 23781, 23747, 23713, 23680, 23647, 23613, 23580
            dw 23547, 23514, 23481, 23448, 23416, 23383, 23350, 23318
            dw 23286, 23253, 23221, 23189, 23157, 23125, 23093, 23061
            dw 23030, 22998, 22967, 22935, 22904, 22873, 22842, 22811
            dw 22780, 22749, 22718, 22687, 22657, 22626, 22596, 22565
            dw 22535, 22505, 22475, 22444, 22414, 22385, 22355, 22325
            dw 22295, 22266, 22236, 22207, 22177, 22148, 22119, 22090
            dw 22061, 22032, 22003, 21974, 21945, 21917, 21888, 21860
            dw 21831, 21803, 21774, 21746, 21718, 21690, 21662, 21634
            dw 21606, 21578, 21551, 21523, 21495, 21468, 21441, 21413
            dw 21386, 21359, 21331, 21304, 21277, 21250, 21224, 21197
            dw 21170, 21143, 21117, 21090, 21064, 21037, 21011, 20985
            dw 20958, 20932, 20906, 20880, 20854, 20828, 20802, 20777
            dw 20751, 20725, 20700, 20674, 20649, 20623, 20598, 20573
            dw 20548, 20523, 20498, 20473, 20448, 20423, 20398, 20373
            dw 20348, 20324, 20299, 20275, 20250, 20226, 20201, 20177
            dw 20153, 20129, 20105, 20080, 20056, 20032, 20009, 19985
            dw 19961, 19937, 19914, 19890, 19866, 19843, 19820, 19796
            dw 19773, 19750, 19726, 19703, 19680, 19657, 19634, 19611
            dw 19588, 19565, 19542, 19520, 19497, 19474, 19452, 19429
            dw 19407, 19384, 19362, 19340, 19317, 19295, 19273, 19251
            dw 19229, 19207, 19185, 19163, 19141, 19119, 19098, 19076
            dw 19054, 19033, 19011, 18989, 18968, 18947, 18925, 18904
            dw 18883, 18861, 18840, 18819, 18798, 18777, 18756, 18735
            dw 18714, 18693, 18672, 18652, 18631, 18610, 18590, 18569
            dw 18549, 18528, 18508, 18487, 18467, 18447, 18426, 18406
            dw 18386, 18366, 18346, 18326, 18306, 18286, 18266, 18246
            dw 18226, 18206, 18187, 18167, 18147, 18128, 18108, 18089
            dw 18069, 18050, 18030, 18011, 17992, 17972, 17953, 17934
            dw 17915, 17896, 17877, 17858, 17839, 17820, 17801, 17782
            dw 17763, 17744, 17726, 17707, 17688, 17670, 17651, 17632
            dw 17614, 17595, 17577, 17559, 17540, 17522, 17504, 17485
            dw 17467, 17449, 17431, 17413, 17395, 17377, 17359, 17341
            dw 17323, 17305, 17287, 17269, 17252, 17234, 17216, 17199
            dw 17181, 17163, 17146, 17128, 17111, 17093, 17076, 17059
            dw 17041, 17024, 17007, 16990, 16972, 16955, 16938, 16921
            dw 16904, 16887, 16870, 16853, 16836, 16819, 16802, 16786
            dw 16769, 16752, 16735, 16719, 16702, 16685, 16669, 16652
            dw 16636, 16619, 16603, 16586, 16570, 16554, 16537, 16521
            dw 16505, 16489, 16472, 16456, 16440, 16424, 16408, 16392
rd_ft:
            db 0, 0, 0, 0, 0, 0, 0, 1, 17, 0, 0, 1, 1, 50, 1, 0
            db 1, 0, 33, 1, 1, 0, 0, 1, 0, 1, 1, 0, 34, 1, 1, 1
            db 1, 51, 1, 1, 0, 1, 18, 0, 0, 0, 0, 0, 0, 1, 0, 0
            db 1, 0, 1, 0, 1, 18, 0, 0, 0, 1, 17, 0, 0, 1, 0, 33
            db 1, 0, 1, 1, 50, 1, 1, 1, 1, 51, 1, 1, 1, 0, 34, 1
            db 0, 0, 0, 0, 0, 0, 1, 0, 33, 1, 1, 1, 0, 34, 1, 1
            db 0, 0, 1, 0, 0, 0, 1, 17, 0, 1, 0, 1, 18, 0, 1, 1
            db 1, 51, 1, 0, 1, 1, 50, 1
rd_col:
            db 0, 0, 0, 0, 0, 0, 0, 0, 109, 145, 72, 213, 141, 177, 181, 0
            db 73, 73, 36, 109, 73, 73, 109, 0, 36, 37, 0, 73, 36, 37, 37, 0
            db 8, 12, 4, 48, 12, 48, 48, 0, 133, 169, 68, 233, 165, 201, 201, 0
            db 100, 100, 64, 168, 100, 132, 132, 0, 68, 68, 36, 104, 68, 72, 104, 0
            db 77, 110, 41, 150, 109, 146, 146, 0, 0, 0, 0, 0, 0, 0, 0, 0
            db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
            db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
            db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
            db 0, 0, 0, 0, 0, 0, 0, 0, 73, 109, 41, 145, 77, 109, 109, 0
            db 41, 41, 37, 73, 41, 73, 73, 0, 5, 37, 4, 41, 37, 37, 37, 0
            db 8, 13, 4, 13, 9, 13, 13, 0, 101, 105, 37, 137, 101, 137, 137, 0
            db 68, 68, 36, 105, 68, 68, 100, 0, 36, 36, 36, 73, 36, 73, 73, 0
            db 41, 77, 37, 110, 73, 78, 78, 0, 4, 4, 0, 4, 4, 4, 4, 0
            db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
            db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
            db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
            db 0, 0, 0, 0, 0, 0, 0, 0, 41, 73, 41, 77, 41, 77, 77, 0
            db 37, 41, 5, 41, 41, 41, 41, 0, 5, 5, 5, 41, 5, 5, 5, 0
            db 9, 9, 5, 13, 9, 9, 9, 0, 37, 73, 37, 105, 69, 73, 73, 0
            db 37, 37, 5, 73, 37, 37, 37, 0, 37, 37, 5, 41, 37, 37, 41, 0
            db 41, 41, 5, 78, 41, 41, 41, 0, 5, 5, 5, 5, 5, 5, 5, 0
            db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
            db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
            db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
            db 0, 0, 0, 0, 0, 0, 0, 0, 41, 41, 5, 41, 41, 41, 41, 0
            db 5, 9, 5, 9, 5, 9, 9, 0, 5, 5, 5, 5, 5, 5, 5, 0
            db 9, 9, 5, 9, 9, 9, 9, 0, 37, 37, 5, 41, 37, 37, 41, 0
            db 5, 37, 5, 37, 5, 37, 37, 0, 5, 5, 5, 9, 5, 5, 5, 0
            db 9, 9, 5, 41, 9, 41, 41, 0, 5, 5, 5, 5, 5, 5, 5, 0
            db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
            db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
            db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
rd_skyc:
            db 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14
            db 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10
            db 10, 10, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9
            db 9, 9, 9, 9, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5
            db 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5
fogt:
            db 0, 0, 0, 0, 0, 0, 1, 1, 1, 2, 2, 3, 3, 3, 3, 3
            db 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3
            db 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3
            db 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3

rd_cx:      dw 0
rd_cy:      dw 0
rd_cz:      dw 0
rd_yaw:     dw 0
rd_pit:     dw 0
rd_page:    dw 0
rd_fr:      db 7
rd_fr5:     db 0
rd_cpage:   db 0
rd_full:    db 0
rd_ccx:     db 0
rd_ccy:     db 0
rd_ccz:     db 0
rd_cgx:     db 0
rd_cgy:     db 0
rd_cgz:     db 0
b_sy:       dw 0
b_cy:       dw 0
b_sp:       dw 0
b_cp:       dw 0
b_rx:       dw 0
b_rz:       dw 0
b_ux:       dw 0
b_uy:       dw 0
b_uz:       dw 0
b_fx:       dw 0
b_fy:       dw 0
b_fz:       dw 0
mk_b1:      dw 0
mk_b2:      dw 0
mk_b3:      dw 0
mk_p:       dw 0
mk_d:       dw 0
cn_i:       db 0
cn_j:       db 0
cn_k:       db 0
cn_gid:     dw 0
cc_x:       dw 0
cc_y:       dw 0
cc_z:       dw 0
cp_sx:      db 0
cp_sy:      db 0
cp_ax:      dw 0
cp_ay:      dw 0
cp_r:       dw 0
cp_mode:    db 0
cp_X:       db 0
gh:         ds 16
gnext:      ds 64
hb:         ds 10
cnext:      ds 64
gr_g:       db 0
gr_dd:      db 0
gr_t:       dw 0
dg_min:     db 0
dg_p:       dw 0
dg_n:       db 0
dg_bk:      db 0
dg_c:       db 0
dc_m:       db 0
fc_x:       db 0
fc_y:       db 0
fc_z:       db 0
fc_t:       db 0
fc_f:       db 0
fc_k:       db 0
fc_gid:     dw 0
fc_tp:      dw 0
px:         ds 16
py:         ds 16
rs_n:       db 0
rs_i:       db 0
rs_y:       db 0
rs_top:     db 0
rs_bot:     db 0
ed_xa:      db 0
ed_ya:      db 0
ed_xb:      db 0
ed_yb:      db 0
eg_dst:     db 0
eg_dy:      db 0
eg_adx:     db 0
eg_sg:      db 0
eg_st:      dw 0
eg_y0:      db 0
eg_n:       db 0
eg_cnt:     db 0
cv_row:     db 0
cv_a:       db 0
cv_b:       db 0
cv_col:     db 0
cv_p:       dw 0
cv_np:      dw 0
cv_n:       db 0
cv_i:       db 0
cv_j:       db 0
cv_k:       db 0
cv_ip:      dw 0
cv_cur:     db 0
cv_ns:      db 0
cv_ne:      db 0
fl_a:       db 0
fl_b:       db 0
fl_sp:      dw 0
sl_q:       dw 0
sl_n:       db 0
sl_m:       db 0
sl_i:       db 0
sl_ain:     db 0
sl_bin:     db 0
sl_t0:      dw 0
sl_dz:      dw 0
sl_v:       dw 0, 0, 0
sl_nr:      db 0
sl_src:     dw 0
sl_cur:     dw 0
bx_x0:      dw 0
bx_y0:      dw 0
bx_x1:      dw 0
bx_y1:      dw 0
cp_wx:      dw 0
dc_d:       db 0
gst:        ds 64
dg_st:      db 0
dc_t:       dw 0
hd_x:       dw 0
hd_y:       dw 0
hd_z:       dw 0
c2_src:     dw 0
c2_lim:     dw 0
c2_ax:      db 0
c2_ge:      db 0
s1:         ds 72
s2:         ds 72
s3:         ds 48
s4:         ds 48
            align 256
ed_u:       ds 256
ed_d:       ds 256
iv_blk:     ds 2560                 ; each row's list: how many, then up to 31 pairs (start, end)
ry_l:
            db 0, 0, 0, 85, 0, 51, 170, 146, 0, 113, 153, 69, 85, 177, 73, 17
            db 0, 15, 56, 121, 204, 48, 162, 33, 170, 61, 216, 123, 36, 211, 136, 66
            db 0, 193, 135, 80, 28, 235, 188, 144, 102, 62, 24, 244, 209, 176, 144, 114
            db 85, 57, 30, 5, 236, 212, 189, 167, 146, 125, 105, 86, 68, 50, 33, 16
            db 0, 240, 224, 210, 195, 181, 168, 155, 142, 129, 117, 105, 94, 83, 72, 61
            db 51, 41, 31, 21, 12, 3, 250, 241, 232, 224, 216, 208, 200, 192, 185, 177
            db 170, 163, 156, 149, 143, 136, 130, 124, 118, 112, 106, 100, 94, 89, 83, 78
            db 73, 67, 62, 57, 52, 48, 43, 38, 34, 29, 25, 20, 16, 12, 8, 4
            db 0, 252, 248, 244, 240, 236, 233, 229, 225, 222, 218, 215, 212, 208, 205, 202
            db 199, 195, 192, 189, 186, 183, 180, 178, 175, 172, 169, 166, 164, 161, 158, 156
            db 153, 151, 148, 146, 143, 141, 138, 136, 134, 131, 129, 127, 125, 122, 120, 118
            db 116, 114, 112, 110, 108, 106, 104, 102, 100, 98, 96, 94, 92, 90, 88, 87
            db 85, 83, 81, 80, 78, 76, 74, 73, 71, 70, 68, 66, 65, 63, 62, 60
            db 59, 57, 56, 54, 53, 51, 50, 48, 47, 46, 44, 43, 41, 40, 39, 37
            db 36, 35, 33, 32, 31, 30, 28, 27, 26, 25, 24, 22, 21, 20, 19, 18
            db 17, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1
ry_h:
            db 0, 0, 128, 85, 64, 51, 42, 36, 32, 28, 25, 23, 21, 19, 18, 17
            db 16, 15, 14, 13, 12, 12, 11, 11, 10, 10, 9, 9, 9, 8, 8, 8
            db 8, 7, 7, 7, 7, 6, 6, 6, 6, 6, 6, 5, 5, 5, 5, 5
            db 5, 5, 5, 5, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4
            db 4, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3
            db 3, 3, 3, 3, 3, 3, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2
            db 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2
            db 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2
            db 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
            db 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
            db 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
            db 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
            db 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
            db 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
            db 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
            db 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1

cp_2z:      dw 0
cp_ah:      db 0
cp_al:      db 0
dc_cb:      db 0
fl_col:     dw 0
fl_h:       db 0
cv_blk:     dw 0
eg_ptr:     dw 0
eg_k:       db 0
eg_xa:      db 0
sk_r:       db 0
rs_lp:      dw 0
rs_pg:      db 0
#endasm
End Sub
