# NTC - Native Threaded Code

(c) 2026 Cyborg Unicorn Pty Ltd - MIT License

What NTC is, how the NTC BASIC compiler works now (VB5/VB6 style front end, turbo and
normal modes, project explorer), and the language it takes. Progress is tracked in
`todo.md`. The full language reference, keyword by keyword, is `userguide.md`. These three
are in `docs/`; file and folder names in them (`js/`, `asm/`, `bas/`, `test/` ...) are in `src/`.

---

## 1. What NTC is

NTC uses the Z80 stack pointer as the instruction pointer. A program is a thread: a list of
words, each one the address of a keyword (a machine code routine), followed by that
keyword's arguments.

```
main_thread:
        dw kw_ltov, 10, var_x          ; x = 10
        dw kw_printint, var_x          ; Print x
        dw kw_stop
```

The rules:

- **SP = instruction pointer.** `ret` jumps to the next keyword (10 T).
- **No call. No push.** A keyword pops its arguments off the thread, left to right (10 T
  each), does its work, and ends with `ret`.
- **No firmware** on the CPC hardware platform: I/O goes straight to the hardware. Host
  platforms (CPC firmware, CP/M) call the system for the console only, on the real stack
  (see Platforms in section 4).
- **Shared routines** are entered with `jp` and the return address in IX, and end with
  `jp (ix)`. `ntc_next` is a plain `ret`, so `ld ix, ntc_next` continues the thread.
- **The thread stays word aligned.** Text is ZOSCII: each character is a word pointing at
  an 8 byte glyph bitmap, never a byte string. On the CPC the glyphs are the CPC's own font:
  the first mode set copies chars 32-126 from the lower ROM (`#3900`) into `ntc_font`, running
  the copy from `#C000` because the program (at `#0040`) can sit under the lower ROM.

  ```
  dw kw_printzoscii, glyph_48, glyph_49, 1, 0   ; "HI" newline, end
  glyph_48 equ ntc_font + (#48 - 32) * 8
  ```

- **Compares** set the Z flag (Z = true) for `kw_goto_iftrue` / `kw_goto_iffalse`.
- **Breakpoints** are done the NTC way: `dw bp_name` in the thread, `bp_name: ret` in code.
  Break on `bp_name` in a monitor. SP shows the thread position.
- **ROMable.** The thread, the keywords and the stubs are read only. Variables, return
  points and scratch live in RAM. Numbers passed by address (`lit_5: dw 5`) are read only.

---

## 2. Two modes: turbo and normal

The same thread and the same keywords run in both modes. **SP is the thread in both.**

| | Turbo | Normal |
|---|---|---|
| Interrupts | off the whole time | let in at safe points |
| Straight line keywords | `ret` to the next one | the same - no extra cost |
| Branches (GOTO, loop end, GOSUB, procedure call / end) | `ret` | through `ntc_xn` (about 90 T more) |
| Long runs without a branch | - | `kw_irq` every 32 keywords |
| Waiting for a key / vsync | interrupts off | interrupts on while waiting |

### How normal mode works

`ntc_xn` is the normal mode "next". It saves SP (the thread position) in `ntc_ip`, goes back
to the real stack (the caller's, `ntc_csp`), enables interrupts for one instruction, then
disables them, puts SP back in the thread and carries on with `ret`:

```
ntc_xn: ld (ntc_ip), sp
        ld sp, (ntc_csp)
        ei
        nop                 ; an interrupt can be taken here
        di
        ld sp, (ntc_ip)
        ret
```

Flags are kept, so a compare followed by a branch still works. Inside every keyword SP is
the thread and interrupts are off, exactly as in turbo - the keyword code is the same.

Only **branch keywords** have a normal mode copy: a library section that loads SP (or jumps
into one that does) is copied for normal mode with `ret` -> `jp ntc_xn`, `ret cc` ->
`jp cc, ntc_xn`, `ntc_next` -> `ntc_xn`, and its labels get `_n` (`kw_goto_iftrue_n`,
`kw_next1l_n` ...). All other keywords are one copy used by both modes. The compiler makes
the GOTO / GOSUB / procedure stubs for each mode the same way. `@shared` after the deps in a
section header keeps it as it is in both modes (its SP load or `ret` is real).

The CPC platform puts a small interrupt handler at `#38` when normal mode is used (the
firmware's would turn the ROMs back on). It counts ticks (300 a second, `Ticks`) and takes
the old 3 bytes back out on exit.

### Measured on the emulated CPC

- A loop of two keywords (`s = s + i` / `Next`, the worst case: a branch every second
  keyword): 295 T a pass in turbo, 380 T in normal.
- Straight line code: the same speed in both modes.

### Turbo in the language

- **Build option / `Option Turbo`**: the program starts in turbo mode. Without it, it starts
  in normal mode.
- **`Turbo On` / `Turbo Off`**: switch at run time. `Turbo On` (used in normal mode) is
  `kw_turbo_on: ret` - SP is already the thread. `Turbo Off` (used in turbo mode) is
  `kw_turbo_off: jp ntc_xn`.
- The compiler tracks the mode line by line. A procedure called from both modes is built
  twice (`p_name` and `p_name_n`), each copy calling the right version of everything.
- A block (If / Select / loop) and a procedure must end in the mode they started in, so the
  mode is always known. To let the user choose:

  ```
  If fast Then
    Turbo On
    ShellSort
    Turbo Off
  Else
    ShellSort
  End If
  ```

---

## 3. Speed compared

What NTC is for: write in plain VB-style BASIC, fast, and get compiled speed on a Z80
without writing assembler or C. People can code fast and run fast. An expert in assembler,
or in C with a modern compiler, will beat it - they are not who this is for. Where a hot
spot needs more, an `#asm` procedure is a keyword with no call cost (section 5, Inline
assembly).

Short version of the results: NTC is 10 to 40 times faster than BBC BASIC, faster than
classic Small C, about the same as z88dk's sccz80 in turbo, and slower than SDCC (1.5 to
3.7 times) - SDCC keeps variables in registers and passes arguments in registers.

### How it was measured

Each program ran as a CP/M `.COM` in the harness, with every instruction timed exactly
and rounded up to whole microseconds as the CPC's Gate Array does (a 4 MHz CPC, as in
WinAPE at standard speed). Check: the shell sort test (`bas/shellsort.bas`) gave 14.7 s in
the model, 14.9 s by `Ticks` in WinAPE (AMSDOS build), and turbo 20% faster than normal by
stopwatch, as the model said. Only the work is timed (from `go` to the result), not
loading, filling or printing. BDOS calls count as no time - the timed parts make none,
except BBC BASIC's look at the keyboard every 20 statements, so on a real CP/M BBC BASIC
is a little slower than shown. The NTC normal mode figures include a minimal interrupt
handler (NTC's own on the CPC); CP/M's own handler costs more.

| | What it is |
|---|---|
| NTC turbo, NTC normal | this compiler; Integer (16 bit) and Byte variables, `Option Explicit` |
| SDCC | SDCC 4.2.0 (stock, `-mz80 --opt-code-speed --max-allocs-per-node 200000`), own CP/M start-up (`crt0_cpm_sdcc.s`). z88dk's zsdcc is SDCC with z88dk's patches and extra peephole rules - it could not be built here (its sources are not reachable from this machine); expect it to be the same or a little faster |
| sccz80 | z88dk's own C compiler (built from z88dk's current source), `zcc +cpm -compiler=sccz80 -O3` |
| Small C | Ron Cain's Small C as revised by Chris Lewis (C3.0R1.1, ncb85/SmallC-85) - the classic C of the CP/M era; 8080 code (runs as is on a Z80), Ron Cain's runtime library |
| BBC BASIC | BBC BASIC (Z80) v5 by R.T. Russell, CP/M edition - a fast interpreter; `%` integer variables (32 bit, BBC BASIC has no 16 bit integers), `&` byte array |
| Hand Z80 | the sieve written straight in Z80 (pointer stepping, counter in a register, no tricks) |

All programs are plain code with the same algorithm, the same 16 bit `int` / 8 bit `char`
types (except BBC BASIC) and the same answers (checked), in `compare/bench/`: `.bas` (NTC),
`ansi/*.c` (sccz80 and SDCC), `.c` with Small C's output as `B*C.ASM`, `.bbc`,
`BSIEVEA.ASM`.

### Results (seconds on a 4 MHz CPC)

| Test | What it does | Hand Z80 | SDCC | NTC turbo | sccz80 | NTC normal | Small C | BBC BASIC |
|---|---|---|---|---|---|---|---|---|
| sieve | primes below 8000, byte flags | 0.61 | 0.98 | 3.49 | 3.96 | 4.97 | 6.63 | 151.3 |
| sort | Shell sort, 2001 integers | | 7.14 | 11.35 | 13.85 | 14.27 | 18.10 | 334.2 |
| factor | prime factors of 2..1500, trial division | | 11.00 | 16.65 | 13.11 | 18.10 | 23.56 | 197.6 |
| loop | empty counted loop, 10000 times | | 0.54 * | 0.45 | 0.50 * | 0.70 | 1.17 | 7.00 |
| call | function with 2 parameters, 5000 calls | | 0.22 | 0.80 | 0.82 | 1.17 | 1.11 | 26.7 |
| divide | `(i * 5) \ 3 + i Mod 13`, 5000 times | | 3.18 | 5.89 | 3.66 | 6.02 | 9.71 | 57.2 |
| string | build 30 chars one at a time, 200 times | | - | 1.50 | - | 1.66 | - | 15.2 |

\* The C loop counter is `volatile`, or SDCC would throw the empty loop away; that keeps
it in memory. With a plain `int`, SDCC keeps it in BC and the loop takes **0.085 s**
(`dec bc / ld a,b / or c / jr nz`) - hand assembler speed.

NTC turbo compared with each (the other's time / NTC turbo's time; above 1 = NTC faster):

| Test | SDCC | sccz80 | Small C | BBC BASIC |
|---|---|---|---|---|
| sieve | 0.28 | 1.13 | 1.90 | 43 |
| sort | 0.63 | 1.22 | 1.60 | 29 |
| factor | 0.66 | 0.79 | 1.42 | 12 |
| loop | 1.2 (0.19 without `volatile`) | 1.10 | 2.59 | 16 |
| call | 0.27 | 1.03 | 1.38 | 33 |
| divide | 0.54 | 0.62 | 1.65 | 9.7 |

NTC normal takes longer than turbo by: sieve 42%, sort 26%, factor 9%, loop 55%, call 46%,
divide 2%, string 10%. Against sccz80, NTC normal is 0.6 to 0.97 times its speed; against
Small C 1.3 to 1.7 times (calls 0.95); against BBC BASIC 9 to 30 times.

The hand-written sieve is 1.6 times faster than SDCC, 5.7 times faster than NTC turbo.

### What gets the most from NTC

- **Loops, compares and branches.** A compare and its branch are one keyword with the
  variable addresses and the target in the thread. Small C calls a runtime routine for
  every compare (`call ccle`), which returns 0 or 1 in HL, then tests that
  (`ld a,h / or l / jp nz`). BBC BASIC reads and decodes the statement text every time.
  This is where NTC turbo is ahead of sccz80 (sieve, sort, loop).
- **Variables and arrays.** NTC variables are at fixed addresses, so a keyword loads them
  straight (`ld hl,(nn)`). Small C works out a stack address and calls `ccgint` for every
  local it reads (`ld hl,2 / add hl,sp / call ccgint`).
- **Short keywords gain most from turbo.** Normal mode costs about 90 T per branch, so the
  more branches per unit of work, the more turbo gains: the empty loop takes 55% longer in
  normal, the sieve 42%, the sort 26%.

### What gets the least

- **Division, multiply and Mod.** The time is in the 16 bit divide routine. NTC's is slower
  than z88dk's and SDCC's (`divide`: 5.9 s against 3.7 s and 3.2 s), and that is also why
  sccz80 wins `factor`. Turbo hardly matters (2%): a divide is one long keyword. To do:
  a faster divide.
- **Procedure calls.** NTC's call stub copies the arguments into the parameters and clears
  the locals (in VB, locals start empty on every call): about the same as sccz80 in turbo.
  SDCC passes arguments in registers and is 3.7 times faster. A `#asm` keyword procedure
  has no call cost at all.
- **Strings, Print, Input.** Copying bytes, and the firmware or BDOS doing the output.
  NTC is about as fast as its library routine, like anyone else's.

### Where SDCC and expert assembler win

- Keeping a loop's variables in registers the whole time; NTC loads and stores them in
  memory in every keyword. This is most of SDCC's lead (the sieve: 0.98 s against 3.49 s;
  the loop without `volatile`: 0.085 s).
- Arguments in registers, no copying (calls).
- Stepping a pointer through an array instead of working out `base + index * size` each
  time (the hand sieve does this).
- No step between operations: NTC pays a `ret` (10 T) per keyword, plus about 90 T per
  branch in normal mode.

## 4. The compiler

Files (ES5, no node, no Python):

| Path | What it is |
|---|---|
| `ntc.html` | The GUI: project explorer, editor, NTC output, compiled as you type |
| `js/ntc_parser.js` | VBCC style parser: `ntcParse(files)` -> records and element table. Also `IFtoPF` |
| `js/ntc_compiler.js` | Code generator and library linker: `ntcCompile(source or files, options)` |
| `js/ntc_lib.js` | The `.asm` library files as JS strings (generated from `asm/`) |
| `js/ntc_examples.js` | Example projects for the GUI (generated from `bas/`) |
| `js/ntc_gui.js`, `css/ntc_gui.css` | GUI code and style |
| `js/listRenderer.js`, `css/listRenderer.css` | Project file and procedure lists |
| `asm/ntc_lib.asm` | Keyword library, sections marked `;## name deps [@shared]` |
| `asm/ntc_plat_cpc.asm` | CPC platform layer, straight to the hardware (screen, keys, frame, interrupt handler, exit) |
| `asm/ntc_plat_cpcfw.asm` | CPC platform through the firmware (text, keys, mode, clock) |
| `asm/ntc_plat_cpm.asm` | CP/M platform (BDOS console, own stack, warm boot) |
| `asm/ntc_plat_test.asm` | test harness platform (console through I/O ports, for `test/ntcrun.py`) |
| `lib/<platform>/*.cls` | the platform classes: `StdIO.cls` (console), `System.cls` (what the machine is), `FileSystem.cls` (files) |
| `../docs/userguide.md` | Language reference: every keyword by topic, with an example and its VB5 / VB6 differences |
| `build/` | Test builds: every program in `bas/` compiled for every platform (`.ASM`), and `build.bat` to assemble them all with sjasmplus on Windows / MS-DOS (CPC: AMSDOS `.BIN` files, CP/M: `.COM`) |
| `compare/smallc/` | The sieve (`bas/sievetime.bas`) in Small C, as Z80 source, for timing NTC against a classic Z80 C compiler (results in its README) |
| `compare/bench/` | The speed comparison programs (section 3): NTC, Small C, BBC BASIC, hand Z80 |
| `bas/` | Examples and self tests (`vb_test.bas`, `vb_test2/`, `ntc_test.bas`, ...) |

### Parser (VBCC concept, ported to JS)

- Each physical line is normalised the VBCC way (`pvtStatementTok`): lower case outside
  quotes, one space between words, `'` comments cut, `_` continuation joined. Statements are
  split on `:` outside quotes.
- Each statement is matched on its first words (prefix dispatch), like VBCC's
  `pvtParseApp` / `pvtParseObject` / `pvtParseFunction` / `pvtParseUDT`.
- Context flags say where we are: module, class, procedure, Type, `#If` skip.
- Every statement becomes one record (`{ k: 'for', v, start, limit, step, line, file ... }`).
  Declarations go into the element table (VBCC `cElement`: type, scope, full identifier,
  identifier, params, datatype, value).
- Full identifiers follow VBCC: `module.name` (private), `name` (public), `module.proc.name`
  (local), `class.member`.
- A one line `If c Then a : b Else c` becomes block records (if / else / endif).
- No tree, no recursive descent. Expressions stay as text in the records.

### Code generator

- Walks the records one by one. Expressions go through `IFtoPF` (shunting yard) to postfix,
  then a postfix walk with a value stack emits one keyword per operation into `tmpN`
  (numbers) / `stmpN` (strings). Any name followed by `(` is a function or array: it comes
  out of `IFtoPF` as `NAME@n` with its argument count.
- Constants are folded at compile time; literals go inline where a keyword takes them, or by
  address through the read only number pool (`lit_n`).
- Pass 1 (run twice) works out the types of undeclared variables, labels, GOSUB targets,
  procedure calls and the mode at each call. Then: GOSUB keyword forms, the call graph (no
  recursion), and which modes each procedure is needed in. Pass 2 emits the code.
- A procedure nobody calls is compiled for its errors, then dropped.
- Peephole: branch to a GOTO goes straight to its target, a GOTO to the next label goes,
  code after GOTO / End / Return / procedure end up to the next label goes.
- Only the library sections the program uses get linked, plus their dependencies, once per
  mode where needed.

### Procedures (Sub / Function / Property)

```
        dw p_add_c, var_a, lit_5        ; call: args follow as addresses
        ...
p_add:                                  ; body (thread)
        ...
        dw p_add_r                      ; end
```

- `p_name_c` (code stub) copies the arguments into the parameters, sets the locals to 0 / ""
  (VB: locals start empty on every call, except `Static`), saves SP (the return point) in
  `p_name_rs` and jumps into the body.
- `p_name_r` copies ByRef parameters that the procedure writes back to the caller's
  variable, then loads SP from `p_name_rs`.
- A function's result is its own variable (VB: assign to the function name).
- **No recursion**: each procedure has one set of parameters, locals and one return point.
  A procedure that can call itself (directly or through others) is an error.

### GOTO / GOSUB

- GOTO is one word, `dw l_go`, with a code stub `l_go: ld sp, l / ret` (30 T).
- A GOSUB target becomes a keyword when safe: `l_gs: ld (l_rs), sp / ld sp, l / ret` (50 T),
  RETURN `l_rt: ld sp, (l_rs) / ret` (40 T). Otherwise it uses the GOSUB stack
  (`kw_gosub` / `kw_return`). Labels belong to their procedure.

### Classes - syntactic sugar

- A `.cls` file is a named group of variables and procedures. Members get the class name in
  front (`counter.add`, `p_counter_add`). `Dim c As New Counter` / `c.Add 5` /
  `c.Total` / `c.Limit = 3` / `Counter.Total` all resolve at compile time.
- There is no run time object: every variable of a class uses the class's one set of
  members.
- Planned: `Option ClassSize <kilobytes>` to keep a class's code within a size so classes
  can be banking units. Accepted, not enforced yet.

### Platforms

A platform is one `asm/ntc_plat_<name>.asm` file plus its classes in `lib/<name>/`. The
file starts with `;@key value` lines the compiler reads, then the `ntc_plat_*` sections the
library links against (listed at the top of `ntc_lib.asm`):

| Key | Meaning | cpc | cpcfw | cpm | test |
|---|---|---|---|---|---|
| `;@org` | default org (the GUI's Org box empty) | #0040 | #0040 | #0100 | #4000 |
| `;@text` | `glyph`: Print text as ZOSCII glyph words; `byte`: as byte strings (string pool + `kw_printstrvar`) | glyph | byte | byte | byte |
| `;@scrinit` | the program starts with `kw_scrinit` (mode 1, clear) when it uses the screen | 1 | 0 | 0 | 0 |
| `;@irq` | has `ntc_plat_irqon` (own interrupt handler: normal mode ticks, `Interrupt`) | 1 | 0 | 0 | 0 |
| `;@stack` | a label: the program's own real stack (set before `ntc_csp`) | - | - | ntc_cpmstack | - |
| `;@cols` / `;@rows` | console size | 40 / 25 | 40 / 25 | 80 / 24 | 40 / 25 |

- The library prints through `ntc_plat_putc` (A = char). On the CPC hardware platform it
  turns the char into its glyph and draws it; `kw_printzoscii` (inline glyph words) is only
  used by glyph platforms.
- Host calls (firmware, BDOS) need a real stack. `ntc_fwcall` / `ntc_bdos` keep IX, put the
  thread position in `ntc_ip`, switch SP to `ntc_csp`, enable interrupts, `call`, disable
  them and switch back. The thread itself still never sees `call` / `push`. Those sections
  are `@shared` (their SP loads are real stack switches, not branches), so they have no
  normal mode copy.
- `#If NTC_<PLATFORM>` (e.g. `NTC_CPM`) and `#If NTC` are predefined.
- `Option Terminal VT52 | ANSI` (CP/M): the compiler writes `NTC_TERM equ 0 / 1 / 2` at the
  top of the program; `ntc_plat_cpm.asm` assembles Cls / Locate for that terminal with
  sjasmplus `IF`. It also predefines `NTC_TERM_VT52` / `NTC_TERM_ANSI` and `NTC_TERM_POS`,
  which `lib/cpm/StdIO.cls` uses for CanPosition / CanClear / Rows.
- The platform's classes join a project when its source names them (`StdIO`, `System`,
  `FileSystem`) and
  the project has no class of that name. A project's own `StdIO.cls` replaces the
  platform's, and then `Print`, `Input`, `Inkey`, `Inkey$`, `Cls`, `Locate` and `Mode`
  compile to calls of its methods (`PutStr`, `NewLine`, `Tab`, `GetLine`, `GetKey`, `Cls`,
  `Locate`, `Mode`), except inside `StdIO` itself.
- `#asm` naming any library label (not only a section name) links that label's section, so
  class methods can jump straight to `ntc_plat_putc`, `kw_printint` and so on.

### Project explorer (GUI)

- Left: the project's files (listRenderer) with + Module, + Class, Rename, Remove, and drag
  and drop of `.bas` / `.cls` files. Under it, the procedures of the selected file - click
  one to jump to it (a `-` after the kind = never called).
- Middle: the selected file. Right: the NTC asm for the whole project.
- Open: `.bas` / `.cls` files, a saved project (`.json`), or a VB `.vbp` picked together
  with its files (forms are left out). Save project: one `.json` with
  all files and the start mode. The project is also kept in the browser between visits.
- Errors show the file and line; click one to go there.

### Status

- Passes on an emulated CPC, both modes: `vb_test.bas` (64 checks), `vb_test2` (30 checks,
  2 files), `vb_test3.bas` (11 checks: Enum, With, On GoTo / GoSub, Inkey$),
  `vb_test_long.bas` (58 checks), `vb_test4.bas` (16 checks: array parameters),
  `vb_test5` (18: #asm, Inp / Out, a library class), `vb_test6.bas` (18: Byte arrays,
  ReDim), `vb_test7.bas` (16: Type and 2D array parameters), `vb_test8.bas` (5: AddressOf),
  `vb_test9.bas` (34: ^, IIf, Choose, string functions), `vb_test10` (33: For Each,
  Property arguments, Like, LSet / RSet, String * n), `vb_test11.bas` (17: asm keyword procedures), `vb_test12.bas` (33: String * n, String Max n), `ntc_test.bas` (36 checks), the class project, sieve,
  shell sort (turbo and normal from its menu), the FOR / GOSUB / screen tests.
- Not yet tested on a real CPC.

---

## 5. Language

VB5 / VB6 style. Differences from VB are listed after each part.

### Types and declarations

- `Integer` (16 bit signed), `Long` (32 bit signed), `Byte` and `Boolean` (stored as 16
  bit, True = -1; an array of Byte is 1 byte per element), `String` (40 chars),
  `String * n` (n = 1 .. 255: VB's fixed length - starts as n spaces, every assignment and
  Input pads with spaces or cuts to n), `String Max n` (n = 1 .. 255, NTC: at most n chars,
  not padded).
- Strings are fixed buffers (no heap). A scalar string (variable, local, temp, param,
  result, Type field) has its capacity in the byte before it: `[cap][text...][0]`, so `{s}`
  and every address passed around is still the first char. Array elements are cap + 1
  bytes with no capacity byte (the element size is passed to `kw_sget` / `kw_sset` /
  `kw_strcpyn`, or is in the descriptor). Parameters, function results, Select values and
  temps hold the program's longest string (`NTC_STRMAX`, at least 40, written at the top
  of the program); library functions build into temps and cut at NTC_STRMAX;
  `kw_strcpy` / `kw_strcat` / input cut at the destination's capacity byte; call stubs copy
  strings in and back with the same cut. A function writes straight into a variable only
  when the variable is at least NTC_STRMAX long; concatenation always may (it cuts).
- `Enum ... End Enum` (members are constants, also `EnumName.Member`).
- `Dim` / `Private` / `Public` / `Global` / `Static`, `Const`, `Type ... End Type`.
- Suffixes: `a$` String, `a%` Integer, `a&` Long; `1000&` / `&HFFFF&` are Long literals. Undeclared names are allowed (their type comes from
  how they are used) unless `Option Explicit`.
- Arrays: `Dim a(10)`, `Dim b(1 To 5)`, `Dim g(3, 4)`, `Dim s(10) As String`,
  `Dim pts(5) As Point` (then `pts(i).x`). `Option Base 0 | 1`.
- Dynamic arrays: `Dim a()` then `ReDim [Preserve] a(lo To hi)`, `Erase a`. The bounds must
  be constants (there is no heap): the storage is as big as the biggest `ReDim` of that
  array, and a descriptor holds the current bounds. 1 dimension. `Erase` of a fixed array
  clears it.
  A dynamic array of a Type works too (each field array gets the ReDim).
- `#Const`, `#If ... Then / #ElseIf / #Else / #End If`.

Long: a separate keyword set (`kw_l_*`), every argument an address, 4 bytes low byte first.
An expression is Long when a Long variable, function, array or a literal over 65535 is in
it; Integer sides are widened. A Long put into an Integer keeps the low 16 bits (VB would
stop with Overflow). Integer * Integer stays 16 bit as in VB - use `CLng(a) * b` or
`a * 1000&` for a Long result.

Overflow is never checked: Integer and Long arithmetic wraps (there is no error handling,
see Flow).

Not supported: `Single`, `Double`, `Currency`, `Variant` values, `ReDim` with bounds from
variables, `Declare`.

### Procedures

- `Sub`, `Function`, `Property Get / Let / Set`, `Public / Private / Friend`, `Static`.
- Parameters: `ByVal`, `ByRef` (default), `Optional` with a default.
- `Exit Sub`, `Exit Function`, `Exit Property`. `Call Name(args)` or `Name args`.
- `Sub Main` runs after any top level code. Top level code (outside procedures) in a module
  is the main program, as in classic BASIC.

- Arrays as parameters: `Sub SortUp(a() As Integer)` (Integer, Long, String, Byte; 1 or 2
  dimensions; always ByRef). The call passes the address of a 12 byte descriptor (base,
  lower bounds, counts, element size); the call stub copies it, and `a(i)` / `a(i, j)` go
  through it (`kw_pget` / `kw_pset`, `kw_pget2` / `kw_pset2`). An array parameter or a
  dynamic array can be passed on. `LBound(a [, dim])` / `UBound(a [, dim])` work on them
  (on a fixed array the compiler works them out).
- Arrays of a Type as parameters: `Function Total(a() As Point)` - one descriptor per field
  array; `a(i).x` works as usual.
- `Property Get / Let` with arguments: `Bag.Item(3) = 42`, `x = Bag.Item(3)`.
- Local arrays (not `Static`) are cleared on every call, as in VB.
- Types as parameters: `Sub Grow(p As Point)` / `ByVal p As Point`. The call passes one
  address per field (nested Types, String and Long fields too); a ByRef Type that the
  procedure writes is copied back field by field.
- `AddressOf Proc` gives a number (the address of the procedure's call stub) that can be
  stored and passed around; `CallAddr x [, args]` calls it (driver / device tables). The
  arguments go by address and must match the procedure's parameters - the compiler can't
  check that. `AddressOf` gives the call stub for the turbo mode at that line.
- `Option Reserve start, size [, start, size] ...`: memory the program must stay out of
  (a load area, a screen, firmware RAM). The compiler writes one sjasmplus `ASSERT` per range
  after `ntc_end`, so the assembly stops (naming the range and the source line) if
  `ntc_start .. ntc_end` overlaps it. The program is not laid out around a range (yet).
- `VarPtr(name)`: the address of a variable's value or a fixed size array's first element
  (a read only word, like `AddressOf`), for `FileSystem.Load` / `Save` and `#asm`.

Not supported: recursion (also not found through `CallAddr`), `ParamArray`, 3+ dimension
array parameters.

### Flow

`If / ElseIf / Else / End If` (block or one line), `Select Case` (values, `a To b`,
`Is > x`, strings, `Case Else`), `While / Wend`, `Do [While|Until] / Loop [While|Until]`,
`For / To / Step / Next`, `Exit For | Do | While`, `GoTo`, `GoSub / Return`, `End`, `Stop`,
labels and line numbers.

`For Each x In array` (1 dimension, fixed / parameter / dynamic; not an array of a Type),
`On x GoTo a, b, c` / `On x GoSub a, b, c`, `With ... End With`, `DoEvents` (a safe point:
in normal mode interrupts get in there).

**No error handling - a decision, not a gap.** There is no `On Error` / `Resume` and there
will not be: it makes lazy programmers and costs speed, and with SP as the thread there are
no return points to unwind. A routine that can fail returns a status (a Function result,
e.g. 0 = ok, negative = error) and the caller checks it. Diagnostics are separate:

- `Error text` - prints `Error: text (file line n)` and stops.
- `Debug.Assert condition` - when false prints `Assert failed: condition (file line n)` and
  stops (kept in the program, unlike a VB exe).

`For Each` over collections does not exist (there are no objects).

### Operators

`^`, `-` (unary), `* / \ Mod`, `+ -`, `&`, `= <> < <= > >= Like`, `Not`, `And`, `Or Xor`.
`/` is integer division (no floating point). `^` is a whole number power (`-2 ^ 2` = -4 as
in VB; a negative power gives 0). `And Or Xor Not` are bitwise (True = -1, so
they work as logical too). Strings compare with all six compares. `Like` patterns: `*` any
run, `?` one character, `#` one digit, `[abc]` / `[a-z]` one of, `[!abc]` none of; case
matters, unless the module has `Option Compare Text`: then compares, `Like`, `InStr`,
`InStrRev`, `StrComp` and `Select Case` on strings ignore case (both sides go through
`UCase$` first).

### Functions

- Strings: `Len Left$ Right$ Mid$ Chr$ Asc Str$ CStr Val InStr InStrRev UCase$ LCase$
  Trim$ LTrim$ RTrim$ Space$ Spc String$ Hex$ Oct$ Replace StrReverse StrComp` (with or
  without `$`). `Mid$(s, start[, len]) = text` replaces in place. `LSet s = x` / `RSet s = x`
  put x left / right in s's length, padded with spaces.
- `Format$(n, "pattern")` - the pattern must be a constant: text before the first `0` / `#`
  and after the last is kept, the `0`s give the least digits, a `,` gives groups of 3,
  `.00` is printed as is (whole numbers only). `Format$(42, "0000")` = "0042",
  `Format$(1234567, "#,##0")` = "1,234,567".
- `Join(a [, sep])` (a String array). `a = Split(text [, sep])` fills a dynamic String array
  (`Dim a() As String`): at most 16 parts, or more if a `ReDim` of it is bigger (no heap).
- `IIf(cond, a, b)`, `Choose(n, a, b, ...)` - numbers, Longs or strings (both values are
  worked out first, as in VB; Choose out of range gives 0 / "").
- Arrays: `LBound(a [, dim])`, `UBound(a [, dim])`.
- Numbers: `Abs Sgn Int Fix CInt CLng CBool CByte`, `Sqr` (whole number square root),
  `Rnd(n)` = 0 .. n-1, `Peek Deek`, `Inp(port)`,
  `Inkey` (key code or 0), `Inkey$` (key as text or ""), `Ticks` (interrupt count, normal
  mode). `Val` / `CLng` of text into a Long reads 32 bit decimal.

### Statements (NTC / CPC)

`Print a; b, c` (also `?` and `Debug.Print`), `Input ["prompt";] v`, `Cls`, `Locate x, y`,
`Mode n`, `Frame`, `Poke a, v`, `Doke a, v`, `Randomize [n]`, `Call address` (machine code
run as a keyword: SP is the thread, end with `ret` in turbo, `jp ntc_xn` in normal),
`Break [name]`, `Turbo On`, `Turbo Off`, `Option Turbo`, `Out port, value` (16 bit port,
`out (c), a`), `Interrupt MySub` / `Interrupt Off`.

`Tab(n)` and `Spc(n)` in Print.

Differences: `Print` does not add spaces around numbers, `,` prints one space - unless
`Option VBPrint`: then a number printed on its own gets VB's spaces (`" 5 "`, `"-3 "`) and a
comma moves to the next 14 column zone (numbers inside `&` stay plain).

**Interrupt hook.** `Interrupt MySub` (a Sub with no parameters) runs MySub after
interrupts: the interrupt handler only marks it pending, the next safe point calls it
(the same window `ntc_xn` opens), and its return lets it run again. Normal mode only -
turbo has no interrupts. `Interrupt Off` stops it. Cls and scroll also let interrupts in
while they run in normal mode.

**Console classes.** `StdIO` (PutStr, PutChar, PutInt, NewLine, Tab, GetLine, GetChar,
GetKey, Cls, Locate, Mode, Cols, Column, Row, and the constants CanPosition, CanClear,
CanInput, CanPoll, CanColour, Glyphs, Rows) and `System` (Platform, CpuClock,
TicksPerSecond, FrameRate, HasInterrupts, HasHook, HasScreen, HasKeyboard, MaxHandles,
Ticks) come with each platform; a project's own `StdIO.cls` takes over the console
statements. `Option Terminal VT52 | ANSI` for CP/M. Details in `userguide.md` section 17.

**FileSystem.** The same methods on every platform (Load, Save, Delete, Exists, Rename,
Size, Open, Close, ReadByte, WriteByte, Read, Write, Seek, Eof, ReadLine, WriteLine); what a
platform can do comes from `FileSystem.Capability("NAME")` - one function for every
capability, PRIMAL's `SysPropertyPC` idea: the value (True / a number), or 0 when the
platform hasn't got it (`LOAD`, `SAVE`, `SEQUENTIAL`, `RANDOMACCESS`, `DELETE`, `RENAME`,
`EXISTS`, `SIZE`, `MULTIPLE`, `MAXOPEN`, `RECORDSIZE`). A method the platform can't do
returns `NotSupported` (-1); every result below 0 is a status. CP/M: everything, through
BDOS FCBs and random records (`ntc_plat_cpm.asm`, section `ntc_plat_fs`: two handles plus
a slot for the whole-file calls, 170 bytes each). CPC firmware: Load / Save through the
cassette calls (CAS IN / OUT DIRECT: disc with AMSDOS, else tape). CPC hardware and test:
none yet. The file routines run on the real stack with interrupts on (`fs_go`), like the
other host calls; `ntc_capfind` (in `ntc_lib.asm`) searches a class's capability table and
leaves Z set when found. Details in `userguide.md` section 17.

**Warnings.** Not errors - the program still builds. Now: a Function called as a statement
("the result of F is not used") - with no error handling, an unchecked status is worth
seeing. The GUI shows warnings in yellow under the errors.

### Inline assembly

```
Function AddAsm(ByVal a As Integer, ByVal b As Integer) As Integer
  #asm
            ld hl, ({a})
            ld de, ({b})
            add hl, de
            ld ({result}), hl
  #endasm
End Function
```

**Asm keyword procedures.** A Sub or Function whose whole body is one `#asm` block, and
which does not use `{param}` or `{result}`, is not a procedure at all: it becomes a keyword.
The call is `dw fn_name, arg address, ... [, result address]` - no call stub, no body thread,
no saved return point. The block pops its own arguments and ends with `ret` (added for you):

```
Function Add3(ByVal x As Integer) As Integer
  #asm
            pop hl          ; address of x
            ld e, (hl)
            inc hl
            ld d, (hl)
            inc de
            inc de
            inc de
            pop hl          ; address of the result
            ld (hl), e
            inc hl
            ld (hl), d
  #endasm
End Function
```

`Print Add3(10)` -> `dw fn_add3, lit_10, var_add3_add3` / `dw kw_printint, var_add3_add3`;
`a = Add3(5)` -> `dw fn_add3, lit_5, var_a` (straight into a, unless a is also an argument).
About 90 T against about 205 T through the stubs.

- Every argument is an address, in order: a number's value (literals come from the
  read only pool, an expression goes into a temp first), a String's first char (0
  terminated), a Long's 4 bytes (low word first), an array's descriptor, one address per
  field of a Type. ByVal and ByRef look the same; ByRef means you may write through it (a
  literal or expression passed ByRef goes through a temp first).
- A Function gets the result address last (Integer 2 bytes, Long 4, String a buffer).
  A Sub gets none.
- Pop exactly what the call passes; don't move SP otherwise. Same rules as a library keyword.
- `{Const}`, `{globalvar}` and `{label}` still work in the block.
- One copy serves both modes; in normal mode it counts as a straight keyword for the safe
  point (`kw_irq` every 32).
- These stay ordinary procedures (with stubs): a body that also has BASIC lines, a block
  that uses `{param}` / `{result}`, a block with `ld sp,`, a procedure used with `AddressOf`
  or `Interrupt`, Property procedures.

**Asm blocks in BASIC code.**

- Each `#asm ... #endasm` block becomes one inline keyword: the thread gets one word, the
  code goes after the stubs. The compiler adds the closing `ret`; `ret` anywhere in the
  block is an early exit.
- `{name}` is the label of a variable, parameter, local or array (an array parameter or a
  dynamic array gives its descriptor), the value of a Const, or a BASIC label / line number
  (`ld sp, {skip}` / `ret` jumps there). `{result}` is the
  function's result. Parameters are values at their labels (the call stub copied them in),
  so `ld a, ({b})` reads b; writing a ByRef parameter is copied back on return.
- Labels in a block are local to it (renamed `asm_<file>_<line>_<label>`).
- Library routines a block names (e.g. `ntc_printbuf`) are linked.
- Always reach BASIC names with `{name}`, never with the generated label (`var_x`,
  `p_name_c`, ...). Those labels come from the BASIC and can change when it changes (a
  clash adds `_2`, the normal mode copy adds `_n`); `{name}` is worked out again on every
  compile, so it can't go stale. A generated label written by hand gives a warning:
  `#asm uses the generated label var_v - write {v} so it follows the BASIC`.
- Each asm line carries its BASIC file and line as a comment (`; main.bas 4`), so an
  assembler error points back to the source. BASIC lines in the thread are comments too
  (with the file name when the project has more than one file).
- Cross reference: every compile also gives a map - each label the compiler made, what it
  is, its BASIC name, file and line (`Save .map` in the GUI, `--map=file` in cli.js). It is
  made fresh each time, nothing to maintain; use it to find a label in an emulator or
  debugger.
- Rules: SP is the thread - no `call` / `push` unless SP is first switched to the real stack
  (`ld (ntc_ip), sp / ld sp, (ntc_csp) / ... / ld sp, (ntc_ip)`); no registers are kept
  between keywords; interrupts are off. A block that moves SP (`ld sp,`) is a branch: its
  normal mode copy ends with `jp ntc_xn`.

---

## 6. Test tools (`test/`)

Scratch tools for testing the compiler. They are not part of the compiler or the GUI, which
need nothing but a browser. All paths are relative to the `test/` folder, so it works
wherever the project is.

### What to install

- **node** - for `cli.js` and `gen.js`. Run `npm install` in `test/` once (acorn, for the ES5
  check in `regress.sh`).
- **python3** with the `z80` module (`pip install z80`) - the Z80 core used by `cpcrun.py` and
  `ntcrun.py`.
- **sjasmplus** - on the PATH, or give its full path in `SJASMPLUS`
  (`SJASMPLUS=/path/to/sjasmplus python3 cpcrun.py ...`).
- **Playwright + Chromium** (`pip install playwright`, `playwright install chromium`) - only
  for the GUI tests.

On Windows run them from a bash (Git Bash / WSL) for `regress.sh`; the others run anywhere.

### cli.js - compile from the command line

```
node cli.js main.bas                         one file -> .asm on stdout
node cli.js Main.bas Module2.bas Counter.cls  a project (files in order)
node cli.js main.bas --turbo                 start in turbo mode (like Option Turbo)
node cli.js main.bas --platform=cpm          cpc (default), cpcfw, cpm, test
node cli.js main.bas --amsdos=PROG           also write PROG.BIN with an AMSDOS header when
                                             sjasmplus assembles it (DEVICE + SAVEAMSDOS)
node cli.js main.bas --nocomments            no BASIC source lines as comments
node cli.js main.bas --map=main.map           also write the cross reference
node cli.js main.bas > main.asm 2> errors.txt
```

Errors go to stderr as `ERR file:line: message`. Note: a single file is compiled as text
with no name (module `main`), so a clash between a module name and a procedure name only
shows with real file names (the GUI, or more than one file).

### cpcrun.py - compile, assemble and run on an emulated CPC

```
python3 cpcrun.py prog.bas
python3 cpcrun.py prog.bas 'Bob\n7\n'                typed keys (\n = Return, \x7f = DEL)
python3 cpcrun.py Main.bas '' Module2.bas --turbo    more files and options go to cli.js
```

It runs `cli.js`, writes `prog.asm` next to `prog.bas` (so copy programs into `test/t/`
first rather than running them in `bas/`), assembles to `prog.bin` / `prog.sym` with sjasmplus
(raw binary at the program's org: #0040 on the CPC), then runs it:

- RAM only, no firmware or ROMs. #38 holds `ei / ret` (as a stand in for the firmware's
  handler) until NTC puts its own there in normal mode
- an interrupt every 13333 T (the CPC's 300 Hz interrupt, 6 per frame), held until the Z80
  takes it
- keyboard matrix through the PPI / PSG ports; the typed keys are pressed one at a time
  as the program scans
- the program ends at `End` (NTC returns to a `halt` the harness put at #BFF0); stops with
  TIMEOUT after about 400 M T
- prints the screen as text (reads the screen at #C000 and matches each 8x8 cell against
  the font, any mode), then a status line: halted or not, SP, interrupts taken, T states
  run, gate array writes (screen mode / ROM settings)

### ntcrun.py - run on any platform

```
python3 ntcrun.py prog.bas 'Bob\n' --platform=test
python3 ntcrun.py prog.bas '' --platform=cpm --turbo
python3 ntcrun.py Main.bas '' StdIO.cls --platform=cpcfw
```

The same arguments as `cpcrun.py` plus `--platform=`. `cpc` runs `cpcrun.py`'s CPC. The
others run on a plain Z80 with 64K RAM and a text screen kept by the harness, printed the
same way as `cpcrun.py` prints the CPC screen (so the same `ref/` files fit):

- `test`: the port console of `ntc_plat_test.asm` (40 x 25)
- `cpcfw`: the firmware jumpblock entries the platform uses (`TXT OUTPUT`, `TXT SET CURSOR`,
  `TXT CLEAR WINDOW`, `SCR SET MODE`, `KM WAIT CHAR`, `KM READ CHAR`, `MC WAIT FLYBACK`,
  `KL TIME PLEASE`) are small stubs that hand over to the harness
- `cpm`: program at #0100, BDOS (`call 5`) trapped (functions 2, 6, 9, 11, and the file
  calls 15, 16, 19, 22, 23, 26, 33, 34, 35), the warm boot at #0000 ends the run, 80 x 24;
  VT52 and ANSI clear / cursor codes are understood
- files (`FileSystem` on cpm and cpcfw, the CAS IN / OUT calls on cpcfw) are real files in
  `test/t/files` (or `$NTC_FILES`)

These are much faster than the CPC emulation (no screen to read back from video RAM).

### regress.sh - the regression run

```
bash regress.sh
SJASMPLUS=/path/to/sjasmplus bash regress.sh
```

Runs every test program in both modes (turbo and normal) and checks the result line:
`vb_test` (64 checks), `ntc_test` (36), `vb_test2` (30, 2 files), `vb_test3` (11),
`vb_test_long` (58), `vb_test4` (16), `vb_test5` (18, 2 files), `vb_test6` (18),
`vb_test7` (16), `vb_test8` (5), `vb_test9` (34), `vb_test10` (33, 2 files), `vb_test11` (17), `vb_test12` (33), the class project, sieve, shell sort
(turbo and normal), the guide, and the output tests (`for gs gs2 scr0 scr2 diag1 diag2
vbprint cmptext tiny wrap`, plus `hook` in normal mode only) compared with the expected output in `ref/`.
Then the same programs on the `test`, `cpcfw` and `cpm` platforms in both modes (CP/M skips
`scr0` / `scr2`: a stream has no Locate), the platform classes on every platform (`stdio.bas`
against `ref/stdio.<platform>.txt`), CP/M `Option Terminal` (`term_vt52.bas`,
`term_ansi.bas`) and a project with its own StdIO (`via/`, `ref/via.txt`).
Then checks every JS file parses as ES5. Ends
with `ALL PASS` or `SOME FAILED` (with the last lines of each failure). Work files go in
`test/t/`.

To add a test: put the program in `bas/`, then add a `cp ... ; o=$(...); check "name" "pattern" "$o"`
line in `regress.sh` with a pattern from its last output line.

### gen.js - rebuild the generated JS

```
node gen.js
```

Run it after changing `asm/`, `lib/` or anything in `bas/`. It writes `js/ntc_lib.js` (the
library text, every platform file and the platform classes) and `js/ntc_examples.js`
(the Example list in the GUI, from the list at the top of `gen.js` - add new examples
there).

### genbuild.js - the test builds in build/

```
node genbuild.js
```

Compiles every program in `bas/` (the list at the top of the file) for every platform into
`build/<platform>/NAME.ASM` (8 character names, CRLF line ends). CPC files get the
`amsdos` option, so sjasmplus writes an AMSDOS `NAME.BIN` straight away. `build/build.bat`
then assembles them all on Windows. `regress.sh` runs `genbuild.js` and checks every file
assembles the way `build.bat` does it.

### guitest*.py - GUI tests (Playwright, headless Chromium)

```
python3 guitest5.py
```

- `guitest6.py` - every example on every platform (no errors), and the org follows the
  platform
- `guitest5.py` - opens `ntc.html`, compiles every example, prints errors / stats / compile
  time per example and any browser console errors (should be none)
- `guitest4.py` - opens the test project in `vbp/` (a .vbp with Main.bas, Counter.cls, a
  form and a missing file) and the Long example
- `guitest.py` .. `guitest3.py` - earlier checks: file list, procedure list click to jump,
  2 file example. Some save a screenshot (`gui*.png`) in `test/`

### Usual cycle

1. change `asm/` or `bas/` -> `node gen.js` (and `node genbuild.js` for `build/`; regress.sh
   does that one too)
2. try one program: `cp ../bas/prog.bas t/ && python3 cpcrun.py t/prog.bas`
3. before handing over: `bash regress.sh` (ALL PASS) and `python3 guitest5.py` (no errors)

---

## 7. Open decisions

- Decided 2026-10-11: classes keep one set of members. Several instances are the class's
  own job, Amiga library style: `h = Serial.Open(...)` returns a handle, every method takes
  it, the class keeps per instance state in its own arrays. Private members can't be used
  from outside the class.
- Open: keep `Dim c As Counter` (it only names the one set of members) or make it an error.
- `Option ClassSize <kilobytes>` for banking (planned, not enforced).
