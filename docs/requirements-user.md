# NTC BASIC - user requirements

What a programmer can expect of NTC BASIC on each platform, written after the fact from the code
(src/lib, src/asm/ntc_plat_*.asm, test/gen.js), 2026-11-01. The user guide (userguide.md) and the
language reference (NTC.md) say how; this says what is there. requirements.md is what you need to
run NTC. Components are numbered in components.md; bugs against these in buglist.md.

## 1. The language (every platform)

- A VB-shaped BASIC: Option Explicit, Dim with types (Byte, Integer, Long, String with Max, arrays
  of 1 or 2 dimensions as parameters), Sub / Function with ByVal, classes (.cls: Public / Private,
  one instance), Select Case, Do / Loop, For / Next, #If / #Const, #asm blocks.
- Compiled to native threaded code (NTC): the thread of keyword addresses, SP as the thread pointer
  (NTC.md: "#asm and the stack").
- Integers are 16-bit, Long 32-bit; Float and Fixed are library classes (22) on every Z80 platform,
  joined when used, not a type.
- A program's memory: pages (16K) and overlays by Option; the library ROM on the CPC platforms.
- Not there (52, by design or future): ReDim from variables, overflow checks, 3+ dimension array
  parameters, Format$ patterns, strings over 255.

## 2. The platforms and their classes

A platform's classes are its own lib/<platform>/*.cls plus its base's (cpc9990 and cpccard on cpc,
msx9990 and msxcard on msx, cyborgos and msxdos on cpm, cyborgoshh on cyborgos) plus lib/z80 (Float,
Fixed) on every Z80 platform. x = there, b = from the base, - = not there.

```
   platform    System StdIO FileSys Memory Keys List Graphics VDP V9990 Float/Fixed  own
   cpc           x      x     x       x      x    x     x       x    x      x
   cpcfw         x      x     x       x      x    x     x       x    x      x
   cpcmin        x      x     x       x      x    x     x       x    x      x
   cpc9990       b      x     b       b      b    b     b       b    b      x
   cpccard       b      x     b       b      b    b     b       b    b      x
   cpm           x      x     x       x      -    x     x       -    -      x
   cyborgos      x      b     b       b      -    b     b       -    -      x       CybSys
   cyborgoshh    b      b     b       b      -    b     b       -    -      x       (cyborgos's)
   msxdos        b      b     b       x      -    b     b       -    -      x
   msx           x      x     x       x      x    x     -       x    x      x
   msxcard       b      b     b       b      b    b     -       x    b      x
   msx9990       b      b     b       b      b    b     -       b    b      x
   zxn           x      x     x       x      x    x     x       -    -      x
   sc3000        x      x     x       x      x    x     -       x    -      x
   baremetal     x      x     x       x      -    x     -       -    -      x
   test          x      x     x       x      -    x     -       -    -      x
   colecovision  (its own platform file; classes as sc3000's where they apply)
   md            x      x     -       -      -    -     -       -    -      -       Pad, Psg, Vdp
   m65           x      x     -       -      -    -     -       -    -      -       Joy, Sid, Vic
```

The cyborgos target and the Pi (2026-11-02): a program built for cyborgos runs in any CyborgOS slot
- a CPC, a Next, an MSX, a vCPC on a PC, in a cloud, or on a CPC-CPLink's Pi (where it runs at an
emulated Z80's hundreds of MHz with 4 MB of banks, the CPC its keys, discs and screen). The Pi's
services (the store, Float on the host, Audio, Math, the VDP devices) are reached the same way
wherever the slot is; which are there is a run-time fact the program asks (as it asks for the
network): a Pi Zero (the Next's accelerator) and a cloud vCPC have no HDMI, so no VDP device, and
still have the fast CPU, the gigabytes, the store and the floats. No separate target for it.
cyborgoshh (the Headless Horseman) stays as the name for a slot of a headless CyborgOS.

Known gaps a programmer meets (buglist 15-24): Keys on msxdos, cpm, baremetal, test and cyborgos
(no key states there: read the hardware yourself, as CyborgOS's MSX does); Graphics on the MSX
platforms (VDP instead); VDP / V9990 on the Next.

## 3. What the compiler promises

- The same source builds for every platform it names in #If; a class that a platform lacks is a
  compile error naming it.
- A compiler change that is not meant to alter output alters none: tools/ntccheck/compare.js
  rebuilds every program in the set and reports any byte that differs (39).
- Warnings, not errors, for what still builds: a push / pop on the thread in #asm, Option Reserve
  over the font copy on the CPC, RomEnable off its platforms.
- Error messages name the file and line; "#asm: not found: {x}" and the like name the thing.

## 4. The IDE (6, 7)

- Runs in a browser with nothing installed; projects, modules and classes; the forms designer for
  the JS flavour; a compile to sjasmplus source; the hosted copy is the same code.
- ES5 JavaScript throughout, so it runs where jQuery runs.

## 5. The flavours (5)

- Locomotive BASIC (line numbers, the CPC's firmware), JS and PHP: the same compiler core, a
  different front; each with its own tests in regress.sh.

## 6. The tests a user can run (30-38)

- test/cli.js compiles one program; test/regress.sh runs the Z80 regression (test, cpc, cpcfw,
  cpcmin, cpm, zxn and three msxdos checks); m65regress.sh and mdregress.sh their machines; the
  Float tests in test/float. What regress.sh leaves out: sc3000, msx cartridge, baremetal,
  cyborgos, colecovision (buglist 34).

## 7. Not there, so nobody looks for it

- No floating-point type (Float is a class); no sound class yet (48); no ZX Spectrum 48K / 128K
  target (49); no file devices as classes (50); no text buffer class (51); no esxDOS in the Next
  harness (32).
