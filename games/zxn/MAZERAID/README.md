# MAZE RAID - a maze chase

(c) 2026 Cyborg Unicorn Pty Ltd - MIT License

A game for the **ZX Spectrum Next**, written in **NTC BASIC** (VB5 flavour) and talking straight to the hardware: tilemap, sprites, Layer 2 and the AY are all driven directly. It makes a `.NEX` file.

A beetle bot clears the maze of power dots while four hover sentries hunt it. Grab a power cell
and the sentries turn blue and run: catch them for 200, 400, 800 and 1600. A bonus item turns up
under the pen twice a level. Each sentry hunts its own way:

| Sentry | Hunts |
|---|---|
| SPARK (red) | straight at you |
| GLITCH (pink) | four cells ahead of you |
| BOLT (cyan) | from the far side, lined up through SPARK |
| DRIFT (orange) | at you when far off, then breaks off to its corner |

The sentries switch between scattering to their corners and chasing, on a timer. The tunnel
slows them down, and caught sentries fly back to the pen as eyes. The maze is an original
layout, 27 x 27, and the walls are drawn automatically from it.

## Keys

| | |
|---|---|
| Q A O P, or the cursor keys (5 6 7 8) | up, down, left, right |
| Kempston joystick | move |
| Space | start |

## How it uses the hardware

- **Tilemap:** the maze, dots, flashing power cells, door and side panels. The wall tiles are
  picked from 16 shapes by which neighbours are walls too. When a level is cleared, the walls
  flash through a palette change.
- **Sprites:** the beetle, mirrored for left and down. Each sentry is two sprites: a body in its
  own palette row, with eyes on top that look the way it is going. Also the bonus items and the
  score pop-ups.
- **AY:** munching, the power siren, caught sentries, the bonus and losing a life.
- Runs at a full 50 frames a second.

## Files

`Main.bas`, `Nx.cls`, `Spr.cls`, `Tiles.cls`, `Sfx.cls`, `GfxData.cls`. Also `gfx/` (the art and its layout), `gfxtool.js` (art to `GfxData.cls`), `build.js` (the whole build), `game.json` (the file list for build.js), `MAZERAID.json` (the IDE project) and `build/` (`MAZERAID.asm` and `MAZERAID.NEX`, ready to run).

## Building it

Everything is plain NTC BASIC, VB5 flavour, platform `zxn`. The BASIC compiler and library are
NTC's own, unchanged. The game only brings its own classes.

**In the IDE (`ntc.html`):** use **Open...** to load `MAZERAID.json`. It brings in every file, with
the platform set to ZX Spectrum Next and the mode set to turbo. Then **Save .asm** and run
`sjasmplus MAZERAID.asm`, which writes `MAZERAID.NEX`.

**From the command line:** `node build.js path/to/ntc/src` does the lot. It rebuilds `GfxData.cls`
from `gfx/`, writes `MAZERAID.json`, compiles to `build/MAZERAID.asm`, and assembles `build/MAZERAID.NEX`
if sjasmplus is on the PATH. If you drop the game folder into `src/bas/`, you can leave the path
off.

`build/` already holds a built `MAZERAID.asm` and `MAZERAID.NEX`.

**Running it:** copy `MAZERAID.NEX` to the Next's SD card and pick it in the NextZXOS browser. It
takes over the whole machine: no ROM, no OS, 28MHz. To leave, reset.

## Swapping the graphics

All the art lives in `gfx/` as PNG files. The game never refers to a cell by its number. It uses
the names in `gfx/layout.txt` (`GfxData.S_PLAYER`, `GfxData.T_WALL` ...), so new art drops in
without touching the BASIC.

1. Edit the PNGs, or draw new ones the same size:
   - `tile_pal.png`: 16 x 1 pixels, the tilemap's 16 colours. Colour 15 is see-through.
   - `tiles.png`: 128 pixels wide, 8 x 8 cells, 16 to a row. Cell n is tile n. Cells 32-126 are
     the font, because Print and Tiles.Text use the character code as the tile number.
   - `spr_pal.png`: 16 x N pixels. Row 0 holds the sprite colours the sheet is drawn in. Rows
     1 and up are other colourings of the same 16 slots, which the game picks with a palette
     offset.
   - `sprites.png`: 256 pixels wide, 16 x 16 cells, 4 bit (15 colours plus see-through).
   - Magenta (#FF00FF) or see-through pixels come out transparent. Any other colour is matched
     to the nearest palette entry.
2. If you move things around, change `layout.txt` to match. A sprite entry is
   `sprite NAME col row [frames [w h]]`, a tile entry is `tile NAME index [count]`.
3. Run `node gfxtool.js build`, or `node build.js`, which runs it for you. That rewrites
   `GfxData.cls`. In the IDE, open the new `GfxData.cls` in place of the old one, or open the
   new `MAZERAID.json`.

`node gfxtool.js info` lists what the sheets hold. `node gfxtool.js grid` writes
`gfx/*_grid.png`: the sheets blown up 4x with the cell grid drawn on and the named cells boxed.
It's a guide for drawing over; gfxtool doesn't read those files back.

The Next holds at most 128 four-bit sprite patterns and 256 tiles, and gfxtool stops with an
error if the layout asks for more.

## The hardware classes

These are shared by all five games. Every method is an `#asm` keyword or a few lines of BASIC.
No Z80N opcodes are used except in SOLAR's View.cls, so any Z80 assembler builds them.

| Class | What it does on the Next |
|---|---|
| `Nx.cls` | NextRegs through `#243B`/`#253B`, the layer order (`#15`), palettes (`#40`/`#41`/`#43`), raster line, border, `Seed` |
| `Spr.cls` | 128 hardware sprites: a table of 5-byte attributes in RAM, sent by `Show` through `#303B`/`#57` straight after `Frame`; 4-bit patterns, mirror, rotate, scale 1x-8x, palette offset |
| `Tiles.cls` | The tilemap as a 40 x 32 4-bit picture over the whole 320 x 256 display. The map stays at bank 5 + `#2000` so `Print`/`Locate` still work; tile definitions sit at bank 5 + `#0000` (`#C000`), which means the ULA is switched off |
| `Sfx.cls` | AY 1 through `#FFFD`/`#BFFD`: three channels of sliding-pitch, fading tone or noise effects, updated once a frame |
| `GfxData.cls` | Made by gfxtool.js: the palettes, tile definitions and sprite patterns as data, plus `Load` to put them into the hardware |

Every game runs in turbo mode (`Option Turbo`): interrupts stay off and `Frame` times each frame
by reading the raster line (NextRegs `#1E`/`#1F`).

## Memory

The program, its arrays and the graphics data sit in RAM pages 16-21 at `#0040-#BDFF`, with the
stack at `#BE00-#BFFF`, laid out the same as the CPC (the zxn platform). Bank 5 is at
`#C000-#FFFF`: tile definitions at `#C000-#DFFF` and the tilemap at `#E000`.

The font is font8x8_basic (public domain), the same as the zxn platform uses. All the art is original.

## Screenshots

Taken in an emulated Next (320 x 256, shown at 2x), in `screenshots/`:

![1_title](screenshots/1_title.jpg)
![2_play](screenshots/2_play.jpg)
![3_powered](screenshots/3_powered.jpg)
