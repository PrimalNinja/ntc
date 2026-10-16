' AUCKLAND: STATE3D - fly over Auckland, a real city from OpenStreetMap: its 234,000 buildings
' (the heights mapped, else from their kind and size), roads, railways, the coast and the
' harbour, piers, 50,000 trees, the Sky Tower, the Harbour Bridge and the volcanoes (Rangitoto,
' Mount Victoria, Mount Eden ...). The data: AUCKLAND.DAT (tools/s3dmake from an OSM Cut file,
' tools/osmcut), 3.8 MB in 16K blocks, read into the expansion RAM at the start - a 4MB CPC.
' S3d.cls does the work (Z80), the Graphics class draws (double buffering: main RAM's #4000 is
' the second screen). Map data (c) OpenStreetMap contributors, ODbL.
' Keys (Elite's): < > roll, X climb, Space faster, ? slower; the cursor keys turn left / right
' and dive / climb; S frames skipped (0, 4, 8: the camera moves that many frames more between
' those drawn - faster over the ground); a compass (bottom right: the arrow points to the city's centre); 1-9 the views (the start - 400 m up, flying at the CBD, Rangitoto ahead
' on the right -, south of the CBD, the Sky Tower, the Harbour Bridge, Devonport, the volcanoes);
' B the line budget (600, 1200, 2400 a frame: more detail, slower); T turbo on / off; P pause;
' Q quits.
' cpcfw: an AMSDOS file (RUN"AUCKLAND), AUCKLAND.DAT on the same drive.
Option PressAnyKeyOnEnd "Press a key"     ' at the end: a message and a key (a RUN" program resets when it ends)
Option Explicit
Option RomEnable All              ' RUN" drops the background ROMs: AMSDOS, UniDOS and its nodes started again
Option Reserve &H4000, &H4000     ' main RAM's #4000-#7FFF: the second screen (and the window)
Option Reserve &H8F50, &H13A0     ' S3d's tables (#8F50-#A2EF: under the ROMs' RAM - UniDOS with an IDE node: #A309 up)
Option Buffer &H8F50             ' the file buffer (2K) in S3d's tables: used only while AUCKLAND.DAT is read
Dim k As Integer, tk As Integer, fast As Integer, spd As Integer, n As Integer
Dim p As Integer, r As Integer, y As Integer, frames As Integer, t As Integer, fps As Integer
Dim h As Integer, b As Integer, nb As Integer, p0 As Integer, i As Integer
Dim nx As Integer, nz As Integer, nlm As Integer, lmo As Integer, dro As Integer, wx As Integer, wz As Integer, sx As Integer, sz As Integer
Dim nv As Integer, vx(9) As Integer, vz(9) As Integer, vh(9) As Integer, vfx(9) As Integer, vfz(9) As Integer
Dim vn(9) As String Max 22, cv As Integer, bud As Integer, msg As Integer, tf As Integer, mx As Integer
Dim skip As Integer, mt As String Max 24

Mode 1
S3d.Inks
If RomsAt() <> 0 And RomsAt() - 16 < &HA2F0 Then ' (S3d's tables are #8F50-#A2EF: the ROMs' RAM - and its event
  Print "The ROMs' RAM reaches down to &"; Hex$(RomsAt()); " - AUCKLAND needs up to &A2FF" : End  ' block, 16 below - above)
End If
If MemTab() + Memory.Pages() * 3 > &H8F50 Then   ' (the Memory class's page tables, after the program, under them)
  Print "The page tables reach &"; Hex$(MemTab() + Memory.Pages() * 3); " - over &8F50" : End
End If
Print "AUCKLAND"
If Memory.Pages() < 200 Then Print "It needs a 4MB CPC (the data: 3.8 MB)" : End
h = FileSystem.Open("AUCKLAND.DAT", FileSystem.ForReadRaw)
If h < 0 Then Print "AUCKLAND.DAT isn't on this drive" : End
p0 = NewPage()
n = S3d.Load(p0)
If n < 64 Or Memory.ReadByte(Far(0)) <> 83 Or Memory.ReadByte(Far(3)) <> 49 Then Print "AUCKLAND.DAT: not S3D data" : End
nx = Memory.ReadWord(Far(4)) : nz = Memory.ReadWord(Far(6)) : nb = Memory.ReadWord(Far(8))
nlm = Memory.ReadWord(Far(22)) : lmo = Memory.ReadWord(Far(24)) : dro = Memory.ReadWord(Far(26))
If Memory.FreePages() < nb + 1 Then Print "Not enough free RAM:"; Memory.FreePages() * 16; "K free" : End
S3d.SetPage 0, p0
For b = 1 To nb
  p = NewPage()
  n = S3d.Load(p)
  If n <> 16384 And b < nb Then Locate 1, 3 : Print "AUCKLAND.DAT: short at block"; b : End
  S3d.SetPage b, p
  Locate 12, 1 : Print "loading "; b * 100 \ nb; "% ";
Next
r = FileSystem.Close(h)
If nlm > S3d.LANDMARKS Then nlm = S3d.LANDMARKS
For i = 0 To nlm - 1
  t = Memory.ReadWord(Far(lmo + i * 2))
  If t < 0 Then S3d.SetLandmark i, (t And &H7FFF) Mod nx + 128, (t And &H7FFF) \ nx Else S3d.SetLandmark i, t Mod nx, t \ nx
Next
nv = Memory.ReadWord(Far(28)) : k = Memory.ReadWord(Far(30))
If nv > 10 Then nv = 10
For i = 0 To nv - 1
  vx(i) = Memory.ReadWord(Far(k + i * 32)) : vz(i) = Memory.ReadWord(Far(k + i * 32 + 2))
  vh(i) = Memory.ReadWord(Far(k + i * 32 + 4))
  vfx(i) = Memory.ReadWord(Far(k + i * 32 + 6)) : vfz(i) = Memory.ReadWord(Far(k + i * 32 + 8))
  vn(i) = ""
  For b = 0 To 21
    r = Memory.ReadByte(Far(k + i * 32 + 10 + b))
    If r = 0 Then Exit For
    vn(i) = vn(i) + Chr$(r)
  Next
Next
wx = Memory.ReadWord(Far(10)) : wz = Memory.ReadWord(Far(12)) : sx = Memory.ReadWord(Far(16)) : sz = Memory.ReadWord(Far(18))
S3d.Setup nx, nz, wx, wz, dro, nlm, sx, sz
wx = Memory.ReadWord(Far(48)) : wz = Memory.ReadWord(Far(50)) : S3d.SetCentre wx, wz   ' (the compass)
If nv > 0 Then S3d.Place vx(0), vz(0), vh(0), vfx(0), vfz(0)
bud = 1200 : S3d.SetBudget bud
Locate 1, 3
Print "cursors  turn, dive / climb"
Print "< >      roll"
Print "X        climb"
Print "Space ?  faster / slower"
Print "S        frame skip 0 / 4 / 8"
Print "1-"; Chr$(48 + nv); "      views"
Print "B        detail"
Print "T        turbo"
Print "P        pause"
Print "Q        quit"
Print
Print "Map data (c) OpenStreetMap contributors"
Print
Print "Press a key"
Do : Loop Until Inkey <> 0
Cls
Graphics.DoubleBuffer 1
spd = 8
t = Ticks
Do
  p = 0 : r = 0 : y = 0
  If Keys.Down(Keys.KeyUp) Then p = -1                              ' dive
  If Keys.Down(Keys.KeyX) Or Keys.Down(Keys.KeyDown) Then p = 1     ' climb
  If Keys.Down(39) Then r = -1                                      ' < (the , key)
  If Keys.Down(31) Then r = 1                                       ' > (the . key)
  If Keys.Down(Keys.KeyLeft) Then y = -1
  If Keys.Down(Keys.KeyRight) Then y = 1
  If Keys.Down(Keys.KeySpace) And spd < 64 Then spd = spd + 1
  If Keys.Down(30) And spd > 0 Then spd = spd - 1                   ' ? (the / key)
  S3d.Steer p, r, y, spd
  For i = 1 To skip                                                 ' S: frames skipped - moved, not drawn
    S3d.Move
  Next
  If fast Then
    Turbo On
    S3d.Render
    Turbo Off
  Else
    S3d.Render
  End If
  Graphics.Flip
  frames = frames + 1 : tf = tf + 1
  If S3d.Lines() > mx Then mx = S3d.Lines()
  If msg > 0 Then msg = msg - 1
  If frames = 4 Then
    ' frames a second in tenths: 4 frames * 300 ticks * 10 / the ticks they took (halved: Integer)
    fps = 2 * System.TicksPerSecond * 10 \ ((Ticks - t) \ 2 + 1)
    frames = 0 : t = Ticks
    Locate 1, 1
    If msg > 0 Then
      Print Left$(mt + Space$(40), 40);
    Else
      Print "SPEED "; spd \ 2; "M  HEIGHT "; S3d.Altitude(); "M  FPS "; fps \ 10; "."; fps Mod 10; "  LINES "; S3d.Lines(); "  ";
    End If
    Graphics.CopyText 1
  End If
  k = Inkey                                                         ' 1-9 a view, B the budget
  If k >= 49 And k < 49 + nv Then
    cv = k - 49 : S3d.Place vx(cv), vz(cv), vh(cv), vfx(cv), vfz(cv) : mt = vn(cv) : msg = 4
  ElseIf k = 83 Or k = 115 Then                                     ' S: 0, 4, 8 frames skipped
    skip = skip + 4 : If skip > 8 Then skip = 0
    mt = "FRAMES SKIPPED:" + Str$(skip) : msg = 4
  ElseIf k = 80 Or k = 112 Then                                     ' P: pause until P again (or Q)
    Locate 1, 1 : Print Left$("PAUSED - P to go on" + Space$(40), 40); : Graphics.CopyText 1
    Do : k = Inkey : Loop Until k = 80 Or k = 112 Or Keys.Down(Keys.KeyQ)
    frames = 0 : t = Ticks
  ElseIf k = 66 Or k = 98 Then
    bud = bud * 2 : If bud > 2400 Then bud = 600
    S3d.SetBudget bud
  End If
  k = Keys.Down(51)                                                 ' T: turbo on / off
  If k <> 0 And tk = 0 Then fast = Not fast
  tk = k
Loop Until Keys.Down(Keys.KeyQ)
Graphics.DoubleBuffer 0
Mode 1
Print "Bye - "; tf; " frames, up to "; mx; " lines"
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

' where the Memory class's page tables start (3 bytes a page)
Function MemTab() As Integer
#asm
            ld hl, ntc_memtab
            ld ({result}), hl
#endasm
End Function

' where the ROMs' RAM starts (Option RomEnable's start code found it)
Function RomsAt() As Integer
#asm
            ld hl, (ntc_roms_at)
            ld ({result}), hl
#endasm
End Function
