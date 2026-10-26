# NTC - Native Threaded Code

(c) 2026 Cyborg Unicorn Pty Ltd - MIT License

What NTC is, how the NTC BASIC compiler works now (VB5/VB6 style front end, turbo and
normal modes, project explorer), and the language it takes. Progress is tracked in
`todo.md`. The full language reference, keyword by keyword, is `userguide.md`; a step by step
tutorial, one small page per topic, is in `tutorial/`. These are in `docs/`; file and folder names in them (`js/`, `asm/`, `bas/`, `test/` ...) are in `src/`.

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

A program is built only for the mode(s) it runs in: one mode, one copy of everything. Only
code reached in both modes (a program with `Turbo On` / `Turbo Off`, or a procedure an
interrupt Tick calls as well as turbo code) is built twice.

`Option NoTurbo`: normal mode only - `Turbo On` / `Turbo Off` become no-ops with a warning, the
start mode is normal whatever `Option Turbo` or the build setting say, so what would have been
built twice is built once (the normal copy). A program that never switches mode comes out the
same. For programs that switch mode and are short of memory.

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
| `asm/ntc_lib.asm` | Keyword library, sections marked `;## name deps [@shared] [@data] [@unit] ...` (`@data` / `@unit`: linked when linked code names them - docs/architecture.md) |
| `asm/ntc_plat_cpc.asm` | CPC platform layer, straight to the hardware (screen, keys, frame, interrupt handler, exit) |
| `asm/ntc_plat_cpcfw.asm` | CPC platform through the firmware (text, keys, mode, clock) |
| `asm/ntc_plat_cpm.asm` | CP/M platform (BDOS console, own stack, warm boot) |
| `asm/ntc_plat_test.asm` | test harness platform (console through I/O ports, for `test/ntcrun.py`) |
| `asm/ntc_plat_cpcmin.asm` | CPC platform with minimal firmware: the `cpc` screen / keys / interrupts, the firmware kept for discs and ROMs (handed back per call) |
| `asm/ntc_plat_cyborgos.asm` | the CyborgOS platform: a program in a slot of the hypervisor - `;@base cpm` (gen.js takes the cpm platform's text and classes) plus CyborgOS's own: a `.CYB` out, VT52 by default, `CybSys` (`lib/cyborgos/`) |
| `asm/ntc_plat_baremetal.asm` | Bare Metal: built from its org, nothing assumed - every routine an empty one to fill in for a machine of your own (`lib/baremetal/` the classes, the same) |
| `asm/ntc_plat_zxn.asm` | ZX Spectrum Next platform, straight to the hardware, laid out as the `cpc` one: the tilemap as the text screen, the 8 x 5 keyboard, the line interrupt every 52 lines; the compiler adds the NEX file's start stub (NMI off, the MMU slots) |
| `asm/ntc_plat_msx.asm` | MSX platform: a cartridge ROM (`"AB"` at #4000, 16K / 32K, the variables in RAM from #C010 - the compiler's romLayout), the BIOS kept (its keyboard buffer, its interrupt: JIFFY, H.TIMI for normal mode), the console on the MSX's own video chip (`asm/ntc_lib_vdp.asm`) |
| `asm/ntc_plat_msxcard.asm`, `ntc_plat_msx9990.asm` | `;@base msx` with the console on a V9938 card at #88 / a V9990 at #60 (their own `ntc_plat_vdev` section in place of msx's) |
| `asm/ntc_plat_sc3000.asm` | Sega SC-3000: a cartridge ROM at #0000 (16K / 32K / 48K, the restart vectors), 2K of RAM, the TMS9918 console, the keyboard matrix, the frame interrupt |
| `asm/ntc_plat_cpccard.asm`, `ntc_plat_cpc9990.asm` | `;@base cpc` with the console on an MSX V9938 card (AMSDAP, &FF88) / a V9990 (AMSDAP or Powergraph, &FF60) |
| `asm/ntc_lib_vdp.asm` | the video chips: a text console on a TMS9918 / V9938 / V9958 or a V9990 (`ntc_vcon`, `ntc_vtms`, `ntc_v9`, `ntc_font6`), and the VDP / V9990 classes' engines (`ntc_vdpc`, `ntc_v9c`) |
| `lib/<platform>/*.cls` | the platform classes: `StdIO.cls` (console), `System.cls` (what the machine is), `FileSystem.cls` (files), `Memory.cls` (RAM pages, heap), `List.cls` (linked lists); the CPC platforms also `Graphics.cls`, the CPC platforms, zxn, msx and sc3000 `Keys.cls` (keys held down, joysticks); `VDP.cls` (a TMS9918 / V9938 / V9958: msx, msxcard, sc3000, the CPC platforms through AMSDAP) and `V9990.cls` (msx, the CPC platforms) |
| `hwlib/` | Optional game libraries, one class per video chip (named after the chip, or the machine where there is no chip): `Zxn.cls`, `Cpc.cls`, `Asic.cls`, `Tms9918.cls`, `V9938.cls`, `V9990.cls` - the same core calls (Init, Pattern, Put, Hide, Anim, Move, Bounds, Frame, X, Y), each chip's own calls on top - `StdIO_<chip>.cls` consoles, `Vec.cls` (3D). Nothing in the compiler uses them: a program adds the classes it wants to its project (a project class replaces a platform class of the same name). `hwlib/README.md`; `hwlib/tests/` a test of each per machine, `node hwlib/tools/build.js` builds them |
| `ntc3d/` | NTC3D: a 3D framework for the ZX Spectrum Next (zxn, Layer 2 256 x 192, double buffered, solid shaded polygons) - `E3.cls` (the engine: camera, filler, clipper, stars, flat faces, text), `Obj3D.cls` (up to 32 objects: classes and masks, movers, hits, events, bolts, debris, fireballs), `Fly3D.cls` (flying the camera), `Hud3D.cls` (the HUD on the ULA), `Nx.cls` (NextRegs, palettes). Optional, as hwlib: a game adds them to its project (game.json's `framework`). `ntc3d/FRAMEWORK.md` is its manual; `node ntc3d/tools/e3models.js` makes a game's models (`E3Data.cls`, `NAME.DAT`), `node ntc3d/tools/build.js` builds a game (project, asm, NEX), `node ntc3d/tools/zesshot.js` runs a NEX in ZEsarUX for pictures, `ntc3d/tools/emu/` its own Next emulator for game tests (Python: z80, pillow); `ntc3d/example/ROCKS` the example game |
| `../docs/requirements.md` | What you need to use NTC, rebuild its generated files and run the tests; the targets it builds for |
| `../docs/userguide.md` | Language reference: every keyword by topic, with an example and its VB5 / VB6 differences |
| `../docs/architecture.md` | Memory maps, the ROM structure, interrupts and start up |
| `../docs/md.md` | The Sega Mega Drive / Genesis platform (`md`): NTC on the 68000, its memory, classes, building and testing |
| `../docs/m65.md` | The MEGA65 platform (`m65`): NTC on the 45GS02, its memory, classes, building and testing (with Xemu and NTC's test driver, `test/xemu/`) |
| `../docs/cyborgos-readme.md` | CyborgOS: a separate project written in NTC BASIC (`bas/cyborgos320kb`, `bas/cyborgos128kb`) - its own README, user guide, design and todo list |
| `../docs/tutorial/` | The tutorial: 77 small pages (1.1 the IDE ... 14.4 a game loop in a Tick), contents in `README.md`; every example is checked by `test/tutcheck.py` |
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
- Temps are numbered from 0 in each statement. A Function called inside an expression would
  overwrite the caller's temps that still hold values (`U(a) - U(b)`), so pass 1 notes each
  procedure's temp count and, at each call, the slot the caller has reached (`live`); after
  pass 1 `decideTempBases` gives each procedure a first slot above its callers' live temps,
  and `tmp()` / `stmp()` / `ltmp()` add it in pass 2. Calls with nothing live cost nothing;
  interrupt Ticks, `Interrupt` hooks and `AddressOf` targets (they can run at any point) go
  above everything.
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

| Key | Meaning | cpc / cpcmin | cpcfw | cpm | test | zxn | msx | sc3000 |
|---|---|---|---|---|---|---|---|---|
| `;@org` | default org (the GUI's Org box empty) | #0040 | #0040 | #0100 | #4000 | #0040 | #4000 | #0000 |
| `;@text` | `glyph`: Print text as ZOSCII glyph words; `byte`: as byte strings (string pool + `kw_printstrvar`) | glyph | byte | byte | byte | glyph | byte | byte |
| `;@scrinit` | the program starts with `kw_scrinit` (mode 1, clear) when it uses the screen | 1 | 0 | 0 | 0 | 1 | 1 | 1 |
| `;@irq` | has `ntc_plat_irqon` (own interrupt handler: normal mode ticks, `Interrupt`) | 1 | 0 | 0 | 0 | 1 | 1 | 1 |
| `;@stack` | a label or address: the program's own real stack (set before `ntc_csp`) | - | - | ntc_cpmstack | - | #C000 | - | - |
| `;@cols` / `;@rows` | console size | 40 / 25 | 40 / 25 | 80 / 24 | 40 / 25 | 40 / 32 | 40 / 24 | 40 / 24 |
| `;@rom` | a cartridge: the ROM's start and end - the compiler's romLayout puts what the program writes in RAM, `ntc_plat_romhead` at the org | - | - | - | - | - | #4000 #C000 | #0000 #C000 |
| `;@ram` / `;@ramtop` | the cartridge's RAM image's org / the end its variables must stay under | - | - | - | - | - | #C010 / #E000 | #C010 / #C800 |
| `;@romfile` / `;@romsizes` | the ROM file's extension / the sizes it is padded to (K) | - | - | - | - | - | ROM / 16 32 | SC / 16 32 48 |
| `;@irqrate` | interrupts a second (Option Class Interrupt's rates; default 300) | - | - | - | - | - | 50 | 50 |
| `;@islc` | the handler passes C = 1 at a frame's interrupt (`DEFINE NTC_ISLC`: ntc_isl_tick) | - | - | - | - | (always) | 1 | 1 |
| `;@vdp` | the console is a video chip on ports (`NTC_VDP`: `asm/ntc_lib_vdp.asm`'s console sections) | - | - | - | - | - | 1 | 1 |
| `;@base` | built on another platform: its text and classes, its `;@` keys and `;##` sections less the ones it has its own of (gen.js) | - | - | - | - | - | - | - |

The CPC platforms are three amounts of firmware: `cpcfw` all of it; `cpcmin`
(`ntc_plat_cpcmin.asm`) = the `cpc` file plus the firmware calls - each one (`fs_go`) hands
the machine back (`fs_fwon`: the firmware's 3 bytes at #38, `ei`; `fs_fwoff`: `di`, NTC's
handler, `#8C | mode` to the gate array, CRTC start #3000) - for FileSystem (CAS calls,
AMSDOS RSXs) and `System.Command` (any RSX, KL FIND COMMAND + KL FAR PCALL); `cpc` none.

`zxn` (`ntc_plat_zxn.asm`, `lib/zxn/`) is the ZX Spectrum Next straight to the hardware, laid out
as the `cpc` platform so programs and their maps carry over: the program from #0040 in RAM pages
16-21 (#0000-#BFFF), the stack from #C000 down, bank 5 - what the ULA and the tilemap show - at
#C000-#FFFF. The compiler writes a NEX file (`DEVICE ZXSPECTRUMNEXT`, `MMU 0 5, 16` before the
org, `SAVENEX` at the end; the name from the `name` option, else `NTC.NEX`) with a start stub in
bank 5 at #7E00: the NMI buttons off (NextReg 6 bits 3 and 4: Multiface M1, DivMMC DRIVE),
DivMMC's entry points cut to `rst 8` with ROM 3 selected (NextRegs #B8 = 2, #B9 = 0, #BB = 0 - it
would page DivMMC's ROM in on a fetch from #0000, #0038, #0066 ... otherwise; its automatic paging
is left on and port #E3 untouched, since turning it off, or that port, loses NextZXOS's esxDOS
state, which CyborgOS's SD drive calls on: ROM 3 into slots 0-1, `rst 8`), 28MHz, IM 1, the slots
(slot 3, where the stub runs, last, from its copy in slot 7), then `ntc_start`. NextRegs go through ports #243B / #253B, so the
program needs no Z80N opcodes. The text screen is the tilemap in text mode: a byte a character,
40 x 32 (Mode 0, 1) or 80 x 32 (Mode 2), yellow on blue. Interrupts are the line interrupt, set 52
lines on by each one - 6 a frame of 312 lines, 300 a second, as the CPC's 6 a frame; `Frame` waits
for raster line 192. `End` is a soft reset (NextReg 2) back to NextZXOS. No files yet (FileSystem
says NotSupported), Memory is Small only. Graphics draws on Layer 2 (320 x 256, double buffered,
the CPC's 320 x 200 shown 28 rows down; the platform's own `ntc_gfx`, in place of the library's);
`Option NexData "FILE", blocks` puts a data file's 16K blocks in the NEX file's banks (1-4, 6, 7,
11, 22-111; `ntc_nexdata`: the count, then each block's bank) - `zxn_sel` (HL = a bank) puts one
in #4000-#7FFF. `#If NTC_ZXN` is predefined; the assembly has `DEFINE NTC_ZXN` (only there:
`IFDEF NTC_ZXN` in the library and in `#asm` - sjasmplus's IFDEF tests DEFINEs, not labels).

`msx`, `msxcard`, `msx9990` and `sc3000` are cartridges (`;@rom`): the compiler's romLayout
(after holeLayout) keeps the code, the threads, the strings and the numbers in the ROM and moves
what the program writes into an image built for RAM (`DISP` `;@ram`) after the code - the
Variables part, labelled data in the library (a label with data after it; unlabelled data after
code is inline opcodes and stays), @data and @romram sections, `#asm` data - which the start
code copies to RAM; a variable that is only `ds` becomes an equ after the image (cleared, not
stored). `; @const` on a label's line, or a section marked @const, keeps a table in the ROM.
IF / ELSE / ENDIF lines go to both parts. The platform's `ntc_plat_romhead` section is put at
the org (the MSX header and INIT; the SC-3000's restart vectors) and the ROM is padded to
`;@romsizes` (`OUTPUT "NAME.ROM"` / `.SC`). `cpccard` and `cpc9990` are `;@base cpc` with
their own screen sections. The consoles of all six are `asm/ntc_lib_vdp.asm`'s: `ntc_vcon` (the
cursor, wrap, scroll) over a device table in the platform's `ntc_plat_vdev` (`ntc_vtms`: the
TMS9918 family's text modes; `ntc_v9`: a V9990 bit map with a 6 x 8 font), on the real stack
through `ntc_vcall`.

`md` (`ntc_plat_md.asm`, `ntc_lib_68k.asm`, `lib/md/`) is the Sega Mega Drive / Genesis: a 68000,
so its own keyword library and 68000 output (vasm, Motorola syntax; `test/mdbuild.py` builds the
`.md` cartridge ROM). The thread is A7 in user mode; interrupts push on the supervisor stack, so
they are on all the time and there is one mode. Threads are longs (`dc.l`), variables live in RAM
from $FF8000, so their addresses are 16 bits sign extended. The console is plane A (40 x 28); the
platform classes are `Vdp` (colours, tiles, planes, scrolling, the 80 sprites), `Pad`, `Psg`,
`StdIO`, `System`. `docs/md.md` has all of it; `bas/cyswarm/` is a game built with it.

`m65` (`ntc_plat_m65.asm`, `ntc_lib_m65.asm`, `lib/m65/`) is the MEGA65: a 45GS02, so its own
keyword library and 45GS02 output (vasm, 6502 oldstyle syntax with `-mega65`; `test/m65build.py`
builds the `.PRG`). The thread is SP, 16 bits after `CLE`; a thread word is the keyword's address
less 1 (`rts` adds it back). Interrupts would push onto the thread, so they are off all the time
(the NMI blocked) and there is one mode. The console is 80 x 25 text; the platform classes are
`Vic` (a 320 x 200, 256 colour game screen in two buffers, with 80 sprites, stars and a text layer
drawn by the CPU and the DMA chip), `Joy`, `Sid`, `StdIO`, `System`. `docs/m65.md` has all of
it; `bas/cyswarm_m65/` is the same game built with it.

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

### The keyword library ROMs (Library: ROM, cpc / cpcmin / cpcfw)

The library can live in a 16K background ROM instead of in each program (`Option Library
ROM`, `library: 'rom'`, GUI **Library: in ROM**). One ROM per platform, each with its own
name and file (`NTC CPC` NTCCPC.ROM, `NTC CPCMIN` NTCMIN.ROM, `NTC CPCFW` NTCFW.ROM:
`ntcRomFile`), so all of them can be fitted at once.

- **The platform files** mark what differs in a ROM with `IF NTC_ROMLIB ... ELSE ... ENDIF`
  (every program has `NTC_ROMLIB equ 0`; ntcRomAsm keeps the IF part and drops the rest), and
  a section with `@romram` in its header runs from RAM in the ROM (the linker ignores the
  word). cpc / cpcmin: the gate array writes keep the upper ROM on (`#84 | mode` in place of
  `#8C | mode`); the first mode set copies the font from the lower ROM in the ROM itself
  (lower ROM on, upper stays on - no copy to #C000); `ntc_plat_scroll` and `ntc_plat_cls`
  (both read the screen: the scroll copy, the LDIR fill) are a `@romram` section that turns
  the upper ROM off round the work and sets `ntc_uroff`; the interrupt handler
  (`ntc_plat_irqh`, `@romram`) turns the ROM on for its call of `ntc_irqv` while `ntc_uroff` is
  set and off again after; `ntc_plat_memtop` is `NTC_ROMDATA`; cpcmin's `fs_fwoff` puts the mode
  back with the ROM on. The program's start uses the firmware (still there at that point on
  every CPC platform) to find the ROM; KL ROM SELECT lets interrupts in, so `di` follows.

- **Making the ROM** (`ntcRomAsm(platform, registry)` in ntc_compiler.js, run by
  `test/genrom.js`): compiles `Print` with `library: 'allmodes'` (every section, both mode
  copies), drops what a ROM can't use (plain `ntc_xn` - the hook version is kept; asserts),
  and rewrites the uses of the program's own symbols as RAM variables the start code fills:
  `ntc_free` -> `(ntc_v_free)`, `ntc_start`, `NTC_STAMP`, `NTC_ROMENABLE` (an `IF` becomes a
  test of `ntc_v_romen`). `NTC_STRMAX` is 255 and `NTC_MEMBANKS` 64. Lines are sorted into code
  (the ROM), initialised variables (assembled for `#8800` and copied there by the patcher), the
  other variables (`#9400` up, cleared) and constants. A capacity byte before a buffer goes with
  the buffer; a label at the end of a section, or alone between two variables, stays with the
  variable before it (`ntc_pgstk_top`). A run of variables one after another in the source
  stays together and in order (code counts on it: `ntc_plat_mode` copies 4 bytes into
  `ntc_sbpc ... ntc_sshift`); runs are ordered by the registry (known ones first). So a new
  variable goes at the end of its run, or the asserts stop the build (a known one moved). The Graphics
  section runs from RAM too: it reads the screen, which the upper ROM hides; `gfx_begin` / `gfx_end`
  and the screen routines (`gfx_line`, `gfx_double`, `gfx_copyrows`) turn the upper ROM off
  and on round themselves (KL U ROM DISABLE / ENABLE, so the firmware's interrupts keep it).
  The fast ticker event gets the ROM's number as its far address. On cpc / cpcmin the same
  hooks use `ntc_urom_off` / `on` that write the gate array directly (and set `ntc_uroff`).
- **The ROM:** an AMSDOS header (each file is 16512 bytes), the standard header (background,
  names, `jp ntc_rom_init` - `scf / ret`, no RAM taken; no BASIC commands yet), then NTC's block
  after the names: `"NTC", 1`, `"CPCFW", 0`, `dw ntc_rom_patch, ntc_rom_index, NTC_ROM_N`.
  The index is one `dw` per number (0: no longer in this ROM); padded with 0 to 16K.
- **The registry** (`src/asm/ntc_rom_<platform>.txt`, bundled as `NTC_ROM_REG` by gen.js):
  `<n> code <name>` (a routine's number), `- data|bss|const <name> <value>` (a variable's
  fixed address, a constant's value), `gone` (no longer in the ROM: the number is never used
  again). Only what programs can name is registered: section names, `NTC_ROM_RUNTIME` (labels
  the compiler's own code uses), labels the platform classes name, and their `_n` copies.
  genrom.js appends new entries (numbers in order; variables at the address they got) and the
  ROM's source asserts that every known variable is still where the registry says.
- **The program** (`ntcRomJumpBlock`): in place of the library, the routines its text names
  as `name: jp <number>`, the variables and constants as `equ`, and `ntc_rj_find`: KL ROM SELECT
  on slots 0-31 (the first call keeps the caller's selection), a background ROM (`#C000` = 1)
  whose names are followed by the NTC block for this platform; then `call ntc_rom_patch` with
  HL = jump block, BC = entries, A = slot. The patcher copies its variables to `#8800`, clears
  `#9400` up, stores the slot in `ntc_v_rom`, and replaces each number by the address (carry,
  DE = the number, for one it hasn't got). The start code fills `ntc_v_*` and pushes
  `ntc_rj_exit` (KL ROM DESELECT: the caller's selection back) before everything else, so
  `End` and `Option Stack`'s return both come back through it. `ASSERT ntc_free <= #8800`.
- **Interrupts:** in the firmware's interrupt the lower ROM is on, so RAM below `#4000` (where
  the jump block is) can't be reached from the event. The start code gives `ntc_irqv` the ROM's
  own address of `ntc_isl_tick` (`ld hl,(ntc_isl_tick + 1)`: the patched jump).
- **Cost:** 10 T per keyword (the `jp`); the sieve timing is about 25% slower. Programs lose
  the library's size (SIEVE 1588 -> 680 bytes).
- Firmware and AMSDOS calls from the ROM return to it (the firmware restores the upper ROM
  selection); all three checked on the real 6128 ROMs with `realcpc` (`XROM=`): self tests,
  files, overlays, pages, interrupt classes, the Memory class, cube3d.
- Sizes (one ROM each, Graphics out): NTCCPC about 2.9K free, NTCMIN about 1.0K, NTCFW about 1.4K.
- **ROM sets** (`ntcRomAsm(platform, registry, { place, measure })`, `genrom.js --cap --place
  --out`). Sections marked `@far` (real stack code: `ntc_memcore2` - the part of the Memory
  core after the `mem_go` wrappers -, `ntc_mem`, `ntc_memcopy`, `ntc_list`, `ntc_listsort`)
  may go into ROM 2, 3 ... (`place`: section -> ROM). genrom measures (one oversized ROM from
  #4000 with markers round each `@far` section), moves groups of `@far` sections that name
  each other (`chunks[].deps`: header deps and the labels they use) out until the main ROM
  fits `--cap` (16384), builds, and moves one more while a ROM is too big. Each other ROM has
  a header (background ROM, `scf / ret` init), names `NTC CPCMIN2` ..., and the block
  `"NTC", 2, platform, 0, dw NTC_ROM_SET, db k, NTC_ROM_COUNT`; the main block adds `dw
  ntc_rom_patch, ntc_rom_index, NTC_ROM_N`. `NTC_ROM_SET` is a CRC of the code and placement.
  Crossing between ROMs is rewritten (`crossRewrite`): `call x` -> `call xc_x`, `jp / jr x` ->
  `call xc_x : ret`, `jp cc, x` -> `jp cc, ntc_xt_n` (a trampoline `call xc_x : ret` at the
  section's end); any other naming of another ROM's code (or djnz) stops the build. Only real
  stack code may cross: every `call` in the library already is, and genrom lists the rewrites
  in sections that aren't `@far` ("cross:") to check. `xc_x` (RAM, 10 bytes): `ld (ntc_rx_bc),
  bc : ld bc, x : jp ntc_rx_c<rom>`; `ntc_rx_c<k>` saves `ntc_rx_cur` on the stack, selects ROM k
  (`ntc_rx_sel`), restores BC, calls x through `ntc_rx_jt` (`jp 0`, written), keeps BC, selects
  the saved ROM, restores BC, `ret` - registers and flags pass both ways. `ntc_rx_sel`: cpc /
  cpcmin `ld b, #DF : ld (ntc_rx_cur), bc : out (c), c` (the variable first, for the interrupt
  handler); cpcfw `call #B90F` (KL ROM SELECT, keeping AF / DE / HL and the interrupt state), so
  the firmware's record of the ROM in stays right for its events' far calls. RAM code is
  reached from the main ROM, so it names main ROM code directly, except a RAM section a far
  section uses (`ntc_membank`): there all ROM code is far called. The index points a far
  routine's number at its `xc_`. `ntc_rx_cur` / `ntc_rx_s0..7` are always there (the patcher
  fills them from DE = the slots); cpc / cpcmin's `ntc_irq_rom` selects `ntc_rx_s0` round the
  interrupt classes' count and `ntc_rx_cur` after. The program's start: `ntc_rj_scan` finds ROM
  `ntc_rj_want` (0: any stamp, its count in `ntc_rj_n`; the others: the main one's stamp), the
  slots go into `ntc_rj_slots`, then the main ROM's patcher. Checked on the real 6128 ROMs:
  2-ROM sets on all three platforms, 4-ROM sets in slots 2, 9, 4, 12 (cpcfw, cpc), with
  interrupt classes counting during far calls.

### Flavours (ntcPrep)

`ntcCompile` first hands its files to `ntcPrep`, the flavour preprocessor: every file comes
back as VB5 text for the one parser and compiler. A file's first line (`Option Flavour JS`,
`//# Option Flavour JS`) picks its flavour, else a `.js` name, else `options.flavour`, else
`vb5`. The flavours come from a factory, `ntcFlavours()`: one function each, `(file, options) ->
{ text, lines, cls, errors }`; `vb5` passes the text through (only the Option Flavour line is
blanked). A translated file carries `lines` (the source line of each VB line: the parser's
`srcLine`), `orig` (the user's file name: messages are renamed back at the end) and a `.cls`
name when it is a class. The JS flavour is `js/ntc_flavour_js.js` (`ntcFlavourJs`): tokens,
then a recursive reader that writes VB lines; expressions fully bracketed so VB's precedence
never matters; text typing (`+` with text -> `&`) from what the file declares. The result has
`vbfiles` (the VB5 text of every file); `cli.js --vb` prints it. Plan and table:
`docs/js_flavour.md`. The Locomotive flavour (`js/ntc_flavour_loco.js`, `ntcFlavourLoco`) is
line based: pass 1 tokenises each line (keywords, `a` / `a%` / `a$`, `'#` hints, DATA items, DIM
sizes), pass 2 writes each line's statements as one VB line (`:` joined, so a one-line `If`
keeps them all), the declarations and the DATA table at the top, `End`, the DEF FN functions
and helpers at the end. A line using something unsupported throws inside pass 2: the line
becomes `' WARNING: ...` (its number kept when something jumps to it) and a warning - flavours
return `warnings`, ntcPrep passes them on, ntcCompile adds them to its own.

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
  not padded). Also on a `ByVal` parameter (`ByVal k As String Max 1`: its copy n long, longer
  ones cut) and a function's result (`Function H2(v As Integer) As String Max 2`) - else they
  are as long as the program's longest string, each one that long in the program's file.
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
- `Option PressAnyKeyOnEnd ["message"]`: every end of the program (`End`, `Error`, a failed
  `Debug.Assert`, the last line: `emitStop`) prints the message on a line of its own
  (`kw_printnl0`, default `Press any key`) and runs `kw_waitkey` (`ntc_plat_getkey`) before
  `kw_stop` - a program RUN" from AMSDOS resets the machine when it ends.
- `Option Stack address`: the start code saves the caller's SP (`ntc_ssp`), sets SP, and pushes
  `ntc_sback` (switch back to the caller's SP, ret) so `End` (`kw_stop`: `ld sp,(ntc_csp) / ret`)
  still returns to the caller. ASSERT: below `ntc_start` or 64+ bytes above `ntc_end`. Options
  are all read first; the start code applies Stack, then RomEnable, then runs the program.
- `Option RomEnable All | rom [, rom] ...` (cpcfw): the start code starts the background ROMs
  again (KL ROM WALK / KL INIT BACK per ROM, DE = `ntc_end`, HL = `#ABFF`) unless CAS IN OPEN
  is already AMSDOS's far call (`#DF` at `#BC77`: the program was CALLed and they run).
  `RUN"` of a binary resets the firmware and drops them. Writes `NTC_ROMENABLE equ 0 / 1`.
- `Option Library ROM | RAM` (cpc, cpcmin, cpcfw): the keyword library in the platform's ROM -
  see "The keyword library ROMs" in section 4.
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
returns `NotSupported` (-1); every result below 0 is a status. `Devices` / `SelectDevice` /
`CurrentDevice`: how files travel, TAPE / DISC (`|TAPE`, `|DISC` on cpcfw; CP/M: DISC).
`Volumes` / `SelectVolume` / `CurrentVolume`: drives - on cpcfw any name the DOS has an RSX
for (KL FIND COMMAND, KL FAR PCALL: |A, |B, |C, |M ... AMSDOS, M4, UniDOS), on CP/M the BDOS
drive calls (24, 25, 14). Neither can list volumes: `Volumes` is what the platform knows
plus every volume used successfully (SelectVolume, or a Load / Save with "C:NAME").
`Capability("CPMVERSION")`: BDOS 12. CP/M: everything, through
BDOS FCBs and random records (`ntc_plat_cpm.asm`, section `ntc_plat_fs`: two handles plus
a slot for the whole-file calls, 170 bytes each). CPC firmware: Load / Save through the
cassette calls (CAS IN / OUT DIRECT: disc with AMSDOS, else tape), and one open file
(handle 1: CAS IN CHAR / CAS TEST EOF for ForRead, CAS OUT CHAR for ForWrite - an ASCII file
as BASIC's OPENOUT makes; section `ntc_plat_fsseq`, sharing the 2K buffer, so Load / Save
give Failed while it is open; `fs_hmode` is in `ntc_plat_fs`). cpcmin: the same; its
`ntc_plat_fsseq` is `@ramonly` (below). CPC hardware and test: none yet. The file routines run on the real stack with interrupts on (`fs_go`), like the
other host calls; `ntc_capfind` (in `ntc_lib.asm`) searches a class's capability table and
leaves Z set when found. Details in `userguide.md` section 17.

**ROMDISC** (volume R; `ntc_lib.asm` section `ntc_romdisc`, `@ramonly`; per platform
`ntc_plat_romsel` - `rd_sel` / `rd_unsel`: cpc straight to the gate array and `#DFxx`, keeping
`ntc_rx_cur` right in a Library: ROM program; cpcmin / cpcfw KL ROM SELECT / DESELECT, inside
`fs_go` where the firmware is alive - and on cpcmin / cpcfw `ntc_plat_rdroute`). Read-only files
in ROMs made by `ntcRomDisc(files)` (ntc_compiler.js; `test/genromdisc.js`): background ROMs
`NTCDISC.ROM`, `NTCDISC2.ROM` ... with the block `"NTC", 2, "ROMDISC", 0, dw stamp, db place,
db ROMs, dw directory`, data from `#C040`; ROM 0's directory: 18 byte entries (name 8 +
extension 3, flags - bit 0 compressed, bit 7 the end -, ROM, address, 3 byte length), read until
the end flag; a file runs on into the next ROM at `#C040`. `rd_mount` finds the disc once
(slots 0-31, ROM 0 then the others by its stamp). The routines (`rd_load`, `rd_open` - handle 2,
`rd_readb`, `rd_read`, `rd_readln`, `rd_eof`, `rd_close`, `rd_exists`, `rd_size`, `rd_dirent`,
`rd_selvol`) take `rd_a1 .. rd_a3` and `rd_res`, return HL, and run on the real stack: through
`rd_go` (cpc, whose FileSystem class has R only) or `fs_go` (cpcmin / cpcfw). There a method
names both routines and jumps to `rd_route` (by name: `"R:..."`, or no volume and `fs_vol` =
`"R"`), `rd_routeh` (handle 2) or `rd_routev` (`SelectVolume "R"`: `rd_fsvol` sets `fs_vol`):
these run on the thread (no call, no push), copy `fs_a1 .. fs_res` into `rd_a1 .. rd_res` when R
is picked, and jump to `fs_go` / `fs_go0`. No disc driver: FileSystem's methods just reach the
disc's routines when the volume is R.

**Memory.** `Option Memory Small | CPCExpansion [maxpages]` picks the scheme when
compiling (`NTC_MEM_SMALL` / `NTC_MEM_CPCEXPANSION` for `#If`; library sections marked
`@if:ntc_mem_small` / `@if:ntc_mem_cpcexpansion` - a section whose `#Const` isn't set isn't in
the library, so both schemes can use the same labels and the class file stays one).
`ntc_memcore` is shared (calling frame, far pointers, heap fitting over `mem_hlo`-`mem_hhi`,
read / write); `ntc_mem` is the scheme. **Small** (default on cpm, test): one heap over free
main RAM, from `ntc_end` to the first of `ntc_plat_memtop` (a new platform section: CPC
#A600, CP/M the BDOS at (6)), the stack less 256, an Option Reserve start (`ntc_rsvtab`, a
table the compiler writes before `ntc_end`). **CPCExpansion** (default on the CPC
platforms): 16K pages switched into
`#4000-#7FFF` by the gate array (C4-C7 + bank bits, the port's high byte `#7F`-`#78` picking
the 512K block), up to a 4MB expansion. One class for every model - small (64K, 1 page: main
RAM #4000), medium (128K, 5), large (up to a 512K expansion, 33), huge (4MB, 257): the first
call probes (markers written to bank 63 down to 0 and main RAM, read back, so banks the
hardware doesn't decode show up). Page numbers are 16 bit. Page types: C code (overlay
classes load into these), D the heap (`Alloc` / `Free`), I interrupt handler blocks (a label
for now), U the program's own (music, level data). Two tables, one entry a page: the
RAT (its type: - free, C, D, I, U, B) and the port table (the 2 bytes that select it, so
selecting a page is a look-up). A free page is found by scanning the RAT (CPIR), freed by
writing - back - no lists. C / I / U take from the low block first (main + the #7F block), D
from the high one (#78-#7E), each falling back to the other.
The tables (3 bytes a page) go from `ntc_end` up, sized to what the probe finds, fewer pages
when they don't fit below #4000. `AllocPage` / `FreePage`, `SelectPage`, `Map(first,
count)`, a heap in D pages (`Alloc` / `Free`, far pointers as Longs: page in the high word).
`Copy` goes through the 2K buffer FileSystem uses (`ntc_buf`), so page to page works with
one window. The page in the window is kept in `mem_cur`, written before the port, for a
future interrupt handler to put back. The program and its stack must be out of the window
(`Option Reserve &H4000, &H4000`), else `Pages() = 0`. cpm: no pages. Code: `ntc_lib.asm`
sections `ntc_memcore`, `ntc_mem` (two, one per scheme), `ntc_memcopy`, `ntc_buf2k`;
`bas/memmap.bas` draws the map. *maxpages* becomes `NTC_MEMBANKS equ` (the banks probed, and
the size of the fixed bank data). **Whole banks**: list 6, type B (`mem_kinds` "--CDIUB";
`mem_listof` looks at 5 kinds, `mem_kindlist` still 4, so AllocPage can't ask for B).
`mem_allocbank` takes the first bank whose 4 pages (2 + 4 x bank ...) are all free (only
banks the tables cover: `mem_bankcount` = (pages - 1) / 4). `mem_callbank`: copies
`ntc_bk_stub` .. `ntc_bk_end` (16 bytes) into the bank at its own address, byte by byte
through the window (`mem_sel` of the bank's page for that address), then `ntc_bk_go`
(section `ntc_membank`, `@romram`): interrupt state saved (`ld a, i`), `di`, the real SP in
`mem_bksp`, both ROMs off (`ntc_plat_rmr` gives the ROM / mode byte now: cpc / cpcmin from
`ntc_smode`, cpcfw from the firmware's C'), then `out (c), c` with C2 for the bank - the next
byte comes from the bank's copy of the stub, which sets SP to 0, pushes the return to
`ntc_bk_ret` and jumps to the address (HL = value). `ntc_bk_ret`: `#7FC0` out (main RAM: the
next byte is the program's copy again), SP, the ROM byte, `ntc_rampt` (the window's page) and
the interrupt state back.

**Overlay classes** (`Option Class Overlay ["FILE"]`, cpcmin / cpcfw with CPCExpansion; for
Small and cpm see one overlay area below). The
compiler marks the thread of each of the class's procedures (`{t: 'ovl'}` ... `{t: 'ovlend'}`
in the keyword list); the emitter sends those lines to the class's own list, written after
the program as `OUTPUT "PROGRAM.001"` / `ORG #4000` ... `OUTEND` - one assembly, so every label
is shared and nothing is linked at load time; only the page is decided at run time. The
class's variables, the call stubs, `#asm` blocks and asm keyword procedures stay in the
program. The call stub, after the usual argument copies and `ld (p_x_rs), sp`, jumps to
`ntc_ovl_enter` (`ntc_lib.asm` section `ntc_ovl`): it keeps `mem_cur` in the procedure's
`_pg` word and switches in the class's page from its block (`ovl_blk_<class>: dw page,
db "PROGRAM.001", 0`), loading the file first (`mem_take` a C page, then FileSystem's `fs_load`
through `fs_go`, which returns into `ovl_mt`, a one-word "thread"). The return stub switches
`_pg` back. The compiler adds `Load` / `Unload` / `Loaded` / `Page` (asm keywords on the
same section) to the class text before parsing. `--raw` output carries the overlays after
`ntc_end`; the harness cuts the binary there and copies the page files (the names in the `OUTPUT` / `SAVEAMSDOS` lines) to its disc folders.

The shared parts (variables, the "Overlay not loaded" message, `ntc_ovl_fresh` - page
variables cleared and the local memory made one free block after a load - local memory,
the members' result) are in section `ntc_ovlcom`; `ntc_ovl` comes in two versions, picked by
`@if:ntc_mem_cpcexpansion` / `@if:ntc_mem_small`. **One overlay area** (Small, cpm and
cpcmin / cpcfw): `ovl_cur` is the class block in `#4000-#7FFF`, and a block's page word is 1
while its class is there. `ntc_ovl_enter` looks at the caller's thread (SP when the stub
jumps): in `#4000-#7FFF` it is code of the class in the area, so `ovl_cur` goes into `_pg`,
else 0. The return stub jumps to `ntc_ovl_ret` with `_pg`: not 0 and not `ovl_cur` means the
caller's class was swapped out, so it is loaded again before going back to its thread. `Load`
/ `Unload` called with a thread in the area give -13 (`OVL_BUSY`). `Private Paged` is ignored
(ordinary variables), since the class doesn't stay. The compiler adds `Option Reserve
&H4000, &H4000` when the program has none covering the area, and `ntc_rsvtab` is always
emitted (the Small heap stops at the area). CP/M page files are the plain bytes (`fs_load`
reads whole records into `#4000`, at most 16K).

**Pages** (`Option Page Name = A, B` or `Option Page "FILE.EXT" = ...`, `Option Home`;
`Option Class Overlay X` is the same as `Option Page X = ThisClass`). The block is `dw page,
end, vsize`, then the file name and the page's name (0-ended each; the name empty for a page
named by its file), so the message says `Overlay not loaded: Level1 (PROGRAM.001)`. A pre-pass (`scanPages`, before parsing, following `#If` /
`#Const` with the compile's predefined names) reads them from every file: `objPages` (id ->
name, file, block `ovl_blk_<page>`, classes), `objClassPages` (class -> its pages, the home
first). Each class still gets its own thread list (`objOvlAsm`); `composePages` writes each
page from its classes' lists, one after another (labels `ovl_<page>__<n>_s` / `_e` around
each, for the sizes). A class in more than one page is written into each; in every page but
its home, **every label its list defines is renamed** `label__<page>` (thread labels, its
paged variables; `X_go` / `X_gs` / `X_rt` references become the copy's own GOTO / GOSUB stubs,
written in the page). A call word `dw p_x_c` whose callee is in the same page, when pass 1's
call graph says the callee is called from one of its own pages (`objLocalCalled`), becomes
`dw p_x_cl[__page]`: a **local entry** in the page (`ld a, 1 / ld (ntc_ovl_lc), a / jp p_x_c`,
for a copied class also `ld hl, <this copy's body> / ld (ntc_ovl_body), hl`). The call stub (in
the program) checks `ntc_ovl_lc` after its argument copies: set means no page switch, `_pg` =
#FFFF so the return stub switches nothing back. A copied class's far calls jump to
`ntc_ovl_enterc` with the procedure's copy table (`p_x_ct: db n`, then `dw block, body` per
copy, the home first; only the home when the class has paged variables): the copy whose page
is in the window (RAM pages: its block's page word = `mem_cur`; one area: block = `ovl_cur`),
else the home; `ntc_ovl_body` gets its body and the stub runs `ld sp, (ntc_ovl_body)`. Blocks
are per page, so loading, `ntc_ovl_fresh` (paged variables of every class in the page), the
one overlay area's `ovl_cur` / `ntc_ovl_ret` and the members all work by page unchanged. Each
page ends with `DISPLAY` lines (the assembler prints the sizes) and the compile result has
`layout` (sizes counted from the thread words; `cli.js --layout`, the GUI's messages). **Page files** are
`PROGRAM.nnn` (`programName`: the `name` option, else `amsdos`, else the main file's name),
numbered in page order; a page named `"NAME.EXT"` keeps that name. Each starts with `dw
NTC_STAMP`, a CRC-16 of the whole program text (`NTC_STAMP equ` at the end of the output);
`ntc_ovl_core` (both schemes) compares it after loading and fails with `OVL_STALE` (-14). A class in a
page may also be an interrupt class (`objClassKind[class].isl` = its slot; the Tick goes
through its call stub, so its page is switched in; refused with Small).

**Graphics** (`ntc_lib.asm` section `ntc_gfx`, class `lib/cpc*/Graphics.cls`): one line loop for
modes 0-2 - C holds a marker of the pixel's bits (`#AA`/`#55`, `#88 >> n`, `#80 >> n`), `RRC C`
steps it one pixel right and its carry means the next byte; the pixel is `C AND IYL` (the
pen's bits for the mode) XORed in. Going down a row: `H + 8`, and when bits 3-5 of H come back
to 0 the character row is done (`+ #C050`) - true for either screen (`#C0` or `#40`). Double
buffering shows `#C000` or main RAM's `#4000` with CRTC R12 (`#30` / `#10`) at the vertical
sync; `gfx_begin` / `gfx_end` put main RAM in the window around drawing on `#4000` and then the
setting in `ntc_rampt` back (the Memory class's `mem_sel` keeps it). Called on the real stack;
uses IX and IY.

**Interrupt classes** (`Option Class Interrupt rate | Frame | Share weight`, cpc / cpcmin /
cpcfw). Section `ntc_islots`: 16 slots of 8 bytes (count, reload, running, due, Tick's call
stub), filled by the start code. A reload of `#8000 + weight` marks a shared slot; the
counting loop skips those. After it, if no fixed slot fell due (`ntc_islfx`) and there are
shared slots (`ntc_islshn`), the current shared slot (`ntc_islsc`) is marked due and its
turns (`ntc_islsw`, loaded from its weight) go down by one; at 0 the next shared slot takes
over. The platform's interrupt handler calls `ntc_irqv` (`ntc_isl_tick`): it counts each
slot down (or, for Frame, looks for the start of the vertical sync on PPI port B) and marks
it due. `ntc_xnh` (the normal mode safe point) runs a due slot's Tick that isn't running, as
a call from that point - like the `Interrupt` hook - and Tick's return stub clears its
running flag. Tick is ordinary BASIC, so nothing runs inside the hardware interrupt but the
counting.

**Keys** (`lib/<cpc platforms>/Keys.cls`, section `ntc_keys` in `ntc_lib.asm`): `ntc_kdown`
(HL = key number) and `ntc_kjoy` (HL = 0 / 1) read all 10 matrix lines through the PPI / PSG
into `ntc_kmat` - straight from the hardware on all three CPC platforms (in a keyword,
interrupts are off, so the firmware's own scan can't cut in) - then put the result through
the method's result pointer, still on the thread, and `ret`. No stack, no IX / IY.

**`@ramonly` sections.** A library section marked `@ramonly` is left out of the keyword ROM
(`ntcRomAsm`); what it names of the ROM's gets registry entries anyway. A `Library: ROM`
program links the `@ramonly` sections it uses into itself (`linkLibrary(..., true)` keeps only
those), and their ROM names come through the jump block like the program's own.
`NTC_ROMLIB` is 1 in a `Library: ROM` program, so such a section takes its ROM-mode code.
Used for cpcmin's `ntc_plat_fsseq` (NTCMIN.ROM had no room for it) and `ntc_gfx` (Graphics: so other
graphics classes can sit beside it; in a Library: ROM program the compiler puts `ntcRomHook`'s
ROM-off calls round its screen work, and `ntc_urom_off` / `on` are exported).

**cpcfw interrupts** (`ntc_plat_irq` in `ntc_plat_cpcfw.asm`, `;@irq 2`: only when the
program uses `Interrupt` or interrupt classes). The firmware keeps its interrupt handler; a
fast ticker event (KL NEW FAST TICKER, block at `#A5F0`) calls `ntc_fwevt` 300 times a
second, which does the same counting as the cpc handler. The event is **asynchronous but not
express**: in the 6128 ROM, KL EVENT (`#01E2`) jumps straight to an express event's routine
from inside the interrupt, with the lower ROM on, and never reads the far address - a routine
below `#4000` (the program starts at `#0040`) then runs ROM code. A plain asynchronous event
runs at the end of the interrupt (on the firmware's own stack at `#B8B4`) through KL FAR
ICALL, which uses the far address: ROM select `#FF`, both ROMs off. Patching RAM `#0038`
instead would miss most interrupts: the lower ROM has its own `#0038` (`JP #B941` on the
6128, `JP #B939` on the 464), used whenever the lower ROM is on - during every firmware call.
Running the interrupts example, 88% of interrupts came with the lower ROM on.
Checked with the real 6128 ROMs: `test/realcpc.c` (scratch tool, see `test/README.md`).

**Arrays after the program.** Arrays (and array descriptors) are no longer `ds` blocks in
the program: the compiler gives them addresses after `ntc_end` (`ntc_bss`, `equ`s), so they
are not in the file. `ntc_free` (= `ntc_bss` + their size) is the first free byte: the
Memory class's tables, the Small heap, `Option RomEnable`'s lowest address and the
`Option Reserve` / Stack / FileSystem / overlay checks all use it. The main thread starts with
`kw_bssinit, ntc_bss, ntc_bss_size` (after the screen set-up): it checks the arrays fit under
`ntc_plat_memtop` (and 256 bytes under the real stack when that is above them), clears them,
or prints a message and stops. Scalars and Strings (their capacity byte) stay in the program.

**List class** (`ntc_lib.asm` section `ntc_list`): linked lists in the Memory heap. A handle
is a far pointer to a 20 byte header (first, last, count, data size, free chain, pools); nodes
(next, previous, data) come from pools of up to 16000 bytes cut into nodes on the list's free
chain. Field access goes through `lst_at` (switch the page in, the address). `Sort`
(section `ntc_listsort`, so the 2K buffer only comes in with it) is a radix sort: two passes
(the key's low byte, then its high byte with the sign bit flipped), each node onto the end
of one of 256 buckets (head and tail far pointers in `ntc_buf`), the buckets joined after
each pass, then the previous links. The inner loops keep the node in registers and switch
pages only when the page changes (`lst_rs_sel`). 5,000 nodes on a 6128: 4.2-4.8 CPC seconds
(`bas/sorttime.bas`, timed with `test/cpctime.py`).

**Paged variables** (`Private Paged` in an overlay class): the compiler routes their
declarations (by label, `objPagedLabel`) into the overlay: Strings into its file, the rest
as `equ`s after `ovl_<class>_end`. The class block is now `dw page, vars start, vars size` and
the name; the loader clears the variables and makes the rest of the page one free block, the
class's local memory (`LocalAlloc` / `LocalFree`: the heap code, `mem_fit`, run on that region
with `mem_hlo` / `mem_hhi` set to it).

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
- **Window data**: in a program built round the window (`Option Reserve &H4000, &H4000`), the
  lines of `#asm` blocks between `; @window` and `; @endwindow` are put in the window hole
  itself, from #4000 (a sjasmplus macro, `ntc_windata`, expanded by the guard that skips the
  hole; a program that ends below #4000 gets them after `ntc_end`, and the file then ends at
  `ntc_fileend`). They are in the file but not in the program's RAM: the program copies them
  at its start, before anything uses the window, into a page that it later switches into the
  window and calls (code assembled for its address there, data). The labels stay the
  block's (renamed as usual), so the block's own code reaches them. CyborgOS keeps its bank
  image and FileCall's page code there (about 2.8K of main RAM)
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
node cli.js main.bas --platform=cpm          cpc (default), cpcmin, cpcfw, cpm, cyborgos,
                                             baremetal, test, zxn
node cli.js main.bas --org=#8000             built to run from there (Option Org)
node cli.js main.bas --amsdos=PROG           also write PROG.BIN with an AMSDOS header when
                                             sjasmplus assembles it (DEVICE + SAVEAMSDOS)
node cli.js main.bas --nocomments            no BASIC source lines as comments
node cli.js main.bas --map=main.map           also write the cross reference
node cli.js main.bas --const=DEMO            a #Const for #If (True; --const=NAME=3 a value)
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

### cpctime.py - time a program at the real CPC's speed

```
python3 cpctime.py t/sorttime.bas '\nNX' --mark=lst_first,lst_sort
python3 cpctime.py prog.bas 'typed keys' --ram=576 --turbo
```

The same emulated CPC as `cpcrun.py`, but it steps one instruction at a time and adds up
the real CPC's time for each: the gate array stretches every instruction to a whole number
of microseconds (4 T steps), so a CPC runs slower than the T states say (cpcrun's `T`). The
300 Hz interrupt comes every 3333 microseconds as on the real machine, so `Ticks`, and
anything a program times with it, matches a CPC. The frame sync follows the same clock (a
frame every 20 ms, the sync high for its first 512 microseconds), so `Frame` and the double
buffer flip wait as long as on a CPC. About 10 times slower to run than
`cpcrun.py`. It prints the screen, the interrupts taken and the run time in CPC seconds;
with `--mark=label,...` also each time the program reaches one of those labels, from the
start and from the mark before (labels from the `.sym` file: `kw_turbo_on`, `lst_sort` ...).

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
- `zxn` (`zxnrun.py`): a ZX Spectrum Next - the NEX file the assembly wrote, loaded as
  NextZXOS loads one (its banks in the file's order, its PC and SP, banks 5, 2, 0 in slots 2-7);
  the MMU slots (8K pages), NextRegs through #243B / #253B, the ULA and line interrupts (IM 1),
  the raster line (#1E / #1F), the CPU speed, the 8 x 5 keyboard (typed text as for the CPC;
  `{n}` = key n held, half row * 8 + bit), and the tilemap read back as text through the
  program's font. A soft reset (NextReg 2) ends the run (`--- halted (a soft reset ...)`);
  `NTC_ZXNREGS=1` prints the NextRegs, the slots and the palette at the end

These are much faster than the CPC emulation (no screen to read back from video RAM).

### mdbuild.py, mdrun.py, mdregress.sh - the Mega Drive (md)

`python3 mdbuild.py Main.bas [More.cls ...] --out=GAME.md [--log]` compiles for `md`, assembles
with vasm (`NTC_VASM`) and fills in the cartridge header. `python3 mdrun.py GAME.md
[--frames=N] [--pad=frame:buttons,...] [--shot=out.png] [--text] [--log] [--untilend]` runs it on
the Genesis Plus GX libretro core (`NTC_MDCORE`), with pads, pictures, plane A as text, and (a
`--log` build) the console's transcript. `mdregress.sh` runs the self tests that fit a machine
with no keyboard, `md_test` first (157 checks of the statements on the 68000). `docs/md.md` says
how to build vasm and the core.

### m65build.py, m65run.py, m65regress.sh - the MEGA65 (m65)

`python3 m65build.py Main.bas [More.cls ...] --out=GAME.PRG [--log] [--list=GAME.lst]` compiles
for `m65`, assembles with vasm (`NTC_VASM65`) and puts the load address in front. `python3
m65run.py GAME.PRG [--frames=N] [--joy=frame:buttons,...] [--keys=frame:text,...] [--shot=out.png]
[--text] [--log] [--untilend]` runs it on Xemu's xmega65 (`NTC_XEMU`) built with NTC's test
driver (`test/xemu/`: a patch and `ntctest.c`), with the joystick, keys, pictures, the console as
text, and (a `--log` build) the console's transcript. `m65regress.sh` runs `m65_test` (163
checks of the statements on the 45GS02) and the VB self tests that fit. `docs/m65.md` says how to
build vasm and Xemu.

### tutcheck.py - check the tutorial

```
python3 tutcheck.py              every page of docs/tutorial
python3 tutcheck.py 8.3 13.5     only those pages
```

Every ```` ```basic ```` block in the tutorial is compiled; one followed by a ```` ```text ````
block is run with `ntcrun.py` and must print exactly that. HTML comments steer it (they don't
show when the page is read): `<!-- file: Counter.cls -->` makes the next block an extra file
for the program after it; `<!-- platform: cpm -->` compiles there; `<!-- run: cpm keys="Ann\n"
cmdline="x" ram=576 files="NOTES.TXT=line\n" -->` runs there with typed keys, a CP/M command
tail, the RAM size and files on the disc; `<!-- nocheck -->` skips a fragment. Part of
`regress.sh`.

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

### genrom.js - the keyword library ROM

```
node genrom.js [platform]       (cpcfw; needs sjasmplus)
```

Makes the ROM's source with `ntcRomAsm`, assembles it, appends new registry entries to
`asm/ntc_rom_<platform>.txt`, makes it again with the new registry and writes
`build/rom/NTCCPC`, `NTCMIN` or `NTCFW.ASM` / `.ROM`. Run `gen.js` after it (the registry goes
into `ntc_lib.js`). `regress.sh` checks that it adds nothing for any of the three.
`ntcrun.py` fits the platform's ROM image in slot 6 when the program wants it (`--library=rom`
or `Option Library ROM`; `NTC_XROM=file` for another one, `NTC_ROMDIR=dir` for a set built
with `--out`), and the rest of a set (`NAME2.ROM` ...) in slots 5, 4, 3 ...; a ROMDISC with
`NTC_ROMDISC=dir/NTCDISC.ROM` (and its `NTCDISC2.ROM` ...) in slots 10, 11 ...; at
`kw_waitkey` (`Option PressAnyKeyOnEnd`, which every program in `bas/` has) a breakpoint types
Return when the typed text is used up, so tests needn't (`NTC_NOENDKEY=1`: not; cpcrun.py,
cpctime.py and ntcrun.py all do it); it follows
`#DFxx` writes on cpc / cpcmin and KL ROM SELECT on cpcfw (its fast ticker stub selects the
main ROM for the event, as KL FAR ICALL does). `genrom.js [platform] [--cap=bytes]
[--out=dir] [--place=section:rom,...]`: `--out` leaves the registry file alone (the forced
splits regress.sh tests). On cpc / cpcmin (cpcrun.py) the
image is at #C000 while the gate array has the upper ROM on and slot 6 is selected; writes
go to the RAM below (the screen).

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
