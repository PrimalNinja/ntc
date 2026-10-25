' StdIO - the console: screen (or stream) and keyboard. NTC platform class: MEGA65 (45GS02): screen memory, the keyboard
'
' Print, Input, Inkey, Inkey$, Cls, Locate and Mode use the same routines, so these
' methods and the BASIC statements can be mixed. Each method's body is only #asm, so it is
' a keyword: StdIO.PutStr s compiles to one thread word plus the argument, no procedure call.
'
' Your own StdIO class: put a StdIO.cls in the project and it replaces this one, and the
' console statements (Print, Input, Inkey, Inkey$, Cls, Locate, Mode) then call its methods:
' PutStr, PutChar, NewLine, Tab, GetLine, GetKey, Cls, Locate, Mode. Copy this file to start.

' ---- what this console can do (constants, worked out when compiling)
Public Const CanPosition = True      ' Locate and the cursor position work
Public Const CanClear = True         ' Cls clears (else it starts a new line)
Public Const CanInput = True         ' the keyboard (RETURN 13, DEL 8, cursor keys &HF0-&HF3)
Public Const CanPoll = True          ' GetKey / Inkey look without waiting
Public Const CanColour = False       ' pen / paper colours (not yet)
Public Const Glyphs = False          ' the text is ASCII in screen memory (NTC's font, loaded at start)
Public Const Rows = 25               ' text rows, 0 = a stream with no bottom edge

' ---- output
Public Sub PutChar(ByVal c As Integer)
#asm
            NTC_POP z_p0
            ldy #0
            lda (z_p0),y
            sta z_t0
            NTC_RS
            lda z_t0
            cmp #13
            beq nl
            jsr ntc_plat_putc
            jmp done
nl:
            jsr ntc_plat_newline
done:
            NTC_TS
#endasm
End Sub

Public Sub PutStr(ByVal s As String)
#asm
            NTC_POP z_p0
            jmp ntc_printbuf
#endasm
End Sub

Public Sub PutInt(ByVal n As Integer)
#asm
            jmp kw_printint
#endasm
End Sub

Public Sub NewLine()
#asm
            jmp kw_printnl
#endasm
End Sub

Public Sub Tab(ByVal col As Integer)
#asm
            jmp kw_printtab
#endasm
End Sub

' ---- input
Public Function GetChar() As Integer
#asm
            NTC_POP z_p2
            NTC_RS
            jsr ntc_plat_getkey
            sta z_t0
            NTC_TS
            ldy #0
            lda z_t0
            sta (z_p2),y
            iny
            lda #0
            sta (z_p2),y
#endasm
End Function

Public Function GetKey() As Integer
#asm
            jmp kw_inkey
#endasm
End Function

Public Sub GetLine(s As String)
#asm
            jmp kw_inputstr
#endasm
End Sub

' ---- screen
Public Sub Cls()
#asm
            jmp kw_cls
#endasm
End Sub

Public Sub Locate(ByVal x As Integer, ByVal y As Integer)
#asm
            jmp kw_locatevv
#endasm
End Sub

Public Sub Mode(ByVal m As Integer)
#asm
            jmp kw_modev
#endasm
End Sub

Public Function Cols() As Integer
#asm
            NTC_POP z_p0
            ldy #0
            lda ntc_scols
            sta (z_p0),y
            iny
            lda #0
            sta (z_p0),y
#endasm
End Function

Public Function Column() As Integer
#asm
            NTC_POP z_p0            ; 1 based, like Locate
            ldy #0
            lda ntc_curx
            clc
            adc #1
            sta (z_p0),y
            iny
            lda #0
            sta (z_p0),y
#endasm
End Function

Public Function Row() As Integer
#asm
            NTC_POP z_p0
            ldy #0
            lda ntc_cury
            clc
            adc #1
            sta (z_p0),y
            iny
            lda #0
            sta (z_p0),y
#endasm
End Function
