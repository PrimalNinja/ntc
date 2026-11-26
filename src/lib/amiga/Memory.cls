' Memory - the Amiga's free memory, handed out in blocks. NTC platform class: Commodore Amiga 500
'
' The program has the whole machine, and NTC uses only a little of it. Two pools, found when the
' disc boots:
'   chip   chip RAM from the end of the program to its top (512K, 1 MB or 2 MB in all). Only chip
'          RAM can be shown (bitplanes, sprites, the copper), played (samples) or blitted.
'   other  the other RAM: a trapdoor's "slow" 512K, "fast" RAM in the side slot (up to 8 MB). Only
'          the 68000 sees it: for code's data, files waiting to be used, tables.
' A block is a Long address for #asm (above 64K: not Peek / Poke). Blocks are not given back:
' take what the game needs once, at its start.
'   pic = Memory.Alloc(40960)          ' 0: there is not that much chip RAM left
'   buf = Memory.AllocAny(200000)      ' other RAM when the machine has it, else chip RAM
'   If System.ChipRam() < 1024 Then ...
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Option Explicit

' Alloc(bytes): a block of chip RAM (its address, a 4 byte edge), or 0
Public Function Alloc(ByVal bytes As Long) As Long
#asm
            movea.l (sp)+, a0
            move.l (a0), d0
            moveq #0, d1
            NTC_RS
            jsr ntc_ami_alloc
            NTC_TS
            movea.l (sp)+, a0
            move.l d0, (a0)
#endasm
End Function

' AllocOther(bytes): a block of the other RAM, or 0 (a machine with none: always 0)
Public Function AllocOther(ByVal bytes As Long) As Long
#asm
            movea.l (sp)+, a0
            move.l (a0), d0
            moveq #1, d1
            NTC_RS
            jsr ntc_ami_alloc
            NTC_TS
            movea.l (sp)+, a0
            move.l d0, (a0)
#endasm
End Function

' AllocAny(bytes): a block of the other RAM when there is that much, else of chip RAM, or 0.
' For anything the custom chips do not have to reach: it leaves chip RAM for what must be there.
Public Function AllocAny(ByVal bytes As Long) As Long
#asm
            movea.l (sp)+, a0
            move.l (a0), d2
            NTC_RS
            move.l d2, d0
            moveq #1, d1
            jsr ntc_ami_alloc
            tst.l d0
            bne got
            move.l d2, d0
            moveq #0, d1
            jsr ntc_ami_alloc
got:
            NTC_TS
            movea.l (sp)+, a0
            move.l d0, (a0)
#endasm
End Function

' Free(): the bytes of chip RAM left; FreeOther(): of the other RAM (its bigger block's)
Public Function Free() As Long
#asm
            moveq #0, d1
            NTC_RS
            jsr ntc_ami_left
            NTC_TS
            movea.l (sp)+, a0
            move.l d0, (a0)
#endasm
End Function

Public Function FreeOther() As Long
#asm
            moveq #1, d1
            NTC_RS
            jsr ntc_ami_left
            NTC_TS
            movea.l (sp)+, a0
            move.l d0, (a0)
#endasm
End Function
