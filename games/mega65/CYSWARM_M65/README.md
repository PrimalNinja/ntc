# CYBORG SWARM - MEGA65

(c) 2026 Cyborg Unicorn Pty Ltd

A swarm shooter in the Galaga mould, written in NTC BASIC for NTC's `m65` (45GS02) platform, with
the per-frame flying in 45GS02 `#asm` keywords. It's the same game as the Mega Drive version, moved
across. The program is `build/CYSWARM.PRG` (40K): put it on the SD card or a D81 and
`RUN "CYSWARM.PRG"` (or `DLOAD` and `RUN`), or drop it on Xemu.

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

## Controls

- **Joystick in port 2:** left / right move, fire fires (two missiles at a time; four with two
  fighters)
- **Fire or RETURN** - start
- **RETURN** - pause

## Screen

320 x 200, 50 frames a second (PAL). The playfield is the left 256 pixels; the panel on the right
(high score, score, stage, the stage flags, the reserve fighters) is drawn only when it changes.
The MEGA65 has only 8 hardware sprites, so everything that moves is drawn by the CPU: NTC's `Vic`
class puts the screen in full-colour character mode (every pixel its own byte, 256 colours),
keeps two buffers in the RAM at $40000 and $50000, clears the playfield with the DMA chip each
frame, draws the stars, the sprites (up to 80) and the text into the buffer not on show, and swaps
them at the next frame. Sound is the SIDs (`Sid` class: three tone channels and a noise).

## How it's built

| File | What |
|---|---|
| `Main.bas` | the game: the title, the stage flow, the entries, the formation, the fighter, missiles, enemy shots, collisions, dives, the tractor beam, capture and rescue, scoring, the panel, sound, tunes |
| `Swarm.cls` | the 44 enemies' arrays (state, kind, position, angle, speed, path ...) and two 45GS02 keywords: `Swarm.Step` (every enemy a frame on - following its path, flying home to its slot, holding its place in the formation, beside its Queen, exploding - and its entry in the sprite table, turned to its direction) and `Swarm.Hit` (the enemy at a point) |
| `Gfx.cls` | the 65 images and the 4 palettes (made by `tools/cyswarm_gfx.py`) |
| `Paths.cls` | the flight paths, the sine and arctangent tables, the formation's slots (made by `tools/cyswarm_data.py`) |
| `tools/cyswarm_gfx.py` | draws every sprite as text and turns the enemies and the fighter to 5 directions (the game flips them for the other 11) |
| `tools/cyswarm_data.py` | the paths: segments of (frames, turn a frame, speed), aiming at the fighter, and what happens at the end |
| `tools/font8x8.txt` | the 8x8 font of the logo's letters (font8x8_basic, public domain) |
| `test/bot.py` | a player for testing: it reads the game's RAM by the vasm listing's labels, dodges, shoots, can walk into the beam and rescue; it reports the stages, deaths, captures, and any frame the game didn't finish in time |
| `test/run.py` | runs the PRG on Xemu through NTC's `test/m65run.py` (screenshots, joystick, keys, the screen's text) |
| `game.json` | the name, the platform (`m65`) and the source files |
| `build.js` | builds the lot (below) |
| `CYSWARM.json` | the project for NTC's IDE (`ntc.html`, Open...) |
| `assets/` | what the graphics and the paths look like |
| `screenshots/` | the title, a stage, the bonus stage, the beam, a capture, the rescue, two fighters, game over, the results |
| `build/` | `CYSWARM.PRG` (the program), `CYSWARM.s` (the assembly) |

The game logic is BASIC: the decisions (what enters when, who dives, the beam, scoring) happen a
few times a frame. The work done for every enemy every frame - 44 of them moving along curves with
sine tables, steering home with an arctangent, choosing one of 16 directions and the flips - is
`Swarm.Step`, one keyword, and the drawing is `Vic.Update`. At 40MHz it holds 50 frames a second
with all 44 enemies on screen: the bot played six games of 10 to 11 stages each (two of them with a
capture, a rescue and two fighters) without the game missing a frame.

## Building

Needs NTC BASIC (its `src` folder), node, and vasm (6502 oldstyle syntax: vasm 2.0f built with
`make CPU=6502 SYNTAX=oldstyle`, giving `vasm6502_oldstyle`; the `-mega65` option gives it the
45GS02's instructions).

```
node build.js /path/to/ntc/src --vasm=/path/to/vasm6502_oldstyle
```

That writes `CYSWARM.json`, `build/CYSWARM.s`, `build/CYSWARM.lst` and `build/CYSWARM.PRG`. NTC is
found from the argument, else `NTC_SRC`, else `../ntc/src` (or `../..` in NTC's own
`bas/cyswarm_m65`); vasm from `--vasm=`, else `NTC_VASM65`, else the PATH. `--gfx` runs the two
Python tools first (only needed after changing the art or the paths), `--log` makes a test build
that keeps the screen's text in RAM.

To test (needs Xemu's xmega65 built with NTC's test driver as NTC's `docs/m65.md` says, in
`NTC_XEMU`):

```
python3 test/run.py --frames=600 --joy=200:F,204:- --shot=shot.png
python3 test/bot.py build/CYSWARM.PRG build/CYSWARM.lst 20000 --capture
python3 test/bot.py build/CYSWARM.PRG build/CYSWARM.lst 5000 --idle
```

## Not checked

It has run on Xemu only, not on a real MEGA65, and the sound has never been listened to (the test
runs have no audio). Xemu's 45GS02 timing is close to the real machine's, not exact.
