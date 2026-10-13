' MemMap: main memory from the program up to the top of free RAM (the TPA on CP/M), what
' RAM pages this machine has, take some, then draw the memory as a map.
' 64K: one page (main RAM #4000). 6128: five. 512K expansion: 33. 4MB: 257. The program
' asks for what it wants - a 0 back means it isn't there, and it carries on without it.
' Music, sprites and level pages come from main RAM and the standard 512K first, the heap
' (D pages) from the blocks above it first.
Option PressAnyKeyOnEnd "Press a key"     ' at the end: a message and a key (a RUN" program resets when it ends)
Option Explicit
' The program must stay out of #4000-#7FFF (the window pages are switched into): checked
' when assembling. (The test platform's programs start at #4000, so it has no paging.)
#If NTC_CPC Then
Option Reserve &H4000, &H4000
#End If
#If NTC_CPCMIN Then
Option Reserve &H4000, &H4000
#End If
#If NTC_CPCFW Then
Option Reserve &H4000, &H4000
#End If
Dim music As Integer, sprites As Integer, level As Integer
Dim p1 As Long, p2 As Long, p3 As Long
Dim n As Integer, b As Integer, r As Integer
Dim m As String, fr As Long

' first screen: what the machine has, then main memory
Print "Memory on "; System.Platform
n = Memory.Pages()
Summary
MainMap
Print "Press a key";
Do While Inkey <> 0 : Loop
Do : Frame : Loop Until Inkey <> 0
Print

' second screen: take some pages and blocks, then the page map
Cls
Print "Pages on "; System.Platform
Summary
If n = 0 Then
  ' Option Memory Small (or the program in the window): no pages, a heap in main RAM
  Print "No paging - heap &"; Hex$(Memory.HeapStart()); "-&"; Hex$(Memory.HeapEnd())
Else
  Print "Page tables end at &"; Hex$(Memory.TableEnd())
  music = Memory.AllocPage(Memory.TypeUser)
  sprites = Memory.AllocPage(Memory.TypeCode)
  level = Memory.AllocPage(Memory.TypeUser)
  Print "Music "; music; " Sprites "; sprites; " Level "; level
End If

p1 = Memory.Alloc(1000)
p2 = Memory.Alloc(6000)
p3 = Memory.Alloc(12000)
ShowPtr "1000", p1
ShowPtr "6000", p2
ShowPtr "12000", p3
If p1 <> 0 And p3 <> 0 Then
  Memory.WriteWord p1, 12345
  r = Memory.Copy(p1, p3, 2)
  Print "Copy page "; Memory.PageOf(p1); " to "; Memory.PageOf(p3); ": "; Memory.ReadWord(p3)
End If
Print "Largest free block "; Memory.Largest()

Print
If n = 0 Then
  ' no map: the heap is one stretch of main RAM
ElseIf n <= 33 Then
  ' the map: a row per 64K, a column per 16K
  m = Memory.Map(1, n)
  Print "        #0000 #4000 #8000 #C000"
  Print "Main     prog  ["; Mid$(m, 1, 1); "]   ram   scr"
  For b = 0 To (n - 1) \ 4 - 1
    Print "Bank "; b + 1; "  ";
    For r = 0 To 3
      Print " ["; Mid$(m, 2 + b * 4 + r, 1); "]  ";
    Next
    Print
  Next
Else
  ' a row per 512K block (port &7F, &7E ...), a character per 16K page
  Print "Main ["; Memory.Map(1, 1); "]"
  For b = 0 To (n - 2) \ 32
    Print "&"; Hex$(&H7F - b); " "; Memory.Map(2 + b * 32, 32)
  Next
End If
If n > 0 Then Print "C code D data U user - free"

r = Memory.Free(p2)
r = Memory.Free(p1)
r = Memory.Free(p3)
If n = 0 Then
  Print "After Free: largest block "; Memory.Largest()
Else
  Print "After Free: "; Memory.FreePages(); " pages free"
  Print "Pages "; Memory.Map(1, 33)
End If

End

' RAM size, pages, 64K banks and the model (Small / CP/M: no paging)
Sub Summary()
  Dim md As Integer
  If n = 0 Then
    Print "No RAM pages (Option Memory Small)"
    Exit Sub
  End If
  Print Memory.RamSize(); "K, "; n; " pages: main + "; (n - 1) \ 4; " banks"
  md = Memory.Model()
  Print "Model "; Choose(md, "small (64K)", "medium (128K)", "large (to 576K)", "huge (to 4MB)"); ", "; Memory.FreePages(); " pages free"
End Sub

' the program, its tables, the heap or free RAM, the window, up to the platform's top
Sub MainMap()
  Dim e As Integer, t As Integer, top As Integer, hs As Integer, he As Integer
  fr = 0
  e = Memory.ProgramEnd() : t = Memory.TableEnd() : top = Memory.Top()
  Area Memory.ProgramStart(), e, "program and arrays"
  If U(t) > U(e) Then Area e, t, "page tables"
  If Memory.Pages() > 0 Then
    ' CPCExpansion: the heap is in D pages; main RAM around the window is free
    Area t, &H4000, "free" : fr = fr + U(&H4000) - U(t)
    Area &H4000, &H8000, "window (pages)"
    Area &H8000, top, "free" : fr = fr + U(top) - U(&H8000)
  Else
    hs = Memory.HeapStart() : he = Memory.HeapEnd()
    If U(he) > U(hs) Then Area hs, he, "heap (Alloc, List)" : fr = fr + U(he) - U(hs)
    If (he = &H4000) And (U(top) > U(&H8000)) Then
      Area &H4000, &H8000, "Option Reserve"
      Area &H8000, top, "free" : fr = fr + U(top) - U(&H8000)
    ElseIf U(top) > U(he) + 16 Then
      Area he, top, "stack and spare"
    End If
  End If
#If NTC_CPM Then
  Print "&"; Hex$(top); " end of the TPA (BDOS above)"
#Else
  Print "&"; Hex$(top); " top of free RAM"
#End If
  Print "Stack at &"; Hex$(Memory.StackTop())
  Print "Free main RAM: "; fr; " bytes"
End Sub

' one line of the map: start-end (end not included), size, what
Sub Area(ByVal a As Integer, ByVal b As Integer, ByVal what As String)
  If U(b) <= U(a) Then Exit Sub
  Print "&"; Right$("000" + Hex$(a), 4); "-&"; Right$("000" + Hex$(b - 1), 4); " "; U(b) - U(a); " "; what
End Sub

' an address as an unsigned number (Integers above &7FFF are negative)
Function U(ByVal x As Integer) As Long
  If x < 0 Then U = CLng(x) + 65536 Else U = x
End Function

Sub ShowPtr(ByVal what As String, ByVal p As Long)
  If p = 0 Then
    Print "Alloc "; what; ": no room"
  Else
    Print "Alloc "; what; ": page "; Memory.PageOf(p); " at &"; Hex$(Memory.Address(p))
  End If
End Sub
