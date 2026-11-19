; z80pcm.asm - TIANLONG for the Mega Drive: the music player, on the Z80. 4-bit DPCM samples (two a
; byte, the high nibble first) streamed from the 68000's ROM through the Z80's bank window
; ($8000-$FFFF: 32K of the 68000's space, chosen by 9 bits written to $6000) to the YM2612's DAC.
; Each nibble picks a step from DELTAS (it never takes the value past 0 or 255: tools/md_music.js
; packs them so). The YM2612's Timer A times each sample: 7 of its counts (144 / 7670454 s each),
; 7610 a second - the same whatever the Z80 waits for the 68000's bus.
; (c) 2026 Cyborg Unicorn Pty Ltd
;   sjasmplus z80pcm.asm --raw=Z80PCM.BIN      (build.js does it)
;
; The 68000 talks to it through MBOX (it takes the Z80's bus to write there):
;   +0  1 play, 2 stop (the Z80 clears it when it has read it)
;   +1  the first 32K block (the 68000's address / 32768: 9 bits, low byte first)
;   +3  how many blocks (16 bits, low byte first)
;   +5  1: round again at the end, 0: stop

MBOX        equ $1F00
YM0         equ $4000
YM1         equ $4001
BANK        equ $6000

            org 0
            di
            im 1
            ld sp, $1FF0
            jp start

            ds $38 - $
            ret

            ds $100 - $
deltas:     ; the steps (at a 256 boundary: D its page, E the nibble)
            db 0, 1, 2, 4, 8, 16, 32, 64, -128, -1, -2, -4, -8, -16, -32, -64

first:      dw 0            ; the song's first block
blocks:     dw 0            ; its length in blocks
loop:       db 0
cur:        dw 0            ; the block playing
left:       dw 0            ; the blocks still to play

start:      call ymwait
            ld a, $2B       ; the DAC on
            ld (YM0), a
            call ymwait
            ld a, $80
            ld (YM1), a
            call ymwait
            ld a, $B6       ; channel 6 to both speakers (part II)
            ld ($4002), a
            call ymwait
            ld a, $C0
            ld ($4003), a
            call ymwait
            ld a, $24       ; Timer A = 1017: 7 x 144 / 7670454 s (7610 samples a second)
            ld (YM0), a
            ld a, 1017 >> 2
            ld (YM1), a
            call ymwait
            ld a, $25
            ld (YM0), a
            ld a, 1017 & 3
            ld (YM1), a
            call ymwait
            ld a, $27       ; it runs, its flag on
            ld (YM0), a
            ld a, $15
            ld (YM1), a
            call ymwait
            ld a, $2A       ; the DAC's value from now on
            ld (YM0), a
            ld a, $80
            ld (YM1), a
idle:       ld a, (MBOX)
            or a
            jr z, idle
command:    cp 1
            jr z, cmd_play
            xor a           ; stop: silence
            ld (MBOX), a
            ld a, $80
            ld (YM1), a
            jr idle
cmd_play:   ld hl, (MBOX + 1)
            ld (first), hl
            ld hl, (MBOX + 3)
            ld (blocks), hl
            ld a, (MBOX + 5)
            ld (loop), a
            xor a
            ld (MBOX), a
            ld c, $80
again:      ld hl, (first)
            ld (cur), hl
            ld hl, (blocks)
            ld (left), hl
block:      ld hl, (left)
            ld a, h
            or l
            jr z, ended
            dec hl
            ld (left), hl
            ld de, (cur)
            call setbank
            inc de
            ld (cur), de
            ld d, high deltas
            ld hl, $8000
byte:       ld a, (hl)              ; the high nibble
            ld b, a
            rrca
            rrca
            rrca
            rrca
            and $0F
            call sample
            ld a, b                 ; the low nibble
            and $0F
            call sample
            inc l
            jr nz, byte
            inc h                   ; every 256 bytes: the block's end? a command?
            jp z, block
            ld a, (MBOX)
            or a
            jr z, byte
            jp command
ended:      ld a, (loop)
            or a
            jp nz, again
            ld a, $80
            ld (YM1), a
            jp idle

; sample: the next sample (nibble A: its step) when Timer A says it's time; then the timer again
sample:     ld e, a
            ld a, (de)
            add a, c
            ld c, a
sm_wait:    ld a, (YM0)             ; Timer A's flag
            rrca
            jr nc, sm_wait
            ld a, $27               ; the flag cleared, the timer reloaded
            ld (YM0), a
            ld a, $15
            ld (YM1), a
            call ymwait
            ld a, $2A               ; the DAC
            ld (YM0), a
            ld a, c
            ld (YM1), a
            ret

; setbank: the window on block DE (9 bits, the lowest first, each in bit 0 of a write to BANK)
setbank:    push hl
            push bc
            ld hl, BANK
            ld a, e
            ld b, 8
sb_lp:      ld (hl), a
            rrca
            djnz sb_lp
            ld (hl), d
            pop bc
            pop hl
            ret

ymwait:     ld a, (YM0)
            rlca
            jr c, ymwait
            ret
