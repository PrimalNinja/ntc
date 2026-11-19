' Memory - the FM Towns' free memory, handed out in blocks. NTC platform class: Fujitsu FM Towns
'
' The program has all of memory (flat, no paging), and NTC uses only a little of it. Two pools:
'   low   from the end of the program to $9F000: about 550K with a small program
'   high  from the end of the high data (or $100000) to the top of the machine's RAM: 1 MB on a
'         2 MB machine with no high data
' A block is a Long address for #asm (above 64K: not Peek / Poke). Blocks are not given back:
' take what the game needs once, at its start.
'   buf = Memory.Alloc(98304)          ' 0: there is not that much left
'   If Memory.Free() < 200000 Then ...
Option Explicit

' Alloc(bytes): a block in the low pool (its address, a 4 byte edge), or 0
Public Function Alloc(ByVal bytes As Long) As Long
#asm
            pop esi
            mov eax, [esi]
            xor ebx, ebx
            NTC_RS
            call ntc_tw_alloc
            NTC_TS
            pop edi
            mov [edi], eax
#endasm
End Function

' AllocHigh(bytes): a block in the high pool, or 0
Public Function AllocHigh(ByVal bytes As Long) As Long
#asm
            pop esi
            mov eax, [esi]
            mov ebx, 1
            NTC_RS
            call ntc_tw_alloc
            NTC_TS
            pop edi
            mov [edi], eax
#endasm
End Function

' Free(): the bytes left in the low pool; FreeHigh(): in the high pool
Public Function Free() As Long
#asm
            xor ebx, ebx
            NTC_RS
            call ntc_tw_left
            NTC_TS
            pop edi
            mov [edi], eax
#endasm
End Function

Public Function FreeHigh() As Long
#asm
            mov ebx, 1
            NTC_RS
            call ntc_tw_left
            NTC_TS
            pop edi
            mov [edi], eax
#endasm
End Function
