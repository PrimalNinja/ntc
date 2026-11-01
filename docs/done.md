# NTC - done

What has been done, newest first (moved out of todo.md on 2026-11-01; the open work is there,
by component).

## ticked in the open list (moved here 2026-11-01)
- [x] File I/O, first step (2026-10-12): FileSystem class - CP/M full, CPC firmware
      Load / Save, none on CPC hardware and test (see done)
- [x] console on CPC firmware and CP/M (2026-10-11, platforms `cpcfw`, `cpm`)
- [x] ZX Spectrum Next, native (`zxn`, 2026-10-17)
- [x] zxn: Graphics on Layer 2, AUCKLAND.NEX (2026-10-17)
- [x] MEGA65, native (`m65`, 45GS02: SP the thread, interrupts off; the `Vic`, `Joy`, `Sid`
      classes; `bas/cyswarm_m65`; docs/m65.md, 2026-10-25)
- [x] CP/M: `Option Terminal VT52 | ANSI` (2026-10-11) gives Cls / Locate, CanPosition /
      CanClear / Rows follow it
- [x] host calls (BDOS `call 5`, firmware) on a real stack: `ntc_fwcall` / `ntc_bdos` switch
      SP to `ntc_csp` for the call only, the thread never sees call / push (Julian OK'd the
      firmware / CP/M platforms, 2026-10-11)
- [x] CP/M: org #0100, page zero is CP/M's, exit with jp 0, console through BDOS
- [x] decided 2026-10-12: CP/M builds never page (no gate array writes, Small only, overlays
      through BDOS file reads). SymbOS runs CP/M programs in memory it manages, on the CPC,
      MSX, Enterprise 128 and PCW, so one bank-free .COM with its .PAG overlays runs on all of
      them, as on real CP/M and MSX-DOS. (Notes kept in case a CPC-only CP/M build is wanted:
      CP/M 2.2 runs in C0 like AMSDOS; a RAM disc's 512K is found by a CP/M directory in the
      expansion RAM, not by drive letter - M: may be an M4 / XMAS drive; the probe must save and
      put back what it writes. CP/M Plus runs in C2: every page setting swaps all four blocks.)

- 2026-11-01 The bug pass (buglist.md's entries checked one by one; ANALYSIS.LOG has the evidence):
  - compiler: a byte array parameter's element with an index expression in a Long context read the
    wrong byte (`CLng(a(i)) + CLng(a(i + 1)) * 256&` gave hex 3434 for 1234): kw_ztov zeroed the
    index's own temp before kw_pget read it. The destination moves to the next temp.
    test/compare/bytearr.bas.
  - compiler: warns on push / call / rst / ex (sp) in an inline #asm block before any label or
    `ld sp` (SP is the thread). test/asmsp.bas. NTC.md says so.
  - compiler: a library class a platform hasn't is named ("Keys (keys.down) is a library class this
    platform (cpm) hasn't - it is on cpc, ...") instead of "unknown function or array".
  - msxdos: Keys (the MSX's class).
  - cpc, cpcfw, cpcmin: Memory.PagesCut() - the pages mem_tb_fit cut so the page tables fit.
  - Float: the Z80 engine is the default backend (UseEngine 0 / 1), a coprocessor only on
    UseEngine 2; HasCoprocessor(). docs/float.md.
  - test: chk.py fails when nothing ran (it had checked 0 values: the emulator wasn't on its PATH)
    and checks 20 rounding ties; ntcrun / msxrun / zxnrun count the real T-states while stepping
    to an interrupt (cpcrun.step1, from the z80 module's frame_tick, modulo its 100000 T frame -
    the first version wasn't, and counted a frame's end as ~4 billion T) - they counted 1 T an
    instruction; regress.sh builds vb_test on sc3000, msx, msxcard, msx9990, baremetal, cyborgos,
    cyborgoshh, cpc9990, cpccard and hello on colecovision, and runs chk.py, asmsp, keysdos and
    bytearr; compare.js compiles test/compare/*.bas and says what differs (asm, errors, warnings).
    compare.js against the tree before: 730 the same, 277 different - 226 the new class message
    only, 9 msxdos programs that use Keys now built, the rest comment line numbers and NTC_STAMP.
- 2026-10-31 Float and Fixed built in (src/lib/z80/, docs/float.md, test/float/): gen.js gives every Z80
  platform lib/z80's classes (not md, m65) unless it has its own of that name. The compiler now
  follows a library class's own names when it picks them (Fixed names Float: a program using only
  Fixed got "unknown float.fromint"), and a library class joins only when it's used as one
  (Name.x or As Name), not when its name is a word in the program - vb_test6's variable "fixed"
  had pulled Fixed and Float in. compare.js: 1007 the same. Float / Fixed tests (test/float) the
  same with the classes from the library (no files added).
- 2026-10-31 A constant string's bytes 128-255 (Chr$ of a constant, folded into a literal, on byte
  text platforms - CP/M, CyborgOS ...) came out as ? - kept now (a code page's letters: KOI8-R,
  Latin-1; dbText writes them as numbers). Control codes and 127 are still ?. compare.js: 1007 the
  same (no program had one). Found by CyborgOS's LANG (Russian, Spanish).
- 2026-10-31 E3: CamSet (a camera matrix written into cm made the camera's: squared up, its copies
  worked out) and CamPosL (the position as 24.8 Longs) - a camera worked out outside E3 (NTC's
  Float class: ToBinScaled / MToBinScaled to s1.14 and 24.8). ROCKS builds byte for byte the same
  (unused, they aren't linked); checked in a ROCKS copy whose camera went through Float and back
  each frame: 268 trips, the conversions exact, CamSet's squaring up 2 / 16384 at most.
  Next: an object's own matrix (o-rotation from the program, roll included): the angles oa / ob
  feed five places - C = camera x O (near and far, od / od_c8), the sun into the model (od_osn),
  the camera into the model (od_pa, od_cmp); O worked out once (angles or given) and those five
  made to take it. Its 8 bit values s.7 with 1.0 as 127 (the sine table's): clamped.
- 2026-10-29 lib/cyborgos/CybSys.cls as it was (the target's interface to CyborgOS's services is NTC's;
  CyborgOS's own internals - DUMP / REVIVE / SLOTD's kernel calls - stay in CyborgOS's cmds/CybSys.cls).
  Today's earlier additions to it taken back out (Julian).
- 2026-10-29 lib/cyborgos/CybSys.cls (as CyborgOS's): RunIn (a program started in a slot), Listen / Accept
  (BDOS 131 ops 35 / 36: SLOTD's listening - a vCPC's for now).
- 2026-10-29 lib/cyborgos/CybSys.cls (kept the same as CyborgOS's cmds/CybSys.cls): Pause(s, p) and
  State(s) - BDOS 131 op 5, CyborgOS's PAUSE / UNPAUSE (a slot's program stopped where it is, going on).
- 2026-10-29 A platform: `cyborgoshh`, CyborgOS - The Headless Horseman - a program in a slot of a
  headless CyborgOS (a vCPC: cyborg-os-vcpc, its kernel and slots with no screen or keyboard of
  their own). For now it is `cyborgos` exactly: asm/ntc_plat_cyborgoshh.asm is `;@base cyborgos`
  (gen.js takes cyborgos's text and classes, which are cpm's with CyborgOS's on top), the same .CYB
  out; NTC_CYBORGOSHH defined, with NTC_CYBORGOS and NTC_CPM. The compiler's cyborgos cases (cpmLike,
  NTC_CPM, the #EF00 check) are platIs('cyborgos') now, so what is built on it is cyborgos too. The
  GUI lists it; gen.js, ntcrun.py (run as cpm) and hosted/ know it. Checked: CyborgOS's PS.CYB the
  same byte for byte from both; tools/ntccheck/compare.js against the tree before: 954 programs and
  platforms the same.
- 2026-10-27 test/v9990.py: a model of the V9990 for the harnesses (CyborgOS's console on a
  Powergraph / GFX9000) - its ports (P#0-P#7), the register select with WII / RII, VRAM through
  R#0-R#5 (AII), the palette (R#14's ternary pointer), LMMV, LMMM, LMMC, PSET with R#45's logical
  operations and TP, the picture (bit map modes, SCAY with R#18's roll) and ocr() - the text read
  off the picture with ntc_font6. NTC_V9990=1: ntcrun.py's CPC platforms get one at &FF60, msxrun.py
  at #60 (and msxrun's ROM font, RDSLT from CGTABL, is ntc_font6 now: a program copying it gets
  real characters)
- 2026-10-27 Merged another session's debug work (it was on ntc20261026-0022; its 9 files untouched
  here since): test/zxnrun.py - the Next's sprites in pictures, the 9-bit palette (#44), NTC_PROFT
  (exact T per label between two T), NTC_PROFTLOG, NTC_WATCH, NTC_LOGVARS, NTC_INTCHK, NTC_TRACEZ_AFTER
  and TRACEZ chg= / irq= / spin=; Auckland's S3d.cls (all six copies) and City3D's City.cls - the
  small helpers (CMPS, HNEG, HABS, UCAP, X6, VX12, PJDIV) as macros written in, no call / ret
  (auckland zxn in the harness: FPS 2.8 -> 3.2 at view 2); auckland/ANALYSIS.TXT - where the frame's
  time goes. The city3d / s3dmake / auckland regress tests pass; bill and street fly
- 2026-10-27 colecovision: Julian's ColecoVision work merged and made a target - the platform text
  (bare metal + the ROM keys, the cartridge header and start, the VDP's NMI off, Frame polled) is
  `asm/ntc_plat_colecovision.asm` now (gen.js, ntc.html), `tools/coleco/build.js` compiles for it (the
  same ROM as with the text handed over), `tools/coleco/run.mjs` the hardware model, the ball test in
  `test/coleco/ball/`; regress.sh builds and walks it when tools/coleco has its npm install
- 2026-10-27 msxdos (for CyborgOS's MSX C0): the mapper's probe took no segment at all with Option
  Memory CPCExpansion over 63 banks (MEM_BANKS * 4 = 256: `cp` 0) - now at most 31 banks (MSX_MAXSEG:
  a setting's C holds the ordinal 0-31). msxrun.py: a HALT with interrupts on waits for the frame
  interrupt (Frame) - a HALT with them off, or at #0000 (the warm boot), is the end; R#23's vertical
  scroll in TEXT 2's text (the name table a ring of 32 rows); MSX-DOS 2's handle calls (#43-#4E, #40 /
  #41, #1B, #19, #5A) on the files folder; RDSLT / CALSLT (INITXT) stand-ins; the PPI's keyboard
  matrix ({n} held keys: 49 CTRL, 58 ESC); a .COM run as it is (CYBORGOS.COM); MSX_DOSLOG=1 lists
  the DOS calls
- 2026-10-27 msxdos: a new platform - an MSX-DOS 2 / Nextor .COM (MSX2 and later; CyborgOS's MSX port
  is built on it). ;@base cpm (the BDOS console and FCB files), with the MSX's frame interrupt (Ticks =
  JIFFY, normal mode's handler on H.TIMI through a stub copied to #C000 - page 0 is the BIOS while it
  runs), the real stack below #C000, and Option Memory CPCExpansion over the memory mapper
  (asm/ntc_lib_msx.asm: every free user segment from MSX-DOS 2's ALL_SEG at the probe, 4 a bank, the
  window = page 1 by PUT_P1, settings shaped as the CPC's as the Next's are; lib/msxdos/Memory.cls).
  test/msxrun.py: the harness (the mapper, DOS 2's mapper support, the frame interrupt, the VDP's
  ports and TEXT 2's text). regress.sh: vb_test, sieve, the Interrupt hook, and the Memory class on a
  512K mapper - the same results as the CPC with 576K (ref/mem_576.txt)
- 2026-10-31 NTC3D: Galaxy3D.cls (a wraparound cube of 2^bits cells kept in 16 bit: Init, At, Rebase,
  Rel, Near, Wrap) and Radar3D.cls (Scanner with stalks, Compass) added as optional classes, MIT as the
  rest of NTC3D: game.json's new `extras` (tools/build.js) builds them in; the framework's own list and
  ROCKS are as they were; Radar3D.Isqrt is a Long square root (Sqr takes only an Integer). Written for and tested in a game (not part of NTC): its scanner with stalks
  and its compass work, its galaxy wraps, Rebase follows
- 2026-10-27 NTC3D updated from Julian's new zip (IRON DUST's additions): the ground feature (MV_CIRCLE,
  MV_HUNT, MV_HOME, OF_LAND / EV_LAND, OF_GUNANY), Fly3D.Drive, E3.Skyline / Texts / UClr / UInk /
  lodb, compound models (M.Compound), build settings by tools/prep.js (nobj, features ground /
  noquad3 / noflyers, vertex buffers sized from E3Data's MaxV / MaxFV), and its own emulator in
  tools/emu (ROCKS's test/run.py needs nothing outside ntc3d/ now). Kept on top: MIT License on the
  library's files, build.js finding NTC's src from where it is, tools/zesshot.js. ROCKS rebuilt with
  this NTC ends at #757C (18564 bytes left); its 3000 frame run gives the same log as Julian's
  (score 745, 3.24 frames a picture); a build with ground + noquad3 and 36 objects assembles clean
- 2026-10-26 NTC3D added (`src/ntc3d/`, from Julian's NTC3D zip): the ZX Spectrum Next 3D framework
  (E3, Obj3D, Fly3D, Hud3D, Nx; the model tool e3models.js, build.js, the ROCKS example, its
  manual FRAMEWORK.md). build.js finds NTC's src from its own place now (it had a fixed path).
  ROCKS rebuilt with this NTC: assembles clean, ends at #7EF2 (16142 bytes left under #BE00 - the
  CyborgOS glue no longer in a plain Next program), runs in ZEsarUX (tools/zesshot.js). Its
  test/run.py still needs DIREMOON STRIKE's test/emu.py (not part of NTC)
- 2026-10-26 md: Pad.Read's 6 button read (ntc_md_pad, the frame interrupt) stopped one TH step
  short - it read the 4th step (?0SA00DU) where the 6 button pad answers on the 6th, so the pad
  looked like a 3 button one and X, Y, Z, Mode never registered. Now the full 8 steps (H L H L H L,
  the extra buttons read on the 7th, back low on the 8th). Test: test/mdpad (mdregress.sh pad6:
  X, Y, Z, Mode, A, X+Y+Z held by mdrun.py's --pad)
- 2026-10-26 Option HighCode (cpcfw) and Option Place: code in #C000-#FFFF too - in the file at
  #4000-#7FFF round the window data (same offsets, +#8000), copied up by the start code, which also
  does KL U ROM DISABLE and SCR SET BASE #40 (the screen at #4000). highLayout: the start code, the
  library's code and the Option Place classes below #4000, then the rest (procedures, each #asm
  block on its own) below #4000 as far as it goes, then #C000 up to the window data, then after it,
  then from #8000; the variables, strings and the library's data from #8000. CyborgOS's flat build
  uses it. Test: test/hcode (regress.sh). Harness (ntcrun.py): SCR SET BASE (#BC08), the screen
  read wherever it is (R12's page once the CRTC is set), main RAM's pages read where they are kept
  while a bank is paged in; KL ROM SELECT / DESELECT keep the RAM under #C000 (it wrote #80 over
  it for good - CyborgOS's network tests' references had a missing "C" from it)
- 2026-10-26 zxn: a Next program no longer carries code it never runs. Frame no longer needs
  ntc_plat_irqh: its catch-up of lost ticks is built only when the interrupt handler is in the program
  (NTC_ZXIRQ, set after linking - normal mode), so a turbo program with Frame has no handler,
  ntc_ticks or hook variables. And the Next's bank switch glue at #0040 (CyborgOS's pivot) stays only
  when the program uses it (the hypervisor's #asm names ntc_bk_sp / ntc_bk_out: linkTidy in the
  compiler). A turbo Next program with Frame: 345 bytes less; a normal one: 71 less. Every other
  platform builds the same (tools/ntccheck/compare.js: 795 programs), CyborgOS byte for byte the same.
  The CPC's glue (14 bytes) stays in every CPC program at #0040: taken out, the cpcfw Library: ROM test
  irqfar (a set of 4 ROMs, interrupt classes during far calls) ran off into the stack (an RST 3 at
  #BF88). Without the glue the program ends at #02FD and fails; padded to end at #0301 or more it
  passes, so it looks like the program's end below about #0300 rather than the glue. Not found yet: todo.
- 2026-10-26 zxn: Inkey gives the cursor keys (Caps Shift + 5-8, which the Next's cursor keys are)
  the CPC firmware's codes - up 240, down 241, left 242, right 243 - where it gave nothing. CyborgOS's
  programs (MON, MON2, YING, YANG) read those codes, so on the Next their cursors did nothing.
  test/inkey_zxn.bas in regress.sh.
- 2026-10-25 Regression suite back to all passing (887). Library: ROM had stopped building on all
  three CPC platforms since the Next port: the CPC Memory section got IFNDEF NTC_ZXN / IFDEF
  NTC_PGLOADED blocks, which ntcRomAsm passed through, so the section looked like it used Next
  labels and was left out - and with it ntc_memcore, List, Copy (the variables after it moved 44
  bytes and the registry asserts failed). ntcRomAsm now keeps IFNDEF NTC_ZXN's CPC part and drops
  IFDEF NTC_PGLOADED (Option Page ... Loaded is a program's); the registry is unchanged. The zxn
  start stub test expected DivMMC automap off (NextReg #0A = 0); the stub leaves it on, cut to RST 8
  (#B8, #B9, #BB) for esxDOS - the test updated. regress.sh builds build/rom/ first when a fresh tree
  has none (the ROM tests ran before the genrom step that makes them).
- 2026-10-25 Merged: the MSX / SC-3000 / CPC video card targets (msx, msxcard, msx9990, sc3000,
  cpccard, cpc9990), the Sega Mega Drive (md, 68000) and the MEGA65 (m65, 45GS02) in one tree - the
  compiler, js/ntc_lib.js (regenerated by gen.js from the merged sources: the same as the hand merge),
  test/gen.js and the READMEs. Checked: every program in bas/ compiled for every platform gives the
  same output as the tree it came from. hwlib/ added (optional game libraries: a class per video chip,
  the balls and cube tests); its 16 tests rebuilt with this tree are byte for byte the ones it came with.
  hwlib builds MSX / SC-3000 programs on baremetal (its chip classes drive the hardware); the msx /
  sc3000 platforms came at the same time - moving its tests onto them is to do.
- 2026-10-25 Six targets. `msx` (a cartridge ROM, the BIOS kept: its keyboard buffer and
  interrupt; the console on the MSX's own video chip, 80 columns on an MSX2), `msxcard` (the
  console on a V9938 card at #88: HB-4000, CT-80E, MA-20V), `msx9990` (the console on a V9990:
  GFX9000, Video9000, Powergraph), `sc3000` (Sega SC-3000: a cartridge ROM, 2K of RAM, the
  TMS9918 console, the keyboard matrix), `cpccard` / `cpc9990` (cpc with the console on an MSX
  V9938 card through the AMSDAP adapter at &FF88, or a V9990 at &FF60: AMSDAP or the CPC
  Powergraph). The compiler builds cartridges (`;@rom`, `;@ram`: romLayout keeps the code in the
  ROM and puts what the program writes in a RAM image; `; @const` / @const keep tables in the
  ROM; `ntc_plat_romhead` at the org; the ROM padded to its size), `;@irqrate` (Option Class
  Interrupt's rates on a 50 a second platform), `;@islc` (`DEFINE NTC_ISLC`: ntc_isl_tick takes
  the frame from C - zxn too, where it was `IFDEF NTC_ZXN`), `;@vdp`, `NTC_<base>` defined for a
  `;@base` platform. gen.js: a `;@base` platform's own `;##` sections and `;@` keys replace the
  base's. `asm/ntc_lib_vdp.asm`: the video chip consoles (TMS9918 family text modes, a V9990 bit
  map with a 6 x 8 font from the public domain X11 5x8) and the engines of two new classes,
  `VDP` (TMS9918 / V9938 / V9958: Screen 2, 5-8, PSet, Point, Box, Line, Copy, Palette, VPoke ...)
  and `V9990` (Screen 1-3, PSet, Box, Line, Copy, Palette ...), for the MSX platforms, the
  SC-3000 (VDP) and every CPC platform (through AMSDAP). `Keys` for msx (the matrix, PSG
  joysticks) and sc3000 (the matrix, the joypads). Tested: the self tests from the ROM on the
  SC-3000 (MAME) and the MSX (openMSX, C-BIOS MSX1 / MSX2 / MSX2+), the consoles and classes in
  openMSX (GFX9000, HB-4000) and MAME; cpccard / cpc9990 in cpcrun.py's CPC with a model of the
  cards' ports (no CPC emulator here has AMSDAP). Not on real hardware yet.
- 2026-10-21 zxn: `ntc_zxn_inthold` (a call from #asm): the line interrupt held by the Next's
  interrupt controller (core 3.02+, NextReg #C0 bit 0, #C4) until the Z80 takes it, instead of
  the 32 T pulse a program with interrupts off misses; the handler ends with reti. For CyborgOS;
  a game whose Frame waits catch every pulse doesn't need it. Untested on hardware as yet.
- 2026-10-21 zxn: a NEX must be started by NextZXOS (the browser, .nexload, an autoexec) for
  esxDOS calls to work; loaded as a snapshot in an emulator the DOS answers "nonsense" (2) to
  everything - noted in the start stub (CyborgOS's SD drive, tested on JNEXT / NextZXOS 2.06H).
- 2026-10-21 Two platforms. `cyborgos`: a program in a slot of the CyborgOS hypervisor - the cpm
  platform (asm/ntc_plat_cyborgos.asm says `;@base cpm`: gen.js composes its text and classes
  from the base's) plus what CyborgOS adds: the output is always a .CYB (the AMSDOS header - the
  one file for the CPC and the Next), Option Terminal VT52 the default (`;@terminal` in the
  platform header), CybSys a platform class (the hypervisor's services, with Host() for which
  machine), NTC_CYBORGOS and NTC_CPM defined. `baremetal`: built from its org and nothing assumed
  - every platform routine and class method an empty one to fill in (asm/ntc_plat_baremetal.asm,
  lib/baremetal/); `Option Org` (and `--org=`) for where a program is built to run. The GUI
  lists both; ntcrun.py runs cyborgos as cpm. `cli.js --const=NAME[=value]`: a #Const for that
  build.
- 2026-10-21 `#asm`: `@name:` is a global label (sjasmplus's): other blocks can name it - the way
  CyborgOS's SD card code (main RAM, FileShut's block) reaches FileCall's page code names
  (`@g_fl_peek: EQU fl_peek`). zxn's NEX stub no longer writes port #E3 (DivMMC memory) nor turns
  DivMMC's automatic paging off: both lose NextZXOS's esxDOS state (its file handles); instead
  NextRegs #B8 = 2, #B9 = 0, #BB = 0 let only `rst 8` with ROM 3 selected page DivMMC in, which no
  NTC program does - CyborgOS's SD drive does it on purpose (ROM 3 in slots 0-1 for the call).
  zxnrun.py: `NTC_INTPULSE=32` - INT as the Next's 32 T pulse, not held (`missed=` at the end).

CyborgOS (a separate project built with NTC BASIC) keeps its own list in its own repository.

- 2026-10-21 Pages on the ZX Spectrum Next: `Option Page Name Loaded n = Class, ...` - the page is
  built (its addresses resolved against the program) but not loaded by it: it is in RAM page n from
  the start, its class block holding n, so a call only switches it into the window and jumps. On zxn
  (the only platform for it so far - the Next has no page files) page n is the NEX file's bank
  20 + n (zxnPageBank: past a big Option NexData it moves up with ZXN_FIRSTBANK, the same bank
  mem_sel maps for page n), assembled there at #4000 and loaded by NextZXOS with the program; Option Memory
  CPCExpansion is chosen by itself when there are pages; the Memory class marks the pages taken at
  its start (ntc_pgloaded, mem_start), so AllocPage never hands one out. zxn's ntc_plat_fs is a
  no-files stub (a page that was Unloaded can't come back: Load says NotSupported, a call stops with
  "Overlay not loaded"). Refused: a zxn page without Loaded, Loaded elsewhere, two pages on one n,
  a bank past 111. regress.sh: the pages test on zxn (both modes, ref/pages_zxn.txt:
  Loaded() is True for every page from the start), the refusals, the banks / blocks, Unload / Load, pages past a 9-block NexData.
  To come: Loaded on the CPC platforms; `Loaded` with no number (the program sets the page later)
  and `Loaded Using Fn` (a function of yours brings the page in); page files on the Next once it
  has a file system

- 2026-10-17 Fixed: Rnd(variable) and Randomize variable (or none) didn't assemble on their own -
  kw_rndv and kw_seedv jump into kw_rndl's and kw_seedl's code, which wasn't pulled in with them
  (Rnd(literal) and Randomize literal were fine)
- 2026-10-18 bas/auckland_block (the Next): buildings as solid textured blocks over a floating
  horizon, nearest first (bucketed by distance) - buildings hide buildings; the harness profiles
  the Next (NTC_PROFZ=1: the PC at each interrupt, the busiest labels)
- 2026-10-18 Hidden line removal tests: bas/auckland_tern (a ternary back-face test, per wall at run
  time) and bas/auckland_mask (s3dmake's wall masks, S3D2: a byte a wall, eight directions; an AND
  a wall). Both leave out walls facing away; neither is faster in the CBD (the time is in the corners'
  projection, not the lines) - see bas/auckland/README.TXT. The harness: NTC_PEEK=label,... (words)
- 2026-10-18 s3dmake: "Start at" a street (the first view), "Only the area round" a place (a square of
  it, every street and house: AUCKLAND-CBD, -DEVONPORT, -BEACHHAVEN.NEX, 1MB or 2MB).
  The Next's Layer 2 showed nothing (blue): in text mode the tilemap's paper is see-through only
  as the global transparent colour (NextReg #14), not by #4C's index - Graphics sets it; the
  harness (zxnrun) now puts the tilemap over Layer 2 the Next's way
- 2026-10-18 AUCKLAND1M.NEX: AUCKLAND for a 1MB Next (33 blocks, no bank past 47: s3dmake "At
  most" 528K); s3dmake fits a small size by thinning the trees after the small buildings (the
  woods' fill first)
- 2026-10-17 AUCKLAND on the ZX Spectrum Next: AUCKLAND.NEX (the same Main.bas / S3d.cls, #If /
  IFDEF NTC_ZXN where the Next differs). Graphics for zxn on Layer 2 (320 x 256, double buffered,
  XOR lines; the platform's own ntc_gfx); Option NexData "FILE", blocks - a data file's 16K blocks in
  the NEX's banks; zxn_sel puts one at #4000 (as the CPC's RAM page). The data made smaller for a
  2MB Next (s3dmake At most 1552K: 64,821 buildings, every road and tree). About 1.5-2 frames a
  second over the CBD in the harness (the CPC: 0.3). Fixed on the way: NTC_ZXN is a DEFINE now
  (sjasmplus's IFDEF tests DEFINEs: the library's Next-only part had never been assembled), and
  NextRegs selected while interrupts can come keep their selection (ntc_zxsel: the handler selects
  it again)
- 2026-10-17 ZX Spectrum Next platform `zxn` (asm/ntc_plat_zxn.asm, lib/zxn): straight to the
  hardware, laid out as `cpc` - the program at #0040 in RAM pages 16-21, the stack from #C000, bank
  5 (the screen) at #C000-#FFFF. A NEX file with a start stub (the NMI buttons and DivMMC's paging
  off, 28MHz, IM 1, the MMU slots). The text screen is the tilemap (40 x 32 / 80 x 32), the 8 x 5
  keyboard, Keys (key numbers half row * 8 + bit, Kempston joysticks), the line interrupt every 52
  lines (300 a second, as the CPC), Frame on the raster line, End a soft reset. StdIO, System,
  List, Memory (Small), FileSystem (no files yet). The harness: test/zxnrun.py (a Next: NEX loader,
  MMU, NextRegs, line interrupts, keyboard, the tilemap as text); every shared test passes on it
- 2026-10-17 VarPtr in a routine nothing calls (left out, with its variables): its address
  constant (vp_name) was still written - "Label not found" when the program used only some of a
  class (Http.cls's Time alone). Now left out too
- 2026-10-15 `As String Max n` on a ByVal parameter and a function's result (parser): its buffer n
  long instead of the program's longest string (MON: 1K smaller)
- 2026-10-15 Option Buffer Size n / Option Buffer address, n: the library's buffer smaller (32-2048);
  Memory.Copy copies that much at a time; FileSystem and List.Sort need 2048 (assembly stops).
  CyborgOS back on Memory.Copy (PRIMAL's chunked copy) with a 128 byte buffer, Hyp.Xfer gone.
  Tests "Option Buffer Size: Memory.Copy", "... FileSystem refused"
- 2026-10-15 PREP writes FILES.DIR as one 128 byte record of unused entries, not an empty file (a
  disc ROM may make no file for an empty one: PREP said it failed on UniDOS); its message says
  which step failed
- 2026-10-14 Memory class (CPCExpansion): PRIMAL's layout - a RAT (1 byte a page: its type) and
  a port table (2 bytes a page: the BC that selects it); no linked lists. A free page is found
  by CPIR, freed by writing - back; selecting a page is a look-up (no bank arithmetic). The
  per-bank table (129 bytes) and the 7 list heads / counts (28) are gone; the ROMs' RAM 92
  bytes smaller. bank_t.bas's bank code moved to #3000 (CallBank's switch code landed on it)
- 2026-10-14 Library: ROM with a program built round the window (#4000-#7FFF): the ROM's
  Memory class probes and puts its tables above the window (it ended with no banks: CyborgOS's
  Library: ROM build said "needs a 6128"). Option Memory honours #If (test "Option Memory in
  #If"). Built round the window, the strings are laid out one by one, filling what is left
  below the hole
- 2026-10-14 Harness: an `out (#DF), a` stand-in firmware call with A = #F6 (a byte just read)
  was taken as the PPI (CAS IN CHAR lost); |ERA
- 2026-10-14 Finer linking: `@data` (variables) and `@unit` (small routines) sections are linked
  when linked code names one of their labels - no header lists them. `ntc_data` split into a
  core and `ntc_d_*` variables; Backspace / Cls / Mode / Locate split from each platform's
  putc / newline. Print "Hello": cpcfw 555 -> 310 bytes, cpm 531 -> 470 (its 256-byte stack
  stays). The ROMs keep their registry (same RAM addresses); 4 new routine numbers

- 2026-10-14 Library: ROM: the start code (find the ROM set, patch the jump block, messages:
  about 460 bytes) goes last and the arrays / Memory tables start on it - it has run by then
  (as PRIMAL drops its relocation table). Hello: free RAM from #0089 instead of #0251
- 2026-10-14 FileSystem `ForReadRaw` (cpcfw, cpcmin; CP/M and the ROMDISC take it as ForRead):
  a headerless file read to its last record, #1A bytes kept (AMSDOS goes on after its soft end
  of file - checked on the real ROMs). `Eof` reads a byte ahead instead of CAS TEST EOF (which
  lost bytes at a #1A). Harness: a headerless file reads as AMSDOS does (each #1A a soft end,
  then on to the last record). Test "FileSystem ForReadRaw cpcfw / cpcmin"
- 2026-10-14 `Option NoRomDisc` (cpcfw, cpcmin): FileSystem without the ROMDISC, 1.1K less (#If
  NTC_NOROMDISC in the platform's FileSystem class)

- 2026-10-14 Graphics and CUBE3D on cpm (an Amstrad CPC, mode 2, one screen, no firmware): BDOS 12
  picks the way. CP/M 2.2 draws on #C000 in the program's 64K; CP/M Plus copies the line loop to
  #C000 (common memory) and draws each line from there with C1 (screen = block 1 at #4000), C2
  back. Harness: NTC_CPMVER (22 / 31, Plus modelled as C2 with the gate array), NTC_GFXCHK
- 2026-10-14 **Option Reserve builds round the range**: guards at each place a program can be cut
  (a library section, a procedure, the variables, the strings) skip the hole (`ds`) when the
  next part would reach into it (sjasmplus sizes from its earlier pass); a jr that crosses parts
  becomes jp; names that are another label + n go after everything; the arrays go after the
  hole; NTC_WINHOLE / ntc_memtab put the Memory class's tables above the window. Test hole.bas
- 2026-10-14 **CITY3D** demo (cpcfw, `bas/city3d`): a wireframe city to fly through - 64 x 64
  repeating cells (streets every 4th row / column, 1-7 storeys, taller in the middle), camera
  free in all directions (Elite's keys + cursors, T turbo), ~2000 units seen, buildings out of
  view skipped, lines clipped to the near plane and the view's sides, double buffered. All Z80
  in City.cls: per-frame tables (column / row / height terms in camera space) make each corner
  three additions; projection by shifts and an 8-step divide. About 1.4 frames a second at real
  speed (aimed at WinAPE 1000% for now). Harness: cpcfw now gives the vertical sync (#F5xx).
  Interrupts are let in while Render works (it runs ~0.1-1 s with them off otherwise, and the
  lost ticks made the FPS read ~10x high); the start screen shows the buildings and RAM used
- 2026-10-16 **AUCKLAND** (STATE3D) demo (cpcfw, 4 MB, `bas/auckland`): Auckland from
  OpenStreetMap - 233,935 buildings, roads, coast, 50,040 trees, the Sky Tower, Harbour Bridge,
  volcanoes - in AUCKLAND.DAT (3808K, 16K blocks of 384 m tiles) read into the expansion RAM;
  City3d's camera and clipping, the tiles 7 x 7 round the camera nearest first with a line budget,
  landmarks further (Rangitoto, the Sky Tower, the Harbour Bridge to 11 km). Starts 200 m up out
  in the gulf flying in, Rangitoto ahead on the right; P pauses. Made by tools/osmcut +
  tools/s3dmake (browser). About 0.3 frames a second (City3d 0.6). Test: a made-up town
  (test/s3d). Its file buffer is in S3d's tables (Option Buffer &H9000): with it in the
  program the Memory class's page tables (3 bytes a page, after the program) ran into those
  tables and the frames drew garbage.
  Option RomEnable All (RUN" dropped UniDOS: no file, no block read). Its tables moved under the
  ROMs' RAM - #8F50-#A2EF (UniDOS with an IDE node takes #A309 up): heights to 191 (382 m), 256
  landmark tiles, 12 points a building; it stops with a message when the ROMs' RAM (or the page
  tables) would reach them.
  S: frames skipped (0, 4, 8: S3d.Move moves the camera as a frame does, not drawn); a compass
  (Z80, in Render: an arrow bottom right pointing to the city's centre - the Sky Tower, block 0's
  word 48 / 50 from s3dmake). Dive is the cursor up key alone now.
- Compiler (open): the Memory class's page tables go after the program (ntc_free) even when an
  Option Reserve range starts soon after - nothing warns when they run into it (their size is
  only known at run time: 3 bytes a page).
- 2026-10-17 **AUCKLINK** + `tools/s3dpi`: AUCKLAND for a coprocessor card that serves a ROM (the
  CPC-CPLINK2, M4-like): the engine in C (integer only, for an RP2040), the card keeps the data,
  the CPC sends its keys and draws the card's line lists (3 bytes a point) out of the card's ROM
  (PROTOCOL.TXT). sim.c runs the whole link in one program; the CPC side (bas/aucklink, Link.cls)
  draws a list in 0.2-1.1 s (300-1400 lines): 4-10 times AUCKLAND's frame rate, drawing now the
  limit. 2026-10-18: wired to the real CPC-CPLINK2 register map (PROTOCOL.TXT, the overview from
  github.com/rabs664/Amstrad-CPC-CPLink2): commands out through the #FD80 data FIFO gated on
  #FD81 bit1 (DIR), #FD81 write = reset, PI ROM 1 = upper ROM 32 for the status block and lists.
  Compile-checked and the no-card path runs; the with-card path can't be emulated here. Not on
  a disc (cpcfw.dsk is full): build it from bas/aucklink.
- 2026-10-16 **Compiler**: a call with function calls among its arguments (`S 1, F(2), F(3)`)
  passed the last call's result for all of them (each was its function's result variable): each
  is now kept in the argument's temporary first. Test argfn.
- 2026-10-14 CUBE3D: + / - (the ; and - keys) are held keys (Keys class) on the CPC platforms -
  the size changes every frame while held (cpm keeps Inkey$). MAXPOINTS 24, MAXEDGES 40 (room
  for Keys on cpcmin). Harness (cpcrun): a Keys scan no longer moves typed keys on
- 2026-10-14 CUBE3D: only the edges that moved are drawn again (old line off, new on) - the
  shape no longer blinks in place when a turn moves it less than a pixel. The turn is a fixed
  step a frame again (the clock-based step was erratic in normal mode)
- 2026-10-13 every program in bas/ has `Option PressAnyKeyOnEnd` in place of its own "Press a key"
  loop (Locomotive: `'# Option ...` on a line of its own; JS: `//# Option ...`); the test harnesses
  press Return at that wait
- 2026-10-13 ROMDISC: read-only files in ROMs (NTCDISC.ROM ..., up to 8, any slots), FileSystem's
  volume R on cpc (its only volume), cpcmin and cpcfw - Load, Open ForRead (handle 2), ReadByte, Read,
  ReadLine, Eof, Close, Exists, Size, DirEntry; 8.3 names, a directory read until the end flag, a
  flags byte (compressed: reserved); `ntcRomDisc` + test/genromdisc.js; checked on the real 6128
- 2026-10-13 keyword ROM sets: a platform's library in as many ROMs as it needs (NTCMIN.ROM,
  NTCMIN2.ROM ...), one build, found by the set's stamp in any slots; `@far` sections (Memory,
  List) move out as groups; far calls through RAM stubs (cpc / cpcmin `#DFxx`, cpcfw KL ROM
  SELECT); the interrupt handler puts the main ROM in for interrupt classes; genrom `--cap` /
  `--place` / `--out`; harness slots 6, 5, 4 ...; regress builds 2- and 4-ROM sets; checked on the
  real 6128 ROMs (realcpc `XROM2=` ...)
- 2026-10-13 Graphics out of the keyword ROMs (`@ramonly`: a Library: ROM program carries it)
- 2026-10-13 `Option PressAnyKeyOnEnd ["message"]`: a message and a key at every end of the program
- 2026-10-13 interrupt classes: up to 16 (was 4); `Option Class Interrupt Share` *weight* (1-100):
  shared classes split what the fixed ones (a rate, Frame) leave, by weight; test isl2 (8 classes)
- 2026-10-13 Memory: whole 64K banks - `Banks`, `AllocBank`, `FreeBank`, `BankPage`, `CallBank`
  (the bank as all 64K, RAM setting C2, a 16 byte switch copied into the bank), `BankStub`;
  type B; the harness's RAM model has C1-C3 (C2 = a full bank swap); test bank_t
- 2026-10-13 FileSystem on cpcfw / cpcmin: one open file - Open ForRead / ForWrite, ReadByte,
  WriteByte, Read, Write, Eof, ReadLine, WriteLine, Close (CAS IN / OUT CHAR); test seq_t
- 2026-10-13 Keys class (cpc, cpcmin, cpcfw): `Down(key)` (CPC key numbers), `Joystick(n)`, from
  the matrix; harness `{n}` holds key n; test keys_t
- 2026-10-13 Locomotive flavour: INKEY(n), JOY(n), OPENIN / OPENOUT / CLOSEIN / CLOSEOUT /
  PRINT #9 / INPUT #9 / LINE INPUT #9 / EOF mapped onto Keys and FileSystem; test loc/files.loc
- 2026-10-13 `@ramonly` library sections: left out of the keyword ROM, linked into a Library: ROM
  program that uses them (cpcmin's open-file code: NTCMIN.ROM was full); `NTC_ROMLIB` is 1 in a
  Library: ROM program; ROM registry asserts on constants compare 16 bit (negative values)
- 2026-10-13 Locomotive BASIC flavour, step 1: `.loc` / `'# Option Flavour Locomotive`; line
  numbers (only jump targets kept), a / a% / a$ renaming, '# type hints, DATA / READ / RESTORE,
  DEF FN, SWAP, MID$ on the left, MAX / MIN, BIN$, WAIT, IF ... THEN line; unsupported lines become
  comments + warnings; GUI + Locomotive; example loco_demo; tests (test/loc)
- 2026-10-13 JS flavour, first version: `Option Flavour JS` / a `.js` file; ntcPrep (a flavour
  preprocessor with a factory of flavours: vb5 passes through, js -> VB5 text line for line);
  let/var/const with //# type hints, functions, if/while/for/switch/break/continue/return, ES6
  classes (one per file), JS operators and string / Math methods, //# NTC lines, /* #asm */;
  refused forms give messages; GUI + JS; example js_demo; regression tests (test/jsf)
- 2026-10-13 keyword library in ROM (cpc, cpcmin, cpcfw): `Option Library ROM` / GUI Library "in ROM";
  `ntcRomAsm` + test/genrom.js build `build/rom/NTCFW.ROM` (16K + AMSDOS header, background
  ROM "NTC CPCFW"); permanent append-only registry of numbers / variable addresses; the program
  has `name: jp <number>` entries, finds the ROM in slots 0-31 and has its patcher fill in the
  addresses; checked on the real 6128 firmware (self tests, files, interrupts, pages, cube3d)
- 2026-10-09 tinyz80b BASIC to NTC compiler (first cut, regex parser), ES5, line by line,
  IFtoPF shunting yard, no parse tree
- 2026-10-09 realtime GUI `ntc.html` with textEditor.js: BASIC left, NTC asm right
- 2026-10-09 keyword library `asm/ntc_lib.asm`, linked by use, sections `;## name deps`
- 2026-10-09 CPC platform `asm/ntc_plat_cpc.asm`: no firmware, no call, no push, IX link,
  screen modes 0/1/2, scroll, LOCATE, CLS, keyboard matrix scan, FRAME
- 2026-10-09 ZOSCII text: `kw_printzoscii` + glyph words pointing at 8 byte bitmaps
- 2026-10-09 GOTO as 1 word + stub (`ld sp, l / ret`)
- 2026-10-10 FOR keywords: STEP 1 with `inc (hl)`, literal step, variable step
- 2026-10-10 GOSUB targets as keywords (`l_gs` / `l_rt` stubs), fallback to the GOSUB stack
- 2026-10-10 VBCC copied for reference, analysed; analyser files copied in
- 2026-10-10 folder layout: `js/`, `css/`, `asm/`, `bas/`; `NTC.md` overview
- 2026-10-10 **parser**: VBCC concept ported to JS (`js/ntc_parser.js`): statement
  normalising (pvtStatementTok), prefix dispatch, context flags (module / class / procedure
  / Type / #If), statement records, element table. Replaces the regex parser. Z80 only, no
  target generator split
- 2026-10-10 IFtoPF: any name followed by `(` is a function / array with its argument
  count (`NAME@n`), commas, string literals, `&`
- 2026-10-10 **code generator** rewritten on the records (`js/ntc_compiler.js`)
- 2026-10-10 no separate old dialect: classic statements are built ins (Peek Poke Deek Doke
  Call Break Cls Locate Mode Frame Inkey Rnd Randomize), old programs still compile
- 2026-10-10 modules, multiple files, `Option Explicit`, `Option Base`
- 2026-10-10 `Dim / Private / Public / Global / Static As Integer | Byte | Boolean | String`,
  type suffixes, undeclared names typed by use
- 2026-10-10 `Const` (folded, numbers and strings), `#Const` / `#If` / `#ElseIf` / `#Else`
- 2026-10-10 `Sub` / `Function` / `Property Get|Let|Set` as keywords: call stub copies args
  into parameters, `ByVal` / `ByRef` (copied back when written) / `Optional` defaults,
  function result variable, locals zeroed on entry, `Static` kept, `Exit Sub|Function`
- 2026-10-10 call graph check: recursion is an error
- 2026-10-10 `Select Case` (values, ranges, `Is`, strings, `Case Else`), one line and
  block If, While, Do forms, For, Exit, GoTo, GoSub (labels per procedure)
- 2026-10-10 string built ins with temp string slots: Len Left$ Right$ Mid$ Chr$ Asc Str$
  CStr Val InStr UCase$ LCase$ Trim$ LTrim$ RTrim$ Space$ Spc String$ Hex$, `&` concat,
  string compares < <= > >=
- 2026-10-10 UDTs (`Type`), whole Type copy, arrays of Types (`pts(i).x`)
- 2026-10-10 multi dimension arrays, `1 To n` bounds, string arrays (`kw_sget` / `kw_sset`)
- 2026-10-10 classes as syntactic sugar: `.cls` members prefixed, `obj.Method`,
  `obj.Prop`, `obj.Prop = v`, `Class.Member`
- 2026-10-10 **turbo / normal modes**: one library, normal copies only for branch keywords
  (made from the same text: ret -> jp ntc_xn). `ntc_xn` lets an interrupt in at safe
  points; `kw_irq` every 32 straight keywords; key and vsync waits let interrupts in
- 2026-10-10 `Option Turbo`, build option, `Turbo On` / `Turbo Off`, mode tracked line by
  line, procedures built once per mode they are called in (`p_x` / `p_x_n`), mode checks on
  blocks and procedures
- 2026-10-10 CPC interrupt handler at #38 for normal mode, `Ticks`
- 2026-10-10 **project explorer**: listRenderer file list (+ Module, + Class, Rename,
  Remove, drag and drop), procedure list of the selected file (click to jump), open / save
  project (.json), project kept in the browser, errors with file and line
- 2026-10-10 example projects generated from `bas/` (`js/ntc_examples.js`)
- 2026-10-10 self tests pass on the emulated CPC in both modes: vb_test (64), vb_test2 (30,
  2 files), ntc_test (36), class project, sieve, shell sort, FOR / GOSUB / screen tests
- 2026-10-10 `Enum` (members are consts, `Enum.Member`, auto numbering)
- 2026-10-10 `With ... End With` (`.member` -> `obj.member`)
- 2026-10-10 `On x GoTo / GoSub`
- 2026-10-10 `Inkey$` (string)
- 2026-10-10 **`Long`** (32 bit): `kw_l_*` keyword set (add sub mul div mod and or xor not
  neg abs sgn, six compares, print, Str$ / CStr, Val, Input, arrays), Long variables, arrays,
  Type fields, parameters (ByVal / ByRef), function results, `CLng`, `1000&` literals,
  literals over 65535, constant folding in 32 bit, `For` with a Long counter, `Select Case`
  on a Long. `vb_test_long.bas` (58 checks) passes in both modes
- 2026-10-10 `Tab(n)` in Print (`kw_printtab`)
- 2026-10-10 arrays as parameters (`a() As Integer | Long | String`, through a descriptor,
  passed on), `LBound` / `UBound`. `vb_test4.bas` (16 checks) passes in both modes
- 2026-10-10 fix: a module named like a public procedure (shellsort.bas / Sub ShellSort)
  clashed with the procedure's locals ("already declared") - the module gets `_mod`
- 2026-10-10 GUI: open a `.vbp` together with its files - a new project with the files it
  lists, in its order (forms left out, missing files named)
- 2026-10-10 PRIMAL source added in `primal/` for REFERENCE only (not part of NTC, not
  changed). What it holds, for the memory work below:
  - Multi level API: LOADER (level 1, ~50% platform specific: console, file, memory table,
    heap, lists, relocation, patching), MEM (level 2, banked memory, one module per memory
    model, picked at run time), BIOS (3, driver model, design stage), KERNEL (4) and SHELL (5)
    platform independent. Targets: CPC (AMSDOS / FutureOS / CP/M), Adam, CP/M 2.2 / Plus,
    Enterprise, MSX-DOS, RomWBW, SC3000, SymbOS, TRS-80, Einstein, Spectrum 16k / + / +2 / +3.
    CPC = reference large memory system, Spectrum 16k = reference small one
  - Module header: `jp Main`, reloc table offset, build org, extra RAM after load (overwrites
    the reloc table), version, API id, required memory type, patch table, jumpblock, ISR,
    loader, `"PRIMAL",0`, description. Apps build at org #0000 and are relocated (sjasmplus
    relocation tables). Jumpblock entries are `jp 0` patched by the loader per API level;
    MEM patches its bank functions back into the loader ("patch back")
  - Memory table (loader): records `type, from, to`: 1 = non pageable RAM, 2 = pageable
    (bank window), 252 = video RAM, 253 = reserved, 254 = ROM, 255 = extension, 0 = end.
    CPC: loader at #0040, 128 byte stack at RAMTOP #A140 (under AMSDOS), pool = end of loader
    buffers .. #3FFF, #8000 .. below the stack, pageable #4000-#7FFF. Spectrum: pool .. #DF56,
    pageable #DF57-#FF57
  - Heaps: application / system / buffer, each a list of banks (port values). Bank select
    remembers the current bank per heap and skips the OUT when it is already selected. Far
    copies (F2F / F2N / N2F) go through a 128 byte copy buffer in non banked RAM with
    interrupts off
  - CPC bank ports (`ld bc, port / out (c), c`): #7FC0 = base 64k. #7FC4-#7FC7 = extra 64k
    (6128) in the #4000 window. Bits 5-3 of the low byte pick the 64k block: #7FCC-CF,
    #7FD4-D7, #7FDC-DF, #7FE4-E7, #7FEC-EF, #7FF4-F7, #7FFC-FF = 512k. Over 512k the port's
    high byte drops: #7Exx (1MB), #7Dxx / #7Cxx (2MB), down to #78xx (4MB). Configs in
    primal/src/ams_64 .. ams_4096. 256k silicon disc uses #7FE4-#7FFF (ams_256s);
    notes/memorytests.txt: WinApe vs real 664 tests show which ports exist per expansion
  - ams_v64: "virtual" banks - a bank select saves the window #4000-#7FFF to a file
    (def_7fc0.bin, app_7fc4.bin ...) and loads the other one. ~20000+ T per switch
  - RAT (resource allocation table, notes/memorynotes.txt): one byte per 16k bank: `-` free,
    `A` allocated, `R` reserved (survives a reset, e.g. a RAM disc), `E` extension of a
    multi bank block, `H` heap
  - PRIMAL's CPC loader uses the firmware (KM_*, TXT_OUT_CHAR, CAS_*) and call / push; NTC
    uses neither. kernel.asm includes Simon Owen's 6510 emulator (zero page / stack moved
    into defined space so it relocates)
- 2026-10-11 **`#asm` / `#endasm`**: lines kept as written; each block is an inline keyword
  (`asm_<file>_<line>`, thread gets one word, code goes with the stubs); labels local to the
  block; `{name}` = label of a variable / param / result / array (descriptor for array
  params and dynamic arrays) or the value of a Const, `{result}` = the function result;
  a block with `ld sp,` gets `ret` -> `jp ntc_xn` in its normal copy; library routines a
  block names are linked. Works in procedures and at top level
- 2026-10-11 `Inp(port)` / `Out port, value` (16 bit port, `in a,(c)` / `out (c),a`)
- 2026-10-11 diagnostics: `Error text` (prints "Error: text (file line n)" and stops),
  `Debug.Assert cond` (prints the condition and place when false, stops); `kw_printnl0`
- 2026-10-11 `On Error` / `Resume` give a clear error: NTC has no error handling (decision)
- 2026-10-11 classes: `Private Type` / `Type` inside a class; a Private class member used
  from outside is an error ("Pool.Bump is Private"); class arrays, arrays of a Type,
  `Public Const` as `Class.Const` tested (library class with handles: `vb_test5`)
- 2026-10-11 Byte arrays are real bytes (`kw_aget8` / `kw_aset8`, peek / poke keywords for a
  constant index); scalar Byte variables stay 16 bit
- 2026-10-11 dynamic arrays: `Dim a()`, `ReDim [Preserve] a(lo To hi)` with constant bounds
  (no heap: the storage is the biggest ReDim of that array, the descriptor holds the
  bounds), `Erase` (dynamic: no elements; fixed: cleared), `UBound` / `LBound`
- 2026-10-11 Types as parameters (ByVal / ByRef, nested Types, String and Long fields,
  passed on to another procedure): one address per field, ByRef copies back when written
- 2026-10-11 2 dimension array parameters; array descriptors are 12 bytes (base, lower
  bounds, counts, element size); `LBound(a, 2)` / `UBound(a, 2)` on them
- 2026-10-11 Long: `Hex$` of a Long (`kw_l_hex`), `For` with a Long counter and a Step from
  a variable, `^` on Longs (`kw_l_pow`)
- 2026-10-11 `AddressOf Proc` (a word holding the procedure's call stub) and
  `CallAddr ptr [, args]` (`kw_callp`) - driver / device tables
- 2026-10-11 `Option VBPrint`: numbers printed alone get VB spacing (" 5 ", "-3 "), a comma
  moves to the next 14 column zone (`kw_printintvb`, `kw_l_printvb`, `kw_printzone`)
- 2026-10-11 Interrupt hook: `Interrupt MySub` / `Interrupt Off` - the interrupt handler marks
  it pending, the next safe point (`ntc_xnh`, linked instead of `ntc_xn` only when used)
  calls the Sub; its return lets it run again. Normal mode only (turbo has no interrupts)
- 2026-10-11 Cls and scroll let interrupts in while they run (normal mode)
- 2026-10-11 `^` (whole number power), `IIf`, `Choose`, `StrComp`, `InStrRev`, `Replace`,
  `StrReverse`, `Oct$`, `Sqr` (whole number), `Mid$(s, start[, len]) = text`, `DoEvents`
  (a safe point in normal mode)
- 2026-10-11 `For Each x In array` (fixed, parameter or dynamic array, 1 dimension; `Next x`)
- 2026-10-11 `Property Let / Get` with arguments (`Bag.Item(3) = 42`, `Bag.Item(3)`)
- 2026-10-11 local arrays (not Static) are cleared on every call, as in VB
- 2026-10-11 `{label}` in #asm: a BASIC label / line number (`ld sp, {skip} / ret` jumps)
- 2026-10-11 arrays of a Type as parameters: one descriptor per field array
- 2026-10-11 `Like` (`*`, `?`, `#`, `[abc]`, `[a-z]`, `[!abc]`; case matters)
- 2026-10-11 `Option Compare Text` (per module: string compares, Like, InStr, InStrRev,
  StrComp, Select Case fold case through UCase$)
- 2026-10-11 `Format$(n, pattern)` (constant pattern: text before / after, `0` least digits,
  `#`, `,` groups of 3, `.00` printed as is - whole numbers), Integer and Long
- 2026-10-11 `Join(stringarray [, sep])`; `a() = Split(text [, sep])` into a dynamic String
  array (holds at most 16 parts or its biggest ReDim - no heap; more parts are dropped)
- 2026-10-11 warnings (shown in the GUI in yellow, `WARN` in cli.js): a Function called as a
  statement ("the result of F is not used")
- 2026-10-11 dynamic arrays of a Type (`Dim a() As T`, ReDim / Preserve / Erase on each
  field array); a String * n passed ByRef is padded again after the call
- 2026-10-11 listing / cross reference: every #asm line carries its BASIC file and line,
  thread comments carry the file name in projects with several files; a map of every
  generated label (kind, BASIC name, file, line) comes with each compile (`Save .map`,
  `cli.js --map=`); a generated label written by hand in #asm gives a warning ("write {v}")
- 2026-10-11 `LSet` / `RSet`; `String * n` padded with spaces / cut to n on every
  assignment and Input, starts as n spaces (also as a Type field and a local)
- 2026-10-11 tests: `vb_test5` (18, 2 files: #asm, Inp/Out, library class), `vb_test6` (18:
  Byte arrays, ReDim), `vb_test7` (16: Type / 2D array params, Long extras), `vb_test8` (5:
  AddressOf), `vb_test9` (34: ^, IIf, Choose, string functions), `diag1` / `diag2` (Error,
  Assert), `vbprint`, `hook`, `vb_test10` (2 files: For Each, Property args, local
  arrays, #asm label, Type array params, Like, LSet / RSet, String * n, Format$, Join,
  Split; 33 checks), `cmptext` (Option Compare Text) - all pass in both
  modes (hook: normal only)
- 2026-10-11 **asm keyword procedures**: a Sub / Function whose body is only `#asm` and
  doesn't use `{param}` / `{result}` becomes a keyword - `dw fn_name, args..., result` - no
  stubs, no body thread, no saved SP (Add3: ~90 T instead of ~205 T). `x = F(...)` stores
  straight into x. Not for AddressOf / Interrupt targets, `ld sp,` blocks, Property. Test
  `vb_test11` (17 checks)
- 2026-10-11 fix: `DoEvents` was dropped by the parser - now a safe point (`kw_irq`) in
  normal mode as documented
- 2026-10-11 `userguide.md`: language reference by topic (CPC BASIC manual style), with the
  differences from VB5 / VB6 at each keyword
- 2026-10-11 **platforms**: a platform file starts with `;@key value` lines (org, text form,
  screen set up, own interrupt handler, own stack, size) read by the compiler. New:
  `cpcfw` (CPC through the firmware: TXT / KM / SCR / MC / KL, real stack switch per call),
  `cpm` (CP/M .COM at #0100, BDOS 6 console, own stack, warm boot), `test` (port console for
  the harness). The library prints through `ntc_plat_putc`; byte text platforms get Print
  text as string pool strings instead of ZOSCII glyph words. `Ticks` goes through
  `ntc_plat_ticks`. `Interrupt` needs `;@irq` (CPC hardware only). `#If NTC` /
  `#If NTC_<platform>` predefined. GUI: platform list, Org empty = the platform's, platform
  saved with the project
- 2026-10-11 **platform classes** `lib/<platform>/StdIO.cls` and `System.cls`: join a
  project when named; methods are asm keywords (no call overhead), capability constants
  (CanPosition, CanClear, CanPoll, Rows ...; Platform, TicksPerSecond, HasHook ...). A
  project's own `StdIO.cls` replaces the platform's and the console statements (Print,
  Input, Inkey, Inkey$, Cls, Locate, Mode) call its methods (not inside StdIO itself)
- 2026-10-11 fix: on cpcfw a full-width line got an empty line after it (the program printed
  its own new line after the 40th char, but the firmware had already wrapped) - now the
  firmware wraps and a new line straight after a wrap does nothing; the hardware and test
  platforms do the same now (they used to leave the empty line too). The harness wraps like
  the firmware on cpcfw. Test `wrap.bas`
- 2026-10-11 shellsort.bas: up to 2000 numbers (Return = 2000, several seconds - stopwatch
  timing), a menu T = turbo / N = normal / X = exit to re-run, prints Ticks for normal runs
  (turbo has interrupts off on the CPC, so Ticks stand still there). 2001 numbers with
  CPC timing: turbo 11.7 s, normal 14.7 s (turbo 20% faster); matches WinAPE (AMSDOS
  Ticks 14.9 s, stopwatch about 16 s with the 1.1 s refill before the sort). (The first
  figures, normal 2.5 x turbo, came from the harness undercounting - see Testing)
- 2026-10-11 `bas/sievetime.bas` (build SIEVETIM): sieve to 8000 with a Byte array,
  passes (Return = 5), T / N / X, the key starts the sieve straight away. The same in Small
  C: `compare/smallc/` (sieve.c, SIEVEC.ASM - Small C's 8080 code in Z80 mnemonics, one for
  one, plus its runtime), copied to build/cpm. 5 passes with CPC timing: Small C 33.2 s,
  NTC normal 24.9 s, NTC turbo 17.5 s. Turbo vs normal by kind of program: factoring by
  trial division 8%, shell sort 20%, sieve 29% (short keywords show it most, divides least)
- 2026-10-11 **speed compared** (NTC.md section 3, programs in `compare/bench/`): sieve,
  sort, factor, loop, call, divide, string in NTC (turbo, normal), Small C (C3.0R1.1, its
  output as `B*C.ASM`), BBC BASIC (Z80) v5 (CP/M edition) and the sieve in hand Z80,
  timed with exact T-states and CPC microsecond timing. NTC normal 1.3-1.7 x Small C (calls
  0.95 x), turbo 1.4-2.6 x; 9-30 x BBC BASIC; the hand sieve 5.7 x NTC turbo.
  2026-10-12: also z88dk sccz80 (-O3; NTC turbo about the same: faster on sieve / sort /
  loop, slower on factor / divide) and SDCC 4.2 (1.5-3.7 x faster than NTC turbo:
  registers for variables and arguments). zsdcc not built (sources not reachable here).
  Same C source for both: `compare/bench/ansi/`
- 2026-10-12 `build/dsk/`: cpc.dsk, cpcmin.dsk, cpcfw.dsk (.BIN), cpm.dsk (.COM) - CPC data format
  CPCEMU images made by `test/gendsk.sh` (sjasmplus, then cpmtools dskform / cpmcp), checked with
  cpmls and a copy back; in regress. cpcmin.dsk: 161K of 178K used - a second disc (or leaving
  the self tests off) when the programs outgrow one
- 2026-10-12 files.bas / filestep.bas: Option RomEnable 7 for cpcmin too (Julian: FILES on cpcmin went to tape -
  the test only restarted AMSDOS for cpcfw)
- 2026-10-12 **three CPC platforms** (Julian): `cpcfw` full firmware, `cpcmin` minimal firmware (new:
  the cpc screen / keys / interrupts, the firmware kept alive and handed back for each firmware
  call - fs_fwon / fs_fwoff: #38 bytes, ei / di, NTC's handler, gate array mode + ROMs off, CRTC
  start; FileSystem as cpcfw; `System.Command(name)`: any ROM's RSX, no arguments), `cpc` no
  firmware (no files again). Option RomEnable for cpcfw / cpcmin. GUI, builds (5 platforms),
  harness (cpcrun firmware stand-ins), regress (fs_fw / fs_fw2 on cpcmin, fs_none on cpc,
  stdio.cpcmin), `bas/amsdos.bas` (build AMSDOS: Load / Save, an AMSDOS message, Mode 2 kept
  across a file call, ticks, drive B)
- 2026-10-12 `Option Stack address` (Julian): the real stack grows down from there; the caller's SP is
  saved and a return stub pushed so End still returns to the caller; ASSERT that it isn't in the
  program (or < 64 bytes above its end); warning on cpcfw for #A600-#BFFF. Options are all read
  first and applied in a fixed order: Stack, RomEnable, the program (Reserve: a check)
- 2026-10-12 cpcfw FILES checked in WinAPE: works (RUN", Option RomEnable 7). Option RomEnable now
  gives the ROMs HL = #ABFF (the usual AMSDOS value) instead of #B0FF; files.bas empties the key
  buffer before its last wait; bas/filestep.bas (FILESTEP, with RomEnable) and filestpn.bas
  (FILESTPN, without) go through the file calls one step at a time with a key between
- 2026-10-12 devices and volumes (Julian): a device is how files travel (TAPE, DISC), a volume
  is a drive - any name, tried when used, since neither AMSDOS nor CP/M can list them.
  `Devices` / `SelectDevice` / `CurrentDevice` (TAPE / DISC), `Volumes` / `SelectVolume` /
  `CurrentVolume`; `Volumes()` = known at start (A after Option RomEnable) + each volume used
  successfully (SelectVolume, or Load / Save with "C:NAME"); a program can loop A-Z to build
  it (CPC: RSX lookups, no disc access - shows what the DOS offers; CP/M: each try reads
  the drive, loop only on CP/M 3). Capabilities VOLUMES, CPMVERSION (BDOS 12; CP/M's
  Capability now runs on the real stack, `fs_capab`). Harness: RSX C and M (M4-like),
  folders per volume, BDOS 12 = CP/M 3
- 2026-10-12 FileSystem devices (first try, replaced the same day): `Devices()`, `SelectDevice(name)`, `CurrentDevice()`, capability
  DEVICES - cpcfw: AMSDOS's |TAPE / |DISC / |A / |B through KL FIND COMMAND + KL FAR PCALL;
  CP/M: BDOS 24 / 25 / 14 (error mode 255 first, so CP/M 3 reports a missing drive). Julian's
  report: cpcfw Save always went to tape - RUN" of a binary resets the firmware and drops
  AMSDOS. `Option RomEnable All | n [, n]` (cpcfw): the start code starts the ROMs again
  (KL ROM WALK / KL INIT BACK) unless AMSDOS still has the cassette calls (#DF at #BC77:
  CALLed from BASIC). Without the option nothing is started (RUN": tape; MEMORY &1FFF :
  LOAD : CALL &2000: AMSDOS kept). Harness: per device folders (TAPE, A, B / CP/M drives),
  AMSDOS's far call CAS entries (RST 3), `--called`. Tests fs_fw (RomEnable 7), fs_fw2
  (RUN": tape / --called: disc), devices in fs_cpm / fs_none; bas/files.bas uses
  `#If NTC_CPCFW` + `Option RomEnable 7`
- 2026-10-12 `Option Reserve start, size [, start, size] ...`: an sjasmplus ASSERT per range
  after `ntc_end` (the assembly stops if the program overlaps it, naming the range and the
  line); pairs and bounds checked by the compiler; a warning on cpc when #C000 is covered
  (the font copy code). In regress (one that fits, one that overlaps)
- 2026-10-12 **FileSystem class** on every platform (`lib/<platform>/FileSystem.cls`), the
  same methods everywhere: Load, Save, Delete, Exists, Rename, Size, Open, Close,
  ReadByte, WriteByte, Read, Write, Seek, Eof, ReadLine, WriteLine; results >= 0, status
  < 0 (NotSupported -1 ... BadMode -11), Open modes ForRead / ForWrite / ForUpdate.
  `Capability("NAME")`: one function for all capabilities (PRIMAL's SysPropertyPC idea):
  the value or 0 (`ntc_capfind` in ntc_lib.asm: a table of name + value, case ignored, Z
  set when found). CP/M: all of it (BDOS FCBs, random records, two handles). CPC
  firmware: Load / Save (CAS IN / OUT DIRECT - disc with AMSDOS, else tape). CPC hardware,
  test: none (NotSupported). File code runs on the real stack (`fs_go`). `VarPtr(name)`
  (variable or fixed size array address). Harness: BDOS file calls and CAS calls on real
  files (`test/t/files`). Tests `fs_cpm`, `fs_fw`, `fs_none` (both modes), demo
  `bas/files.bas` (build FILES); System.MaxHandles = 2 on CP/M
- 2026-10-11 the CPC platform uses the CPC's own font: the first mode set copies chars
  32-126 from the lower ROM (#3900) into ntc_font (now a RAM buffer, 760 bytes less per
  program), running the copy from #C000 (the program at #0040 can be under the lower ROM).
  cpcrun.py emulates the lower ROM for that (stand-in font: test/font_standin.txt)
- 2026-10-11 every program in bas/ ends with `Press a key` and waits (build/ results stay on
  screen); vb_test12's Input check now asks "Type 8 letters (only 5 fit)" and passes for any
  answer that was cut to 5; regress types the key, `~` in typed text = no key on that look,
  and a check now also needs the program to have ended
- 2026-10-11 `build/`: every program in `bas/` compiled for every platform (88 .ASM files,
  made by `test/genbuild.js`) and `build.bat` (MS-DOS) to assemble them all with
  sjasmplus: CPC as AMSDOS `.BIN` (compiler option `amsdos` / `cli.js --amsdos=NAME` adds
  `DEVICE AMSTRADCPC6128` and `SAVEAMSDOS`), CP/M `.COM`, test `.BIN`. Every program now
  ends with `ntc_end:`. regress.sh regenerates and assembles them all
- 2026-10-12 **arrays after the program** (not in the file; kw_bssinit checks they fit under
  the platform's top and clears them, else "GURU 001"; ntc_free is
  the first free byte); **List class** (handle-based linked lists in the heap, node pools,
  merge sort; every platform); **Private Paged** variables and local memory (LocalStart /
  LocalSize / LocalAlloc / LocalFree) in overlay classes. Demo LISTS; tests `list_t`, `pvar`
- 2026-10-12 List.Sort is now a radix sort (the merge sort took close to a minute for 5,000 nodes;
  now 4.2-4.8 s on a 6128). Demo SORTTIME (5,000 nodes, turbo and normal). `test/cpctime.py`
  times a program at the real CPC's speed (gate array stretching, interrupts every 3333
  microseconds). Found: turbo and normal differ by about 5% here - the List calls (about
  600 microseconds each) take most of the time. Next: faster List calls
- 2026-10-12 **Graphics class** (cpc, cpcmin): XOR lines in modes 0 / 1 / 2 with pens (one
  loop for every mode), Plot, Clip on / off, double buffering (#C000 and main RAM's #4000, the
  CRTC swapped at the flyback, RAM pages still usable: drawing puts main RAM in the window only
  while it writes), CopyText for text on both screens. Vector3D draws through it (each screen
  keeps its own lines to take off); CUBE3D keys A / B / C mode, D double buffering, T turbo.
  Measured (real CPC speed, the cube; corrected after cpctime.py got a real frame sync, see
  below): mode 1 7.7 frames a second whatever the screens or turbo, mode 0 8.5, mode 2 6.3 -
  two screens don't cost speed, they stop the flicker; turbo gives nothing here (93% of the
  time is in Z80 code). Test `gfx/lines.bas`
- 2026-10-12 **cpcfw interrupts**: the Interrupt statement and interrupt classes on cpcfw, through
  a firmware fast ticker event (KL NEW FAST TICKER, 300 a second, express + asynchronous, both
  ROMs off; KL DEL FAST TICKER at the end). The event block must be in the central 32K, so it
  sits at #A5F0 and Memory.Top is #A5F0 when interrupts are used. System.HasHook and the HOOK /
  INTERRUPTCLASSES capabilities True on cpcfw; INTERRUP built for cpcfw; regress checks isl,
  hook and the interrupts example on cpcfw. Tutorial: 9.1 overlays with Small, new 10.7 (text
  and records in nodes), 6.5 replacing / tailoring any library class, 5.3 when turbo gains nothing
- 2026-10-13 Page names are plain words (`Option Page Level1 = ...`, `Option Class Overlay
  Level1`, `Option Home Stars = Level2`): a name, not a file - the file is numbered; quotes with
  an extension pick the file (`"LEVEL1.PAG"`; quoted without an extension still works as a
  name). The block carries the page's name too: `Overlay not loaded: Stage1 (MAIN.002)`
- 2026-10-13 **Page files numbered** (Julian): `PROGRAM.001` ... `PROGRAM.999` (the program's
  name: GUI project name, genbuild NAME, `cli.js --name=`, else the main file's name), in page
  order; `"NAME.EXT"` keeps its own name. Two programs on a disc can't clash any more (the
  demo had renamed its pages to dodge OVERLAYS' LEVEL1/LEVEL2). Each page file starts with the
  build stamp (CRC-16 of the program text): a file from another build is refused, -14 (`The
  file is from another build`), both schemes, tested by keeping an old page file
  (`NTC_KEEPPAGES=1` in the harness). Harness and gendsk take the page names from the
  `OUTPUT` / `SAVEAMSDOS` lines
- 2026-10-13 **Pages** (Julian's design): `Option Page "NAME" = A, B ...` puts classes into a
  page together (one `.PAG`, loaded as one); a class in several pages is copied into each
  (every label it defines renamed `label__page` in the copies, its GOTO / GOSUB stubs and paged
  variables per copy); a class in no page is in main RAM; calls inside a page go through a
  local entry (no switch: about 60 T against about 320 T for a switch); calls from outside to
  a copied class use its home copy (first page listing it, or `Option Home Class = "NAME"`),
  or, with no paged variables, a copy whose page is in the window (`ntc_ovl_enterc`, copy
  tables). `Option Class Overlay "X"` = `Option Page "X" = ThisClass` (same name: same page).
  Blocks per page, so the one overlay area (cpm / Small) works by page. Layout: compile result
  `layout` (GUI messages, `cli.js --layout`), assembler `DISPLAY` sizes. Checks: unknown class,
  page declared twice, class twice in a page, empty page, bad Option Home, over 16K, page +
  interrupt class, `#asm` naming a copied class's thread labels; gendsk refuses two programs
  writing the same page file. A class in a page can have a Tick too (`Option Class Interrupt`
  in it: a driver - its page switched in for each Tick; RAM pages only, refused with one
  overlay area; checked on the real ROMs: 50 a second). Demo PAGES (cpcmin / cpcfw / cpm), test `test/pages/` (RAM pages
  and one area, both modes; checked on the real 6128 ROMs too), tutorial 13.6
- 2026-10-12 fix: **cpcfw interrupts never ran on a real CPC** (Julian: the interrupt demo
  crashed). The fast ticker event was express: the 6128 ROM's KL EVENT (#01E2) jumps straight
  to an express routine from the interrupt with the lower ROM on and ignores the far address,
  so the CPU ran ROM code at the routine's address (#07F3) 300 times a second. Now a plain
  asynchronous event (class #80): run at the end of the interrupt through KL FAR ICALL, which
  honours ROM select #FF. Found and checked with the real 6128 ROMs (`test/realcpc.c`, the
  floooh/chips emulator): clock exact (16 ticks in 16 s), Interrupt hook works. Patching RAM
  #0038 (Julian's idea) checked too: the lower ROM has its own #0038 (JP #B941), so 88% of the
  demo's interrupts never reach RAM #0038 (they come during firmware calls). cpcfw now sets
  the event only when the program uses Interrupt / interrupt classes (`;@irq 2`).
  **Graphics class on cpcfw** (ntc_smode kept by Mode); CUBE3D built for cpcfw (Spin an
  overlay, as on cpcmin) - checked on the real ROMs in modes 0 / 1 / 2, one and two screens,
  turbo. The harness missed both: its firmware stand-ins call any event routine as a plain
  call with the ROMs off
- 2026-10-12 fix (test tool): `cpctime.py` had no real frame sync - port B bit 0 toggled every
  50 reads, so `Frame` and the double buffer flip hardly waited and the CUBE3D frame rates were
  too high (8.4 / 9.5 / 6.7). It now follows the clock: a frame every 20 ms, the sync for its
  first 512 microseconds. Real waits found: about 10 ms a frame in Frame (one screen) and in
  the flip (two screens)
- 2026-10-12 **CUBE3D** demo (cpc, cpcmin): `bas/cube3d/Vector3D.cls` - 3D wireframe shapes
  in 8.8 fixed point, turned round X / Y / Z (sine table), perspective, XOR lines on the mode 1
  screen, all Z80 on the real stack with interrupts let in (normal mode) - ported from B.
  Chiha's TEC-1 demo (MIT, 2023; from The Amstrad User 69, 1990). `Spin.cls` is the demo: an
  overlay class on cpcmin (SPIN.PAG in a RAM page) calling Vector3D in main memory. About 10
  frames a second for the cube (the lines take most of it: drawn and taken off with XOR).
  Fix found on the way: an #asm block with `ld sp, (var)` (the real stack switch) was taken
  for a jump, so in normal mode every `ret` in it - its own subroutines' too - became
  `jp ntc_xn`; now only `ld sp, label / hl` makes a jump. Next: faster lines (8-bit error
  for short lines), double buffering (two screens, no erase flicker), filled faces
- 2026-10-12 fix: interrupt classes ran far too seldom on a real CPC (a 1 a second Tick about
  every 4 s, the Frame star every couple of seconds): drawing text held interrupts off for a
  whole Print (about 0.85 ms a character), so 3 interrupts in 4 merged into one, and a Frame
  class missed the sync when its interrupt was taken late. Text now lets a waiting interrupt
  in after each character (normal mode, on a small stack of its own), mode 0 / 1 / 2 draw with
  their own loops (mode 1 about 2x, mode 0 about 2.2x faster), and Frame counts 6 interrupts
  a frame, put back to 0 by the sync. Checked at the real CPC's speed (cpctime.py) in regress
- 2026-10-12 MEMMAP: both screens start with the RAM size, pages, 64K banks and model
- 2026-10-12 a block part that ends in another turbo mode than the block started in (Turbo On
  ... Turbo Off with the start mode set to turbo) is no longer an error: the compiler switches
  back to the block's mode at the end of that part, with a warning (a procedure still must end
  in its mode)
- 2026-10-12 **tutorial** (`docs/tutorial/`, 77 pages 1.1-14.4: the IDE, Hello World,
  calculations, flow, options, StdIO, System, FileSystem, Memory, List, classes, paging and
  overlays, overlay classes, interrupt handlers); `test/tutcheck.py` compiles every example and
  runs the ones that show output (in regress.sh). GUI: **AMSDOS .BIN** setting (CPC platforms:
  Save .asm assembles straight to NAME.BIN with its header)
- 2026-10-12 **System.HasCapability(name)** (COMMANDLINE, SCREEN, KEYBOARD, CLOCK, HOOK,
  INTERRUPTCLASSES, PAGES, FILES, ROMCOMMANDS, OVERLAYS) and **System.CommandLine** (CP/M: the
  command tail, copied aside by the start code when used; "" elsewhere). Demo CMDLINE;
  ntcrun `--cmdline=`. **Memory.ProgramStart / ProgramEnd / Top / StackTop**; MEMMAP draws
  main memory up to the top (the TPA end on CP/M) with the free RAM; OVERLAYS shows the room
  after each overlay
- 2026-10-12 fix: a Function called inside an expression overwrote the caller's temps when
  it used temps itself (`U(a) - U(b)` with a Long Function gave the wrong answer). Pass 1
  now notes each procedure's temps and, per call, the temps the caller still holds; pass 2
  puts the callee's temps above them (decideTempBases). Interrupt Ticks / hooks and AddressOf
  targets go above everything. Calls at the start of an expression cost nothing. Test `temps`
- 2026-10-12 fix: an Integer For loop to 32767 (or down to -32768) looped for ever - the step
  wrapped round; now the Next keywords see the overflow and end the loop (test `for_end`).
  The turbo / normal timing demos say `Option Turbo Off` (with the turbo setting on, their
  If ... Turbo On ... Turbo Off ... Else was an error); the mode error now names both modes.
  SORTTIME takes up to 32767 nodes (35000 overflowed the Integer and gave 5000)
- 2026-10-12 **one overlay area** for overlay classes on cpm and on cpcmin / cpcfw with
  Option Memory Small (64K CPCs): one class at a time at #4000-#7FFF, a call loads its class
  over the one there, a return loads the caller's class again if it was swapped out; Load /
  Unload from the area give -13; Paged variables stay in main memory there. CP/M .PAG files
  are plain bytes. OVERLAYS demo now also on cpm; test `ovls` (cpm, cpcmin, cpcfw, 64K)
- 2026-10-12 fix: overlay .PAG files had no AMSDOS header, so AMSDOS took them for text and
  CAS IN DIRECT didn't load them (OVERLAYS stopped, then RUN" reset). Now SAVEAMSDOS (AMSDOS
  builds) or a header written in the OUTPUT block; the harness's CAS calls now follow the
  header rules (headerless = ASCII, no IN DIRECT; CAS OUT writes a header); the failure
  message says why and waits for a key
- 2026-10-12 **Option NoTurbo**: normal mode only; Turbo On / Off do nothing (a warning), so
  code reached in both modes (procedures, branch keywords) is built once instead of twice. A
  program that never switches mode is unchanged (it is already built once). Shell sort 314 bytes smaller
- 2026-10-12 **Option Class Overlay ["FILE"] / Interrupt rate | Frame**: overlay classes'
  threads built into .PAG files in the same compile (OUTPUT / ORG #4000), loaded into C pages
  on the first call or with the added Load(), Unload / Loaded / Page; far-call stubs keep and
  restore the caller's page (cpcmin, cpcfw). Interrupt classes: 4 slots counted by the
  interrupt handler, Tick run at safe points (cpc, cpcmin). Demos OVERLAYS, INTERRUP; tests
  `ovl`, `isl`; build/dsk split into examples and tests discs per platform. Page types table
  in the user guide
- 2026-10-12 **Option Memory Small | CPCExpansion [maxpages]**: the scheme decided when
  compiling (`NTC_MEM_*` defines; library sections with `@if:` are only there when their
  #Const is set). Small = one heap over free main RAM on any platform (cpm and test now have
  Alloc / Free), about 900 bytes against 2,100; maxpages caps CPCExpansion and its fixed
  data (`NTC_MEMBANKS`). `Memory.WindowStart` / `WindowSize` constants, `HeapStart` /
  `HeapEnd`; new platform section `ntc_plat_memtop`. Tests `mem_s` (4 platforms, both
  modes), the caps, the refusal on cpm
- 2026-10-12 **Memory class up to 4MB**: 257 pages (16 bit page numbers), probe of 64
  banks over ports #7F-#78, a list per type (free low / free high / C / D / I / U, next
  table), C / I / U from main + the standard 512K first and D from the blocks above (each
  falls back), tables sized at run time from ntc_end (fewer pages when they don't fit),
  `Map(first, count)`, `TableEnd`, `ModelHuge`. Harness `--ram=4160`; tests at 4MB and with
  the tables near #4000
- 2026-10-12 **Memory class** (cpc, cpcmin, cpcfw; cpm stub, test has no pages): probes up
  to a 512K expansion (64K small 1 page, 128K medium 5, large up to 33), page types C / D /
  I / U / free, AllocPage / FreePage / SelectPage / CurrentPage / Map, heap in D pages
  (Alloc / Free / Largest, far pointers as Longs), ReadByte / ReadWord / WriteByte /
  WriteWord, Copy through the shared 2K buffer (`ntc_buf`, now also FileSystem's CAS
  buffer). Harness emulates the gate array RAM setting (`--ram=64|128|576`); tests `mem_t`
  (3 sizes, cpcmin, cpcfw, both modes) and `bas/memmap.bas` (MEMMAP in build/)
- 2026-10-11 **string lengths**: `String * n` (VB fixed length, padded) now n = 1 .. 255,
  new `String Max n` (NTC: at most n, not padded, 1 .. 255), default `String` stays 40.
  A capacity byte before every scalar string ([cap][text][0]); array elements cap + 1 bytes
  (stride passed to kw_sget / kw_sset / kw_strcpyn, or in the descriptor: kw_psets,
  Join, Split); params, results, Select values and temps hold the program's longest
  string (`NTC_STRMAX equ`, at least 40); kw_strcpy / kw_strcat / input cut at the
  destination; library functions build into temps, cut at NTC_STRMAX; call stubs copy
  strings with the same cut. Test `vb_test12` (33 checks)
- 2026-10-11 CPC builds (cpc, cpcfw) at org #0040 (AMSDOS binaries), was #4000; the
  harness loads at the program's org. Fix found by it: kw_printzoscii took any word below
  #0100 as a control word, and a small program's font can now sit there - only 0 (end)
  and 1 (new line) are controls now (test `tiny.bas`)
- 2026-10-11 CP/M `Option Terminal VT52 | ANSI` (Cls / Locate with the terminal's codes,
  `NTC_TERM` for the platform file, `NTC_TERM_*` for #If); tests `term_vt52`, `term_ansi`
- 2026-10-11 `#asm` naming a library label (not only a section) links that label's section
- 2026-10-11 test harness `test/ntcrun.py` (test / cpcfw / cpm on a plain Z80, firmware and
  BDOS handed to the harness); regress.sh runs every test on all four platforms in both
  modes (230 checks with the terminal, string length and tiny tests); `guitest6.py`

---
