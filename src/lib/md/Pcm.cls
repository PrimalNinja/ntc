' Pcm - music on the Mega Drive: songs as 4-bit DPCM (7610 samples a second) played by the Z80 on
' the YM2612's DAC, straight from the ROM, while the 68000 runs the game. NTC platform class:
' Sega Mega Drive / Genesis (first written for TIANLONG). (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'   Pcm.Init data    the Z80's player loaded and started. data: the songs' address (a Long), on a
'                    32K edge of the ROM (in #asm: align 15 before the incbin)
'   Pcm.Play n, lp   song n (0-4) from its start; lp 1: round again at its end
'   Pcm.Quiet        the music stopped
' The songs' data (tools/md/dpcm.js makes it): 5 x (a word: the song's first 32K block from the
' data's start, a word: its blocks), then the songs in 32K blocks. The Z80's player is
' tools/md/z80pcm.asm (sjasmplus z80pcm.asm --raw=Z80PCM.BIN: its 554 bytes are below).
Option Explicit

Private mb As Long

Public Sub Init(ByVal data As Long)
    mb = data
    Z80.Load Player(), 554
    Z80.Poke &H1F00, 0
End Sub

Private Function Player() As Long
#asm
            movea.l (sp)+, a0
            move.l #pc_z80, (a0)
            bra pc_end
pc_z80:
            dc.b $F3, $ED, $56, $31, $F0, $1F, $C3, $19, $01, $00, $00, $00, $00, $00, $00, $00
            dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
            dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
            dc.b $00, $00, $00, $00, $00, $00, $00, $00, $C9, $00, $00, $00, $00, $00, $00, $00
            dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
            dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
            dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
            dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
            dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
            dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
            dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
            dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
            dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
            dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
            dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
            dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
            dc.b $00, $01, $02, $04, $08, $10, $20, $40, $80, $FF, $FE, $FC, $F8, $F0, $E0, $C0
            dc.b $00, $00, $00, $00, $00, $00, $00, $00, $00, $CD, $23, $02, $3E, $2B, $32, $00
            dc.b $40, $CD, $23, $02, $3E, $80, $32, $01, $40, $CD, $23, $02, $3E, $B6, $32, $02
            dc.b $40, $CD, $23, $02, $3E, $C0, $32, $03, $40, $CD, $23, $02, $3E, $24, $32, $00
            dc.b $40, $3E, $FE, $32, $01, $40, $CD, $23, $02, $3E, $25, $32, $00, $40, $3E, $01
            dc.b $32, $01, $40, $CD, $23, $02, $3E, $27, $32, $00, $40, $3E, $15, $32, $01, $40
            dc.b $CD, $23, $02, $3E, $2A, $32, $00, $40, $3E, $80, $32, $01, $40, $3A, $00, $1F
            dc.b $B7, $28, $FA, $FE, $01, $28, $0B, $AF, $32, $00, $1F, $3E, $80, $32, $01, $40
            dc.b $18, $EB, $2A, $01, $1F, $22, $10, $01, $2A, $03, $1F, $22, $12, $01, $3A, $05
            dc.b $1F, $32, $14, $01, $AF, $32, $00, $1F, $0E, $80, $2A, $10, $01, $22, $15, $01
            dc.b $2A, $12, $01, $22, $17, $01, $2A, $17, $01, $7C, $B5, $28, $36, $2B, $22, $17
            dc.b $01, $ED, $5B, $15, $01, $CD, $13, $02, $13, $ED, $53, $15, $01, $16, $01, $21
            dc.b $00, $80, $7E, $47, $0F, $0F, $0F, $0F, $E6, $0F, $CD, $F2, $01, $78, $E6, $0F
            dc.b $CD, $F2, $01, $2C, $20, $EC, $24, $CA, $A6, $01, $3A, $00, $1F, $B7, $28, $E2
            dc.b $C3, $73, $01, $3A, $14, $01, $B7, $C2, $9A, $01, $3E, $80, $32, $01, $40, $C3
            dc.b $6D, $01, $5F, $1A, $81, $4F, $3A, $00, $40, $0F, $30, $FA, $3E, $27, $32, $00
            dc.b $40, $3E, $15, $32, $01, $40, $CD, $23, $02, $3E, $2A, $32, $00, $40, $79, $32
            dc.b $01, $40, $C9, $E5, $C5, $21, $00, $60, $7B, $06, $08, $77, $0F, $10, $FC, $72
            dc.b $C1, $E1, $C9, $3A, $00, $40, $07, $38, $FA, $C9
            even
pc_end:
#endasm
End Function

Public Sub Play(ByVal n As Integer, ByVal lp As Integer)
#asm
            movea.l (sp)+, a0
            move.w (a0), d0             ; the song
            movea.l (sp)+, a0
            move.w (a0), d3             ; round again
            movea.l {mb}, a1            ; its header: the first block, the blocks
            lsl.w #2, d0
            move.w 0(a1, d0.w), d1
            move.w 2(a1, d0.w), d2
            move.l a1, d0               ; the data's own block in the 68000's space
            moveq #15, d4
            lsr.l d4, d0
            add.w d0, d1
            move.w #$0100, $A11100
pp_bus:
            btst #0, $A11100
            bne pp_bus
            move.b d1, $A01F01
            lsr.w #8, d1
            move.b d1, $A01F02
            move.b d2, $A01F03
            lsr.w #8, d2
            move.b d2, $A01F04
            move.b d3, $A01F05
            move.b #1, $A01F00
            move.w #$0000, $A11100
#endasm
End Sub

Public Sub Quiet()
    Z80.Poke &H1F00, 2
End Sub
