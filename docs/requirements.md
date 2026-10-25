# NTC - requirements and targets

What you need to use NTC, to rebuild its generated files, and to run its tests, and the
machines it builds programs for.

## 1. Using NTC (compile a program)

| Need | What for | Notes |
|---|---|---|
| A web browser | `src/ntc.html` - the editor and compiler | Nothing to install. The compiler is ES5 JavaScript; jQuery and Bootstrap are in `src/3p/`, so it works offline |
| sjasmplus | assembles the compiler's `.asm` output | Tested with v1.24.0. On the PATH, in `src/build/`, or its path given to `build.bat`. sjasmplus writes the CPC `.BIN` (AMSDOS header) itself (`DEVICE AMSTRADCPC6128` + `SAVEAMSDOS`) |
| Windows / MS-DOS | `src/build/build.bat` (assembles every test build) | Optional: any system that runs sjasmplus can assemble the `.ASM` files by hand |
| A CPC or CP/M machine, or an emulator | running the programs | WinAPE has been used for the CPC builds. `src/build/dsk/` has ready made disc images |
| An MSX or SC-3000 (a cartridge flash board), or an emulator | the cartridge ROMs | openMSX 19 (C-BIOS machines, the `gfx9000` and `Sharp_HB-4000` extensions) and MAME 0.264 (`mame sc3000 -cart NAME.SC`) have been used |

## 2. Rebuilding the generated files

After changing anything in `src/asm/`, `src/lib/` or `src/bas/`, these files must be made
again - the compiler and the GUI only read them, not the sources:

| Generated file | Made from | Made by |
|---|---|---|
| `src/js/ntc_lib.js` | `asm/ntc_lib.asm`, `asm/ntc_plat_*.asm`, `lib/<platform>/*.cls` | `src/test/gen.js` |
| `src/js/ntc_examples.js` | the examples in `bas/` | `src/test/gen.js` |
| `src/build/<platform>/*.ASM` | every program in `bas/`, for every platform | `src/test/genbuild.js` |
| `src/build/dsk/*.dsk` | the build files, assembled | `src/test/gendsk.sh` |

| Need | Version used | Notes |
|---|---|---|
| Node.js | v22 | for `gen.js` and `genbuild.js` (and `cli.js`). There is no Node-free way to remake `ntc_lib.js` yet - see the todo |
| bash, sjasmplus, cpmtools, libdsk | cpmtools with libdsk 1.5.9 | only for `gendsk.sh` (the disc images, CPC data format `cpcdata`) |

## 3. Test tools (`src/test/`)

Scratch tools for testing the compiler - not part of NTC itself. Details in `NTC.md`
section 6.

| Need | Version used | What for |
|---|---|---|
| Node.js + `npm install` in `src/test/` | v22, acorn 8 | `cli.js` (compile from the command line), the ES5 check in `regress.sh` |
| Python 3 with the `z80` module (`pip install z80`) | 3.13, z80 1.2.0 | `cpcrun.py` / `ntcrun.py`: the emulated CPC (RAM from 64K to 4MB, `--ram=`), CP/M and test hosts |
| sjasmplus | v1.24.0 | assembling inside the test runs (or set `SJASMPLUS` to its path) |
| bash | | `regress.sh`, `gendsk.sh` (on Windows: Git Bash or WSL) |
| cpmtools + libdsk | libdsk 1.5.9 | the `build/dsk` check in `regress.sh` (skipped when not installed) |
| Playwright + Chromium (`pip install playwright`, `playwright install chromium`) | | the GUI tests `guitest*.py` only |
| vasm (Motorola syntax: `make CPU=m68k SYNTAX=mot`), the Genesis Plus GX libretro core | vasm 2.0f | `mdbuild.py` / `mdrun.py` / `mdregress.sh`: the Mega Drive (`NTC_VASM`, `NTC_MDCORE`; `docs/md.md`) |
| vasm (6502 oldstyle syntax: `make CPU=6502 SYNTAX=oldstyle`), Xemu's xmega65 with `test/xemu/`'s patch | vasm 2.0f, Xemu 40dfef0 | `m65build.py` / `m65run.py` / `m65regress.sh`: the MEGA65 (`NTC_VASM65`, `NTC_XEMU`; `docs/m65.md`) |

## 4. Targets

One BASIC source builds for every target; what changes is the start-up, the console, and
what the platform classes (`StdIO`, `System`, `FileSystem`, `Memory`) can do.

| Target | Name | Output | Runs on | Needs |
|---|---|---|---|---|
| Amstrad CPC, no firmware | `cpc` | `NAME.BIN` (AMSDOS header) at `#0040`, `RUN"NAME` | CPC 464 / 664 / 6128 | nothing: ROMs off, own screen, keys and interrupt handler; all RAM from `#0040` to the stack. No files |
| Amstrad CPC, minimal firmware | `cpcmin` | `NAME.BIN` at `#0040` | CPC 464 / 664 / 6128 | the firmware's RAM (`#A700-#BFFF`) left alone, handed back for discs, tape and ROM commands. Files: AMSDOS (`Option RomEnable 7` after `RUN"`); the program must end below `#A600` |
| Amstrad CPC, full firmware | `cpcfw` | `NAME.BIN` at `#0040` | CPC 464 / 664 / 6128 | the firmware for text, keys and files (AMSDOS, other ROMs' commands); program below `#A600` when it uses files |
| CP/M 2.2 / 3 | `cpm` | `NAME.COM` at `#0100`, ends with a warm boot | any Z80 CP/M machine | BDOS only. Console: a stream, or 80 x 24 with `Option Terminal VT52 / ANSI` |
| Test harness | `test` | raw `NAME.BIN` at `#4000` | `src/test/ntcrun.py` only | - |
| MSX | `msx` | `NAME.ROM`: a cartridge, 16K / 32K at `#4000` | MSX1, MSX2, MSX2+, turbo R with 16K RAM or more | the BIOS (its keyboard buffer and interrupt); the MSX's own video chip (80 columns from the MSX2); `End` returns to the BIOS. No files |
| MSX + V9938 card | `msxcard` | `NAME.ROM` | any MSX with a V9938 card at `#88` (HB-4000, CT-80E, MA-20V) | as `msx`, the console on the card (80 columns) |
| MSX + V9990 | `msx9990` | `NAME.ROM` | any MSX with a V9990 at `#60` (GFX9000, Video9000, Powergraph) | as `msx`, the console on the V9990's own monitor |
| Sega SC-3000 | `sc3000` | `NAME.SC`: a cartridge, 16K / 32K / 48K at `#0000` | SC-3000 (and an SG-1000 with the SK-1100 keyboard) | nothing: own console (TMS9918), keys and interrupt handler; 2K of RAM for the variables, arrays and stack. No files. `End` stops (RESET starts again) |
| Amstrad CPC + MSX V9938 card | `cpccard` | `NAME.BIN` at `#0040` | CPC with the AMSDAP adapter and an MSX V9938 card (`&FF88`) | as `cpc`, the console on the card's monitor |
| Amstrad CPC + V9990 | `cpc9990` | `NAME.BIN` at `#0040` | CPC with a V9990 at `&FF60`: AMSDAP and an MSX V9990 cartridge, or the CPC Powergraph | as `cpc`, the console on the V9990's monitor |
| ZX Spectrum Next, no ROM | `zxn` | `NAME.NEX` (banks 8-10: the program at `#0040`; bank 5: a start stub), run from NextZXOS's browser | ZX Spectrum Next (a core with the tilemap's text mode and the line interrupt; so far run only in `src/test/zxnrun.py`) | nothing: the stub turns the NMI buttons and DivMMC's paging off, maps RAM to `#0000-#BFFF` and the screen (bank 5) to `#C000-#FFFF`, sets 28MHz; own text screen (the tilemap), keys and interrupt handler; Graphics on Layer 2; data files built into the NEX (`Option NexData`). No files yet. `End` is a soft reset (back to NextZXOS) |
| Sega Mega Drive / Genesis | `md` | `NAME.md`, a cartridge ROM (68000) | Mega Drive / Genesis (so far run only on the Genesis Plus GX core) | nothing: own start (TMSS, the VDP), console on plane A, pads. `docs/md.md` |
| MEGA65 | `m65` | `NAME.PRG` at `$2001` (45GS02), `RUN"NAME` | MEGA65 (so far run only on Xemu) | nothing: ROMs out, interrupts off, 40MHz, own 80 x 25 console, keyboard queue, joysticks; the `Vic` class's 256 colour screen with sprites drawn by the CPU. `docs/m65.md` |

What each target can do:

| | cpc | cpcmin | cpcfw | cpm | test | zxn |
|---|---|---|---|---|---|---|
| Screen | own drawing, CPC font, modes 0 / 1 / 2 | own drawing | firmware text | BDOS console | ports | the tilemap's text mode, 40 x 32 / 80 x 32 |
| Interrupts (normal mode, `Interrupt`) | own handler, 300 Hz | own handler | firmware, plus a fast ticker event for `Interrupt` | - | - | own handler, the line interrupt: 300 Hz |
| Files (`FileSystem`) | - | Load / Save, tape / disc, volumes | Load / Save, tape / disc, volumes | everything (sequential, random access, delete, rename ...) | - | - (later: NextZXOS / esxDOS) |
| RAM pages (`Memory`, `Option Memory CPCExpansion`) | up to a 4MB expansion | up to a 4MB expansion | up to a 4MB expansion | - | - | - (later: the Next's 8K pages) |
| Data in the program's file (`Option NexData`: 16K blocks loaded into banks) | - | - | - | - | - | up to 97 blocks (1.5 MB; past bank 47 a 2MB Next) |
| Heap in main RAM (`Option Memory Small`) | yes | yes | yes | yes (up to the BDOS) | yes | yes (up to `#BE00`) |
| ROM commands (`System.Command`) | - | yes | yes | - | - | - |
| Overlay classes (`Option Class Overlay`) | - | yes (RAM pages, or one overlay area with `Small`) | yes (the same) | yes (one overlay area) | - | - |
| Pages (`Option Page`: several classes a page, classes copied into pages) | - | yes (RAM pages, or one overlay area with `Small`) | yes (the same) | yes (one overlay area) | - | - |
| Linked lists (`List`) | yes | yes | yes | yes | yes | yes |
| Graphics (`Graphics`: lines in modes 0-2, double buffering) | yes | yes | - | - | - | Layer 2: 320 x 200 of 320 x 256, 256 colours, double buffering |
| Interrupt classes (`Option Class Interrupt`), `Interrupt` | yes | yes | yes (firmware fast ticker event) | - | - | yes |

RAM pages: 64K machines (464, 664) have 1 page, 128K (6128, or a 464 with a 64K
expansion) 5, up to 33 with a 512K expansion and up to 257 with a 4MB expansion (WinAPE
offers one). The program must stay out of
`#4000-#7FFF` to use them (`Option Reserve &H4000, &H4000`).

The MSX and SC-3000 targets, and cpccard / cpc9990, have the cpc column's language but no
files, RAM pages, overlays or pages; their screen is the video chip's text (40 x 24, 80 x 24 on
a V9938 / V9958 / V9990, 32 x 24) and the `VDP` / `V9990` classes draw on it (also on cpc,
cpcmin and cpcfw through the AMSDAP adapter or the Powergraph). Interrupts are the frame's (50
or 60 a second) on the MSX and the SC-3000.

Not supported yet: CPC Plus / GX4000 extras (cartridge pages, ASIC), the original ZX Spectrum
(looked at, put aside - the Next is `zxn`), MSX disk files (MSX-DOS) and MegaROM mappers. See
`todo.md`.
