# CYBORG SWARM - Sega Mega Drive / Genesis

(c) 2026 Cyborg Unicorn Pty Ltd, MIT License

A swarm shooter in the Galaga mould, written in NTC BASIC for NTC's `md` (68000) platform, with
the per-frame flying in 68000 `#asm` keywords. The ROM is `build/CYSWARM.md` (45K): a flash cart
or any Mega Drive emulator.

## The game

The swarm flies in - Drones, Hornets and Queens, five waves of eight on curving paths - and takes
its places in the formation, which sways while they arrive and breathes once it's full. Then they
peel off and dive: Drones loop over and swing down at you, Hornets dash and weave, Queens dive with
up to two Hornets beside them. Diving enemies shoot.

- **Queens** take two hits (green, then purple).
- **The tractor beam:** a Queen can come down, stop, and beam your fighter up. It turns red and sits
  behind her. Shoot that Queen **while she dives** and your fighter is freed: it spins down and
  docks beside yours - two fighters, twice the fire (and twice the target: a hit loses one, not a
  life). Shoot her while she's in the formation and the captured fighter turns on you and leaves.
  Shooting the captured fighter itself loses it.
- **Every fourth stage** (3, 7, 11 ...) is a bonus stage: 40 enemies fly through in formation
  shows and leave, nobody shoots. 100 a hit, 10,000 for all 40.
- Extra fighters at 20,000 and 70,000, then every 70,000.
- At the end: shots fired, hits, the hit-miss ratio.

| Enemy | In the formation | Diving |
|---|---|---|
| Drone | 50 | 100 |
| Hornet | 80 | 160 |
| Queen | 150 | 400 alone, 800 with one escort shot first, 1600 with both |
| Captured fighter | 500 | 1000 |

## Pad

- **Left / Right** - move
- **A, B or C** - fire (two missiles at a time; four with two fighters)
- **Start** - start, pause

## Screen

H40, 320 x 224. The playfield is the left 256 pixels; the panel on the right (high score, score,
stage, the stage flags, the reserve fighters) is opaque, so the swarm flies behind it. The stars
are plane B, scrolled down and twinkling (colour cycling). Text and the panel are plane A. Every
enemy, the fighters, the shots, the beam and the explosions are hardware sprites (up to 66 of the
80).

## How it's built

| File | What |
|---|---|
| `Main.bas` | the game: the title, the stage flow, the entries, the formation, the fighter, missiles, enemy shots, collisions, dives, the tractor beam, capture and rescue, scoring, the panel, sound, tunes |
| `Swarm.cls` | the 44 enemies' arrays (state, kind, position, angle, speed, path ...) and two 68000 keywords: `Swarm.Step` (every enemy a frame on - following its path, flying home to its slot, holding its place in the formation, beside its Queen, exploding - and its sprite, turned to its direction) and `Swarm.Hit` (the enemy at a point) |
| `Gfx.cls` | the tiles and the 4 palettes (made by `tools/cyswarm_gfx.py`) |
| `Paths.cls` | the flight paths, the sine and arctangent tables, the formation's slots (made by `tools/cyswarm_data.py`) |
| `tools/cyswarm_gfx.py` | draws every sprite as text and turns the enemies and the fighter to 5 directions (the game flips them for the other 11) |
| `tools/cyswarm_data.py` | the paths: segments of (frames, turn a frame, speed), aiming at the fighter, and what happens at the end |
| `tools/font8x8.txt` | the 8x8 font for the panel and the text (font8x8_basic, public domain) |
| `test/bot.py` | a player for testing: it reads the game's RAM by the vasm listing's labels, dodges, shoots, can walk into the beam and rescue; it reports the stages, deaths, captures, and any frame the game didn't finish in time |
| `test/run.py` | runs the ROM on the emulator core through NTC's `test/mdrun.py` (screenshots, pad presses, the screen's text) |
| `game.json` | the name, the platform (`md`) and the source files |
| `build.js` | builds the lot (below) |
| `CYSWARM.json` | the project for NTC's IDE (`ntc.html`, Open...) |
| `assets/` | what the graphics and the paths look like |
| `screenshots/` | the title, a stage, the bonus stage, the beam, a capture, the rescue, two fighters, game over, the results |
| `build/` | `CYSWARM.md` (the ROM), `CYSWARM.s` (the assembly) |

The game logic is BASIC: the decisions (what enters when, who dives, the beam, scoring) happen a
few times a frame. The work done for every enemy every frame - 44 of them moving along curves with
sine tables, steering home with an arctangent, choosing one of 16 directions and the flips, writing
the sprite table - is `Swarm.Step`, one keyword. It holds 60 frames a second: the bot played 26
stages with two fighters without the game missing a frame.

## Building

Needs NTC BASIC (its `src` folder), node, and vasm (Motorola syntax: vasm 2.0f built with
`make CPU=m68k SYNTAX=mot`, giving `vasmm68k_mot`).

```
node build.js /path/to/ntc/src --vasm=/path/to/vasmm68k_mot
```

That writes `CYSWARM.json`, `build/CYSWARM.s` and `build/CYSWARM.md` (with the cartridge header's
name, size and checksum filled in). NTC is found from the argument, else `NTC_SRC`, else
`../ntc/src`; vasm from `--vasm=`, else `NTC_VASM`, else the PATH. `--gfx` runs the two Python
tools first (only needed after changing the art or the paths), `--log` makes a test build that keeps
the screen's text in RAM.

To test (needs the Genesis Plus GX libretro core built as NTC's `docs/md.md` says, in
`NTC_MDCORE`):

```
python3 test/run.py --frames=1200 --pad=100:S,104:- --shots=600,1200:shot
vasmm68k_mot -quiet -spaces -Fbin -coalesced -L build/CYSWARM.lst -o /dev/null build/CYSWARM.s
python3 test/bot.py build/CYSWARM.md build/CYSWARM.lst 20000 --capture
```

## Not checked

It has run on the Genesis Plus GX emulator core only, not on a real Mega Drive. The start code
does what a real machine needs (TMSS, the Z80 held, the VDP set up from scratch, the pads read
once a frame for 6 button pads), and the VDP is never touched from the interrupt.
