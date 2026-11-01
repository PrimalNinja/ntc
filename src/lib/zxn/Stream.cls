' Stream - music streamed from a file on the SD card to the Next's DACs: as long as the card holds.
' (c) 2026 Cyborg Unicorn Pty Ltd
'
'   If Stream.Open("HCASE1.MUS") = 0 Then ...    ' the file: 8-bit unsigned samples, 12324 a second
'   Stream.Fill                                 ' once a frame (and around long jobs)
'   Stream.Close
'
' The DMA plays a ring of 2048 bytes (#F400, bank 5) to the DACs (port #DF) round and round, paced
' by its prescaler (875kHz / 71 = 12324 Hz), as UMBRELLA's and HEADCASE's music did from the NEX's
' banks. Fill reads where the DMA has got to and reads the file straight into the part of the ring
' it has played (esxDOS F_READ, about 250 bytes a frame); at the file's end it seeks back to the
' start (the music loops) and reads on. The ring holds 166 ms: nothing may run longer than that
' between two Fills.
'
' The esxDOS calls (NextZXOS's esxDOS API, RST 8 and a hook byte) go through a small routine Open
' copies to #FC00 (bank 5's second page, slot 7 - never mapped out): a stack of its own there, the
' ROM in slots 0-1 and ROM 3 selected (NextReg #8E = 3: the NEX stub lets only RST 8 with ROM 3
' page DivMMC in - NextRegs #B8, #B9, #BB), bank 5's first page in slot 2 (the standard #4000: the
' ROM's interrupt handler writes its system variables at #5C00 should the DOS let one in), RST 8;
' then ROM 0 (no RST 8 can page DivMMC in), the slots as they were, interrupts as they were. As
' CyborgOS's SD drive does (tested on NextZXOS 2.06H). The NEX must be started by NextZXOS (the
' browser, .nexload, an autoexec) - loaded as a snapshot, esxDOS answers every call with an error.
' The file is found in the current folder (the NEX's, when the browser starts it).
Option Explicit

Public Const OK = 0
Public Const NotFound = 1          ' the file couldn't be opened (or no esxDOS)

' Open name: the music file opened and playing (0), or NotFound (the DMA stays silent)
Public Function Open(ByVal name As String) As Integer
#asm
            ld hl, st_rout          ; the routine to #FC00 (each time: cheap, and nothing else is there)
            ld de, #FC00
            ld bc, st_routend - st_rout
            ldir
            ld hl, {name}           ; the name (ASCIIZ) to the routine's buffer: the DOS can't see
            ld de, sx_name          ; the program's pages during a call (a String parameter makes
                                    ; this a procedure: the name is its local, the result {Open})
            ld b, 63
st_nm:
            ld a, (hl)
            ld (de), a
            inc hl
            inc de
            or a
            jr z, st_nmz
            djnz st_nm
            xor a
            ld (de), a
st_nmz:
            ld a, (st_h)            ; a file open already: closed first
            or a
            jr z, st_op
            dec a
            ld (sx_a), a
            ld a, #9B               ; F_CLOSE
            ld (sx_hook), a
            ld ix, st_op
            jp sx_go
st_op:
            xor a
            ld (st_h), a
            ld a, '*'               ; F_OPEN: the current drive, IX the name, B 1: to read
            ld (sx_a), a
            ld hl, sx_name
            ld (sx_ix), hl
            ld hl, #0100
            ld (sx_bc), hl
            ld a, #9A
            ld (sx_hook), a
            ld ix, st_op2
            jp sx_go
st_op2:
            ld a, (sx_rf)
            and 1
            ld de, 1                ; carry: not found
            jr nz, st_ret
            ld a, (sx_ra)
            inc a
            ld (st_h), a            ; the handle + 1
            ld a, (st_on)           ; the DMA, the first time: the DACs on, the ring silent, started
            or a
            jr nz, st_op3
            ld bc, #243B
            ld a, 8
            ld (ntc_zxsel), a
            out (c), a
            inc b
            in a, (c)
            or 8
            out (c), a
            ld hl, #F400
            ld de, #F401
            ld bc, 2047
            ld (hl), #80
            ldir
            ld hl, 0
            ld (st_wp), hl
            ld hl, st_dma
            ld bc, (st_dmaend - st_dma) * 256 + #6B
            otir
            ld a, 1
            ld (st_on), a
st_op3:
            ld de, 0
st_ret:
            ld ({Open}), de
            jp st_end

st_dma:
            db #83, #C3, #C7, #CB    ; disable, reset, reset port timings
            db #7D                  ; WR0: A to B, port A's address and the length follow
            dw #F400, 2048
            db #54, #02              ; WR1: port A memory, incrementing; its timing
            db #68, #22, 71         ; WR2: port B an I/O port, fixed; its timing, the prescaler
            db #CD                  ; WR4: burst mode, port B's address follows
            dw #00DF
            db #A2, #CF, #87         ; WR5: auto restart; load; enable
st_dmaend:
@st_on:     db 0                    ; 1: the DMA is playing the ring
@st_h:      db 0                    ; the file's handle + 1 (0: none)
@st_wp:     dw 0                    ; the ring: where the file goes in next
@st_n:      dw 0                    ; bytes still to read this time
@st_c:      dw 0                    ; bytes this go
@st_loops:  db 0                    ; the file's end met this Fill (twice: give up - an empty file)

; ---- the routine at #FC00: an esxDOS call. In: (sx_hook) the hook, (sx_a) A, (sx_bc), (sx_de),
; (sx_hl), (sx_ix); IX the return (JP (IX): no CALL here - SP is NTC's thread). Out: (sx_ra) A,
; (sx_rf) F, (sx_rbc) BC, (sx_rde) DE
st_rout:
            DISP #FC00
@sx_go:
            ld (sx_ret), ix
            ld (sx_sp), sp
            ld sp, sx_stk
            ld a, i                 ; interrupts as they were (P/V: IFF2)
            ld a, 0
            jp po, sx_d
            inc a
sx_d:
            ld (sx_ei), a
            di
            ld bc, #243B
            ld hl, sx_mmu
            ld a, #50               ; MMU 0, 1, 2 kept
            out (c), a
            inc b
            in a, (c)
            ld (hl), a
            inc hl
            dec b
            ld a, #51
            out (c), a
            inc b
            in a, (c)
            ld (hl), a
            inc hl
            dec b
            ld a, #52
            out (c), a
            inc b
            in a, (c)
            ld (hl), a
            dec b
            ld a, #50               ; the ROM in slots 0, 1; bank 5's first page in slot 2
            out (c), a
            inc b
            ld a, #FF
            out (c), a
            dec b
            ld a, #51
            out (c), a
            inc b
            ld a, #FF
            out (c), a
            dec b
            ld a, #52
            out (c), a
            inc b
            ld a, 10
            out (c), a
            dec b
            ld a, #8E               ; ROM 3 (bit 3 off: slots 6, 7 kept)
            out (c), a
            inc b
            ld a, #03
            out (c), a
            ld a, (sx_hook)
            ld (sx_rst + 1), a
            ld a, (sx_a)
            ld bc, (sx_bc)
            ld de, (sx_de)
            ld hl, (sx_hl)
            ld ix, (sx_ix)
sx_rst:     rst 8
            db 0
            di
            ld (sx_ra), a
            push af
            pop hl
            ld a, l
            ld (sx_rf), a
            ld (sx_rbc), bc
            ld (sx_rde), de
            ld bc, #243B
            ld a, #8E               ; ROM 0: no RST 8 pages DivMMC in now
            out (c), a
            inc b
            xor a
            out (c), a
            dec b
            ld hl, sx_mmu
            ld a, #50
            out (c), a
            inc b
            ld a, (hl)
            out (c), a
            inc hl
            dec b
            ld a, #51
            out (c), a
            inc b
            ld a, (hl)
            out (c), a
            inc hl
            dec b
            ld a, #52
            out (c), a
            inc b
            ld a, (hl)
            out (c), a
            ld a, (ntc_zxsel)       ; the NextReg NTC's code had selected, selected again
            dec b
            out (c), a
            ld sp, (sx_sp)
            ld ix, (sx_ret)
            ld a, (sx_ei)
            or a
            jr z, sx_x
            ei
sx_x:
            jp (ix)
@sx_hook:   db 0
@sx_a:      db 0
@sx_bc:     dw 0
@sx_de:     dw 0
@sx_hl:     dw 0
@sx_ix:     dw 0
@sx_ra:     db 0
@sx_rf:     db 0
@sx_rbc:    dw 0
@sx_rde:    dw 0
sx_ret:     dw 0
sx_sp:      dw 0
sx_ei:      db 0
sx_mmu:     ds 3
@sx_name:   ds 64
            ds 256                  ; the call's stack (the DOS's too)
sx_stk:
            ENT
st_routend:
st_end:
#endasm
End Function

' Fill: the part of the ring played since last time, read from the file (on from its start at
' the end); nothing when no file is open
Public Sub Fill()
#asm
            ld a, (st_h)
            or a
            jp z, sf_done
            ld a, #BB               ; where the DMA is: port A's address
            out (#6B), a
            ld a, #18
            out (#6B), a
            ld a, #A7
            out (#6B), a
            in a, (#6B)
            ld l, a
            in a, (#6B)
            ld h, a
            ld de, #F400
            or a
            sbc hl, de
            ld de, (st_wp)
            or a
            sbc hl, de
            ld a, h
            and 7
            ld h, a                 ; bytes played since: (read - write) mod the ring
            ld (st_n), hl
            xor a
            ld (st_loops), a
sf_lp:
            ld hl, (st_n)
            ld a, h
            or l
            jp z, sf_done
            ld hl, 2048             ; this go: no further than the ring's end
            ld de, (st_wp)
            or a
            sbc hl, de
            ex de, hl
            ld hl, (st_n)
            or a
            sbc hl, de
            jr nc, sf_c1
            add hl, de
            ex de, hl
sf_c1:
            ld (st_c), de           ; F_READ: A the handle, IX where, BC how many
            ld (sx_bc), de
            ld hl, (st_wp)
            ld de, #F400
            add hl, de
            ld (sx_ix), hl
            ld a, (st_h)
            dec a
            ld (sx_a), a
            ld a, #9D
            ld (sx_hook), a
            ld ix, sf_r
            jp sx_go
sf_r:
            ld a, (sx_rf)
            and 1
            jr nz, sf_stop          ; an error: the stream stops (the ring plays what it has)
            ld de, (sx_rbc)         ; DE = bytes read
            ld hl, (st_wp)
            add hl, de
            ld a, h
            and 7
            ld h, a
            ld (st_wp), hl
            ld hl, (st_n)
            or a
            sbc hl, de
            ld (st_n), hl
            ld hl, (st_c)           ; fewer than asked: the file's end - back to its start
            or a
            sbc hl, de
            jr z, sf_lp
            ld a, (st_loops)
            inc a
            ld (st_loops), a
            cp 3
            jr nc, sf_stop
            ld a, (st_h)            ; F_SEEK: A the handle, BCDE the place, IXL 0: from the start
            dec a
            ld (sx_a), a
            ld hl, 0
            ld (sx_bc), hl
            ld (sx_de), hl
            ld (sx_ix), hl
            ld a, #9F
            ld (sx_hook), a
            ld ix, sf_lp
            jp sx_go
sf_stop:
            xor a
            ld (st_h), a
sf_done:
#endasm
End Sub

' Close: the file closed, the ring silent (the DMA plays on, quietly)
Public Sub Close()
#asm
            ld a, (st_h)
            or a
            jr z, sc_q
            dec a
            ld (sx_a), a
            xor a
            ld (st_h), a
            ld a, #9B               ; F_CLOSE
            ld (sx_hook), a
            ld ix, sc_q
            jp sx_go
sc_q:
            ld hl, #F400
            ld de, #F401
            ld bc, 2047
            ld (hl), #80
            ldir
#endasm
End Sub

' Playing(): True while a file is streaming
Public Function Playing() As Integer
#asm
            ld de, 0
            ld a, (st_h)
            or a
            jr z, sp_no
            dec de
sp_no:
            pop hl
            ld (hl), e
            inc hl
            ld (hl), d
#endasm
End Function
