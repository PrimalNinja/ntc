' Swarm - CYBORG SWARM's enemies: where each is, where it is going, and its sprite.
' (c) 2026 Cyborg Unicorn Pty Ltd
'
' 44 enemies: 0-3 the Queens, 4-19 the Hornets, 20-39 the Drones (each has its slot in the
' formation), 40-43 a fighter a Queen has captured (40 + the Queen's number).
' Positions are in 1/16 pixels on the playfield (256 x 200, its top left at the screen's);
' angles 1024 a turn, 0 = up, 256 = right (Paths.cls).
' Swarm.Step moves them all a frame on and puts their sprites in Vic's sprite table;
' Swarm.Hit finds one at a point. Both are 45GS02 code (keywords); the game decides the rest.

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
Public pathbase As Integer, sinbase As Integer, atanbase As Integer, slotbase As Integer

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
' (base page: z_t0 = the enemy * 2, z_a .. z_g working values; the real stack: jsr)
Public Sub Step()
#asm
            NTC_RS
            inc {anim}
            bne an1
            inc {anim}+1
an1:
            lda #0
            sta z_t0
loop:
            ldx z_t0
            lda {es},x
            beq jdraw
            cmp #1
            beq jpath
            cmp #2
            beq jhome
            cmp #3
            beq jform
            cmp #6
            beq jdying
            cmp #9
            beq jheld
            cmp #13
            beq jgoto
            cmp #14
            beq jescort
jdraw:
            jmp draw
jpath:
            jmp st_path
jhome:
            jmp st_home
jform:
            jmp st_form
jdying:
            jmp st_dying
jheld:
            jmp st_held
jgoto:
            jmp st_goto
jescort:
            jmp st_escort

; ---- following a path
st_path:
            ldx z_t0
            lda {en},x
            ora {en}+1,x
            bne p_move
p_seg:
            ldx z_t0                    ; the segment: frames, turn, speed
            lda {ep},x
            asl
            sta z_p0
            lda {ep}+1,x
            rol
            sta z_p0+1
            clc
            lda z_p0
            adc {pathbase}
            sta z_p0
            lda z_p0+1
            adc {pathbase}+1
            sta z_p0+1
            ldy #0
            lda (z_p0),y
            sta z_d                     ; frames
            iny
            lda (z_p0),y
            sta z_d+1
            iny
            lda (z_p0),y
            sta z_e                     ; turn (the end: the next state)
            iny
            lda (z_p0),y
            sta z_e+1
            iny
            lda (z_p0),y
            sta z_f                     ; speed
            iny
            lda (z_p0),y
            sta z_f+1
            clc                         ; ep += 3
            lda {ep},x
            adc #3
            sta {ep},x
            lda {ep}+1,x
            adc #0
            sta {ep}+1,x
            lda z_d+1
            bmi p_aim
            ora z_d
            bne p_new
            jmp p_end
p_aim:
            ; aim: face the fighter, and say so (the game may shoot)
            sec
            lda {ptx}
            sbc {ex},x
            sta z_a
            lda {ptx}+1
            sbc {ex}+1,x
            sta z_a+1
            sec
            lda {pty}
            sbc {ey},x
            sta z_b
            lda {pty}+1
            sbc {ey}+1,x
            sta z_b+1
            jsr atan
            ldx z_t0
            lda z_a
            sta {ea},x
            lda z_a+1
            sta {ea}+1,x
            lda {fqn}
            cmp #8
            bcs p_seg
            asl
            tay
            lda z_t0
            lsr
            sta {fq},y
            lda #0
            sta {fq}+1,y
            inc {fqn}
            jmp p_seg
p_new:
            lda z_d
            sta {en},x
            lda z_d+1
            sta {en}+1,x
            lda {em},x                  ; mirrored: the other way
            and #1
            beq p_nm
            sec
            lda #0
            sbc z_e
            sta z_e
            lda #0
            sbc z_e+1
            sta z_e+1
p_nm:
            lda z_e
            sta {et},x
            lda z_e+1
            sta {et}+1,x
            lda z_f
            sta {ev},x
            lda z_f+1
            sta {ev}+1,x
p_move:
            ldx z_t0
            lda {en},x                  ; en - 1
            bne p_m1
            dec {en}+1,x
p_m1:
            dec {en},x
            clc                         ; ea = (ea + et) and 1023
            lda {ea},x
            adc {et},x
            sta {ea},x
            sta z_a
            lda {ea}+1,x
            adc {et}+1,x
            and #3
            sta {ea}+1,x
            sta z_a+1
            lda {ev},x
            sta z_c
            lda {ev}+1,x
            sta z_c+1
            jsr fwd
            ldx z_t0                    ; off the playfield?
            lda {ey},x                  ; y > 212 * 16 or y < -48 * 16
            sta z_a
            lda {ey}+1,x
            sta z_a+1
            lda #<(212*16)
            sta z_b
            lda #>(212*16)
            sta z_b+1
            jsr sgt                     ; z_a > z_b: carry set
            bcs p_off
            lda #<(-48*16)
            sta z_b
            lda #>(-48*16)
            sta z_b+1
            jsr slt
            bcs p_off
            ldx z_t0
            lda {ex},x                  ; x < -40 * 16 or x > 296 * 16
            sta z_a
            lda {ex}+1,x
            sta z_a+1
            lda #<(-40*16)
            sta z_b
            lda #>(-40*16)
            sta z_b+1
            jsr slt
            bcs p_off
            lda #<(296*16)
            sta z_b
            lda #>(296*16)
            sta z_b+1
            jsr sgt
            bcs p_off
            jmp draw
p_off:
            ldx z_t0
            lda {em},x                  ; leaving for good (the bonus stage, a rogue)
            and #2
            bne off_gone
            lda #7                      ; else round to the top
            sta z_e
            lda #0
            sta z_e+1
p_end:                                  ; z_e = the state after the path
            ldx z_t0
            lda z_e
            cmp #7
            bne p_e2
            lda #<(-16*16)              ; round: from the top, over its slot, home
            sta {ey},x
            lda #>(-16*16)
            sta {ey}+1,x
            jsr slot
            ldx z_t0
            lda z_a
            sta {ex},x
            lda z_a+1
            sta {ex}+1,x
            lda #<512
            sta {ea},x
            lda #>512
            sta {ea}+1,x
            lda #2
            sta z_e
p_e2:
            lda z_e
            cmp #12
            beq off_gone
            sta {es},x
            lda #0
            sta {es}+1,x
            lda #40                     ; flying home at 2.5 pixels a frame
            sta {ev},x
            lda #0
            sta {ev}+1,x
            jmp draw
off_gone:
            ldx z_t0
            lda #0
            sta {es},x
            sta {es}+1,x
            jmp draw

; ---- to the slot / to tx, ty
st_home:
            jsr slot
            jmp seek
st_goto:
            ldx z_t0
            lda {tx},x
            sta z_a
            lda {tx}+1,x
            sta z_a+1
            lda {ty},x
            sta z_b
            lda {ty}+1,x
            sta z_b+1
seek:                                   ; z_a, z_b = the target
            lda z_a
            sta z_d
            lda z_a+1
            sta z_d+1
            lda z_b
            sta z_e
            lda z_b+1
            sta z_e+1
            ldx z_t0
            sec                         ; dx, dy
            lda z_a
            sbc {ex},x
            sta z_a
            lda z_a+1
            sbc {ex}+1,x
            sta z_a+1
            sec
            lda z_b
            sbc {ey},x
            sta z_b
            lda z_b+1
            sbc {ey}+1,x
            sta z_b+1
            lda z_a                     ; |dx|, |dy|
            sta z_f
            lda z_a+1
            sta z_f+1
            bpl sk1
            sec
            lda #0
            sbc z_f
            sta z_f
            lda #0
            sbc z_f+1
            sta z_f+1
sk1:
            lda z_b
            sta z_g
            lda z_b+1
            sta z_g+1
            bpl sk2
            sec
            lda #0
            sbc z_g
            sta z_g
            lda #0
            sbc z_g+1
            sta z_g+1
sk2:
            lda z_f+1                   ; both under 40: there
            bne sk_far
            lda z_f
            cmp #40
            bcs sk_far
            lda z_g+1
            bne sk_far
            lda z_g
            cmp #40
            bcs sk_far
            ldx z_t0
            lda z_d
            sta {ex},x
            lda z_d+1
            sta {ex}+1,x
            lda z_e
            sta {ey},x
            lda z_e+1
            sta {ey}+1,x
            lda #<512
            sta {ea},x
            lda #>512
            sta {ea}+1,x
            lda {es},x
            cmp #2
            beq sk_form
            lda #5
            bne sk_set
sk_form:
            lda #3
sk_set:
            sta {es},x
            lda #0
            sta {es}+1,x
            jmp draw
sk_far:
            lda z_f+1                   ; both under 20 pixels: straight there
            cmp #>(20*16)
            bcc sk_n1
            bne sk_steer
            lda z_f
            cmp #<(20*16)
            bcs sk_steer
sk_n1:
            lda z_g+1
            cmp #>(20*16)
            bcc sk_near
            bne sk_steer
            lda z_g
            cmp #<(20*16)
            bcs sk_steer
sk_near:
            lda #48                     ; near: straight there, turning to face down
            sta z_c
            jsr clampadd
            ldx z_t0
            sec
            lda #<512
            sbc {ea},x
            sta z_a
            lda #>512
            sbc {ea}+1,x
            sta z_a+1
            jsr turnby
            jmp draw
sk_steer:
            jsr atan                    ; the way there
            ldx z_t0
            sec
            lda z_a
            sbc {ea},x
            sta z_a
            lda z_a+1
            sbc {ea}+1,x
            sta z_a+1
            jsr turnby
            ldx z_t0
            lda {ea},x
            sta z_a
            lda {ea}+1,x
            sta z_a+1
            lda {ev},x
            sta z_c
            lda {ev}+1,x
            sta z_c+1
            jsr fwd
            jmp draw

; ---- in the formation
st_form:
            jsr slot
            ldx z_t0
            lda z_a
            sta {ex},x
            lda z_a+1
            sta {ex}+1,x
            lda z_b
            sta {ey},x
            lda z_b+1
            sta {ey}+1,x
            lda #<512
            sta {ea},x
            lda #>512
            sta {ea}+1,x
            jmp draw

; ---- exploding
st_dying:
            ldx z_t0
            inc {ef},x
            lda {ef},x
            cmp #16
            bcc jd2
            lda #0
            sta {es},x
            sta {es}+1,x
jd2:
            jmp draw

; ---- a captured fighter: 16 pixels behind its Queen
st_held:
            ldx z_t0
            lda {eo},x
            asl
            tay                         ; Y = the Queen * 2
            lda {ea},y
            sta {ea},x
            sta z_a
            lda {ea}+1,y
            sta {ea}+1,x
            sta z_a+1
            sty z_t1
            jsr getsin                  ; x = the Queen's - sin
            ldx z_t0
            ldy z_t1
            sec
            lda {ex},y
            sbc z_b
            sta {ex},x
            lda {ex}+1,y
            sbc z_b+1
            sta {ex}+1,x
            clc                         ; y = the Queen's + cos
            lda z_a
            adc #<256
            sta z_a
            lda z_a+1
            adc #>256
            sta z_a+1
            jsr getsin
            ldx z_t0
            ldy z_t1
            clc
            lda {ey},y
            adc z_b
            sta {ey},x
            lda {ey}+1,y
            adc z_b+1
            sta {ey}+1,x
            jmp draw

; ---- an escort: beside its Queen while she dives, else on its own
st_escort:
            ldx z_t0
            lda {eo},x
            asl
            tay
            sty z_t1
            lda {es},y
            cmp #1
            beq es_ok
            lda #1                      ; its own path from here
            sta {es},x
            lda #0
            sta {es}+1,x
            lda {ty},x
            sta {ep},x
            lda {ty}+1,x
            sta {ep}+1,x
            lda #0
            sta {en},x
            sta {en}+1,x
            jmp draw
es_ok:
            lda {ea},y
            sta {ea},x
            sta z_a
            lda {ea}+1,y
            sta {ea}+1,x
            sta z_a+1
            clc                         ; cos: the Queen's right is (cos, sin)
            lda z_a
            adc #<256
            sta z_a
            lda z_a+1
            adc #>256
            sta z_a+1
            jsr getsin
            ldx z_t0
            lda {tx},x
            sta z_c
            lda {tx}+1,x
            sta z_c+1
            jsr mul8
            ldx z_t0
            ldy z_t1
            clc
            lda {ex},y
            adc z_b
            sta {ex},x
            lda {ex}+1,y
            adc z_b+1
            sta {ex}+1,x
            sec                         ; sin
            lda z_a
            sbc #<256
            sta z_a
            lda z_a+1
            sbc #>256
            sta z_a+1
            jsr getsin
            ldx z_t0
            lda {tx},x
            sta z_c
            lda {tx}+1,x
            sta z_c+1
            jsr mul8
            ldx z_t0
            ldy z_t1
            clc
            lda {ey},y
            adc z_b
            sta {ey},x
            lda {ey}+1,y
            adc z_b+1
            sta {ey}+1,x
            jmp draw

; ---- the sprite: Vic's sprite table entry SPR0 + the enemy (8 bytes: x, y, image,
; attributes, shown)
draw:
            lda #0                      ; the entry: ntc_vic_sat + (SPR0 + i) * 8 (z_t0 = i * 2)
            sta z_p1+1
            lda z_t0
            asl
            rol z_p1+1
            asl
            rol z_p1+1
            clc
            adc #<(ntc_vic_sat+{spr0}*8)
            sta z_p1
            lda z_p1+1
            adc #>(ntc_vic_sat+{spr0}*8)
            sta z_p1+1
            ldx z_t0
            lda {es},x
            bne dr_on
            jmp dr_hide
dr_on:
            lda {ey},x                  ; y = ey / 16 - 8
            sta z_b
            lda {ey}+1,x
            sta z_b+1
            ldy #4
dr_ys:
            lda z_b+1
            cmp #$80
            ror z_b+1
            ror z_b
            dey
            bne dr_ys
            sec
            lda z_b
            sbc #8
            sta z_b
            lda z_b+1
            sbc #0
            sta z_b+1
            bpl dr_yok                  ; above -32: hidden
            cmp #$FF
            bne dr_hide
            lda z_b
            cmp #$E0
            bcc dr_hide
dr_yok:
            lda {ex},x                  ; x = ex / 16 - 8
            sta z_c
            lda {ex}+1,x
            sta z_c+1
            ldy #4
dr_xs:
            lda z_c+1
            cmp #$80
            ror z_c+1
            ror z_c
            dey
            bne dr_xs
            sec
            lda z_c
            sbc #8
            sta z_c
            lda z_c+1
            sbc #0
            sta z_c+1
            ldy #0                      ; x, y into the entry
            lda z_c
            sta (z_p1),y
            iny
            lda z_c+1
            sta (z_p1),y
            iny
            lda z_b
            sta (z_p1),y
            iny
            lda z_b+1
            sta (z_p1),y
            lda {es},x
            cmp #6
            bne dr_dir
            lda {ef},x                  ; exploding: frame ef / 4, palette 2
            lsr
            lsr
            clc
            adc #{gfx.i_expl}
            sta z_d
            lda #32
            sta z_d+1
            jmp dr_put
dr_dir:
            clc                         ; 16 directions -> 5 drawn, flipped
            lda {ea},x
            adc #32
            sta z_a
            lda {ea}+1,x
            adc #0
            sta z_a+1
            ldy #6
dr_ds:
            lsr z_a+1
            ror z_a
            dey
            bne dr_ds
            lda z_a
            and #15
            ldy #0                      ; Y = the flips
            cmp #5
            bcc dr_f
            cmp #9
            bcs dr_d2
            eor #$FF                    ; 8 - d
            sec
            adc #8
            ldy #2                      ; flip y
            bne dr_f
dr_d2:
            cmp #13
            bcs dr_d3
            sec
            sbc #8
            ldy #3                      ; flip x and y
            bne dr_f
dr_d3:
            eor #$FF                    ; 16 - d
            sec
            adc #16
            ldy #1                      ; flip x
dr_f:
            sta z_e                     ; the frame (0-4)
            sty z_e+1
            lda {ek},x
            cmp #3
            beq dr_fighter
            tay                         ; the kind's first image + frame * 2 + the wings
            lda z_e
            asl
            sta z_e
            lda {anim}
            lsr
            lsr
            lsr
            lsr
            and #1
            ora z_e
            clc
            adc dr_bases,y
            sta z_d
            lda #32                     ; Drones, Hornets: palette 2
            cpy #2
            bne dr_pal
            lda #16                     ; a Queen: palette 1, hit: palette 3
            ldy {eh},x
            cpy #2
            beq dr_pal
            lda #48
            jmp dr_pal
dr_fighter:
            lda z_e
            clc
            adc #{gfx.i_fighter}
            sta z_d
            lda #48                     ; a captured fighter: palette 3 (red)
            ldy {es},x
            cpy #11
            bne dr_pal
            lda #16                     ; being freed: yours again (palette 1)
dr_pal:
            ora z_e+1
            sta z_d+1
dr_put:
            ldy #4
            lda z_d
            sta (z_p1),y
            iny
            lda z_d+1
            sta (z_p1),y
            iny
            lda #1
            sta (z_p1),y
            jmp next
dr_hide:
            ldy #6
            lda #0
            sta (z_p1),y
next:
            inc z_t0
            inc z_t0
            lda z_t0
            cmp #88
            bcs fin
            jmp loop
fin:
            NTC_TS
            jmp done

dr_bases:
            db {gfx.i_drone}, {gfx.i_hornet}, {gfx.i_queen}

; ---- z_b = sin(z_a) (* 256): z_a any angle
getsin:
            lda z_a
            asl
            sta z_p0
            lda z_a+1
            and #3
            rol
            sta z_p0+1
            clc
            lda z_p0
            adc {sinbase}
            sta z_p0
            lda z_p0+1
            adc {sinbase}+1
            sta z_p0+1
            ldy #0
            lda (z_p0),y
            sta z_b
            iny
            lda (z_p0),y
            sta z_b+1
            rts

; ---- z_b = z_b * z_c / 256 (signed: the hardware multiplier, the product's bytes 1-2)
mul8:
            lda z_b
            sta $D770
            lda z_b+1
            sta $D771
            and #$80
            beq m8a
            lda #$FF
m8a:
            sta $D772
            sta $D773
            lda z_c
            sta $D774
            lda z_c+1
            sta $D775
            and #$80
            beq m8b
            lda #$FF
m8b:
            sta $D776
            sta $D777
            lda $D779
            sta z_b
            lda $D77A
            sta z_b+1
            rts

; ---- x, y += the angle z_a at speed z_c (enemy z_t0)
fwd:
            jsr getsin
            jsr mul8
            ldx z_t0
            clc
            lda {ex},x
            adc z_b
            sta {ex},x
            lda {ex}+1,x
            adc z_b+1
            sta {ex}+1,x
            clc
            lda z_a
            adc #<256
            sta z_a
            lda z_a+1
            adc #>256
            sta z_a+1
            jsr getsin
            jsr mul8
            ldx z_t0
            sec
            lda {ey},x
            sbc z_b
            sta {ey},x
            lda {ey}+1,x
            sbc z_b+1
            sta {ey}+1,x
            rts

; ---- z_a, z_b = the slot's x, y (a captured fighter: where it is)
slot:
            lda z_t0
            cmp #80
            bcs slot_self
            asl                         ; the slot's column, row (2 words each)
            clc
            adc {slotbase}
            sta z_p0
            lda {slotbase}+1
            adc #0
            sta z_p0+1
            ldy #0
            lda (z_p0),y                ; x = (column * 2 - 9) * sprx + fcx
            asl
            sec
            sbc #9
            sta z_b
            lda #0
            sbc #0
            sta z_b+1
            lda {sprx}
            sta z_c
            lda {sprx}+1
            sta z_c+1
            jsr mul16
            clc
            lda z_b
            adc {fcx}
            sta z_a
            lda z_b+1
            adc {fcx}+1
            sta z_a+1
            ldy #2
            lda (z_p0),y                ; y = row * spry + fcy
            sta z_b
            lda #0
            sta z_b+1
            lda {spry}
            sta z_c
            lda {spry}+1
            sta z_c+1
            jsr mul16
            clc
            lda z_b
            adc {fcy}
            sta z_b
            lda z_b+1
            adc {fcy}+1
            sta z_b+1
            rts
slot_self:
            ldx z_t0
            lda {ex},x
            sta z_a
            lda {ex}+1,x
            sta z_a+1
            lda {ey},x
            sta z_b
            lda {ey}+1,x
            sta z_b+1
            rts

; ---- z_b = z_b * z_c (the low 16 bits)
mul16:
            lda z_b
            sta $D770
            lda z_b+1
            sta $D771
            lda #0
            sta $D772
            sta $D773
            sta $D776
            sta $D777
            lda z_c
            sta $D774
            lda z_c+1
            sta $D775
            lda $D778
            sta z_b
            lda $D779
            sta z_b+1
            rts

; ---- ex += z_a, ey += z_b, each kept within +/- z_c (z_c: 0-127)
clampadd:
            lda z_a+1                   ; dx > c: c
            bmi ca1
            bne ca0
            lda z_a
            cmp z_c
            bcc ca2
            beq ca2
ca0:
            lda z_c
            sta z_a
            lda #0
            sta z_a+1
            jmp ca2
ca1:                                    ; dx < -c: -c
            cmp #$FF
            bne ca1b
            lda z_a
            clc
            adc z_c
            bcs ca2
ca1b:
            sec
            lda #0
            sbc z_c
            sta z_a
            lda #$FF
            sta z_a+1
ca2:
            lda z_b+1
            bmi ca3
            bne ca2b
            lda z_b
            cmp z_c
            bcc ca4
            beq ca4
ca2b:
            lda z_c
            sta z_b
            lda #0
            sta z_b+1
            jmp ca4
ca3:
            cmp #$FF
            bne ca3b
            lda z_b
            clc
            adc z_c
            bcs ca4
ca3b:
            sec
            lda #0
            sbc z_c
            sta z_b
            lda #$FF
            sta z_b+1
ca4:
            ldx z_t0
            clc
            lda {ex},x
            adc z_a
            sta {ex},x
            lda {ex}+1,x
            adc z_a+1
            sta {ex}+1,x
            clc
            lda {ey},x
            adc z_b
            sta {ey},x
            lda {ey}+1,x
            adc z_b+1
            sta {ey}+1,x
            rts

; ---- ea turned by z_a (the difference, any size: the short way, 28 at most)
turnby:
            lda z_a+1
            and #3
            sta z_a+1
            cmp #2                      ; >= 512: - 1024
            bcc tb1
            ora #$FC
            sta z_a+1
tb1:
            lda z_a+1                   ; > 28: 28
            bmi tb2
            bne tb1b
            lda z_a
            cmp #29
            bcc tb3
tb1b:
            lda #28
            sta z_a
            lda #0
            sta z_a+1
            jmp tb3
tb2:                                    ; < -28: -28
            cmp #$FF
            bne tb2b
            lda z_a
            cmp #<(-28)
            bcs tb3
tb2b:
            lda #<(-28)
            sta z_a
            lda #$FF
            sta z_a+1
tb3:
            ldx z_t0
            clc
            lda {ea},x
            adc z_a
            sta {ea},x
            lda {ea}+1,x
            adc z_a+1
            and #3
            sta {ea}+1,x
            rts

; ---- z_a = the angle of the way z_a = dx, z_b = dy (0 = up)
atan:
            lda #0
            sta z_t2                    ; bit 0 left, bit 1 down
            lda z_a+1
            bpl at1
            sec
            lda #0
            sbc z_a
            sta z_a
            lda #0
            sbc z_a+1
            sta z_a+1
            lda #1
            sta z_t2
at1:
            lda z_b+1
            bmi at2
            lda z_t2
            ora #2
            sta z_t2
            jmp at3
at2:
            sec
            lda #0
            sbc z_b
            sta z_b
            lda #0
            sbc z_b+1
            sta z_b+1
at3:
            lda z_b                     ; |dx| > |dy|: from the across line
            cmp z_a
            lda z_b+1
            sbc z_a+1
            bcc at_x
            lda z_b
            ora z_b+1
            beq at_zero
            ; t = |dx| * 32 / |dy| (0-32)
            lda z_a
            sta z_c
            lda z_a+1
            sta z_c+1
            lda z_b
            sta z_d
            lda z_b+1
            sta z_d+1
            jsr div32
            jsr atantab
            jmp at_q
at_x:
            lda z_b
            sta z_c
            lda z_b+1
            sta z_c+1
            lda z_a
            sta z_d
            lda z_a+1
            sta z_d+1
            jsr div32
            jsr atantab
            sec                         ; 256 - a
            lda #<256
            sbc z_a
            sta z_a
            lda #>256
            sbc z_a+1
            sta z_a+1
            jmp at_q
at_zero:
            lda #0
            sta z_a
            sta z_a+1
at_q:
            lda z_t2
            and #2
            bne at_down
            lda z_t2
            and #1
            beq at_e
            sec                         ; up, left: 1024 - a
            lda #<1024
            sbc z_a
            sta z_a
            lda #>1024
            sbc z_a+1
            and #3
            sta z_a+1
            jmp at_e
at_down:
            sec                         ; down, right: 512 - a
            lda #<512
            sbc z_a
            sta z_a
            lda #>512
            sbc z_a+1
            sta z_a+1
            lda z_t2
            and #1
            beq at_e
            sec                         ; down, left: 512 + a = 1024 - (512 - a)
            lda #<1024
            sbc z_a
            sta z_a
            lda #>1024
            sbc z_a+1
            sta z_a+1
at_e:
            rts
; z_a = atan table [A] (A = 0-32)
atantab:
            asl
            tay
            lda {atanbase}
            sta z_p0
            lda {atanbase}+1
            sta z_p0+1
            lda (z_p0),y
            sta z_a
            iny
            lda (z_p0),y
            sta z_a+1
            rts
; A = z_c * 32 / z_d (z_c <= z_d, unsigned): 0-32
div32:
            lda #0
            sta z_t3                    ; the quotient
            ldx #6                      ; 6 bits (the first: z_c >= z_d)
            jmp dv_cmp
dv_lp:
            asl z_c
            rol z_c+1
            asl z_t3
dv_cmp:
            lda z_c
            cmp z_d
            lda z_c+1
            sbc z_d+1
            bcc dv_n
            sta z_c+1
            lda z_c
            sbc z_d
            sta z_c
            inc z_t3
dv_n:
            dex
            bne dv_lp
            lda z_t3
            rts

; ---- signed compares: z_a > z_b / z_a < z_b, the answer in the carry
sgt:
            lda z_b                     ; z_b < z_a
            cmp z_a
            lda z_b+1
            sbc z_a+1
            bvc sg1
            eor #$80
sg1:
            asl                         ; the sign into the carry
            rts
slt:
            lda z_a
            cmp z_b
            lda z_a+1
            sbc z_b+1
            bvc sl1
            eor #$80
sl1:
            asl
            rts
done:
#endasm
End Sub

' the first enemy (not exploding, not gone, not a fighter being freed) within r of x, y (all in 1/16 pixels), or -1
Public Function Hit(ByVal x As Integer, ByVal y As Integer, ByVal r As Integer) As Integer
#asm
            NTC_POP z_p0
            ldy #0
            lda (z_p0),y
            sta z_a
            iny
            lda (z_p0),y
            sta z_a+1
            NTC_POP z_p0
            dey
            lda (z_p0),y
            sta z_b
            iny
            lda (z_p0),y
            sta z_b+1
            NTC_POP z_p0
            dey
            lda (z_p0),y
            sta z_c
            iny
            lda (z_p0),y
            sta z_c+1
            NTC_POP z_p2
            ldx #0
lp:
            lda {es},x
            beq nx
            cmp #6
            beq nx
            cmp #11                     ; a fighter being freed: yours, not a target
            beq nx
            sec                         ; |ex - x| < r
            lda {ex},x
            sbc z_a
            sta z_d
            lda {ex}+1,x
            sbc z_a+1
            bpl h1
            sta z_d+1
            sec
            lda #0
            sbc z_d
            sta z_d
            lda #0
            sbc z_d+1
h1:
            sta z_d+1
            lda z_d
            cmp z_c
            lda z_d+1
            sbc z_c+1
            bcs nx
            sec                         ; |ey - y| < r
            lda {ey},x
            sbc z_b
            sta z_d
            lda {ey}+1,x
            sbc z_b+1
            bpl h2
            sta z_d+1
            sec
            lda #0
            sbc z_d
            sta z_d
            lda #0
            sbc z_d+1
h2:
            sta z_d+1
            lda z_d
            cmp z_c
            lda z_d+1
            sbc z_c+1
            bcs nx
            txa                         ; found: its number
            lsr
            ldy #0
            sta (z_p2),y
            iny
            lda #0
            sta (z_p2),y
            jmp done
nx:
            inx
            inx
            cpx #88
            bcc lp
            ldy #0
            lda #$FF
            sta (z_p2),y
            iny
            sta (z_p2),y
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
