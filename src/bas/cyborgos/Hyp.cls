' Hyp: the bank side of CyborgOS (docs/cyborgos.md) - what goes into a task's 64K bank, and
' the switch into it and back.
'
' A task's bank (RAM setting C2: the whole 64K is the bank) holds a CP/M page zero, the program
' from #0100, a few stubs at STUB (#F600, also the BDOS address: the top of the TPA), its text
' page at #F700 (80 x 25, written by the hypervisor) and its saved SP at #FFFE:
'   #0000 jp exit        #0005 jp STUB (BDOS)      #0038 jp the interrupt save
'   #0044 out (c), c     #0046 jp the landing (ld sp, (#FFFE) : ret)
' Main RAM's #0040-#0048 is the same switch (the start code of every cpc / cpcmin / cpcfw
' program): each side pushes where it carries on, keeps its SP, loads BC with the other side's
' setting and jumps to #0044; the out flips the map and the next byte comes from the other
' side's own #0046. Only SP changes: A, DE and HL go through as they are (the messages).
'
' Run(setting) hands the CPU to a task until it calls the BDOS (call 5: a far call, Run gives
' 1, Fn = C, Arg = DE; the next Run answers with Reply's A and HL) or an interrupt stops it
' (Run gives 0; the firmware's interrupt handler is then run for it here in main RAM).
Option Explicit
Public Const STUB = &HF500
Public Const OBUF = &HF600         ' a program's characters out, collected (128), OBUF + 128 their count
Public Const KEY = &HF681          ' the slot's next key (0 none): the bank's BDOS answers 1, 6 and 11 from it
Private sps As Integer, ra As Integer, rhl As Integer, rfn As Integer, rde As Integer, rcnt As Integer
Private slc As Integer, hsp As Integer, rclr As Integer, rrom As Integer
Private font(767) As Byte          ' the matrices of characters 32-127 (FontInit), for Text
Const SLICE = 6                    ' interrupts in a task's time slice (6: 1/50 s)

' Setting(): the gate array's RAM setting (B = port, C = value) as C2 for the bank whose page
' is in the window now (Memory.SelectPage of one of its pages first)
Public Function Setting() As Integer
#asm
            ld de, (ntc_rampt)
            ld a, e
            and #F8
            or 2
            ld e, a
            pop hl
            ld (hl), e
            inc hl
            ld (hl), d
#endasm
End Function

' FarPtr(page, address): the Memory class's far pointer to the address (its low 14 bits) in
' that page: page * 65536 + #4000 + (address And #3FFF)
Public Function FarPtr(ByVal page As Integer, ByVal address As Integer) As Long
#asm
            pop hl
            ld c, (hl)
            inc hl
            ld b, (hl)              ; BC = page
            pop hl
            ld e, (hl)
            inc hl
            ld a, (hl)
            and #3F
            or #40
            ld d, a                 ; DE = #4000 + the address's low 14 bits
            pop hl
            ld (hl), e
            inc hl
            ld (hl), d
            inc hl
            ld (hl), c
            inc hl
            ld (hl), b
#endasm
End Function

' Printable(p, n): how many of the n bytes at p (main RAM) come before the first control code
' (below 32) - the run Out writes at once
Public Function Printable(ByVal p As Integer, ByVal n As Integer) As Integer
#asm
            ld hl, ({p})
            ld bc, ({n})
            ld de, 0
pr_lp:
            ld a, b
            or c
            jr z, pr_end
            ld a, (hl)
            cp 32
            jr c, pr_end
            inc hl
            inc de
            dec bc
            jr pr_lp
pr_end:
            ld ({result}), de
#endasm
End Function

' FontInit(): the firmware's character matrices 32-127 copied to RAM (once, after Mode 2), for
' Text. TXT SET M TABLE copies them into a table (the 2K buffer, free then); 96 are kept and the
' firmware goes back to its own (the lower ROM can't be switched in here: this code may be below #4000)
Public Sub FontInit()
#asm
            ld ({hsp}), sp
            ld sp, (ntc_csp)
            ld de, 32               ; D = 0: a table, E = its first character
            ld hl, #4000
            call #BBAB              ; TXT SET M TABLE (the matrices from 32 on, copied there)
            di
            ld hl, #4000
            ld de, {font}
            ld bc, 96 * 8
            ldir
            ld de, #FF00            ; D <> 0: no table of its own any more
            call #BBAB
            di
            ld sp, ({hsp})
#endasm
End Sub

' Text(p, n, col, row): the n characters at p (main RAM) on the screen from col, row (0-based),
' written straight into screen memory in mode 2 (pen 1 on paper 0) - the firmware's text
' output is far slower. Each character's place comes from SCR CHAR POSITION (it follows the
' hardware scroll). Nothing past column 79; the firmware's cursor is left where it was
Public Sub Text(ByVal p As Integer, ByVal n As Integer, ByVal col As Integer, ByVal row As Integer)
#asm
            ld ({hsp}), sp
            ld sp, (ntc_csp)
            ld hl, ({p})
            ld a, ({n})
            ld b, a
            ld a, ({col})
            ld d, a
            ld a, ({row})
            ld e, a
            call hy_text
            ld sp, ({hsp})
            jr hy_end
; hy_text: B characters at HL to the screen from column D, row E (called on the real stack)
hy_text:
            ld a, b
            or a
            ret z
hy_tx_lp:
            ld a, d
            cp 80
            ret nc
            push bc
            push de
            ld a, (hl)
            inc hl
            push hl
            sub 32
            cp 96
            jr c, hy_tx_ok
            ld a, '?' - 32
hy_tx_ok:
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            ld bc, {font}
            add hl, bc
            push hl                 ; the character's matrix
            ld h, d
            ld l, e
            call #BC1A              ; SCR CHAR POSITION: HL = its screen address
            di                      ; (firmware calls come back with interrupts on: the thread
                                    ; must not get an interrupt pushed into it)
            pop de
            ld b, 8
hy_tx_ln:
            ld a, (de)
            ld (hl), a
            inc de
            ld a, h
            add a, 8
            ld h, a
            djnz hy_tx_ln
            pop hl
            pop de
            pop bc
            inc d
            djnz hy_tx_lp
            ret
hy_end:
#endasm
End Sub

' Char(c, col, row): one character, as Text
Public Sub Char(ByVal c As Integer, ByVal col As Integer, ByVal row As Integer)
  Text VarPtr(c), 1, col, row
End Sub

' Reply a, hl: what the task's BDOS call gives back at the next Run
Public Sub Reply(ByVal a As Integer, ByVal hl As Integer)
  ra = a : rhl = hl
End Sub

Public Function Fn() As Integer
  Fn = rfn And 255
End Function

Public Function Arg() As Integer
  Arg = rde
End Function

' Count(): how many characters the program had collected at OBUF when it gave the CPU back
Public Function Count() As Integer
  Count = rcnt
End Function

' Run(setting): the task in that bank runs until a BDOS call (1) or an interrupt (0)
Public Function Run(ByVal setting As Integer) As Integer
#asm
            ld ({sps}), sp
            ld sp, (ntc_csp)
            call #B903              ; KL U ROM DISABLE: the task's top 16K, not a ROM (Library:
            di                      ; ROM has the keyword ROM on), while it runs
            ld ({rrom}), a
            ld a, {SLICE}
            ld ({slc}), a
            ld a, 1                 ; from BASIC: it has taken the characters (Collected)
            ld ({rclr}), a
rn_again:
            push ix                 ; IX, IY and
            push iy
            db #08                  ; ex af, af': the alternate registers kept - the
            exx                     ; firmware's (BC' = its ROM / mode setting); a task
            push af                 ; may use them
            push bc
            push de
            push hl
            exx
            db #08
            ld hl, rn_back
            push hl                 ; where main RAM carries on
            ld (ntc_bk_sp), sp
            ld a, ({rclr})
            ld e, a                 ; E = 1: the bank empties its characters out (BASIC has them)
            ld a, ({ra})
            ld hl, ({rhl})
            ld bc, ({setting})
            jp ntc_bk_out           ; out (c), c: the task's bank; its #0046 lands it
rn_back:
            ld ({rcnt}), ix         ; the characters it collected (the stubs put them in IX)
            db #08                  ; ex af, af'
            exx
            pop hl                  ; the alternate registers back
            pop de
            pop bc
            pop af
            exx
            db #08
            pop iy
            pop ix
            push af                 ; carry: a BDOS call (A = C, DE = DE)
            push bc
            ld bc, (ntc_rampt)      ; the window's page back
            out (c), c
            pop bc
            pop af
            jr c, rn_far
            rst #38                 ; an interrupt stopped the task: the firmware's handler
            di
            ld hl, {slc}            ; a time slice is SLICE interrupts: until it is used up the
            dec (hl)                ; task carries on straight away (no trip through BASIC)
            jr z, rn_int
            ld a, (ntc_isldue)      ; ... unless an interrupt class (the system keys) is due
            or a
            jr nz, rn_int
            xor a                   ; its characters stay in its bank (and the count goes on)
            ld ({rclr}), a
            jp rn_again
rn_int:
            ld hl, 0
            jr rn_end
rn_far:
            ld ({rfn}), a
            ld ({rde}), de
            ld hl, 1
rn_end:
            ld ({result}), hl
            ld a, ({rrom})
            call #B90C              ; KL ROM RESTORE
            di
            ld sp, ({sps})

#endasm
End Function

' Info(n): the bank image - 0 the page zero part's address, 1 its length, 2 the stubs'
' address, 3 their length (copied to STUB)
Public Function Info(ByVal n As Integer) As Integer
#asm
            pop hl
            ld a, (hl)
            ld hl, hi_p0
            or a
            jr z, in_e
            ld hl, hi_p0e - hi_p0
            dec a
            jr z, in_e
            ld hl, sb_start
            dec a
            jr z, in_e
            ld hl, sb_end - sb_start
in_e:
            ex de, hl
            pop hl
            ld (hl), e
            inc hl
            ld (hl), d
            ret
; page zero (#0000-#0080)
hi_p0:
            db #C3
            dw {STUB} + (sb_exit - sb_start)    ; #0000: warm boot = the task ends
            db 0, 0
            db #C3
            dw {STUB}                           ; #0005: BDOS (#0006: the top of the TPA)
            ds #38 - 8
            db #C3
            dw {STUB} + (sb_int - sb_start)     ; #0038: the interrupt
            ds #44 - #3B
            db #ED, #49                         ; #0044: out (c), c
            db #C3
            dw {STUB} + (sb_land - sb_start)    ; #0046: this bank switched in
            ds #5C - #49
            db 0, "           "                 ; #005C: the default FCB
            ds #80 - #68
            db 0                                ; #0080: no command tail
hi_p0e:
; the stubs: assembled here, run at STUB in the bank (jumps inside them are to STUB + offset).
; Characters out (BDOS 2, 6 with E < #FE) are collected at OBUF with no switch; the hypervisor
; gets them (IX = how many) at the next far call or interrupt, at a line end, or when 128 wait
sb_start:
            di                                  ; BDOS: C = function, DE = argument
            ld a, c
            cp 2
            jr z, sb_put
            cp 6
            jr z, sb_f6
            cp 11
            jr z, sb_stat
            cp 1
            jr z, sb_f1
            jr sb_call
sb_f6:
            ld a, e
            cp #FF
            jr z, sb_get
            cp #FE
            jr c, sb_put
; keys: the hypervisor leaves the slot's next key at KEY (0 none), so these never switch
sb_stat:
            ld a, ({KEY})                       ; 6 / #FE, 11: is a key waiting (#FF / 0)
            or a
            jr z, sb_ret
            ld a, #FF
sb_ret:
            ld l, a
            ld h, 0
            ei
            ret
sb_get:
            ld hl, {KEY}                        ; 6 / #FF: the key or 0
            ld a, (hl)
            ld (hl), 0
            jr sb_ret
sb_f1:
            ld hl, {KEY}                        ; 1: the key (echoed) or 0
            ld a, (hl)
            or a
            jr z, sb_ret
            ld (hl), 0
            ld e, a
            ld hl, {OBUF} + 128                 ; the echo, collected (not when full)
            ld a, (hl)
            cp 127
            ld a, e
            jr nc, sb_ret
            inc (hl)
            ld l, (hl)
            dec l
            ld h, {OBUF} / 256
            ld (hl), a
            jr sb_ret
sb_put:
            ld hl, {OBUF} + 128                 ; the count
            ld a, (hl)
            inc (hl)
            ld l, a
            ld h, {OBUF} / 256
            ld (hl), e
            cp 127
            jr nc, sb_flush                     ; full
            ld a, e
            cp 10
            jr z, sb_flush                      ; a line end: shown now
            ei
            ret
sb_flush:
            ld c, #80                           ; (function #80: only the characters)
sb_call:
            push ix                             ; IX, IY and the alternate registers kept
            push iy                             ; over the call (ex af, af')
            db #08
            exx
            push af
            push bc
            push de
            push hl
            exx
            db #08
            ld a, ({OBUF} + 128)
            ld ixl, a
            ld ixh, 0
            ld a, c
            ld hl, {STUB} + (sb_far - sb_start)
            push hl
            ld (#FFFE), sp
            ld bc, #7FC0
            scf                                 ; carry: a far call
            jp #0044
sb_far:
            db #08                              ; the answer in A and HL; the program's
            exx                                 ; other registers back
            pop hl
            pop de
            pop bc
            pop af
            exx
            db #08
            pop iy
            pop ix
            ei
            ret
sb_int:
            push af                             ; an interrupt: everything kept
            push bc
            push de
            push hl
            db #08                              ; ex af, af'
            exx
            push af
            push bc
            push de
            push hl
            push ix
            push iy
            ld a, ({OBUF} + 128)
            ld ixl, a
            ld ixh, 0
            ld hl, {STUB} + (sb_rest - sb_start)
            push hl
            ld (#FFFE), sp
            ld bc, #7FC0
            or a                                ; no carry: an interrupt
            jp #0044
sb_rest:
            pop iy
            pop ix
            pop hl
            pop de
            pop bc
            pop af
            exx
            db #08                              ; ex af, af'
            pop hl
            pop de
            pop bc
            pop af
            ei
            ret
sb_land:
            ld sp, (#FFFE)                      ; this bank's SP
            push af
            ld a, e                             ; E = 1: the hypervisor has the characters
            or a
            jr z, sb_lkeep
            xor a
            ld ({OBUF} + 128), a
sb_lkeep:
            pop af
            ret
sb_exit:
            ld c, 0
            jp {STUB}
sb_end:
            ASSERT sb_end - sb_start <= 256, "the bank stubs must fit below OBUF"

#endasm
End Function
