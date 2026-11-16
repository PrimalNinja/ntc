' regress.sh: dot_fs_call (the Large Model DOT's esxDOS file call for a program's own FileSystem class): its
' name, stat and data buffers are the Option Buffer buffer, placed in the DOT's 8K after its code
Option Buffer &H3E00, 336
Dim r As Integer
r = Probe()
Print "cy"; r
End
Function Probe() As Integer
#asm
            ld a, #9A               ; F_OPEN
            ld (dot_fs_hook), a
            ld hl, dot_fs_name
            ld (hl), 'X'
            inc hl
            ld (hl), 0
            ld hl, dot_fs_name
            ld (dot_fs_hl), hl
            ld a, '*'
            ld (dot_fs_a), a
            ld bc, 1
            ld (dot_fs_bc), bc
            ld (ntc_ip), sp
            ld sp, (ntc_csp)
            ld hl, dot_fs_call
            call dot_os
            ld sp, (ntc_ip)
            ld a, (dot_fs_cy)
            ld l, a
            ld h, 0
            ld ({result}), hl
#endasm
End Function
