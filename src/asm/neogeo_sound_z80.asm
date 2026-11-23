; ============================================================
; NTC's Neo Geo sound driver: the Z80 program in a cartridge's M1 ROM
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
; ============================================================
; Not an NTC-threaded program: the Neo Geo gives the Z80 each byte the 68000
; writes to REG_SOUND ($320000) as an NMI, which pushes on SP - so this is a
; plain Z80 program with a real stack. The 68000 (ntc_ng_snd in the neogeo
; platform) writes a byte and waits for the answer on REG_SOUND: the NMI
; queues the byte and answers with its count of the bytes taken so far, so
; the 68000 knows each one arrived (even the same byte twice running).
;
; The main loop takes the queued bytes as messages (the first byte says which):
;   $01           (the BIOS) a slot switch is coming: nothing to do
;   $03           (the BIOS) a soft reset: the driver starts again
;   $10 r v       the YM2610's SSG (an AY-3-8910: 3 square waves, a noise, envelopes): register r
;                 (0-13) = v
;   $20 n         music: ADPCM-B sample n played round and round (the song table, n 0-31)
;   $21           music off
;   $22 v         the music's loudness (0-255)
;   $30 n c l     ADPCM-A sample n (the sample table, 0-63) played once on channel c (0-5) at
;                 loudness l (0-31)
;   $31 c         ADPCM-A channel c stopped
;   $32 c l       ADPCM-A channel c's loudness l (0-31)
;   $40 t         (Neo Geo CD) CD audio: track t (BCD) played, and played again at its end: the
;                 request goes in this RAM at $FEF8 (the command, $80 = a new one, play) and
;                 $FEF9 (the track), where the CD BIOS takes it each frame (SYSTEM_IO)
;   $41           (Neo Geo CD) CD audio stopped ($82: stop)
;   $50 r v       FM: the YM2610's register r ($21-$B6) = v on its first port (the LFO, the timers'
;                 mode, key on / off, and FM channels 1 and 2's registers)
;   $51 r v       FM: register r ($30-$B6) = v on its second port (FM channels 3 and 4's registers)
;   anything else is passed over
;
; The tables, in the ROM (a game's build writes them in: test/ngbuild.js --songs, --samples):
;   $0100  the songs: 32 x 8 bytes: start, end (256-byte units of the V ROM, little endian
;          words: end = the last unit), delta-N (the rate: 65536 = 55.5 kHz), loudness, 0
;   $0200  the samples: 64 x 4 bytes: start, end (256-byte units, as above)
;
; The Z80's memory: $0000-$7FFF this ROM, $F800-$FFFF RAM. Its ports: $00 in: the byte from the
; 68000; $0C out: the answer; $04/$05 the YM2610's first address / data port (the SSG, ADPCM-B,
; FM 1-2; reading $04: its status, bit 7 busy), $06/$07 the second (ADPCM-A, FM 3-4); $08 out:
; NMIs on; $18 out: NMIs off.
;   sjasmplus --raw=M1.BIN neogeo_sound_z80.asm
; On a Neo Geo CD the same program is the disc's .Z80 file, loaded into the Z80's RAM at 0:
; it runs in RAM there, the tables included.
; ============================================================
		device NONE
		org #0000
		di
		jp start

		ds #0038 - $, #FF
		ei						; (no interrupts are used: IM 1 lands here)
		reti

		ds #0066 - $, #FF
; ---- NMI: a byte from the 68000: queued, counted, answered
nmi:
		push af
		push hl
		in a, (#00)
		ld hl, (qw)
		ld (hl), a
		inc l					; (the queue is 256 bytes on a 256 byte edge)
		ld (qw), hl
		ld a, (count)
		inc a
		ld (count), a
		out (#0C), a
		pop hl
		pop af
		retn

		ds #0100 - $, #FF
songs:	ds 32 * 8, 0
samples: ds 64 * 4, 0

; ---- RAM
QUEUE	equ #F800				; 256 bytes
qw		equ #F900				; the queue's write and read positions
qr		equ #F902
count	equ #F904				; bytes taken
STACK	equ #0000				; (the stack's top: #FFFF down)

start:
		di
		ld sp, STACK
		im 1
		xor a
		out (#0C), a
		ld (count), a
		ld (CDREQ), a			; no CD audio request
		ld (CDREQ + 1), a
		ld hl, QUEUE
		ld (qw), hl
		ld (qr), hl
		call ym_init
		out (#08), a			; NMIs on
main:
		call get				; a = the next byte (waits)
		cp #10
		jp z, m_ssg
		cp #20
		jp z, m_song
		cp #21
		jp z, m_songoff
		cp #22
		jp z, m_songvol
		cp #30
		jp z, m_samp
		cp #31
		jp z, m_sampoff
		cp #32
		jp z, m_sampvol
		cp #40
		jp z, m_cdda
		cp #41
		jp z, m_cddaoff
		cp #50
		jp z, m_fma
		cp #51
		jp z, m_fmb
		cp #03
		jp z, m_reset
		jp main
m_reset:
		di
		out (#18), a
		jp start

m_ssg:
		call get
		ld d, a
		call get
		ld e, a
		ld a, d
		cp 14
		jp nc, main
		call ym_a
		jp main

m_song:
		call get
		and 31
		ld l, a
		ld h, 0
		add hl, hl
		add hl, hl
		add hl, hl
		ld bc, songs
		add hl, bc
		push hl
		ld de, #1001			; ADPCM-B: reset
		call ym_a
		ld de, #1000
		call ym_a
		ld de, #11C0			; both sides
		call ym_a
		pop hl
		ld d, #12				; start, end
		ld b, 4
ms_lp:
		ld e, (hl)
		inc hl
		call ym_a
		inc d
		djnz ms_lp
		ld d, #19				; delta-N
		ld e, (hl)
		inc hl
		call ym_a
		ld d, #1A
		ld e, (hl)
		inc hl
		call ym_a
		ld d, #1B				; loudness
		ld e, (hl)
		call ym_a
		ld de, #1090			; start, round and round
		call ym_a
		jp main
m_songoff:
		ld de, #1001
		call ym_a
		ld de, #1000
		call ym_a
		jp main
m_songvol:
		call get
		ld e, a
		ld d, #1B
		call ym_a
		jp main

m_samp:
		call get
		and 63
		ld l, a
		ld h, 0
		add hl, hl
		add hl, hl
		ld bc, samples
		add hl, bc				; hl: the sample's entry
		call get
		cp 6
		jr c, mp_c
		xor a
mp_c:
		ld c, a					; the channel
		call get
		and 31
		or #C0					; both sides
		ld e, a
		ld a, #08
		add a, c
		ld d, a
		call ym_b				; its loudness
		ld a, #10				; start low, start high, end low, end high
		add a, c
		ld d, a
		ld e, (hl)
		inc hl
		call ym_b
		ld a, #18
		add a, c
		ld d, a
		ld e, (hl)
		inc hl
		call ym_b
		ld a, #20
		add a, c
		ld d, a
		ld e, (hl)
		inc hl
		call ym_b
		ld a, #28
		add a, c
		ld d, a
		ld e, (hl)
		call ym_b
		call bit_c				; e = 1 << c: on
		ld d, #00
		call ym_b
		jp main
m_sampoff:
		call get
		cp 6
		jp nc, main
		ld c, a
		call bit_c
		ld a, e
		or #80
		ld e, a
		ld d, #00
		call ym_b
		jp main
m_sampvol:
		call get
		cp 6
		jr c, mv_c
		xor a
mv_c:
		ld c, a
		call get
		and 31
		or #C0
		ld e, a
		ld a, #08
		add a, c
		ld d, a
		call ym_b
		jp main

; FM: a register on the first / second port (below $20 they are the SSG's and the ADPCM's: left alone)
m_fma:
		call get
		ld d, a
		call get
		ld e, a
		ld a, d
		cp #20
		jp c, main
		call ym_a
		jp main
m_fmb:
		call get
		ld d, a
		call get
		ld e, a
		ld a, d
		cp #30
		jp c, main
		call ym_b
		jp main

; the CD BIOS's CD audio request: the track first, then the command (so the BIOS never takes a
; command with the last request's track)
CDREQ	equ #FEF8
m_cdda:
		call get
		ld (CDREQ + 1), a
		ld a, #80
		ld (CDREQ), a
		jp main
m_cddaoff:
		xor a
		ld (CDREQ + 1), a
		ld a, #82
		ld (CDREQ), a
		jp main

; e = 1 << c
bit_c:
		ld e, 1
		ld a, c
		or a
		ret z
bc_lp:
		sla e
		dec a
		jr nz, bc_lp
		ret

; get: a = the next queued byte (waits for one)
get:
		push hl
g_wait:
		ld hl, (qr)
		ld a, (qw)
		cp l
		jr z, g_wait
		ld a, (hl)
		inc l
		ld (qr), hl
		pop hl
		ret

; ym_a / ym_b: the YM2610's register d = e, first / second port (waits while it is busy)
ym_a:
		in a, (#04)
		rlca
		jr c, ym_a
		ld a, d
		out (#04), a
		ld a, e
		out (#05), a
		ret
ym_b:
		in a, (#04)
		rlca
		jr c, ym_b
		ld a, d
		out (#06), a
		ld a, e
		out (#07), a
		ret

; the chip quiet: the SSG's channels off, ADPCM-A and B stopped, the FM keys off
ym_init:
		ld de, #073F			; SSG: no tones, no noise
		call ym_a
		ld de, #0800
		call ym_a
		ld de, #0900
		call ym_a
		ld de, #0A00
		call ym_a
		ld de, #1001			; ADPCM-B reset
		call ym_a
		ld de, #1000
		call ym_a
		ld de, #1C00			; no flags from ADPCM-B
		call ym_a
		ld de, #00BF			; ADPCM-A: every channel stopped
		call ym_b
		ld de, #013F			; ADPCM-A: all of it loud
		call ym_b
		ld de, #2800			; FM: the keys off (channels 1, 2, 5, 6)
		call ym_a
		ld de, #2801
		call ym_a
		ld de, #2802
		call ym_a
		ld de, #2804
		call ym_a
		ld de, #2805
		call ym_a
		ld de, #2806
		call ym_a
		xor a
		ret

		ds #8000 - $, #FF		; 32K (the packer pads the ROM to its size)
