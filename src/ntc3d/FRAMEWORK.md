# NTC3D

(c) 2026 Cyborg Unicorn Pty Ltd - MIT License

NTC3D (NTC's `src/ntc3d/`) is a 3D framework for **NTC BASIC on the ZX Spectrum Next**: solid, shaded, filled polygons on
Layer 2 at 256 x 192, double buffered. It works the way JSprites works for 2D. You describe your
models once. Each object in the world gets a class, a mask and a *mover*: a Z80 behaviour that moves
it every frame by itself. One call a frame moves everything and finds what hit what. Another call
draws it all. Your BASIC is the game: what's where, what each happening does, the score. It never
loops over the objects to move or test them.

It's DIREMOON STRIKE's engine and object code, taken out of the game and made general. DIREMOON
STRIKE is now built on it. `example/ROCKS` is a second, small game written in pure BASIC on it.
IRON DUST, a tank battle on a planet's surface, is the third: it brought the ground features
(Ground games, below).

## Contents

| | |
|---|---|
| `E3.cls` | the 3D engine (POLY's, changed): camera, objects, polygon filler, clipper, stars, moon disc, flat faces in the world, text, the ULA text layer, the frame counter |
| `Obj3D.cls` | the objects: the table, the movers, the hits, the events, bolts, debris, fireballs, drawing |
| `Fly3D.cls` | flying the camera from a set of control bits, with optional assist; keeping the world near the middle (Rebase) |
| `Hud3D.cls` | the HUD: text and numbers on the ULA over the picture, bars, scanner, cross hairs |
| `Nx.cls` | NextRegs and palettes (E3 uses it) |
| `tools/e3models.js` | the model tool: a model file to `E3Data.cls`, `build/NAME.DAT` and a picture of the models |
| `tools/build.js` | builds a game: the IDE project, the asm, the NEX |
| `tools/zesshot.js` | runs a NEX in ZEsarUX and saves pictures of the screen (ZESARUX=) |
| `tools/prep.js` | the build's settings, applied to the framework's sources as they're read: how many objects, which optional parts (Build settings, below) |
| `tools/emu/` | the emulator the tests run on (Python 3): a ZX Spectrum Next with Layer 2, the ULA, the AY's ports, NEXTREG and the zxnDMA, screenshots (the ULA's paper colours from palette entries 16-31, as on the Next). Needs `pip install z80 pillow`. |
| `example/ROCKS/` | the example game: `Main.bas`, `models.js`, `test/run.py`, its `build/` |
| `screenshots/` | ROCKS, DIREMOON STRIKE, IRON DUST and the model tool's pictures |

Everything is ES5 JavaScript for node (the tools) and NTC BASIC with Z80 in `#asm` blocks (the
classes). No sprites, tilemap or copper are used.

## The ideas

**The world.** x right, y up, z ahead at the start. Positions are 16 bit whole numbers, so the
world is 65536 units across. Fly3D.Rebase moves the camera and everything with it back near the
middle now and then. A ship is a few hundred units across.

**Time.** Game time is in 50ths of a second. Each picture moves everything on by dt, the 50ths the
last one took, so the game runs at the same speed whatever the frame rate. The frame count comes
from the raster (interrupts are off): `E3.vbl` goes up once a frame. The drawing looks at it all
the time. `E3.vhook` is called every frame it sees go by, and the game can hang its sound tick
there.

**The picture.** Layer 2 has two buffers. You draw into the one not on show, then `E3.Flip` shows
it at the frame's end. A picture goes:
- `E3.Begin c`: clear the buffer (the zxnDMA does it);
- `E3.Stars`, your background (a moon, a ground plane, big flat faces);
- `Obj3D.Draw`: the objects, far to near;
- the HUD;
- wait for the frame, then `E3.Flip`.

**Models.** Each model is one convex solid of up to 64 points and 16 points a face. The model tool
works out its faces from a cloud of points. Each *kind* has a near model and a far one, and a hit
box. Faces are shaded by the sun in 16 steps of their colour ramp: the palette is 16 ramps of 16
shades. Far away an object is drawn with its far model. Further still it's a dot.

**Objects** (Obj3D, up to 32). Each one has:
- a model kind and size;
- where it is, its speed and its turn (spin);
- its class and mask;
- its hit box;
- its mover, the mover's state, timer and settings;
- flags, a life, a gun;
- two numbers of yours (`otype`, `ouv`).

**Classes and masks.** A class is a number 1 to 15. `CL_PLAYER` (1) is you, the camera: never an
object. A mask has bit c set (2^c) for each class the object hits. Only the masks are tested. If no
mask has a class's bit, nothing tests against that class. That keeps the hit test cheap.

**Hits.**
- Against you: an object with `M_PLAYER` in its mask hits you when the camera passes through its
  hit box. That means it crosses the view's plane within the box across and up, so fast things
  can't skip through. With the `ground` feature it counts either way through (from behind too, or
  backing into it) and while you're in it.
- Against other objects: two objects hit when their boxes overlap. The box is `ohw` across and
  along, `ohh` up.

**Events.** `Obj3D.Update` puts what happened on a queue (up to 32 a frame). The game reads it with
`Obj3D.NextEvent`:
- `EV_HIT` (ea hit eb; eb 255 = you);
- `EV_FIRE` (ea's gun is ready and you're in front of it);
- `EV_LAND` (ea, flagged `OF_LAND`, has come down to the ground: `ground` feature).

The framework never decides what a hit does. That's the game's job.

## The classes

Arguments are integers unless shown. Colours are palette indexes: ramp x 16 + shade.

### E3: the engine

`E3.Init`: Layer 2 and the other display registers, the palette from the data block, both buffers
cleared, the ULA's screen wiped see-through. Call it first.

| Camera | |
|---|---|
| `CamReset` | at 0, 0, 0 facing +z |
| `CamPos x, y, z` | put it there |
| `CamGet(k)` | its x, y or z (k 0, 1, 2) |
| `CamTurn p, y, r` | turn about its own right (pitch), up (yaw) and forward (roll) by p, y, r / 16384 radians |
| `CamMove s` | move it s / 16 units ahead |
| `cm(0..8)` | its right, up and forward in the world (s1.14: 16384 = 1) |

| Picture | |
|---|---|
| `Begin c` | start a picture: clear to colour c (c under 0: leave it) |
| `Begin2 c1, c2, yb` | the rows above yb c1, from yb down c2 (c2 under 0: leave them) |
| `Stars` | `nstar` stars (up to the data's NStars), none from row `stymax` down |
| `Moon c0, c1, c2` | the planet at `ppos` (x, y, z / 256), radius `prad` (/ 256): a flat disc lit toward the `sun` |
| `HPlane ux, uy, uz, c, yb` | a flat ground plane to the horizon (the camera's up / 256), down to row yb |
| `HQuad x0, x1, y, z0, z1` / `VQuad x, y0, y1, z0, z1` / `Quad3` | big flat faces straight in the world, colour pair `pc` (see Main.bas DrawTrench in DIREMOON STRIKE) |
| `Poly n, c` / `Fill` | a 2D polygon `pvx()`, `pvy()` |
| `Box x, y, w, h, c` | a rectangle |
| `Dot x, y, c` | a 2 x 2 dot |
| `Text x, y, s, c` / `Num x, y, v, n, c` / `Char x, y, ch, c` | the 5 x 7 font; `txs` 1 - 3 times its size; on the ULA when `uto` = 1 |
| `Flip` | show the picture just drawn |
| `Poll`, `WaitWrap`, `vbl`, `rline` | the frame count and the raster line |
| `Radar x, y` | scanner dots (Hud3D.Scanner uses it): x and z / 1024; with the `ground` feature / 512 (a nearer scanner) |
| `Skyline tab, n, yb` | mountains on a level camera's skyline: n peaks from an Integer array (`VarPtr`), 6 words each: bearing x, z (127 = 1), half width and height in pixels seen head on, colours (as `pc`), top (0 a point; k flat, w / 2^k each side). Triangles standing on row yb + 1, drawn in order. |
| `Texts n` | text page n of the model file's `texts` (from the data bank) on the ULA: each line's x, y, ink and text in one call. Fixed title and help text kept out of the program. |
| `UClr y, x0, x1` | the ULA text cells under text at y, x0 .. x1 cleared; with `uca` = 1 their attributes too (a paper backing gone: see-through) |
| `UInk i, c` | the ULA's palette entry i the colour of Layer 2's colour c. Inks are 1-15; a paper backing is paper p (attribute + p * 8) and entries 16 + p, 24 + p. Init makes 16-31 see-through, so set them again for a dark backing behind HUD text. |
| `lodb` | how far the far model goes before an object's drawn as a blob: 128 / 2^lodb pixels across (2 from Init: 4 pixels; 1: 8 - cheaper with many things far off) |

The objects' part of E3 (`obj()`, `ViewAll`, `Scene`, `vwx/vwy/vwz()`) is Obj3D's to drive.

### Obj3D: the objects

`Obj3D.Init` after E3.Init.

**Making and taking out**

| | |
|---|---|
| `Spawn(kind, size, class, x, y, z, dot)` | a new object in the first free slot of `lo` .. `hi` - 1, or -1 when there's no room. Its radius and hit box come from the model x 2^size, dot is its colour when it's a dot. It starts still (MV_STILL) with no mask, flags, life or gun. |
| `Kill i` | take it out |
| `Clear` | take them all out, forget the events |
| `Count(class)` | how many there are of a class |

**Setting it up**

| | |
|---|---|
| `SetVel i, vx, vy, vz` | its speed, units a 50th |
| `SetMover i, mover, flags` | its mover and flags (state and timer back to 0) |
| `Hold i, dist, across, up, faster, time` | MV_HOLD's settings in one go |
| `Spin i, a, b` | it turns by a (about y) and b (about x) 256ths a picture |
| `Mark i, c` | its colour on the scanner |
| `Move i, x, y, z` / `Pos i` | put it somewhere / where it is (into `px, py, pz`) |
| `Aim i, x, y, z, speed` | its speed pointed at a point (the biggest part = speed, under 256) |
| `AimAt x, y, z, speed` | the same sum into `avx, avy, avz` |
| `OnScreen(i)` | 1 when it's in the view |

Its numbers can be read and set straight: `ocls, omask, omv, oflg, ost, otm, olife, ogun, otype,
ouv, ovx, ovy, ovz, opa, opb, ospd, odist, ohw, ohh` (each `(0 .. 31)`).

**Shooting and blowing up**

| | |
|---|---|
| `BoltModel kind, size, dot` / `blife` | the bolts' model and life (50ths) |
| `FireAt(from, x, y, z, speed)` | a bolt from object `from` toward a point: class CL_EBOLT, it hits you. Returns its slot. |
| `Fire(from, speed)` | at you. From -1, from you along your way: class CL_PBOLT, hitting the classes in `pmask` (enemies and scenery to start with). |
| `DebrisModel kind, size, dot, fall` / `dflg` | the debris's model; fall is how fast its bits fall; `dflg` their flags (`OF_LAND`: they come down and lie on the ground) |
| `Burst x, y, z, n, vx, vy, vz` | n bits of debris flying off a point, each living about a second |
| `BlastModel kind, dot` / `Boom i, size` | object i becomes a fireball for 16 50ths, a size bigger for the last 8; it hits nothing |

**Each frame**

| | |
|---|---|
| `Update dt` | everything moved on by dt 50ths (lives and guns counted down, flags seen to), `E3.ViewAll`, then the hits: events queued |
| `NextEvent()` | the next event (`EV_FIRE`, `EV_HIT`, `EV_LAND`; its objects in `ea`, `eb`), 0 when there are no more |
| `Pick(mask, range)` | the nearest object of a class in mask under the cross hairs, nearer than range (a laser), or -1. `pky` (0 normally) raises the line it looks along: y = z * pky / 128 in the view (a gun's elevation; IRON DUST's cross hairs sit at row 96 - pky). |
| `Draw` | every object drawn, far to near, as Update last saw them |
| `Shift dx, dy, dz` | everything moved back (Fly3D.Rebase does it) |

The station keepers need your speed (`pvx, pvy, pvz`: a 50th's move) and your way ahead, lagging
(`hfx, hfy, hfz`, s1.14). Fly3D.Steer and Fly3D.Drive keep them.

**Movers** (`omv`)

| Mover | What it does | Its settings |
|---|---|---|
| `MV_STILL` | stays put (its spin still turns it) | |
| `MV_STRAIGHT` | on by its speed | ovx, ovy, ovz |
| `MV_FALL` | on by its speed, falling faster | opa: the fall a 50th |
| `MV_BLAST` | a fireball: still, a size bigger for its last 8 50ths of life | olife |
| `MV_HOLD` | keeps station ahead of you, weaving, held for a while, then a run in to 1500 ahead, a break off up and out, and back (ost 0, 1, 2). Its offsets don't turn with you: roll and it moves round the screen | odist: how far ahead; opa, opb: across and up (world x, y); ospd: how much faster than you it may go; otm: how long it holds |
| `MV_HOLDONLY` | MV_HOLD that never runs in (a big ship) | as MV_HOLD |
| `MV_CHARGE` | straight at you; within 2500 it turns to MV_PASS | ospd |
| `MV_PASS` | on through, facing its way; taken out 3000 behind you | |
| `MV_TURN` | turns after you and keeps after you, odist ahead | odist, opa, opb, ospd |
| `MV_WEAVE` | on by its speed, swaying | opa: across, opb: up (amounts a 50th) |
| `MV_ORBIT` | round a point at its height | opa, opb: the point (x, z); odist: how far out; ospd: 256ths of a turn a second |
| `MV_CIRCLE` | (ground) round you at its height, facing you: strafing | odist: how far out; ospd: 256ths of a turn a second (minus: the other way); opa: its top speed each way a 50th; ost: its angle (8.8) |
| `MV_HUNT` | (ground) drives at you till it's odist off, then creeps round you facing you. Every otm 50ths it falls back behind object opb (its cover) for 90, then hunts for 150 (ost 0 hunting, 1 in cover) | odist, opa (top speed), opb (the cover's slot, -1 none), otm |
| `MV_HOME` | (ground) a homing missile: in on you in 3D, turning fast, facing its way | opa: its top speed each way a 50th |

The ground movers steer: the speed each way goes dt / 8 of the way to (the point - it) / 8, kept
within opa. They move on x and z only (their height stays), MV_HOME on all three.

The station keepers' steering: the speed it wants is your speed plus (the point - it) / 8, kept
within yours ± ospd. Its speed goes dt / 8 of the way there each step. That's why they stay in
view while you turn.

**Flags** (`oflg`)

| Flag | |
|---|---|
| `OF_BEHIND` | taken out when 2500 behind you along the world's z (things on a run) |
| `OF_WRAP` | put back 9000 ahead of you (at opa across, opb up) when it's 14000 away |
| `OF_FACECAM` | turned to look at you |
| `OF_FACEVEL` | turned to look along its way |
| `OF_LAND` | (ground) when its y comes down to `gy`: put there, stopped, its spin stopped, the flag cleared, an `EV_LAND` event (a mortar shell; debris with `dflg`) |
| `OF_GUNANY` | (ground) its gun's ready with you anywhere within 8500, not only in front of you |

**Guns.** `ogun` counts down. When it runs out with you 700 to 8500 in front of the object you
get an EV_FIRE event and the gun stops. Set `ogun(i)` again in your event code to re-arm it. A
station keeper breaking off doesn't fire. With `OF_GUNANY` it's you anywhere within 8500.

### Fly3D: flying

`Fly3D.Init` sets everything to its starting values, the camera as it is.

| | |
|---|---|
| `Steer keys, dt` | fly dt 50ths with the controls in keys: `K_DIVE 1, K_CLIMB 2, K_ROLLL 4, K_ROLLR 8, K_FASTER 16, K_SLOWER 32` (any source: keys, stick, the game). Roll and pitch build up while held, the speed changes, the camera turns and moves, Obj3D gets your speed and way. |
| `Drive keys, dt` | a ground vehicle for dt 50ths: `K_FWD 1, K_BACK 2, K_LEFT 4, K_RIGHT 8`. The turn builds up and eases off (`tmax`, `ease`); forward up to `smax`, back to `smax / 2`, rolling to a stop with neither (`acc`). The camera's kept level, so the horizon is always row 96; its height is yours (`E3.CamPos`). |
| `Reset` | no roll or pitch going; your way ahead is where the camera looks |
| `GetCam` | `cx, cy, cz` from the camera |
| `Rebase()` | past `rlim` (8000) from the middle on a way that's on (`rbx, rby, rbz`), the camera, the objects and the planet go back by whole 256s. dx, dy, dz say how far, so move your own world numbers too. 1 when it moved. |

Its settings:
- `rmax`, `pmax` (380, 280): the roll and pitch rates held.
- `ease` (5): how slowly they build and ease off.
- `acc` (50): the speed's change a 50th.
- `smin`, `smax`, `spd` (400, 4000, 1600).
- `tmax` (300): Drive's turn rate held.
- `assist`:
  - `AS_NONE`.
  - `AS_RUN`: a bank turns you, and the nose comes back round to +z when you let go. This is for a
    run along the world's z.
  - `AS_TRENCH`: AS_RUN, plus the pitch levels and the roll's limited.

### Hud3D: the HUD

Text on the ULA's screen sits over the picture and costs nothing a picture: draw it when it
changes. Each 8 x 8 cell has one colour, so put text at y = 8n or 8n + 1 and keep different
colours in different cells.

| | |
|---|---|
| `Ink n, c` | ULA ink n (1 - 7) = Layer 2 colour c |
| `Text x, y, s, ink` | text on the ULA (over what's there) |
| `Num x, y, v, n, ink` | a number in n places, its cells cleared first |
| `Clear y, x0, x1` | clear the text cells from x0 to x1 on the rows text at y covers |
| `Wipe` | all the ULA text gone |
| `Cross x, y, ink` | cross hairs on the ULA |
| `Bar x, y, w, h, v, vmax, c, bg` | a bar in Layer 2 (each picture, after Obj3D.Draw) |
| `Scanner x, y, w, h, frame, bg` | the scanner in Layer 2: you in the middle, ahead up it, each marked object a dot |

## The model tool

```
node tools/e3models.js models.js [game folder] [--name NAME] [--png models.png]
```

It writes `E3Data.cls` (the K_ constants, `MaxV` and `MaxFV` - the most points in a model and in a
face, which the build sizes E3's vertex buffers by - the sines, the font, the edge table (256
reciprocals), where the data block's tables are) and `build/NAME.DAT` (the data block: projection
table, palette, stars, model table, hit table, models). The model file is a node module that gets
the builder M:

```js
module.exports = function (M) {
  var GREY = 0, RED = 2, FIRE = 3;
  var ramps = [ { a: [0, 0, 0], b: [1, 1, 1] }, ... 16 of them ];   // darkest, lightest, lift
  var dart = M.Model('dart', M.mirrorX([[0, 0, 120], [0, 24, -60], [0, -18, -60], [100, -6, -70]]),
    function (n, c, k) { return n[2] < -0.85 ? FIRE : RED; });      // normal, middle, face number
  return { ramps: ramps,
           kinds: [ M.kind('DART', dart, dart, [60, 30]) ],          // near, far, hit box
           stars: { n: 64, seed: 3 } };
};
```

- **`M.Model(name, points, colour, opt)`.** Points are whole numbers -127 .. 127; a model unit is
  2^size world units. Colour gives each face a ramp.
- **`opt.keep(face)`** can drop faces, for a one sided panel.
- **`M.oneFace(name, points, ramp)`** is a single face.
- **Helpers:** `M.mirrorX`, `M.random(seed)` (Python's generator, so data made by DIREMOON STRIKE's
  old Python tool comes out byte for byte the same), `M.round` (Python's rounding), `M.norm`,
  `M.mul`, `M.dot`, `M.cross`.
- **`M.Compound(name, parts, opt)`.** A model built of several convex parts (each an `M.Model`),
  drawn as one object. The tool merges them into one model with its faces in a painter's order: part
  A goes before part B when one of A's face planes has the eye on one side and all of B on the
  other; parts it can't order go by distance. That order holds for one eye point, `opt.eye` (model
  units, default `[0, 60, 2000]`: ahead and a little above). With `opt.views: 2` the tool makes
  two orders, from ahead and from behind (eye z mirrored), and E3 picks the one for where the
  camera is each time it draws the object (one test: the sign of the camera's offset along the
  object's facing). A tank whose hull is below the eye can then have its turret, gun barrel and
  missile pods as separate boxes. Limits: 64 points and 64 faces in all, and the order is only right
  for views near the eye(s): keep the parts' layout simple (a hull under the eye, things standing on
  it; a rotor above a flyer seen from below). `M.box(x0, x1, y0, y1, z0, z1)` gives a box's corners.
- **Text pages: `texts`.** An array of pages, each a list of `[x, y, ink, text]` lines (x under 0:
  in the middle; characters 32 - 95). They go in the data bank from #E000 up (the ULA's screen is
  in slot 6 while text is drawn, so the data must be in slot 7); `E3.Texts n` draws page n.
- **The skyline: `skyline`.** An array of peaks, each `[x, z, half width, height, colours, top]`
  (as `E3.Skyline` takes them). It goes in the data bank and E3Data gets `SkyAt` and `NSky`:
  `E3.Skyline E3Data.SkyAt, E3Data.NSky, 96`.
- **`M.kind(NAME, near, far, hit)`.** The hit box is [across, up] half sizes in model units. Left
  out, it's the near model's extents.
- **`stars.colour(rnd, i)`** can colour the stars.

Each kind is K_NAME in BASIC, numbered in order. Up to about 4K of models fit in the block with
the tables.

To add a model: put it in the model file, add a kind, run the tool, and Spawn it by its K_ name.

## Build settings

`node tools/build.js <game folder> [NTC's src folder]` reads the game's `game.json`:

```json
{ "name": "IRONDUST", "framework": ".", "files": ["Main.bas", "E3Data.cls", "Ctl.cls", "Snd.cls"],
  "nobj": 36, "features": ["ground", "noquad3", "noflyers"] }
```

- **`framework`**: where NTC3D's classes are (E3, Nx, Obj3D, Fly3D, Hud3D are added from there).
- **`nobj`**: how many objects (8 - 64; 32 when not given). Obj3D's arrays and E3's object tables
  are sized to it (lines tagged `@objarr`, `@objtab`, `@nobj`): about 64 bytes an object.
- **`features`**: optional Z80, in `; @if NAME` / `; @else` / `; @end` blocks (`; @if !NAME`: kept
  unless the game names it):
  - `ground`: the ground movers (MV_CIRCLE, MV_HUNT, MV_HOME), OF_LAND / EV_LAND, OF_GUNANY, the
    either-way hit test against you, the nearer scanner;
  - `noquad3`: leaves out the flat faces in the world (Quad3, HQuad, VQuad: 400 bytes);
  - `noflyers`: leaves out MV_CHARGE, MV_PASS, MV_TURN, MV_WEAVE, MV_ORBIT and OF_WRAP (600 bytes).
- E3's vertex buffers are sized from E3Data's `MaxV` and `MaxFV` (lines tagged `@verts`): a game
  with small models gets back up to 800 bytes.

All of it is done by `tools/prep.js` as the sources are read: the files on disc don't change.

## Memory

| Where | What |
|---|---|
| `#0000 - #BDFF` | the program: NTC's runtime, the classes, your code, every variable and array (MMU pages 16-21, banks 8-10). **It must end below `#BE00`**: the build prints how much room is left. |
| `#BE00 - #BFFF` | the stack (the real one: Z80 code calls on it) |
| `#C000 - #FFFF` | between drawings, the data block (Option NexData, bank 1: pages 2, 3). While drawing, Layer 2's buffer 64 rows at a time, and the ULA's screen (page 10) for HUD text: each drawing call puts the data block back when it's done |

| Bank | |
|---|---|
| 1 | the data block |
| 5 | the ULA's screen (the HUD text) and NTC's start stub |
| 8 - 10 | the program |
| 12 - 14, 15 - 17 | Layer 2's two buffers |

Nothing is past bank 47, so a 1MB Next is enough.

**What the framework takes.** ROCKS, a whole game with the full framework, ends at `#7654`: 18.3K
left for a game's own code and arrays. DIREMOON STRIKE ends at `#B2AD` (2.9K left). IRON DUST, with
34 objects, the ground feature and the two left-outs, ends at `#BDA7`: 89 bytes left. Objects: `nobj` in game.json (Build
settings).

E3's polygon filler has two 256-byte tables and a 128-byte run of pushes that must sit on 256-byte
boundaries (`ALIGN`), so up to 255 bytes before them go spare, and how many changes as the code
before them grows. Keep 300 bytes in hand.

**Rules for your own Z80.**
- Never push or call on the thread: SP is NTC's thread pointer. Save SP, switch to `(ntc_csp)`,
  and put it back after.
- A Sub whose body is only `#asm` gets its parameters' addresses on the thread: pop them. A
  procedure with BASIC in it too sees them as variables (`{name}`).
- Interrupts stay off.
- In a long loop of your own (over the objects, say), call `fn_e3_lib_vpoll` now and then (every
  tenth of a frame or so: it keeps every register but DE). The frame count only goes up when
  something looks at the raster; a stretch of over a frame with no look loses one, and Sync then
  waits a frame too long. Obj3D's loops and ViewAll do it every 8th object.

## A worked minimal example

A rock you can fly round and shoot:

```basic
Option Explicit
Option Turbo
Option NexData "DEMO.DAT", 1
Dim dt As Integer, vflip As Integer, e As Integer, s As Integer, k As Integer

E3.Init
Obj3D.Init
Fly3D.Init
Obj3D.BoltModel E3Data.K_BOLT, 1, 12 * 16 + 14
Obj3D.DebrisModel E3Data.K_SHARD, 2, 3 * 16 + 10, 0
Obj3D.BlastModel E3Data.K_FIREBALL, 3 * 16 + 14
Fly3D.spd = 800                                              ' (slow: 50 units a 50th)
s = Obj3D.Spawn(E3Data.K_ROCKA, 3, Obj3D.CL_ENEMY, 0, 0, 12000, 6)
Obj3D.Spin s, 1, 2
Do
  k = 0
  If (Inp(&HFDFE) And 2) = 0 Then k = k Or Fly3D.K_DIVE      ' S
  If (Inp(&HFEFE) And 4) = 0 Then k = k Or Fly3D.K_CLIMB     ' X
  Fly3D.Steer k, dt
  If (Inp(&HFDFE) And 1) = 0 Then s = Obj3D.Fire(-1, 200)    ' A: a bolt
  Obj3D.Update dt
  Do
    e = Obj3D.NextEvent()
    If e = 0 Then Exit Do
    If e = Obj3D.EV_HIT Then                                 ' a bolt hit the rock
      Obj3D.Kill Obj3D.ea
      Obj3D.Pos Obj3D.eb
      Obj3D.Burst Obj3D.px, Obj3D.py, Obj3D.pz, 4, 0, 0, 0
      Obj3D.Boom Obj3D.eb, 3
    End If
  Loop
  E3.Begin 0
  E3.Stars
  Obj3D.Draw
  Do While E3.vbl - vflip < 3
    E3.WaitWrap
  Loop
  Frame
  E3.Poll
  E3.Flip
  dt = E3.vbl - vflip : vflip = E3.vbl
Loop
```

`example/ROCKS/Main.bas` is the same idea grown into a game, with no Z80 of its own (183 lines of
BASIC):
- **Rocks** drift (MV_STRAIGHT, OF_WRAP) and take two shots.
- **A beacon** goes round the middle (MV_ORBIT).
- **Drones** sway their way across (MV_WEAVE, OF_FACEVEL).
- **Hunters** turn after you and keep 2500 ahead (MV_TURN), firing when their gun's ready
  (EV_FIRE: Obj3D.Fire).
- **The HUD** has a score on the ULA, a shield bar and a scanner.

Build and run it (node for the tools; sjasmplus on the PATH for the NEX; Python 3 with
`pip install z80 pillow` for the emulator in `tools/emu`):

```
cd example/ROCKS
node ../../tools/e3models.js models.js --png models.png
node ../../tools/build.js .  [path to NTC's src folder, or set NTC_SRC]
python3 test/run.py 3000
```

`test/run.py` runs `build/ROCKS.NEX` in `tools/emu` (NTC3D's own copy: nothing outside this folder
is needed) holding keys in turns. Its log is `example/ROCKS/test/run_log.txt`, its screenshots
`test/shots/`. A 3000 frame run (one minute) scored 745 with all the movers seen, at 3.24
frames a picture (a full clear and 32 stars every picture).

Any game's test does the same:

```python
import sys; sys.path.insert(0, 'tools/emu')
from emu import NX
z = NX('build/GAME.NEX', 'build/GAME.sym')
z.run_frames(100); z.held = {56}; z.run_frames(10)        # Space held for 10 frames
print(z.var('var_score')); z.shot('shot.png')             # a BASIC variable; a screenshot
```

Keys are half row x 8 + bit (Space 56, Enter 48, Q 16, A 8, O 41, P 40, M 58); `z.var('var_x')`,
`z.arr('arr_x', i)`, `z.setvar` read and set the program's variables by the build's `.sym` file.

## DIREMOON STRIKE on the framework

- **Its waves.**
  - Wave 1's fighters are MV_HOLD (the Brute MV_HOLDONLY) with OF_WRAP and guns.
  - The surface and trench Wasps are MV_CHARGE then MV_PASS.
  - Ground things are MV_STILL with OF_BEHIND; rocks are MV_STILL with OF_WRAP.
- **Shooting and hits.**
  - Your lasers are `Obj3D.Pick`.
  - Enemy bolts are `FireAt`.
  - Explosions are `Burst` and `Boom`.
  - What hits you comes in as `EV_HIT` with eb = 255.
- **What stays in the game.** The trench and the moon's surface are drawn by the game itself with
  E3's flat faces (DrawTrench, Ground2, DrawPlates): they're scenery, not objects.

## Ground games (IRON DUST)

IRON DUST drives a hover tank over a plain; everything it needed that another game could use went
into the framework:
- `Fly3D.Drive`: tank steering, the camera kept level. The horizon is always row 96, so the sky
  and the ground are one `E3.Begin2` (the DMA fills both: no ground polygon at all).
- `E3.Skyline`: mountains and a volcano on the skyline, on fixed bearings, from a table.
- `Obj3D`'s ground feature: MV_CIRCLE (scouts strafing round you), MV_HUNT (tanks that come at
  you, stand off, creep round and fall back behind cover), MV_HOME (missiles you can shoot down),
  OF_LAND / EV_LAND (mortar shells landing, debris lying on the ground), OF_GUNANY (guns that fire
  from behind you too).
- Compound models (`M.Compound`): tanks with a hull, track skirts, a turret, barrels and missile
  pods; a gunship with a rotor; two painter's orders, ahead and behind, picked as they're drawn.
- `Obj3D.pky`: a gun with elevation (Pick along the raised line).
- `E3.Texts`, `uca`: text pages from the data bank; HUD text on a dark paper backing.
- Cover that stops shots is just a mask: enemy shots carry `M_SCENERY`, so they hit the rocks and
  the game takes them out; your shot is `Pick` with the scenery's class in the mask, so the
  nearest thing in the way takes it.

## Not done

- A compound model's parts don't turn on their own: a tank's turret turns with its hull (the whole
  tank faces where it aims).
- No object to object collision between two moving fast things that pass through each other in
  one step (only the camera's test is a crossing test).
- Movers can't be added from BASIC: a new behaviour means Z80 in Obj3D's Lib (its table `os_tab`).
- No Option Page banking of the classes: they all live in main memory (Option Page on the Next
  pages into #4000-#7FFF, where the program is).
- The engine's per object cost (40 - 100 thousand T-states a model drawn, a few thousand for
  ViewAll) is what limits a busy scene: a ground game with 20 things about runs at 3 to 4 frames a
  picture.
