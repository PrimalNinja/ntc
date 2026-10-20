# POLY

(c) 2026 Cyborg Unicorn Pty Ltd - MIT License

A filled-polygon 3D engine for the **ZX Spectrum Next** (28MHz), in the spirit of 3D Starstrike II
on the Amstrad CPC: solid faces, full hidden-surface removal, dithered colours. Written in **NTC
BASIC** with the engine in Z80 (`E3.cls`).

The demo: you start in an asteroid field with a planet in the distance. Fly to the planet, down
through its sky to a city of about 600 buildings, across the rooftops, up and out again. The autopilot flies the whole loop.

## Keys

None: it's a demo. The autopilot flies the whole loop, and the keys are ignored (flying it by hand
into the planet could crash it). `Ctl.cls`, which read Elite's keys (S / X dive and climb, < / >
roll, Space / V faster and slower, Z / C turn, H the autopilot), is still in the build for later.

## What the engine does

- **Screen**: Layer 2, 256 x 192, double-buffered (banks 12 and 15). It is cleared by DMA each frame.
- **Fill**: convex polygons drawn by stack pushes, both edges stepped in registers. That costs about
  225 T-states a row plus 5.5 per pixel. A whole screen takes 161 raster lines. Each polygon gets a
  pair of colours that swap on odd rows (a checker dither): 16 ramps x 16 shades, plus the mixes
  between them.
- **Hidden surfaces**: back faces are dropped (a winding test on the screen, or a normal test in 3D
  when that isn't safe). Objects are sorted far to near, and buildings within the city too. Every
  shape is convex, so nothing needs a depth buffer.
- **Clipping**: a near plane and a guard band in 3D, then a screen-edge clip only on the sides a
  polygon actually crosses.
- **Objects**: each one's rotate-and-translate is self-modifying code, patched per object, with the
  camera pre-scaled for each object size. Detail drops with distance in steps: the full model, a
  cheaper path (8-bit, faces tested before their corners are projected), a low-poly model, a
  hexagon, a dot.
- **Planet**: drawn as a disc from 32 directions round the view cone. From space it gets an
  atmosphere rim and lit bands toward the sun. Close in it becomes a horizon, with ground below and
  sky above. Its height and "up" feed the flight model and the autopilot.
- **City**: 48 x 48 cells on the planet's surface, with roads every 4th cell and 8 kinds of
  building. Only the faces you can see are drawn, picked by where you are relative to each box.
  The farther a building is, the less work it gets:
  - near: exact corners;
  - middle distance: 4 projections, with the other corners worked out from those;
  - farther: one outline polygon in the haze;
  - farthest: each 4 x 4-cell block becomes one box.

  Buildings are depth-sorted with a counting sort.
- **RAM spent on speed**: a 7.5K table for the projection reciprocal, a 2K table for edge slopes,
  sines and square roots, and code unrolled per vertex.

## Speed (measured in ZEsarUX at 28MHz, autopilot loop)

| scene | frames a second |
|---|---|
| open space, planet and a few asteroids | 10 - 24 |
| close among the asteroids (28 of them) | 4 - 5 |
| descending to the city | 3 - 8 |
| low over the city, hundreds of buildings | 3 - 6 |

**Honest comparison with Starstrike II.** I did not measure Starstrike II, so there is no
side-by-side number. What I can say:

- The polygon filler is fast: a full 256 x 192 screen in 161 raster lines (about 10 ms). The Next's
  clock is 7x the CPC's.
- The scenes are far heavier than Starstrike's: a planet, a horizon, and hundreds of buildings at
  once.
- In the city the frame rate is about what Starstrike II manages with its handful of objects. So
  the gain went into "better looking, much more on screen", not into "5x faster".
- With a Starstrike-sized scene (a few objects in space) it runs at 15 - 24 fps.

**Where the time goes in the city:**

| part | share of the time |
|---|---|
| filling rows | 17% |
| city logic | 12% |
| waiting for the frame | 11% |
| fill setup | 9% |
| projection | 8% |
| clipping | 5% |

**Not done** (ideas from the brief that are still open):

- Object code paged into the middle of the Next's RAM and streamed in. Everything currently fits in
  the main 64K.
- A quad fast path in the filler.
- Not drawing the planet's ground under the city's ground plate.

## Files

| | |
|---|---|
| `Main.bas` | the demo: flight, autopilot, panel |
| `E3.cls` | the engine (BASIC wrappers, all the Z80) |
| `E3Data.cls` | tables and models, made by `tools/gen_data.py` |
| `Ctl.cls`, `Nx.cls` | keys and Kempston; NextRegs |
| `tools/gen_data.py` | palette, tables, asteroid models, the city, font, stars |
| `tools/gen_xform.py` | writes the unrolled transform code |
| `build/POLY.NEX` | run it |
| `assets/` | screenshots (`x3_` copies enlarged) |
| `test/` | emulator scripts (see below) |

## Building

```
python3 tools/gen_data.py      # only after changing the tables, models or city
node test/nb.js .              # compile and assemble: build/POLY.NEX
```

`nb.js` needs NTC BASIC's `src` folder (its second argument, or `NTC_SRC=`) and `sjasmplus` on the PATH.

## Testing (test/)

These drive a headless ZEsarUX (`ZESARUX=` its path):

- `tour2.py NEX secs every` takes clean screenshots during the autopilot loop, with the frame rate,
  height and waypoint for each.
- `fpsv.py NEX` counts frames over 6 seconds.
- `bench13.sh` runs the fixed city view (`t13`) with the current engine.
- `prof3.py NEX` shows where the time goes, grouped by routine.
- `pc.py` and `peek.py` sample the program counter and read memory.

Screenshots taken while the emulator runs can show a single black row; that is the emulator
capturing mid-frame, not the program. `tour2.py` pauses the emulator for each shot.
