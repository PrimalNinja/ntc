# NTC - known bugs

Things that are wrong, by component - the numbers are [components.md](components.md)'s, the same
as the todo's (todo.md: work to do; this: things that are wrong). Newest first in each. Each bug
carries its state: REPORTED (seen, not yet confirmed or traced), CONFIRMED (reproduced or found in
the code), FIXED (moving to done.md). Started 2026-11-01: four entries moved from the todo, then
an analysis of every component (the other session's; ANALYSIS.LOG has its method).

## 2 ntc_compiler.js - the compiler

- REPORTED 2026-11-01 A push or pop in an #asm block corrupts the thread: SP is the thread, so a push
  writes over the words before the block, and the block works once and breaks when that thread
  runs again (proven on the test platform: three calls in a loop printed garbage and hung). The
  compiler accepts it silently. It should refuse `push` / `pop` in an #asm block that is not a
  keyword block (a keyword block pops its own parameters, by design) and that does not switch SP
  first (`ld sp,`), or at least warn. Two CyborgOS crashes today came from this.
- REPORTED (moved from the todo, 2026-11-01) `CallAddr`: the arguments are not checked against the target's parameters (the
      compiler can't know it); recursion through `CallAddr` is not found either

## 9 A machine's own runtime parts (cpc, msx, nxt) - also 17

- CONFIRMED 2026-11-01 The CPC runtime's page count and its bank count disagree, silently. The RAM
  probe sets mem_banks (RamSize = (banks + 1) x 64); mem_count starts at 1 + 4 x banks and is then
  cut, a page at a time, until the page tables (3 bytes a page) fit between ntc_memtab and the
  platform's top (mem_tb_fit). A program built round the window with little room above it
  (CyborgOS's C0) ends with far fewer pages than banks - about 56 of 257 on a 4 MB CPC - while
  RamSize still says 4160K. Nothing reports the cut. Memory.RamSize should come from mem_count (or
  Pages() should be what MEM and RAM discs use), and the cut should be visible (a flag, or an
  Option that reserves table room). This is the CyborgOS "MEM map vs totals" bug. (Confirmed in the
  code: ntc_lib_cpc.asm's mem_tb_fit takes a page off mem_count until the tables fit under
  mem_tend, with no flag. Why the Python harness shows a full map at 4160 and WinAPE doesn't is
  still open: mem_tend is the platform's top - ntc_plat_memtop - so more ROMs reserving workspace,
  as on Julian's WinAPE, would leave less table room.)
- REPORTED 2026-11-01 The Next runtime has no esxDOS in the harness (zxnrun.py: a .NEX only), so
  nothing in NTC's own tests exercises ntc_lib_nxt's file calls; CyborgOS's ZEsarUX harness is the
  only test.

## 13 The platform files

- REPORTED (moved from the todo, 2026-11-01) cpcfw: a Tick waits for the end of a statement, and the firmware's text takes about
      3.4 ms a character, so a Frame class that prints, beside a main loop that prints, runs
      20-25 times a second (two dues in one Print run as one). Options: a due count instead
      of a flag (catch up - right for game logic at a fixed rate, wrong for "once a frame"),
      or NTC's own glyph drawing on cpcfw (about 0.4 ms a character on cpc)
- REPORTED (moved from the todo, 2026-11-01) cpcfw End resets the machine straight away (RUN" programs): the last screen is gone
      before it can be read - wait for a key, or go back to BASIC when CALLed?

## 17 Memory.cls

- (Memory.Pages vs RamSize: see 9 - the class exposes both and callers pick either.)

## 18 Keys.cls

- REPORTED 2026-11-01 Keys.cls is missing on msxdos (and cpm, baremetal, test, cyborgos): a program
  that reads key states can't be built there, and a platform without it fails at compile with a
  "no class" message rather than a clear "Keys isn't on this platform". (The MSX's AUTOEXEC Shift
  skip in CyborgOS had to read the PPI itself.)

## 22 Float.cls, Fixed.cls

- REPORTED 2026-11-01 Float: rounding on ties can differ between the Z80 engine and a coprocessor
  (round-half-even is not guaranteed on the Z80 path), and "auto" picks the backend; the agreed
  design (Z80 by default, UseCoprocessor per kind, HasCoprocessor, bit-identical rounding, a
  Z80-only option) is not implemented. (Fixed names Float, so a program that uses only Fixed still
  joins Float - by design, ~1.5K.)

## 25 src/ntc3d (E3 and the rest)

- REPORTED 2026-11-01 E3 has CamSet / CamPosL for the camera; objects still have no matrix (roll, any
  orientation): an object is placed by position and yaw / pitch only. Analysed, not built.

## 31 The CPC harness

- REPORTED (moved from the todo, 2026-11-01) ntcrun.py counts 1 T per instruction while stepping to deliver an interrupt (up to
      2000 steps per 13333 T block, every block in turbo): its `T=` and the test platform's
      Ticks are too low, turbo most. The z80 module reports no T-states for one step - needs
      a T-state table (the scratch timing script used for the WinAPE comparison has one,
      with CPC microsecond timing too)

## 32 msxrun.py, zxnrun.py

- REPORTED 2026-11-01 zxnrun.py has no esxDOS: the Next's FileSystem is untested here (see 9).

## 34 regress.sh

- REPORTED 2026-11-01 regress.sh covers test, cpc, cpcfw, cpcmin, cpm, zxn and three msxdos checks;
  not sc3000, msx (cartridge), baremetal, cyborgos, colecovision (coleco/ has its own, not in the
  run). A change to a shared runtime file is untested on those until someone builds for them.

## 36 float/ - the Float and Fixed tests

- REPORTED 2026-11-01 The Float tests check values, not rounding ties: a tie case (x.5 at every
  scale, both signs) belongs in chk.py so a backend change that alters rounding is caught.

## 39 tools/ntccheck - compare.js

- REPORTED 2026-11-01 compare.js proves a compiler change produces the same bytes for every program -
  the right check - but a change that is meant to alter output (today's byte-array fix) can only
  show as "0 different" when no program has the case; a test program for each fixed bug belongs in
  the compared set so the next regression of it shows.

## 43 NTC.md, userguide.md, tutorial/, architecture.md

- REPORTED 2026-11-01 docs/NTC.md does not say that SP is the thread inside an #asm block, nor that a
  keyword block pops its own parameters: the one rule a hand-written block most needs.

## 45 todo.md, done.md, buglist.md

- FIXED 2026-11-01 done.md and buglist.md didn't exist (todo.md held 850 lines of done above its
  open list): now todo.md is the open work by component, done.md the done history, this file the
  bugs.

## analysed, nothing found (2026-11-01)

1, 3-7 (the three flavours' "=>" are operator tokens in strings, not arrow functions: the IDE's JS
is ES5 throughout); 8, 10-14 by reading (the Z80 regression passes: 726 checks, 0 failed); 15, 16,
19-21, 23, 24 (no asm block in any library class pushes on the thread - all scanned); 28, 29 (all
compile byte-identically before and after today's compiler change - compare.js: 1007 the same - and
the ones in regress.sh run); 30, 31, 33, 35, 37, 38; 40-42; 44, 46, 47. Not analysed in depth: 26
hwlib (its own tests), 27 iftopf.js (covered by the JS flavour's regression entries). 48-52: no code.

## by design, so people stop reporting them

- 2 / 52: ReDim takes constants only, no overflow checks, array parameters of 1 and 2 dimensions
  only, Format$ without patterns - the language limits listed under 52 in the todo.
