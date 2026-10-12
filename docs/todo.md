# NTC - todo

Progress tracker for the NTC compiler. Move items from **todo** to **done** as they are
finished, with the date.

---

## done

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
  the platform's top and clears them, else "Not enough memory for the arrays"; ntc_free is
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
- 2026-10-12 **Option NoTurbo**: normal mode only, one copy of each procedure and branch
  keyword; Turbo On / Off do nothing (a warning). Shell sort 314 bytes smaller
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

## todo

### Language

- [ ] **`Interrupts` class - interrupt handlers as separately compiled frames** (decided in
      discussion 2026-10-11; replaces the `Interrupt MySub` statement).
      Background - how interrupts work now: keywords run with interrupts off; an interrupt
      is only taken at a safe point (`ntc_xn` window between keywords: branches in normal
      mode and `kw_irq` every 32 straight keywords) or inside the windows of long keywords
      (Cls, scroll, key wait, frame wait, host calls - all switch SP to `ntc_csp` first, so
      SP is always the real stack when an interrupt comes). The CPC handler (`ntc_irq`)
      only counts ticks and sets `ntc_hookpend`; `ntc_xnh` then runs the hook Sub as normal
      thread code at the next safe point; `ntc_hookon` stops it re-entering itself.
      Problems with running a BASIC Sub in the main program's frame (found 2026-10-11):
      1. temps (`tmpN` / `stmpN` / `ltmpN`) can be live across a safe point (`kw_irq` can
         land mid-expression) - the hook's expressions overwrite them
      2. BUG NOW: `kw_irq` can land between a compare and its branch (the compare counts
         as a straight keyword); plain `ntc_xn` keeps the flags, but with a hook the hook's
         code runs in between and the branch goes the wrong way. Fix even before the class:
         put `kw_irq` only at statement starts (or never between a compare and its branch)
      3. procedures / GOSUB targets called from both main code and the hook: one set of
         params, locals and one `_rs` return point each (no recursion), so the hook's call
         overwrites the main program's - the recursion check (call graph cycles) does not
         catch main + hook sharing
      Design:
      - the handler is a Sub compiled as its own FRAME: a third compile mode (`_i`) - the
        Sub and every procedure it calls get their own copies AND their own storage
        (params, locals, `_rs`, ByRef words), their own temps (`itmpN` ...), own GOSUB
        return points / stack. Shared with main: global / module variables only. Asm
        keyword procedures (body only #asm, no storage) need no `_i` copy - both sides call
        the same one. So a handler can be all BASIC, BASIC with #asm, or effectively all
        asm (`dw fn_x` + `dw kw_iret`, ~60-80 T over a raw asm handler)
      - running: an interrupt at a safe point between keywords -> the platform handler saves
        AF (fixes problem 2 for good) and the thread position, runs the frame's thread with
        interrupts off, `kw_iret` restores. An interrupt inside a long keyword's window ->
        only mark the frame pending, it runs at the next safe point (library scratch such as
        `ntc_ip`, `ntc_sptr` is in use mid keyword). Library keywords are shared code: safe
        because the frame only runs between keywords
      - placement: a frame is its own allocation unit, so it can be placed apart (a fixed
        address e.g. below #4000 on the CPC, a ROM, a bank that is never paged out, or left
        next to the program). An ISOLATED frame (music player, interrupt driven I/O
        buffers) gets its own copies of the library sections it uses, placed with it, so
        nothing it needs can be paged out (bank window, upper ROM / #C000 games) - an
        ORDINARY frame (game logic, timers) shares the program's library. Same mechanism,
        only placement differs. Fits the range allocator planned under Memory map (every
        jump between units already goes through stubs). A resident frame can outlive the
        main program (TSR style), found by a header
      - communication: a MAILBOX at the start of the frame: +0 command (0 = none), +2
        parameter, +4 status / reply (optionally a signature + version word in front). Main
        writes the parameter, then the command (inside one keyword, interrupts off, so the
        frame never sees half a command); the frame acts, writes the status, clears the
        command (= done, `Busy` = command <> 0). A ring of slots if commands can come faster
        than the frame runs. The caller only needs the frame's base address: a label (same
        build), `Option Frame <name> At #xxxx`, or found by signature (resident / ROM)
      - as a class, e.g. `Music.cls`: `Play tune`, `Stop`, `Volume v` (asm keywords that
        only write the mailbox, ~the cost of a Poke), `Busy()`, `Position()` (the status);
        the class's handler Sub is the frame. The same shape is the general interrupt
        driven driver class (e.g. Serial: the frame fills a receive ring, GetChar / Ready
        read it, Baud posts a command)
      - API sketch: `Interrupts.Every n, AddressOf Sub` (every n ticks, CPC EVERY),
        `Interrupts.After n, AddressOf Sub` (once, CPC AFTER), `Interrupts.Frame AddressOf
        Sub` (every vsync - 1 in 6 interrupts on the CPC), `Interrupts.Off`; a small fixed
        timer table; `Interrupts.Fast AddressOf AsmSub` for work that must run even inside
        long keywords' windows: strict rules - asm only, no library code (the compiler can
        warn when a handler's asm names a library label), short, save IX / IY (the platform
        saves the rest with exx / ex af,af' - nothing in the library uses the alternate set
        on the CPC hardware platform; the CPC firmware uses BC' itself)
      - `AddressOf` gives the stub for the mode at that line; a handler always runs in its
        own frame, so `Interrupts.*` must give the frame's entry, not a turbo / normal stub
      - platforms: cpc - the program owns #38, works directly. cpcfw - register the frame /
        Fast handler as a firmware event (KL NEW FAST TICKER, KL NEW FRAME FLY, KL ADD
        TICKER), with the pending rule. cpm / test - none (`System.HasHook` /
        `Interrupts.Available` False, using it is a compile error). Turbo mode: no
        interrupts, handlers only run in normal mode
      - rule for every platform handler, to write in NTC.md: the interrupt handler itself
        never calls library code - it only counts, marks pending, or runs a frame between
        keywords
      - then remove the `Interrupt` statement (or keep it as sugar for
        `Interrupts.Every 1, AddressOf Sub`); update hook.bas / ref, userguide 12, NTC.md
- [ ] FUTURE (CPC, main target): **library in ROM** - a second CPC build next to the RAM one
      (RAM only for now; keep this possible). Why: many CPC users have ROM boards (and the M4
      has ROM slots); the library is half to nine tenths of a typical program (measured
      2026-10-11: guide 2424 of 2806 bytes, guess 2490 / 2800, shellsort 2610 / 3832,
      vb_test 2815 / 6194; the whole library ~8 KB without normal copies, so 8-16 KB of RAM
      back as it grows). An NTC thread is already a tokenised program, so it is a BASIC
      interpreter's layout (keywords in ROM, tokens in RAM) without the interpreter loop.
      Plan (discussed 2026-10-11):
      1. ROM / RAM split first (see Memory map): library working storage at a fixed RAM
         address given by the platform file (like an interpreter's system variables), data
         with start values copied at start, nothing writes into library code
      2. a keyword number list: add-only, versioned (major = breaks compatibility, additions
         don't) - the contract between programs and ROM versions
      3. the NTC ROM: one 16K image (every section, turbo + normal copies, CPC platform,
         font), header (signature, version, count), export table (keyword number ->
         address, could be in PRIMAL style levels), a standard sideways ROM header with an
         RSX `|NTC,"PROG"` that loads, links and runs
      4. link at LOAD time, not through a jump table: the program file holds keyword numbers
         in the thread + a bitmap (1 bit per thread word: "this is a keyword number") + a
         short fixup list for code (stubs, #asm); the loader finds the ROM (scan slots for
         the signature), checks the version, writes the real addresses into the thread once
         - no run time cost. No register (IY) kept for it: the table is only read while
         loading (and IY belongs to the ROM on the Spectrum anyway). A RAM `jp` table
         (10 T per keyword) only for a thread that is itself in ROM and must work with any
         compatible core
      5. ROM missing / too old: a plain message (two builds, RAM and ROM, rather than one
         file with the library bundled - the program's layout is fixed at compile time, so
         a bundled fallback saves no RAM the program could use)
      Watch: the upper ROM covers the screen at #C000 - reads give the ROM, so scroll (the
      one routine that reads the screen) must use hardware scroll or a small routine copied
      to RAM that switches the ROM off around the copy; writes (glyphs, Cls) are fine. The
      #38 interrupt handler is in RAM and calls nothing - normal mode unaffected. On cpcfw
      the firmware switches upper ROMs during its calls, so the call wrapper must be in RAM
      and select the NTC ROM again. Test: cpcrun.py needs the gate array ROM enable bit, the
      #DFxx ROM select port and a ROM image in a slot, then the whole regression runs in
      "library in ROM" mode too. Later: the standard classes (StdIO / System - asm keywords,
      no storage) in the ROM as well; a cartridge style build (thread in ROM too, only
      variables in RAM - CPC Plus / GX4000 cartridges)
- [ ] FUTURE: `Option ClassSize <kilobytes>` - keep a class's code within a size so classes
      can be used as banking units. Accepted, not enforced.

### Decisions (2026-10-11, from Julian's notes)

- **No error handling. Never `On Error`, no exceptions.** It makes lazy programmers and runs
  slower; it would also need the thread return points tracked and unwound, which NTC does
  not do (SP is the thread, GOSUB stack is per target). Fallible routines return a status
  (Function result), the caller checks it. Convention to write down: 0 = ok, negative =
  error (or document per library). Diagnostics are a different thing and are wanted:
  an `Error` statement (print and stop), maybe `Assert`, maybe a trace
- **NTC gets File I/O, Graphics and Sound** - as libraries / platform drivers, not as
  language changes
- **I/O as classes, with `#asm` / `#endasm`** to write their hot paths
- **Classes stay syntactic sugar: one set of members per class** (this answers the old
  "copy per `Dim x As New`" question). Several instances are the class's own job, Amiga
  `serial.library` style: `h = Serial.Open(...)` returns a handle (an Integer index), every
  method takes the handle, the class keeps per instance state in its own arrays (or an
  array of a Type) and has a fixed number of slots. Singletons (screen, keyboard, sound
  chip, gate array) just use scalars. No vtables, no allocation, direct calls

### Classes as libraries (to check / add)

- [ ] decide: keep `Dim c As Counter` (it only aliases the one set of members) or make it an
      error now that classes are namespaces
- [ ] `CallAddr`: the arguments are not checked against the target's parameters (the
      compiler can't know it); recursion through `CallAddr` is not found either


### Libraries / drivers (as classes)

- [x] File I/O, first step (2026-10-12): FileSystem class - CP/M full, CPC firmware
      Load / Save, none on CPC hardware and test (see done)
- [ ] FileSystem, next:
      - `Capability` with a literal name folded when compiling (the platform is known), and
        the If on a constant dropping its dead branch; in an `If`, the flag form (Z = true,
        PRIMAL style) straight into the branch with no value stored
      - `Capability` for `System` and `StdIO` too, in place of the CanPosition / HasHook ...
        constants (one pattern for every platform class and later drivers)
      - CPC firmware: SEQUENTIAL through CAS IN CHAR / CAS OUT CHAR (one file in, one out),
        DELETE / RENAME through AMSDOS's |ERA / |REN (RSX, only with AMSDOS)
      - [x] CPC hardware with the firmware for files: done as the cpcmin platform (2026-10-12).
        An own FDC (uPD765) driver for `cpc` - later, if ever
      - cpcmin: check in WinAPE (AMSDOS test); messages on/off as an option (CAS NOISY #BC6B
        for tape, AMSDOS's #BE78 = #FF for disc errors); System.Command with arguments
      - CPC (cpcfw / cpcmin), later: a directory listing (CAS CATALOG / |DIR print to the screen;
        names back into the program needs more); Delete / Rename via |ERA / |REN once Command
        takes arguments
      - MSX: the cpm build under MSX-DOS 1 / 2 (BDOS-compatible: console and FCB files) - try
        it, check Option Terminal VT52 there (cursor ESC Y; clear screen may be Ctrl-L);
        an `msx` platform through the MSX BIOS (CHPUT, CHGET, CHSNS, POSIT, CLS) for
        programs without MSX-DOS
      - check on a real CPC / WinAPE: CAS calls with IY as NTC leaves it (AMSDOS is believed to
        load its own IY), tape messages, disc errors (Retry / Cancel) mid-load; that AMSDOS's
        CAS IN OPEN entry really starts with #DF (the "AMSDOS is running" test); the
        |TAPE / |DISC / |A / |B calls through KL FAR PCALL; Option RomEnable 7 after RUN"
      - CPC: CurrentDevice when CALLed is "DISC" - AMSDOS's current drive could be read from
        its workspace (needs the layout)
      - third party mass storage (IDE, SD card interfaces: random access) - needs research,
        not Amstrad standard; possibly later, as their own FileSystem variants
      - CPC firmware: the 2K buffer CAS IN / OUT OPEN need is in the program now (`fs_buf`);
        a way to put it elsewhere, often #C000 (the screen) - e.g. `Option FileBuffer &HC000`
        (an equ the platform file tests: no `ds 2048` then), checked against the program
        like Option Reserve
      - cpc (no firmware): `End` that resets (`rst 0`) instead of returning, for programs that use
        the firmware's / BASIC's RAM (#A700-#BFFF) - there is nothing intact to return to then
      - Option Reserve: lay the program out around a range (skip it between sections) instead
        of only stopping the assembly
      - `Option Files n` for MAXOPEN (now fixed at 2 on CP/M), VB style statements
        (`Open ... As #n`, `Print #`, `Line Input #`, `Close #`) as a front on the class
      - Spectrum +3 = +3DOS; later a simple NTC file system
- [ ] Graphics (CPC): Plot, Draw / Line (Bresenham), Circle, Fill, Point (read), Ink /
      Paper / Pen / Border, sprites (masked, pre shifted). Screen address: row * 80 +
      (line in char) * #800 + x bytes; inks and border are gate array (#7Fxx), not the CRTC
- [ ] Sound (CPC AY-3-8912): reached through the PPI, not directly: PSG data on PPI port A
      (#F4xx), PSG control on PPI port C (#F6xx: #C0 = select register, #80 = write, #40 =
      read, #00 = inactive), PPI port B is #F5xx (vsync etc.). Registers 0-5 tone, 6 noise,
      7 mixer, 8-10 volume, 11-12 envelope period, 13 envelope shape, 14 = keyboard row in
      (shared with the keyboard scan - sound and key scans must not interleave). Sound /
      Envelope / Volume / Noise; music player from the interrupt (ties to the interrupt hook)

Note on the source notes (AI written): several Z80 examples in them are not valid Z80
(`add hl, a`, `ld de, hl`, `in a, (c)` with the port in HL), they treat parameters as
pointers (they are values), they put PSG ports at #F5 / #F6 directly and inks on the CRTC.
Corrected above.

### Direction (2026-10-11)

Focus is the language. Not a new system now. Later goal: code the rest of a cool OS in this
BASIC dialect.

### Targets

- [x] console on CPC firmware and CP/M (2026-10-11, platforms `cpcfw`, `cpm`)
- [ ] more hosts: ZX Spectrum, then more (the PRIMAL target list is the guide)
- [ ] file devices as classes (Disk / RamDisk / Printer / Serial, the standard set
      MaxFiles / Ready / CanRead / CanWrite / CanSeek; `Open ... As #n` and `Print #n`
      onto them; handles from `Option Files n`; status, not errors). `Print #n` needs byte
      text on every platform, glyph platforms included
- [x] CP/M: `Option Terminal VT52 | ANSI` (2026-10-11) gives Cls / Locate, CanPosition /
      CanClear / Rows follow it
- [ ] CP/M: more terminal types (ADM-3A ...) if wanted; Ticks from the CP/M 3 clock where
      there is one
- [ ] an If on a constant (StdIO.CanPosition ...) could drop the dead branch instead of
      jumping over it
- [ ] `Option CPM`, `Option <target>` ... for target specific things, or loadable drivers /
      libraries (like PRIMAL modules) that applications in this dialect use
- [x] host calls (BDOS `call 5`, firmware) on a real stack: `ntc_fwcall` / `ntc_bdos` switch
      SP to `ntc_csp` for the call only, the thread never sees call / push (Julian OK'd the
      firmware / CP/M platforms, 2026-10-11)
- [x] CP/M: org #0100, page zero is CP/M's, exit with jp 0, console through BDOS
- [ ] CP/M files through BDOS FCBs (with the file device classes)
- [ ] Spectrum: ROM at #0000-#3FFF (IM 1 handler is in ROM), screen at #4000 (attribute
      layout, 32x24 text), keyboard ports #xxFE; 128k paging at #C000 only

### Memory map (ROM / RAM / banks)

- [ ] `Option RAM <from>-[<to>][, ...]` and `Option ROM <from>-<to>`. No options: as now (all
      RAM from Org). With ROM: code, thread, library code and read-only data go in ROM; variables,
      temps, library data, `_rs` / `_a` words, GOSUB stack go in the RAM ranges (first range
      that fits). Error when something does not fit
- [ ] split every library / platform section into code and data (53 data labels sit inside
      code sections now, e.g. `ntc_tabcol`, `ntc_pidx`, `ntc_kprev`); data with a start value
      gets a copy in ROM and an ldir to RAM at start, the rest is zeroed
- [ ] CPC: code in upper ROM (#C000) over the screen at #C000 is a FEATURE (Julian): the
      code runs from ROM with its own sprite / font / table data in ROM, and its writes to
      #C000-#FFFF go straight through to screen RAM - 16k of code + data and the full 16k
      screen at the same addresses, no address games. What to design around: from that
      code the screen is write only (reads give the ROM). So plain sprite / text output,
      fills and hardware scroll (CRTC R12/R13) work as they are; anything that reads the
      screen (copy scroll, XOR / masked sprites that read the background, Point) needs a
      routine outside #C000 that turns the upper ROM off for the read, a shadow copy of the
      background in RAM, or drawing into a back buffer at #4000 / #8000 and flipping the
      screen base
- [ ] if reading RAM under a ROM is needed: a keyword / library routine that copies x bytes
      from under the ROM into a shared RAM buffer (ROM off, ldir, ROM back on). It must sit
      outside the ROM area it switches off. (The firmware has RAM LAM - RST 4 at #0020,
      `ld a,(hl)` with the ROMs off - one byte per call; a block copy is better.) Graphics /
      I/O classes are decided when we get to them
- [ ] decide where the start stack (`ntc_csp`) lives when there is a ROM option
- [ ] FUTURE: `Option RAMBanks <from>-<to>` (CPC 6128 #4000-#7FFF window), with
      `Option ClassSize` as the banking unit. Do not shoot ourselves in the foot meanwhile:
      the allocator works on ranges, nothing may assume code and data are next to each other,
      and every jump between code sections goes through a stub (GOTO stub, call stub) so a
      bank switch can go in the stub later
- [ ] keep the compiler's memory model like PRIMAL's memory table (`type, from, to` records:
      RAM, pageable, video, reserved, ROM) so `Option RAM / ROM / RAMBanks` and a platform's
      defaults all become the same list, and a PRIMAL target could hand its table over later
- [ ] the platform file gives the defaults: usable RAM ranges, screen, start stack, bank
      window and bank port list (CPC: from primal/src/ams_*.asm)

CPC memory facts to design against (Julian has more ideas to add later):

- gate array port #7Fxx, value bits 7-6: `00` pen select, `01` colour, `10` screen mode +
  ROM enable (bit 2 = lower ROM off, bit 3 = upper ROM off, bit 4 = interrupt counter
  reset), `11` RAM config (6128 / expansions). Upper ROM number: port #DFxx
- RAM configs (low 3 bits, CPU view of #0000/#4000/#8000/#C000): C0 = 0,1,2,3 (normal),
  C1 = 0,1,2,7, C2 = 4,5,6,7, C3 = 0,3,2,7, C4-C7 = 0,n,2,3 with n = 4..7 (the #4000
  window). Bits 5-3 = which 64k of an expansion (see PRIMAL notes above)
- ROM over RAM: with a ROM on, reads come from ROM, writes go to the RAM under it (lower ROM
  #0000-#3FFF, upper #C000-#FFFF). So screen writes work with the upper ROM on, screen reads
  (scroll) do not
- the video always reads the base 64k (banks 0-3), whatever the RAM config. The screen can
  be at #0000 / #4000 / #8000 / #C000 (CRTC R12 bits 5-4), 16k. A screen at #4000 clashes
  with the C4-C7 bank window (the CPU sees the extra bank there, the video still shows bank
  1) - so with banking the screen stays at #C000 or #8000
- hardware scroll (CRTC R12 / R13 start address) instead of copying: no screen reads, so it
  works with code in the upper ROM; text output then has to follow the moving start address
- #0000-#003F: restart vectors, #38 = interrupt (IM 1); with the lower ROM on, #38 is read
  from ROM - NTC turns ROMs off and puts its own handler at #38
- code running in the bank window can not switch its own bank: bank switch stubs and the
  keywords that do it must be outside the window (e.g. #0040-#3FFF or #8000-#BFFF)
- ideas for banked NTC: thread + keywords of a class in one bank, a GOTO / call stub to
  another class = `ld bc, port / out (c), c / ld sp, target / ret` (stub outside the
  window); data arrays in banks reached by bank switching keywords (aget / aset with a
  bank); a copy buffer outside the window for bank to bank copies, like PRIMAL; interrupts
  must not change the bank (or must put it back)

Whole 64k switching (Julian's tip, CPC specific - FUTURE, NTC and / or a PRIMAL / CP/M idea):

- one OUT can swap the whole 64k (config C2 = banks 4,5,6,7 of an expansion block:
  #7FC2, #7FCA, #7FD2 ... and the lower port high bytes over 512k). The code keeps running
  at the next address in the new 64k, so that address must hold the same code in every 64k
- fastest context switch: every 64k has the same switcher at the same address:
  `ld (save_sp), sp / out (c), c / ld sp, (save_sp) / ret` - save_sp is at the same address
  in each 64k, so after the OUT it reads the new system's SP. Each system's stack holds its
  own registers. Full 64k programs, not just 16k banks
- set each 64k up first through the 16k window (C4-C7 style configs), then switch to it
- idea: up to 8 systems (Ctrl+1 .. Ctrl+8), Ctrl+9 a CLI, Ctrl+0 a monitor. Keep the base
  64k for the switcher / drivers / screen ("hypervisor") and put the 8 systems in a 512k
  expansion: 8 blocks = 8 systems
- the video only shows the base 64k, so a system in C2 can not draw on the real screen.
  C1 = base 0,1,2 + the block's bank 7 at #C000; C3 = base 0, base 3 at #4000, base 2,
  block's bank 7 at #C000. So the base code can reach each system's top 16k (C1), and a
  system's #C000 copy can be ldir'd to the real screen at #4000 (C3). Better for text
  systems: console output goes to the base code, which keeps an 80x25 text buffer per system
  and redraws on a switch
- the interrupt handler (#38) and the switcher must be in every 64k at the same address;
  lower ROM off (CP/M needs RAM at #0000)
- shared hardware (FDC, printer, serial): switching from the interrupt in the middle of a
  disk access breaks it - drivers live in the base 64k with a lock, or switching only
  happens at safe points
- other machines: MSX2 memory mapper (ports #FC-#FF, one per 16k page) can swap all 4 pages
  with 4 OUTs - switch the 3 pages the code is not in first, the code's page last (same
  rule: next address must match); some mappers can not be read back. Spectrum 128 only
  pages #C000 (#7FFD); +2A / +3 special all RAM modes (#1FFD) give 4,5,6,7 - two 64k at most

- Julian's model: context switch = push all registers on the current 64k's stack, swap
  banks, pop all registers, ret. Round robin from the interrupt, so every system keeps
  running behind, not just the visible one
- each system opens an 80x25 text screen by default (2000 bytes each). Writes when not
  visible only update the buffer; the visible one also updates the real screen at once; a
  switch redraws from the buffer. Keyboard: the selector keys are always watched, only the
  visible system gets the other keys
- the base 64k holds the real device drivers; reaching them from a system is a bank switch

CP/M compatible (or mostly) system idea - device model, not decided:

- CP/M 2.2: logical CON: RDR: PUN: LST: mapped by the IOBYTE (#0003) to physical TTY: CRT:
  BAT: UC1: / PTR: UR1: UR2: / PTP: UP1: UP2: / TTY: CRT: LPT: UL1:. Page zero: jp WBOOT at
  #0000, IOBYTE #0003, drive #0004, jp BDOS #0005, FCB #005C, DMA #0080, TPA from #0100
- CP/M 3: named character devices in a device table (up to 12, DEVICE command, baud rates),
  banked BIOS, disks through XDPH
- a way: programs see CP/M 3 style named devices (and the IOBYTE for 2.2 programs); behind
  them a driver table in the base 64k, each driver a module (init, status, in, out, ioctl).
  New hardware (serial, network, SD / M4) = more named devices or drives. New for multi
  system: pipes between systems (system 1 LST: -> system 2 RDR:)
- most CP/M programs only use BDOS calls; the ones that call the BIOS or hardware directly
  are the compatibility risk. DDT uses RST 38h for breakpoints, which is the IM 1 interrupt
  address

### Memory class - next (design talk 2026-10-12)

- [ ] `FileSystem.LoadPage(name, page)`: load into a page through the window, cut at the 16K
      boundary and carry on in the next page (files over 16K)
- [ ] check in WinAPE that the firmware / AMSDOS leave the RAM setting alone during a file
      call on cpcfw / cpcmin (a load into a selected page); if not, re-select from `mem_cur`
- [ ] interrupt handler: when I blocks or paged code exist, switch to a private stack, call
      each I block (with a divider: every 6th interrupt = 50 Hz), put the page back from
      `mem_cur`. Nested di / ei count (PRIMAL style); the handler sets it to 1, ei; ret at
      the end
- [ ] AY music player class as an I block (player + tune in main RAM out of the window;
      Stop flag, load a new tune, Play). Keyboard scan moves into the interrupt (the AY and
      the keys share the PPI)
- [ ] pageable classes: compiled at #4000 into a C page, called through a stub outside the
      window (save page, switch, run, switch back); strings returned land outside the window
- [ ] compiled sprites in C pages: the compiler packs sprite data into a 16K page image with
      an address table at #4000 (same layout for every level's file, so the class code works
      with any loaded set); one page switch per Draw of all instances; PUSH drawing with
      interrupts off; inline next-line step; 2 / 4 / 8 shifted copies per mode; skip
      transparent bytes, masks for partial ones; clipping / erase choices
- [ ] code past the window: the compiler continues the program at #8000 when it reaches #4000
      (a thread jump over the gap), so a big program can still page
- [ ] library jumpblock at #8000 (shared build mode): fixed 3 byte slot per library keyword,
      RAM or ROM targets, version check; standalone build stays the default (no extra 10 T)
- [ ] ROM pages (upper ROM at #C000, port #DF) as their own class: sprites from ROM write the
      screen under it; no screen reads while the ROM is in
- [ ] virtual memory: whole 16K pages to SD / CompactFlash / USB (or floppy). Per page:
      resident, changed (set by WriteByte / WriteWord / Copy / SelectPage of D or U), the
      file it came from; C pages and U pages loaded from a file are never written back.
      Least recently used order in the type lists. One file per page (`P0012.PAG`) works
      with AMSDOS now; a swap file with 16K slots needs random access (M4, IDE, USB)
- [ ] overlay classes, next: `Implements` (an interface class; several files built against
      it, `ILevel.Load("LEVEL" & n)` swaps the file behind it - a jump table at #4000 in
      each); stand-alone DLLs on the library jumpblock; overlays on cpc (no files: put them
      after the program in its file and copy them into pages at start?); library keywords
      used only by an overlay inside its page; a warning when overlay classes call each
      other (64K reloads)
- [ ] List, next: faster calls (GetWord / NextOf as plain keywords without mem_go and the
      argument checks); fields as Strings; a node of another list or a deleted one isn't
      caught; Memory.SavePage / LoadPage (a data page out to a file and back)
- [x] decided 2026-10-12: CP/M builds never page (no gate array writes, Small only, overlays
      through BDOS file reads). SymbOS runs CP/M programs in memory it manages, on the CPC,
      MSX, Enterprise 128 and PCW, so one bank-free .COM with its .PAG overlays runs on all of
      them, as on real CP/M and MSX-DOS. (Notes kept in case a CPC-only CP/M build is wanted:
      CP/M 2.2 runs in C0 like AMSDOS; a RAM disc's 512K is found by a CP/M directory in the
      expansion RAM, not by drive letter - M: may be an M4 / XMAS drive; the probe must save and
      put back what it writes. CP/M Plus runs in C2: every page setting swaps all four blocks.)
- [ ] cpm: the start code checks the TPA reaches #8000 when there are overlay classes (a clear
      message instead of a crash on a small TPA / SymbOS window); find out which BDOS calls
      SymbOS has (random records 33-36 for Seek)
- [ ] the Small heap uses the RAM on both sides of a reserved range (with overlays it stops at
      #4000 now, wasting #8000 up to the BDOS on CP/M)
- [ ] overlay classes: reusing a C page when none is free (CPCExpansion on 64K - the Small
      overlay area is done); Paged variables saved across swaps in the overlay area
- [ ] interrupt classes, next: Tick in a page (I pages, a paged interrupt class); asm-only
      Ticks run inside the interrupt itself (music players: no wait for a safe point);
      cpcfw (firmware frame flyback / ticker events); flags kept across a hook / Tick run
      at a safe point (a compare then kw_irq then a branch); harness vertical sync timing
      (it toggles per read, so Frame classes run in bursts there)
- [ ] check the 4MB ports (#78-#7E, A10 low) against other expansion hardware in WinAPE

### Turbo / normal

- [ ] long string work and Long divide still hold interrupts off while they run (short:
      40 chars, 32 steps); Cls, scroll and Mode let them in

### Optimisations

- [ ] cpcfw: a Tick waits for the end of a statement, and the firmware's text takes about
      3.4 ms a character, so a Frame class that prints, beside a main loop that prints, runs
      20-25 times a second (two dues in one Print run as one). Options: a due count instead
      of a flag (catch up - right for game logic at a fixed rate, wrong for "once a frame"),
      or NTC's own glyph drawing on cpcfw (about 0.4 ms a character on cpc)
- [ ] cpcfw End resets the machine straight away (RUN" programs): the last screen is gone
      before it can be read - wait for a key, or go back to BASIC when CALLed?

- [ ] Double buffering without the wait: the flip waits for the sync and then sets R12, about
      10 ms a frame doing nothing in CUBE3D. The CRTC takes R12 at the start of the next frame
      wherever it is written, so the flip can set R12 at once and the program wait only before
      it draws on the other screen - and the next Turn (about 32 ms, longer than a frame) runs
      in between, so no wait at all. CUBE3D: about 7.7 -> 8.4 frames a second. Check the CRTC
      types (1 is said to differ on R12 / R13 mid-frame). One screen: `Frame` before the draw
      costs the same 10 ms and can't stop the flicker (the draw takes about 4 frames)

Background (NTC.md section 3, 2026-10-12): one pass of the sieve's inner loop is 366 T in
NTC turbo against 107 T for SDCC. The work itself is the same (110 T against 107 T); the
rest is NTC's: variables loaded and stored in memory by every keyword (115 T), operand
addresses popped from the thread (90 T), and the `ret` / `jp` between keywords (51 T).
Normal mode adds about 90 T per branch (`ntc_xn`). Each item below cuts one of these.
Generic first: they help nearly every program. Gains are estimates from keyword T counts -
measure each with the bench set (`compare/bench/`) before and after.

- [ ] **For loops, counter not used**: if the body and the code after the loop never read
      the loop variable, use a hidden down-counter: one keyword `dec` 16 bit + branch if not
      zero (about 45 T) instead of `kw_next1l` (about 120 T: inc in memory, load, signed
      compare with the limit). If the variable is read after the loop, set its final value
      once at the exit
- [ ] **For loops, Step 1 / -1, constant limit**: the loop always ends at exactly limit + 1
      (limit - 1), so the end test can be "equal to" (two byte compares) instead of signed
      <=; one check on entry that the loop runs at all. About 30-40 T per pass, nearly every
      For loop
- [ ] **Loop rotation**: `Do While c ... Loop` / `While ... Wend` / `Do Until`: test at the
      bottom (one jump to it on entry) instead of test at the top + jump back: one branch
      keyword per pass instead of two. About 20 T turbo, about 110 T normal (the jump back
      also went through `ntc_xn`)
- [ ] **Merged keywords for common pairs** (pattern match on the thread, one keyword for
      two): compare + conditional branch ("jump if var > literal" etc.: about 40 T - every
      If and loop test); array read + compare (`If f(i) = 1`: no temp written and read
      back); `x = x + y` / `x = x - y` with the same target (one pop and one address load
      fewer, about 25 T); literal values inline in the thread instead of a pointer to a
      constant (`f(j) = 0`: about 7 T). Pick the pairs by counting them in bas/ and the
      bench programs
- [ ] **Normal mode: interrupts on every 4th branch**: a counter at the branch (`dec`, skip
      unless zero, about 20 T) and the full `ntc_xn` window only every 4th time. Interrupts
      still get in every few hundred T; normal mode's extra on tight loops from 55% to about
      15%. Check the worst case latency against the CPC's 300 Hz interrupt (it waits for an
      ack, two missed in a row lose one)
- [ ] **Constant shortcuts in maths**: `x \ 2^n` -> shift, `x Mod 2^n` -> `And` (sign fix for
      negatives, or only when known positive, e.g. a loop counter); `x * 2^n` and small
      constants (`* 3`, `* 5`, `* 10`) -> shifts and adds (SDCC does `i * 5` this way);
      divide by a constant below 256 -> an 8 bit divisor routine
- [ ] **Faster 16 bit divide**: z88dk's and SDCC's are 1.6-1.85 x faster (`divide`, most of
      `factor`). Unrolled loop; a quick path when both values fit in 8 bits. Every `\`,
      `Mod`, `/`
- [ ] **Thread-level inlining** of small BASIC procedures: copy the procedure's thread into
      the caller with the arguments put in directly (`s = Add2(i, 3)` ->
      `dw kw_add, var_i, lit_3, var_s`): no call stub, no argument copying, no return
      point. Only for small procedures (thread size grows per copy); a ByVal parameter that
      is assigned needs a temp copy of the argument; each copy needs its own locals (or safe
      sharing - no recursion, so possible); a Function's result goes straight to the
      caller's target. SDCC is 3.7 x faster on calls
- [ ] **Keywords made for one site** (fabricated by the compiler, like the loop jump-back
      `do4_t_go` already is): the statement's addresses and constants built into the code
      (`ld hl,(var_j) / ld de,(var_i) / add hl,de / ld (var_j),hl / ret` = 73 T against
      `kw_add` 119 T), the thread still one `dw`. No pops, no loads through pointers. Sieve
      inner loop about 366 T -> 220 T. Costs 10-15 bytes per site against 6-8 bytes of thread:
      inner loops only, or an option per procedure
- [ ] **Whole loop body as one piece of code** (the step after site keywords): the loop's
      variables loaded into registers once (`j` in DE, `i` in BC) and stored back on exit,
      the body straight code - native code for that loop, about SDCC's 107 T for the sieve,
      the rest of the program still threaded. Only for loops whose body the compiler can do
      this way (no calls, few variables)
- [ ] **Call stub - look at the whole procedure** (like the old single stack allocation for
      all Dims): today each local is cleared on its own (`ld hl,0 / ld (var_i),hl / ld hl,0 /
      ld (var_j),hl`, an `ldir` per local array). Lay a procedure's locals out together and
      clear them in one block (one `ldir`, or `ld (nn),hl` with HL loaded once); skip locals
      that are always assigned before they are read (the sieve's `i` and `j`: no clear at
      all - VB's "locals start empty" only matters for a local read before written); a ByVal
      parameter never assigned in the procedure can read the caller's value, no copy.
      Cheaper argument passing for small procedures (registers for one or two Integers)
- [ ] `x++` / `x--`: `kw_inc` / `kw_dec` are already about as fast as a separate keyword can be
      (31 T usually); gains only when folded into a bigger keyword (a loop's own step)

### GUI

- [ ] FUTURE: formRenderer for project forms (structured form creator)

### Testing

- [ ] test on a real CPC (both modes, Turbo On / Off)
- [ ] ntcrun.py counts 1 T per instruction while stepping to deliver an interrupt (up to
      2000 steps per 13333 T block, every block in turbo): its `T=` and the test platform's
      Ticks are too low, turbo most. The z80 module reports no T-states for one step - needs
      a T-state table (the scratch timing script used for the WinAPE comparison has one,
      with CPC microsecond timing too)
- [ ] `asm/ntc_plat_test.asm` is left over from the removed Python harness - delete?

---

## possibly future

- [ ] `ReDim` with bounds from variables - needs a heap (or a declared most size). Not now
- [ ] Overflow is not checked (Integer and Long wrap). With no error handling this stays,
      write it in NTC.md as the rule
- [ ] 3+ dimension array parameters (not planned unless needed)
- [ ] `Format$` with dates / text patterns (`@`, `>`, `<`), `%`; Split's most parts (16)
      could be an option
