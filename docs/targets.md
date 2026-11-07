# NTC - Targets

(c) 2026 Cyborg Unicorn Pty Ltd

The platforms NTC compiles for: what each machine is, how its memory and display work, how
complete its graphics library is, and where the gaps are. For how to *select* a platform see
`tutorial/5.5-platform-options.md`; for the capability query see `tutorial/7.3-capabilities.md`.

Status = **maturity**, independent of this build box: **stable** = proven, runs (games shipped on
it); **draft** = new, compiles + assembles but not yet run on the real machine / an emulator;
**skeleton** = new, compiles but structurally unfinished; **template / harness** = not a real
machine.

Build-box note (a sandbox limitation, *not* a maturity one): the Z80 targets assemble here with
sjasmplus; the 68000 targets (`md`, `neogeo`, `ti89`) and the 45GS02 `m65` assemble with
vasm / vasm6502 **on your machine** — the cloud box only lacks those assemblers.

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
| `sc3000` | Z80 | cartridge, small RAM | TMS9918A (`#BE`/`#BF`) | stable |
| `colecovision` | Z80 | cartridge, bare metal, VDP frame = NMI | TMS9918A (`#BE`/`#BF`) | stable |
| `md` | 68000 | ROM + 64K work RAM | VDP | stable (games shipped; assembles with vasm on your machine) |
| `m65` | 45GS02 | MEGA65, large RAM | native | stable (assembles with vasm6502 on your machine) |
| `pcw16` | Z80 | 1MB in 64×16K blocks, 4 quarters (Rosanne) | Rosanne OS | draft |
| `neogeo` | 68000 (+Z80 sound) | cartridge, SP=thread in user mode | fix-layer | draft (assembles with vasm on your machine) |
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
| Bitmap | `cpc` (native), `pcw16`, PCW 8256, `trs80`, `system80`, `ti83`, `ti89`, Sharp G850, `m65` |
| Tile/sprite | `sc3000`, `colecovision`, `md`, `neogeo` |
| Both | `msx` (TMS9918 tiles **and** V9938 bitmap+sprites), `zxn` (Layer 2 **and** HW sprites + tilemap) |

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
| `md` | `Vdp` (15) | tiles + HW sprites |
| `zxn` | `Graphics` (10) | **hardware sprites / Layer 2 / 256-col not classed** - big gap vs the silicon |
| `cpm`, `cyborgos`, `cyborgoshh` | (inherited `Graphics`) | CyborgOS really draws via the **Pi/RVDU streamer**, not a per-platform class |
| `colecovision` | **none** | identical video to `sc3000` (TMS9918A, `#BE`/`#BF`) - the SC-3000 `VDP` class drops straight on |
| `m65`, `pcw16`, `neogeo`, `ti83`, `ti89`, `trs80`, `system80` | **none** | console only so far; graphics is the next layer |

### Known gaps (library, not hardware)

- `colecovision` ships no classes at all, yet its video is the same TMS9918A as `sc3000` - copying
  `sc3000/VDP.cls` would give it the full card API for free.
- `zxn` under-represents the Next badly: hardware sprites, Layer 2 and 256-colour exist in silicon
  but aren't shipped classes (BOUNCE drove sprites through a *project* class, not the library).
- `cyborgos` graphics completeness isn't in this table - its path is the Pi/RVDU streamer
  (`streamer/`, `pi-bridge.md`).
- The recent targets (`pcw16`, `neogeo`, `ti83`, `ti89`, `trs80`, `system80`) are console-only; the
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
