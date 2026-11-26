# NTC - known bugs

Things that are wrong, by component - the numbers are [components.md](components.md)'s, the same
as the todo's (todo.md: work to do; this: things that are wrong). Newest first in each. Each bug
carries its state: REPORTED (seen, not yet confirmed or traced), CONFIRMED (reproduced or found in
the code), FIXED (moving to done.md). Started 2026-11-01: four entries moved from the todo, then
an analysis of every component (the other session's; ANALYSIS.LOG has its method). The same
day every entry was checked (ANALYSIS.LOG): the real ones fixed, the rest moved to the todo (not
bugs: work not done) or to "by design".

Brought up to date 2026-11-26 (build 20261126-2): nothing had been entered here from 2 November
to 26 November. The entries dated after 2026-11-01 were written that day from build-info.txt;
each names its build, where the detail is.

## 2 ntc_compiler.js - the compiler

- REPORTED 2026-11-16 (CyborgOS 20261116-6) Three parameters of CyborgOS's hypervisor - Hyp.ReplyE(e),
  Hyp.FileOwns(slot), Hyp.BootDrive(d) - made ByRef put a stray "?" after HELP's "-- more" line on
  the V9990 screen (CyborgOS's test v9_help). They were left ByVal. Which of the three, and whether
  the fault is the compiler's by-reference code or the hypervisor's own, is NOT found.
- REPORTED 2026-11-11 (20261111-1) A paged class (Option Page X = Class) none of whose procedures
  the program calls leaves the page's stubs pointing at labels the unused-procedure pass dropped
  ("Label not found: p_x_pg ..."). Seen on zxn (TIANREV's 2MB build leaves the class out of the
  Option Page line). Tried 2026-11-26 with a small case on cpcmin (one class in a page, its one Sub
  never called): it compiles and assembles clean. Not reproduced, not traced; it may have gone with
  the layout rework of 20261116-5, or need the Next.
- FIXED 2026-11-23 (20261123-2) Every towns program failed to assemble after 20261120-1: the
  compiler wrote the 68000's NTC_A16 macro (vasm's) into the 80386's file and nasm refused it.
- FIXED 2026-11-16 (20261116-9) An argument was copied back before the caller's page was back: a
  caller in another page that gave one of its Private Paged variables to a ByRef parameter the
  procedure writes got nothing back.
- FIXED 2026-11-16 (20261116-5) On the Next the Loaded / SaveNex pages were never marked taken in
  the Memory class (the library tested NTC_PGLOADED before the program defined it), so AllocPage
  could have handed one out.
- FIXED 2026-11-16 (20261116-4) The words StdIO.SetTerminal in a comment of the library's own StdIO
  class were taken for a call, so every cpm program using that class was built as if it chose its
  terminal while running.
- FIXED 2026-11-11 (20261111-3) #asm that names a label of the platform's start code linked that
  section a second time (every label in it came out twice).
- FIXED 2026-11-07 (20261107-6) A far call to a page's asm keyword from another page crashed.
- FIXED 2026-11-06 (20261106-1) A public pure-#asm method of a page / overlay class, called from
  outside the page, ran without its page switched in.
- FIXED 2026-11-05 (20261105-13) A class copied into two or more pages, with a procedure nothing
  calls, failed to assemble.
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

- FIXED 2026-11-18 (20261118-1) zxn: a program whose arrays were put in #C000-#FFFF stopped at its
  start with GURU 001 (kw_bssinit asked for the top of memory and the Next answered #BA00 always).
- FIXED 2026-11-16 (20261116-7) zxn: the Memory class's table stopped at page 109 on a 2MB Next
  (built in fours, the two pages left over dropped).
- FIXED 2026-11-16 (20261116-6) zxn: the font was font8x8_basic; it is the Amstrad CPC's. The RAM
  probe wrote a marker into the program's own banks. (The MEGA65 and the TI-89 still carry
  font8x8_basic: a question in the todo, 12.)
- FIXED 2026-11-11 (20261111-2) zxn: the Memory class's RAM probe wrote a marker byte at #4000 of
  every bank and never put the bytes back (HIVEWOOD's graphics, RANAMAGE's main thread). A Loaded
  page past a 1MB Next's last bank aliased a real bank; it is refused.
- FIXED 2026-11-10 (20261110-1, 20261110-2) zxn on a real Next: a data block was put in the Next's
  bank 7 (the DOS's workspace), and the NEX start stub rewrote DivMMC's entry-point registers. Four
  games crashed at their first esxDOS call on the machine while every emulator ran them.
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

- FIXED 2026-11-16 (20261116-10) ntcrun.py's stand-in for the firmware's fast ticker did out (#DD),
  a round the event routine; with A = #F6 the emulator took it for the PPI and never brought the
  main ROM in ("ROM set romset4: interrupts during far calls cpcfw" crashed once the Loader's
  variables moved the ROM's). The emulator's fault, not NTC's.
- FIXED 2026-11-01 ntcrun.py counted 1 T per instruction while stepping to deliver an interrupt
  (up to 2000 steps per 13333 T block, every block in turbo): its `T=` and the test platform's
  Ticks were too low. No table needed: the z80 module's frame_tick counts the real T-states of a
  step. cpcrun.step1() steps one instruction and returns them; ntcrun, msxrun and zxnrun use it.
  (Fixed again the same day: frame_tick wraps every 100000 T - the first fix counted a step across
  it as ~4 billion T; CyborgOS's cosregress caught it. Now modulo 100000.)

## 33 A machine's build, run and regression set

- CONFIRMED 2026-11-25 (20261125-1), not NTC's: the ep128emu core's own file device handed one
  program over wrongly nearly every time (a file of exactly 5,334 bytes; before any of its bytes
  ran), and never off the disc. epregress.sh loads everything off the disc.

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

- FIXED 2026-11-26 (20261126-2) done.md, todo.md, components.md, this file, architecture.md and
  targets.md were not kept after 9 November: seven platforms, a flavour and three weeks of
  language changes were in build-info.txt and each machine's own document only. Brought up to date
  from build-info.txt.

## 58 The other machines' own classes

- CONFIRMED 2026-11-26 (20261126-1), cause NOT found - c64reu, the Disk class: on the emulator one
  program hung in the KERNAL opening a file that was not there, a few frames after another load.
  The class now waits for the serial bus to be idle before it opens a file, and the hang is gone;
  why it happened was not found.

## analysed, nothing found

- 2026-11-16 (20261116-2) CyborgOS's KEYMAN prints a different length for its encoded message with
  every build of the compiler (113, 108, 114 bytes); the round trip decodes right every time. It
  moves with something outside the program's logic (timing or memory contents when KEYMAN picks
  its encoding); no compiler fault found.

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
