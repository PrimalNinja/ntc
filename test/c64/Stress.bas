' the windows under load: a loop too long for the three windows (so pieces are fetched on every
' pass), a Sub called from it, and a frame hook that pushes 20 bytes every frame. The sums must
' still come out right.
Dim i As Integer, j As Integer
Dim l As Long, k As Long, m As Long

Sub AddUp(ByVal n As Integer)
  l = l + n
End Sub

#asm
            sei
            lda #<stress_hook
            sta ntc_c64_hook
            lda #>stress_hook
            sta ntc_c64_hook+1
            cli
            jmp stress_on
stress_hook:
            ldx #20
stress_h1:
            txa
            pha
            dex
            bne stress_h1
            ldx #20
stress_h2:
            pla
            dex
            bne stress_h2
            rts
stress_on:
#endasm

For j = 1 To 40
  For i = 1 To 500
    If (i And 3) = 0 Then AddUp i Else l = l + 1
    k = k + 1 : m = m + i
    k = k + 1 : m = m - i
    k = k + 1 : m = m + 2
    k = k + 1 : m = m - 1
    k = k + 1 : m = m + i
    k = k + 1 : m = m - i
    k = k + 1 : m = m + 2
    k = k + 1 : m = m - 1
    k = k + 1 : m = m + i
    k = k + 1 : m = m - i
    k = k + 1 : m = m + 2
    k = k + 1 : m = m - 1
  Next
Next
Print "l="; l; " k="; k; " m="; m; " frames="; Ticks
End
