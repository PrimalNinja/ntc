AUCKLAND - a real city on a Z80
================================

Fly over Auckland, New Zealand, in wireframe, on an Amstrad CPC with 4 MB of
expansion RAM. The whole city is in memory: 233,935 buildings, 43,082 road,
rail, coast and water lines, 50,040 trees, the Sky Tower, the Harbour Bridge
and the volcanoes - from OpenStreetMap, 409 square km.

Map data (c) OpenStreetMap contributors, ODbL (openstreetmap.org/copyright).


NEEDS
-----
- CPC 6128 or 464 (Z80, 4 MHz), 4 MB RAM expansion (200 RAM pages or more)
- UniDOS with a mass storage node (IDE, SD ...): AUCKLAND.DAT is 3.8 MB
  (without UniDOS's block read it loads a byte at a time: far too slow)
- WinAPE works too: IDE drive = AUCKLAND.IMG, UniDOS ROMs, 4 MB RAM

Files: AUCKLAND.BIN (the program, 35K) and AUCKLAND.DAT (the data), on the
same drive.  RUN"AUCKLAND


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

A compass (bottom right) points north as seen from above: up is ahead.


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
- mode 1, 320 x 200: white buildings and roads, green trees and volcanoes,
  cyan coast and water
- about 0.3 frames a second (2.5 to 4.5 s a frame at 1200 lines)


MEMORY
------
#0040-#3FFF   the program
#4000-#7FFF   the second screen; also the window the data pages are read
              through (the expansion RAM, 16K a page)
#8000-#8A0C   the program, its variables
#8A0D-#8D18   the RAM pages' tables (3 bytes a page, 4 MB: 260 pages)
#8F50-#A2EF   the engine's tables (the file buffer while loading)
#A2F0-        the firmware and the ROMs' RAM (UniDOS with an IDE node takes
              #A309 up); AUCKLAND stops with a message if the ROMs need more
#C000-#FFFF   the screen
