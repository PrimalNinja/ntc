# CHAOTIC

(c) 2026 Cyborg Unicorn Pty Ltd - MIT License

An abstract shooter for the **ZX Spectrum Next**, written in **NTC BASIC**: a web of lanes seen down
its length, things climbing out of the middle at you, and the screen filling with bullets and
light. DEFENDER HELLGATE's pickups and power-ups, and a bullet hell that comes from the centre.

## How it plays

- **You're the claw on the rim.** Slide round the rim from lane to lane and shoot down the lanes.
  Shots fly down the lane you're on (and the ones either side, powered up).
- **Things climb out of the middle**, small and far away, bigger as they come, firing as they
  climb. If one reaches the rim it comes along the rim for you.
- **16 webs:** circle, square, cross, flat, star, vee, triangle, bow tie, U, heart, steps,
  hexagon, wave, peanut, double vee, diamond. Some close round (you can go all the way round),
  some are open (they have ends). After 16 they come round again, faster.
- **A level** is a set number of things (16 on level 1, two more each level, up to 60). Clear
  them all and you dive down the web into the next one (SUPERZAP: 1,000 x the level).

## The things

| Thing | From level | What it does |
|---|---|---|
| Snapper | 1 | Climbs, firing aimed shots. On the rim it flips along towards you. |
| Pod | 2 | Slow. Shot (or on the rim) it splits into two snappers. |
| Spinner | 3 | Fires three-armed spirals and slips from lane to lane. On the rim it's a snapper. |
| Seeder | 5 | Stops part way up and sprays rings of bullets until it's killed. |
| Pulsar | 7 | Stops two thirds of the way up and pulses: its lane is live (flashing red and white) and kills you if you're in it. Fires a ring as each pulse starts. |
| Fuse | 9 | Fast, hops lanes, hunts you along the rim. |

**The CORE**: every fourth level (4, 8, 12 ...), when the level's things are gone, the core sits
in the middle of the web: twin spirals, then rings as it's hurt, then aimed fans as well, and
snappers. One lane is its gap (it glows): only shots down that lane hurt it, and the gap moves on
every three seconds. Worth 5,000 x (level / 4), and a shower of big Ps and gems.

## From DEFENDER HELLGATE

- **Pickups:** what you shoot drops them. They float up their lane to the rim, then slide along
  the rim towards you. Touch one to take it. They go after about five seconds on the rim.
  - **P:** ten P is a power level (100 points each).
  - **Big P:** a whole power level.
  - **Gem:** 500, plus 50 for each link of your HIT chain.
  - **G:** another guard. **N:** another nova.
- **Power levels 1-5:** 1 one shot at a time; 2 faster; 3 the lanes either side as well, every
  other shot; 4 faster again, and the shots fly faster; 5 three lanes every shot, double damage.
  Past 5 a power level is worth 2,000. Losing a claw costs a power level.
- **GUARD (M):** a ring round the claw for two seconds. It eats every bullet on the screen (10
  points each, every four a gem), and anything on the rim that touches it burns. Every 25 P is
  another guard. You start with three.
- **NOVA (N):** the smart bomb. Every thing on the web gone, every bullet gone, a fifth off the
  core. You start with two.
- **HIT chain:** kills close together build it (HIT n, and its gauge). Each kill is worth 10 more
  per link.
- **Claws:** four to start, another every 40,000 (up to six).

## Keys

| | |
|---|---|
| O P (or the joystick) | slide round the rim. Left is left on the screen wherever you are; on a side that goes up and down, Q A (up, down) |
| Space (fire 1) | fire (hold it) |
| M (fire 2) | GUARD |
| N | NOVA |

## How it works

- **The web is drawn once a level** on Layer 2 (one screen, bank 16), by a line routine in Z80
  (`Web.Line`). Every line has a palette colour of its own: the 17 spokes, the 16 rim-and-inner
  edges, the three rings. Lighting up your lane, flashing a pulsar's lane, making a ring of light
  run out along the web - all of it is changing a few palette entries, never drawing.
- **The particles** (`Web.Step`, Z80): up to 160 blocks of 2 x 2 pixels flying over the web. Each
  one keeps the four pixels it covers, so it can put them back: every frame they all come off
  (last first), move, and go back on. That's done straight after the frame starts, in the top
  border, so Layer 2 is never seen half done. Each has a colour ramp (8 palette entries, fading).
- **The copper** (`Cop.cls`) sets two NextRegs on every other line of the picture: the fallback
  colour (#4A: the background, wherever no layer is drawn - a band of colours rolling down) and
  Layer 2's sideways scroll (#16: the web wobbles when you die, nova or kill the core).
- **Depth:** a thing's depth is 0 (the middle) to 4096 (the rim). `tools/shapes.py` makes the
  webs and a perspective curve (65 steps); at the start of a level the middle of every lane at
  every step is worked out once (`lx()`, `ly()`: 1,040 points), so placing anything is a table
  look-up.
- **Three sizes:** far down the web a thing is a small pattern, nearer a full 16 x 16, near the
  rim the same doubled by the sprite hardware.
- **The bullets** (`Bul.cls`, from IDOL WINGS): 64 sprites moved and checked against you in Z80
  each frame, aimed or fired in rings and spirals at any of 256 angles.
- **The panel** is the tilemap, in the top border.

## Building

```
python3 tools/shapes.py        # the 16 webs and the depth curve -> Shapes.cls
python3 tools/art_chaotic.py   # the sprites and the panel's tiles -> gfx/
node build.js path/to/ntc/src  # gfx -> GfxData.cls, the compiler, sjasmplus -> build/CHAOTIC.NEX
```

`test/chbot.py` plays it in the emulator: it slides to the lane of whatever is nearest the rim,
fires all the time, uses the guard when bullets are close, and takes screenshots
(`python3 test/chbot.py FRAMES [seed] [tag] [level]`; level jumps ahead to try the later things).

It fits any Next; the program uses 29K of NTC BASIC's 48K program area.
