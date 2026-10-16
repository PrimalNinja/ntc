' Hyp: the bank side of CyborgOS (docs/cyborgos.md) - what goes into a task's 64K bank, and
' the switch into it and back.
'
' A task's bank (RAM setting C2: the whole 64K is the bank) holds a CP/M page zero, the program
' from #0100, the stubs at STUB (#EF00: the BDOS entry, the top of the TPA; a CP/M BIOS jump
' table, a DPB; the start-up that fills the default FCBs), the font at FONT (#F300: Con draws
' from it), OBUF etc. at #F600, its text page at #F700 (80 x 25, written by the hypervisor) and
' its saved SP at #FFFE:
'   #0000 jp WBOOT       #0005 jp STUB (BDOS)      #0038 jp the interrupt save
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
Public Const STUB = &HEF00         ' the stubs: the BDOS entry (#0006: the top of the TPA), the BIOS
Public Const FONT = &HF300         ' the matrices of characters 32-127 (768 bytes; from the hypervisor's page)
Public Const HFONT = &H1000        ' ... kept in the hypervisor's page at #5000 (FontInit), for Install and Say
Public Const SRCH = &HF6F0         ' BDOS 17's FCB name (12 bytes), then the entries passed (18 goes on)
Public Const OBUF = &HF600         ' a program's characters out, collected (128), OBUF + 128 their count
Public Const KEY = &HF681          ' the slot's next key (0 none): the bank's BDOS answers 1, 6 and 11 from it
Public Const CCOLS = &HF687        ' the slot's console: its columns, rows (BDOS 49 answers from them), MODE
Public Const CROWS = &HF688        ' (0 2, 1 S, 2 W, 3 UW, 4 P), the status strip's text (4 characters at
Public Const CMODE = &HF689        ' the top of the 4 columns right of the console - MODE S)
Public Const CSTRIP = &HF68A
Private sps As Integer, ra As Integer, rhl As Integer, rfn As Integer, rde As Integer, rcnt As Integer
Private slc As Integer, hsp As Integer, rclr As Integer, rrom As Integer
Private fin As Integer, fout As Integer   ' FileCall: the slot reading a file, the one writing one (0: none)
Private hps As Integer             ' the hypervisor's page's RAM setting (UsePage): the disc buffers' RAM
Private drs As Integer             ' the RAM discs' driver's page's RAM setting (UseDriver; 0: none)
Private hdr As Integer             ' the drive the hypervisor's own reading (FileCall 100-104) is on (Drive)
Private dxb As Integer             ' the driver's copies go through it (128 bytes of main RAM: UseDriver)
Private ccu As Integer                  ' Con: the cursor is on the screen (Scr: cleared, off)
Private scc As Integer, sco As Integer   ' the screen (Scr): its columns, its start (bytes, in each 2K line
Private scw As Integer             ' block: the hardware scroll); scw: CRTC R1 (words a row)
Private pon As Integer, pox As Integer, poy As Integer   ' the pointer (Svc 11): drawn, at its column, row
Private svp As Integer             ' the service page's RAM setting (UseSvc: Svc's code)
Private svst As Integer, svsg As Integer, svns As Integer, svfr As Integer, svdp As Integer   ' (SvcVars)
Const SLICE = 6                    ' interrupts in a task's time slice (6: 1/50 s)

' Setting(): the gate array's RAM setting (B = port, C = value) as C2 for the bank whose page
' is in the window now (Memory.SelectPage of one of its pages first)
' UsePage: the page in the window now is the hypervisor's (the disc buffers: Hyp.FileCall)
Public Sub UsePage()
#asm
            ld hl, (ntc_rampt)
            ld ({hps}), hl
#endasm
End Sub

' UseDriver(b): the page in the window now holds the RAM discs' driver (RAMDISC.CYB put it
' there): FileCall offers it each call first; its copies go through b (128 bytes of main RAM)
Public Sub UseDriver(ByVal b As Integer)
  dxb = b
#asm
            ld hl, (ntc_rampt)
            ld ({drs}), hl
#endasm
End Sub

' ClaimPage(page): a specific page, if free now, marked the program's own (TypeUser "U") in the
' Memory class's RAT - for reclaiming the RAM disc pages that outlived a reset (the boot probe).
' The page, or 0 (not a page this machine has, or not free). CyborgOS's own: not in the library
Public Function ClaimPage(ByVal page As Integer) As Integer
#asm
            ld hl, ({page})
            ld a, h
            or l
            jr z, cp_no
            ld de, (mem_count)
            ex de, hl
            or a
            sbc hl, de              ; page - count: carry means page > count
            jr c, cp_no
            ld hl, ({page})         ; the RAT byte: (mem_ttype) + page - 1
            ld de, (mem_ttype)
            add hl, de
            dec hl
            ld a, (hl)
            cp "-"                  ; free?
            jr nz, cp_no
            ld (hl), "U"            ; TypeUser
            ld hl, ({page})
            jr cp_done
cp_no:
            ld hl, 0
cp_done:
            ld ({result}), hl
#endasm
End Function

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

' FontInit(): the firmware's character matrices 32-127 into the hypervisor's page at #5000
' (once, after Mode 2 and UsePage): Install copies them into each bank (FONT: Con draws from the
' bank's page in the window), Say uses them there. TXT SET M TABLE copies them into a table of
' its own; the firmware then goes back to its own (the lower ROM can't be switched in here: this
' code may be below #4000). Not in main RAM: 768 bytes the Library: ROM build has no room for
Public Sub FontInit()
#asm
            ld ({hsp}), sp
            ld sp, (ntc_csp)
            ld bc, ({hps})
            out (c), c
            ld de, 32               ; D = 0: a table, E = its first character
            ld hl, #4000 + {HFONT}
            call #BBAB              ; TXT SET M TABLE (the matrices from 32 on, copied there)
            di
            ld de, #FF00            ; D <> 0: no table of its own any more
            call #BBAB
            di
            ld bc, (ntc_rampt)
            out (c), c
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
' state, escape row; #F687 its columns and rows - MODE; #F68A the status strip's text), so
' nothing about it passes through BASIC. Handles CR, LF, BS, TAB and the VT52 codes ESC E
' (clear), ESC H (home), ESC I (reverse line feed: on the top row the screen scrolls back), ESC Y
' row col (move), ESC A B C D (up, down, right, left), ESC K J (clear to the end of the row, of
' the page), ESC L M (insert, delete a row) and Amstrad's ESC l o d (clear the row, to the cursor
' in the row, in the page); the page (#F700, 2K at most) is a ring of its rows
' (a scroll moves its top row and clears one row); on the screen a scroll moves the screen's
' start a row on (the CRTC's R12 / R13: the hardware scroll, in Scr's mode - not the firmware's,
' which knows only 80 x 25) and clears the new last row. The window's page is put back at the end.
' Why Z80: this was Main.bas's Collected / Out / PutC / NewLine / RowA / ClsT / PutMem / ToFront
' - per line about 4 Memory calls (each one turning Long far pointers into a page and an
' address and switching pages in and out), several hundred keywords and a safe point at every
' branch: about 200,000 T a line. Here the page is switched in once and each character costs a
' few hundred T (most of it the 8 screen bytes).
Public Sub Con(ByVal pg As Integer, ByVal src As Integer, ByVal n As Integer, ByVal front As Integer)
#asm
; CN_SB 1: the scrollback (Shift + Up / Down: 48 rows a slot, kept in a 16K page Main gives - #If
; SCROLLBACK in Main.bas, set the two together). Off for now: 526 bytes of main RAM (2026-10-16)
CN_SB:      equ 0
            ld ({hsp}), sp
            ld sp, (ntc_csp)
            ld bc, ({pg})
            out (c), c              ; the slot's page 3 at #4000: OBUF #7600, state #7682, page #7700
            IF CN_SB
            ld (cn_pg), bc
            ENDIF
            xor a
            ld (cn_pv), a
            ld a, ({front})
            ld (cn_front), a
            ld a, (#7687)           ; its columns and rows (MODE)
            ld (cn_c), a
            ld a, (#7688)
            ld (cn_r), a
            ld a, ({ccu})           ; the cursor off first, whatever comes (it was on: cn_was)
            ld (cn_was), a
            or a
            call nz, cn_cuxor
            ld hl, ({n})
            bit 7, h
            jp nz, cn_neg
            ld (cn_left), hl
            IF CN_SB
            ld a, (cn_front)        ; in front and looking back (scrollback): the page again first
            or a
            jr z, cn_live
            ld a, (#7F26)
            or a
            jr z, cn_live
            xor a
            ld (#7F26), a
            call cn_cls
            call cn_strip
            call cn_draw
            ld hl, (cn_left)
cn_live:
            ENDIF
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

; n < 0: -1 the whole page to the screen (it was cleared: Show), not looking back any more; -2
; the scrollback (src: the key - #F4 Shift + Up a screen back, #F5 Shift + Down one on), drawn
cn_neg:
            ld a, l
            cp #FD                  ; -3: the cursor flashes - on (it was off), an underline XORed
            jr nz, cn_neg1          ; where the next character goes; off (it was on: done above)
            ld a, (cn_front)
            or a
            jr z, cn_done
            ld a, (cn_was)
            or a
            jr nz, cn_done
            ld a, (#7682)
            ld d, a
            ld a, (#7683)
            ld e, a
            call cn_scr
            ld a, h
            add a, #38              ; (its cell's last pixel line)
            ld h, a
            ld (cn_ca), hl
            call cn_cuxor
            jr cn_done
cn_neg1:
            IF CN_SB
            inc hl
            ld a, h
            or l
            jr nz, cn_view
            ld (#7F26), a
            ENDIF
cn_show:
            call cn_strip
            call cn_draw
            jr cn_done
            IF CN_SB
cn_view:
            ld a, (#7F21)           ; (no history page: nothing)
            or a
            jr z, cn_done
            ld a, (cn_r)
            dec a
            ld b, a                 ; a screen: its rows - 1
            ld a, ({src})
            cp #F4
            ld a, (#7F26)
            jr nz, cn_vw_dn
            add a, b
            ld hl, #7F25
            cp (hl)
            jr c, cn_vw_set
            ld a, (hl)              ; (not past the oldest row kept)
            jr cn_vw_set
cn_vw_dn:
            sub b
            jr nc, cn_vw_set
            xor a
cn_vw_set:
            ld hl, #7F26
            cp (hl)
            jr z, cn_done
            ld (hl), a
            call cn_cls
            jr cn_show

            ENDIF

; the screen's rows: the page's - or, looking back (#FF26 rows), the history's first, then the
; page's. Row e shows line count + e - back of history + page (count the rows kept, #FF25)
cn_draw:
            ld e, 0
            IF CN_SB
cn_dr_row:
            push de
            ld a, (#7F25)
            add a, e
            ld hl, #7F26
            sub (hl)                ; the line: count + e - back
            ld hl, #7F25
            sub (hl)
            jr c, cn_dr_h
            call cn_rowa            ; HL = row (line - count) of the page
            ld a, (cn_c)
            jr cn_dr_go
cn_dr_h:
            add a, (hl)
            call cn_hget            ; HL = the history's row (copied in), 80 characters at most
            ld a, (cn_c)
            cp HW
            jr c, cn_dr_go
            ld a, HW
cn_dr_go:
            ld b, a
            pop de
            push de
            ld d, 0
cn_dr_col:
            ld a, (hl)
            inc hl
            cp 33
            jr c, cn_dr_sk
            push hl
            push de
            push bc
            call cn_glyph
            pop bc
            pop de
            pop hl
cn_dr_sk:
            inc d
            djnz cn_dr_col
            pop de
            inc e
            ld a, (cn_r)
            dec a
            cp e
            jr nc, cn_dr_row
            ret
            ELSE
cn_sh_row:                          ; (no scrollback: the page's rows as they are)
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
            ld a, (cn_c)
            dec a
            cp d
            jr nc, cn_sh_col
            inc e
            ld a, (cn_r)
            dec a
            cp e
            jr nc, cn_sh_row
            ret
            ENDIF

            IF CN_SB
; the scrollback: each row that scrolls off the top of the page - its first HW characters - goes
; to the slot's history: HROWS rows (a ring) in a 16K page of its own that Main gave it (#FF20:
; its RAM setting, 0 none; #FF22 where in it; #FF24 the next row written, #FF25 how many, #FF26
; how far back the screen looks). Copied 8 bytes at a time through the stack - only the window
; changes, so no main RAM for a buffer
HW:         equ 80
HROWS:      equ 48
cn_hput:                            ; HL = the row going (the page)
            ld a, (#7F21)
            or a
            ret z
            ld (cn_hs), hl
            ld hl, (cn_pg)
            ld (cn_h1), hl
            ld hl, (#7F20)
            ld (cn_h2), hl
            ld a, (#7F24)
            call cn_haddr
            ld (cn_hd), hl
            ld hl, #7F24            ; the next row on, one more kept
            ld a, (hl)
            inc a
            cp HROWS
            jr c, cn_hp_h
            xor a
cn_hp_h:
            ld (hl), a
            inc hl
            ld a, (hl)
            cp HROWS
            jr nc, cn_hcp
            inc (hl)
; cn_hcp: HW bytes from cn_hs in RAM setting cn_h1 to cn_hd in cn_h2, then the slot's page back
cn_hcp:
            ld a, HW / 8
cn_hc_lp:
            ld (cn_hn), a
            ld bc, (cn_h1)
            out (c), c
            ld hl, (cn_hs)
            ld b, 4
cn_hc_in:
            ld e, (hl)
            inc hl
            ld d, (hl)
            inc hl
            push de
            djnz cn_hc_in
            ld (cn_hs), hl
            ld bc, (cn_h2)
            out (c), c
            ld hl, (cn_hd)
            ld de, 8
            add hl, de
            ld (cn_hd), hl
            ld b, 4
cn_hc_out:
            pop de
            dec hl
            ld (hl), d
            dec hl
            ld (hl), e
            djnz cn_hc_out
            ld a, (cn_hn)
            dec a
            jr nz, cn_hc_lp
            ld bc, (cn_pg)
            out (c), c
            ret
cn_hget:                            ; A = a line of the history (0 the oldest kept): copied to
            ld hl, #7F24            ; #FF30 in the slot's page (HL)
            add a, (hl)
            inc hl
            sub (hl)
            jr nc, cn_hg_r
            add a, HROWS
cn_hg_r:
            call cn_haddr
            ld (cn_hs), hl
            ld hl, (#7F20)
            ld (cn_h1), hl
            ld hl, (cn_pg)
            ld (cn_h2), hl
            ld hl, #7F30
            ld (cn_hd), hl
            call cn_hcp
            ld hl, #7F30
            ret
cn_haddr:                           ; A = a history row: HL = its address in the history page
            ld e, a
            ld a, HW
            call cn_mul
            ld de, (#7F22)
            add hl, de
            ret
; cn_cls: the screen cleared (written only: the Library: ROM build's keyword ROM may be over it)
cn_cls:
            ld hl, #C000
            ld bc, #4000
cn_cl_lp:
            ld (hl), 0
            inc hl
            dec bc
            ld a, b
            or c
            jr nz, cn_cl_lp
            ret
            ENDIF

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
            cp 9
            jr z, cn_tab
            cp 8
            ret nz                  ; other control codes: nothing
            ld a, (#7682)           ; BS: back one (not past the start of the row)
            or a
            ret z
            dec a
            ld (#7682), a
            ret
cn_tab:                             ; TAB: spaces to the next column of 8
            ld b, ' '
            call cn_print
            ld a, (#7682)
            and 7
            jr nz, cn_tab
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
            cp 'I'
            jp z, cn_rev
            cp 'Y'
            jr z, cn_sety
            cp 'A'
            jr z, cn_up
            cp 'B'
            jr z, cn_down
            cp 'C'
            jr z, cn_right
            cp 'D'
            jr z, cn_lft
            cp 'K'
            jp z, cn_eol
            cp 'J'
            jp z, cn_eos
            cp 'l'
            jp z, cn_eln
            cp 'o'
            jp z, cn_sol
            cp 'd'
            jp z, cn_sos
            cp 'M'
            jp z, cn_dell
            cp 'L'
            jp z, cn_insl
            ret                     ; (the rest - e f j k p q ...: nothing)
cn_sety:
            ld a, 2
            ld (#7685), a
            ret
cn_up:                              ; ESC A, B, C, D: up, down, right, left (not past the edge)
            ld hl, #7683
            jr cn_dec
cn_lft:
            ld hl, #7682
cn_dec:
            ld a, (hl)
            or a
            ret z
            dec (hl)
            ret
cn_down:
            ld de, #7683
            ld hl, cn_r
            jr cn_inc
cn_right:
            ld de, #7682
            ld hl, cn_c
cn_inc:
            ld a, (de)
            inc a
            cp (hl)
            ret nc
            ld (de), a
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
            ld hl, cn_c
            cp (hl)
            jr c, cn_e3_col
            xor a
cn_e3_col:
            ld (#7682), a
            ld a, (#7686)
            ld hl, cn_r
            cp (hl)
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
            call cn_next
            ld (cn_sp), hl
cn_pr_adv:
            ld hl, #7682
            inc (hl)
            ld a, (hl)
            ld hl, cn_c
            cp (hl)
            ret c
            xor a                   ; past the last column: the next row
            ld (#7682), a
            ld (cn_pv), a
; a line feed: the next row, or the page (and the screen) scroll
cn_nl:
            ld a, (#7683)
            inc a
            ld hl, cn_r
            cp (hl)
            jr nc, cn_scroll
            ld (#7683), a
            ret
cn_scroll:
            ld a, (#7684)           ; the ring's top row moves on (no copy)
            inc a
            cp (hl)
            jr c, cn_sc_top
            xor a
cn_sc_top:
            ld (#7684), a
            ld a, (cn_r)
            dec a
            call cn_rowa            ; the new last row cleared (the old top row: kept first)
            IF CN_SB
            push hl
            call cn_hput
            pop hl
            ENDIF
            ld a, (cn_c)
            ld b, a
cn_sc_cl:
            ld (hl), ' '
            inc hl
            djnz cn_sc_cl
            ld a, (cn_front)
            or a
            ret z
            ld hl, ({sco})          ; the screen: its start a row on (R12, R13), the new last row
            ld de, ({scc})          ; cleared, the status strip again (it went off the top)
            add hl, de
            ld a, h
            and #07
            ld h, a
            ld ({sco}), hl
            call cn_crtc
            ld a, (cn_r)
            dec a
            ld e, a
cn_sc_clr:                          ; E = a screen row: cleared, then the status strip again
            ld d, 0
            call cn_scr
            ld b, 8
cn_sc_ln:
            push bc
            push hl
            ld a, ({scc})
            ld b, a
cn_sc_b:
            ld (hl), 0
            call cn_next
            djnz cn_sc_b
            pop hl
            ld a, h
            add a, 8
            ld h, a
            pop bc
            djnz cn_sc_ln
            jp cn_strip

; ESC I (reverse line feed): the row before, or on the top row the page (and the screen) scroll
; back: the ring's top row a row back, the new top row cleared; on the screen its start a row
; back (R12, R13) and the new top row cleared - the line feed's scroll the other way
cn_rev:
            ld a, (#7683)
            or a
            jr z, cn_rv_sc
            dec a
            ld (#7683), a
            ret
cn_rv_sc:
            ld a, (#7684)
            or a
            jr nz, cn_rv_top
            ld a, (cn_r)
cn_rv_top:
            dec a
            ld (#7684), a
            xor a
            call cn_rowa            ; (row 0 of the page now)
            ld a, (cn_c)
            ld b, a
cn_rv_cl:
            ld (hl), ' '
            inc hl
            djnz cn_rv_cl
            ld a, (cn_front)
            or a
            ret z
            ld hl, ({sco})
            ld de, ({scc})
            or a
            sbc hl, de
            ld a, h
            and #07
            ld h, a
            ld ({sco}), hl
            call cn_crtc
            ld e, 0
            jp cn_sc_clr

; ESC K the row from the cursor on cleared, J the rest of the page too, l the whole row, o the
; row up to the cursor, d the page up to it; M the cursor's row deleted (those below up a row, a
; blank one at the end), L a blank one put in (those below down, the last gone) - the column 0.
; The page changed first, then its rows drawn again on the screen when in front
cn_eol:
            ld a, (cn_c)
            ld hl, #7682
            sub (hl)
            ld b, a
            ld d, (hl)
            ld a, (#7683)
            ld e, a
            jp cn_wipen
cn_eos:
            call cn_eol
            ld a, (#7683)
cn_eos_lp:
            inc a
            ld hl, cn_r
            cp (hl)
            ret nc
            push af
            ld e, a
            call cn_wrow
            pop af
            jr cn_eos_lp
cn_eln:
            ld a, (#7683)
            ld e, a
            jp cn_wrow
cn_sol:
            ld a, (#7682)
            inc a
            ld b, a
            ld d, 0
            ld a, (#7683)
            ld e, a
            jp cn_wipen
cn_sos:
            call cn_sol
            ld a, (#7683)
cn_sos_lp:
            or a
            ret z
            dec a
            push af
            ld e, a
            call cn_wrow
            pop af
            jr cn_sos_lp
cn_dell:
            xor a
            ld (#7682), a
            ld a, (#7683)
            ld b, a                 ; B: the row filled from the one below
cn_dl_lp:
            ld a, (cn_r)
            dec a
            cp b
            jr z, cn_dl_end
            ld c, b
            inc c
            ld a, b
            push bc
            call cn_cpr
            pop bc
            inc b
            jr cn_dl_lp
cn_dl_end:
            ld e, b
            call cn_wrow            ; the last row blank
            ld a, (cn_r)
            dec a
            ld c, a
            ld a, (#7683)
            jr cn_redr
cn_insl:
            xor a
            ld (#7682), a
            ld a, (cn_r)
            dec a
            ld b, a                 ; B: the row filled from the one above
cn_il_lp:
            ld a, (#7683)
            cp b
            jr z, cn_il_end
            ld c, b
            dec c
            ld a, b
            push bc
            call cn_cpr
            pop bc
            dec b
            jr cn_il_lp
cn_il_end:
            ld e, b
            call cn_wrow            ; the cursor's row blank
            ld a, (cn_r)
            ld c, a
            ld a, (#7683)
            inc a
; cn_redr: rows A to C - 1 drawn again from the page
cn_redr:
            cp c
            ret nc
            push af
            push bc
            ld e, a
            ld d, 0
            ld a, (cn_c)
            ld b, a
            call cn_drwn
            pop bc
            pop af
            inc a
            jr cn_redr
; cn_cpr: the page's row C copied to its row A
cn_cpr:
            push af
            ld a, c
            call cn_rowa
            pop af
            push hl
            call cn_rowa
            ex de, hl
            pop hl
            ld a, (cn_c)
            ld c, a
            ld b, 0
            ldir
            ret
; cn_wrow: row E blank; cn_wipen: B characters of row E from column D blank (B > 0) - in the page,
; then drawn (cn_drwn: B characters of row E from column D, from the page, when in front)
cn_wrow:
            ld d, 0
            ld a, (cn_c)
            ld b, a
cn_wipen:
            push de
            push bc
            ld a, e
            call cn_rowa
            pop bc
            pop de
            push bc
            ld a, l
            add a, d
            ld l, a
            jr nc, cn_wn_lp
            inc h
cn_wn_lp:
            ld (hl), ' '
            inc hl
            djnz cn_wn_lp
            pop bc
cn_drwn:
            ld a, (cn_front)
            or a
            ret z
            push de
            push bc
            ld a, e
            call cn_rowa
            pop bc
            pop de
            ld a, l
            add a, d
            ld l, a
            jr nc, cn_dw_lp
            inc h
cn_dw_lp:
            ld a, (hl)
            inc hl
            push hl
            push de
            push bc
            call cn_glyph
            pop bc
            pop de
            pop hl
            inc d
            djnz cn_dw_lp
            ret

; ESC E: the page cleared, column, row and ring back to 0; the screen too if in front (written,
; not copied: the Library: ROM build may have the keyword ROM over it for reads)
cn_clear:
            ld hl, #7700
            ld de, #7701
            ld (hl), ' '
            ld bc, 2047
            ldir
            xor a
            ld (#7682), a
            ld (#7683), a
            ld (#7684), a
            ld a, (cn_front)
            or a
            ret z
            ld hl, 0
            ld ({sco}), hl
            ld ({pon}), hl          ; (no pointer on the cleared screen)
            call cn_crtc
            xor a
            ld hl, #C000
            ld c, #40
cn_cl_l:
            ld b, 0
cn_cl_b:
            ld (hl), a
            inc hl
            djnz cn_cl_b
            dec c
            jr nz, cn_cl_l
; cn_strip: MODE S (the screen wider than the console): the status strip's 4 characters (#F68A)
; at the top of the columns right of the console
cn_strip:
            ld a, (cn_front)
            or a
            ret z
            ld a, (cn_c)
            ld d, a
            ld a, ({scc})
            cp d
            ret z
            ret c
            ld e, 0
            ld hl, #768A
            ld b, 4
cn_st_lp:
            ld a, (hl)
            push hl
            push de
            push bc
            call cn_glyph
            pop bc
            pop de
            pop hl
            inc hl
            inc d
            djnz cn_st_lp
            ret

; cn_crtc: the screen's start (sco, bytes) to the CRTC: R12 = #30 + its words' high 2 bits, R13
; the low 8 (#C000, MA10 / MA11 clear: kept within 2K, never the carry into the next 16K)
cn_crtc:
            ld hl, ({sco})
            srl h
            rr l
            ld a, h
            and 3
            or #30
            ld bc, #BC0C
            out (c), c
            inc b
            out (c), a
            ld bc, #BC0D
            out (c), c
            inc b
            out (c), l
            ret

; cn_rowa: A = row of the screen -> HL = its row in the page ring (#7700 + ((top + A) mod rows)
; * columns)
cn_rowa:
            ld hl, #7684
            add a, (hl)
            ld hl, cn_r
            cp (hl)
            jr c, cn_ra_in
            sub (hl)
cn_ra_in:
            ld e, a
            ld a, (cn_c)
            call cn_mul
            ld de, #7700
            add hl, de
            ret

; cn_mul: HL = A * E (BC kept; D = 0 after)
cn_mul:
            push bc
            ld hl, 0
            ld d, 0
            ld b, 8
cn_mu_lp:
            add hl, hl
            rlca
            jr nc, cn_mu_n
            add hl, de
cn_mu_n:
            djnz cn_mu_lp
            pop bc
            ret

; cn_next: HL = the next screen byte: + 1 within its 2K line block (BC kept)
cn_next:
            inc l
            ret nz
            ld a, h
            inc a
            and #07
            push bc
            ld c, a
            ld a, h
            and #F8
            or c
            ld h, a
            pop bc
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
            ld de, {FONT} - #8000   ; (the bank's page 3 in the window: FONT - #C000 + #4000)
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
; cn_scr: D = column, E = row -> HL = the screen address: the screen's start (sco) + row *
; columns (scc) + column, within each 2K line block, at #C000
cn_scr:
            push de
            ld a, ({scc})
            call cn_mul
            pop de
            ld c, d
            ld b, 0
            add hl, bc
            ld bc, ({sco})
            add hl, bc
            ld a, h
            and #07
            or #C0
            ld h, a
            ret
cn_cuxor:                           ; the cursor's underline XORed at cn_ca, on <-> off
            ld hl, (cn_ca)
            ld a, (hl)
            cpl
            ld (hl), a
            ld a, ({ccu})
            xor 1
            ld ({ccu}), a
            ret
cn_was:     db 0
cn_ca:      dw 0
cn_front:   db 0
cn_c:       db 80                   ; the slot's columns, rows
cn_r:       db 25
cn_pv:      db 0                    ; cn_pp / cn_sp valid (0: the cursor moved)
cn_pp:      dw 0                    ; the page byte for the next character
cn_sp:      dw 0                    ; its screen address
cn_left:    dw 0
cn_ptr:     dw 0
            IF CN_SB
cn_pg:      dw 0                    ; the slot's page 3 setting (pg)
cn_h1:      dw 0                    ; cn_hcp: from (its setting, address), to, 8-byte runs left
cn_hs:      dw 0
cn_h2:      dw 0
cn_hd:      dw 0
cn_hn:      db 0
            ENDIF
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
            ld bc, ({hps})          ; the hypervisor's page in the window: the font
            out (c), c
            ld hl, ({sco})          ; the screen's start (TOP is shown in MODE 2: 80 columns)
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
            ld bc, #4000 + {HFONT}  ; (the hypervisor's page in the window)
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
            or #C0
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
            ld bc, (ntc_rampt)
            out (c), c
            ld sp, ({hsp})
            jr sy_end
sy_off:     dw 0
sy_end:
#endasm
End Sub

' Scr(m, k): the screen modes - all in the 16K screen at #C000 (columns x rows <= 2048, so the
' hardware scroll works: a row's 8 pixel lines each in their own 2K block). k = 0: the console's
' columns in mode m, 1 its rows, 2 the screen set to it (the CRTC's widths, heights and sync
' positions - centred on the standard 80 x 25 -, the screen cleared, its start at #C000)
'   0  MODE 2   80 x 25     2  MODE W   88 x 23     4  MODE P   64 x 32
'   1  MODE S   84 x 24: the console 80 x 24 and a status strip of 4 columns on the right
'   3  MODE UW  96 x 21         5  MODE F   84 x 24: all of it the console (a program's own
'                                         status columns: MON)
' Its own CRTC values, not the firmware's (it knows only 80 x 25): Con scrolls by scc
Public Function Scr(ByVal m As Integer, ByVal k As Integer) As Integer
#asm
            ld ({hsp}), sp          ; (the real stack: SP is the thread)
            ld sp, (ntc_csp)
            xor a
            ld ({ccu}), a           ; (the screen cleared: no cursor on it)
            ld a, ({m})
            cp 6
            jr c, sm_ok
            xor a
sm_ok:
            ld l, a                 ; the mode's row of the table (6 bytes)
            add a, a
            add a, l
            add a, a
            ld e, a
            ld d, 0
            ld hl, sm_tab
            add hl, de
            ld a, ({k})
            or a
            jr z, sm_cols
            dec a
            jr z, sm_rows
            push hl                 ; 2: the screen
            ld e, (hl)              ; its columns
            ld d, 0
            ld ({scc}), de
            srl e
            ld ({scw}), de
            ld hl, 0
            ld ({sco}), hl
            ld ({pon}), hl          ; (no pointer on the cleared screen)
            pop hl
            inc hl
            inc hl                  ; R1, R2, R6, R7
            di
            ld d, 1
            call sm_crtc
            ld d, 2
            call sm_crtc
            ld d, 6
            call sm_crtc
            ld d, 7
            call sm_crtc
            ld hl, sm_start         ; R12, R13: #C000
            ld d, 12
            call sm_crtc
            ld d, 13
            call sm_crtc
            xor a                   ; cleared (written, not copied: the Library: ROM build may
            ld hl, #C000            ; have the keyword ROM over it for reads)
            ld c, #40
sm_cl:
            ld b, 0
sm_cl1:
            ld (hl), a
            inc hl
            djnz sm_cl1
            dec c
            jr nz, sm_cl
            ld hl, 0
            jr sm_res
sm_cols:
            ld a, (hl)              ; the console's: the screen's, less the status strip's 4 (S)
            inc hl
            sub (hl)
            jr sm_a
sm_rows:
            inc hl
            inc hl
            inc hl
            inc hl
            ld a, (hl)
sm_a:
            ld l, a
            ld h, 0
sm_res:
            ld ({result}), hl
            ld sp, ({hsp})
            ret                     ; (on with the thread)
sm_crtc:                            ; CRTC register D = (HL), HL on
            ld bc, #BC00
            out (c), d
            ld b, #BD
            ld a, (hl)
            out (c), a
            inc hl
            ret
sm_start:   db #30, 0
; columns, the status strip's, R1 (words a row), R2 (horizontal sync), R6 (rows), R7 (vertical sync)
sm_tab:     db 80, 0, 40, 46, 25, 30
            db 84, 4, 42, 47, 24, 30
            db 88, 0, 44, 48, 23, 29
            db 96, 0, 48, 50, 21, 28
            db 64, 0, 32, 42, 32, 34
            db 84, 0, 42, 47, 24, 30
#endasm
End Function

' KeyRep(f): the keys' start delay and repeat f times as long (KM GET DELAY, KM SET DELAY: 255
' at most each, in 1/50 s) - for an emulator running faster than a CPC (WinAPE at 1000%: 10)
Public Sub KeyRep(ByVal f As Integer)
#asm
            ld ({hsp}), sp
            ld sp, (ntc_csp)
            call #BB42              ; KM GET DELAY: H the start delay, L the repeat
            di
            ld a, h
            call kr_mul
            ld h, a
            ld a, l
            call kr_mul
            ld l, a
            call #BB3F              ; KM SET DELAY
            di
            ld sp, ({hsp})
            jr kr_end
kr_mul:                             ; A = A x f, 255 at most (0: 256 to the firmware - kept)
            or a
            ret z
            push hl
            ld e, a
            ld d, 0
            ld hl, 0
            ld a, ({f})
            ld b, a
kr_lp:
            add hl, de
            djnz kr_lp
            ld a, h
            or a
            ld a, l
            pop hl
            ret z
            ld a, 255
            ret
kr_end:
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

' Info(n): the bank image, kept in the hypervisor's page (window data: in the file at #5300,
' copied there by FileCall 99 at the start - not in main RAM) - 0 the page zero part's address
' there, 1 its length, 2 the stubs' address there, 3 their length (copied to STUB), 4 where a
' program starts (the stubs' start-up: the default FCBs from the command tail, then #0100)
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
            ld hl, sb_img
            dec a
            jr z, in_e
            ld hl, sb_end - sb_start
            dec a
            jr z, in_e
            ld hl, sb_init
in_e:
            ex de, hl
            pop hl
            ld (hl), e
            inc hl
            ld (hl), d
            ret
; @window
; (the hypervisor's page from #5300 - #4000 the disc buffers, #5000 the font: Install copies
; these into each bank from there, FileCall 99 put them there at the start)
            ds #5300 - $
; page zero (#0000-#0080)
hi_p0:
            db #C3
            dw sb_bwb                           ; #0000: warm boot - the BIOS's WBOOT (the task
            db 0, 0                             ; ends); (#0001) - 3: the BIOS jump table
            db #C3
            dw sb_start                         ; #0005: BDOS (#0006: the top of the TPA)
            ds #38 - 8
            db #C3
            dw sb_int                           ; #0038: the interrupt
            ds #44 - #3B
            db #ED, #49                         ; #0044: out (c), c
            db #C3
            dw sb_land                          ; #0046: this bank switched in
            ds #5C - #49
            db 0, "           "                 ; #005C: the default FCB
            ds #80 - #68
            db 0                                ; #0080: no command tail
hi_p0e:
; the stubs: assembled here, run at STUB in the bank (DISP: their labels are the bank's
; addresses). The BDOS: what needs nothing of the hypervisor is answered here, with no
; switch - the console out (2, 9: collected at OBUF; the hypervisor gets them, IX = how many, at
; the next far call or interrupt, or when 128 wait), the keys (1, 6, 10, 11: from KEY, where
; the hypervisor leaves the slot's next key), the IOBYTE (7, 8), the disc's parameters (27, 31)
; and the calls with nothing to do (3, 4, 5, 28, 29, 30, 37 - 30 with #C0 on at DE is CyborgOS's
; UniDOS call), CP/M 3's 49 for the console's size (MODE); the rest is a far call. Then the
; BIOS (its jump table: (#0001) - 3) and the start-up (the default FCBs)
sb_img:
            DISP {STUB}
sb_start:
            di                                  ; BDOS: C = function, DE = argument
            ld a, c
            cp 2
            jp z, sb_put
            cp 6
            jr z, sb_f6
            cp 11
            jr z, sb_stat
            cp 1
            jr z, sb_f1
            cp 9
            jp z, sb_str
            cp 10
            jp z, sb_line
            cp 3
            jr z, sb_rdr
            cp 7
            jr z, sb_iob
            cp 8
            jr z, sb_siob
            cp 27
            jr z, sb_alv
            cp 31
            jr z, sb_dpb
            cp 4
            jr z, sb_zero
            cp 5
            jr z, sb_zero
            cp 28
            jr z, sb_zero
            cp 29
            jr z, sb_zero
            cp 30
            jr z, sb_f30
            cp 37
            jr z, sb_zero
            cp 49
            jp z, sb_scb
            jp sb_call
sb_f30:                                         ; 30: nothing - unless #C0 on at DE: CyborgOS's
            ld a, (de)                          ; UniDOS call (CD, DIR: the hypervisor's)
            cp #C0
            jp nc, sb_call
sb_zero:
            xor a                               ; 4, 5 (the printer: not yet), 28, 29, 30, 37
sb_ret:
            ld l, a
            ld h, 0
            ei
            ret
sb_rdr:
            ld a, #1A                           ; 3: the reader - the end of a file
            jr sb_ret
sb_iob:
            ld a, (#0003)                       ; 7: the IOBYTE
            jr sb_ret
sb_siob:
            ld a, e                             ; 8
            ld (#0003), a
            jr sb_zero
sb_alv:
            ld hl, sb_alvec                     ; 27: the allocation vector (a CPC data disc's)
            ei
            ret
sb_dpb:
            ld hl, sb_dpbv                      ; 31: the disc parameter block
            ei
            ret
sb_f6:
            ld a, e
            cp #FF
            jr z, sb_get
            cp #FE
            jr c, sb_put
sb_stat:
            ld a, ({KEY})                       ; 6 / #FE, 11: is a key waiting (#FF / 0)
            or a
            jr z, sb_ret
            ld a, #FF
            jr sb_ret
sb_get:
            ld hl, {KEY}                        ; 6 / #FF: the key or 0 (no wait)
            ld a, (hl)
            ld (hl), 0
            jr sb_ret
sb_f1:
            call sb_key                         ; 1: a key (waited for), echoed
            push af
            ld e, a
            call sb_putc
            pop af
            jr sb_ret
sb_put:
            call sb_putc                        ; 2: E out
            ei
            ret
sb_str:
            ld h, d                             ; 9: the string at DE, to "$"
            ld l, e
sb_st_lp:
            ld a, (hl)
            cp '$'
            jr z, sb_zero
            push hl
            ld e, a
            call sb_putc
            pop hl
            inc hl
            jr sb_st_lp
; sb_putc - E collected at OBUF (the hypervisor shown them when 128 wait). Interrupts off
sb_putc:
            ld hl, {OBUF} + 128                 ; the count
            ld a, (hl)
            inc (hl)
            ld l, a
            ld h, {OBUF} / 256
            ld (hl), e
            cp 127
            ret c
            push bc
            push de
            ld c, #80                           ; full: function #80, only the characters
            call sb_call
            di
            pop de
            pop bc
            ret
; sb_key - A = the next key, waited for: none at KEY - a far call (#81) that has the hypervisor
; run the others until a key comes (or the clock moves on), then look again
sb_key:
            ld hl, {KEY}
            ld a, (hl)
            or a
            jr z, sb_k_wait
            ld (hl), 0
            ret
sb_k_wait:
            push bc
            push de
            ld c, #81
            call sb_call
            di
            pop de
            pop bc
            jr sb_key
; 10: a line typed into the buffer at DE (its size, then how many came, then them): BS / DEL
; rub out, Control + U / X the whole line, Control + C at its start ends the program, CR / LF
; end it (CR echoed)
sb_line:
            ld (sb_lbuf), de
            xor a
            ld (sb_lcnt), a
sb_l_lp:
            call sb_key
            cp 13
            jr z, sb_l_end
            cp 10
            jr z, sb_l_end
            cp 8
            jr z, sb_l_bs
            cp 127
            jr z, sb_l_bs
            cp 21
            jr z, sb_l_kill
            cp 24
            jr z, sb_l_kill
            cp 3
            jr nz, sb_l_ch
            ld a, (sb_lcnt)
            or a
            jr nz, sb_l_lp
            ld c, 0                             ; Control + C: the program ends
            jp sb_call
sb_l_ch:
            cp 32
            jr c, sb_l_lp
            ld b, a
            ld hl, (sb_lbuf)
            ld a, (sb_lcnt)
            cp (hl)
            jr nc, sb_l_lp                      ; full
            inc a
            ld (sb_lcnt), a
            ld e, a
            ld d, 0
            inc hl
            add hl, de
            ld (hl), b
            ld e, b
            call sb_putc
            jr sb_l_lp
sb_l_kill:
            ld a, (sb_lcnt)
            or a
            jr z, sb_l_lp
            call sb_l_rub
            jr sb_l_kill
sb_l_bs:
            ld a, (sb_lcnt)
            or a
            jr z, sb_l_lp
            call sb_l_rub
            jr sb_l_lp
sb_l_rub:
            dec a
            ld (sb_lcnt), a
            ld e, 8
            call sb_putc
            ld e, ' '
            call sb_putc
            ld e, 8
            jp sb_putc
sb_l_end:
            ld hl, (sb_lbuf)
            inc hl
            ld a, (sb_lcnt)
            ld (hl), a
            ld e, 13
            call sb_putc
            jp sb_zero
sb_lbuf:    dw 0
sb_lcnt:    db 0
sb_call:
            push ix                             ; a far call: IX, IY and the alternate
            push iy                             ; registers kept over it (ex af, af')
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
            ld hl, sb_far
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
            ld hl, sb_rest
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
sb_scb:
            ld h, d                             ; 49 (CP/M 3's system control block): the
            ld l, e                             ; console's width - 1 (#1A), its page length
            inc hl                              ; (#1C) - MODE's; other bytes 0, sets kept
            ld a, (hl)                          ; nowhere
            or a
            jp nz, sb_zero
            ld a, (de)
            cp #1C
            ld hl, {CROWS}
            jr z, sb_scb_a
            cp #1A
            jp nz, sb_zero
            ld a, ({CCOLS})
            dec a
            jp sb_ret
sb_scb_a:
            ld a, (hl)
            jp sb_ret
; the BIOS: CP/M 2.2's 17 entries. The console ones as the BDOS's; the printer and punch take
; nothing yet; the disc ones (sectors) can't be had here: SELDSK gives 0 (no such drive),
; READ / WRITE 1 (an error)
sb_bios:
            jp sb_bboot                         ; BOOT
sb_bwb:
            jp sb_bboot                         ; WBOOT: (#0001)
            jp sb_bconst                        ; CONST
            jp sb_bconin                        ; CONIN
            jp sb_bconout                       ; CONOUT
            jp sb_bnone                         ; LIST
            jp sb_bnone                         ; PUNCH
            jp sb_brdr                          ; READER
            jp sb_bnone                         ; HOME
            jp sb_bseld                         ; SELDSK
            jp sb_bnone                         ; SETTRK
            jp sb_bnone                         ; SETSEC
            jp sb_bdma                          ; SETDMA
            jp sb_bfail                         ; READ
            jp sb_bfail                         ; WRITE
            jp sb_blstst                        ; LISTST
            jp sb_bsectr                        ; SECTRAN
sb_bboot:
            ld c, 0                             ; the task ends
            jp sb_start
sb_bconst:
            di
            ld a, ({KEY})
            or a
            jr z, sb_bc_n
            ld a, #FF
sb_bc_n:
            ei
            ret
sb_bconin:
            di
            call sb_key
            ei
            ret
sb_bconout:
            di
            ld e, c
            call sb_putc
            ei
sb_bnone:
            ret
sb_brdr:
            ld a, #1A
            ret
sb_bseld:
            ld hl, 0
            ret
sb_bdma:
            ld d, b
            ld e, c
            ld c, 26
            jp sb_start
sb_bfail:
            ld a, 1
            ret
sb_blstst:
            ld a, #FF
            ret
sb_bsectr:
            ld h, b
            ld l, c
            ret
; a CPC data format disc's parameters (31) and allocation vector (27): 180 1K blocks, 64
; directory entries in the first two
sb_dpbv:
            dw 36                               ; SPT: 128 byte records a track
            db 3, 7, 0                          ; BSH, BLM, EXM
            dw 179, 63                          ; DSM, DRM
            db #C0, 0                           ; AL0, AL1
            dw 16, 0                            ; CKS, OFF
sb_alvec:
            db #C0
            ds 22
; the start-up: the default FCBs (#005C, #006C) from the command tail (#0080), as the CCP
; makes them - "B:NAME.EXT", * as ?s - then the program at #0100
sb_init:
            ld hl, #005C
            call sb_iclr
            ld hl, #006C
            call sb_iclr
            ld hl, #0081
            ld a, (#0080)
            ld b, a
            ld de, #005C
            call sb_parse
            ld de, #006C
            call sb_parse
            jp #0100
sb_iclr:
            ld (hl), 0
            inc hl
            ld c, 11
sb_ic_sp:
            ld (hl), ' '
            inc hl
            dec c
            jr nz, sb_ic_sp
            ld c, 4
sb_ic_z:
            ld (hl), 0
            inc hl
            dec c
            jr nz, sb_ic_z
            ret
; sb_parse - HL = the tail, B = characters left; DE = an FCB: the next word into it
sb_parse:
            ld a, b
            or a
            ret z
            ld a, (hl)
            cp ' '
            jr nz, sb_p_word
            inc hl
            dec b
            jr sb_parse
sb_p_word:
            ld (sb_pfcb), de
            ld a, b
            cp 2
            jr c, sb_p_name
            inc hl
            ld a, (hl)
            dec hl
            cp ':'
            jr nz, sb_p_name
            ld a, (hl)
            sub '@'
            ld (de), a                          ; its drive
            inc hl
            inc hl
            dec b
            dec b
sb_p_name:
            inc de
            ld c, 8
            call sb_pfield
            ld a, b
            or a
            ret z
            ld a, (hl)
            cp '.'
            jr nz, sb_p_skip
            inc hl
            dec b
            ld de, (sb_pfcb)
            ld a, e
            add a, 9
            ld e, a
            ld c, 3
            call sb_pfield
sb_p_skip:
            ld a, b                             ; the rest of the word
            or a
            ret z
            ld a, (hl)
            cp ' '
            ret z
            inc hl
            dec b
            jr sb_p_skip
; sb_pfield - up to C characters into the field at DE, to a "." or a space; * fills it with ?
sb_pfield:
            ld a, b
            or a
            ret z
            ld a, (hl)
            cp ' '
            ret z
            cp '.'
            ret z
            cp '*'
            jr z, sb_pf_star
            inc c
            dec c
            jr z, sb_pf_on                      ; (the field full: the extra left out)
            ld (de), a
            inc de
            dec c
sb_pf_on:
            inc hl
            dec b
            jr sb_pfield
sb_pf_star:
            inc c
            dec c
            jr z, sb_pf_on
            ld a, '?'
            ld (de), a
            inc de
            dec c
            jr sb_pf_star
sb_pfcb:    dw 0
sb_end:
            ENT
            ASSERT sb_end - sb_start <= {FONT} - {STUB}, "the bank stubs must fit below FONT"
            ASSERT sb_end - sb_start <= #340, "the stubs must leave a program's first stack (#F240-#F2FF) free"
; @endwindow

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

' ---- the slots' files: CP/M's file calls (BDOS 15-23, 33-36; Main's Bdos), in Z80
' (in BASIC they took 2.4K). Through the firmware's cassette calls (AMSDOS, UniDOS ...), with
' their 2K buffers at #4000-#4FFF of the hypervisor's own page (UsePage: the first expansion
' bank's page 0) - put in the window for each call, then the page that was there back; so a
' slot's file stays open between its calls. Main RAM's own #4000-#7FFF is left free. One file
' read and one written at a time (AMSDOS has one of each), by any slots: another asking gets
' 255; a slot's new open replaces the file it was reading (CP/M needs no close after reading).
' A record goes through main RAM (buf: 128 bytes). Random records (33, 34): read on, or
' from the start again; written, only the next one. Rename (23): the disc ROM's |REN.
' Size (35): counted, reading the file through. Set random record (36): where the file is.
' Search (17, 18): the folder itself (UniDOS: Ctrl J examine). With
' UniDOS a drive letter can be a path ("IDE:GAMES/": CD), put before each name (30: CD's, DIR's
' calls - fl_unicall)
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
            cp 99
            jp z, fl_inst
            IF NTC_ROMLIB = 0
; the RAM discs' driver (RAMDISC.CYB's, in a page of its own at #4000) sees the call first:
; carry - it was one of its drives' (HL the answer), else on to the disc ROM. It gets IX = the
; call (f, fcb, slot, setting, dma, drive, buf; 100-105: drive = the hypervisor's drive), at
; #4003 a jump to fl_dx (its copies: it runs in the window, so can't switch it itself), at
; #4006 its page's RAM setting
            ASSERT {buf} - {f} = 12, "FileCall's parameters, one after another"
            ld a, ({drs} + 1)
            or a
            jr z, fl_nodrv
            di
            ld a, ({f})
            cp 100
            jr c, fl_dr_go
            cp 106
            jr nc, fl_dr_go
            ld hl, ({hdr})
            ld ({drive}), hl
fl_dr_go:
            ld bc, ({drs})
            out (c), c
            ld hl, fl_dx
            ld (#4004), hl
            ld hl, ({drs})
            ld (#4006), hl
            ld ix, {f}
            call #4000
            jr nc, fl_nodrv
            ld (fl_res16), hl
            ld a, 1
            ld (fl_r16), a
            jp fl_done
; fl_dx - A bytes (1-128) from HL to DE through dxb: IX = HL's RAM setting, IY = DE's (0:
; main RAM, no switch); the driver's page back in the window after. HL, DE on past them
fl_dx:
            ld (fl_dxn), a
            push de
            ld de, ({dxb})
            push ix
            pop bc
            inc b
            dec b
            jr z, fl_dx1
            out (c), c
fl_dx1:
            ld c, a
            ld b, 0
            ldir
            pop de
            push hl
            push iy
            pop bc
            inc b
            dec b
            jr z, fl_dx2
            out (c), c
fl_dx2:
            ld hl, ({dxb})
            ld a, (fl_dxn)
            ld c, a
            ld b, 0
            ldir
            pop hl
            ld bc, ({drs})
            out (c), c
            ret
fl_dxn:     db 0
fl_nodrv:
            ENDIF
            di
            ld bc, ({hps})          ; the rest runs in the hypervisor's page (window data from
            out (c), c              ; #5300: fp_go)
            call fp_go
            jp fl_done
; 99: the window data (#5300 to fp_end: the bank image, the page code) copied from main RAM's
; own #4000-#7FFF (where the file put it) into the hypervisor's page, through buf; once, at the
; start, before anything else uses main RAM's #4000-#7FFF
fl_inst:
            ld hl, #5300
fl_in_lp:
            push hl
            ld bc, #7FC0            ; main RAM's own
            out (c), c
            ld de, ({buf})
            ld bc, 128
            ldir
            ld bc, ({hps})
            out (c), c
            pop de
            push de
            ld hl, ({buf})
            ld bc, 128
            ldir
            pop hl
            ld bc, 128
            add hl, bc
            ld de, fp_end
            or a
            sbc hl, de
            add hl, de
            jr c, fl_in_lp
            xor a
            ld (fl_res), a
            jp fl_done
; ---- what the page code can't do itself (it runs in the window): switch the window to a slot's
; page and back. Each puts the hypervisor's page back in the window
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
fl_pk_back:
            ld bc, ({hps})
            out (c), c
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
            jr fl_pk_back
fl_toslot:                          ; BC bytes from DE (main RAM) to the slot's HL (all in one of
            push bc                 ; its pages: fl_fits)
            call fl_sel
            pop bc
            ex de, hl
            ldir
            jr fl_blk_back
fl_fromslot:                        ; BC bytes from the slot's HL (in one page) to DE (main RAM)
            push bc
            call fl_sel
            pop bc
            ldir
fl_blk_back:
            ld bc, ({hps})
            out (c), c
            ret
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
fl_ix:      dw 0
fl_iy:      dw 0
fl_res:     db 0
fl_r16:     db 0                    ; 1: the result is fl_res16
fl_res16:   dw 0
fl_slot:    db 0
; (main RAM: the page code calls them - no room left in the page)
fl_isin:                            ; Z: the file being read is this slot's, this FCB
            ld a, ({fin})
            ld hl, fl_infcb
            jr fl_is
fl_isout:
            ld a, ({fout})
            ld hl, fl_outfcb
fl_is:                              ; (its FCB: the one it was opened with - or, the first
            ld b, a                 ; call after with another, that one: a program's own copy
            ld a, (fl_slot)         ; of it, BBC BASIC's channels)
            cp b
            ret nz
            ld e, (hl)
            inc hl
            ld d, (hl)
            inc hl
            push hl
            call fl_cmpf
            pop de
            ret z
            ld a, (de)              ; (the open's FCB still: this one from now on - unless it
            xor 1                   ; is the other file's: a program reading the record it
            ret nz                  ; writes, through that file's FCB)
            push de
            ld a, ({fin})
            ld de, (fl_infcb)
            call fl_oth
            jr z, fl_is_no
            ld a, ({fout})
            ld de, (fl_outfcb)
            call fl_oth
fl_is_no:
            pop de
            jr nz, fl_is_re
            inc a                   ; (NZ: not this one)
            ret
fl_is_re:
            xor a
            ld (de), a
            ld hl, ({fcb})
            ex de, hl
            dec hl
            ld (hl), d
            dec hl
            ld (hl), e
            ret
fl_oth:                             ; Z: the slot's file (A: fin / fout), its FCB DE the call's
            ld b, a
            ld a, (fl_slot)
            cp b
            ret nz
fl_cmpf:                            ; Z: the call's FCB is DE
            ld hl, ({fcb})
            or a
            sbc hl, de
            ret
; @window
; ---- the page code: in the hypervisor's page (window data), called with it in the window
fp_start:
            ASSERT fp_start >= #5300, "FileCall's page code: after the disc buffers and the font"
fp_go:
            ld (fp_sp), sp
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
            cp 17
            jp z, fl_srch1
            cp 18
            jp z, fl_srch
            cp 35
            jp z, fl_size
            cp 36
            jp z, fl_setran
            cp 100
            jp z, fl_hopen
            cp 101
            jp z, fl_hread
            cp 102
            jp z, fl_hclose
            cp 103
            jp z, fl_hload
            cp 30
            jp z, fl_unicall
            jp fp_done
; ---- the hypervisor's own reading (RUN, DIR, CD): 100 open the file named at fcb (dma
; characters, main RAM); 101 read dma bytes (128 at most) to buf: how many; 102 close; 103 the
; rest of it into the slot (setting) from address dma, fcb bytes at most: how many. Not while
; a slot reads a file (255)
fl_hopen:
            ld a, ({fin})
            or a
            jp nz, fp_done
            ld de, fl_name_s + 1
            ld hl, ({fcb})          ; a name with no drive: the hypervisor's drive's path first
            ld bc, ({dma})          ; when it has one (UniDOS: CD IDE: ...)
            ld a, ':'
            cpir
            jr z, fl_ho_nm
            ld a, ({hdr})
            call fl_pfxm
fl_ho_nm:
            ld hl, ({fcb})
            ld bc, ({dma})
            ldir
            call fl_nlen
            call fl_inopen
            jr c, fl_ho_ok
            ld hl, fl_name_s        ; NAME.CYB not there: with UniDOS NAME.COM instead (RUN - a
            ld e, (hl)              ; .COM with no entry: UniDOS reads a file with no header to
            ld d, 0                 ; its real end)
            add hl, de
            ld a, (hl)
            cp 'B'
            jp nz, fp_done
            ld (hl), 'M'
            dec hl
            ld a, (hl)
            cp 'Y'
            jp nz, fp_done
            ld (hl), 'O'
            call fl_uni
            jp nc, fp_done
            call fl_inopen
            jp nc, fp_done
            ld hl, ({fcb})          ; (the caller's name too: NAME.COM)
            ld bc, ({dma})
            add hl, bc
            dec hl
            ld (hl), 'M'
            dec hl
            ld (hl), 'O'
fl_ho_ok:
            ld a, 99                ; (99: the hypervisor's)
            ld ({fin}), a
            jp fl_ok
fl_hread:
            ld a, ({dma})
            ld (fl_n), a
            call fl_rdrec
            ld (fl_res), a
            jp fp_done
fl_hclose:
            ld a, ({fin})
            cp 99
            jp nz, fp_done
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
            ld hl, (fl_at)
            ld c, b
            ld b, 0
            call fl_fits
            jr c, fl_hl_slow
            push bc
            ld de, ({buf})          ; in one page: one ldir
            call fl_toslot
            pop bc
            ld hl, (fl_at)
            add hl, bc
            jr fl_hl_put
fl_hl_slow:
            ld b, c
            ld de, ({buf})
fl_hl_cp:
            ld a, (de)              ; into the slot
            call fl_poke
            inc hl
            inc de
            djnz fl_hl_cp
fl_hl_put:
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
            jp fp_done
; ---- 15: open (to read)
fl_open:
            ld a, ({fin})
            or a
            jr z, fl_op_new
            ld b, a
            ld a, (fl_slot)
            cp b
            jp nz, fp_done          ; another slot's being read
            call fl_inclose         ; this slot's: CP/M needs no close after reading - this open
fl_op_new:                          ; replaces it (Exists opens and leaves it)
            call fl_name
            call fl_inopen
            jp nc, fp_done
            ld hl, fl_name_s        ; kept, to open it again (33 going back)
            ld de, fl_inname
            ld bc, FL_NL
            ldir
            ld a, (fl_slot)
            ld ({fin}), a
            ld hl, ({fcb})
            ld (fl_infcb), hl
            ld a, 1
            ld (fl_infcb + 2), a
            ld hl, 0
            ld (fl_inrec), hl
            jp fl_ok
; ---- 22: make (a new file, to write)
fl_make:
            ld a, ({fout})
            or a
            jp nz, fp_done
            call fl_name
            call fl_plain
            ld hl, fl_name_s + 1
            ld a, (fl_name_s)
            ld b, a
            ld de, #4800
            call #BC8C              ; CAS OUT OPEN
            di
            jp nc, fp_done
            ld a, (fl_slot)
            ld ({fout}), a
            ld hl, ({fcb})
            ld (fl_outfcb), hl
            ld a, 1
            ld (fl_outfcb + 2), a
            ld hl, 0
            ld (fl_outrec), hl
            jp fl_ok
; ---- 16: close
fl_close:
            call fl_isin
            jr nz, fl_cl_out
            call fl_inclose
            jp fl_ok
fl_cl_out:
            call fl_isout
            jp nz, fp_done
            xor a
            ld ({fout}), a
            call fl_plain
            call #BC8F              ; CAS OUT CLOSE
            di
            jp nc, fp_done
            jp fl_ok
; ---- 19: delete (|ERA, "name")
fl_del:
            call fl_name
            call fl_plain
            ld hl, fl_name_s + 1
            ld (fl_desc + 1), hl
            ld a, (fl_name_s)
            ld (fl_desc), a
            ld hl, fl_yes           ; (UniDOS asks before it deletes a folder - all it holds too -,
            ld a, (hl)              ; a read-only or a hidden file: KM WAIT CHAR, its text unseen,
            ld (hl), 0              ; the VDU off. KM CHAR RETURN: the answer waiting for it - N,
            or a                    ; so a CP/M program's delete never takes a folder; Y only after
            ld a, 'N'               ; BDOS 30 op 8, RMDIR's, for its empty folder)
            jr z, fl_del_n
            ld a, 'Y'
fl_del_n:
            call #BB0C
            ld hl, fl_era           ; KL FIND COMMAND; KM READ CHAR after
            call #BCD4              ; takes the answer back when nothing asked
            di
            jp nc, fp_done
            ld ix, fl_par
            ld a, 1                 ; one parameter: the string
            call #001B              ; KL FAR PCALL
            call #BB09              ; KM READ CHAR (interrupts: off again in fl_done)
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
            ld bc, FL_NL
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
            jp nc, fp_done
            ld ix, fl_par2          ; IX+0: the last parameter (the old name), IX+2: the new
            ld a, 2
            call #001B              ; KL FAR PCALL
            jp fl_ok              ; (interrupts: off again in fl_done)
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
            ld bc, FL_NL
            ldir
            call fl_inopen
            jp nc, fp_done
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
            ld hl, ({dma})          ; into the slot's DMA: in one page, one ldir
            ld bc, 128
            call fl_fits
            jr c, fl_rd_slow
            ld de, ({buf})
            call fl_toslot
            jp fl_ok
fl_rd_slow:                         ; (across two pages: a byte at a time)
            ld hl, ({buf})
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
            jp nz, fp_done
fl_eof:
            ld a, 1
            ld (fl_res), a
            jp fp_done
; ---- 21 / 34: write the next record
fl_write:
            call fl_isout
            jp nz, fp_done
            ld hl, ({dma})          ; the slot's DMA into buf
            ld bc, 128
            call fl_fits
            jr c, fl_wr_slow
            ld de, ({buf})
            call fl_fromslot
            jr fl_wr_got
fl_wr_slow:
            ld de, ({buf})
            ld b, 128
fl_wr_cp:
            call fl_peek
            ld (de), a
            inc hl
            inc de
            djnz fl_wr_cp
fl_wr_got:
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
            jp nc, fp_done
            inc hl
            djnz fl_wr_lp
            ld hl, (fl_outrec)
            inc hl
            ld (fl_outrec), hl
            jp fl_ok
; ---- 35: the file's size in records (r0-r2): counted, reading it through. The file this slot
; is reading is opened again after, at its record; another slot's being read: 255
fl_size:
            ld a, ({fin})
            or a
            jr z, fl_sz_free
            ld b, a
            ld a, (fl_slot)
            cp b
            jp nz, fp_done
            call fl_inclose
            ld a, 1
fl_sz_free:
            ld (fl_had), a
            call fl_name
            call fl_inopen
            jr nc, fl_sz_back
            ld hl, 0
            ld (fl_cnt), hl
fl_sz_lp:
            call fl_rdrec
            jr z, fl_sz_end
            ld hl, (fl_cnt)
            inc hl
            ld (fl_cnt), hl
            cp 128
            jr z, fl_sz_lp
fl_sz_end:
            call fl_inclose
            ld hl, (fl_cnt)
            call fl_ranput
            xor a
            ld (fl_res), a
fl_sz_back:
            ld a, (fl_had)
            or a
            jp z, fp_done
            ld hl, fl_inname        ; the slot's read file again, on to its record
            ld de, fl_name_s
            ld bc, FL_NL
            ldir
            call fl_inopen
            jp nc, fp_done
            ld a, (fl_slot)
            ld ({fin}), a
            ld hl, (fl_inrec)
fl_sz_skip:
            ld a, h
            or l
            jp z, fp_done
            push hl
            call fl_rdrec
            pop hl
            dec hl
            jr fl_sz_skip
; ---- 36: set the random record (r0-r2) from where the file is: the next record read or
; written; a file not open here: from the FCB's extent and record (ex * 128 + cr)
fl_setran:
            call fl_isin
            ld hl, (fl_inrec)
            jr z, fl_sr_put
            call fl_isout
            ld hl, (fl_outrec)
            jr z, fl_sr_put
            ld hl, ({fcb})
            ld de, 32
            add hl, de
            call fl_peek            ; cr
            ld e, a
            ld bc, -20
            add hl, bc
            call fl_peek            ; ex
            ld h, a
            srl h
            ld a, e
            jr nc, fl_sr_lo
            or #80
fl_sr_lo:
            ld l, a
fl_sr_put:
            call fl_ranput
            jp fl_ok
; ---- 17 / 18: search the folder (UniDOS: the FCB's drive's, else the slot's) for BDOS 17's
; name ("?" any character; kept at SRCH in the bank, SRCH + 12 the entries passed - 18 goes on
; from there): the next one, as a CP/M directory entry at the DMA (its record count from its
; length, 128 at most). 17 examines the folder (Ctrl J) into the hypervisor's page (#6000-#7BFF:
; 112 entries at most), then 17 and 18 look there. No UniDOS (or an AMSDOS floppy): none (255)
fl_srch1:
            ld hl, ({fcb})
            ld de, {SRCH}
            ld b, 12
fl_s1_lp:
            call fl_peek
            ex de, hl
            call fl_poke
            ex de, hl
            inc hl
            inc de
            djnz fl_s1_lp
            ex de, hl
            xor a
            call fl_poke            ; none passed
            xor a
            ld (fl_cn), a
            ld hl, #6000
            ld (fl_at), hl
            ld de, fl_name_s + 1    ; "B:" (or B's path)
            ld hl, {SRCH}
            call fl_peek
            or a
            jr z, fl_s_own
            add a, 64
            jr fl_s_drv
fl_s_own:
            ld a, ({drive})
            or a
            jr z, fl_s_nod
fl_s_drv:
            call fl_pfx
fl_s_nod:
; UniDOS: the directory itself (Ctrl J examine), its files into the cache - no file opened (so
; not held up by another slot's reading)
            push de
            call fl_exdir
            pop de
            jp nz, fp_done          ; (none to list: no UniDOS, an AMSDOS floppy - 255)
fl_sx_lp:
            ld hl, (fl_at)
            inc hl                  ; (the name straight into the entry)
            ld ix, FL_DATE
            ld c, 13                ; examine next
            call fl_cjc
            jr nc, fl_sx_end
            jr nz, fl_sx_end
            bit 4, a
            jr nz, fl_sx_lp         ; (a folder: not for CP/M)
            ld hl, (fl_at)
            ld (hl), 1              ; in use
            ld a, b
            or c
            jr z, fl_sx_sz
            ld de, #FFFF            ; (64K or more)
fl_sx_sz:
            ld bc, 12
            add hl, bc
            ld (hl), b              ; kind, flags 0
            inc hl
            ld (hl), b
            inc hl
            ld (hl), e              ; its length
            inc hl
            ld (hl), d
            ld hl, (fl_at)
            ld bc, 64
            add hl, bc
            ld (fl_at), hl
            ld hl, fl_cn
            inc (hl)
            ld a, (hl)
            cp FL_CMAX
            jr c, fl_sx_lp
fl_sx_end:
            jp fl_srch
fl_srch:
            ld hl, {SRCH} + 12
            call fl_peek
            ld (fl_skip), a
            xor a
            ld (fl_k), a
fl_s_lp:
            ld a, (fl_cn)           ; the next entry, from the cache
            ld b, a
            ld a, (fl_k)
            cp b
            jp nc, fp_done          ; (none: 255)
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, #6000
            add hl, de
            ld de, ({buf})
            ld bc, 64
            ldir
            ld hl, fl_k
            inc (hl)
            ld a, (fl_skip)
            cp (hl)
            jr nc, fl_s_lp          ; passed already
            ld hl, ({buf})
            ld a, (hl)
            dec a
            jr nz, fl_s_lp          ; not in use (1)
            inc hl
            ld de, {SRCH} + 1
            ld b, 11
fl_s_cmp:
            ex de, hl
            call fl_peek
            ex de, hl
            and #7F
            cp '?'
            jr z, fl_s_any
            ld c, a
            ld a, (hl)
            and #7F
            cp c
            jr nz, fl_s_lp
fl_s_any:
            inc hl
            inc de
            djnz fl_s_cmp
            ld hl, ({buf})          ; the entry: user 0, the name, extent 0, the records, no blocks
            ld (hl), 0
            ld de, 14
            add hl, de
            ld e, (hl)
            inc hl
            ld d, (hl)
            ex de, hl
            ld bc, 127
            add hl, bc
            jr c, fl_s_big
            ld a, h
            cp #40
            jr nc, fl_s_big
            sla l
            rla
            jr fl_s_rc
fl_s_big:
            ld a, 128
fl_s_rc:
            ex de, hl
            ld (hl), a
            ld b, 3
fl_s_z1:
            dec hl
            ld (hl), 0
            djnz fl_s_z1
            ld de, 4
            add hl, de
            ld b, 16
fl_s_z2:
            ld (hl), 0
            inc hl
            djnz fl_s_z2
            ld hl, ({dma})
            ld de, ({buf})
            ld b, 32
fl_s_put:
            ld a, (de)
            call fl_poke
            inc hl
            inc de
            djnz fl_s_put
            ld hl, {SRCH} + 12
            ld a, (fl_k)
            call fl_poke
            jp fl_ok
fl_skip:    db 0
fl_k:       db 0
fl_cn:      db 0                    ; the folder's entries in the cache (#6000)
fl_ranput:                          ; the FCB's r0-r2 = HL
            ex de, hl
            ld hl, ({fcb})
            ld bc, 33
            add hl, bc
            ld a, e
            call fl_poke
            inc hl
            ld a, d
            call fl_poke
            inc hl
            xor a
            jp fl_poke
; ---- the parts
fl_inopen:                          ; open fl_name_s to read: carry = done
            call fl_plain
            ld hl, fl_name_s + 1
            ld a, (fl_name_s)
            ld b, a
            ld de, #4000
            call #BC77              ; CAS IN OPEN
            di
            ld (fl_hdr), hl         ; (its header: BDOS 30 #C7)
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
fl_fits:                            ; HL = a slot address, BC = bytes: NC = all in its 16K page.
            push hl                 ; Keeps BC, DE, HL
            ld a, h
            and #3F
            ld h, a
            add hl, bc
            ld a, h
            cp #40
            jr c, fl_ft_ok
            jr nz, fl_ft_no
            ld a, l
            or a
            jr nz, fl_ft_no
fl_ft_ok:
            pop hl
            or a
            ret
fl_ft_no:
            pop hl
            scf
            ret
fl_plain:                           ; the hypervisor's page in the window (the buffers)
            ld bc, ({hps})
            out (c), c
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
            call fl_pfx             ; "B:", or B's path (UniDOS: "IDE:GAMES/")
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
fp_done:                            ; back to FileCall in main RAM (fp_done)
            ld sp, (fp_sp)
            ret
fl_era:     db "ER", "A" + #80
fl_rencmd:  db "RE", "N" + #80
fl_par2:    dw fl_desc, fl_desc2
fl_desc2:   db 0
            dw 0
fl_dfl:     db 0                    ; fl_name: the drive for an FCB whose own is 0 (rename)
fl_par:     dw fl_desc
fl_desc:    db 0
            dw 0
fl_n:       db 128                  ; bytes fl_rdrec reads
fl_cnt:     dw 0
fl_at:      dw 0
fl_infcb:   dw 0
            db 0                    ; (1: fl_infcb the open's - fl_is)
fl_inrec:   dw 0
fl_want:    dw 0
fl_outfcb:  dw 0
            db 0
fl_outrec:  dw 0                    ; the next record written (36)
fl_had:     db 0                    ; 35: this slot's read file closed for it
fp_sp:      dw 0
; ---- UniDOS: its Ctrl J BIOS command (found once, KL FIND COMMAND) - a drive letter can be a
; path (CD IDE:, CD SD:GAMES ...: any UniDOS device's folder), folders listed (examine). FL_MAP:
; letters A-P, 32 bytes each: the path's length (0 none: the letter itself, "B:"), the path
; ("IDE:GAMES/": a device or logical drive, its folders, the last "/" or ":"). Cleared when
; UniDOS is found, and only set with it: with AMSDOS no letter has a path. Up there with the
; names (48 characters: a path and NAME.EXT), BDOS 132's block, DIR's listing: the FILES.DIR
; cache is #6000-#7BFF (112 entries)
FL_CMAX:    equ 112                 ; the cache's entries
FL_NL:      equ 49                  ; a name: its length, then the characters
fl_name_s:  equ #7C00               ; length, then "B:NAME.EXT" (or "IDE:GAMES/NAME.EXT")
fl_inname:  equ fl_name_s + FL_NL   ; the one being read's (33 going back)
fl_new_s:   equ fl_inname + FL_NL   ; (23: the new name)
FL_UB:      equ #7D00               ; BDOS 132's block (72 bytes)
FL_EXK:     equ #7D48               ; the folder DIR lists (its path: length, 31 characters)
FL_DATE:    equ #7D68               ; a date examine gives (7), then a name (11)
FL_TN:      equ #7D70
FL_MAP:     equ #7E00
            ASSERT #6000 + FL_CMAX * 64 <= fl_name_s, "the search's cache, below the names"
            ASSERT fl_new_s + FL_NL <= FL_UB, "the names, below BDOS 132's block"
            ASSERT (FL_MAP & 255) = 0, "FL_MAP: a page's start (fl_mapa)"
fl_cjf:     db 0                    ; 0: not looked for yet, 1: UniDOS, 2: none
fl_cj:      dw 0                    ; Ctrl J's far address (address, ROM)
            db 0
fl_cjn:     db #8A                  ; (its name)
fl_exv:     db 0                    ; FL_EXK's listing is the one UniDOS examines now ...
fl_exi:     dw 0                    ; ... at this entry next
fl_ue:      dw 0
; carry: UniDOS here (the first time: looked for, the paths cleared)
fl_uni:
            ld a, (fl_cjf)
            cp 1
            jr z, fl_un_y
            or a
            ret nz                  ; (2: none - NC)
            ld hl, fl_cjn
            call #BCD4              ; KL FIND COMMAND: C = its ROM, HL = its address
            di
            ld a, 2
            jr nc, fl_un_s
            ld (fl_cj), hl
            ld a, c
            ld (fl_cj + 2), a
            ld hl, FL_MAP
            ld de, FL_MAP + 1
            ld bc, 511
            ld (hl), 0
            ldir
            ld a, 1
fl_un_s:
            ld (fl_cjf), a
            jr fl_uni
fl_un_y:
            scf
            ret
; Ctrl J command C (the other registers its input; its output back)
fl_cjc:
            rst #18                 ; (RST 3: a far call)
            dw fl_cj
            di
            ret
; A = a drive letter: HL = its FL_MAP entry, A = its path's length (Z: none). Carry: not A-P,
; or no UniDOS (no paths). A, HL only
fl_mapa:
            sub 'A'
            cp 16
            ccf
            ret c
            ld l, a
            ld a, (fl_cjf)
            cp 1
            scf
            ret nz
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, h
            add a, FL_MAP / 256
            ld h, a
            ld a, (hl)
            or a
            ret
; A = a drive letter: "B:" at DE, or its path - DE past it (BC, HL kept)
fl_pfx:
            push af
            call fl_pfxm
            jr nz, fl_px_d
            pop af
            ld (de), a
            inc de
            ld a, ':'
            ld (de), a
            inc de
            ret
fl_px_d:
            pop af
            ret
; ... its path only, if it has one (NZ; Z: none, nothing put)
fl_pfxm:
            push hl
            call fl_mapa
            jr c, fl_pm_no
            jr z, fl_pm_no
            push bc
            ld c, a
            ld b, 0
            inc hl
            ldir
            pop bc
            or a
            jr fl_pm_r
fl_pm_no:
            xor a
fl_pm_r:
            pop hl
            ret
fl_nlen:                            ; fl_name_s's length: its characters end at DE
            ld hl, -(fl_name_s + 1)
            add hl, de
            ld a, l
            ld (fl_name_s), a
            ret
; the folder whose path is at fl_name_s + 1 to DE (fl_exdir2: fl_name_s, its length set)
; examined (Ctrl J 12): Z its listing ready (examine next: Ctrl J 13), NZ no UniDOS, a drive
; it can't examine (AMSDOS's floppies), not a folder
fl_exdir:
            call fl_nlen
fl_exdir2:
            call fl_uni
            jr nc, fl_ed_no
            xor a
            ld (fl_exv), a
            ld hl, fl_name_s
            ld b, (hl)
            inc hl
            ld ix, FL_DATE
            ld c, 12
            call fl_cjc
            ret c
fl_ed_no:
            ld a, 254               ; (254: no UniDOS, or a drive it can't examine)
            or a
            ret
; ---- 30: CP/M's set file attributes - not done here (255) - unless the block at DE (72 bytes)
; is CyborgOS's UniDOS call (CD, DIR): Byte(0) #C0 + the call (an FCB's drive byte is 0-16:
; never that), Byte(1) a drive letter (A-P). 255: no UniDOS (or a bad block). So Main sends it
; here with the other file calls, nothing of its own
;   0  UniDOS here: 0
;   1  the letter's path to Byte(2) (its length - 0 none -, the path)
;   2  the letter's path from Byte(2) (length, 31 at most - a "/" put at its end if it has no
;      "/" or ":" there -; 0: none, the letter itself again): it must be a folder (examined;
;      a drive UniDOS can't examine - DFA:, DFB:, AMSDOS's floppies - is taken as it is):
;      0 set, else UniDOS's error (not 0; 254 a drive it can't examine - a floppy AMSDOS has)
;   3  the devices (Ctrl J 1): 64 bytes at Byte(2) (names, the last character + #80, 255 the end)
;   4  a device (Ctrl J 2): its name at Byte(2) (the last character + #80) - 64 bytes at
;      Byte(8): the status (bit 0 there, 1 folders, 2 read only, 3 removable, 4 a stream, 5
;      the new API), -, free K (4 bytes), all K (4), the description (the last + #80)
;   5  the letter's folder's entry Word(2) (0 the first): Byte(4) its protection bits (bit 0
;      read only, 1 hidden, 2 system, 4 a folder), Byte(5-8) its size, Byte(9-15) its date (year
;      word, month, day, hours, minutes, seconds), Byte(16-26) its name (8 + 3): 0; 1 no more.
;      Byte(1) 0: the folder's path at Byte(28) (length, path) instead. One after another
;      (0, 1, 2 ...) each is the next examined, else the folder is examined again to it
;   6  a folder made: its path at Byte(2) (length, path ending "/": "IDE:GAMES/NEW/"): 0, else
;      UniDOS's error (255 also while a file is being written)
;   7  the header of the file this slot reads (the disc ROM's copy, 69 bytes - UniDOS's made-up
;      one for a file with none: its 24 bit length at 64 #800000) at Byte(2): 0; 255 none open
fl_unicall:
            ld hl, ({fcb})
            ld de, FL_UB
            ld b, 72
fl_uc_in:
            call fl_peek
            ld (de), a
            inc hl
            inc de
            djnz fl_uc_in
            ld a, (FL_UB)
            sub #C0
            cp 9
            jp nc, fp_done          ; (CP/M's 30)
            ld (FL_UB), a
            call fl_uni
            jp nc, fp_done
            ld a, (FL_UB)
            or a
            jp z, fl_ok
            dec a
            jp z, fl_uc_get
            dec a
            jp z, fl_uc_set
            dec a
            jp z, fl_uc_dev
            dec a
            jp z, fl_uc_inf
            dec a
            jp z, fl_uc_dir
            dec a
            jr z, fl_uc_md
            cp 2
            jr z, fl_uc_yes
            ld a, ({fin})           ; 7: the header of the file this slot reads (the disc ROM's,
            ld hl, fl_slot          ; from CAS IN OPEN: 69 bytes) to Byte(2)
            cp (hl)
            jp nz, fp_done
            ld hl, (fl_hdr)
            ld de, FL_UB + 2
            ld bc, 69
            ldir
            xor a
            ld b, 71
            jp fl_uc_back
fl_hdr:     dw 0
fl_uc_yes:                          ; 8: the next delete (19) may take a folder (RMDIR's)
            ld a, 1
            ld (fl_yes), a
            jp fl_ok
fl_yes:     db 0
fl_uc_md:                           ; 6: a folder made (CAS OUT OPEN, the path ending "/")
            ld a, ({fout})
            or a
            jp nz, fp_done
            ld hl, FL_UB + 2
            ld a, (hl)
            or a
            jp z, fp_done
            ld b, a
            inc hl
            ld de, #4800
            call #BC8C              ; CAS OUT OPEN
            di
            jr nc, fl_md_nc
            call #BC92              ; (a file: CAS OUT ABANDON - not made)
            di
            ld a, 1
            jr fl_md_r
fl_md_nc:
            and #7F
            cp #17                  ; (DSK_ERR_DIRECTORY_FOUND: made)
            jp z, fl_ok
            or a
            jr nz, fl_md_r
            inc a
fl_md_r:
            ld (fl_res), a
            jp fp_done
fl_uc_back:                         ; A the answer, the block's first B bytes back to the slot
            ld (fl_res), a
            ld a, (FL_UB)
            add a, #C0
            ld (FL_UB), a
            ld hl, ({fcb})
            ld de, FL_UB
fl_uc_out:
            ld a, (de)
            call fl_poke
            inc hl
            inc de
            djnz fl_uc_out
            jp fp_done
fl_uc_get:
            ld a, (FL_UB + 1)
            call fl_mapa
            jp c, fp_done
            ld de, FL_UB + 2
            ld c, (hl)
            ld b, 0
            inc bc
            ldir
            xor a
            ld b, 34
            jr fl_uc_back
fl_uc_dev:
            ld de, FL_UB + 2
            ld c, 1
            call fl_cjc
            jp nc, fp_done
            xor a
            ld b, 66
            jr fl_uc_back
fl_uc_inf:
            ld hl, FL_UB + 2
            ld de, FL_UB + 8
            ld c, 2
            call fl_cjc
            jp nc, fp_done
            xor a
            ld b, 72
            jr fl_uc_back
fl_uc_set:
            ld a, (FL_UB + 1)
            call fl_mapa
            jp c, fp_done
            ld (fl_ue), hl
            xor a
            ld (fl_exv), a
            ld a, (FL_UB + 2)
            or a
            jr z, fl_us_put         ; none: the letter itself again
            cp 32
            jp nc, fp_done
            ld b, a
            ld hl, FL_UB + 3
fl_us_up:                           ; capitals
            ld a, (hl)
            cp 'a'
            jr c, fl_us_c
            cp 'z' + 1
            jr nc, fl_us_c
            sub 32
            ld (hl), a
fl_us_c:
            inc hl
            djnz fl_us_up
            dec hl
            ld a, (hl)
            cp ':'
            jr z, fl_us_ex
            cp '/'
            jr z, fl_us_ex
            ld a, (FL_UB + 2)
            cp 31
            jp nc, fp_done
            inc a
            ld (FL_UB + 2), a
            inc hl
            ld (hl), '/'
fl_us_ex:
            ld hl, FL_UB + 2        ; a folder?
            ld de, fl_name_s
            ld bc, 32
            ldir
            call fl_exdir2
            jr z, fl_us_put
            cp 254
            jr z, fl_us_put         ; (a floppy AMSDOS runs - DFA:, DFB: - can't be examined: taken)
            or a
            jr nz, fl_us_err
            inc a
fl_us_err:
            ld (fl_res), a
            jp fp_done
fl_us_put:
            ld hl, FL_UB + 2
            ld de, (fl_ue)
            ld bc, 32
            ldir
            jp fl_ok
fl_uc_dir:
            ld de, fl_name_s + 1    ; the folder's path
            ld a, (FL_UB + 1)
            or a
            jr z, fl_ud_p
            call fl_pfx
            jr fl_ud_k
fl_ud_p:
            ld hl, FL_UB + 28
            ld a, (hl)
            cp 32
            jp nc, fp_done
            ld c, a
            ld b, 0
            inc hl
            ldir
fl_ud_k:
            call fl_nlen
            ld hl, fl_name_s        ; the same folder, still the one examined, at this entry:
            ld de, FL_EXK           ; on from there
            ld a, (fl_exv)
            or a
            jr z, fl_ud_new
            ld a, (hl)
            inc a
            ld b, a
fl_ud_cmp:
            ld a, (de)
            cp (hl)
            jr nz, fl_ud_new
            inc hl
            inc de
            djnz fl_ud_cmp
            ld hl, (fl_exi)
            ld de, (FL_UB + 2)
            or a
            sbc hl, de
            jr z, fl_ud_next
fl_ud_new:
            ld hl, fl_name_s
            ld de, FL_EXK
            ld bc, 32
            ldir
            call fl_exdir2
            jr z, fl_ud_ok
            or a
            jr nz, fl_us_err
            inc a
            jr fl_us_err
fl_ud_ok:
            ld hl, 0
            ld (fl_exi), hl
            ld a, 1
            ld (fl_exv), a
fl_ud_skip:                         ; on to entry Word(2)
            ld hl, (fl_exi)
            ld de, (FL_UB + 2)
            or a
            sbc hl, de
            jr z, fl_ud_next
            ld hl, FL_TN
            ld ix, FL_DATE
            ld c, 13
            call fl_cjc
            jr nc, fl_ud_end
            jr nz, fl_ud_end
            ld hl, (fl_exi)
            inc hl
            ld (fl_exi), hl
            jr fl_ud_skip
fl_ud_next:
            ld hl, FL_UB + 16
            ld ix, FL_UB + 9
            ld c, 13
            call fl_cjc
            jr nc, fl_ud_end
            jr nz, fl_ud_end
            ld (FL_UB + 4), a
            ld (FL_UB + 5), de
            ld (FL_UB + 7), bc
            ld hl, (fl_exi)
            inc hl
            ld (fl_exi), hl
            xor a
            ld b, 28
            jp fl_uc_back
fl_ud_end:
            xor a
            ld (fl_exv), a
            inc a
            ld (fl_res), a
            jp fp_done
fp_end:
            ASSERT fp_end <= #6000, "FileCall's page code: below the search's cache (#6000)"
; @endwindow
fl_exit:
#endasm
End Function

' FileShut(slot): its files closed (its program ended, was killed or reset)
Public Sub FileShut(ByVal slot As Integer)
#asm
            ld ({hsp}), sp
            ld sp, (ntc_csp)
            ld bc, ({hps})          ; (the buffers: the hypervisor's page)
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
' ---- the services (BDOS 131 ops 10, 11, 13, 14, 15: MON's, any program's): Z80 in a page of the
' hypervisor's own (the service page, C5: UseSvc), not main RAM - main RAM keeps the entry and
' the copy (it switches the window, so can't be in it). FileCall 99 put the code there from main
' RAM's #6000-#7FFF (window data). SvcVars gives it where Main keeps st(), sg(), ns, front, dp
'   10  up to 2K of memory to the slot (Byte(1) kind: 0 a 16K page Word(2), 1 an upper ROM, 2 main
'       RAM, 3 slot Word(2)'s memory; Word(4) the address, Word(6) where to, Word(8) how many; a
'       page or a ROM to its end)
'   11  the pointer (Byte(1) 0 off, 1 at column Byte(2), row Byte(3); only while in front)
'   13  2K block Word(2) of the slot's store from the slot (Word(6), Word(8)); 14 to the slot
'   15  a raw table to the slot at Word(2) (Byte(1): 0 the slots, 1 the memory, 2 the ROMs 0-31, 3 the
'       RAM discs)
' 0 done, 255 no such page / slot / table
Public Sub UseSvc()
#asm
            ld hl, (ntc_rampt)
            ld ({svp}), hl
#endasm
End Sub

Public Sub SvcVars(ByVal vst As Integer, ByVal vsg As Integer, ByVal vns As Integer, ByVal vfr As Integer, ByVal vdp As Integer)
  svst = vst : svsg = vsg : svns = vns : svfr = vfr : svdp = vdp
End Sub

' Svc(t, p, setting, buf): slot t's request at p (setting: its RAM setting; buf: 128 bytes of main
' RAM for the copies): the answer. Svc(0, 0, 0, buf): the services' code (#6000 to sv_end) from
' main RAM's own #4000-#7FFF (where the file put it) into the service page - once, at the start
Public Function Svc(ByVal t As Integer, ByVal p As Integer, ByVal setting As Integer, ByVal buf As Integer) As Integer
#asm
            ld ({hsp}), sp
            ld sp, (ntc_csp)
            ld (sv_ix), ix
            ld (sv_iy), iy
            di
            ld a, ({t})
            or a
            jr z, sv_inst
            ld bc, ({svp})
            out (c), c
            call sv_go              ; (in the service page) A = the answer
sv_back:
            di
            ld l, a
            ld h, 0
            ld ({result}), hl
            ld bc, (ntc_rampt)      ; the page that was in the window back
            out (c), c
            ld ix, (sv_ix)
            ld iy, (sv_iy)
            ld sp, ({hsp})
            jp sv_exit
sv_inst:
            ld hl, #6000
sv_in_lp:
            push hl
            ld bc, #7FC0            ; main RAM's own
            out (c), c
            ld de, ({buf})
            ld bc, 128
            ldir
            ld bc, ({svp})
            out (c), c
            pop de
            push de
            ld hl, ({buf})
            ld bc, 128
            ldir
            pop hl
            ld bc, 128
            add hl, bc
            ld de, sv_end
            or a
            sbc hl, de
            add hl, de
            jr c, sv_in_lp
            xor a
            jr sv_back
sv_ix:      dw 0
sv_iy:      dw 0
; sv_dx - A bytes (1-128) from HL to DE through buf: IX = HL's RAM setting, IY = DE's (0: none -
; main RAM outside the window); the service page back in the window after. HL, DE on past them
sv_dx:
            ld (sv_dxn), a
            push de
            ld de, ({buf})
            push ix
            pop bc
            inc b
            dec b
            jr z, sv_dx1
            out (c), c
sv_dx1:
            ld c, a
            ld b, 0
            ldir
            pop de
            push hl
            push iy
            pop bc
            inc b
            dec b
            jr z, sv_dx2
            out (c), c
sv_dx2:
            ld hl, ({buf})
            ld a, (sv_dxn)
            ld c, a
            ld b, 0
            ldir
            pop hl
            ld bc, ({svp})
            out (c), c
            ret
sv_dxn:     db 0
; @window
; ---- the service page's code (window data from #6000, copied there by FileCall 99)
            ds #6000 - $
sv_go:
            ld (sv_sp), sp
            ld hl, ({p})            ; the request (16 bytes) from the slot
            ld de, ({setting})
            call sv_sw
            push bc
            pop ix
            ld iy, ({svp})
            ld de, sv_blk
            ld a, 16
            call sv_dx
            ld hl, (sv_blk + 8)     ; how many: 2K at most
            bit 7, h
            jr nz, sv_n2
            ld de, 2049
            or a
            sbc hl, de
            add hl, de
            jr c, sv_n1
sv_n2:
            ld hl, 2048
sv_n1:
            ld (sv_n), hl
            xor a
            ld (sv_stop), a
            ld a, 2                 ; (the copies to the slot: its bank)
            ld (sv_dk), a
            ld hl, ({setting})
            ld (sv_ds), hl
            ld hl, (sv_blk + 6)
            ld (sv_da), hl
            ld a, (sv_blk)
            cp 10
            jp z, sv_mem
            cp 11
            jp z, sv_ptr
            cp 13
            jp z, sv_store
            cp 14
            jp z, sv_store
            cp 15
            jp z, sv_tab
sv_err:
            ld sp, (sv_sp)
            ld a, 255
            ret
sv_ok:
            ld sp, (sv_sp)
            xor a
            ret
; 10: memory
sv_mem:
            ld hl, (sv_blk + 4)
            ld (sv_sa), hl
            ld hl, (sv_blk + 2)
            ld a, (sv_blk + 1)
            or a
            jr nz, sv_m1
            ld de, (mem_count)      ; 0: a page (below Pages)
            push hl
            or a
            sbc hl, de
            pop hl
            jp nc, sv_err
            call sv_pgset
            ld (sv_ss), bc
            ld a, 1
            ld (sv_stop), a
            jr sv_mgo
sv_m1:
            dec a
            jr nz, sv_m2
            ld (sv_ss), hl          ; 1: a ROM
            ld a, 1
            ld (sv_stop), a
            ld a, 3
            jr sv_mgo1
sv_m2:
            dec a
            jr nz, sv_m3
            ld a, 4                 ; 2: main RAM
            jr sv_mgo1
sv_m3:
            dec a
            jp nz, sv_err
            call sv_slot            ; 3: a slot's memory (one in use)
            jp z, sv_err
            ld (sv_ss), de
            ld a, 2
            jr sv_mgo1
sv_mgo:
            ld a, 1
sv_mgo1:
            ld (sv_sk), a
            call sv_copy
            jr sv_ok
; HL = a slot number: Z when it isn't one in use, else DE = its RAM setting
sv_slot:
            ld a, h
            or a
            jr nz, sv_sl0
            or l
            ret z
            ld de, ({svns})
            ld a, (de)
            cp l
            jr c, sv_sl0
            add hl, hl
            push hl
            ld de, ({svst})
            add hl, de
            ld a, (hl)
            pop hl
            or a
            ret z
            ld de, ({svsg})
            add hl, de
            ld e, (hl)
            inc hl
            ld d, (hl)
            or 1                    ; (NZ)
            ret
sv_sl0:
            xor a
            ret
; 13 / 14: a 2K block of the store (13 from the slot, 14 to it)
sv_store:
            ld hl, (sv_blk + 2)
            ld a, h
            or a
            jp nz, sv_err
            ld a, l
            and 7
            add a, a
            add a, a
            add a, a
            ld (sv_sa + 1), a       ; the block's place in its page
            xor a
            ld (sv_sa), a
            srl l
            srl l
            srl l
            ld h, #FF               ; its page: the slot's byte at #FF00 + block / 8
            ld de, ({setting})
            call sv_sw
            push bc
            pop ix
            ld iy, ({svp})
            ld de, sv_tmp
            ld a, 1
            call sv_dx
            ld a, (sv_tmp)
            or a
            jp z, sv_err
            ld l, a
            ld h, 0
            call sv_pgset
            ld (sv_ss), bc
            ld a, 1
            ld (sv_sk), a
            ld a, (sv_blk)
            cp 14
            jr z, sv_st1
            ld hl, (sv_sa)          ; 13: the slot to the page
            ld (sv_da), hl
            ld hl, (sv_ss)
            ld (sv_ds), hl
            ld a, 1
            ld (sv_dk), a
            ld hl, (sv_blk + 6)
            ld (sv_sa), hl
            ld hl, ({setting})
            ld (sv_ss), hl
            ld a, 2
            ld (sv_sk), a
sv_st1:
            call sv_copy
            jp sv_ok
; 11: the pointer, while the slot is in front
sv_ptr:
            ld hl, ({svfr})
            ld a, (hl)
            ld hl, {t}
            cp (hl)
            jp nz, sv_ok
            ld a, ({pon})
            or a
            call nz, pt_xor
            xor a
            ld ({pon}), a
            ld a, (sv_blk + 1)
            or a
            jp z, sv_ok
            ld a, (sv_blk + 2)
            ld hl, {scc}
            cp (hl)
            jp nc, sv_ok            ; (off the screen: none)
            ld ({pox}), a
            ld a, (sv_blk + 3)
            ld ({poy}), a
            call pt_xor
            ld a, 1
            ld ({pon}), a
            jp sv_ok
pt_xor:                             ; the checkerboard XORed at pox, poy (the screen is main RAM)
            ld a, ({poy})
            ld e, a
            ld d, 0
            ld hl, 0
            ld a, ({scc})
            ld b, 8
pt_mul:
            add hl, hl
            rlca
            jr nc, pt_mn
            add hl, de
pt_mn:
            djnz pt_mul
            ld a, ({pox})
            ld e, a
            add hl, de
            ld de, ({sco})
            add hl, de
            ld a, h
            and #07
            or #C0
            ld h, a
            ld b, 4
pt_ln:
            ld a, (hl)
            xor #AA
            ld (hl), a
            ld a, h
            add a, 8
            ld h, a
            ld a, (hl)
            xor #55
            ld (hl), a
            ld a, h
            add a, 8
            ld h, a
            djnz pt_ln
            ret
; 15: a table
sv_tab:
            ld hl, (sv_blk + 2)
            ld (sv_da), hl
            ld a, (sv_blk + 1)
            or a
            jr z, sv_t0
            dec a
            jp z, sv_t1
            dec a
            jp z, sv_t2
            dec a
            jp z, sv_t3
            jp sv_err
; 0: the slots - a word how many, then from 16 a record each: state, in front, MODE, the name's
; length, the name
sv_t0:
            call sv_clr
            ld hl, ({svns})
            ld a, (hl)
            ld (sv_rec), a
            ld (sv_tn), a
            call sv_out16
            ld a, 1
            ld (sv_tj), a
sv_t0lp:
            ld a, (sv_tn)
            ld b, a
            ld a, (sv_tj)
            cp b
            jr z, sv_t0a
            jp nc, sv_ok
sv_t0a:
            ld hl, (sv_da)
            ld de, 16
            add hl, de
            ld (sv_da), hl
            call sv_clr
            ld a, (sv_tj)
            ld l, a
            ld h, 0
            add hl, hl
            ld de, ({svst})
            add hl, de
            ld a, (hl)
            ld (sv_rec), a          ; its state
            ld hl, ({svfr})
            ld a, (sv_tj)
            cp (hl)
            jr nz, sv_t0b
            ld a, 1
            ld (sv_rec + 1), a      ; in front
sv_t0b:
            ld a, (sv_rec)
            or a
            jr z, sv_t0d
            ld a, (sv_tj)           ; its RAM setting
            ld l, a
            ld h, 0
            add hl, hl
            ld de, ({svsg})
            add hl, de
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (sv_tsg), de
            ld hl, {CMODE}          ; MODE
            ld a, 1
            call sv_from
            ld a, (sv_tmp)
            ld (sv_rec + 2), a
            ld a, (sv_rec)
            cp 2
            jr nz, sv_t0d
            ld de, (sv_tsg)
            ld hl, #F6D8            ; the program's name: its length, then 12
            ld a, 13
            call sv_from
            ld a, (sv_tmp)
            cp 13
            jr c, sv_t0c
            ld a, 12
sv_t0c:
            ld (sv_rec + 3), a
            ld hl, sv_tmp + 1
            ld de, sv_rec + 4
            ld bc, 12
            ldir
sv_t0d:
            ld hl, sv_tj
            push hl
            call sv_out16
            pop hl
            inc (hl)
            jp sv_t0lp
; 1: the memory - words: the tables' end, the top, the pages, total K, free pages; from 16 a byte a page
sv_t1:
            call sv_clr
            ld hl, (mem_tend)
            ld (sv_rec), hl
            call mem_top
            ld (sv_rec + 2), hl
            ld hl, (mem_count)
            ld (sv_rec + 4), hl
            call mem_ramsize
            ld (sv_rec + 6), hl
            call mem_freepages
            ld (sv_rec + 8), hl
            ld hl, sv_rec
            ld de, (sv_da)
            ld bc, 18               ; (and pages 0, 1: 0)
            call sv_out
            ld hl, (mem_count)      ; pages 2 on: the RAT (2030 at most)
            dec hl
            ld a, h
            or l
            jp z, sv_ok
            ld de, 2031
            or a
            sbc hl, de
            add hl, de
            jr c, sv_t1a
            ld hl, 2030
sv_t1a:
            ld (sv_n), hl
            ld hl, (mem_ttype)
            inc hl
            ld (sv_sa), hl
            ld hl, (sv_blk + 2)
            ld de, 18
            add hl, de
            ld (sv_da), hl
            xor a
            ld (sv_sk), a
            ld (sv_stop), a
            call sv_copy
            jp sv_ok
; 2: the upper ROMs 0-31 - 64 bytes each: the first 16, then 48 of the name table (0s if none)
sv_t2:
            xor a
            ld (sv_tj), a
sv_t2lp:
            call sv_clr
            ld a, (sv_tj)
            ld c, a
            call #B90F              ; KL ROM SELECT (#C000 only: this code at #6000 stays)
            di
            push bc
            ld hl, #C000
            ld de, sv_rec
            ld bc, 16
            ldir
            ld hl, (sv_rec + 4)
            ld a, h
            and #C0
            cp #C0
            jr nz, sv_t2a
            ld de, #FF90
            or a
            sbc hl, de
            add hl, de
            jr nc, sv_t2a
            ld de, sv_rec + 16
            ld bc, 48
            ldir
sv_t2a:
            pop bc
            call #B918              ; KL ROM DESELECT
            di
            ld hl, sv_rec
            ld de, (sv_da)
            ld bc, 64
            call sv_out
            ld hl, (sv_da)
            ld de, 64
            add hl, de
            ld (sv_da), hl
            ld hl, sv_tj
            inc (hl)
            ld a, (hl)
            cp 32
            jr c, sv_t2lp
            jp sv_ok
; 3: the RAM discs - the driver's table (its page, #6A00: 128 bytes), 0s if none
sv_t3:
            call sv_clr
            ld hl, ({svdp})
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld a, d
            or e
            jr z, sv_t3a
            ex de, hl
            call sv_pgset
            ld (sv_ss), bc
            ld hl, #6A00
            ld (sv_sa), hl
            ld hl, 128
            ld (sv_n), hl
            ld a, 1
            ld (sv_sk), a
            xor a
            ld (sv_stop), a
            call sv_copy
            jp sv_ok
sv_t3a:
            ld hl, sv_rec
            ld de, (sv_da)
            ld bc, 128
            call sv_out
            jp sv_ok
; sv_from - A bytes from slot (sv_tsg's) HL into sv_tmp
sv_from:
            ld de, (sv_tsg)
            push af
            call sv_sw
            push bc
            pop ix
            ld iy, ({svp})
            ld de, sv_tmp
            pop af
            jp sv_dx
; sv_clr - sv_rec (128 bytes) 0
sv_clr:
            ld hl, sv_rec
            ld de, sv_rec + 1
            ld bc, 127
            ld (hl), 0
            ldir
            ret
; sv_out16 - sv_rec's first 16 to the slot at sv_da; sv_out - BC bytes from HL (here) to the slot's DE
sv_out16:
            ld hl, sv_rec
            ld de, (sv_da)
            ld bc, 16
sv_out:
            ld (sv_sa), hl
            ld (sv_da), de
            ld (sv_n), bc
            ld a, 1
            ld (sv_sk), a
            ld hl, ({svp})
            ld (sv_ss), hl
            xor a
            ld (sv_stop), a
            ld hl, (sv_da)
            push hl
            call sv_copy
            pop hl
            ld (sv_da), hl          ; (where it went: kept)
            ret
; sv_copy - sv_n bytes from the source (sv_sk: 0 main RAM outside the window, 1 a page - RAM setting
; sv_ss, 2 a bank - C2 setting sv_ss, 3 ROM sv_ss, 4 main RAM anywhere) at sv_sa to the
; destination (sv_dk: 1 a page, 2 a bank; sv_ds) at sv_da, 128 at most a go, none across a 16K
; page's end; sv_stop: at the source's page end, stop
sv_copy:
            ld hl, (sv_n)
            ld a, h
            or l
            ret z
            ld bc, 128
            or a
            sbc hl, bc
            add hl, bc
            jr nc, sc_c1
            ld b, h
            ld c, l
sc_c1:
            ld (sv_c), bc
            ld a, (sv_sk)
            or a
            jr z, sc_dl
            ld hl, (sv_sa)
            call sc_room
sc_dl:
            ld hl, (sv_da)
            call sc_room
            ld a, (sv_sk)           ; the source: IX its RAM setting, HL where
            ld hl, (sv_sa)
            ld ix, 0
            or a
            jr z, sc_sok
            cp 1
            jr nz, sc_s2
            ld ix, (sv_ss)
            call sc_win
            jr sc_sok
sc_s2:
            cp 2
            jr nz, sc_s3
            ld de, (sv_ss)
            call sv_sw
            push bc
            pop ix
            jr sc_sok
sc_s3:
            cp 3
            jr nz, sc_s4
            ld a, (sv_ss)           ; a ROM: its bytes into buf first
            ld c, a
            call #B90F              ; KL ROM SELECT
            di
            push bc
            ld hl, (sv_sa)
            ld a, h
            or #C0
            ld h, a
            ld de, ({buf})
            ld bc, (sv_c)
            ldir
            pop bc
            call #B918              ; KL ROM DESELECT
            di
            ld hl, ({buf})
            jr sc_sok
sc_s4:
            ld a, h                 ; main RAM: its #4000-#7FFF is page 1
            and #C0
            cp #40
            jr nz, sc_sok
            push hl
            ld hl, 1
            call sv_pgset
            pop hl
            push bc
            pop ix
sc_sok:
            push hl
            ld a, (sv_dk)           ; the destination: IY, DE
            ld hl, (sv_da)
            cp 1
            jr nz, sc_d2
            ld iy, (sv_ds)
            call sc_win
            jr sc_dok
sc_d2:
            ld de, (sv_ds)
            call sv_sw
            push bc
            pop iy
sc_dok:
            ex de, hl
            pop hl
            ld a, (sv_c)
            call sv_dx
            ld bc, (sv_c)
            ld hl, (sv_sa)
            add hl, bc
            ld (sv_sa), hl
            ld hl, (sv_da)
            add hl, bc
            ld (sv_da), hl
            ld hl, (sv_n)
            or a
            sbc hl, bc
            ld (sv_n), hl
            ld a, (sv_stop)
            or a
            jp z, sv_copy
            ld a, (sv_sa + 1)
            and #3F
            ld b, a
            ld a, (sv_sa)
            or b
            jp nz, sv_copy
            ret
sc_room:                            ; sv_c no more than to HL's 16K page's end
            ld a, h
            and #3F
            ld h, a
            ex de, hl
            ld hl, 16384
            or a
            sbc hl, de
            ld de, (sv_c)
            or a
            sbc hl, de
            ret nc
            add hl, de
            ld (sv_c), hl
            ret
sc_win:                             ; HL: its place in the window
            ld a, h
            and #3F
            or #40
            ld h, a
            ret
; sv_sw - DE = a bank's C2 setting, HL = an address in it: BC = the setting with its page in the
; window, HL = the address there
sv_sw:
            ld a, h
            rlca
            rlca
            and 3
            add a, 4
            ld b, a
            ld a, e
            and #F8
            or b
            ld c, a
            ld b, d
            jr sc_win
; sv_pgset - HL = a page: BC = its RAM setting (the Memory class's port table; 0 main RAM)
sv_pgset:
            ld a, h
            or l
            ld bc, #7FC0
            ret z
            add hl, hl
            ld de, (mem_tport)
            add hl, de
            dec hl
            ld b, (hl)
            dec hl
            ld c, (hl)
            ret
sv_sp:      dw 0
sv_n:       dw 0
sv_c:       dw 0
sv_sk:      db 0
sv_ss:      dw 0
sv_sa:      dw 0
sv_dk:      db 0
sv_ds:      dw 0
sv_da:      dw 0
sv_stop:    db 0
sv_tj:      db 0
sv_tn:      db 0
sv_tsg:     dw 0
sv_blk:     ds 16
sv_tmp:     ds 16
sv_rec:     ds 128
sv_end:
            ASSERT sv_end <= #8000, "the service page's code"
; @endwindow
sv_exit:
#endasm
End Function
#End If

#If NTC_LIBRARY_ROM Then
#Else
' Drive(letter): the disc system's |letter command run (KL FIND COMMAND, KL FAR PCALL: AMSDOS's
' |A / |B, UniDOS's, the M4's ...): True, or False when no ROM has that command (CD)
' A RAM disc's letter (the driver's 114) is True without a command. The letter is the drive
' the hypervisor's own reading (FileCall 100-104) is on from now (hdr)
Public Function Drive(ByVal letter As Integer) As Integer
#asm
            ld ({hsp}), sp
            ld sp, (ntc_csp)
            ld (dv_ix), ix
            ld (dv_iy), iy
            ld hl, 0
            ld ({result}), hl
            ld hl, ({letter})
            ld ({hdr}), hl
            IF NTC_ROMLIB = 0
            ld a, ({drs} + 1)
            or a
            jr z, dv_rsx
            ld (dv_blk + 2), hl
            di
            ld bc, ({drs})
            out (c), c
            ld ix, dv_blk
            call #4000
            ld bc, (ntc_rampt)
            out (c), c
            jr nc, dv_rsx
            ld hl, -1
            ld ({result}), hl
            jr dv_done
dv_blk:     dw 114, 0, 0, 0, 0, 0, 0
            ENDIF
dv_rsx:
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
