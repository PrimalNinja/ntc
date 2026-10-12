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

What each target can do:

| | cpc | cpcmin | cpcfw | cpm | test |
|---|---|---|---|---|---|
| Screen | own drawing, CPC font, modes 0 / 1 / 2 | own drawing | firmware text | BDOS console | ports |
| Interrupts (normal mode, `Interrupt`) | own handler, 300 Hz | own handler | firmware, plus a fast ticker event for `Interrupt` | - | - |
| Files (`FileSystem`) | - | Load / Save, tape / disc, volumes | Load / Save, tape / disc, volumes | everything (sequential, random access, delete, rename ...) | - |
| RAM pages (`Memory`, `Option Memory CPCExpansion`) | up to a 4MB expansion | up to a 4MB expansion | up to a 4MB expansion | - | - |
| Heap in main RAM (`Option Memory Small`) | yes | yes | yes | yes (up to the BDOS) | yes |
| ROM commands (`System.Command`) | - | yes | yes | - | - |
| Overlay classes (`Option Class Overlay`) | - | yes (RAM pages, or one overlay area with `Small`) | yes (the same) | yes (one overlay area) | - |
| Linked lists (`List`) | yes | yes | yes | yes | yes |
| Graphics (`Graphics`: lines in modes 0-2, double buffering) | yes | yes | - | - | - |
| Interrupt classes (`Option Class Interrupt`), `Interrupt` | yes | yes | yes (firmware fast ticker event) | - | - |

RAM pages: 64K machines (464, 664) have 1 page, 128K (6128, or a 464 with a 64K
expansion) 5, up to 33 with a 512K expansion and up to 257 with a 4MB expansion (WinAPE
offers one). The program must stay out of
`#4000-#7FFF` to use them (`Option Reserve &H4000, &H4000`).

Not supported yet: CPC Plus / GX4000 extras (cartridge pages, ASIC), ZX Spectrum (looked at,
put aside), MSX (planned). See `todo.md`.
