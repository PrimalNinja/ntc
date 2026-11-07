; ============================================================
; Neo Geo Z80 sound driver (conventional, NMI-driven)   *** DRAFT / UNTESTED ***
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
; ============================================================
; NOT an NTC-threaded program. The Neo Geo delivers each sound command from
; the 68k as a Z80 **NMI**, which auto-pushes PC onto SP - so NTC's SP-as-IP
; model can't run here (the push lands in the thread). This is therefore a
; plain Z80 driver with a real stack: NMI-safe by construction. The 68k game
; (NTC, md backend) talks to it through REG_SOUND ($320000) only.
;
; HANDSHAKE (the fixed Neo Geo mechanism):
;   68k writes a command byte to $320000  ->  Z80 takes an NMI
;   Z80 NMI reads the command on port $00, queues it, acks on port $0C
;   68k reads $320000 to get the ack
;
; Assembles with sjasmplus (syntax verified). Behaviour is NOT verified - no
; Neo Geo / MAME here. Ports marked ;!!NG need confirming against the hardware
; (YM2610 port pair, the NMI-enable port, the ROM-bank ports).
; ============================================================
		org #0000

; ---- reset: the Z80 boots here (M1 ROM at #0000) ----
		di
		ld sp, #FFFC			; real stack at the top of the Z80's 2K work RAM (#F800-#FFFF) ;!!NG confirm RAM window
		jp setup

		; the NMI vector is #0066 (fixed by the Z80); keep the bytes between
		; reset and #0066 clear so a jp sits exactly at the vector
		ds #0066 - $, 0

; ---- NMI: a command is waiting from the 68k ----
nmi:
		push af
		push hl
		in a, (#00)				; the command byte the 68k sent      ;!!NG port $00 = command in
		ld hl, cmd_queue_w
		ld (cmd_pending), a		; simplest: latest command wins (a real driver rings a queue)
		ld a, 1
		ld (cmd_flag), a
		ld a, (cmd_pending)
		out (#0C), a			; ack back to the 68k (read at $320000) ;!!NG port $0C = reply out
		pop hl
		pop af
		retn

; ---- setup: init the YM2610, enable NMI, then the main loop ----
setup:
		call ym_init
		xor a
		ld (cmd_flag), a
		; enable the NMI from the 68k command port
		ld a, 1
		out (#18), a			; ;!!NG NMI-enable port (commonly $18 on Neo Geo)
		 ei						; (NMI is non-maskable; EI is for any mode-1 use)

main:
		ld a, (cmd_flag)
		or a
		jr z, main_tick
		xor a
		ld (cmd_flag), a
		ld a, (cmd_pending)
		call do_command
main_tick:
		call ym_service			; service YM2610 timers / step the music frame
		jr main

; ---- act on a command byte (0 = silence; 1.. = tracks / sfx) ----
do_command:
		or a
		jr nz, dc_play
		jp ym_silence
dc_play:
		; map the command byte to a track/sfx table entry and start it
		; (the music/sfx data and player live below - stubbed here)
		ret

; ---- YM2610 (stubs: the real register writes go here) ----
; The YM2610 is reached through a port pair: address then data, two banks
; (A1/D1 for part 1, A2/D2 for part 2).                     ;!!NG confirm the 4 ports
YM_A1	equ #04
YM_D1	equ #05
YM_A2	equ #06
YM_D2	equ #07

; ym_reg - write A to YM2610 part-1 register C
ym_reg:
		out (YM_A1), a			; ... this is a skeleton; real code loads C=reg, A=val
		ret

ym_init:
		; reset the chip, clear channels, set timers for the music tick
		ret
ym_service:
		; per-frame: advance the active track, feed the ADPCM-A/B sample channels
		ret
ym_silence:
		; key-off all channels
		ret

; ---- driver state (Z80 work RAM) ----
cmd_pending:	db 0
cmd_flag:		db 0
cmd_queue_w:	db 0

		; pad the image to a ROM size the cart expects (set by the packer)
