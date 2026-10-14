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
Private en(11) As Byte             ' EntSet: a name as CP/M has it (8 + 3, spaces after); en(11): 1 = .COM
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
' ---- replaced by Con (kept for comparison): Printable found the run of printable characters
' for Main's Out, which then still did a Memory.Copy and a Print / Text per run
'| ' Printable(p, n): how many of the n bytes at p (main RAM) come before the first control code
'| ' (below 32) - the run Out writes at once
'| Public Function Printable(ByVal p As Integer, ByVal n As Integer) As Integer
'| #asm
'|             ld hl, ({p})
'|             ld bc, ({n})
'|             ld de, 0
'| pr_lp:
'|             ld a, b
'|             or c
'|             jr z, pr_end
'|             ld a, (hl)
'|             cp 32
'|             jr c, pr_end
'|             inc hl
'|             inc de
'|             dec bc
'|             jr pr_lp
'| pr_end:
'|             ld ({result}), de
'| #endasm
'| End Function

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
' ---- replaced by Con (kept for comparison): Text and Char drew characters for Main's Out /
' PutC / ToFront, one call (with its BASIC around it) per run or per character
'| ' Text(p, n, col, row): the n characters at p (main RAM) on the screen from col, row (0-based),
'| ' written straight into screen memory in mode 2 (pen 1 on paper 0) - the firmware's text
'| ' output is far slower. Each character's place comes from SCR CHAR POSITION (it follows the
'| ' hardware scroll). Nothing past column 79; the firmware's cursor is left where it was
'| Public Sub Text(ByVal p As Integer, ByVal n As Integer, ByVal col As Integer, ByVal row As Integer)
'| #asm
'|             ld ({hsp}), sp
'|             ld sp, (ntc_csp)
'|             ld hl, ({p})
'|             ld a, ({n})
'|             ld b, a
'|             ld a, ({col})
'|             ld d, a
'|             ld a, ({row})
'|             ld e, a
'|             call hy_text
'|             ld sp, ({hsp})
'|             jr hy_end
'| ; hy_text: B characters at HL to the screen from column D, row E (called on the real stack)
'| hy_text:
'|             ld a, b
'|             or a
'|             ret z
'| hy_tx_lp:
'|             ld a, d
'|             cp 80
'|             ret nc
'|             push bc
'|             push de
'|             ld a, (hl)
'|             inc hl
'|             push hl
'|             sub 32
'|             cp 96
'|             jr c, hy_tx_ok
'|             ld a, '?' - 32
'| hy_tx_ok:
'|             ld l, a
'|             ld h, 0
'|             add hl, hl
'|             add hl, hl
'|             add hl, hl
'|             ld bc, {font}
'|             add hl, bc
'|             push hl                 ; the character's matrix
'|             ld h, d
'|             ld l, e
'|             call #BC1A              ; SCR CHAR POSITION: HL = its screen address
'|             di                      ; (firmware calls come back with interrupts on: the thread
'|                                     ; must not get an interrupt pushed into it)
'|             pop de
'|             ld b, 8
'| hy_tx_ln:
'|             ld a, (de)
'|             ld (hl), a
'|             inc de
'|             ld a, h
'|             add a, 8
'|             ld h, a
'|             djnz hy_tx_ln
'|             pop hl
'|             pop de
'|             pop bc
'|             inc d
'|             djnz hy_tx_lp
'|             ret
'| hy_end:
'| #endasm
'| End Sub
'| 
'| ' Char(c, col, row): one character, as Text
'| Public Sub Char(ByVal c As Integer, ByVal col As Integer, ByVal row As Integer)
'|   Text VarPtr(c), 1, col, row
'| End Sub

' ---- the console, in Z80: it runs for every character a program prints, so it is not BASIC.
' Con(pg, src, n, front): n characters to a slot's console, with its page 3 (#C000-#FFFF of its
' bank) in the window - pg is that RAM setting (bank C2 setting with layout 7: #C7 + bank * 8).
' src: the characters in main RAM, or 0 for the ones the program collected at OBUF in its bank.
' front <> 0: the slot is on the screen, so each character is also drawn there.
' n < 0: no characters - the whole page drawn on the screen (a slot brought to the front).
' The slot's console state is in its bank (#F682: column, row, top row of the page ring, escape
' state, escape row), so nothing about it passes through BASIC. Handles CR, LF, BS and the VT52
' codes ESC E (clear), ESC H (home), ESC Y row col (move); the page is a ring of 25 rows (a
' scroll moves its top row and clears one row); the screen scrolls through the firmware (it
' scrolls when a character goes below the last line). The window's page is put back at the end.
' Why Z80: this was Main.bas's Collected / Out / PutC / NewLine / RowA / ClsT / PutMem / ToFront
' - per line about 4 Memory calls (each one turning Long far pointers into a page and an
' address and switching pages in and out), several hundred keywords and a safe point at every
' branch: about 200,000 T a line. Here the page is switched in once and each character costs a
' few hundred T (most of it the 8 screen bytes and SCR CHAR POSITION).
Public Sub Con(ByVal pg As Integer, ByVal src As Integer, ByVal n As Integer, ByVal front As Integer)
#asm
            ld ({hsp}), sp
            ld sp, (ntc_csp)
            ld bc, ({pg})
            out (c), c              ; the slot's page 3 at #4000: OBUF #7600, state #7682, page #7700
            xor a
            ld (cn_pv), a
            ld a, ({front})
            ld (cn_front), a
            or a
            call nz, cn_loc         ; in front: where the screen starts now (hardware scroll)
            ld hl, ({n})
            bit 7, h
            jp nz, cn_show
            ld (cn_left), hl
            ld hl, ({src})
            ld a, h
            or l
            jr nz, cn_src
            ld hl, #7600            ; src 0: the characters the program collected (OBUF)
cn_src:
            ld (cn_ptr), hl
cn_lp:
            ld hl, (cn_left)
            ld a, h
            or l
            jr z, cn_done
            dec hl
            ld (cn_left), hl
            ld hl, (cn_ptr)
            ld a, (hl)
            inc hl
            ld (cn_ptr), hl
            call cn_char
            jr cn_lp
cn_done:
            ld bc, (ntc_rampt)      ; the window's page back
            out (c), c
            ld sp, ({hsp})
            jp cn_end

; the whole page to the screen (it was cleared): every character that isn't a space
cn_show:
            ld e, 0
cn_sh_row:
            push de
            ld a, e
            call cn_rowa            ; HL = row e of the page
            pop de
            ld d, 0
cn_sh_col:
            ld a, (hl)
            inc hl
            cp 33
            jr c, cn_sh_skip
            push hl
            push de
            call cn_glyph
            pop de
            pop hl
cn_sh_skip:
            inc d
            ld a, d
            cp 80
            jr c, cn_sh_col
            inc e
            ld a, e
            cp 25
            jr c, cn_sh_row
            jr cn_done

; cn_char: A = one character
cn_char:
            ld b, a
            ld a, (#7685)           ; in an escape sequence?
            or a
            jr nz, cn_esc0
            ld a, b
            cp 32
            jp nc, cn_print
            ld hl, cn_pv            ; a control code: the cursor may move (the pointers redone)
            ld (hl), 0
            cp 27
            jr z, cn_setesc
            cp 13
            jr z, cn_cr
            cp 10
            jp z, cn_nl
            cp 8
            ret nz                  ; other control codes: nothing
            ld a, (#7682)           ; BS: back one (not past the start of the row)
            or a
            ret z
            dec a
            ld (#7682), a
            ret
cn_setesc:
            ld a, 1
            ld (#7685), a
            ret
cn_cr:
            xor a
            ld (#7682), a
            ret
cn_esc0:
            ld hl, cn_pv
            ld (hl), 0
cn_esc:
            cp 1
            jr nz, cn_esc2
            xor a                   ; ESC x
            ld (#7685), a
            ld a, b
            cp 'E'
            jp z, cn_clear
            cp 'H'
            jr z, cn_home
            cp 'Y'
            ret nz
            ld a, 2
            ld (#7685), a
            ret
cn_home:
            xor a
            ld (#7682), a
            ld (#7683), a
            ret
cn_esc2:
            cp 2
            jr nz, cn_esc3
            ld a, b                 ; ESC Y row
            sub 32
            ld (#7686), a
            ld a, 3
            ld (#7685), a
            ret
cn_esc3:
            xor a                   ; ESC Y row col
            ld (#7685), a
            ld a, b
            sub 32
            cp 80
            jr c, cn_e3_col
            xor a
cn_e3_col:
            ld (#7682), a
            ld a, (#7686)
            cp 25
            jr c, cn_e3_row
            xor a
cn_e3_row:
            ld (#7683), a
            ret

; a printable character (B): into the page, on the screen if in front, the column on. The page
; and screen pointers are worked out at the first character after the cursor moved (cn_pv 0),
; then just stepped on - a run of characters costs the 8 screen bytes each, not a sum each
cn_print:
            ld a, (cn_pv)
            or a
            jr nz, cn_pr_have
            ld a, (#7683)
            call cn_rowa
            ld a, (#7682)
            ld e, a
            ld d, 0
            add hl, de
            ld (cn_pp), hl
            ld a, (cn_front)
            or a
            jr z, cn_pr_set
            ld a, (#7682)
            ld d, a
            ld a, (#7683)
            ld e, a
            push bc                 ; (B: the character)
            call cn_scr
            pop bc
            ld (cn_sp), hl
cn_pr_set:
            ld a, 1
            ld (cn_pv), a
cn_pr_have:
            ld hl, (cn_pp)          ; the page
            ld (hl), b
            inc hl
            ld (cn_pp), hl
            ld a, (cn_front)
            or a
            jr z, cn_pr_adv
            ld hl, (cn_sp)          ; the screen
            push hl
            ld a, b
            call cn_glyph8
            pop hl
            ld a, l                 ; the next column: + 1 within the 2K line block
            add a, 1
            ld l, a
            ld a, h
            adc a, 0
            and #07
            ld c, a
            ld a, h
            and #F8
            or c
            ld h, a
            ld (cn_sp), hl
cn_pr_adv:
            ld hl, #7682
            inc (hl)
            ld a, (hl)
            cp 80
            ret c
            ld (hl), 0              ; past the last column: the next row
            xor a
            ld (cn_pv), a
; a line feed: the next row, or the page (and the screen) scroll
cn_nl:
            ld hl, #7683
            ld a, (hl)
            inc a
            cp 25
            jr nc, cn_scroll
            ld (hl), a
            ret
cn_scroll:
            ld a, (#7684)           ; the ring's top row moves on (no copy)
            inc a
            cp 25
            jr c, cn_sc_top
            xor a
cn_sc_top:
            ld (#7684), a
            ld a, 24
            call cn_rowa            ; the new last row cleared
            ld b, 80
cn_sc_cl:
            ld (hl), ' '
            inc hl
            djnz cn_sc_cl
            ld a, (cn_front)
            or a
            ret z
            ld b, 1                 ; the screen: SCR HW ROLL up, the new line in paper ink 0 -
            xor a                   ; one firmware call (it was 4 TXT calls: set the cursor, CR,
            call #BC4D              ; LF and a space, as the firmware scrolls only at a character
            di                      ; below the last line); firmware calls come back with ei
            jp cn_loc               ; the screen's start moved

; ESC E: the page cleared, column, row and ring back to 0; the screen too if in front
cn_clear:
            ld hl, #7700
            ld de, #7701
            ld (hl), ' '
            ld bc, 25 * 80 - 1
            ldir
            xor a
            ld (#7682), a
            ld (#7683), a
            ld (#7684), a
            ld a, (cn_front)
            or a
            ret z
            call #BB6C              ; TXT CLEAR WINDOW
            di
            jp cn_loc

; cn_rowa: A = row 0-24 of the screen -> HL = its row in the page ring (#7700 + ((top + A) mod 25) * 80)
cn_rowa:
            ld hl, #7684
            add a, (hl)
            cp 25
            jr c, cn_ra_in
            sub 25
cn_ra_in:
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl              ; * 16
            ld d, h
            ld e, l
            add hl, hl
            add hl, hl              ; * 64
            add hl, de              ; * 80
            ld de, #7700
            add hl, de
            ret

; cn_glyph: A = character, D = column, E = row: drawn (cn_show)
cn_glyph:
            push af
            call cn_scr
            pop af
; cn_glyph8: A = character, HL = its screen address: its 8 bytes into screen memory (mode 2, pen
; 1 on paper 0), one per pixel line (#800 apart; unrolled)
cn_glyph8:
            sub 32
            cp 96
            jr c, cn_gl_ok
            ld a, '?' - 32
cn_gl_ok:
            push hl
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, {font}
            add hl, de
            ex de, hl               ; DE = its matrix
            pop hl
            ld a, (de)
            ld (hl), a
            inc de
            ld a, h
            add a, 8
            ld h, a
            ld a, (de)
            ld (hl), a
            inc de
            ld a, h
            add a, 8
            ld h, a
            ld a, (de)
            ld (hl), a
            inc de
            ld a, h
            add a, 8
            ld h, a
            ld a, (de)
            ld (hl), a
            inc de
            ld a, h
            add a, 8
            ld h, a
            ld a, (de)
            ld (hl), a
            inc de
            ld a, h
            add a, 8
            ld h, a
            ld a, (de)
            ld (hl), a
            inc de
            ld a, h
            add a, 8
            ld h, a
            ld a, (de)
            ld (hl), a
            inc de
            ld a, h
            add a, 8
            ld h, a
            ld a, (de)
            ld (hl), a
            ret
; cn_scr: D = column, E = row -> HL = the screen address: the screen's start (cn_off) + row * 80
; + column, within each 2K line block, at #C000 (it was SCR CHAR POSITION for every character:
; a firmware call through the jumpblock and the lower ROM)
cn_scr:
            ld l, e
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl              ; row * 16
            push hl
            add hl, hl
            add hl, hl              ; * 64
            pop bc
            add hl, bc              ; * 80
            ld c, d
            ld b, 0
            add hl, bc
            ld bc, (cn_off)
            add hl, bc
            ld a, h
            and #07
            ld b, a
            ld a, (cn_base)
            or b
            ld h, a
            ret
; cn_loc: the screen's start (SCR GET LOCATION: A = its base, HL = its offset)
cn_loc:
            call #BC0B
            di
            ld (cn_base), a
            ld (cn_off), hl
            ret
cn_front:   db 0
cn_pv:      db 0                    ; cn_pp / cn_sp valid (0: the cursor moved)
cn_pp:      dw 0                    ; the page byte for the next character
cn_sp:      dw 0                    ; its screen address
cn_base:    db #C0
cn_off:     dw 0
cn_left:    dw 0
cn_ptr:     dw 0
cn_end:
#endasm
End Sub

' Say(p, n, col, row): n characters at p (main RAM) straight onto the screen from col, row
' (0-based) - no slot's page, no cursor (the TOP screen). Why Z80: TOP printed through the
' firmware (TXT OUTPUT, about 1,000 characters a second) took most of a second to appear.
Public Sub Say(ByVal p As Integer, ByVal n As Integer, ByVal col As Integer, ByVal row As Integer)
#asm
            ld ({hsp}), sp
            ld sp, (ntc_csp)
            call #BC0B              ; SCR GET LOCATION: A = the screen's base, HL = its offset
            di
            ld (sy_base), a
            ld (sy_off), hl
            ld hl, ({p})
            ld a, ({n})
            ld b, a
            ld a, ({col})
            ld d, a
            ld a, ({row})
            ld e, a
            inc b
sy_lp:
            dec b
            jr z, sy_done
            ld a, d
            cp 80
            jr nc, sy_done
            ld a, (hl)
            inc hl
            push hl
            push bc
            push de
            sub 32                  ; the character's matrix
            cp 96
            jr c, sy_ok
            ld a, '?' - 32
sy_ok:
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            ld bc, {font}
            add hl, bc
            push hl
            ld l, e                 ; its screen address: start + row * 80 + column, in 2K
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            push hl
            add hl, hl
            add hl, hl
            pop bc
            add hl, bc
            ld c, d
            ld b, 0
            add hl, bc
            ld bc, (sy_off)
            add hl, bc
            ld a, h
            and #07
            ld b, a
            ld a, (sy_base)
            or b
            ld h, a
            pop de
            ld b, 8
sy_ln:
            ld a, (de)
            ld (hl), a
            inc de
            ld a, h
            add a, 8
            ld h, a
            djnz sy_ln
            pop de
            pop bc
            pop hl
            inc d
            jr sy_lp
sy_done:
            ld sp, ({hsp})
            jr sy_end
sy_base:    db #C0
sy_off:     dw 0
sy_end:
#endasm
End Sub

' Show(pg): the slot's whole page on the (cleared) screen
Public Sub Show(ByVal pg As Integer)
  Con pg, 0, -1, 1
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
;           ld a, e                             ; (was: a line end shown at once - a trip
;           cp 10                               ; through the hypervisor's BASIC for every
;           jr z, sb_flush                      ; line; now at the end of the time slice, 1/50 s)
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

' ---- FILES.DIR / name.HDR entries (64 bytes; the layout: Main.bas, StartTask). In Z80 code:
' the BASIC for this (Cpm, EntOk, EntName, EntLong ... ) made CyborgOS 3K bigger - too big for
' the RAM below AMSDOS's

' EntSet(p, n): the name at p (n characters, capitals: NAME or NAME.EXT; no extension = .COM)
' made 8 + 3, for EntIs and EntMake
Public Sub EntSet(ByVal p As Integer, ByVal n As Integer)
#asm
            ld hl, {en}
            ld b, 11
es_sp:
            ld (hl), ' '
            inc hl
            djnz es_sp
            ld (hl), 0              ; en(11): .COM?
            ld hl, ({p})
            ld a, ({n})
            ld c, a
            ld de, {en}
            ld b, 8
es_nm:
            ld a, c                 ; the name: up to "." (8 characters at most kept)
            or a
            jr z, es_noext
            ld a, (hl)
            inc hl
            dec c
            cp '.'
            jr z, es_ext
            inc b
            dec b
            jr z, es_nm
            ld (de), a
            inc de
            dec b
            jr es_nm
es_noext:
            ld hl, es_com
            ld c, 3
es_ext:
            ld de, {en} + 8
            ld b, 3
es_ex:
            ld a, c
            or a
            jr z, es_chk
            ld a, (hl)
            ld (de), a
            inc hl
            inc de
            dec c
            djnz es_ex
es_chk:
            ld hl, {en} + 8
            ld de, es_com
            ld b, 3
es_ck:
            ld a, (de)
            cp (hl)
            jr nz, es_done
            inc hl
            inc de
            djnz es_ck
            ld a, 1
            ld ({en} + 11), a
            jr es_done
es_com:     db "COM"
es_done:
#endasm
End Sub

' EntIs(p, s, n): the entry at p is a good one (kind 1, a CP/M .COM that runs here, its sum
' right, #F400 bytes at most) for EntSet's name, or with the long name at s (n characters): its
' length, else 0
Public Function EntIs(ByVal p As Integer, ByVal s As Integer, ByVal n As Integer) As Integer
#asm
            ld hl, 0
            ld ({result}), hl
            ld hl, ({p})
            ld a, (hl)
            dec a
            jr nz, ei_done          ; not a file
            ld de, 12
            add hl, de
            ld a, (hl)
            dec a
            jr nz, ei_done          ; not a CP/M .COM
            inc hl
            bit 0, (hl)
            jr z, ei_done           ; not to run here
            ld hl, ({p})            ; the sum of bytes 0-61 = bytes 62-63
            ld de, 0
            ld b, 62
ei_sum:
            ld a, (hl)
            add a, e
            ld e, a
            jr nc, ei_s1
            inc d
ei_s1:
            inc hl
            djnz ei_sum
            ld a, (hl)
            cp e
            jr nz, ei_done
            inc hl
            ld a, (hl)
            cp d
            jr nz, ei_done
            ld hl, ({p})            ; the disc name
            inc hl
            ld de, {en}
            ld b, 11
ei_nm:
            ld a, (de)
            cp (hl)
            jr nz, ei_long
            inc hl
            inc de
            djnz ei_nm
            jr ei_yes
ei_long:
            ld a, ({n})             ; the long name: n characters, then a 0 (or all 38)
            or a
            jr z, ei_done
            cp 39
            jr nc, ei_done
            ld b, a
            ld hl, ({p})
            ld de, 24
            add hl, de
            ld de, ({s})
ei_ln:
            ld a, (de)
            cp (hl)
            jr nz, ei_done
            inc hl
            inc de
            djnz ei_ln
            ld a, ({n})
            cp 38
            jr z, ei_yes
            ld a, (hl)
            or a
            jr nz, ei_done
ei_yes:
            ld hl, ({p})
            ld de, 14
            add hl, de
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld hl, #F400            ; more than #0100-#F4FF: not used
            or a
            sbc hl, de
            jr c, ei_done
            ld ({result}), de
ei_done:
#endasm
End Function

' EntMake(p, s, n, size): the entry at p made for EntSet's name: a file, CP/M .COM (when it is
' one), runs here, size bytes, loaded and run at #0100, long name at s (n characters, 38 kept)
Public Sub EntMake(ByVal p As Integer, ByVal s As Integer, ByVal n As Integer, ByVal size As Integer)
#asm
            ld hl, ({p})
            ld b, 64
em_z:
            ld (hl), 0
            inc hl
            djnz em_z
            ld hl, ({p})
            ld (hl), 1              ; a file
            inc hl
            ex de, hl
            ld hl, {en}
            ld bc, 11
            ldir                    ; its disc name
            ld a, ({en} + 11)
            ld (de), a              ; 12: a CP/M .COM
            inc de
            ld a, 1
            ld (de), a              ; 13: runs here
            inc de
            ld hl, ({size})
            ex de, hl
            ld (hl), e              ; 14-15: its length
            inc hl
            ld (hl), d
            inc hl
            inc hl
            ld (hl), 1              ; 16-17: load at #0100
            inc hl
            inc hl
            ld (hl), 1              ; 18-19: run at #0100
            ld hl, ({p})
            ld de, 24
            add hl, de
            ex de, hl
            ld a, ({n})
            cp 39
            jr c, em_ln
            ld a, 38
em_ln:
            or a
            jr z, em_sum
            ld c, a
            ld b, 0
            ld hl, ({s})
            ldir                    ; 24-61: its long name
em_sum:
            ld hl, ({p})
            ld de, 0
            ld b, 62
em_s:
            ld a, (hl)
            add a, e
            ld e, a
            jr nc, em_s1
            inc d
em_s1:
            inc hl
            djnz em_s
            ld (hl), e              ; 62-63: the sum of 0-61
            inc hl
            ld (hl), d
#endasm
End Sub

' EntDisc(p, d): the entry at p's disc name written at d as NAME.EXT: its length
Public Function EntDisc(ByVal p As Integer, ByVal d As Integer) As Integer
#asm
            ld hl, ({p})
            inc hl
            ld de, ({d})
            ld bc, #0800            ; B: 8 name characters, C: the count
ed_nm:
            ld a, (hl)
            inc hl
            cp ' ' + 1
            jr c, ed_n1
            ld (de), a
            inc de
            inc c
ed_n1:
            djnz ed_nm
            ld a, (hl)
            cp ' ' + 1
            jr c, ed_done
            ld a, '.'
            ld (de), a
            inc de
            inc c
            ld b, 3
ed_ex:
            ld a, (hl)
            inc hl
            cp ' ' + 1
            jr c, ed_e1
            ld (de), a
            inc de
            inc c
ed_e1:
            djnz ed_ex
ed_done:
            ld l, c
            ld h, 0
            ld ({result}), hl
#endasm
End Function

' EntAt(p, m): where in the m bytes of entries at p one has EntSet's disc name (0, 64 ...), or m
Public Function EntAt(ByVal p As Integer, ByVal m As Integer) As Integer
#asm
            ld bc, 0                ; the offset
ea_lp:
            ld hl, ({m})
            or a
            sbc hl, bc
            jr z, ea_done           ; none
            ld hl, ({p})            ; this entry's disc name
            inc hl
            ld de, {en}
            ld a, 11
ea_nm:
            ex af, af'
            ld a, (de)
            cp (hl)
            jr nz, ea_next
            inc hl
            inc de
            ex af, af'
            dec a
            jr nz, ea_nm
            jr ea_done
ea_next:
            ld hl, ({p})
            ld de, 64
            add hl, de
            ld ({p}), hl
            ld hl, 64
            add hl, bc
            ld b, h
            ld c, l
            jr ea_lp
ea_done:
            ld ({result}), bc
#endasm
End Function

' Vdu(on): the firmware's text on the screen (TXT VDU ENABLE) or not (TXT VDU DISABLE). Off
' while CyborgOS runs: the console is drawn here (Con), and AMSDOS's own messages ("NAME.CYB
' not found" when RUN looks for a file, "Bad command" for a name it can't take) would land
' on top of it
Public Sub Vdu(ByVal on As Integer)
#asm
            ld ({hsp}), sp
            ld sp, (ntc_csp)
            ld a, ({on})
            or a
            jr z, vd_off
            call #BB54              ; TXT VDU ENABLE
            jr vd_done
vd_off:
            call #BB57              ; TXT VDU DISABLE
vd_done:
            di
            ld sp, ({hsp})
#endasm
End Sub
