# hwlib - NTC BASIC game library: the hardware tests

Part of NTC (`src/hwlib`), and optional: the compiler never adds these classes by itself. A
program adds the chip classes it wants to its own project. A project class replaces a platform
class of the same name, so hwlib's `V9990.cls` (or a `StdIO_<chip>.cls` added as `StdIO.cls`)
takes over from the platform's own on the platforms that have one (msx, msx9990, the CPC ones).

Two sets of small test programs, one of each for every machine and video chip, each built for
its hardware rather than scaled from another:

- **Balls** (tests/<target>): picks a screen mode, clears the screen, prints some text, then
  bounces balls that spin (4 animation frames) using that chip's own sprites.
- **Cube** (tests/cube_<target>): a solid cube turning, lit, the faces turned away dropped,
  drawn the best way each machine can (see below).

## The libraries (lib/)

Each library is named after its chip. Where there's no chip to name it after, it's named after
the machine.

| Library | Hardware | Sprites |
|---|---|---|
| Zxn.cls | ZX Spectrum Next | 128 hardware sprites, 16x16, 8 bit colour |
| Cpc.cls | Amstrad CPC (no sprite hardware) | software sprites, mode 0: masked, what's under them put back, double buffered (#C000 / #4000) |
| Asic.cls | CPC Plus / GX4000 | 16 hardware sprites, 16x16, 15 colours of their own |
| Tms9918.cls | MSX1, SC-3000 / SG-1000 | 32 sprites, 16x16, 1 colour each, 4 on a line |
| V9938.cls | MSX2 (and MSX2+) | 32 sprites, 16x16, a colour on each line, 8 on a line |
| V9990.cls | MSX GFX9000, CPC V9990 boards | 125 sprites, 16x16, 16 colours, 16 on a line |

Every library has the same core calls:

    Init  Pattern n, addr  Put n, x, y, pattern  Hide n  Anim n, first, count, delay
    Move n, dx, dy  Bounds x0, y0, x1, y1  Frame  X(n)  Y(n)

`Frame` waits for the frame, then puts every sprite on the screen, moves each one (bouncing
off the Bounds) and steps its animation. A game's loop is `Do : <chip>.Frame : Loop` plus its
own logic.

Each chip also has calls of its own:

- Tms9918: `Colour`
- V9938: `Colour`, `Lines` (a colour for each of the sprite's 16 lines), `Palette`
- V9990: `Palette`, `Shades`
- Cpc: `Inks`
- Asic: `Palette`

### Text and screen modes

The Next, CPC and CPC Plus keep NTC's own console.

The TMS9918, V9938 and V9990 have no firmware to print with, so each one has a `StdIO_<chip>.cls`
that the build copies in as the project's `StdIO.cls`. That makes `Print`, `Cls`, `Locate`
and `Mode` work on them. The modes:

| Chip | Mode 0 | Mode 1 | Mode 2 |
|---|---|---|---|
| Tms9918 | 40x24 text | 32x24 text + sprites | - |
| V9938 | 40x24 text | 32x24 text + sprites | 80x24 text (checked in openMSX) |
| V9990 | P1 32x26 + sprites | same | B1 bitmap, 256x212, 64 colours, 2 screens (P2, 64 columns, not done yet) |

The bitmap modes for vectors: Tms9918 Mode 2 (Graphic 2), V9938 Mode 3 (Graphic 4, 256x212,
16 colours, 2 pages), V9990 Mode 2 (B1), Zxn Mode 2 (Layer 2, 256x192, 256 colours, 2 screens;
with StdIO_Zxn.cls the text is drawn on Layer 2). The CPC and CPC Plus use mode 0 and NTC's
Graphics double buffering.

### Several machines in one build

To support several machines in one build, include several libraries and let the user choose
at the start. Nothing is detected automatically.

## The targets (tests/<target>/Main.bas)

| Target | NTC platform | File | Tested |
|---|---|---|---|
| next | zxn | NEXT.NEX | ZEsarUX (Next) - working |
| cpc | cpc | CPC.BIN (AMSDOS header) | ZEsarUX (CPC 6128) - working |
| cpcplus | cpc | CPCPLUS.BIN | 1984 (6128 Plus) - working: 12 balls, moving and spinning (2026-10-28; the ASIC's unlock had been sending 0s - a 17 value Choose, past NTC's 8 - so the ASIC stayed locked and the program crashed) |
| cpc_v9990 | cpc | CPCV9990.BIN | **build only**. The port address in V9990.cls (`VPort`, &HFF60 with `--const=CPC`) is a placeholder: set it to your board's real address |
| msx1 | baremetal, org #C000 | MSX1.ROM (16K cartridge) | openMSX (C-BIOS MSX1) - working |
| msx2 | baremetal, org #C000 | MSX2.ROM | openMSX (C-BIOS MSX2) - working |
| msx_v9990 | baremetal, org #C000 | MSXV9990.ROM | openMSX (C-BIOS MSX2 + GFX9000) - working |
| sc3000 | baremetal, org #8000 | SC3000.SC (8K cartridge) | MAME sc3000 - working |

build/shots/all.png (balls) and build/shots/cubes.png (cubes) have screenshots of each one,
taken a moment apart so you can see them move.

## The cube set (tests/cube_<target>/Main.bas)

lib/Vec.cls does the 3D the same way on every machine, in asm:

- turns the cube with one matrix from a sine table
- puts it in perspective
- drops the faces turned away
- lights the rest, from up, left and in front, with some light everywhere so no face goes black
- turns each face's outline into a left and a right x for each line

Each chip's class then fills those lines its own way. Each machine also draws on the screen it
isn't showing and swaps screens at the frame, so nothing flickers or tears. The CPU-drawn
machines and the V9938 / V9990 do it like this:

    <chip>.Begin                                  ' the old picture's box cleared
    Vec.Turn 2, 3, 1 : Vec.Project
    <chip>.Keep Vec.Bx0, Vec.By0, Vec.Bx1, Vec.By1
    For f = 0 To 5
      b = Vec.Face(f)                             ' 0: turned away; 17-65: how lit
      If b Then <chip>.Spans Vec.Y0, Vec.Y1, <colour for b>, Vec.L(), Vec.R()
    Next
    <chip>.Show

| Target | How it's drawn | Speed (emulator) |
|---|---|---|
| cube_next | Layer 2, 256x192. 32 shades set in the palette from 512 colours. Fills done by the Z80N at 28MHz with an unrolled loop. Two screens (16K banks 12 and 15). | 49 a second (ZEsarUX). The frame rate is 50. |
| cube_cpc | Mode 0. The cube is drawn half as wide, because mode 0 pixels are twice as wide as high. Whole bytes are filled with an unrolled loop, and the end pixels are masked. 6 shades. Screens at #C000 / #4000. | 9.5 a second (ZEsarUX) |
| cube_cpcplus | The same as cube_cpc, plus the ASIC's palette for 14 shades from 4096 colours. | Runs in 1984 (6128 Plus), not timed. It can't run on a plain CPC, where writing to the ASIC's port turns the lower ROM on over the program. |
| cube_msx1, cube_sc3000 | Graphic 2. The cube is drawn in RAM as 1 bit, shaded with 8 ordered-dither patterns (2 colours in each 8 pixels, so no colour clash this way), then copied to the character set that isn't shown, and the name table swapped. The picture is 120x128. | MSX1: 7.5 a second (openMSX). The SC-3000 works in MAME but wasn't timed (same chip, about the same clock). |
| cube_msx2 | Graphic 4, 256x212, 12 shades. Each line of each face is filled by the V9938's own command (LMMV). The old box is cleared by HMMV while the CPU works out the next cube. Two pages. | 9 a second (openMSX) |
| cube_msx_v9990 | B1, 256x212, a byte a pixel, 32 shades. Fills done by the V9990's command (LMMV), with the old box cleared the same way as on the V9938. Two screens in its RAM. | 10.5 a second (openMSX + GFX9000) |
| cube_cpc_v9990 | The same as the MSX V9990 cube. | **Build only.** Set `VPort` for your board. |

The speed is the number of pictures drawn a second. tools/run/fps.py measures it by reading
the cube's turn angle twice, 2 seconds apart.

**What limits the speed on the 3.5-4MHz machines:**

- The work done for each line: setting up a VDP command, or the masks and the pointers.
- The 3D maths, even in asm.

On the V9990, making the fills 1 pixel wide didn't change the speed, so its fill speed isn't
what holds it back.

**Faster ways to go:**

- turns worked out in advance
- a sorted span list
- unrolled code made for each width

Those are bigger jobs than a test program.

On the Next screenshots a black line sometimes runs across the picture. That's ZEsarUX saving
the screen part way through a frame; it isn't on the screen itself.

## Building and running

    python3 tools/art.py            # the art: tests/<target>/Art.cls (the ball, font, palettes)
    node tools/build.js [target]    # needs sjasmplus; NTC is the src/ this is in (or NTC_SRC=...)
    python3 tools/run/shot_next.py [next|cube_next]     # ZEsarUX (ZESARUX=path)
    python3 tools/run/shot_cpc.py [cpc|cube_cpc]
    python3 tools/run/shot_msx.py [target ...]          # openMSX (xvfb-run) and MAME; SHOT_LATER=2 for later shots
    python3 tools/run/check_cpcplus.py
    python3 tools/run/fps.py [cube_target ...]          # pictures a second

## Things to know

- **Built on baremetal.** The MSX and SC-3000 tests use NTC's baremetal platform with Option Org,
  the chip classes driving the hardware. NTC also has msx / sc3000 platforms (cartridge ROMs that
  run from ROM, the variables in RAM); the tests haven't been moved onto them.
- **Cartridges run from RAM** (on baremetal). Baremetal keeps the variables beside the code, so
  a program built for it can't run from ROM. build.js puts a short stub in front that copies the
  program into RAM and jumps to it:
  - **MSX:** to #C000.
  - **SC-3000:** to #8000, so it needs a cartridge with 32K of RAM there, like BASIC Level
    III's. It won't run on a plain SG-1000 game cartridge, which has only 2K of RAM.
- **MSX stack at #FFF0.** No BIOS is used, so all the RAM up to there is the program's. The
  stack can't start right at the top, though, because writing to #FFFF switches the MSX2's
  sub-slots (`Option Stack &HFFF0`).
- **Strings of up to 255 characters.** PutStr takes `String Max 255`. A plain String is cut to
  40 characters, which loses the end of an 80-column line.
- **The 40- and 80-column modes clip the font** (TMS9918 / V9938 Text 1 and Text 2). These modes
  show 6 pixels of each character, and the stand-in font (font8x8_basic, public domain) uses 7,
  so M and W lose a column. A font drawn 6 pixels wide fixes this. The 32-column modes are fine.
- **Starting the CPC builds.** The CPC builds carry an AMSDOS header, as NTC writes them
  (`RUN"CPC`). The test script starts them a different way: it loads the program at #40 and
  runs it with both ROMs off. RUN" works for the Plus ones (RUN"CPCPLUS, RUN"CUBECPCP from an M4
  in 1984's 6128 Plus).
- **CPC Plus speed.** On a plain CPC, a ball meant to move 1 pixel a frame moved 14 pixels in
  half a second, so 12 sprites run at about half the frame rate. This was measured only on a
  plain CPC. The CPC software sprites haven't been timed.
- **CPC software sprites look the right shape.** Mode 0 pixels are twice as wide as they are
  high, so the CPC ball is 8 pixels wide and 16 high, which looks round. Each frame is stored
  twice, once shifted half a byte, so balls move one pixel at a time.
