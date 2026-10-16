' AUCKLAND: STATE3D - fly over Auckland, a real city from OpenStreetMap: its 234,000 buildings
' (the heights mapped, else from their kind and size), roads, railways, the coast and the
' harbour, piers, 50,000 trees, the Sky Tower, the Harbour Bridge and the volcanoes (Rangitoto,
' Mount Victoria, Mount Eden ...). The data: AUCKLAND.DAT (tools/s3dmake from an OSM Cut file,
' tools/osmcut), 3.8 MB in 16K blocks, read into the expansion RAM at the start - a 4MB CPC.
' S3d.cls does the work (Z80), the Graphics class draws (double buffering: main RAM's #4000 is
' the second screen). Map data (c) OpenStreetMap contributors, ODbL.
' Keys (Elite's): < > roll, S X dive / climb, Space faster, ? slower; the cursor keys turn left /
' right and dive / climb; T turbo on / off; Q quits.
' cpcfw: an AMSDOS file (RUN"AUCKLAND), AUCKLAND.DAT on the same drive.
Option PressAnyKeyOnEnd "Press a key"     ' at the end: a message and a key (a RUN" program resets when it ends)
Option Explicit
Option Reserve &H4000, &H4000     ' main RAM's #4000-#7FFF: the second screen (and the window)
Option Reserve &H9000, &H1600     ' S3d's tables (#9000-#A5FF)
Dim k As Integer, tk As Integer, fast As Integer, spd As Integer, n As Integer
Dim p As Integer, r As Integer, y As Integer, frames As Integer, t As Integer, fps As Integer
Dim h As Integer, b As Integer, nb As Integer, p0 As Integer, i As Integer
Dim nx As Integer, nz As Integer, nlm As Integer, lmo As Integer, dro As Integer
Dim nm As String Max 16

Mode 1
S3d.Inks
Print "AUCKLAND - STATE3D"
Print "Map data (c) OpenStreetMap contributors"
Print
If Memory.Pages() < 200 Then Print "It needs a 4MB CPC (the data: 3.8 MB)" : End
h = FileSystem.Open("AUCKLAND.DAT", FileSystem.ForReadRaw)
If h < 0 Then Print "AUCKLAND.DAT isn't on this drive" : End
p0 = NewPage()
n = S3d.Load(p0)
If n < 64 Or Memory.ReadByte(Far(0)) <> 83 Or Memory.ReadByte(Far(3)) <> 49 Then Print "AUCKLAND.DAT: not S3D data" : End
nx = Memory.ReadWord(Far(4)) : nz = Memory.ReadWord(Far(6)) : nb = Memory.ReadWord(Far(8))
nlm = Memory.ReadWord(Far(22)) : lmo = Memory.ReadWord(Far(24)) : dro = Memory.ReadWord(Far(26))
nm = ""
For i = 0 To 15
  k = Memory.ReadByte(Far(32 + i))
  If k = 0 Then Exit For
  nm = nm + Chr$(k)
Next
Print nm; ": "; nb + 1; " blocks of 16K, "; nx; " x"; nz; " tiles"
If Memory.FreePages() < nb + 1 Then Print "Not enough free RAM:"; Memory.FreePages() * 16; "K free" : End
S3d.SetPage 0, p0
Print "Reading";
If S3d.Fast() Then Print " (UniDOS)";
Print
For b = 1 To nb
  p = NewPage()
  n = S3d.Load(p)
  If b = 1 Then
    If S3d.Fast() Then Locate 8, 5 : Print "(UniDOS)    ";
  End If
  If n <> 16384 And b < nb Then Locate 1, 7 : Print "AUCKLAND.DAT: short at block"; b : End
  S3d.SetPage b, p
  Locate 1, 6 : Print b * 100 \ nb; "%  "; b; " of"; nb; "   ";
Next
r = FileSystem.Close(h)
If nlm > S3d.LANDMARKS Then nlm = S3d.LANDMARKS
For i = 0 To nlm - 1
  t = Memory.ReadWord(Far(lmo + i * 2))
  S3d.SetLandmark i, t Mod nx, t \ nx
Next
S3d.Setup nx, nz, Memory.ReadWord(Far(10)), Memory.ReadWord(Far(12)), dro, nlm, Memory.ReadWord(Far(16)), Memory.ReadWord(Far(18))
Locate 1, 8
Print "< >       roll"
Print "S X       dive / climb"
Print "cursors   turn, dive / climb"
Print "Space ?   faster / slower"
Print "T         turbo on / off"
Print "Q         quit"
Print
Print "Press a key"
Do : Loop Until Inkey <> 0
Cls
Graphics.DoubleBuffer 1
spd = 8
t = Ticks
Do
  p = 0 : r = 0 : y = 0
  If Keys.Down(Keys.KeyS) Or Keys.Down(Keys.KeyUp) Then p = -1      ' dive
  If Keys.Down(Keys.KeyX) Or Keys.Down(Keys.KeyDown) Then p = 1     ' climb
  If Keys.Down(39) Then r = -1                                      ' < (the , key)
  If Keys.Down(31) Then r = 1                                       ' > (the . key)
  If Keys.Down(Keys.KeyLeft) Then y = -1
  If Keys.Down(Keys.KeyRight) Then y = 1
  If Keys.Down(Keys.KeySpace) And spd < 64 Then spd = spd + 1
  If Keys.Down(30) And spd > 0 Then spd = spd - 1                   ' ? (the / key)
  S3d.Steer p, r, y, spd
  If fast Then
    Turbo On
    S3d.Render
    Turbo Off
  Else
    S3d.Render
  End If
  Graphics.Flip
  frames = frames + 1
  If frames = 8 Then
    ' frames a second in tenths: 8 frames * 300 ticks * 10 / the ticks they took (halved: Integer)
    fps = 4 * System.TicksPerSecond * 10 \ ((Ticks - t) \ 2 + 1)
    frames = 0 : t = Ticks
    Locate 1, 1
    Print "SPEED "; spd \ 2; "M  HEIGHT "; S3d.Altitude(); "M  FPS "; fps \ 10; "."; fps Mod 10; "  LINES "; S3d.Lines(); "  ";
    Graphics.CopyText 1
  End If
  k = Keys.Down(51)                                                 ' T: turbo on / off
  If k <> 0 And tk = 0 Then fast = Not fast
  tk = k
Loop Until Keys.Down(Keys.KeyQ)
Graphics.DoubleBuffer 0
Mode 1
Print "Bye"
End

' a far pointer into block 0 (in its page)
Function Far(ByVal o As Integer) As Long
  Far = CLng(p0) * 65536 + &H4000 + o
End Function

' the next free RAM page for the data (page 1 - main RAM's #4000 - left alone: the second screen)
Function NewPage() As Integer
  Do
    NewPage = Memory.AllocPage(Memory.TypeUser)
  Loop While NewPage = 1
  If NewPage <= 0 Then Locate 1, 7 : Print "Out of RAM pages" : End
End Function
