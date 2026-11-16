' StdIO - the console: screen (or stream) and keyboard. NTC platform class: CP/M (BDOS console)
'
' Print, Input, Inkey, Inkey$, Cls, Locate and Mode use the same routines, so these
' methods and the BASIC statements can be mixed. Each method's body is only #asm, so it is
' a keyword: StdIO.PutStr s compiles to one thread word plus the argument, no procedure call.
'
' Your own StdIO class: put a StdIO.cls in the project and it replaces this one, and the
' console statements (Print, Input, Inkey, Inkey$, Cls, Locate, Mode) then call its methods:
' PutStr, PutChar, NewLine, Tab, GetLine, GetKey, Cls, Locate, Mode. Copy this file to start.

' ---- what this console can do (constants, worked out when compiling)
#If NTC_TERM_POS Then
' Option Terminal VT52 / ANSI / ADM3A / Televideo (or SetTerminal used): Cls and Locate send the terminal's codes
Public Const CanPosition = True       ' Locate and the cursor position work
Public Const CanClear = True          ' Cls clears (else it starts a new line)
Public Const Rows = 24                ' text rows, 0 = a stream with no bottom edge
#Else
' no Option Terminal: a stream
Public Const CanPosition = False      ' Locate and the cursor position work
Public Const CanClear = False         ' Cls clears (else it starts a new line)
Public Const Rows = 0                 ' text rows, 0 = a stream with no bottom edge
#End If
Public Const CanInput = True         ' there is a keyboard
Public Const CanPoll = True         ' GetKey / Inkey look without waiting
Public Const CanColour = False        ' pen / paper colours (not yet)
Public Const Glyphs = False         ' the program draws the text itself (the CPC font, copied from the ROM)

' ---- the terminal, chosen while the program runs (20261116-4)
' SetTerminal n: the codes Cls and Locate send from now on - 0 none (a stream: Cls starts a new line,
' Locate does nothing), 1 VT52, 2 ANSI, 3 ADM-3A, 4 Televideo (5 and up: kept for more; taken as 0).
' Option Terminal is only what it starts as. A program that calls this carries every terminal's
' codes, and CanPosition / CanClear are True and Rows 24 whatever Option Terminal says.
Public Const TerminalNone = 0
Public Const TerminalVT52 = 1
Public Const TerminalANSI = 2
Public Const TerminalADM3A = 3
Public Const TerminalTelevideo = 4
Public Sub SetTerminal(ByVal n As Integer)
#asm
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            inc h
            dec h
            jr nz, st_none
            cp 5
            jr c, st_set
st_none:
            xor a
st_set:
            ld (ntc_termno), a
#endasm
End Sub

' ---- output
Public Sub PutChar(ByVal c As Integer)
#asm
            pop hl
            ld a, (hl)
            ld ix, ntc_next
            cp 13
            jp z, ntc_plat_newline
            jp ntc_plat_putc
#endasm
End Sub

Public Sub PutStr(ByVal s As String)
#asm
            pop hl
            ld (ntc_sptr), hl
            jp ntc_printbuf
#endasm
End Sub

Public Sub PutInt(ByVal n As Integer)
#asm
            jp kw_printint
#endasm
End Sub

Public Sub NewLine()
#asm
            ld ix, ntc_next
            jp ntc_plat_newline
#endasm
End Sub

Public Sub Tab(ByVal col As Integer)
#asm
            jp kw_printtab
#endasm
End Sub

' ---- input
Public Function GetChar() As Integer
#asm
            pop hl              ; the result
            ld (ntc_ivar), hl
            ld ix, got
            jp ntc_plat_getkey
got:
            ld hl, (ntc_ivar)
            ld (hl), a
            inc hl
            ld (hl), 0
#endasm
End Function

Public Function GetKey() As Integer
#asm
            jp kw_inkey
#endasm
End Function

Public Sub GetLine(s As String)
#asm
            jp kw_inputstr
#endasm
End Sub

' ---- screen
Public Sub Cls()
#asm
            jp kw_cls
#endasm
End Sub

Public Sub Locate(ByVal x As Integer, ByVal y As Integer)
#asm
            jp kw_locatevv
#endasm
End Sub

Public Sub Mode(ByVal m As Integer)
#asm
            jp kw_modev
#endasm
End Sub

Public Function Cols() As Integer
#asm
            pop hl
            ld a, (ntc_scols)
            ld (hl), a
            inc hl
            ld (hl), 0
#endasm
End Function

Public Function Column() As Integer
#asm
            pop hl              ; 1 based, like Locate
            ld a, (ntc_curx)
            inc a
            ld (hl), a
            inc hl
            ld (hl), 0
#endasm
End Function

Public Function Row() As Integer
#asm
            pop hl
            ld a, (ntc_cury)
            inc a
            ld (hl), a
            inc hl
            ld (hl), 0
#endasm
End Function
