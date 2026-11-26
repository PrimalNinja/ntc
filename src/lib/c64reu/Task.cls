' Task - several parts of a program taking turns. NTC platform class: Commodore 64 with an REU (6502)
'
' A task is a Sub that runs alongside the main program and the other tasks. Each gives the
' others a turn with Task.Yield (or Task.Sleep): tasks take turns only there, so nothing
' changes under a task between two of its own Yields. Up to 32 at once; the main program is
' task 0.
'
' A task costs almost nothing here: it is one place in the thread (two bytes). Changing task
' saves one place and goes to another - and when the other task's piece of thread is still in
' one of the three windows, not even the REU is asked.
'
'     Sub Blink()
'         Do
'             Poke &HD020, Peek(&HD020) Xor 1
'             Task.Sleep 25
'         Loop
'     End Sub
'
'     Task.Start AddressOf Blink
'     Do
'         ... the main program ...
'         Task.Yield
'     Loop
'
' To know:
' - A task's Sub takes no parameters. When the Sub ends, the task ends.
' - A Sub's local variables and parameters are one set, not one per task (as everywhere in NTC
'   BASIC). Two tasks may run the same Sub, but then each must keep what it needs across a Yield
'   in an array indexed by Task.Id(), not in a local.
' - The same goes for any Sub that Yields inside: let one task at a time be in it.
' - Gosub's return stack is shared too: no Yield between a Gosub and its Return.
' - End stops the whole program, whichever task says it.

' Start: a new task that runs the Sub (AddressOf TheSub). Its number (1-31), or -1 when 32 are
' running. It gets its first turn at the next Yield.
Public Function Start(ByVal addr As Integer) As Integer
#asm
            NTC_POP z_p0
            NTC_POP z_p2
            ldy #0
            lda (z_p0),y
            sta z_p1
            iny
            lda (z_p0),y
            sta z_p1+1
            NTC_RS
            jsr ntc_tk_start
            sta z_t0
            NTC_TS
            ldy #0
            lda z_t0
            sta (z_p2),y
            iny
            cmp #$FF
            beq none
            lda #0
none:
            sta (z_p2),y
#endasm
End Function

' Yield: the other tasks get a turn; this one carries on after them
Public Sub Yield()
#asm
            jmp ntc_tk_yield
#endasm
End Sub

' Sleep: this task waits for that many frames (50 a second) while the others run
Public Sub Sleep(ByVal frames As Integer)
#asm
            NTC_POP z_p0
            ldx ntc_task
            ldy #0
            sei
            clc
            lda (z_p0),y
            adc ntc_ticks
            sta ntc_tk_wl,x
            iny
            lda (z_p0),y
            adc ntc_ticks+1
            sta ntc_tk_wh,x
            cli
            lda #2
            sta ntc_tk_st,x
            jmp ntc_tk_yield
#endasm
End Sub

' Id(): the number of the task that is running (0 = the main program)
Public Function Id() As Integer
#asm
            NTC_POP z_p0
            ldy #0
            lda ntc_task
            sta (z_p0),y
            iny
            lda #0
            sta (z_p0),y
#endasm
End Function

' Count(): how many tasks there are (the main program is one)
Public Function Count() As Integer
#asm
            NTC_POP z_p0
            ldx #31
            ldy #0
cnt:
            lda ntc_tk_st,x
            beq free
            iny
free:
            dex
            bpl cnt
            tya
            ldy #0
            sta (z_p0),y
            iny
            lda #0
            sta (z_p0),y
#endasm
End Function

' Stop n: task n ends (a task may stop itself: it then never comes back from this)
Public Sub Stop(ByVal n As Integer)
#asm
            NTC_POP z_p0
            ldy #0
            lda (z_p0),y
            and #31
            beq done                ; (not the main program)
            tax
            lda #0
            sta ntc_tk_st,x
            cpx ntc_task
            bne done
            jmp ntc_tk_next
done:
#endasm
End Sub
