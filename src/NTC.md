# NTC - Native Threaded Code

(c) 2026 Cyborg Unicorn Pty Ltd - MIT License

What NTC is, how the tinyz80b compiler works now (VB5/VB6 style front end, turbo and
normal modes, project explorer), and the language it takes. Progress is tracked in
`todo.md`.

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
- **No firmware.** I/O goes straight to the hardware.
- **Shared routines** are entered with `jp` and the return address in IX, and end with
  `jp (ix)`. `ntc_next` is a plain `ret`, so `ld ix, ntc_next` continues the thread.
- **The thread stays word aligned.** Text is ZOSCII: each character is a word pointing at
  an 8 byte glyph bitmap, never a byte string.

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

## 3. The compiler

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
| `asm/ntc_plat_cpc.asm` | CPC platform layer (screen, keys, frame, interrupt handler, exit) |
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
  `vb_test_long.bas` (58 checks), `vb_test4.bas` (16 checks: array parameters), `ntc_test.bas` (36 checks), the class project, sieve,
  shell sort (both choices), the FOR / GOSUB / screen tests.
- Not yet tested on a real CPC.

---

## 4. Language

VB5 / VB6 style. Differences from VB are listed after each part.

### Types and declarations

- `Integer` (16 bit signed), `Long` (32 bit signed), `Byte` and `Boolean` (stored as 16
  bit, True = -1), `String` (40 chars).
- `Enum ... End Enum` (members are constants, also `EnumName.Member`).
- `Dim` / `Private` / `Public` / `Global` / `Static`, `Const`, `Type ... End Type`.
- Suffixes: `a$` String, `a%` Integer, `a&` Long; `1000&` / `&HFFFF&` are Long literals. Undeclared names are allowed (their type comes from
  how they are used) unless `Option Explicit`.
- Arrays: `Dim a(10)`, `Dim b(1 To 5)`, `Dim g(3, 4)`, `Dim s(10) As String`,
  `Dim pts(5) As Point` (then `pts(i).x`). `Option Base 0 | 1`.
- `#Const`, `#If ... Then / #ElseIf / #Else / #End If`.

Long: a separate keyword set (`kw_l_*`), every argument an address, 4 bytes low byte first.
An expression is Long when a Long variable, function, array or a literal over 65535 is in
it; Integer sides are widened. A Long put into an Integer keeps the low 16 bits (VB would
stop with Overflow). Integer * Integer stays 16 bit as in VB - use `CLng(a) * b` or
`a * 1000&` for a Long result. A `For` with a Long counter needs a constant `Step`.

Not supported: `Single`, `Double`, `Currency`, `Variant` values, dynamic arrays /
`ReDim`, `Declare`.

### Procedures

- `Sub`, `Function`, `Property Get / Let / Set`, `Public / Private / Friend`, `Static`.
- Parameters: `ByVal`, `ByRef` (default), `Optional` with a default.
- `Exit Sub`, `Exit Function`, `Exit Property`. `Call Name(args)` or `Name args`.
- `Sub Main` runs after any top level code. Top level code (outside procedures) in a module
  is the main program, as in classic BASIC.

- Arrays as parameters: `Sub SortUp(a() As Integer)` (Integer, Long, String; always ByRef).
  The call passes the address of a descriptor (base, lower bound, element size, count); the
  call stub copies it, and `a(i)` goes through it (`kw_pget` / `kw_pset`). An array
  parameter can be passed on. `LBound(a)` / `UBound(a)` work on it (on a normal array they
  are worked out by the compiler, `UBound(g, 2)` too).

Not supported: recursion, `ParamArray`, 2 dimension arrays or arrays of a Type as
parameters, Types as parameters.

### Flow

`If / ElseIf / Else / End If` (block or one line), `Select Case` (values, `a To b`,
`Is > x`, strings, `Case Else`), `While / Wend`, `Do [While|Until] / Loop [While|Until]`,
`For / To / Step / Next`, `Exit For | Do | While`, `GoTo`, `GoSub / Return`, `End`, `Stop`,
labels and line numbers.

`On x GoTo a, b, c` / `On x GoSub a, b, c`, `With ... End With`.

Not supported: `On Error`, `For Each`.

### Operators

`-` (unary), `* / \ Mod`, `+ -`, `&`, `= <> < <= > >=`, `Not`, `And`, `Or Xor`.
`/` is integer division (no floating point). `And Or Xor Not` are bitwise (True = -1, so
they work as logical too). Strings compare with all six compares.

### Functions

- Strings: `Len Left$ Right$ Mid$ Chr$ Asc Str$ CStr Val InStr UCase$ LCase$ Trim$ LTrim$
  RTrim$ Space$ Spc String$ Hex$` (with or without `$`).
- Arrays: `LBound(a [, dim])`, `UBound(a [, dim])`.
- Numbers: `Abs Sgn Int Fix CInt CLng CBool CByte`, `Rnd(n)` = 0 .. n-1, `Peek Deek`,
  `Inkey` (key code or 0), `Inkey$` (key as text or ""), `Ticks` (interrupt count, normal
  mode). `Val` / `CLng` of text into a Long reads 32 bit decimal.

### Statements (NTC / CPC)

`Print a; b, c` (also `?` and `Debug.Print`), `Input ["prompt";] v`, `Cls`, `Locate x, y`,
`Mode n`, `Frame`, `Poke a, v`, `Doke a, v`, `Randomize [n]`, `Call address` (machine code
run as a keyword: SP is the thread, end with `ret` in turbo, `jp ntc_xn` in normal),
`Break [name]`, `Turbo On`, `Turbo Off`, `Option Turbo`.

`Tab(n)` and `Spc(n)` in Print.

Differences: `Print` does not add spaces around numbers, `,` prints one space.

---

## 5. Test tools (`test/`)

Scratch tools for testing the compiler. They are not part of the compiler or the GUI, which
need nothing but a browser. All paths are relative to the `test/` folder, so it works
wherever the project is.

### What to install

- **node** - for `cli.js` and `gen.js`. Run `npm install` in `test/` once (acorn, for the ES5
  check in `regress.sh`).
- **python3** with the `z80` module (`pip install z80`) - the Z80 core used by `cpcrun.py`.
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
node cli.js main.bas --nocomments            no BASIC source lines as comments
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
(raw binary at #4000), then runs it:

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

### regress.sh - the regression run

```
bash regress.sh
SJASMPLUS=/path/to/sjasmplus bash regress.sh
```

Runs every test program in both modes (turbo and normal) and checks the result line:
`vb_test` (64 checks), `ntc_test` (36), `vb_test2` (30, 2 files), `vb_test3` (11),
`vb_test_long` (58), `vb_test4` (16), the class project, sieve, shell sort (both answers),
the guide, and the FOR / GOSUB / screen tests (`for.bas gs.bas gs2.bas scr0.bas scr2.bas`)
compared with the expected output in `ref/`. Then checks every JS file parses as ES5. Ends
with `ALL PASS` or `SOME FAILED` (with the last lines of each failure). Work files go in
`test/t/`.

To add a test: put the program in `bas/`, then add a `cp ... ; o=$(...); check "name" "pattern" "$o"`
line in `regress.sh` with a pattern from its last output line.

### gen.js - rebuild the generated JS

```
node gen.js
```

Run it after changing `asm/ntc_lib.asm`, `asm/ntc_plat_cpc.asm` or anything in `bas/`. It
writes `js/ntc_lib.js` (the library text the compiler links from) and `js/ntc_examples.js`
(the Example list in the GUI, from the list at the top of `gen.js` - add new examples
there).

### guitest*.py - GUI tests (Playwright, headless Chromium)

```
python3 guitest5.py
```

- `guitest5.py` - opens `ntc.html`, compiles every example, prints errors / stats / compile
  time per example and any browser console errors (should be none)
- `guitest4.py` - opens the test project in `vbp/` (a .vbp with Main.bas, Counter.cls, a
  form and a missing file) and the Long example
- `guitest.py` .. `guitest3.py` - earlier checks: file list, procedure list click to jump,
  2 file example. Some save a screenshot (`gui*.png`) in `test/`

### Usual cycle

1. change `asm/` or `bas/` -> `node gen.js`
2. try one program: `cp ../bas/prog.bas t/ && python3 cpcrun.py t/prog.bas`
3. before handing over: `bash regress.sh` (ALL PASS) and `python3 guitest5.py` (no errors)

---

## 6. Open decisions

- Classes: keep one set of members per class (now), or a copy per `Dim x As New`.
- `Option ClassSize <kilobytes>` for banking (planned, not enforced).