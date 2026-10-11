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
  0.95 x), turbo 1.4-2.6 x; 9-30 x BBC BASIC; the hand sieve 5.7 x NTC turbo
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

- [ ] File I/O: CP/M = BDOS + FCBs (needs the real stack switch); CPC bare = direct FDC
      (uPD765) and an own or AMSDOS compatible disc format, CPC host = AMSDOS CAS_* calls;
      Spectrum +3 = +3DOS; later a simple NTC file system
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

### Turbo / normal

- [ ] long string work and Long divide still hold interrupts off while they run (short:
      40 chars, 32 steps); Cls, scroll and Mode let them in

### GUI

- [ ] FUTURE: formRenderer for project forms (structured form creator)

### Testing

- [ ] test on a real CPC (both modes, Turbo On / Off)
- [ ] speed: the 16 bit divide (most of `divide` and `factor`), and the call stub (Small C's
      plain call / ret is as fast as NTC normal) - see NTC.md section 3
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
