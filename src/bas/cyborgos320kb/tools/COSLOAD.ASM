; COSLOAD.BIN - CyborgOS 320K's boot loader (RUN"COSLOAD from BASIC; CYBORGOS.BAS runs it).
; Built for each CyborgOS build (gendsk.sh): COSZ.INC (packz.py) names the ready-made system
; drive files CYBORGOS.Z1 ... (Z's 16K pages, 32K a file) and how many pages Z keeps; COSCYB.INC
; has the CYBORGOS.BIN it starts (its end, its free RAM, its firmware top).
; All the work is here, not in CyborgOS: this program is gone (CYBORGOS.BIN loads over it) once
; CyborgOS runs, so CyborgOS's main RAM is as it was.
;   1 the ROMs started (KL ROM WALK) - AMSDOS, an IDE / SD interface's ... - as CYBORGOS.BIN
;     would itself; files from "d:" when CYBORGOS.BAS put "CYB d" at #BE80 (else no drive)
;   2 the banks counted as the Memory class does (markers bank 63 down to 0); Z's pages are the
;     ones the slow way gives it, after the slots take theirs: the driver page C6, the data pages
;     C7, then the bank after the slots' (the slots: half the banks, at most 20, banks 2 on)
;   3 Z kept when C6 already has it (the driver page's "CYBD" signature and D_POOL checksum at
;     #7F00: a reset); else, when Z fits, each Zn loaded to #1000 and copied, 2K at a time
;     through #0800, into its pages - last file first: Z1 (the driver page, with the signature)
;     last, so a load that stops part way leaves no Z that looks whole. Then D_POOL gets those
;     pages (page, RAM setting) and the signature its checksum. Z not loaded (it doesn't fit, a
;     file missing): CyborgOS makes Z from CYBORGOS.Z as before
;   4 a small loader put in screen RAM (#C780, its 2K buffer #E000: nothing needs the screen
;     then, so main RAM needs no more than CyborgOS itself): it loads CYBORGOS.BIN over this
;     program at #0040 and jumps there. CyborgOS finds the ROMs running
;     (as when CALLed), takes its slots' banks, then claims Z (ProbeDiscs)
; No CP/M, no NTC: firmware calls only (TXT OUTPUT, KM WAIT CHAR, CAS IN ..., KL ROM WALK).

            DEVICE AMSTRADCPC6128   ; (for SAVEAMSDOS)
            INCLUDE "COSCYB.INC"    ; CYB_END, CYB_FREE, CYB_FWBLK, CYB_FWTOP

COS_BUF     equ #0800               ; CAS IN OPEN's 2K buffer, then the copies' 2K step (and the probe's bytes)
COS_LOAD    equ #1000               ; a Z file (32K at most: to #8FFF)
LDR         equ #C780               ; the loader: in screen RAM (row 24 and the 48 bytes after it in the
LDR_BUF     equ #E000               ; first 2K block), its CAS IN OPEN buffer #E000-#E7FF - nothing
                                    ; needs the screen while CYBORGOS.BIN loads, and main RAM then needs
                                    ; no more than CyborgOS itself (it was past CYBORGOS.BIN's end: 2.1K)
FW_TOP      equ #A600               ; the firmware's top of free RAM with AMSDOS alone
NBANKS      equ 64                  ; the banks the Memory class looks for (Option Memory CPCExpansion 257)
MAXS        equ 20                  ; CyborgOS's most slots
D_POOL      equ #5400               ; the driver page's tables (in the window)
D_SIG       equ #7F00

            org #0040
cos:
            ld hl, cos_hi
            call puts
            ; the boot drive: "CYB d" at #BE80 - names are "d:NAME"
            ld hl, #BE80
            ld de, cyb_sig
            ld b, 4
cos_sig:
            ld a, (de)
            cp (hl)
            jr nz, cos_nodrv
            inc hl
            inc de
            djnz cos_sig
            ld a, (hl)
            cp 'a'
            jr c, cos_up
            sub 32
cos_up:
            ld (name), a
            ld (ldr_name - ldr_start + ldr_img), a
            ld a, ':'
            ld (name + 1), a
            ld (ldr_name - ldr_start + ldr_img + 1), a
            ld a, 2
            ld (pfx), a
            ld hl, ldr_name         ; the loader's name with the drive
            ld (ldr_np - ldr_start + ldr_img), hl
            ld a, ldr_nlen + 2
            ld (ldr_nl - ldr_start + ldr_img), a
cos_nodrv:
            ; the ROMs: as CYBORGOS.BIN's start code does (Option RomEnable All): not below its
            ; arrays' end
            ld de, CYB_FREE
            ld hl, #ABFF
            call #BCCB              ; KL ROM WALK
            inc hl                  ; the first byte the ROMs took
            ld (roms_at), hl
            ld de, FW_TOP
            or a
            sbc hl, de
            jr nc, cos_fwok         ; AMSDOS alone (or no more): CYBORGOS's top as built
            ld hl, (roms_at)        ; more: the event block and the top under the ROMs' RAM -
            ld de, -16              ; CYBORGOS.BIN's start code does that itself only when it
            add hl, de              ; starts the ROMs, so the loader puts it in for it
            ld (ldr_fw - ldr_start + ldr_img), hl
            ld de, CYB_FREE
            or a
            sbc hl, de
            jp c, cos_noroom
cos_fwok:
            ; the banks, and where Z's data pages go: page 4 * (slots + 2) - 2 on (the bank
            ; after the slots'); Z fits when its last page is one the machine has (4 * banks + 1)
            call probe
            cp 8
            jp c, cos_go            ; (under 576K: no Z - CyborgOS has none there either)
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            inc hl
            ld (pmax), hl           ; the last page
            srl a                   ; slots: half the banks, MAXS at most
            cp MAXS
            jr c, cos_ns
            ld a, MAXS
cos_ns:
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            ld de, 6
            add hl, de
            ld (zbase), hl          ; data page 1's page (data page 0: C7)
            call zkept
            jp z, cos_kept
            ld hl, COSZ_CLAIM - 1   ; Z's last page
            call pageno
            ex de, hl
            ld hl, (pmax)
            or a
            sbc hl, de
            jp c, cos_nofit
            call zdrop
            ld a, COSZ_FILES
            ld (fno), a
            ld hl, cosz_last        ; the last file's entry: loaded first
            ld (fent), hl
cos_file:
            ld hl, (pfx)            ; "d:" (2), or nothing (0), then the name
            ld de, name
            add hl, de
            ex de, hl
            ld hl, (fent)
            ld c, (hl)              ; its first page (0: the driver page)
            ld b, 0
            ld (pno), bc
            inc hl
            ld a, (hl)              ; its pages (1 or 2)
            ld (fpg), a
            inc hl
            ld a, (hl)              ; the name's length
            inc hl
            ld bc, COSZ_ENT - 3     ; (the name and its 0s)
            ldir
            ld hl, pfx
            add a, (hl)
            ld b, a
            ld hl, name
            ld de, COS_BUF
            call #BC77              ; CAS IN OPEN
            jp nc, cos_miss
            ld hl, COS_LOAD
            call #BC83              ; CAS IN DIRECT
            push af
            call #BC7A              ; CAS IN CLOSE
            pop af
            jp nc, cos_miss
            ld a, '.'
            call #BB5A
            ld hl, COS_LOAD         ; its pages: COS_LOAD + 16K each
            ld (src), hl
cos_page:
            ld hl, (pno)
            push hl
            inc hl
            ld (pno), hl
            pop hl
            call pageno
            call setting            ; BC = its RAM setting
            call copy16
            ld a, (fpg)
            dec a
            ld (fpg), a
            jr nz, cos_page
            ld hl, (fent)           ; the entry before this one
            ld bc, -COSZ_ENT
            add hl, bc
            ld (fent), hl
            ld a, (fno)
            dec a
            ld (fno), a
            jp nz, cos_file
            call zpool
            ld hl, cos_ok
            call puts
            jr cos_go
cos_kept:
            ld hl, cos_keep
            call puts
            jr cos_go
cos_nofit:
            ld hl, cos_small
            call puts
            jr cos_go
cos_miss:
            ld hl, cos_nofile
            call puts
            ld hl, name
            call puts               ; (its name, 0 ended: the entry's names are)
            ld hl, cos_slow
            call puts
cos_go:
            ; the loader above where CYBORGOS.BIN reaches, then to it
            ld hl, ldr_img
            ld de, LDR
            ld bc, ldr_len
            ldir
            jp LDR

cos_noroom:
            ld hl, cos_roms
            call puts
            ld a, (roms_at + 1)
            call hex
            ld a, (roms_at)
            call hex
            ld hl, cos_roms2
            call puts
            call #BB06              ; KM WAIT CHAR
            rst 0

; pageno - HL = Z's page n (0 the driver page): HL = its Memory page number (4, 5, then zbase on)
pageno:
            ld a, h
            or a
            jr nz, pn_data
            ld a, l
            cp 2
            jr nc, pn_data
            add a, 4
            ld l, a
            ret
pn_data:
            dec hl
            dec hl
            ld de, (zbase)
            add hl, de
            ret

; setting - HL = a page (2 up): BC = its RAM setting (C value, B port) - bank e = (page - 2) / 4
; (0 up, as the probe finds them: the Memory class's numbering), page (page - 2) And 3 of it
setting:
            dec hl
            dec hl
            ld a, l
            and 3
            add a, #C4
            ld c, a
            srl h
            rr l
            srl h
            rr l                    ; L = e
            ld a, l
            and 7
            add a, a
            add a, a
            add a, a
            add a, c
            ld c, a
            ld a, l
            rrca
            rrca
            rrca
            and 7
            ld b, a
            ld a, #7F
            sub b
            ld b, a
            ret

; probe - A = the 64K banks there (as the Memory class's probe finds them): a marker in page 0
; of bank 63 down to 0, then main RAM, each byte saved first and put back after; a bank the
; hardware doesn't decode reads a lower bank's marker
probe:
            di
            ld bc, #7FC0
            out (c), c
            ld a, (#4000)
            ld (COS_BUF + NBANKS), a
            ld hl, COS_BUF
            ld e, 0
pr_save:
            call pr_bc
            out (c), c
            ld a, (#4000)
            ld (hl), a
            inc hl
            inc e
            ld a, e
            cp NBANKS
            jr nz, pr_save
pr_mark:
            dec e
            call pr_bc
            out (c), c
            ld a, e
            add a, #40
            ld (#4000), a
            ld a, e
            or a
            jr nz, pr_mark
            ld bc, #7FC0
            out (c), c
            ld a, #A5
            ld (#4000), a
            ld d, 0                 ; (E = 0)
pr_read:
            call pr_bc
            out (c), c
            ld a, e
            add a, #40
            ld hl, #4000
            cp (hl)
            jr nz, pr_none
            inc d
pr_none:
            inc e
            ld a, e
            cp NBANKS
            jr nz, pr_read
            ld hl, COS_BUF + NBANKS
pr_back:
            dec e
            dec hl
            call pr_bc
            out (c), c
            ld a, (hl)
            ld (#4000), a
            ld a, e
            or a
            jr nz, pr_back
            ld bc, #7FC0
            out (c), c
            ld a, (COS_BUF + NBANKS)
            ld (#4000), a
            ei
            ld a, d
            ret
pr_bc:                              ; E = a bank (0-63): BC = its page 0's RAM setting
            ld a, e
            and 7
            add a, a
            add a, a
            add a, a
            add a, #C4
            ld c, a
            ld a, e
            rrca
            rrca
            rrca
            and 7
            ld b, a
            ld a, #7F
            sub b
            ld b, a
            ret

; zkept - Z there already (a reset)? The driver page (C6) in the window: "CYBD", #5A, #CB at
; #7F00 and the sum of D_POOL at #7F06. Z = kept
zkept:
            call drvin
            ld hl, D_SIG
            ld de, cyb_drv
            ld b, 6
zk_sig:
            ld a, (de)
            cp (hl)
            jr nz, drvout
            inc hl
            inc de
            djnz zk_sig
            call poolsum
            ld hl, (D_SIG + 6)
            or a
            sbc hl, de              ; Z when equal
            jr drvout

; zdrop - C6's signature cleared (a load that stops part way leaves no Z that looks whole)
zdrop:
            call drvin
            xor a
            ld (D_SIG), a
            jr drvout

; zpool - D_POOL's slots (owner not 0) given their pages and RAM settings, then the checksum
zpool:
            call drvin
            ld hl, D_POOL
            ld de, 1                ; Z's page 1: slot 0
zp_lp:
            ld a, (hl)
            or a
            jr z, zp_sum
            push de                 ; (Z's page n)
            push hl                 ; (the slot)
            ex de, hl
            call pageno
            push hl
            call setting
            pop de                  ; DE = the page
            pop hl
            push hl
            inc hl
            inc hl
            ld (hl), e
            inc hl
            ld (hl), d
            inc hl
            ld (hl), c
            inc hl
            ld (hl), b
            pop hl
            ld bc, 6
            add hl, bc
            pop de
            inc de
            jr zp_lp
zp_sum:
            call poolsum
            ld (D_SIG + 6), de
            ; (on to drvout)
drvout:
            push af
            ld bc, #7FC0
            out (c), c
            pop af
            ei
            ret

drvin:                              ; the driver page (C6) in the window
            ld hl, 0
            call pageno
            call setting
            di
            out (c), c
            ret

poolsum:                            ; DE = the sum of D_POOL's bytes (256 x 6)
            ld hl, D_POOL
            ld de, 0
            ld bc, #0600
ps_lp:
            ld a, (hl)
            add a, e
            ld e, a
            jr nc, ps_nc
            inc d
ps_nc:
            inc hl
            dec bc
            ld a, b
            or c
            jr nz, ps_lp
            ret

; copy16 - 16K from (src) into the page whose RAM setting is BC, 2K at a time through COS_BUF
; (main RAM's #4000-#7FFF is out of sight while the page is in the window); (src) moves on
copy16:
            ld (cset), bc
            ld hl, #4000
            ld (dst), hl
            ld a, 8
cp_step:
            push af
            ld hl, (src)
            ld de, COS_BUF
            ld bc, #800
            di
            ldir                    ; (main RAM: #7FC0)
            ld (src), hl
            ld bc, (cset)
            out (c), c
            ld hl, COS_BUF
            ld de, (dst)
            ld bc, #800
            ldir
            ld (dst), de
            ld bc, #7FC0
            out (c), c
            ei
            pop af
            dec a
            jr nz, cp_step
            ret

puts:
            ld a, (hl)
            or a
            ret z
            call #BB5A              ; TXT OUTPUT
            inc hl
            jr puts
hex:
            push af
            rrca
            rrca
            rrca
            rrca
            call hex_d
            pop af
hex_d:
            and 15
            add a, #90
            daa
            adc a, #40
            daa
            jp #BB5A

; the loader: copied to LDR and run there. CYBORGOS.BIN (from "d:") loaded at #0040 (over
; COSLOAD.BIN), the firmware top put in when the ROMs took more than AMSDOS's RAM, then
; CYBORGOS started
ldr_img:
            DISP LDR
ldr_start:
            ld hl, (ldr_np)
            ld a, (ldr_nl)
            ld b, a
            ld de, LDR_BUF
            call #BC77              ; CAS IN OPEN
            jr nc, ldr_fail
            ld hl, #0040            ; (its load address and entry: CYBORGOS.BIN is built at #0040)
            call #BC83              ; CAS IN DIRECT
            jr nc, ldr_fail
            call #BC7A              ; CAS IN CLOSE
            ld hl, (ldr_fw)
            ld a, h
            or l
            jr z, ldr_go
            ld (CYB_FWBLK), hl
            ld (CYB_FWTOP), hl
ldr_go:
            jp #0040
ldr_fail:
            ld hl, ldr_msg
ldr_puts:
            ld a, (hl)
            or a
            jr z, ldr_key
            call #BB5A
            inc hl
            jr ldr_puts
ldr_key:
            call #BB06
            rst 0
ldr_fw:     dw 0                    ; the firmware top for CYBORGOS (0: as built)
ldr_np:     dw ldr_name + 2         ; the name CAS IN OPEN gets, its length (COSLOAD: with "d:")
ldr_nl:     db ldr_nlen
ldr_name:   db "  CYBORGOS.BIN"     ; ("d:" put in front by COSLOAD)
ldr_nlen    equ 12
ldr_msg:    db 13, 10, "No CYBORGOS.BIN", 13, 10, "Press a key", 0
ldr_end:
            ENT
ldr_len     equ ldr_end - ldr_start

cyb_sig:    db "CYB "
cyb_drv:    db "CYBD", #5A, #CB
cos_hi:     db "CyborgOS ", 0
cos_ok:     db " Z", 13, 10, 0
cos_keep:   db "(Z kept)", 13, 10, 0
cos_small:  db "(Z from CYBORGOS.Z: not all of it fits)", 13, 10, 0
cos_nofile: db 13, 10, "No ", 0
cos_slow:   db ": Z from CYBORGOS.Z", 13, 10, 0
cos_roms:   db 13, 10, "The ROMs' RAM reaches down to #", 0
cos_roms2:  db ": no room for CyborgOS", 13, 10, "(fewer ROMs)", 13, 10, "Press a key", 13, 10, 0
roms_at:    dw 0
pfx:        dw 0                    ; 2: "d:" in front of the names, 0: none
pmax:       dw 0                    ; the machine's last page (4 * banks + 1)
zbase:      dw 0                    ; Z's data page 1's page (the bank after the slots')
fno:        db 0                    ; files left
fpg:        db 0                    ; this file's pages left
fent:       dw 0                    ; this file's entry in cosz_files
pno:        dw 0                    ; the Z page being copied (0: the driver page)
src:        dw 0
dst:        dw 0
cset:       dw 0
name:       ds 16                   ; "d:CYBORGOS.Zn", 0
            INCLUDE "COSZ.INC"      ; COSZ_FILES, COSZ_PAGES, COSZ_CLAIM, cosz_files (first page, pages, name's length, name)
cos_end:
            ASSERT cos_end <= COS_BUF, "COSLOAD.BIN must end below its buffer (#0800)"
            ASSERT LDR + ldr_len <= #C800, "COSLOAD.BIN: the loader doesn't fit in the screen's first 2K block's row 24"
            ASSERT CYB_END <= LDR, "COSLOAD.BIN: CYBORGOS.BIN would load over the loader"
            ASSERT COSZ_FILES > 0, "COSLOAD.BIN: no Z files"
            ASSERT COSZ_CLAIM >= COSZ_PAGES, "COSLOAD.BIN: Z keeps fewer pages than its files have"

            SAVEAMSDOS "COSLOAD.BIN", cos, cos_end - cos, cos
