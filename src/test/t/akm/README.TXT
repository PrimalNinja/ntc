AUCKLAND - a real city on a Z80
================================

Fly over Auckland, New Zealand, in wireframe, on an Amstrad CPC with 4 MB of
expansion RAM. The whole city is in memory: 233,935 buildings, 43,082 road,
rail, coast and water lines, 50,040 trees, the Sky Tower, the Harbour Bridge
and the volcanoes - from OpenStreetMap, 409 square km.

Map data (c) OpenStreetMap contributors, ODbL (openstreetmap.org/copyright).

WHY
---
A baseline. A whole real city - every building, road and tree of 409 square
km - flown through in 3D on a stock Z80 with a RAM expansion: about 0.3
frames a second, and it can't get any slower than that. Like UAE (the
"Unusable Amiga Emulator") when it came out, which ended up awesome: from
here every faster routine, every better table, every coprocessor card is
measured against this.


NEEDS
-----
- CPC 6128 or 464 (Z80, 4 MHz), 4 MB RAM expansion (200 RAM pages or more)
- UniDOS with a mass storage node (IDE, SD ...): AUCKLAND.DAT is 3.8 MB
  (without UniDOS's block read it loads a byte at a time: far too slow)
- WinAPE works too: IDE drive = AUCKLAND.IMG, UniDOS ROMs, 4 MB RAM

Files: AUCKLAND.BIN (the program, 35K) and AUCKLAND.DAT (the data), on the
same drive.  RUN"AUCKLAND


ZX SPECTRUM NEXT (AUCKLAND.NEX)
------------------------------
The same program (Main.bas and S3d.cls, built for the zxn platform: the
hardware banged, no NextZXOS left running) on a 2MB Next, at 28 MHz:

- AUCKLAND.NEX holds it all: the program and the data (Option NexData) -
  NextZXOS's browser loads the data's 94 blocks straight into the Next's
  16K banks with the program, so there is nothing to read after: it starts
  flying at once. 1.6 MB.
- the data is smaller than the CPC's: 1.5 MB (s3dmake, "At most" 1552K):
  every road, the coast, the water, all 50,040 trees and the landmarks, and
  the 64,821 biggest buildings - the 169,000 small houses are left out (the
  Next has 2 MB, the CPC 4 MB)
- each tile's block goes in #4000-#7FFF (MMU slots 2 and 3) as the CPC puts
  its RAM page there; the drawing is Layer 2 at 320 x 256, 256 colours, double
  buffered, the CPC's 320 x 200 picture centred in it; the text (the speed
  line) stays on the tilemap over it
- about 1.5 to 2 frames a second over the CBD (1,400-1,500 lines), 4 or more
  out in the gulf - in the test harness's timing (28 MHz T-states)
- keys as below, but N M roll and Z slower (the Spectrum has no < > ? keys);
  the Next's cursor keys turn and dive / climb
- to build it: tools/s3dmake with "At most" 1552K gives AUCKLAND.DAT (94
  blocks); put it next to the .asm the compiler writes for the zxn platform
  (cli.js ... --platform=zxn --name=AUCKLAND) and assemble with sjasmplus:
  it writes AUCKLAND.NEX. A different data file: change the block count in
  Main.bas's Option NexData (97 at most)
- a 1MB Next (768K for programs: 16K banks up to 47): AUCKLAND1M.NEX - the
  same program with Option NexData "AUCKLAND.DAT", 33 and s3dmake's "At most"
  528K (33 blocks: 600K the file). To fit, all the small houses and minor
  roads go and then the woods' trees (466 trees kept - the mapped ones first):
  12,845 buildings, every major road, the coast, water and the landmarks.
  The NEX needs no 2MB (no bank past 47)
- a start of your own: s3dmake's "Start at" a street's name - key 1 looks
  at the street's far end from 250 m off, 60 m up; the usual start is key 2
  (AUCKLAND-BEACHHAVEN.NEX: Gemini Place, Beach Haven)
- maps of one area, all their detail (every street, house and tree): s3dmake's
  "Only the area round" - AUCKLAND-CBD.NEX (6 km round the Sky Tower),
  AUCKLAND-DEVONPORT.NEX (8 km), AUCKLAND-BEACHHAVEN.NEX (8 km round Gemini
  Place); about 450K each: a 1MB Next or a 2MB one

TEST VARIANTS (hidden line removal experiments)
-----------------------------------------------
- bas/auckland_tern: the ternary back-face test - each wall's outward normal
  and the way to the camera as two trits (x, z: -1, 0, +1), dotted with no
  multiplying; a wall facing away: its ground edge left out, an upright only
  where a wall beside it shows (s3dmake writes outlines anticlockwise, so a
  wall's outward side is known). Same data as AUCKLAND.
- bas/auckland_mask: the same worked out ahead of time - s3dmake's wall masks
  (S3D2 data: a byte a wall, bit k set when it can be seen from direction k of
  eight); the engine finds the camera's direction from a building once and
  ANDs: no maths a wall, and a ground corner no wall beside it shows isn't
  transformed or projected. Its data is about a third bigger.
- measured (the harness, the CBD at 70 m, the camera still): both leave out
  a few per cent of the edges drawn and run at the same speed as AUCKLAND
  (78 frames against 75-78): at this distance most buildings are past 300 m,
  where only their tops and uprights are drawn, and the time goes in finding
  and projecting the corners, not in drawing lines
- bas/auckland_block (the Next): the buildings as solid blocks, Lords of
  Midnight style - each its corners' box on the screen (left, right, top,
  foot), a generic wall texture (light grey, a floor line each 4 m storey,
  windows), a pale outline. No building's edges are ever drawn: a corner
  beside or behind the camera takes the block to the screen's side. The lines
  left are the ground's (roads, the coast) and the 3D lines (the Sky Tower,
  the Harbour Bridge, the volcanoes). The ground and 3D lines get half the
  line budget, the blocks their own. Drawn nearest first over a floating
  horizon: each
  column keeps the highest row drawn so far, a block shows only above it, and
  one wholly behind is rejected after its top is projected (its foot only
  when it shows). The ground and the 3D lines are drawn first; each
  tile's buildings go in 64 buckets by distance (32 m each) for the order.
  Real hidden surface removal: buildings hide buildings. In the harness it
  draws 58 frames to the wireframe's 78 at 70 m in the CBD (the filling and
  the ground lines); every building drawn, none missing.
- bas/auckland_street: auckland_mask (the wall masks, S3D2 data) at street
  level - the eyes 2 m up on every view, no roll, the height kept: the cursor
  keys turn and look up / down (to 78 degrees), F looks straight ahead again.
  Turning is round the world's up, so the right axis stays level; walking is
  the way it faces, level, whichever way it looks.
- bas/auckland_bill (the Next): auckland_block with billboards (bk_bill):
  each building one flat face, as wide as its outline's longer side, as tall
  as the building, always facing the camera (a mirror cylinder: from any side
  the same face). Only its middle is transformed, its top projected and its
  foot's row. 49 frames to the block's 58: the faces are wider than the
  boxes, more to fill.
  It flies level - no banking, no diving: the cursor keys and X move it up
  and down (S3d.Climb) - so the buildings stay upright on the screen (the
  horizon's columns need it) and a block's feet are its tops straight down:
  their rows alone are worked out (ve_projy), not their columns.
- the harness's profile (NTC_PROFZ=1), the CBD at 70 m: AUCKLAND - lines 31%,
  projecting 22%, outcodes 12%, the maths 13%, transforming 11%; the blocks -
  projecting 25%, the ground lines 18%, filling only 10%


KEYS
----
cursors     turn left / right, dive / climb
< >         roll
X           climb
Space ?     faster / slower
S           frame skip 0 / 4 / 8 (the camera moves that many frames more
            between the ones drawn: faster over the ground)
1-9         views: the start (200 m up in the gulf, flying in, Rangitoto on
            the right), south of the CBD, the Sky Tower, the Harbour Bridge,
            Devonport, Rangitoto, Mount Eden, One Tree Hill, Mount Hobson
B           detail: 600, 1200, 2400 lines a frame
T           turbo on / off
P           pause
Q           quit (shows the frames drawn and the most lines in one)

A compass (bottom right) points to the city's centre (the Sky Tower) as
seen from above: up is ahead.


THE DATA (AUCKLAND.DAT)
-----------------------
- 3,808K: a 16K header block and 237 data blocks, read whole into the
  expansion RAM at the start (UniDOS's Ctrl J block read, 16K at a time,
  straight into each RAM page)
- the world: 55 x 54 tiles of 384 m (21 x 21 km); a tile is never split
  over two blocks; the header block holds a directory (block, offset for
  each tile), the landmark list and the 9 views
- a tile: 16 byte header, then its buildings (big, middle, small - drawn
  to less distance in that order), ground lines, 3D lines, trees
- buildings: 12 corners at most, each a byte x and z (2 m steps from the
  tile's middle); a height byte (2 m steps, 382 m at most). Heights from
  OpenStreetMap's height or levels, else guessed from the kind and size
- roads: motorways and main roads as two lines, minor roads as one; bridges
  as 3D lines at their deck height
- trees: the mapped ones, and woods and scrub filled with one every 35 m
- landmarks (3D lines): the Sky Tower (328 m), the Harbour Bridge (deck up
  to 43 m, the truss over the main span), a cone for each volcano and peak
  over 25 m (Rangitoto on its island's outline)

Made in a web browser, no install: tools/osmcut cuts an OpenStreetMap .pbf
(BBBike's Auckland extract), tools/s3dmake turns the cut into the .DAT.
Any city works the same way.


THE ENGINE
----------
- all Z80 (S3d.cls, #asm); the BASIC around it is NTC (compiled to threaded
  code)
- the camera: position in 0.5 m units, its axes (right, up, forward) as
  16-bit fixed point (16384 = 1), free in every direction (pitch, roll, yaw)
- each frame: tables of a local x, z and height step's camera-space x, y, z
  (256 + 256 + 192 entries, 6 bytes each) are built from the axes, so a
  vertex is then six additions - no multiplies
- tiles: the 7 x 7 round the camera, nearest first, each with a share of
  the frame's line budget; buildings beyond a tile's distance or out of
  view are dropped before any projection (a first-corner test, then all
  corners' outcodes ANDed)
- landmarks: drawn from 4 to 9 tiles away (3.5 km); Rangitoto, the Sky
  Tower and the Harbour Bridge to 29 tiles (11 km)
- lines clipped to the near plane and the screen, drawn with XOR lines
  into a second screen (double buffering: main RAM #4000-#7FFF), shown at
  the frame flyback
- trees: drawn on the screen as a trunk and a triangle
- mode 1, 320 x 200: white buildings and roads, green volcanoes, cyan
  coast, water and trees
- about 0.3 frames a second (2.5 to 4.5 s a frame at 1200 lines)


MEMORY
------
#0040-#3FFF   the program
#4000-#7FFF   the second screen; also the window the data pages are read
              through (the expansion RAM, 16K a page)
#8000-#8A7F   the program, its variables
#8A80-#8D8B   the RAM pages' tables (3 bytes a page, 4 MB: 260 pages)
#8F50-#A2EF   the engine's tables (the file buffer while loading)
#A2F0-        the firmware and the ROMs' RAM (UniDOS with an IDE node takes
              #A309 up); AUCKLAND stops with a message if the ROMs need more
#C000-#FFFF   the screen

PROFILE
-------
Where a frame's time goes: 23 frames flown on the full data (the start view,
the Sky Tower, the Harbour Bridge, south of the CBD), sampled at a random
point of each 1/300 s (19,152 samples while flying; the loading left out).

  18.4%  vertex transform - the frame tables' additions per corner
  17.1%  projection - the 24-bit divide per point (x / z, y / z)
  14.8%  drawing the lines (gfx_line)
  14.3%  walking the data - tiles, buildings, lines, trees, paging blocks in
  13.7%  multiplies - each tile's position against the camera (tile dots,
         landmark tiles too), the frame tables, the trees' / 3
  13.2%  clipping, outcodes, edges
   4.8%  compares
   3.6%  the rest (NTC's own code, clearing the screen 0.3%)

So about 70% is calculation and walking the data, 15% putting pixels on the
screen. A frame: 2.5 to 4.5 s at 1200 lines.
