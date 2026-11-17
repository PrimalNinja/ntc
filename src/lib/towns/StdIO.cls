' StdIO - the console: screen (or stream) and keyboard. NTC platform class: Fujitsu FM Towns (80386): the text is drawn on the 640 x 400 screen (80 x 25) from the ROM's font, the keyboard is read at its ports
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
Public Const CanClear = True       ' Cls clears (else it starts a new line)
Public Const CanInput = True         ' the keyboard (the cursor keys are &HF0-&HF3: up, down, left, right)
Public Const CanPoll = True         ' GetKey / Inkey look without waiting
Public Const CanColour = False        ' pen / paper colours (not yet)
Public Const Glyphs = False         ' the text is the ROM's own font
Public Const Rows = 25            ' text rows, 0 = a stream with no bottom edge

' ---- output
Public Sub PutChar(ByVal c As Integer)
#asm
            pop esi
            movzx eax, word [esi]
            NTC_RS
            cmp eax, 13
            je nl
            call ntc_plat_putc
            jmp done
nl:
            call ntc_plat_newline
done:
            NTC_TS
#endasm
End Sub

Public Sub PutStr(ByVal s As String)
#asm
            pop esi
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
            pop ebx
            NTC_RS
            call ntc_plat_getkey
            NTC_TS
            and eax, 0xFF
            mov [ebx], ax
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
            pop esi
            movzx eax, byte [ntc_scols]
            mov [esi], ax
#endasm
End Function

Public Function Column() As Integer
#asm
            pop esi                 ; 1 based, like Locate
            movzx eax, byte [ntc_curx]
            inc eax
            mov [esi], ax
#endasm
End Function

Public Function Row() As Integer
#asm
            pop esi
            movzx eax, byte [ntc_cury]
            inc eax
            mov [esi], ax
#endasm
End Function
