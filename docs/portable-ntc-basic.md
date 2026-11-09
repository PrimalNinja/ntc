# Writing portable software with NTC BASIC

(c) 2026 Cyborg Unicorn Pty Ltd

How to write an NTC BASIC program once and build it for the ZX Spectrum Next, the Amstrad CPC,
the MSX, CyborgOS (on all of them and the vCPC) and, to a degree, CP/M, with as little changed
as possible. Written against NTC 20261105-11. The
user guide (docs/userguide.md) has the full detail of every option and class named here.

## 1. The shared memory map

NTC's memory map is designed to be the same on the Amstrad CPC, the ZX Spectrum Next and the
MSX, and on CP/M to a degree. Lay a program out to this map and it lands in the same places on
all of them.

The vCPC (Virtual CPC) boots straight into CyborgOS. So a program for it is a CyborgOS target
(`cyborgos`), running in a slot under the second memory map below, not a native one. Its own
C0, the window and its 64 banks of 64K are the host program's, not the program's.

| Range | What it is, on every machine |
|---|---|
| `#0000-#003F` | restart vectors; `#0038` is the interrupt entry. Not yours |
| org up to `#3FFF` | the main program: code, threads, stubs, library, variables, strings |
| `#4000-#7FFF` | the window: one 16K page at a time. Kept free of the main program |
| `#8000` up to the platform's top | the rest of the main program, its arrays, the Memory class's tables |
| the top up to `#BFFF` | the system's: stack, DOS / firmware RAM. Not yours |
| `#C000-#FFFF` | the screen or the system. Not yours |

What differs per machine:

| | CPC | Next | MSX (MSX-DOS 2) | CP/M |
|---|---|---|---|---|
| Org | `#0040` | `#0040` | `#0100` | `#0100` |
| Window switched by | the gate array (`#7Fxx`) | MMU slots 2-3 | the mapper (`PUT_P1`) | none: one overlay area, loaded from files |
| Pages are | files, loaded on first call | `Loaded n` banks in the NEX file | the mapper's segments | one overlay class at a time |
| Top of the program | `#A600` (cpc, cpcmin, cpcfw) | `#BA00` (FileSystem's DOS area, then the stack) | the real stack, below `#C000` | the BDOS |
| `#C000-#FFFF` | the screen | bank 5: the ULA screen, the tilemap | the interrupt stub, MSX-DOS | the BDOS / BIOS |

So, to stay portable:

- **The main program has to fit below the lowest top of the machines it's for.** With the CPC
  on the list, that's `#A600`, even though the Next allows up to `#BA00`.
- **The window is for pages only.** Keep the main program out of it: `Option Memory Paged
  &H4000, &H4000` does
  that.
- **Nothing of yours below the org or from the top up.** That's the system's, and the screen's
  on most of them.
- **Reach the screen through classes, never a fixed address.** The CPC's screen and the Next's
  bank 5 are both at `#C000`, but they hold different things.
- **The code that switches pages lives outside the window.** NTC's stubs already do that. It's
  the reason a hand-written switch inside a page goes wrong.
- **CP/M uses overlays.** It has one overlay area at `#4000`, loaded from files, and no RAM pages
  for now (page support may be added later). MSX-DOS 2, which is CP/M underneath, has its
  mapper's pages. A call between two overlay classes loads from disc each way, so design each
  one to mostly call itself and main.

### The cartridge machines: Sega SC-3000 and ColecoVision

They're also supported and almost the same as the others. The difference is that the program is
a cartridge ROM with very little RAM, usually one block:

| | Sega SC-3000 (`sc3000`) | ColecoVision (`colecovision`) |
|---|---|---|
| The program | a ROM at `#0000`: 16K, 32K or 48K | a ROM at `#8000`: 8K - 32K |
| RAM | 2K, `#C000-#C7FF`: the variables, the arrays, the stack | 1K, `#6000-#63FF`: the same |
| Mode | normal or turbo | `Option Turbo` only: the Z80's INT isn't connected, and the VDP's frame NMI would push on the thread, so NTC keeps the NMI off and `Frame` polls the VDP's status |
| Paging | coming soon | coming soon |

- Code and constant data are in the ROM; only the variables need RAM. So keep strings,
  arrays and buffers small, and read-only tables in ROM.
- The same game code carries over if it's already written against classes: here the graphics
  are the TMS9918 (hwlib's `Tms9918.cls`).
- When paging comes, the page lines and the rules above will apply to them as well.

### The second memory map: a whole 64K (CyborgOS)

NTC BASIC has a second map, used by CyborgOS (the `cyborgos` platform: a CP/M 2.2 slot):

- The program has almost the full 64K to itself, about 55K or more, as **one single block**.
- It runs in its own 64K at the CPC's RAM config `C2`: an expansion block's banks, the whole
  64K switched at once.
- The kernel (the hypervisor) sits at `C0`, the base 64K.
- The program can be moved off `C2`, and the hypervisor can take `C0` and `C2` both. The program
  still gets a full 55K+ single block.

What that means:

- **The block is one piece,** not built round a `#4000-#7FFF` window. You can still page, in a
  controlled way: with interrupts disabled while the page is in.
- **Coming:** CyborgOS will give each concurrent 64K program up to 512K of its own to page.
- **On a 128K machine** (a 6128) it's a cut-down version, there only to give the full 64K block
  as an option.
- **The hardware is the hypervisor's.** A slot reaches the screen, the clock, ports and drives
  through its services (`CybSys`), not directly.
- **The same source can build for both maps.** Keep the machine-specific parts in classes, with
  `#If NTC_CYBORGOS` for the slot's.

## 2. The rules

These rules are for portability. You can do everything by hand (your own bank switching, your
own hardware code, your own layout) if you don't care about portability.

And if you follow them, a program is mostly BASIC and classes tagged into pages, overlays or
main. Moving it from one model to the other (pages to overlays, the first map to a CyborgOS
slot) is then mostly re-tagging classes and moving things around. It's a little stuffing
around, but not hard.

### Rule 1: a class keeps code together, and a class is what gets banked

A class is a logical container. You can make classes two ways, and mix them:

- **As components:** reusable parts, such as `List`, `Memory`, `NTC3D`, a sound driver or a
  sprite engine. A component can go in main RAM, in a page or in an overlay. Where it goes is
  decided by the `Option Page` lines, not by the class.
- **As banks:** classes named for where they go, such as `Page1`, `Page2`, `Page3`, or
  `Level1`, `Level2`, `Title`. Each one holds everything for that part. Use whatever suits; this
  way is fine when you don't care about reusing the class.

Either way:

- Put a level, a screen, a driver or a game part in a class along with what only it uses.
- To get code out of main RAM, put the class in a page or an overlay. Don't inline or reshuffle
  code to save main RAM.
- A small helper that several pages use (maths, text, rules) gets listed in each of those pages.
  The compiler copies it in, so each page calls its own copy with no page switch.
- A class every page and main use goes in no page. It stays in main RAM.

### Rule 2: choose pages or overlays, and declare them in one place

- **Pages**, when the machine has banked memory: each page stays in RAM and is switched into the
  window when called.
- **Overlays**, when you want the page to be REPLACED: one at a time in the window, loaded over
  the one before (`Option Class Overlay`, or `Option Memory Small`). That's what CP/M has.
- **Mix them.** Start the pages from 1 or higher, and use page 0 (the window's own 16K) for
  overlays.
- **Interrupt classes** (`Option Class Interrupt`) can be in a page: each `Tick` switches the
  page in and back. They can't be in an overlay, because a Tick would load from disc. A program
  can still mix interrupt-driven pages with overlays.

Put the page lines in the main file:

```
Option Memory Paged    &H4000, &H4000        ' the window: pages swap in here
Option Memory Safe     &H1000, &H0800        ' always mapped: the banking code goes here
Option Safe "BANK" = Bank                    ' the classes that must be in Safe memory
Option Page Title  = Title                   ' a page: these classes, built together
Option Page Level1 = Level1, Maths, Stars
Option Page Level2 = Level2, Maths, Stars
```

**The memory map is one directive: `Option Memory` *kind* *start*`,` *size* [`,` *start*`,`
*size*] ...** One kind per line, as many lines as you need:

| Kind | Means |
|---|---|
| `Paged` | the window where pages and overlays swap in at run time; the program is built round it |
| `Reserved` | the program keeps out and is built round it: a screen, a load area, firmware RAM, hardware |
| `Safe` | always-mapped RAM for the safe classes: the code that must stay put while a bank is in the window |
| `Available` | usable RAM, the default; only stated to write the whole map out |

This lets you map memory in as fine detail as you want. Each kind can have as many ranges as
you need, so the map can say exactly what every stretch is for. For example:

```
Option Memory Safe      &H0100, &H0F00        ' the banking code, low and always mapped
Option Memory Available &H1000, &H3000        ' the program
Option Memory Paged     &H4000, &H4000        ' the window
Option Memory Available &H8000, &H2000        ' more program
Option Memory Reserved  &HA000, &H0800        ' a music player loaded here
Option Memory Reserved  &HA800, &H0800        ' a level's data loaded from disc
```

The program flows round everything that isn't `Available`.

**The point: waste no memory, but keep the code that must stay mapped out from under the pages.**

- Most code doesn't care where it sits. Only some code must never be under a banked page:
  - the code that switches banks (it would vanish mid-switch);
  - interrupt handlers;
  - anything a page calls back into.
- That code, and only that code, goes in `Safe` with `Option Safe "NAME" = Class, ...`.
- Everything else is free to go anywhere, so no 16K is thrown away just to be careful.
- Don't put whole programs in `Safe`, and don't reserve big ranges to be safe. Reserve what is
  really owned by something else, and mark safe only what must be.

In 20261105-11 a `Paged` range is still built round as a gap. Letting non-safe code be built
under the window as well is the next step, and it's what gets the 16K back.

- **The old forms are deprecated:** `Option Reserve`, `Option Safe Areas`, the window form
  `Option Page <startbank>, <addr>, <size>`, `Option HighCode` and `Option Place`. They will be
  errors by default, unless the program says `Option Deprecated`. Write new code with
  `Option Memory` only.
- `Option Memory Small` / `CPCExpansion` *n* (the heap scheme) is a different form of the same
  word, and stays.
- **The page start.** Paging can start at page 0, where the window's own 16K is page 0 and still
  used: take that when the program needs that 16K. Or it can start at 1 and up, where that 16K
  stays fixed: on the CPC you can then double buffer the screen between `#4000-#7FFF` and
  `#C000-#FFFF`, or use it for overlays. The page start was given by the old window form;
  `Option Memory` doesn't say yet how to give it.
- **Memory something else owns: reserve it.** `Option Memory Reserved` keeps the program out of
  any range, and the program is built round it. That's how hardware that sits in memory fits in.
  For example, the CPC Plus's ASIC registers page in at `#4000-#7FFF`: keep that range for them,
  and choose the page start to suit.
- **Safe classes:**
  - `Option Safe "NAME" = Class, ...` names the classes whose code must live in `Safe` memory:
    the banking or slot-access code, which would vanish if it sat in the window mid-switch.
  - Their code is laid into the first `Safe` range, and the build stops if it doesn't fit.
  - A class is a page or safe, never both; the compiler refuses one in both.
- **Put things where you need them:**
  - buffers: `Option Buffer address [, size]` moves the library's buffer;
  - screens, level data, a loaded file: an `Option Memory Reserved` range;
  - third-party code (a player, a driver, a ROM's workspace): load it straight into a
    reserved range and call it there.
- A page holds at most 16K: code plus page variables. The compiler lists each page's size.

### Calls and where the code is

| Call | What happens |
|---|---|
| A class calls its own members, in a page | a local call in the page, not a far call |
| A class calls another class in the same page | a local call, no switch |
| A paged class calls a class in another page | through that member's own keyword stub, which switches the page in and back |
| Main calls a paged class | through the member's stub in main |
| Main calls a class copied into several pages | currently goes to the copy nearest `#C0`: the lowest page holding it |

A class ends up in several pages when those pages depend on it. Every copy shares the class's
ordinary variables, but each copy has its own `Private Paged` variables. So if main must always
reach one particular copy, list the class in that one page only.

Inline asm stays in its class: a paged class's asm is in the page, and an unpaged class's asm
is in main. That's what makes drivers possible. A driver class, with its BASIC, its asm and its
data, all goes in one page and runs there. The old bug moved paged asm into main memory, which
made driver code impossible to write.

### Rule 3: never switch banks yourself

- No NextReg `#50-#57` writes, no gate array `OUT &7Fxx`, no `PUT_P1` in your own code.
- Use the Memory class:

  | Method | Does |
  |---|---|
  | `AllocPage(type)` | a page of your own (`TypeUser` for your data) |
  | `SelectPage(page)` | puts a page in the window |
  | `Copy(src, dst, length)` | copies between far pointers (it switches the window itself) |
  | `ReadByte`, `WriteByte`, `ReadWord`, `WriteWord` | single values through far pointers |
  | `FreePage(page)` | gives a page back |

- A far pointer is a Long: the page in the high word, the address in the low word. Page 0 means
  plain memory, with no switching.

  ```
  ptr = CLng(page) * 65536 + Memory.WindowStart
  ```

- Write `Memory.WindowStart` and `Memory.WindowSize`, not `&H4000`.
- `Memory.Copy` goes through the library's 2K buffer. A program with no files can make it
  small with `Option Buffer Size 128`, which saves 2K of main RAM.

### Rule 4: data goes in pages too

- Put level data, graphics, music and tables in a page class with the code that uses them. For
  example, a `LevelData` class with the data and a `Load` that puts it where it belongs.
- Don't drop raw data into banks with build tricks. Examples are adding banks to `SAVENEX
  BANK`, or `MMU` / `ORG` in `#asm` to place data in a NEX bank. They only work on one machine,
  and the Memory class doesn't know the bank is taken. On the Next, its probe writes a marker
  into the first byte of every bank it doesn't know.
- `Option NexData` is Next-only. Use it only for data too big for pages, and only inside
  `#If NTC_ZXN`.

### Rule 5: the hardware lives in hardware classes

- Sprites, tiles, palettes, sound chips, screen layout and ports each get a class of their
  own: `Spr`, `Tiles`, `Sfx`, `Nx`.
- The game calls `Spr.Show`, `Tiles.Put`, `Sfx.Play`. It never writes a port.
- For another machine, write the same class with the same methods for that machine's hardware.
  The game code doesn't change.
- Pick the version per platform with `#If NTC_ZXN` / `#If NTC_CPC` / `#If NTC_MSX` in the
  class, or keep one file per platform and list the right one in the project.

### Rule 5a: graphics and sound through hwlib, and the coprocessor

The CPC, the Next and the vCPC can all have a Raspberry Pi coprocessor attached; a vCPC can
also use a PC. On the CPC, the Pi gives:

- the Next's graphics, emulated in full;
- V9990 and V9938 graphics;
- mp3 playback;
- a maths coprocessor;
- the 3D library.

So a game written for the Next's graphics can run on a CPC with a Pi.

Why these graphics: portability. The Pi gives the CPC the same graphics as real machines, so one
game's graphics code runs on all of them:

- **zxn:** the Next's graphics, so a Next game ports to the CPC.
- **v9938:** the MSX2's chip. A real V9938 card on a real CPC is being tested now.
- **v9990:** works on a real CPC, but the boards are as rare as hen's teeth. The Pi makes the
  chip available to everyone.

The Next's own Pi is a Pi Zero with no HDMI and no audio, so it offers only part of that: the
maths and the services, not the Pi's video or sound. On the Next, use its own hardware for
those (`Zxn.cls`, the Next's `Stream.cls`).

**hwlib** (`src/hwlib/lib`) gives every graphics chip the same core calls:

```
Init  Pattern n, addr  Put n, x, y, pattern  Hide n  Anim n, first, count, delay
Move n, dx, dy  Bounds x0, y0, x1, y1  Frame  X(n)  Y(n)  HitBox n, x, y, w, h  Hit(n, m)
```

| Library | Use it for |
|---|---|
| `Zxn.cls` | the Next's own 128 hardware sprites |
| `Pi.cls` | the Pi's VDP over the link. `Pi.Profile = "zxn"` gives the Next's graphics on a CPC, and also has v9990, v9938, md and pi720 / 1080 / 2160. Its layers: `Tiles`, `Tile`, `TileRow`, `Scroll`, `Layer2Tag` |
| `V9990.cls`, `V9938.cls`, `Tms9918.cls` | the MSX's chips and the CPC's V9990 boards |
| `Cpc.cls` | a CPC with no Pi: software sprites, double buffered at `#C000` / `#4000` |
| `Asic.cls` | the 6128 Plus / 464 Plus / GX4000's ASIC: 16 hardware sprites, 16 x 16, 15 colours of their own, over any screen mode. Its registers page in at `#4000-#7FFF`: the window (see below) |

- Write the game against the core calls. Pick the chip class per platform, by `#If` or by which
  file the project lists.
- **CPC with no Pi: compiled sprites in banks.**
  - Each sprite is compiled to code: the fastest Z80 that writes that sprite straight into screen
    memory, with no data to read and no mask loop.
  - The sprites go in pages. A sprite's page is switched in, then the sprite is called, and it
    draws.
  - A CPC has up to 4MB (1MB is common), so there's room for many sprites and their frames.
  - The Memory class's `TypeCode` pages are meant for these.
- **The vCPC has no real graphics of its own**, but it may gain all the Pi's emulated parts
  (the Next's graphics, V9990, V9938, mp3, the maths, 3D). It would then have the same graphics
  as a CPC with a Pi. Write for the hwlib calls and it carries over.
- **The vCPC's speed varies:** about 2GHz on a PC; on a Pi, somewhere between 4MHz and 2GHz.
  That's one more reason rule 9 says to time with `Frame` and `Ticks`, never loop counts.
- A chip's own extra calls (`Palette`, `Inks`, `Shades`, the Pi's layers) go in that platform's
  part of the game.
- **Music:** `Stream.cls` has the same four calls (`Open`, `Fill`, `Close`, `Playing`) on the
  Next's own DACs and on the Pi's audio service.
- **Assets on the Pi: install them, then load by tag.** The link to the Pi isn't fast, so a game
  doesn't send its graphics over it each run:
  - The game is installed on the Pi first. One of the Pi's services is a datastore, and the
    installer stores the assets in it under tags like `<gamename>/<sprites>`.
  - When the game runs, the CPC loads them by tag with small instructions that parallel the
    Next's: `Pi.PatternTag`, `Pi.TilesTag`, `Pi.Layer2Tag`.
  - A profile's `GRAPHICS/<PROFILE>/PATTERNS`, `TILES`, `LAYER2` and `PALETTE` load by
    themselves when the display opens.
  - So the CPC sends only short commands, and the Pi does the heavy lifting.
- **Maths and 3D:** Float's coprocessor op (answered by the vCPC today; by C0 on a CPC to come)
  and NTC3D. Use them instead of writing your own.

### Rule 6: use the functions NTC provides, when they are there

If NTC has a keyword, a library class or a method that does the job, use it. Don't write your
own, unless there's a good reason: it's measured too slow for the job, or it can't do what's
needed. The classes are:

- `Keys`:
  - key numbers are the CPC's on every platform;
  - `Down(key)` and `Joystick(n)` work on cpc, cpcmin, cpcfw, cpccard, cpc9990, zxn, msx,
    msxcard, msx9990 and sc3000.
- `Graphics`: the CPC's screen. On the Next it draws on Layer 2 in CPC mode 1 coordinates, so
  CPC drawing code carries over.
- `StdIO`: the console. A project's own `StdIO.cls` replaces the platform's.
- `System`: `Platform`, `CpuClock`, `FrameRate`, `HasScreen` and the rest. Ask it; don't
  assume.
- `FileSystem`, `Memory`, `List`: the same methods on every platform that has them.

### Rule 7: platform differences go in `#If` blocks, kept small

NTC defines `NTC` and `NTC_<platform>`: `NTC_ZXN`, `NTC_CPC`, `NTC_CPCFW`, `NTC_CPM`,
`NTC_MSX`, `NTC_MSXDOS`, `NTC_CYBORGOS` and the rest. The page lines are the usual case:

```
#If NTC_ZXN Then
Option Page DuelPg Loaded 21 = Battle, Fx      ' the Next: already in bank 41 from the NEX file
#Else
Option Page DuelPg = Battle, Fx                ' CPC and others: loaded from PROGRAM.00n on first call
#End If
```

The compiler reads `Option Page` lines after `#If`, so this works.

Conditional compilation works in both languages:

- **In NTC BASIC:** `#If` / `#ElseIf` / `#Else` / `#End If`. It works round anything, including
  whole `#asm` blocks, so each platform can have its own asm for the same Sub:

  ```
  Sub Plot()
  #If NTC_CPC Then
  #asm
      ; the CPC's way
  #endasm
  #Else
  #asm
      ; the others'
  #endasm
  #End If
  End Sub
  ```

- **In inline asm:** the assembler's own `IFDEF` / `IF` ... `ELSE` ... `ENDIF`, inside one
  `#asm` block:

  ```
      IFDEF NTC_ZXN
          call zxn_sel
      ELSE
          call mem_sel
      ENDIF
  ```

  NTC writes `DEFINE NTC_ZXN` (the Next) and `DEFINE NTC_MSXDOS` into the asm for `IFDEF`. It
  also writes `equ` values such as `NTC_ROMLIB` and `NTC_WINHOLE` for `IF`. For a platform with
  no `DEFINE`, use `#If` round the block.
- `cli.js --const=NAME` adds your own constant for `#If`, such as `#If DEMO Then`.

Keep `#If` to option lines and hardware classes. Game logic with `#If` all through it isn't portable; it's several
programs in one file.

### Rule 8: write it in NTC BASIC first; asm is for optimising

- Develop everything you can in NTC BASIC. Get it working that way first.
- Inline asm is an optimisation: a loop that's measured too slow, or hardware that BASIC
  can't reach. Per-platform asm is fine for that. Keep the BASIC version as the reference (for
  example under `#If`), so a new platform starts from working BASIC, not from someone else's
  asm.
- Use `{name}` for BASIC names, never the compiler's labels (`var_x`, `fn_x`).
- Follow the thread rules:
  - SP is the thread, so no `call` or `push` until you switch to the real stack:
    `ld ({saved}), sp` / `ld sp, (ntc_csp)` ... `ld sp, ({saved})`;
  - no `ei` (turbo mode runs with interrupts off the whole time).
- No hard-coded addresses in the window. Code and data in a page class's asm are in that page,
  at `#4000` up, and labels resolve there.

### Rule 9: don't assume the speed

- The CPC runs at 4MHz and the Next game builds at 28MHz.
- Time with `Frame`, `Ticks` and `System.FrameRate`, not loop counts.
- Interrupt classes (`Option Class Interrupt 50`) keep time the same everywhere, in normal mode.

### Rule 10: watch main RAM

- Check the program's end against the platform's top. Next: below `#BA00` (FileSystem's DOS
  area, then the stack). The compiler's layout list and `ntc_end` / `ntc_free` in the .sym say
  where it ends.
- Main RAM holds:
  - the classes in no page;
  - one entry stub for each paged procedure called from main or another page (calls inside a
    page stay in the page);
  - the library;
  - every variable.
- To free main RAM, move a class into a page.

## 3. From a game's point of view: the Pi, the network and AI

Which target gets what:

| | Native platforms (cpc, zxn, msx ...) | CyborgOS targets (a slot: `cyborgos`) |
|---|---|---|
| The Pi's services | yes | yes |
| The network | not yet: the drivers are inside CyborgOS (to do: make them classes) | yes |
| AI models | the model itself, yes: NTC's `lib/z80/Net.cls` runs the GRU (load a `.MDL`, feed, generate) | yes, plus the services: RAT, MODEL and MIND on ports |
| Memory | the first map: pages and overlays in the window | the second map: the slot's 64K, plus what CyborgOS lends it |

### 3.1 The Pi (native platforms and CyborgOS alike)

One link to the Pi carries many channels, each to a service. The link can be:
- the CPC-CPLink or CPLink2;
- a serial line (USIfAC II);
- the Next's UART to its Pi Zero;
- TCP, for tests.

A game can have several services open at once: the display, the music, the maths and the store.

| Service | What a game gets |
|---|---|
| store | tagged data kept on the Pi between boots: install the assets once, load them by tag |
| vdp | the Pi's HDMI as a video chip: the profiles v9938, v9990, zxn, md, pi720 / 1080 / 2160. The sprite table, moves, bounds, animation and collisions run on the Pi, plus a tile layer, Layer 2 and scroll. hwlib's `Pi.cls` drives it |
| audio | music by type, from a tag under `MUSIC/<type>/`: MP3, 8BIT, SID, VGM, FM, MOD, MIDI, GME, AY38912. Controls: PLAY, STOP, PAUSE, SEEK, VOL; events ENDED, POS |
| float, math | IEEE floats, whole arrays and matrix products (Float's coprocessor). `EVAL`, `BIG` numbers, and `XFORM` (3D points through a matrix, projected: the Z80 draws, the Pi does the sums) |
| disk | Pi volumes as drives with real random access |
| vdu | the Pi's HDMI as a full-HD virtual display |
| term, run | a shell on the Pi; a command run there with its output sent back |

- The link isn't fast. Bulk data goes into the store once, at install time; at run time the game
  sends short commands. The CPLink2's Pi ROM moves big answers at LDIR speed.
- The Next's Pi Zero has no HDMI and no audio, so vdp and audio aren't there on the Next.
- Not yet: `plugin` (code sent to the Pi to run as a real coprocessor), and RAT models and slots
  on the Pi.

### 3.2 The network (CyborgOS targets)

- CyborgOS drives the machine's wifi board, and the program never touches it, so the same
  program runs on every machine. The boards:
  - the CPC: an M4 (`NET M4`);
  - the Next: its ESP8266 (`NET ESP`);
  - the vCPC: the host's sockets;
  - the MSX: none yet.
- A program uses `Http.cls` with `CybSys.cls`:
  - `Http.Get(url, buffer, max)`;
  - `Http.Post(url, body, n, buffer, max)`;
  - for streaming: `Http.Start` / `More` / `Finish`.
  
  Under them are BDOS 131 ops 20-27, the sockets.
- **Ports: services in slots.**
  - A slot opens a port with `CybSys.PortOpen(name)`. Other slots call it with
    `CybSys.PortCall(name, message)` (128 characters).
  - The service side uses `PortGet` / `PortReply`.
  - A game's score table, its level server or its enemies' brain can each be a port.
- **Moving a running program:**
  - `RMOVE` / `RCOPY` send a running slot to another machine's `SLOTD`, and it carries on there.
  - A vCPC listens today; a CPC, Next or MSX can send but not yet receive.

### 3.3 AI models (CyborgOS targets)

- **RAT, the decision service, with its models.**
  - `MODEL` serves a model (`.MDL`) on a port, one slot each: up to 18 models with RAT and an
    application in 20 slots.
  - `RAT` decides. A game asks it something like `ORC attack flee:8 hide shout` and gets back a
    decision and its plan.
  - Models learn: likes move with praise and scolding, boredom, health.
  - `RATMODEL.TXT` on the disc says how a model is made.
  - Samples: RATS, PET (a Tamagotchi-style pet) and RATBOX (a swarm: one model, a copy of its
    weights for each rat).
- **GEN, MIND, GRU: the generative model.**
  - A ternary GRU (k=2: weights -4..+4, multiply-free on the Z80). It completes text rather than
    chatting. It's trained on a PC, and the Z80 gives byte-for-byte the same output.
  - `MIND` serves a model on a port, and `GRU` is its terminal. The model is a port: it can be
    kept, moved (`RMOVE`) or shared.
  - Models: `GEN.MDL` (NTC BASIC and Z80 asm) and `CYNTHIA.MDL` (chitchat).
  - Speed: about a second a character on a 4MHz CPC; about 100x faster on a vCPC.
- **Bigger models** grow over the store (512K a slot) and over more ports: sharded, or a
  mixture of experts behind a gate.
- For a game: enemies, pets and NPCs decide through RAT, and lines are written by a MIND. Each
  is a `PortCall` away. The game stays small, and the model's size is the server's business.

## 4. Checklist

- [ ] The memory map is `Option Memory` lines only (`Paged`, `Reserved`, `Safe`), with no
      deprecated forms and no `Option Deprecated`.
- [ ] Every page is declared with `Option Page` lines in the main file. `Loaded n` is inside
      `#If NTC_ZXN`.
- [ ] No NextReg `#50-#57`, gate array or mapper writes outside NTC's own library.
- [ ] Every other bank access goes through the Memory class, with far pointers and
      `Memory.WindowStart`.
- [ ] Data is in page classes, not placed in banks by the build.
- [ ] Every port write is in a hardware class, and the game only calls those classes' methods.
- [ ] It's written in NTC BASIC first; any `#asm` is an optimisation of working BASIC.
- [ ] NTC's own keywords and classes (`Keys`, `System`, `StdIO`, `Graphics`, `FileSystem`,
      `Memory`, `List`) are used wherever they do the job, unless there's a stated reason not to.
- [ ] `#If NTC_<platform>` appears only in option lines and hardware classes.
- [ ] Timing comes from `Frame` / `Ticks` / `System`, not from the CPU's speed.
- [ ] The main program ends below the lowest top of its targets (`#A600` with the CPC on the list).
- [ ] Nothing of the program's own is below the org or from the top up; the screen is reached
      through classes.
- [ ] Pages mostly call themselves and main, so CP/M's one overlay area doesn't thrash.

## 5. Where NTC is now (20261105-11)

- **`Option Memory` and `Option Safe` are new** (20261105-11):
  - Safe code goes in the first `Safe` range only; spilling into the second and later ranges
    isn't done yet.
  - `Option HighCode`'s layout, which CyborgOS C0 uses, doesn't place safe code yet.
  - The old forms still compile in this build; making them errors without `Option Deprecated`,
    and moving the programs and C0 over, comes next.
- **`Loaded` pages are Next only.** On the other platforms a page is a file (`PROGRAM.001` ...)
  loaded on first call, so the page lines need the `#If` in rule 7.
- **Bug, reported, still in 20261105-11:** a parameterless Sub whose whole body is `#asm`, in a
  page class, becomes an asm keyword. Main or another page calls it with a bare `dw fn_...` and no page stub, so
  its page is never switched in. A Sub with a parameter, or with a BASIC line, gets its stub
  and works. Until it's fixed, call such a Sub only from inside its own page.
- **Out of date:** the user guide's overlay section still says "Procedures whose body is only
  `#asm` stay in the main program". That was the old bug. Inline asm now stays in its class,
  so a paged class's asm is in its page (see "Calls and where the code is" in rule 2).
- **Pages and the probe:** the Memory class's probe writes a marker into each bank's first byte.
  Pages keep their build stamp there, so they are safe. Raw data placed in a bank by the build
  is not.

## 6. The targets, and what each is best for

| Target | Best for |
|---|---|
| `cpc` | full control of the CPC: no firmware, every byte from `#0040` to the stack yours. An overscan game, say, with no disc access beyond the load |
| `cpcmin` | the CPC with the least firmware that keeps disc access: own screen, keys and interrupts; the firmware only for discs, tape and ROMs |
| `cpcfw` | the CPC with the full firmware: AMSDOS, RSXs, every ROM working |
| `cpc9990`, `cpccard` | the CPC with a V9990 / V9938 card as the console. These should be class inclusions (hwlib's `V9990.cls`, `V9938.cls`), not targets of their own |
| `zxn` | the Next: own screen, keys and interrupts, with NextZXOS's esxDOS kept for files (`FileSystem` calls it with `rst 8`, ROM 3 paged in, through a trampoline at `#BA00`). So today it's the `cpcmin` equivalent. Files need the NEX started by NextZXOS (the browser, `.nexload`, an autoexec), not loaded as a snapshot |
| `zxn` with no DOS | not a target of its own: leave the `FileSystem` class out, and nothing calls the DOS. One gap today: the compiler keeps `#BA00-#BDFF` (the class's DOS area) out of the program even when the class isn't used, so a no-files program loses that 1K |
| `msx` | an MSX cartridge. Close to `cpc`, but the BIOS stays in page 0 (its keys and interrupt) |
| `msxdos` | MSX-DOS 2 / Nextor: the DOS console and files, plus the mapper's pages. Close to `cpcfw` |
| `msx9990`, `msxcard` | the MSX with a V9990 / V9938 card as the console. These should also be class inclusions |
| `cpm` | plain CP/M 2.2 / 3: nothing special, any CP/M machine |
| `cyborgos` | CP/M with bells and whistles: a CyborgOS slot, with the hypervisor's services, the network, ports, the store and AI models |
| `cyborgoshh` | the same, for a headless CyborgOS (a vCPC with no screen of its own) |
| `sc3000`, `colecovision` | the cartridge machines, so far the `cpc` equivalents: full control, small RAM |
| `md`, `m65` | the Mega Drive (68000) and MEGA65 (45GS02): `cpc` equivalents for their own, unrelated targets |
| `baremetal` | a machine NTC doesn't know: do everything from scratch (fill in the platform routines and classes) |
| `test` | NTC's own test harness |

So the pattern is three levels per machine:
- **full control** (`cpc`, the cartridges; `zxn` without `FileSystem`);
- **minimal OS kept for files** (`cpcmin`, `zxn` with `FileSystem`);
- **the full OS** (`cpcfw`, `msxdos`, `cpm`, `cyborgos`).

Extra video chips should be classes added to a project, not targets.

Other machines are possible too. For now they come down to `baremetal`: you supply the platform
routines (a character out, a key in, the clock) and the platform classes, until more useful
support is added for them.

## 7. Worked example: CARD CLASH on the Next

**Main RAM** holds:
- the main loop and the globals;
- `Board`, `Spr`, `Tiles`, `Sfx`, `Nx`, `ArtData` (used by everything);
- `GfxData` (palettes, and the first 80 sprite patterns from bank 5).

**The pages:**

| Page | Classes |
|---|---|
| SplashPg | Splash |
| DuelPg | Battle, Fx, Geo, Rules |
| PaintPg | Paint, Words, Geo, Rules |
| AiPg | Ai, Rules |
| ScreenPg | Screens, Words, Geo, Rules |
| ArtPg | GfxArt: the rest of the sprite patterns and the tiles, with its own `Upload` |

Geo, Rules and Words are small helpers copied into each page that uses them.

**Next-specific parts** (they will also work on a CPC with a Pi, in a way: the Pi emulates the
Next's graphics):
- the hardware classes (`Nx`, `Spr`, `Tiles`, `Sfx`, `GfxData`). These were hand-written
  rather than built on hwlib, so by rule 5a, `Spr` and `Tiles` should become hwlib `Zxn.cls`
  (or `Pi.cls` with the zxn profile on a CPC). On a CPC, the art would be installed in the Pi's
  datastore under `CLASH/...` tags and loaded by tag, instead of being in the program;
- the `Loaded n` on the page lines;
- the first 80 patterns, which the NEX file puts straight into bank 5. That one should move
  into pages as well.

A CPC version would keep `Main.bas`, the pages' classes and the game logic as they are. It
would:
- swap the hardware classes for `Pi.cls` with the zxn profile, or for `Cpc.cls` with compiled
  sprites when there's no Pi;
- load the art from the Pi's datastore by tag;
- drop `Loaded n` through `#If`.

## 8. To do

- **Add the missing groups, and remove the ones that should just be class additions.**
  - Missing: the levels each machine lacks. For example:
    - the Next: `zxn` without the DOS area kept (today `#BA00-#BDFF` stays out even with no
      `FileSystem`);
    - the MSX: a minimal-OS level between `msx` and `msxdos`.
  - Class additions instead of targets:
    - `cpc9990`, `cpccard`, `msx9990`, `msxcard`;
    - each is its base target plus `V9990.cls` / `V9938.cls` and `StdIO_V9990.cls` /
      `StdIO_V9938.cls` as `StdIO.cls`;
    - check that the hwlib consoles match the built-in ones first.
- **The network as a class inclusion, for native targets too.** Today the drivers are inside
  CyborgOS's hypervisor: the M4 in `cyborgosc2/Hyp.cls`, the Next's ESP8266 in
  `cyborgos/Hyp.cls`. `Http.cls` sits on `CybSys` (BDOS 131 ops 20-27). There's no reason a
  native program can't have them:
  - a minimal networking class per board (M4 on the CPC, the ESP on the Next, later the MSX's),
    each with the same few calls. The board does the TCP/IP itself; the class only asks it
    for a connection, sends, receives and closes;
  - `Http.cls` over that class on a native target, and over `CybSys` in a CyborgOS slot,
    with the same calls either way;
  - CyborgOS then uses the same classes in C0.
