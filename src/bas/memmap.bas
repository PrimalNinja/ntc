' MemMap: what RAM pages this machine has, take some, then draw the memory as a map.
' 64K: one page (main RAM #4000). 6128: five. 512K expansion: 33. 4MB: 257. The program
' asks for what it wants - a 0 back means it isn't there, and it carries on without it.
' Music, sprites and level pages come from main RAM and the standard 512K first, the heap
' (D pages) from the blocks above it first.
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
Dim m As String

Print "Memory on "; System.Platform
n = Memory.Pages()
If n = 0 Then
  ' Option Memory Small (or the program in the window): no pages, a heap in main RAM
  Print "No paging - heap &"; Hex$(Memory.HeapStart()); "-&"; Hex$(Memory.HeapEnd())
Else
  Print Memory.RamSize(); "K, "; n; " pages, model ";
  r = Memory.Model()
  If r = Memory.ModelSmall Then Print "small"
  If r = Memory.ModelMedium Then Print "medium"
  If r = Memory.ModelLarge Then Print "large"
  If r = Memory.ModelHuge Then Print "huge"
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

Print "Press a key";
Do While Inkey <> 0 : Loop
Do : Frame : Loop Until Inkey <> 0
Print
End

Sub ShowPtr(ByVal what As String, ByVal p As Long)
  If p = 0 Then
    Print "Alloc "; what; ": no room"
  Else
    Print "Alloc "; what; ": page "; Memory.PageOf(p); " at &"; Hex$(Memory.Address(p))
  End If
End Sub
