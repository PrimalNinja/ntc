' Dat - a file in the FM Towns disc's high data (NTC_HIGHFILE): test/towns/Classes.bas
Option Explicit

Public Function Where() As Long
#asm
            pop edi
            mov dword [edi], td_file
            NTC_HIGHFILE td_file, "towns/Dat.bin"
#endasm
End Function

Public Function Byte(ByVal i As Integer) As Integer
#asm
            pop esi
            movzx eax, word [esi]
            movzx eax, byte [td_file + eax]
            pop edi
            mov [edi], ax
#endasm
End Function
