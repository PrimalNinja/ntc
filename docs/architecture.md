# NTC - Architecture

How an NTC program is laid out in memory, how it starts, how it runs, how interrupts reach
it, and how the keyword ROMs fit in. The CPC platforms get the most detail; CP/M and the test
platform are covered where they differ. For the language see `userguide.md`; for the
compiler's internals and the reasons behind each choice see `NTC.md`.

---

## 1. The ideas everything rests on

**The thread.** A compiled program is a list of 16 bit words. Each word is the address of a
keyword (a machine code routine), followed by that keyword's arguments (addresses of
variables, literals, labels).

```
main_thread:
        dw kw_ltov, 10, var_x          ; x = 10
        dw kw_printint, var_x          ; Print x
        dw kw_stop                     ; End
```

**SP is the instruction pointer.** The Z80 stack pointer points into the thread. A keyword
pops its arguments with `pop`, does its work and ends with `ret`, which fetches the next
keyword's address and jumps to it (10 T states). So inside the thread:

- there is no `call` and no `push` (they would write over the thread);
- shared routines are entered with `jp`, with the return address in IX, and end with
  `jp (ix)`; `ld ix, ntc_next` (a plain `ret`) makes such a routine carry on with the thread;
- no register keeps a value from one keyword to the next.

**The real stack.** Code that needs `call` / `push` (firmware and BDOS calls, the Memory and
List classes, Graphics, file routines) switches SP to the real stack first: the caller's stack
saved at start in `ntc_csp` (CP/M: the program's own). It saves the thread position, runs,
and puts SP back in the thread. Wrappers do this: `ntc_fwcall` / `ntc_bdos` (host calls),
`mem_go` (Memory, List), `fs_go` (FileSystem), the Graphics methods.

**Two modes.** The same thread runs in both:

| | Turbo | Normal |
|---|---|---|
| Interrupts | off the whole time | let in at *safe points* |
| Straight line keywords | `ret` to the next one | the same |
| Branches (GOTO, loop ends, GOSUB / RETURN, procedure call / end) | `ret` | through `ntc_xn`, which opens a one-instruction window for interrupts |
| Long runs with no branch | - | `kw_irq` every 32 keywords |

Only branch keywords have two copies (the normal one named `_n`). Inside every keyword SP is
the thread and interrupts are off, in both modes. A program starts in normal mode unless it
has `Option Turbo`; `Turbo On` / `Off` switch at run time; `Option NoTurbo` builds normal mode
only.

**Procedures** have one set of parameters, locals and one return point each (no recursion).
A call is `dw p_name_c, args...`: the stub copies the arguments, saves SP in `p_name_rs` and
jumps into the body; the end stub `p_name_r` loads SP back. A procedure called from both modes
is built twice.

**Classes** are compile-time groups of variables and procedures: no objects at run time. A
class can be *resident* (in the program), an *overlay* or part of a *page* (loaded into the
`#4000` window), or an *interrupt class* (its `Tick` runs at a set rate).

---

## 2. Where things are: the program file

The compiler writes one assembler file; sjasmplus turns it into the program (CPC: a binary
with an AMSDOS header, CP/M: a `.COM`). In order:

| Part | What |
|---|---|
| `ntc_start` | the start code (section 4) |
| `main_thread` | the main program's thread |
| procedures | each one's thread, call stub (`_c`) and return stub (`_r`); a second copy (`_n`) when called from both modes |
| GOTO / GOSUB stubs | `l_go: ld sp, l / ret` and the like |
| variables | scalars, Strings (a capacity byte, then the text), temporaries (`tmpN`, `stmpN`), return points |
| read only data | the literal pool (`lit_n`), string literals, glyph words (CPC: Print text as ZOSCII glyph words) |
| the library | only the sections the program uses, each once per mode it is used in - or, with `Option Library ROM`, the jump block instead (section 6) |
| `ntc_end` | the end of the file |
| arrays | after `ntc_end`, not in the file: `ntc_bss` is their start, `ntc_free` the first byte after them; `kw_bssinit` clears them at start |

Overlay classes and pages are extra files (`PROGRAM.001` ...), assembled for `#4000` in the
same assembly, so every label is shared and nothing is linked at load time.

---

## 3. Memory maps

### 3.1 CPC, full build (the library in the program)

```
#0000 +--------------------------------------------+
      | restart vectors; #0038 = the interrupt     |
      | entry (cpc, cpcmin: NTC's handler; cpcfw:  |
      | the firmware's)                            |
#0040 +--------------------------------------------+  default org
      | jr over #0042-#004C: the bank switch -     |
      | #0042 main RAM's SP, #0044 out (c), c,     |
      | #0046 jp the landing (ld sp, (#0042) : ret)|
      | the program: start code, threads, stubs,   |
      | variables, literals, its library sections  |
      +--------------------------------------------+  ntc_end
      | arrays (cleared at start)                  |
      +--------------------------------------------+  ntc_free
      | free: the Memory class's page tables, or   |
      | the Small heap                             |
      |                                            |
#4000 |   the RAM page window #4000-#7FFF          |  Memory pages, overlay classes and
#7FFF |   (only when the program is out of it)     |  pages are switched in here
      |                                            |
#A600 +--------------------------------------------+  the platform's top (Memory.Top)
      | cpcfw: #A5F0 the fast ticker block (only   |
      | with Interrupt / interrupt classes)        |
      | cpcfw, cpcmin: the firmware's and AMSDOS's |
      | RAM #A700-#BFFF; the caller's stack        |
      | cpc: the caller's stack (the firmware is   |
      | dead once the program runs)                |
#C000 +--------------------------------------------+
      | the screen (#C000-#FFFF)                   |
#FFFF +--------------------------------------------+
```

The program and its stack must stay out of `#4000-#7FFF` for RAM pages to work
(`Option Reserve &H4000, &H4000` checks it): a program that reaches into the window gets
`Memory.Pages() = 0`. Overlay classes and pages add that reserve themselves.

### 3.2 CPC, `Option Library ROM`

```
#0040 +--------------------------------------------+
      | the program, its jump block, the start     |
      | code that finds the ROM set                |
      |  ... arrays, free RAM ...                  |
#87FF +--------------------------------------------+  the program must end below #8800
#8800 | the ROM's starting variables and the code  |  copied from the main ROM by its
      | it runs from RAM (scroll / cls, interrupt  |  patcher at start
      | handler, CallBank switch; in a set of more |
      | than one ROM, the far call stubs)          |
#9400 +--------------------------------------------+
      | the ROM's other variables (cleared at      |
      | start), including the 2K buffer ntc_buf    |
#A5EF +--------------------------------------------+
      | as 3.1 (firmware, stack, screen)           |
#C000 | the screen - and the keyword ROM, in the   |
      | upper ROM, over it while it is selected    |
#FFFF +--------------------------------------------+
```

`#8800-#A5EF` is fixed by agreement: the ROM does not claim it through the firmware (its
power-on init does nothing). Programs CALLed from BASIC need `MEMORY &87FF` first. Only a ROM
build has this area; a full build runs up to the platform's top. The ROM's variables grow
upward from `#9400`; when the firmware is retired they can grow up into its RAM.

### 3.3 Other platforms

| Platform | Org | Stack | Top of free RAM | Notes |
|---|---|---|---|---|
| `cpm` | `#0100` | the program's own (`ntc_cpmstack`) | the BDOS (address 6); with Graphics on CP/M Plus `#C000` (its line loop copy) | console and files through BDOS; no pages. Graphics (a CPC only) writes the screen itself: 2.2 `#C000`, Plus block 1 through C1 from common memory |
| `test` | `#4000` | the caller's | `#C000` | console through I/O ports, for the test harness |
| `zxn` | `#0040` | its own, from `#C000` down | `#BE00` | the ZX Spectrum Next: see 3.4 |

### 3.4 ZX Spectrum Next (`zxn`)

Laid out as the CPC's map (3.1), in the Next's 8K MMU slots:

```
slot  page
 0-1  16, 17  #0000 +--------------------------------------------+
              |      | #0038: the interrupt handler's jump        |
              |#0040 +--------------------------------------------+  default org
              |      | the program, its arrays, the Small heap    |
 2-3  18, 19  |#4000 |                                            |
 4-5  20, 21  |#8000 |                                            |
              |#BE00 +--------------------------------------------+  the platform's top
              |      | the stack (from #C000 down)                |
 6-7  10, 11  |#C000 +--------------------------------------------+  bank 5: what the ULA
              |      | #C000-#DAFF the ULA screen                 |  and the tilemap show
              |      | #E000-#E9FF the tilemap (80 x 32 bytes)    |
              |      | #EC00-#F3FF its characters (256 x 8)       |
              |#FFFF +--------------------------------------------+
```

Graphics draws on Layer 2: two buffers of 5 banks (12-16, 17-21), the page being drawn on
in slot 6 (`#C000-#DFFF`) meanwhile. `Option NexData` blocks fill banks 1-4, 6, 7, 11, 22-111
(`zxn_sel` puts one in `#4000-#7FFF`: slots 2, 3).

The NEX file holds banks 8-10 (pages 16-21: the program as assembled, `MMU 0 5, 16`), bank
5 (a start stub at `#7E00`) and the `Option NexData` banks. NextZXOS runs the stub with banks 5, 2, 0 in `#4000-#FFFF`; it turns
the NMI buttons off (NextReg 6 bits 3, 4), DivMMC's automatic paging off (NextReg 10 bit 4) and
its memory out (port `#E3`), sets 28MHz and IM 1 and the slots - slot 3 last, from its copy in
slot 7 - and jumps to `ntc_start`. NextRegs through ports `#243B` / `#253B` (no Z80N opcodes).

---

## 4. Start up

What `ntc_start` does, in order (each step only when the program needs it):

1. **`di`.**
2. **`Option Library ROM`:** `ntc_rj_find` - with the firmware (still there at this point on
   every CPC platform) it selects ROM slots 0-31 (KL ROM SELECT) looking for the main ROM of
   the set for this platform, then the set's other ROMs by its stamp; selects the main ROM and
   calls its patcher (section 6). The ROM's RAM (`#8800-#A5EF`) is set up and the jump block
   gets the ROM's addresses. Then `ntc_rj_exit` is pushed, so `End` comes back through it (the
   caller's ROM selection back). Not found: a message, a key, back to the caller.
3. **`Option Stack`:** the caller's SP is saved and SP set to the given address.
4. **`ld (ntc_csp), sp`:** the real stack the program will use for host calls and real stack
   code.
5. **`Option RomEnable`** (cpcfw, cpcmin): the background ROMs (AMSDOS ...) are started again,
   because `RUN"` of a binary dropped them.
6. **Normal mode:** `ntc_nmode` = 1 (key and frame waits let interrupts in).
7. **Interrupt classes:** each slot of `ntc_isl` gets its rate, its first count and its
   `Tick`'s call stub; `ntc_irqv` = `ntc_isl_tick`, the routine the interrupt calls.
8. **The interrupt handler** (cpc, cpcmin; only when normal mode needs it):
   `ntc_plat_irqon` keeps the 3 bytes at `#0038` and puts `jp ntc_irq` there. cpcfw instead
   sets a firmware fast ticker event (block at `#A5F0`).
9. **`ld sp, main_thread : ret`** - the thread starts. Its first words are usually
   `kw_scrinit` (cpc, cpcmin: mode 1, ROMs off, clear screen; the first mode set copies the
   CPC's font from the lower ROM into `ntc_font`) and `kw_bssinit` (the arrays fit under the
   platform's top and below the real stack, and are cleared - else a message and End).

**The first Memory call** (not at start) probes the RAM expansion and builds the page tables
from `ntc_free` up.

---

## 5. Run time

### 5.1 Where SP is

| Running | SP |
|---|---|
| a keyword, a stub, the thread | the thread |
| a host call (firmware, BDOS), Memory, List, FileSystem, Graphics | the real stack (`ntc_csp`); the thread position kept in `ntc_ip` or the class's own word (`mem_sp`, `fs_sp`, `gfx_sp`) |
| the interrupt handler | the real stack in normal mode - interrupts only get in at safe points, which switch to it first |
| bank code run by `Memory.CallBank` | the bank's own stack, from `#FFFF` down, interrupts off |

### 5.2 Interrupts

The CPC gate array interrupts 300 times a second.

**Turbo mode:** interrupts are off. Nothing below runs. Interrupt classes wait.

**Normal mode:** interrupts are off inside keywords and let in at safe points (`ntc_xn`,
`kw_irq`, key and frame waits, text drawing on cpc / cpcmin between characters, Cls and
scroll).

**cpc, cpcmin - NTC's own handler** (`ntc_irq`, at `#0038`, interrupt mode 1):

1. `ex af, af'`, HL kept in RAM.
2. `ntc_ticks` + 1 (`Ticks`).
3. An `Interrupt` hook is marked pending (`ntc_hookpend`).
4. Interrupt classes: `call ntc_irqv` - `ntc_isl_tick` counts every slot down (a `Frame` slot
   watches the vertical sync), marks the due ones; when no fixed slot fell due, one shared
   slot gets a turn (by weight).
5. Registers back, `ei`, `ret`.

With `Option Library ROM` the handler (it runs from RAM) puts the upper ROM on and the main
ROM of the set in for step 4, then the ROM state that was there back.

**zxn - NTC's own handler** (`ntc_irq`, at `#0038`, IM 1): the same steps, but the interrupt is
the Next's line interrupt (the ULA's frame interrupt is off): each one sets the next 52 raster
lines on (NextReg `#22` / `#23`), 6 a frame of 312 lines, 300 a second - as the CPC's. The one at
line 0 is a frame's first (`ntc_zxvs`: a `Frame` slot counts it).

**cpcfw - the firmware's handler**: NTC leaves `#0038` alone (the lower ROM has its own
`#0038`, used whenever the lower ROM is on). A fast ticker event (asynchronous, not express)
calls `ntc_fwevt` 300 times a second through KL FAR ICALL, which does steps 2-4. With
`Option Library ROM` the event's far address is the main ROM, so the firmware selects it for
the call.

**cpcmin during a file call:** the firmware's 3 bytes go back at `#0038` and its interrupts
run (AMSDOS times the drive motor with them); afterwards NTC's handler, mode, ROMs and screen
start are put back (`fs_fwon` / `fs_fwoff`).

**Nothing heavy runs inside the interrupt.** The handler only counts and marks. The marked
work runs at the next safe point, in the thread:

- an `Interrupt` hook: its Sub is called from the safe point (`ntc_xnh`);
- an interrupt class: its `Tick` is called the same way, unless it is still running.

A `Tick` is ordinary BASIC and can do anything. Its temporaries are above every other
procedure's, so it can't overwrite the code it interrupted.

### 5.3 Memory: the window, pages and banks

`Option Memory CPCExpansion` (the default on the CPC):

- **Page 1** is main RAM `#4000-#7FFF`; **pages 2 on** are the expansion's 64K banks, 4 pages
  each, probed by the first call (up to 4MB: 257 pages).
- A page is switched into the window with the gate array (`#7FC4`-style settings, the port's
  high byte `#7F`-`#78` picking the 512K block). The setting now is kept in `ntc_rampt`,
  written before the port, so an interrupt handler can always put the right page back.
- Page types: C code (overlay classes load here), D the heap (`Alloc` / `Free`), I, U the
  program's own, B a whole bank.
- **Whole banks:** `CallBank` runs code with the whole 64K being one bank (RAM setting C2):
  a 16 byte switch is copied into the bank at the same address it has in the program, so
  after the `out` the next byte comes from the bank's copy. Interrupts and both ROMs are off
  meanwhile; everything is put back after.

`Option Memory Small` (the default on cpm and test): no paging, one heap over free main RAM.

### 5.4 Overlay classes and pages

An overlay class's procedures (or a page's classes) live in a file that loads into the
`#4000` window: a C page with CPCExpansion (switched in when called), or the single overlay
area with Small / CP/M. Call stubs in the main program switch the page in, keep the page that
was there and switch it back on return. Each page file starts with the program's build stamp,
checked after loading.

### 5.5 Files and the ROMDISC

FileSystem's methods run on the real stack. cpcfw and cpcmin reach AMSDOS through the firmware
(cpcmin hands the machine back to the firmware for each call). Volume R is the ROMDISC: read-only
files in ROMs (`NTCDISC.ROM` ...). It isn't a disc driver: when the volume is R, a method goes
to the ROMDISC's routines (`rd_*`, section `ntc_romdisc`) instead of AMSDOS's. Those routines
select the ROMDISC's ROM for a moment and copy from it, so they run from RAM - in a `Library:
ROM` program they are part of the program, not the keyword ROM. On cpc (no firmware) the
ROMDISC is the only volume.

### 5.6 End

`End` (or the last line) is `kw_stop`:

1. (`Option PressAnyKeyOnEnd`: the message, then a key.)
2. `ntc_plat_exit`: main RAM back in the window (`#7FC0`), NTC's interrupt handler out
   (`#0038`'s 3 bytes back) or the fast ticker event removed (cpcfw), the upper ROM back on
   if the screen was set up.
3. SP = `ntc_csp`, `ei`, `ret` - back to the caller (with `Option Library ROM` through
   `ntc_rj_exit`: the caller's ROM selection back). A program started with `RUN"` from AMSDOS
   returns into a reset.

zxn: `ntc_plat_exit` is a soft reset (NextReg 2) - back to NextZXOS: a NEX file has no caller.

---

## 6. The keyword ROMs (`Option Library ROM`)

### 6.1 What a ROM holds

Each CPC platform has its own ROM set: `NTCCPC.ROM` (cpc), `NTCMIN.ROM` (cpcmin), `NTCFW.ROM`
(cpcfw), each a 16K background ROM with an AMSDOS header (16512 bytes). All of them can be
fitted at once.

```
#C000  background ROM header: type 1, version, address of the names, jp ntc_rom_init
       names ("NTC CPCMIN" ...), then NTC's block:
         "NTC", 2, platform, 0
         set stamp, place in the set (0 = main), ROMs in the set
         ntc_rom_patch, ntc_rom_index, NTC_ROM_N          (main ROM only)
       ntc_rom_init: scf / ret                            (claims no RAM)
       ntc_rom_patch                                      (main ROM only)
       ntc_rom_index: one word per routine number         (main ROM only)
       the library's code: every keyword, both modes, the platform layer, the classes
       the RAM image: starting variables + RAM code, copied to #8800 (main ROM only)
       padding to 16K
```

Not in the ROMs (a ROM program carries them itself, `@ramonly`): Graphics (so other graphics
classes can sit beside it), the ROMDISC's routines (they switch the ROM away) and cpcmin's
sequential-file code (no room).

### 6.2 The registry

`src/asm/ntc_rom_<platform>.txt` is permanent and append-only:

- each routine a program may name has a **number** that never changes;
- each exported variable has a **fixed address**, each constant a fixed value;
- a routine that goes is marked `gone`; its number is never reused.

A new ROM may move every routine and rewrite anything inside; programs built before still
work, because they only know numbers.

### 6.3 The program's side

In place of the library, the program has:

- a **jump block**: `name: jp <number>` for each library routine it names;
- `equ`s for the ROM variables and constants it names (their registry addresses);
- the start code that finds the set and calls the main ROM's patcher with HL = the jump
  block, BC = its entries, A = the main ROM's slot, DE = the slots of every ROM in the set.

The patcher copies the RAM image to `#8800`, clears `#9400` up, records the slots, and
replaces each number in the jump block with the routine's address. A keyword call then costs
one `jp` more (10 T states).

### 6.4 ROM sets: more than one ROM

When a platform's library doesn't fit 16K, it is built as a set: the main ROM plus
`NAME2.ROM`, `NAME3.ROM` ... from one build, found by the set's stamp in any slots.

- **What moves out:** only sections marked `@far` - real stack code (Memory, List and their
  helpers). Sections that call each other a lot move together. Keywords, the platform layer,
  the interrupt code and everything a keyword reaches directly stay in the main ROM, which is
  selected whenever the thread runs.
- **Crossing ROMs** goes through RAM, which is in sight whichever ROM is selected:
  - each routine in another ROM has a 10 byte stub `xc_<name>` in the ROM's RAM image;
  - the stub jumps to `ntc_rx_c<rom>`, which keeps the ROM now in on the stack, selects the
    other ROM (`ntc_rx_sel`), calls the routine, selects the first ROM again and returns -
    registers and flags pass both ways (about 200 T states);
  - `ntc_rx_sel`: cpc / cpcmin write the slot to `#DFxx` (after writing `ntc_rx_cur`, which
    the interrupt handler reads); cpcfw calls KL ROM SELECT, so the firmware's own record of
    the ROM in - which its events put back - stays right.
- **Programs don't change:** the patcher points a far routine's jump block entry at its stub.
  A program built against a one-ROM set runs with a four-ROM set of a later build.

### 6.5 The ROM's RAM in a set

```
#8800  starting variables of the library
       ntc_rx_cur      the ROM of the set selected now (#DF00 + slot)
       ntc_rx_bc       BC during a far call
       ntc_rx_s0..s7   each ROM's slot (#DF00 + slot), filled by the patcher
       code run from RAM: scroll / cls, the interrupt handler, the CallBank switch
       xc_<name> ...   far call stubs (only in a set of more than one ROM)
       ntc_rx_c0, ntc_rx_c1 ...   one far call routine per ROM
       ntc_rx_jt       jp <target>, written before each far call
       ntc_rx_sel      selects a ROM
#9400  the other variables (cleared), ntc_buf (2K)
#A5EF
```

These addresses change from build to build; programs never use them directly (only the
registry's exported variables keep fixed addresses).

---

## 7. The CPC platforms side by side

| | `cpc` | `cpcmin` | `cpcfw` |
|---|---|---|---|
| Firmware | none once started | kept alive, handed back for each file / ROM command call | used for text, keys, files, interrupts |
| Screen and text | drawn by NTC (CPC font copied from the lower ROM) | as cpc | the firmware's |
| Keys (`Inkey`) | NTC's matrix scan | as cpc | KM READ CHAR |
| `Keys` class | the matrix, straight from the hardware | as cpc | as cpc |
| Interrupts | NTC's handler at `#0038` | as cpc (the firmware's during file calls) | a firmware fast ticker event |
| Files | the ROMDISC (volume R) | AMSDOS through the firmware, and the ROMDISC | AMSDOS through the firmware, and the ROMDISC |
| Top of free RAM | `#A600` | `#A600` | `#A600` (`#A5F0` with the event) |
| Keyword ROM | NTCCPC.ROM | NTCMIN.ROM | NTCFW.ROM |

---

## 8. Where it is in the source

| Path | What |
|---|---|
| `src/js/ntc_parser.js` | the parser: records and the element table |
| `src/js/ntc_compiler.js` | the code generator, the library linker, the start code, `ntcRomAsm` (builds a ROM set), `ntcRomJumpBlock` (a ROM program's side) |
| `src/js/ntc_flavour_js.js`, `ntc_flavour_loco.js` | the JS and Locomotive BASIC flavours (to VB5 text) |
| `src/asm/ntc_lib.asm` | the keyword library: sections `;## name deps [@shared] [@far] [@romram] [@ramonly] [@data] [@unit] [@if:x]` |
| `src/asm/ntc_plat_*.asm` | the platform layers: screen, keys, interrupts, exit, files (`IF NTC_ROMLIB` marks what differs in a ROM) |
| `src/asm/ntc_rom_*.txt` | the ROM registries |
| `src/lib/<platform>/*.cls` | the platform classes: StdIO, System, FileSystem, Memory, List, Graphics, Keys |
| `src/build/rom/` | the built ROMs |
| `src/test/genrom.js` | builds a platform's ROM set and updates its registry |

Section header words: `@shared` - one copy for both modes (its SP loads are real stack
switches); `@far` - real stack code a ROM set may place in another ROM; `@romram` - runs from
RAM in a ROM; `@ramonly` - not in the ROM, a ROM program carries it; `@if:x` - only when
`#Const x` is set (Option Memory's scheme). `@data` - variables (one copy for both modes), and `@unit` - a small
routine: neither needs to be named in any header - a section is linked when a linked
section's code names one of its labels (the compiler scans each linked section for them), so
a program gets only the variables and routines it touches. The core scratch (`ntc_data`:
`ntc_next`, `ntc_csp`, `ntc_ip`, with `ntc_d_nmode`) is always linked; Input's buffer, number
printing, division, the Interrupt hook ... are `@data` sections (`ntc_d_*`), and each
platform's Backspace, Cls, Mode and Locate are `@unit` sections apart from putc / newline. A
`@unit` that runs on into the next routine (no jump at its end) must stay one section with
it, and a `jr` can't cross from one section to another. The ROM builder keeps `@data`
sections that follow each other as one run, so their variables keep the addresses the
registry has (a section's first, unlabelled byte - a capacity - goes with the variable after
it).
