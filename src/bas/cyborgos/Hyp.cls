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
Private fin As Integer, fout As Integer   ' FileCall: the slot reading a file, the one writing one (0: none)
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

' ---- the slots' files: CP/M's file calls (BDOS 15, 16, 19-22, 33, 34; Main's Bdos), in Z80
' (in BASIC they took 2.4K). Through the firmware's cassette calls (AMSDOS, UniDOS ...), with
' their 2K buffers in main RAM's #4000-#4FFF - the window's own RAM (page 1), which nothing
' else uses - put in the window for each call, then the page that was there back; so a slot's
' file stays open between its calls while the hypervisor's Memory.Copy uses #8000. One file
' read and one written at a time (AMSDOS has one of each), by any slots: another asking gets
' 255; a slot's new open replaces the file it was reading (CP/M needs no close after reading).
' A record goes through main RAM (buf: 128 bytes). Random records (33, 34): read on, or
' from the start again; written, only the next one. Rename (23): the disc ROM's |REN.
' Search (17, 18), size (35): not yet (255)
' FileCall(f, fcb, slot, setting, dma, drive, buf): the call's A. setting = the slot's RAM
' setting (sg), drive = the slot's drive letter (0: none), buf = 128 bytes of main RAM
Public Function FileCall(ByVal f As Integer, ByVal fcb As Integer, ByVal slot As Integer, ByVal setting As Integer, ByVal dma As Integer, ByVal drive As Integer, ByVal buf As Integer) As Integer
#asm
            ld ({hsp}), sp
            ld sp, (ntc_csp)
            ld (fl_ix), ix
            ld (fl_iy), iy
            ld a, 255
            ld (fl_res), a
            ld a, ({slot})
            ld (fl_slot), a
            ld a, ({f})
            cp 15
            jp z, fl_open
            cp 16
            jp z, fl_close
            cp 19
            jp z, fl_del
            cp 23
            jp z, fl_ren
            cp 20
            jp z, fl_rdseq
            cp 33
            jp z, fl_rdran
            cp 21
            jp z, fl_write
            cp 34
            jp z, fl_write
            cp 22
            jp z, fl_make
            cp 100
            jp z, fl_hopen
            cp 101
            jp z, fl_hread
            cp 102
            jp z, fl_hclose
            cp 103
            jp z, fl_hload
            jp fl_done
; ---- the hypervisor's own reading (RUN, DIR, CD): 100 open the file named at fcb (dma
; characters, main RAM); 101 read dma bytes (128 at most) to buf: how many; 102 close; 103 the
; rest of it into the slot (setting) from address dma, fcb bytes at most: how many. Not while
; a slot reads a file (255)
fl_hopen:
            ld a, ({fin})
            or a
            jp nz, fl_done
            ld hl, ({fcb})
            ld de, fl_name_s + 1
            ld bc, ({dma})
            ld a, c
            ld (fl_name_s), a
            ldir
            call fl_inopen
            jp nc, fl_done
            ld a, 99                ; (99: the hypervisor's)
            ld ({fin}), a
            jp fl_ok
fl_hread:
            ld a, ({dma})
            ld (fl_n), a
            call fl_rdrec
            ld (fl_res), a
            jp fl_done
fl_hclose:
            ld a, ({fin})
            cp 99
            jp nz, fl_done
            call fl_inclose
            jp fl_ok
fl_hload:
            ld hl, 0
            ld (fl_cnt), hl
            ld hl, ({dma})
            ld (fl_at), hl
fl_hl_lp:
            ld hl, ({fcb})          ; what is left to load (fcb bytes at most)
            ld de, (fl_cnt)
            or a
            sbc hl, de
            jr z, fl_hl_end
            ld a, h
            or a
            ld a, 128
            jr nz, fl_hl_n
            ld a, l
            cp 128
            jr c, fl_hl_n
            ld a, 128
fl_hl_n:
            ld (fl_n), a
            ld (fl_want), a
            call fl_rdrec           ; a record's worth into buf
            jr z, fl_hl_end
            ld b, a
            ld (fl_want + 1), a
            ld hl, (fl_cnt)
            ld e, a
            ld d, 0
            add hl, de
            ld (fl_cnt), hl
            ld de, ({buf})
            ld hl, (fl_at)
fl_hl_cp:
            ld a, (de)              ; into the slot
            call fl_poke
            inc hl
            inc de
            djnz fl_hl_cp
            ld (fl_at), hl
            ld a, (fl_want)
            ld b, a
            ld a, (fl_want + 1)
            cp b
            jr z, fl_hl_lp          ; a whole one: on
fl_hl_end:
            ld hl, (fl_cnt)
            ld (fl_res16), hl
            ld a, 1
            ld (fl_r16), a
            jp fl_done
; ---- 15: open (to read)
fl_open:
            ld a, ({fin})
            or a
            jr z, fl_op_new
            ld b, a
            ld a, (fl_slot)
            cp b
            jp nz, fl_done          ; another slot's being read
            call fl_inclose         ; this slot's: CP/M needs no close after reading - this open
fl_op_new:                          ; replaces it (Exists opens and leaves it)
            call fl_name
            call fl_inopen
            jp nc, fl_done
            ld hl, fl_name_s        ; kept, to open it again (33 going back)
            ld de, fl_inname
            ld bc, 17
            ldir
            ld a, (fl_slot)
            ld ({fin}), a
            ld hl, ({fcb})
            ld (fl_infcb), hl
            ld hl, 0
            ld (fl_inrec), hl
            jp fl_ok
; ---- 22: make (a new file, to write)
fl_make:
            ld a, ({fout})
            or a
            jp nz, fl_done
            call fl_name
            call fl_plain
            ld hl, fl_name_s + 1
            ld a, (fl_name_s)
            ld b, a
            ld de, #4800
            call #BC8C              ; CAS OUT OPEN
            di
            jp nc, fl_done
            ld a, (fl_slot)
            ld ({fout}), a
            ld hl, ({fcb})
            ld (fl_outfcb), hl
            jp fl_ok
; ---- 16: close
fl_close:
            call fl_isin
            jr nz, fl_cl_out
            call fl_inclose
            jp fl_ok
fl_cl_out:
            call fl_isout
            jp nz, fl_done
            xor a
            ld ({fout}), a
            call fl_plain
            call #BC8F              ; CAS OUT CLOSE
            di
            jp nc, fl_done
            jp fl_ok
; ---- 19: delete (|ERA, "name")
fl_del:
            call fl_name
            call fl_plain
            ld hl, fl_name_s + 1
            ld (fl_desc + 1), hl
            ld a, (fl_name_s)
            ld (fl_desc), a
            ld hl, fl_era
            call #BCD4              ; KL FIND COMMAND: C = its ROM, HL = its address
            di
            jp nc, fl_done
            ld ix, fl_par
            ld a, 1                 ; one parameter: the string
            call #001B              ; KL FAR PCALL
            di
            jp fl_ok
; ---- 23: rename (the disc ROM's |REN, "new", "old"): the old name at FCB 0-11, the new
; at 16-27 (its drive 0: the old one's)
fl_ren:
            ld hl, ({fcb})
            call fl_peek
            ld (fl_dfl), a
            ld de, 16
            add hl, de
            call fl_namehl          ; the new name
            xor a
            ld (fl_dfl), a
            ld hl, fl_name_s
            ld de, fl_new_s
            ld bc, 17
            ldir
            call fl_name            ; the old one
            call fl_plain
            ld hl, fl_name_s + 1
            ld (fl_desc + 1), hl
            ld a, (fl_name_s)
            ld (fl_desc), a
            ld hl, fl_new_s + 1
            ld (fl_desc2 + 1), hl
            ld a, (fl_new_s)
            ld (fl_desc2), a
            ld hl, fl_rencmd
            call #BCD4              ; KL FIND COMMAND
            di
            jp nc, fl_done
            ld ix, fl_par2          ; IX+0: the last parameter (the old name), IX+2: the new
            ld a, 2
            call #001B              ; KL FAR PCALL
            di
            jp fl_ok
; ---- 33: read record r0-r1: on to it (from the start again if it is behind)
fl_rdran:
            call fl_isin
            jp nz, fl_rdout
            ld hl, ({fcb})
            ld de, 33
            add hl, de
            call fl_peek
            ld e, a
            inc hl
            call fl_peek
            ld d, a
            ld (fl_want), de
            ld hl, (fl_inrec)
            or a
            sbc hl, de
            jr c, fl_rr_on
            jr z, fl_rr_on
            call fl_inclose         ; behind: open it again
            ld hl, fl_inname
            ld de, fl_name_s
            ld bc, 17
            ldir
            call fl_inopen
            jp nc, fl_done
            ld a, (fl_slot)
            ld ({fin}), a
            ld hl, 0
            ld (fl_inrec), hl
fl_rr_on:
            ld hl, (fl_inrec)
            ld de, (fl_want)
            or a
            sbc hl, de
            jr nc, fl_rdseq
            call fl_rdrec
            jp z, fl_eof
            ld hl, (fl_inrec)
            inc hl
            ld (fl_inrec), hl
            jr fl_rr_on
; ---- 20: read the next record
fl_rdseq:
            call fl_isin
            jr nz, fl_rdout
            call fl_rdrec
            jr z, fl_eof
            ex de, hl
            ld hl, (fl_inrec)
            inc hl
            ld (fl_inrec), hl
            ex de, hl
            ld b, a                 ; the record padded with #1A
            ld a, 128
            sub b
            jr z, fl_rd_put
            ld b, a
            ld a, #1A
fl_rd_pad:
            ld (hl), a
            inc hl
            djnz fl_rd_pad
fl_rd_put:
            ld hl, ({buf})          ; into the slot's DMA
            ld de, ({dma})
            ld b, 128
fl_rd_cp:
            ld a, (hl)
            ex de, hl
            call fl_poke
            ex de, hl
            inc hl
            inc de
            djnz fl_rd_cp
            jp fl_ok
fl_rdout:
            call fl_isout           ; a file being written: nothing to read back
            jp nz, fl_done
fl_eof:
            ld a, 1
            ld (fl_res), a
            jp fl_done
; ---- 21 / 34: write the next record
fl_write:
            call fl_isout
            jp nz, fl_done
            ld hl, ({dma})          ; the slot's DMA into buf
            ld de, ({buf})
            ld b, 128
fl_wr_cp:
            call fl_peek
            ld (de), a
            inc hl
            inc de
            djnz fl_wr_cp
            call fl_plain
            ld hl, ({buf})
            ld b, 128
fl_wr_lp:
            ld a, (hl)
            push bc
            push hl
            call #BC95              ; CAS OUT CHAR
            di
            pop hl
            pop bc
            jp nc, fl_done
            inc hl
            djnz fl_wr_lp
            jp fl_ok
; ---- the parts
fl_isin:                            ; Z: the file being read is this slot's, this FCB
            ld a, ({fin})
            ld hl, fl_infcb
            jr fl_is
fl_isout:
            ld a, ({fout})
            ld hl, fl_outfcb
fl_is:
            ld b, a
            ld a, (fl_slot)
            cp b
            ret nz
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld hl, ({fcb})
            or a
            sbc hl, de
            ret
fl_inopen:                          ; open fl_name_s to read: carry = done
            call fl_plain
            ld hl, fl_name_s + 1
            ld a, (fl_name_s)
            ld b, a
            ld de, #4000
            call #BC77              ; CAS IN OPEN
            di
            ret
fl_inclose:
            xor a
            ld ({fin}), a
            call fl_plain
            call #BC7A              ; CAS IN CLOSE
            di
            ret
fl_rdrec:                           ; read up to fl_n bytes (128) into buf: A = how many (Z
            call fl_plain           ; none), HL past them. A #1A is a byte (the soft end of file)
            ld hl, ({buf})
            ld a, (fl_n)
            ld b, a
fl_rr_lp:
            push bc
            push hl
            call #BC80              ; CAS IN CHAR
            di
            pop hl
            pop bc
            jr c, fl_rr_b
            cp #1A
            jr nz, fl_rr_end
fl_rr_b:
            ld (hl), a
            inc hl
            djnz fl_rr_lp
fl_rr_end:
            ld a, (fl_n)
            sub b
            ld c, a
            ld a, 128
            ld (fl_n), a            ; (128 again for the next)
            ld a, c
            or a
            ret
fl_plain:                           ; main RAM's own #4000 in the window (the buffers)
            ld bc, #7FC0
            out (c), c
            ret
fl_sel:                             ; the slot's page holding HL in the window: HL = there
            push de
            ld a, h
            rlca
            rlca
            and 3
            add a, 4
            ld e, a
            ld bc, ({setting})
            ld a, c
            and #F8
            or e
            ld c, a
            out (c), c
            ld a, h
            and #3F
            or #40
            ld h, a
            pop de
            ret
fl_peek:                            ; A = the slot's byte at HL (BC, DE, HL kept)
            push bc
            push hl
            call fl_sel
            ld a, (hl)
            pop hl
            pop bc
            ret
fl_poke:                            ; the slot's byte at HL = A (BC, DE, HL kept)
            push bc
            push hl
            push af
            call fl_sel
            pop af
            ld (hl), a
            pop hl
            pop bc
            ret
fl_name:                            ; fl_name_s = the FCB's file: length, "B:NAME.EXT"
            ld hl, ({fcb})
fl_namehl:                          ; (HL = an FCB in the slot)
            ld de, fl_name_s + 1
            call fl_peek            ; its drive: 0 = the slot's (or fl_dfl's)
            or a
            jr nz, fl_nm_d
            ld a, (fl_dfl)
            or a
            jr nz, fl_nm_d
            ld a, ({drive})
            or a
            jr z, fl_nm_nod
            sub 64
fl_nm_d:
            add a, 64
            ld (de), a
            inc de
            ld a, ':'
            ld (de), a
            inc de
fl_nm_nod:
            ld b, 11
fl_nm_lp:
            inc hl
            ld a, b
            cp 3
            jr nz, fl_nm_c
            ld a, '.'
            ld (de), a
            inc de
fl_nm_c:
            call fl_peek
            and #7F
            cp ' ' + 1
            jr c, fl_nm_sk
            ld (de), a
            inc de
fl_nm_sk:
            djnz fl_nm_lp
            ex de, hl
            ld de, fl_name_s + 1
            or a
            sbc hl, de
            ld a, l
            ld (fl_name_s), a
            ret
fl_ok:
            xor a
            ld (fl_res), a
fl_done:
            di
            ld bc, (ntc_rampt)      ; the page that was in the window back
            out (c), c
            ld a, (fl_res)
            ld l, a
            ld h, 0
            ld a, (fl_r16)
            or a
            jr z, fl_d8
            ld hl, (fl_res16)
            xor a
            ld (fl_r16), a
fl_d8:
            ld ({result}), hl
            ld ix, (fl_ix)
            ld iy, (fl_iy)
            ld sp, ({hsp})
            jp fl_exit
fl_era:     db "ER", "A" + #80
fl_rencmd:  db "RE", "N" + #80
fl_par2:    dw fl_desc, fl_desc2
fl_desc2:   db 0
            dw 0
fl_dfl:     db 0                    ; fl_name: the drive for an FCB whose own is 0 (rename)
fl_new_s:   ds 17
fl_par:     dw fl_desc
fl_desc:    db 0
            dw 0
fl_ix:      dw 0
fl_iy:      dw 0
fl_res:     db 0
fl_r16:     db 0                    ; 1: the result is fl_res16
fl_res16:   dw 0
fl_n:       db 128                  ; bytes fl_rdrec reads
fl_cnt:     dw 0
fl_at:      dw 0
fl_slot:    db 0
fl_infcb:   dw 0
fl_inrec:   dw 0
fl_want:    dw 0
fl_outfcb:  dw 0
fl_name_s:  ds 17                   ; length, then "B:NAME.EXT"
fl_inname:  ds 17                   ; the one being read's (33 going back)
fl_exit:
#endasm
End Function

' Xfer(toslot, setting, addr, p, n): n bytes between main RAM at p and the slot (its RAM
' setting) at addr - into the slot when toslot <> 0, else out of it. Through the window (a
' page's end carries on in the next), the page that was there put back. (Memory.Copy goes
' through the 2K buffer, which CyborgOS no longer has)
Public Sub Xfer(ByVal toslot As Integer, ByVal setting As Integer, ByVal addr As Integer, ByVal p As Integer, ByVal n As Integer)
#asm
            ld hl, ({n})
            ld (xf_left), hl
            ld hl, ({addr})
            ld de, ({p})
xf_lp:
            ld bc, (xf_left)
            ld a, b
            or c
            jr z, xf_done
            dec bc
            ld (xf_left), bc
            ld a, h                 ; the slot's page holding HL in the window
            rlca
            rlca
            and 3
            add a, 4
            ld c, a
            ld a, ({setting})
            and #F8
            or c
            ld c, a
            ld a, ({setting} + 1)
            ld b, a
            out (c), c
            ld a, h                 ; BC = there in the window
            and #3F
            or #40
            ld b, a
            ld c, l
            ld a, ({toslot})
            or a
            jr z, xf_get
            ld a, (de)
            ld (bc), a
            jr xf_next
xf_get:
            ld a, (bc)
            ld (de), a
xf_next:
            inc hl
            inc de
            jr xf_lp
xf_done:
            ld bc, (ntc_rampt)
            out (c), c
            jr xf_end
xf_left:    dw 0
xf_end:
#endasm
End Sub

' FileShut(slot): its files closed (its program ended, was killed or reset)
Public Sub FileShut(ByVal slot As Integer)
#asm
            ld ({hsp}), sp
            ld sp, (ntc_csp)
            ld bc, #7FC0
            out (c), c
            ld a, ({slot})
            ld b, a
            ld a, ({fin})
            cp b
            jr nz, fs_out
            xor a
            ld ({fin}), a
            push bc
            call #BC7A              ; CAS IN CLOSE
            di
            pop bc
fs_out:
            ld a, ({fout})
            cp b
            jr nz, fs_done
            xor a
            ld ({fout}), a
            call #BC8F              ; CAS OUT CLOSE
            di
fs_done:
            ld bc, (ntc_rampt)
            out (c), c
            ld sp, ({hsp})
#endasm
End Sub

#If NTC_LIBRARY_ROM Then
#Else
' Drive(letter): the disc system's |letter command run (KL FIND COMMAND, KL FAR PCALL: AMSDOS's
' |A / |B, UniDOS's, the M4's ...): True, or False when no ROM has that command (CD)
Public Function Drive(ByVal letter As Integer) As Integer
#asm
            ld ({hsp}), sp
            ld sp, (ntc_csp)
            ld (dv_ix), ix
            ld (dv_iy), iy
            ld hl, 0
            ld ({result}), hl
            ld a, ({letter})
            or #80                  ; a one letter command name: its last letter + #80
            ld (dv_nm), a
            ld hl, dv_nm
            call #BCD4              ; KL FIND COMMAND: carry = found, C = its ROM, HL = its address
            di
            jr nc, dv_done
            xor a                   ; no parameters
            call #001B              ; KL FAR PCALL
            di
            ld hl, -1
            ld ({result}), hl
            jr dv_done
dv_nm:      db 0
dv_ix:      dw 0
dv_iy:      dw 0
dv_done:
            ld ix, (dv_ix)
            ld iy, (dv_iy)
            ld sp, ({hsp})
#endasm
End Function
#End If
