# NTC on the 68000 - the Sega Mega Drive / Genesis (`md`)

(c) 2026 Cyborg Unicorn Pty Ltd - MIT License

The `md` platform compiles NTC BASIC for a Sega Mega Drive / Genesis cartridge: a 68000 thread,
68000 keywords, a ROM file to run on the machine (a flash cart) or an emulator. It is the first
platform that isn't a Z80. The compiler is the same one; the 68000's parts are switched on by the
platform file's `;@cpu 68000`.

---

## 1. NTC on a 68000

The rules are the Z80 ones with A7 in place of SP:

- **A7 = the instruction pointer.** A thread is a list of longs: `dc.l kw_ltov, 10, var_x`.
  `rts` fetches the next keyword (16 cycles).
- **A keyword takes its arguments off the thread** left to right: an address with
  `movea.l (sp)+, an`, a literal with `move.l (sp)+, dn` (its low word is the Integer), and ends
  with `rts`. A branch is `movea.l (sp), sp` (GOTO), `lea label, sp` (a stub).
- **No `bsr` / `jsr`, no `-(sp)` on the thread.** Shared routines are entered with `bra` and the
  return address in A6, and end with `jmp (a6)`; `ntc_next` is a plain `rts`, so
  `lea ntc_next, a6` makes such a routine carry on with the thread (the Z80's IX convention).
- **The real stack** for code that wants `jsr`: `NTC_RS` keeps the thread position in `ntc_ip`
  and loads the real stack (`ntc_csp`), `NTC_TS` puts the thread back. The two macros are defined
  at the top of every program. The platform's console routines are ordinary subroutines on the
  real stack.
- **Compares** set the Z flag (Z = true), as on the Z80; `rts` keeps it and `movea` (taking a
  branch's label) doesn't touch the flags. An `Scc` gives #FF for true, `addq.b #1` turns that
  into Z.

### One mode, interrupts always on

The program runs in **user mode**: A7 is the user stack pointer. A 68000 interrupt switches to
supervisor mode and pushes its frame on the **supervisor stack** (SSP), never on the thread. So
the thread is safe from interrupts without turning them off, and there is nothing for normal mode
to do: every keyword is the turbo one, there are no `_n` copies, `Turbo On` / `Turbo Off` compile to
nothing, `Option Turbo` / `NoTurbo` change nothing. The frame interrupt (level 6) runs all the
time. (The Mega Drive has no NMI either, but user mode makes that not matter.)

### Data

- **Integer** 16 bits, **Long** 32 bits, both big endian as the 68000 keeps them (the Z80 library
  keeps Longs low word first - the 68000 keywords are written for theirs).
- **Variables are in RAM from $FF8000**, the RAM block after the ROM: the start code copies its
  first image there (a String's capacity byte, `String * n`'s spaces, the library's starting
  values). The arrays come after it and `kw_bssinit` clears them.
- **Addresses in an Integer are 16 bits sign extended** - the 68000's short addressing:
  0-32767 is the ROM's first 32K, -32768..-1 is RAM $FF8000-$FFFFFF, exactly where the variables
  are. So `VarPtr`, `Peek`, `Poke`, `Deek`, `Doke` and the array descriptors (12 bytes, as the
  Z80's) work on the variables unchanged. `Deek` / `Doke` need an even address. In a thread an
  address is a long, so threads, literals and strings can be anywhere in the ROM.
- **AddressOf** gives the procedure's number in the program's `ntc_aptab` (from 1), not its
  address (a ROM address is 24 bits); `CallAddr` looks it up. A program that only passes it to
  `CallAddr` (the usual way) doesn't see the difference.
- **Inp(n)** / **Out n, v**: the byte at $A10000 + n - the I/O area (1 the version, 3 / 5 the
  pads' data, 9 / B their control). The 68000 has no I/O ports.

### What isn't there yet

Pages and overlay classes (`Option Page`, `Option Class Overlay`), the `Memory`, `List`,
`FileSystem` and `Graphics` classes, the `Interrupt` statement and interrupt classes, `Library:
ROM`. A Z80 `#asm` block doesn't assemble, of course: `#If NTC_MD Then` picks a 68000 one.
`Input` and `Inkey` read pad 1 (below).

---

## 2. The Mega Drive platform

### Memory

| Where | What |
|---|---|
| $000000 | the 68000's vectors (the frame interrupt, the exceptions) |
| $000100 | the cartridge header (`mdbuild.py` fills in the name, the ROM's end, the checksum) |
| $000200 | the start code, then the program: `ntc_start`, the threads, the stubs, the `#asm` blocks, the literals and strings, the library |
| `ntc_romend` | the end of the ROM: the RAM block's first image follows in the file |
| $FF0000-$FF6FFF | free (an `--log` test build: the console's transcript) |
| $FF7000-$FF77FF | the real stack (`ntc_csp`) |
| $FF7800-$FF7FFF | the supervisor stack (interrupts, exceptions) |
| $FF8000- | the variables (the program's, the library's), then the arrays |

The assembler (vasm, `-Fbin -coalesced`) writes the ROM part from 0 and the RAM part, assembled at
$FF8000, straight after it in the file. The compiler puts every library section's `;@ram` ...
`;@rom` lines in the RAM block - in an `#asm` block too, so a program's own 68000 code can have
its own RAM.

### The start

TMSS (`SEGA` to $A14000 on a machine that wants it), the Z80 held in reset with its bus taken,
RAM cleared, the RAM block copied, the VDP set up (H40: 320 x 224; plane A at $C000, plane B at
$E000, both 64 x 32 cells; sprites at $D800; horizontal scroll at $FC00; the window off), VRAM,
CRAM and VSRAM cleared, the font into tiles 32-126, the pads' TH lines as outputs, the PSG quiet,
then user mode on the real stack and `ntc_start`.

An exception (address error, illegal instruction ...) prints `68000 EXCEPTION nn PC xxxxxx SP
xxxxxx` on the console and stops: SP is the thread position, so it says which keyword was
running.

### The console

Plane A, 40 x 28: character c is tile c (font8x8_basic, public domain, in colour 1 of palette 0 -
white), in front of the sprites. A copy of the text is kept in RAM for scrolling. `Print`,
`Locate`, `Cls`, `Tab`, `Mode` (one mode: it clears) work as everywhere.
`Vdp.TextPalette p` picks the palette (the text is colour 1 of it), `Vdp.LoadFont first, fg, bg`
makes another copy of the font (an opaque one, say) and `Vdp.TextFont first` prints with it.

### Pads, Inkey and Input

The frame interrupt reads both pads every frame (3 or 6 button: a 6 button pad needs the gap
between reads). `Pad.Read(n)`: bit 0 Up, 1 Down, 2 Left, 3 Right, 4 B, 5 C, 6 A, 7 Start, 8 X,
9 Y, 10 Z, 11 Mode. `Inkey` / `Inkey$` give a button newly pressed on pad 1 as a character: Start
13, A B C X Y Z "A" ... "Z", Mode 27, Up Down Left Right &HF0-&HF3 (the CPC's cursor codes).
`Input` reads those until Start - there is no keyboard.

### Frame, Ticks

`Frame` waits for the frame interrupt (the start of the vertical blank). `Ticks` counts frames,
60 a second (50 on a PAL machine).

### The platform classes (`lib/md/`)

Each method is one `#asm` block, so each is a keyword (one thread long and its arguments).

| Class | Members |
|---|---|
| `Vdp` | `Color index, value` (&H0BGR), `Colors addr&, first, count`, `Tiles addr&, first, count` (32 bytes each), `Cell plane, x, y, value`, `Fill plane, x, y, w, h, value`, `ScrollX plane, x`, `ScrollY plane, y`, `Backdrop index`, `TextPalette p`, `LoadFont first, fg, bg`, `TextFont first`, `Sprite n, x, y, size, value`, `Hide n`, `HideAll`, `Update`; constants `Palette`, `FlipX`, `FlipY`, `Front`, `Size8`, `Size16`, `Size24`, `Size32`, `PlaneA`, `PlaneB` |
| `Pad` | `Read(n)`; constants `Up` ... `Mode` |
| `Psg` | `Play channel, period, slide, volume, frames` (3 tones, the noise; a slide a frame, a fade), `Stop channel`, `Quiet`, `Busy(channel)`, `Update` (once a frame) |
| `StdIO` | the console, as on every platform |
| `System` | the same members as everywhere: `Platform` = "MD", `TicksPerSecond` = 60 ... |

A cell's value: tile + `Vdp.Palette` * palette (0-3) + `FlipX` / `FlipY` + `Front`. Sprites are kept
in a copy of the sprite table in RAM; `Vdp.Update` writes it to the VDP - once a frame, after
`Frame`. The VDP is only touched from the program, never from the frame interrupt, so a method is
never cut in two by it. Data in the ROM (tiles, colours) is passed as a Long address: a function
whose `#asm` returns a label's address, as `bas/cyswarm/Gfx.cls` does.

---

## 3. Building and testing

### Tools

- **vasm**, Motorola syntax: http://sun.hasenbraten.de/vasm/ (or a mirror on GitHub),
  `make CPU=m68k SYNTAX=mot`. `NTC_VASM` gives `mdbuild.py` its path. The assembly is
  `vasmm68k_mot -spaces -Fbin -coalesced` (`-spaces`: the compiler writes `move.w d0, d1` with a
  space after the comma; comments start with `;`).
- **To test without a machine**: the Genesis Plus GX libretro core
  (https://github.com/ekeeke/Genesis-Plus-GX): add `vram; cram; reg; work_ram; m68k;` to the
  `global:` line of `libretro/link.T` (so the tests can read the VDP's memory), then
  `make -f Makefile.libretro`. `NTC_MDCORE` gives its path.

### Build

```
python3 test/mdbuild.py bas/cyswarm/Main.bas bas/cyswarm/Swarm.cls bas/cyswarm/Gfx.cls bas/cyswarm/Paths.cls --out=CYSWARM.md --name="CYBORG SWARM"
```

`mdbuild.py` runs `test/cli.js --platform=md`, assembles, and fills in the header's name, ROM end
and checksum. The IDE (platform "Sega Mega Drive / Genesis") writes the same assembly.

### Run

```
python3 test/mdrun.py CYSWARM.md --frames=600 --pad=100:S,104:- --shot=out.png --text
```

`--pad=frame:buttons` (U D L R A B C S X Y Z M, `-` none) holds buttons from that frame on;
`--shots=f1,f2:prefix` takes pictures; `--text` prints plane A; a `--log` build (`mdbuild.py
--log`) keeps the console's transcript in RAM and `--log --untilend` prints it when it stops
changing.

### Tests

`test/mdregress.sh` builds and runs `bas/md_test` (157 checks: constants, Enum, maths and its
edges, logic, Like, IIf, Choose, Long, every string function, LSet / RSet / Mid$ =, String * n,
String Max n, Split / Join, Byte / Long / String / 2D / dynamic arrays, ReDim Preserve, Erase,
For Each, Type and With, If / ElseIf, Select Case with ranges and Is, For with Step, Exit For / Do
/ Function, While, Do loops, GoSub, On GoSub / GoTo, ByRef / ByVal, Optional, Static, a class with
a Property, AddressOf / CallAddr, VarPtr / Peek / Poke / Deek / Doke, a 68000 `#asm` block and asm
keyword functions, Frame and Ticks, the Vdp / Pad / Psg classes, Tab), then the VB self tests that
fit a machine with no keyboard (vb_test, 2, 3, 4, 6, 7, 8, 9, Long, the function arguments, the
class demo, the sieve). All pass. vb_test5, 10 and 11 have Z80 `#asm` in them.

The Z80 platforms' output is unchanged: every example program compiles byte for byte as before on
cpc, cpcmin, cpcfw, zxn, cpm, cyborgos and test, in both modes.

---

## 4. In the compiler (`js/ntc_compiler.js`)

All behind `blnM68k` (set from the platform's `;@cpu 68000`):

- the library is `NTC_LIB_ASM_68K` (`asm/ntc_lib_68k.asm`, put in `js/ntc_lib.js` by `gen.js`);
- one mode: the start mode is always turbo, `Turbo On / Off` emit nothing, `exitCode` is `rts`;
- the header: `org $0`, the platform's vectors section first, the `NTC_RS` / `NTC_TS` macros;
- `ntc_start`: `move.l sp, ntc_csp` / `lea main_thread, sp` / `rts` (the platform's start code
  has done the rest);
- thread words `dc.l`; GOTO stubs `lea label, sp` / `rts`; GOSUB stubs keep the thread position
  in a long;
- `procStubs68k`: the call and return stubs (arguments off the thread with `(sp)+`, Strings,
  Longs, Types, array descriptors, locals cleared, ByRef copied back), the return point a long;
- the variables, temps and the library's `;@ram` lines into the RAM block at $FF8000; literals
  `dc.w` / `dc.l`, strings `dc.b`, everything after on an even address; arrays each on an even
  address;
- `#asm` blocks end with `rts`; `lea x, sp` / `movea.l #x, sp` / `movea.l (..), sp` count as a
  branch (not an asm keyword).
