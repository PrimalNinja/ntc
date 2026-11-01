# NTC - known bugs

Things that are wrong, by component - the numbers are [components.md](components.md)'s, the same
as the todo's (todo.md: work to do; this: things that are wrong). Newest first in each. Each bug
carries its state: REPORTED (seen, not yet confirmed or traced), CONFIRMED (reproduced or found in
the code), FIXED (moving to done.md). Started 2026-11-01: four entries moved from the todo, then
an analysis of every component (the other session's; ANALYSIS.LOG has its method). The same
day every entry was checked (ANALYSIS.LOG): the real ones fixed, the rest moved to the todo (not
bugs: work not done) or to "by design".

## 2 ntc_compiler.js - the compiler

- FIXED 2026-11-01 A byte array parameter's element read in a Long (or other numeric temp)
  context with an index expression read the wrong byte: `CLng(a(i)) + CLng(a(i + 1)) * 256&`
  gave hex 3434 for 1234 - the destination temp was the index's own, zeroed by kw_ztov before
  kw_pget read the index. The destination now moves to the next temp when it is the index's.
  test/compare/bytearr.bas (expects 1234 ABCD) and regress.sh run it.
- FIXED 2026-11-01 A push in an #asm block corrupts the thread: SP is the thread, so a push
  writes over the words before the block, and the block works once and breaks when that thread
  runs again (reproduced: pushy7, then pushy0). The compiler now warns on push, call, rst and
  ex (sp) in an inline #asm block, from its top to the first label or `ld sp` (a pop is safe:
  it reads the thread's own words; a keyword block pops its own parameters, by design).
  test/asmsp.bas in regress.sh. A warning, not an error - see the question in ANALYSIS.LOG.

## 9 A machine's own runtime parts (cpc, msx, nxt) - also 17

- FIXED (NTC's side) 2026-11-01 The CPC runtime's page count and its bank count disagree, silently. The RAM
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
  Now: Memory.PagesCut() (cpc, cpcfw, cpcmin) gives the pages mem_tb_fit cut - 0 when none - so
  a program (CyborgOS's MEM) can show it. RamSize stays the hardware's size. Making room for the
  tables is CyborgOS's (its buglist).

## 13 The platform files

- CONFIRMED 2026-11-01 (moved from the todo) cpcfw End resets the machine straight away (RUN"
  programs): the last screen is gone before it can be read. Traced: ntc_plat_exit tidies up and
  End returns to the caller's stack; under RUN" the caller is the firmware's MC BOOT PROGRAM,
  whose return is a reset. CALLed from BASIC it goes back to BASIC, as it should. The fix is a
  choice (wait for a key on End when RUN", or an Option) - asked in ANALYSIS.LOG, not changed.

## 17 Memory.cls

- (Memory.Pages vs RamSize: see 9 - the class exposes both and callers pick either.)

## 18 Keys.cls

- FIXED 2026-11-01 Keys.cls is missing on msxdos (and cpm, baremetal, test, cyborgos), and a
  program using it failed with "unknown function or array: keys.down". msxdos now has Keys (the
  MSX's, reading the PPI; the msxdos run in regress.sh reads Shift). Any library class a platform
  lacks is now named: "Keys (keys.down) is a library class this platform (cpm) hasn't - it is on
  cpc, ...". cpm, baremetal, test and cyborgos have no keyboard matrix to read: no Keys there.

## 22 Float.cls, Fixed.cls

- FIXED (in part) 2026-11-01 Float: "auto" picked the coprocessor when there was one. The Z80
  engine is now the default (UseEngine 0 or 1); a coprocessor only on UseEngine 2;
  HasCoprocessor() says whether one is there. Not done: bit-identical ties - the engine rounds
  halves away from zero (an 8-bit guard, no sticky bit), C and the Pi round to even; moved to the
  todo (22) as a question. (Fixed names Float, so a program that uses only Fixed still joins
  Float - by design, ~1.5K.)

## 31 The CPC harness

- FIXED 2026-11-01 ntcrun.py counted 1 T per instruction while stepping to deliver an interrupt
  (up to 2000 steps per 13333 T block, every block in turbo): its `T=` and the test platform's
  Ticks were too low. No table needed: the z80 module's frame_tick counts the real T-states of a
  step. cpcrun.step1() steps one instruction and returns them; ntcrun, msxrun and zxnrun use it.
  (Fixed again the same day: frame_tick wraps every 100000 T - the first fix counted a step across
  it as ~4 billion T; CyborgOS's cosregress caught it. Now modulo 100000.)

## 34 regress.sh

- FIXED 2026-11-01 regress.sh covered test, cpc, cpcfw, cpcmin, cpm, zxn and three msxdos checks;
  not sc3000, msx (cartridge), baremetal, cyborgos, colecovision (coleco/ has its own, not in the
  run). Now it builds and assembles vb_test on sc3000, msx, msxcard, msx9990, baremetal,
  cyborgos, cyborgoshh, cpc9990 and cpccard, and hello on colecovision (a build check; they have
  no runner here).

## 36 float/ - the Float and Fixed tests

- FIXED 2026-11-01 The Float tests checked values, not rounding ties; and chk.py checked nothing
  (the emulator wasn't on its PATH, and 0 results passed). Now it fails when fewer results come
  back than asked, and 20 tie cases (both signs, several scales) check the engine's rule: 200
  values within 1 ulp, 20 of 20 ties right. regress.sh runs it.

## 39 tools/ntccheck - compare.js

- FIXED 2026-11-01 compare.js proves a compiler change produces the same bytes for every program -
  the right check - but a change that is meant to alter output (today's byte-array fix) can only
  show as "0 different" when no program has the case; a test program for each fixed bug belongs in
  the compared set so the next regression of it shows. Now compare.js also compiles
  test/compare/*.bas (bytearr.bas, asmsp.bas), and says what differs (asm, errors, warnings).

## 43 NTC.md, userguide.md, tutorial/, architecture.md

- FIXED 2026-11-01 docs/NTC.md did not say that SP is the thread inside an #asm block, nor that a
  keyword block pops its own parameters: the one rule a hand-written block most needs. Now in
  "Asm blocks in BASIC code", and the warning is listed.

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

- 2: `CallAddr`: the arguments are not checked against the target's parameters (the compiler
  can't know what is at an address); recursion through `CallAddr` is not found either. (Moved
  from REPORTED, 2026-11-01.)
- 2 / 52: ReDim takes constants only, no overflow checks, array parameters of 1 and 2 dimensions
  only, Format$ without patterns - the language limits listed under 52 in the todo.
