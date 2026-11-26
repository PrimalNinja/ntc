# NTC - Targets

(c) 2026 Cyborg Unicorn Pty Ltd

The platforms NTC compiles for: what each machine is, how its memory and display work, how
complete its graphics library is, and where the gaps are. For how to *select* a platform see
`tutorial/5.5-platform-options.md`; for the capability query see `tutorial/7.3-capabilities.md`.

Status = **maturity**, independent of this build box: **stable** = proven, runs (games shipped on
it); **draft** = new, a first build;
**skeleton** = new, compiles but structurally unfinished; **template / harness** = not a real
machine.

Build-box note (a sandbox limitation, *not* a maturity one): the Z80 targets assemble here with
sjasmplus; the 68000 targets (`md`, `x68000`, `neogeo`, `neocd`, `amiga`, `ti89`), the 45GS02 `m65` and the
6502 `c64reu` assemble with vasm / vasm6502, and the 80386 `towns` with nasm, **on your machine** — the cloud box only lacks those assemblers.

## 1. The targets

| Platform | CPU | Memory model | Console | Status |
|---|---|---|---|---|
| `cpc` | Z80 | flat 64K, `#4000` page/overlay window, screen `#C000` | direct screen, 25 rows | stable |
| `cpcmin` | Z80 | as `cpc`, firmware kept for disc/ROM | direct screen | stable |
| `cpcfw` | Z80 | as `cpc`, firmware text/keys | firmware | stable |
| `cpc9990` | Z80 | `;@base cpc` | **on the V9990 card** (`&FF60`) | stable |
| `cpccard` | Z80 | `;@base cpc` | on the V9938 card (`&FF88`) | stable |
| `cpm` | Z80 | CP/M TPA (~61K), banks owned by the OS | BDOS | stable |
| `cyborgos` | Z80 | `;@base cpm` + hypervisor slot banking | BDOS + Pi/RVDU | stable |
| `cyborgoshh` | Z80 | `;@base cyborgos` (headless) | Pi/RVDU | stable |
| `msx` | Z80 | cartridge + mapper | VDP (native chip) | stable |
| `msxcard` | Z80 | `;@base msx` | V9938 card at `#88`, 80 col | stable |
| `msx9990` | Z80 | `;@base msx` | V9990 (GFX9000) at `#60` | stable |
| `msxdos` | Z80 | `;@base cpm`, MSX-DOS 2 / Nextor (.COM) | BDOS | stable |
| `zxn` | Z80 | ZX Spectrum Next MMU banking | native | stable |
| `zxndot` | Z80 | ZX Spectrum Next dot command, Small Model: 8K at `#2000` | BASIC's screen (ROM `rst #10`) | stable |
| `zxndotl` | Z80 | `;@base zxndot`, Large Model: 32K at `#8000` + the Memory class's banks from NextZXOS's allocator, slots swapped round OS calls | BASIC's screen | stable |
| `sc3000` | Z80 | cartridge, small RAM | TMS9918A (`#BE`/`#BF`) | stable |
| `colecovision` | Z80 | cartridge, bare metal, VDP frame = NMI | TMS9918A (`#BE`/`#BF`) | stable |
| `md` | 68000 | ROM + 64K work RAM | VDP | stable (games shipped; assembles with vasm on your machine) |
| `x68000` | 68000 | the Sharp X68000: a 2HD floppy image (.XDF) that boots itself, no Human68k; SP=thread in user mode, a supervisor call (`trap #1`); variables and arrays at `$2400`-`$7FFF` (23K), code and strings the rest of RAM | 96 x 32 text (the ROM's font) | stable (TIANLONG runs on it: `docs/x68000.md`) |
| `towns` | 80386 | the Fujitsu FM Towns: a 2HD floppy image that boots itself into 32 bit protected mode, no Towns OS; ESP=thread, the program in ring 3; variables and arrays at `$1000`-`$FFFF` (60K), about 600K of code and strings, files past the program loaded to `$100000` on | 80 x 25 text on the 640 x 400 screen (the ROM's font) | stable (TIANLONG runs on it: `docs/towns.md`) |
| `m65` | 45GS02 | MEGA65, large RAM | native | stable (assembles with vasm6502 on your machine) |
| `c64reu` | 6502 | a stock Commodore 64 with an REU: a PRG at `$0801` that takes the machine. The thread is in the REU and runs through three 64 byte windows in page 1; the C64's own memory holds the library, variables and arrays. A thread of up to 65K (`--split`: a file of its own) beside 51K in the C64; `Option Lot` cuts a bigger program into lots of the REU, 64K of code and 32K of workspace each | 40 x 25 text, own font | draft (first build: `docs/c64reu.md`; assembles with vasm6502) |
| `pcw16` | Z80 | 1MB in 64×16K blocks, 4 quarters (Rosanne) | Rosanne OS | draft |
| `neogeo` | 68000 (+Z80 sound) | cartridge (.neo), SP=thread in user mode, RAM at `$100000` | fix-layer | stable (two games shipped: `docs/neogeo.md`) |
| `neocd` | 68000 (+Z80 sound) | CD (.cue: IPL.TXT and its files, CD audio tracks), SP=thread in user mode, variables at `$0F8000` | fix-layer | draft (builds discs: `docs/neogeo.md` section 7) |
| `amiga` | 68000 | boot disc (.adf): takes the machine from Kickstart, SP=thread in user mode, variables at `$0400`, program at `$10000`; chip / slow / fast RAM found at the start | 80 x 32 text (one bitplane) | draft (first stage: `docs/amiga.md`) |
| `ep128` | Z80 | an EXOS program file at `#0100` (.COM, up to 47K): takes the machine from EXOS, own screen, keys and frame interrupt; every free 16K segment found at the start is a `Memory` page (128K to 4 MB) | 40 x 25 / 80 x 25 text (Nick, 2 colours) | draft (first stage, EXOS 2.0 / 2.1 / 2.4, 128K to 3.7 MB: `docs/ep128.md`) |
| `ti83` | Z80 | flat, program at `#9D95` | TI-OS (`_PutС`), 16×8 | draft |
| `ti89` | 68000 | AMS, nostub | direct LCD | skeleton (assembles with vasm on your machine) |
| `trs80` | Z80 | flat, program `~#5200`, screen `#3C00` | direct video, 64×16 | draft |
| `system80` | Z80 | `;@base trs80` (Model I clone) | direct video, 64×16 | draft |
| `baremetal` | Z80 | template (fill in) | - | template |
| `test` | Z80 | host harness | port I/O | harness |

## 2. Graphics family

The deciding split is **bitmap vs tile/sprite**, because it sets the whole drawing model:

- **Bitmap** - a pixel-addressable framebuffer. Line drawing (`Plot/Line/Box/Fill/Point`) works,
  and sprites are **software** (save background, draw, restore - the PCW save-under trio, or the
  CPC compiled-sprite + double-buffer).
- **Tile/sprite** - no free pixel addressing. You compose a tilemap and move **hardware** sprites
  (`SetTile/Scroll`, `Define/Move/Show`). Line drawing doesn't apply (or is too dear).

| Family | Platforms |
|---|---|
| Bitmap | `cpc` (native), `pcw16`, PCW 8256, `trs80`, `system80`, `ti83`, `ti89`, Sharp G850, `m65`, `ep128` (Nick), `amiga` (bitplanes; its hardware sprites are not classed) |
| Tile/sprite | `sc3000`, `colecovision`, `md`, `neogeo`, `neocd`, `c64reu` (characters and the 8 sprites) |
| Both | `msx` (TMS9918 tiles **and** V9938 bitmap+sprites), `zxn` (Layer 2 **and** HW sprites + tilemap), `x68000` (a graphics page **and** sprites **and** a text plane), `towns` (two bitmap layers **and** sprites) |

The TMS9918 "screen 2" is a *constrained* pseudo-bitmap (colour is per-8-pixels), so
Coleco / SC-3000 / MSX-1 count as tile/sprite; true bitmap on an MSX needs the V9938.

## 3. Graphics-library coverage

What each platform currently **ships** as graphics classes (not what the hardware could do -
see the gaps). Measured by capability, not method count.

| Platform | Graphics classes shipped | Notes |
|---|---|---|
| `cpc`, `cpcmin`, `cpcfw`, `cpc9990`, `cpccard` | `Graphics` (native: Line/Plot/Pen/Clip/**DoubleBuffer**/**Flip**/CopyText) + `VDP` (card: PSet/Point/Box/Fill/Copy/Palette/Screen) | the only targets with **both** a native drawer and a card drawer |
| `msx`, `msxcard`, `msx9990` | `VDP` (PSet/Point/Box/Fill/Copy/Palette/Screen) | richer chip API than CPC's native, but **no** DoubleBuffer/Flip/Clip |
| `sc3000` | `VDP` (17) | TMS9918A tile/sprite |
| `md` | `Vdp`, `Pad`, `Keys`, `Psg`, `Pcm`, `Z80` | tiles + HW sprites, the sprite table, scrolling by cell and by line; DPCM music on the YM2612's DAC by a Z80 player (`docs/md.md`) |
| `x68000` | `Vdp`, `Keys`, `Pcm`, `Opm` | 256 x 256 in 256 colours: sprites, graphics page 0 with up to 4 raster splits, the text plane; ADPCM music, the YM2151's registers; no tile layers, no files (`docs/x68000.md`) |
| `towns` | `Vdp`, `Keys`, `Pcm`, `Memory` | 256 x 240, 2 layers of 32768 colours: sprites, a backdrop in 4 scrolled bands, words; ADPCM music and 4 channels of effects (the RF5C68); no tile layers, no files, no CD (`docs/towns.md`) |
| `m65` | `Vic`, `Joy`, `Sid` | the screen, the palette, sprites, stamps, boxes, a star field; joysticks; the SIDs (`docs/m65.md`) |
| `zxn` | `Graphics` (10) | **hardware sprites / Layer 2 / 256-col not classed** - big gap vs the silicon |
| `cpm`, `cyborgos`, `cyborgoshh` | (inherited `Graphics`) | CyborgOS really draws via the **Pi/RVDU streamer**, not a per-platform class |
| `colecovision` | **none** | identical video to `sc3000` (TMS9918A, `#BE`/`#BF`) - the SC-3000 `VDP` class drops straight on |
| `neogeo`, `neocd` | `Vdp`, `Keys`, `Pad`, `Pcm`, `Psg`, `Fm`, `Cdda`, `Sound` | sprites (a table of 128, any sprite straight), a backdrop of sprites in four scrolled bands, palettes, the fix layer's cells; ADPCM music and samples, the SSG, FM registers (`docs/neogeo.md` section 3) |
| `amiga` | `Memory`, `Keys`, `Loader` | no graphics or sound classes yet; blocks of chip and other RAM, keys held and two joysticks, files off the game's discs (one to four drives, discs changed) (`docs/amiga.md`) |
| `ep128` | `Memory`, `Keys` | no graphics, sound or file classes yet; the machine's segments as pages (`Option Memory Heap Pages`), keys held, the built in joystick and both control ports (`docs/ep128.md`) |
| `c64reu` | `Reu`, `Task`, `Disk`, `Vic`, `Sid`, `Keys`, `Joy` | the REU as the program's memory (blocks, rows, fills), up to 32 tasks, files off the disc into the REU, the 8 sprites and the program's own characters, three SID voices, keys held, both joysticks (`docs/c64reu.md`) |
| `pcw16`, `ti83`, `ti89`, `trs80`, `system80` | **none** | console only so far; graphics is the next layer |

### Known gaps (library, not hardware)

- `colecovision` ships no classes at all, yet its video is the same TMS9918A as `sc3000` - copying
  `sc3000/VDP.cls` would give it the full card API for free.
- `zxn` under-represents the Next badly: hardware sprites, Layer 2 and 256-colour exist in silicon
  but aren't shipped classes (BOUNCE drove sprites through a *project* class, not the library).
- `cyborgos` graphics completeness isn't in this table - its path is the Pi/RVDU streamer
  (`streamer/`, `pi-bridge.md`).
- `amiga` and `ep128` are first stages: memory, keys and (the Amiga) files, no graphics or sound
  classes. The Amiga's are the next ones wanted (a `Vdp` and a `Pcm` in the other 68000 machines'
  shapes).
- `x68000` and `towns` have no tile layers and no file classes; the FM Towns' CD is not used.
- `c64reu`: no class that writes files; bitmap mode is not classed.
- The recent targets (`pcw16`, `ti83`, `ti89`, `trs80`, `system80`) are console-only; the
  normalised display layer (below) is how they get graphics without hand-rolling each one.

## 4. The normalised display model (plan)

Goal: **same shape, different capabilities** - one display interface so the same NTC source draws
on any target, with a capability query for what varies. Built **additively** - a new `Display`
class per target, leaving the legacy `Graphics`/`VDP` classes (and CyborgOS) untouched.

**Coordinates, fixed for every display:** top-left origin, **y-down, x-then-y**, device pixels
`0..Width()-1` / `0..Height()-1`. Every current target already agrees; a firmware or odd-origin
class (the Amstrad GRA ROM is bottom-left/y-up) flips internally. NTC's own fast routines are used
throughout - never firmware.

**Method groups + a capability query:**

- **Bitmap / draw** (cap `BITMAP`): `Clear, Plot, Line, Box, Fill, Point, Palette, Flip, Clip`.
- **Sprite** - *the same shape on both families* (cap `SPRITES`, + `HWSPRITES`): `Define(n,data),
  Move(n,x,y), Show(n,on)`. Hardware sprite list on a tile/sprite machine; save-under software
  blit on a bitmap machine. (This is the CpcScr / ZxnScr pattern from BOUNCE, generalised.)
- **Tiles** (cap `TILES`): `SetTile, Scroll`.
- **`Caps(name)`** - the query, as `System.HasCapability`.

The colour argument `c` is an ink on a colour display, a **dither pattern index** on a mono one
(cap `COLOUR` / `MONO`) - same call either way. Dither is how a mono screen gets apparent greys
(the PCW Cyrus-chess look): spatial patterns for static shading, flicker for the rare moving part.

**Completeness, done honestly**, is then: which of
`{BITMAP, SPRITES, HWSPRITES, TILES, PALETTE, FLIP, POINT, COLOUR|MONO}` a target answers yes to -
a pure-bitmap CPC and a pure-sprite Neo Geo are each complete for their family, not "more" or
"less" than each other.

## 5. Candidate targets (not platforms yet)

- **Amstrad PCW 8256 / 8512** - CP/M Plus machine; runs as `cpm` + a graphics driver class (screen
  bank reached via CP/M 3 `SELMEM`/`MOVE` through BDOS 50; 720×256 mono, roller-RAM, dither).
- **Amstrad NC100** - `cpm` (via the ZCN third-party CP/M) + a graphics class; 480×64 mono.
- **Sharp PC-G850V** (and the G800/G850 Z80 series) - native bare-metal, 144×48 mono; the audience
  already writes Z80 asm on it.
- Dropped: **Cambridge Z88** (no CP/M, needs a full native OZ platform - worth it only as its own
  project), the **NEC PC-8201A** and the **Sharp PC-12xx/E500** families (not Z80 - 8085 / Sharp
  CPUs, outside NTC without a new backend).
