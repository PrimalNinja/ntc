' Swarm - CYBORG SWARM's enemies: where each is, where it is going, and its sprite.
' (c) 2026 Cyborg Unicorn Pty Ltd
'
' 44 enemies: 0-3 the Queens, 4-19 the Hornets, 20-39 the Drones (each has its slot in the
' formation), 40-43 a fighter a Queen has captured (40 + the Queen's number).
' Positions are in 1/16 pixels on the playfield (256 x 224, its top left at the screen's);
' angles 1024 a turn, 0 = up, 256 = right (Paths.cls).
' Swarm.Step moves them all a frame on and puts their sprites in the sprite table (Vdp's);
' Swarm.Hit finds one at a point. Both are 68000 code (keywords); the game decides the rest.

Public Const NE = 44            ' enemies
Public Const SPR0 = 20          ' their sprites: 20-63

' states (es)
Public Const S_FREE = 0
Public Const S_PATH = 1         ' following a path (ep: where in Paths.Table, en: frames left)
Public Const S_HOME = 2         ' flying to its slot
Public Const S_FORM = 3         ' in the formation
Public Const S_BEAM = 5         ' a Queen holding still (its tractor beam: the game's)
Public Const S_DYING = 6        ' exploding (ef counts 0-15)
Public Const S_HELD = 9         ' a captured fighter behind its Queen (eo)
Public Const S_FREEFLY = 11     ' moved by the game (a fighter being freed)
Public Const S_GOTO = 13        ' flying to tx, ty, then S_BEAM
Public Const S_ESCORT = 14      ' beside its Queen (eo) at tx (+/- 256), on its own: path ty

' kinds (ek)
Public Const K_DRONE = 0
Public Const K_HORNET = 1
Public Const K_QUEEN = 2
Public Const K_FIGHTER = 3

Public es(43) As Integer, ek(43) As Integer, ex(43) As Integer, ey(43) As Integer
Public ea(43) As Integer, ev(43) As Integer, et(43) As Integer, ep(43) As Integer
Public en(43) As Integer, eh(43) As Integer, ef(43) As Integer, eo(43) As Integer
Public em(43) As Integer, tx(43) As Integer, ty(43) As Integer

' the formation: its middle (x), its top row (y), half a column's width, a row's height
Public fcx As Integer, fcy As Integer, sprx As Integer, spry As Integer
Public anim As Integer          ' frames (the wings beat on it)
Public ptx As Integer, pty As Integer   ' where an aiming enemy turns to (the fighter)
Public fq(7) As Integer, fqn As Integer ' enemies that have just aimed (the game may shoot)
Public pathbase As Long, sinbase As Long, atanbase As Long, slotbase As Long

' the tables' addresses (once, at the start)
Public Sub Init()
  pathbase = Paths.Table()
  sinbase = Paths.Sines()
  atanbase = Paths.Atans()
  slotbase = Paths.Slots()
  fcx = 128 * 16
  fcy = 36 * 16
  sprx = 128
  spry = 256
End Sub

' every enemy a frame on, and its sprite
Public Sub Step()
#asm
            NTC_RS
            addq.w #1, {anim}
            movea.l {sinbase}, a5
            moveq #0, d7                ; the enemy * 2
loop:
            lea {es}, a0
            move.w 0(a0, d7.w), d0
            beq draw
            cmpi.w #1, d0
            beq st_path
            cmpi.w #2, d0
            beq st_home
            cmpi.w #3, d0
            beq st_form
            cmpi.w #6, d0
            beq st_dying
            cmpi.w #9, d0
            beq st_held
            cmpi.w #13, d0
            beq st_goto
            cmpi.w #14, d0
            beq st_escort
            bra draw

; ---- following a path
st_path:
            lea {en}, a0
            tst.w 0(a0, d7.w)
            bne p_move
p_seg:
            lea {ep}, a0
            move.w 0(a0, d7.w), d0
            movea.l {pathbase}, a1
            add.w d0, d0
            adda.w d0, a1
            move.w (a1)+, d1            ; frames
            move.w (a1)+, d2            ; turn (the end: the next state)
            move.w (a1)+, d3            ; speed
            addq.w #3, 0(a0, d7.w)
            tst.w d1
            bgt p_new
            beq p_end
            ; aim: face the fighter, and say so (the game may shoot)
            move.w {ptx}, d0
            lea {ex}, a0
            sub.w 0(a0, d7.w), d0
            move.w {pty}, d1
            lea {ey}, a0
            sub.w 0(a0, d7.w), d1
            bsr atan
            lea {ea}, a0
            move.w d0, 0(a0, d7.w)
            move.w {fqn}, d0
            cmpi.w #8, d0
            bcc p_seg
            lea {fq}, a0
            add.w d0, d0
            move.w d7, d1
            lsr.w #1, d1
            move.w d1, 0(a0, d0.w)
            addq.w #1, {fqn}
            bra p_seg
p_new:
            lea {en}, a0
            move.w d1, 0(a0, d7.w)
            lea {em}, a0
            btst #0, 1(a0, d7.w)        ; mirrored: the other way
            beq p_nm
            neg.w d2
p_nm:
            lea {et}, a0
            move.w d2, 0(a0, d7.w)
            lea {ev}, a0
            move.w d3, 0(a0, d7.w)
p_move:
            lea {en}, a0
            subq.w #1, 0(a0, d7.w)
            lea {et}, a0
            move.w 0(a0, d7.w), d0
            lea {ea}, a0
            add.w 0(a0, d7.w), d0
            andi.w #1023, d0
            move.w d0, 0(a0, d7.w)
            lea {ev}, a0
            move.w 0(a0, d7.w), d3
            bsr fwd
            lea {ey}, a0                ; off the playfield?
            move.w 0(a0, d7.w), d1
            cmpi.w #236*16, d1
            bgt p_off
            cmpi.w #-48*16, d1
            blt p_off
            lea {ex}, a0
            move.w 0(a0, d7.w), d1
            cmpi.w #-40*16, d1
            blt p_off
            cmpi.w #296*16, d1
            bgt p_off
            bra draw
p_off:
            lea {em}, a0
            btst #1, 1(a0, d7.w)        ; leaving for good (the bonus stage, a rogue)
            bne off_gone
            moveq #7, d2                ; else round to the top
p_end:                                  ; d2 = the state after the path
            cmpi.w #7, d2
            bne p_e2
            lea {ey}, a0                ; round: from the top, over its slot, home
            move.w #-16*16, 0(a0, d7.w)
            bsr slot
            lea {ex}, a0
            move.w d0, 0(a0, d7.w)
            lea {ea}, a0
            move.w #512, 0(a0, d7.w)
            moveq #2, d2
p_e2:
            cmpi.w #12, d2
            beq off_gone
            lea {es}, a0
            move.w d2, 0(a0, d7.w)
            lea {ev}, a0
            move.w #40, 0(a0, d7.w)     ; flying home at 2.5 pixels a frame
            bra draw
off_gone:
            lea {es}, a0
            clr.w 0(a0, d7.w)
            bra draw

; ---- to the slot / to tx, ty
st_home:
            bsr slot
            bra seek
st_goto:
            lea {tx}, a0
            move.w 0(a0, d7.w), d0
            lea {ty}, a0
            move.w 0(a0, d7.w), d1
seek:                                   ; d0, d1 = the target
            move.w d0, d4
            move.w d1, d5
            lea {ex}, a0
            sub.w 0(a0, d7.w), d0       ; dx
            lea {ey}, a0
            sub.w 0(a0, d7.w), d1       ; dy
            move.w d0, d2
            bpl sk1
            neg.w d2
sk1:
            move.w d1, d3
            bpl sk2
            neg.w d3
sk2:
            cmpi.w #40, d2
            bcc sk_far
            cmpi.w #40, d3
            bcc sk_far
            lea {ex}, a0                ; there
            move.w d4, 0(a0, d7.w)
            lea {ey}, a0
            move.w d5, 0(a0, d7.w)
            lea {ea}, a0
            move.w #512, 0(a0, d7.w)
            lea {es}, a0
            moveq #3, d0
            cmpi.w #2, 0(a0, d7.w)
            beq sk_set
            moveq #5, d0
sk_set:
            move.w d0, 0(a0, d7.w)
            bra draw
sk_far:
            cmpi.w #20*16, d2
            bcc sk_steer
            cmpi.w #20*16, d3
            bcc sk_steer
            move.w #48, d6              ; near: straight there, turning to face down
            bsr clampadd
            lea {ea}, a0
            move.w #512, d0
            sub.w 0(a0, d7.w), d0
            bsr turnby
            bra draw
sk_steer:
            bsr atan                    ; the way there
            lea {ea}, a0
            sub.w 0(a0, d7.w), d0
            bsr turnby
            lea {ea}, a0
            move.w 0(a0, d7.w), d0
            lea {ev}, a0
            move.w 0(a0, d7.w), d3
            bsr fwd
            bra draw

; ---- in the formation
st_form:
            bsr slot
            lea {ex}, a0
            move.w d0, 0(a0, d7.w)
            lea {ey}, a0
            move.w d1, 0(a0, d7.w)
            lea {ea}, a0
            move.w #512, 0(a0, d7.w)
            bra draw

; ---- exploding
st_dying:
            lea {ef}, a0
            addq.w #1, 0(a0, d7.w)
            cmpi.w #16, 0(a0, d7.w)
            blt draw
            lea {es}, a0
            clr.w 0(a0, d7.w)
            bra draw

; ---- a captured fighter: 16 pixels behind its Queen
st_held:
            lea {eo}, a0
            move.w 0(a0, d7.w), d6
            add.w d6, d6
            lea {ea}, a0
            move.w 0(a0, d6.w), d0
            move.w d0, 0(a0, d7.w)
            add.w d0, d0
            move.w 0(a5, d0.w), d1
            lea {ex}, a0
            move.w 0(a0, d6.w), d2
            sub.w d1, d2
            move.w d2, 0(a0, d7.w)
            addi.w #512, d0
            andi.w #2047, d0
            move.w 0(a5, d0.w), d1
            lea {ey}, a0
            move.w 0(a0, d6.w), d2
            add.w d1, d2
            move.w d2, 0(a0, d7.w)
            bra draw

; ---- an escort: beside its Queen while she dives, else on its own
st_escort:
            lea {eo}, a0
            move.w 0(a0, d7.w), d6
            add.w d6, d6
            lea {es}, a0
            cmpi.w #1, 0(a0, d6.w)
            beq es_ok
            move.w #1, 0(a0, d7.w)      ; its own path from here
            lea {ep}, a0
            lea {ty}, a1
            move.w 0(a1, d7.w), 0(a0, d7.w)
            lea {en}, a0
            clr.w 0(a0, d7.w)
            bra draw
es_ok:
            lea {ea}, a0
            move.w 0(a0, d6.w), d0
            move.w d0, 0(a0, d7.w)
            add.w d0, d0
            addi.w #512, d0
            andi.w #2047, d0
            move.w 0(a5, d0.w), d1      ; cos: the Queen's right is (cos, sin)
            lea {tx}, a1
            move.w 0(a1, d7.w), d3
            muls.w d3, d1
            asr.l #8, d1
            lea {ex}, a0
            move.w 0(a0, d6.w), d2
            add.w d1, d2
            move.w d2, 0(a0, d7.w)
            subi.w #512, d0
            andi.w #2047, d0
            move.w 0(a5, d0.w), d1      ; sin
            muls.w d3, d1
            asr.l #8, d1
            lea {ey}, a0
            move.w 0(a0, d6.w), d2
            add.w d1, d2
            move.w d2, 0(a0, d7.w)
            bra draw

; ---- the sprite
draw:
            lea ntc_sat+{spr0}*8, a1
            move.w d7, d0
            lsl.w #2, d0
            adda.w d0, a1
            lea {es}, a0
            move.w 0(a0, d7.w), d0
            beq dr_hide
            lea {ey}, a0
            move.w 0(a0, d7.w), d2
            asr.w #4, d2
            addi.w #128-8, d2
            ble dr_hide
            lea {ex}, a0
            move.w 0(a0, d7.w), d3
            asr.w #4, d3
            addi.w #128-8, d3
            bgt dr_xok
            moveq #1, d3
dr_xok:
            cmpi.w #6, d0
            beq dr_expl
            lea {ek}, a0
            move.w 0(a0, d7.w), d4      ; the kind
            lea {ea}, a0
            move.w 0(a0, d7.w), d0
            addi.w #32, d0
            lsr.w #6, d0
            andi.w #15, d0              ; 16 directions -> 5 drawn, flipped
            moveq #0, d5
            cmpi.w #4, d0
            bls dr_f
            cmpi.w #8, d0
            bhi dr_d2
            neg.w d0
            addq.w #8, d0
            move.w #$1000, d5           ; flip Y
            bra dr_f
dr_d2:
            cmpi.w #12, d0
            bhi dr_d3
            subq.w #8, d0
            move.w #$1800, d5           ; flip X and Y
            bra dr_f
dr_d3:
            neg.w d0
            addi.w #16, d0
            move.w #$0800, d5           ; flip X
dr_f:
            cmpi.w #3, d4
            beq dr_fighter
            add.w d0, d0
            move.w {anim}, d1
            lsr.w #4, d1
            andi.w #1, d1
            add.w d1, d0
            lsl.w #2, d0
            add.w d4, d4
            lea dr_bases(pc), a0
            add.w 0(a0, d4.w), d0
            move.w #$4000, d1           ; Drones, Hornets: palette 2
            cmpi.w #4, d4
            bne dr_pal
            move.w #$2000, d1           ; a Queen: palette 1, hit: palette 3
            lea {eh}, a0
            cmpi.w #2, 0(a0, d7.w)
            beq dr_pal
            move.w #$6000, d1
            bra dr_pal
dr_fighter:
            lsl.w #2, d0
            addi.w #{gfx.t_fighter}, d0
            move.w #$6000, d1           ; a captured fighter: palette 3 (red)
            lea {es}, a0
            cmpi.w #11, 0(a0, d7.w)
            bne dr_pal
            move.w #$2000, d1           ; being freed: yours again (palette 1)
dr_pal:
            or.w d1, d0
            or.w d5, d0
            move.w d2, (a1)+
            move.w #5, (a1)+
            move.w d0, (a1)+
            move.w d3, (a1)
            bra next
dr_expl:
            lea {ef}, a0
            move.w 0(a0, d7.w), d0
            lsr.w #2, d0
            lsl.w #2, d0
            addi.w #{gfx.t_expl}+$4000, d0
            move.w d2, (a1)+
            move.w #5, (a1)+
            move.w d0, (a1)+
            move.w d3, (a1)
            bra next
dr_hide:
            clr.w (a1)
next:
            addq.w #2, d7
            cmpi.w #88, d7
            bcs loop
            NTC_TS
            bra done

dr_bases:
            dc.w {gfx.t_drone}, {gfx.t_hornet}, {gfx.t_queen}

; ---- x, y += the angle d0 at speed d3 (enemy d7)
fwd:
            add.w d0, d0
            move.w 0(a5, d0.w), d1
            muls.w d3, d1
            asr.l #8, d1
            lea {ex}, a0
            add.w d1, 0(a0, d7.w)
            addi.w #512, d0
            andi.w #2047, d0
            move.w 0(a5, d0.w), d1
            muls.w d3, d1
            asr.l #8, d1
            lea {ey}, a0
            sub.w d1, 0(a0, d7.w)
            rts

; ---- d0, d1 = the slot's x, y (a captured fighter: where it is)
slot:
            cmpi.w #80, d7
            bcc slot_self
            movea.l {slotbase}, a1
            move.w d7, d0
            add.w d0, d0
            move.w 0(a1, d0.w), d1
            move.w 2(a1, d0.w), d2
            add.w d1, d1
            subi.w #9, d1
            muls.w {sprx}, d1
            add.w {fcx}, d1
            muls.w {spry}, d2
            add.w {fcy}, d2
            move.w d1, d0
            move.w d2, d1
            rts
slot_self:
            lea {ex}, a0
            move.w 0(a0, d7.w), d0
            lea {ey}, a0
            move.w 0(a0, d7.w), d1
            rts

; ---- ex += d0, ey += d1, each kept within +/- d6
clampadd:
            cmp.w d6, d0
            ble ca1
            move.w d6, d0
ca1:
            neg.w d6
            cmp.w d6, d0
            bge ca2
            move.w d6, d0
ca2:
            cmp.w d6, d1
            bge ca3
            move.w d6, d1
ca3:
            neg.w d6
            cmp.w d6, d1
            ble ca4
            move.w d6, d1
ca4:
            lea {ex}, a0
            add.w d0, 0(a0, d7.w)
            lea {ey}, a0
            add.w d1, 0(a0, d7.w)
            rts

; ---- ea turned by d0 (the difference, any size: the short way, 28 at most)
turnby:
            andi.w #1023, d0
            cmpi.w #512, d0
            blt tb1
            subi.w #1024, d0
tb1:
            cmpi.w #28, d0
            ble tb2
            moveq #28, d0
tb2:
            cmpi.w #-28, d0
            bge tb3
            moveq #-28, d0
tb3:
            lea {ea}, a0
            add.w 0(a0, d7.w), d0
            andi.w #1023, d0
            move.w d0, 0(a0, d7.w)
            rts

; ---- d0 = the angle of the way d0 = dx, d1 = dy (0 = up)
atan:
            move.l d4, -(sp)
            moveq #0, d4
            tst.w d0
            bpl at1
            neg.w d0
            bset #0, d4                 ; left
at1:
            tst.w d1
            bmi at2
            bset #1, d4                 ; down
            bra at3
at2:
            neg.w d1
at3:
            cmp.w d1, d0
            bhi at_x
            tst.w d1
            beq at_zero
            andi.l #$FFFF, d0
            lsl.l #5, d0
            divu.w d1, d0
            add.w d0, d0
            movea.l {atanbase}, a0
            move.w 0(a0, d0.w), d0      ; from the up / down line
            bra at_q
at_x:
            andi.l #$FFFF, d1
            lsl.l #5, d1
            divu.w d0, d1
            add.w d1, d1
            movea.l {atanbase}, a0
            move.w #256, d0
            sub.w 0(a0, d1.w), d0
            bra at_q
at_zero:
            moveq #0, d0
at_q:
            btst #1, d4
            bne at_down
            btst #0, d4
            beq at_e
            neg.w d0                    ; up, left: 1024 - a
            addi.w #1024, d0
            andi.w #1023, d0
            bra at_e
at_down:
            neg.w d0                    ; down, right: 512 - a
            addi.w #512, d0
            btst #0, d4
            beq at_e
            neg.w d0                    ; down, left: 512 + a
            addi.w #1024, d0
at_e:
            move.l (sp)+, d4
            rts
done:
#endasm
End Sub

' the first enemy (not exploding, not gone, not a fighter being freed) within r of x, y (all in 1/16 pixels), or -1
Public Function Hit(ByVal x As Integer, ByVal y As Integer, ByVal r As Integer) As Integer
#asm
            movea.l (sp)+, a0
            move.w (a0), d3
            movea.l (sp)+, a0
            move.w (a0), d4
            movea.l (sp)+, a0
            move.w (a0), d5
            movea.l (sp)+, a4
            lea {es}, a1
            lea {ex}, a2
            lea {ey}, a3
            moveq #0, d7
lp:
            move.w 0(a1, d7.w), d0
            beq nx
            cmpi.w #6, d0
            beq nx
            cmpi.w #11, d0              ; a fighter being freed: yours, not a target
            beq nx
            move.w 0(a2, d7.w), d1
            sub.w d3, d1
            bpl h1
            neg.w d1
h1:
            cmp.w d5, d1
            bcc nx
            move.w 0(a3, d7.w), d1
            sub.w d4, d1
            bpl h2
            neg.w d1
h2:
            cmp.w d5, d1
            bcc nx
            move.w d7, d0
            lsr.w #1, d0
            move.w d0, (a4)
            bra done
nx:
            addq.w #2, d7
            cmpi.w #88, d7
            bcs lp
            move.w #-1, (a4)
done:
#endasm
End Function

' an enemy on its way along a path: from x, y facing angle a (pixels), mirrored or not
Public Sub Launch(ByVal i As Integer, ByVal path As Integer, ByVal x As Integer, ByVal y As Integer, ByVal a As Integer, ByVal mirror As Integer)
  es(i) = S_PATH
  ep(i) = path
  en(i) = 0
  em(i) = mirror
  ex(i) = x * 16
  ey(i) = y * 16
  ea(i) = a
End Sub

' a dive from where it is (in the formation)
Public Sub Dive(ByVal i As Integer, ByVal path As Integer, ByVal mirror As Integer)
  es(i) = S_PATH
  ep(i) = path
  en(i) = 0
  em(i) = mirror
End Sub
