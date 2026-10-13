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
Public Const STUB = &HF600
Private sps As Integer, ra As Integer, rhl As Integer, rfn As Integer, rde As Integer

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

' Run(setting): the task in that bank runs until a BDOS call (1) or an interrupt (0)
Public Function Run(ByVal setting As Integer) As Integer
#asm
            ld ({sps}), sp
            ld sp, (ntc_csp)
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
            ld a, ({ra})
            ld hl, ({rhl})
            ld bc, ({setting})
            jp ntc_bk_out           ; out (c), c: the task's bank; its #0046 lands it
rn_back:
            db #08                  ; ex af, af'
            exx
            pop hl                  ; the alternate registers back
            pop de
            pop bc
            pop af
            exx
            db #08
            push af                 ; carry: a BDOS call (A = C, DE = DE)
            push bc
            ld bc, (ntc_rampt)      ; the window's page back
            out (c), c
            pop bc
            pop af
            jr c, rn_far
            rst #38                 ; an interrupt stopped the task: the firmware's handler
            di
            ld hl, 0
            jr rn_end
rn_far:
            ld ({rfn}), a
            ld ({rde}), de
            ld hl, 1
rn_end:
            ld ({result}), hl
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
; the stubs: assembled here, run at STUB in the bank (jumps inside them are to STUB + offset)
sb_start:
            di                                  ; BDOS: C = function, DE = argument
            ld a, c
            ld hl, {STUB} + (sb_far - sb_start)
            push hl
            ld (#FFFE), sp
            ld bc, #7FC0
            scf                                 ; carry: a far call
            jp #0044
sb_far:
            ret                                 ; the answer in A and HL
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
            ret
sb_exit:
            ld c, 0
            jp {STUB}
sb_end:
#endasm
End Function
