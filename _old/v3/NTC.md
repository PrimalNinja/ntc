# NTC - Native Threaded Code

(c) 2026 Cyborg Unicorn Pty Ltd - MIT License

This is an overview of where NTC and the tinyz80b compiler stand now, and the plan for the
two run modes and the VB5/VB6 front end.

---

## 1. What NTC is

NTC uses the Z80 stack pointer as the instruction pointer. A program is a thread: a list of
words, each one the address of a keyword (a machine code routine), followed by that
keyword's arguments.

```
main_thread:
        dw kw_ltov, 10, var_x          ; x = 10
        dw kw_printint, var_x          ; PRINT x
        dw kw_stop
```

The rules:

- **SP = instruction pointer.** `ret` jumps to the next keyword (10 T).
- **No call. No push.** A keyword pops its arguments off the thread, left to right (10 T
  each), does its work, and ends with `ret`.
- **No firmware.** I/O goes straight to the hardware.
- **Interrupts off.** An interrupt would push its return address into the thread and
  overwrite it, so `ntc_start` does `di` first.
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
  Break on `bp_name` in a monitor. SP shows the thread position. There is no normal call
  stack to look at.
- **ROMable.** The thread and the keywords are read only. Variables, GOSUB return points
  and scratch live in RAM.

BASIC spends most of its time inside keywords, not in subroutine calls, so the 10 T
dispatch and 10 T argument fetch make a large difference compared with a C style
call/return model.

### Costs

| Operation | NTC cost |
|---|---|
| Dispatch to next keyword (`ret`) | 10 T |
| Fetch one argument (`pop`) | 10 T |
| GOTO (`dw l_go`, stub `ld sp, l / ret`) | 30 T |
| GOSUB, keyword form (`l_gs`) | 50 T |
| RETURN, keyword form (`l_rt`) | 40 T |
| GOSUB + RETURN, stack form (`kw_gosub` / `kw_return`) | 215 T |

---

## 2. The tinyz80b compiler (current)

A BASIC to NTC cross compiler written in ES5 JavaScript. It is built so it can later be
ported to run natively on the Z80, so it has no parse trees, no recursive descent, and no
character-at-a-time reading.

### How it compiles

- Line by line. Each statement is matched by regex in this first cut.
- Expressions go through `IFtoPF` (shunting yard) to postfix, then a postfix walk with a
  value stack. One keyword per operator, results go to `tmpN` (N = stack slot).
- Pass 1 runs twice to settle types (INPUT, numeric use, string compare, assignment), and
  collects labels, DIMs, GOSUB targets, jump sources, RETURN lines and fall-in.
- Pass 2 makes the code.
- IF / WHILE / FOR / DO nesting uses a block stack.
- Constants are folded and literals go inline (`x = 3 + 4 * 2` is one `kw_ltov`).
- Peephole: branch to a GOTO goes straight to its target, a GOTO to the next label is
  removed, dead code after GOTO / STOP / RETURN is removed.
- Only the library sections the program uses get linked, plus their dependencies.

### Flow control

- **GOTO** is one word, `dw l_go`, with a code stub `l_go: ld sp, l / ret`. A thread
  target is data, not code, so `dw l` on its own can't be used as a jump.
- **GOSUB targets become keywords** when safe:

  ```
  l_gs:   ld (l_rs), sp       ; GOSUB: save return point, 50 T
          ld sp, l
          ret
  l_rt:   ld sp, (l_rs)       ; RETURN, 40 T
          ret
  ```

  `l_rs` is the target's return point in RAM. The stubs are code, so they are ROMable.
  A target falls back to the GOSUB stack (`kw_gosub` / `kw_return`) if code can fall into
  it, a GOTO crosses into or out of its lines, it has no RETURN of its own, or it is on a
  call graph cycle. A target's lines run from its label to the next GOSUB target.
- **FOR**: one keyword at FOR, one per pass at NEXT. STEP 1 uses `inc (hl)`
  (`kw_next1l/v`), so the usual loop doesn't pay for the step add. A literal step uses
  `kw_nextupl/v` or `kw_nextdnl/v`, and a variable step uses `kw_forentry` / `kw_fornext`.

### Platform

The Amstrad CPC is the only platform so far (`asm/ntc_plat_cpc.asm`), driven straight on
the hardware:

- **Screen:** at `#C000`, modes 0/1/2 (20/40/80 columns), with scroll, wrap, LOCATE and CLS.
- **Gate array:** `#8C|mode` with the ROMs off, `#84|mode` when exiting.
- **Keyboard:** PPI/PSG matrix scan. Shift, ctrl and caps are masked so they don't count as
  key presses.
- **FRAME:** vsync from PPI port B bit 0.

### Language (BASIC dialect)

- 16 bit signed integers.
- Strings up to 40 characters.
- `DIM a(n)`.
- `+ - * / \ MOD`, signed compares, and bitwise `AND OR XOR NOT`.
- PRINT / INPUT.
- Single line and block IF / ELSEIF / ELSE.
- WHILE / WEND, DO / LOOP, FOR / NEXT and EXIT.
- GOTO / GOSUB / RETURN.
- POKE / DOKE / PEEK / DEEK.
- RND / RANDOMIZE.
- CLS / LOCATE / MODE / FRAME / INKEY.
- CALL and BREAK.

`tinyz80b.txt` has the full syntax and keyword list.

### Status

- Passes on an emulated CPC:
  - the 36-test self test (`bas/ntc_test.bas`)
  - a sieve (168 primes)
  - the guessing game
  - the FOR edge cases
  - GOSUB in both forms
  - all three screen modes
  - keyboard and INKEY
- Not yet tested on a real CPC.
- The keyword library is incomplete. More keywords get added as needed.

### Files

| Path | What it is |
|---|---|
| `ntc.html` | Realtime GUI: BASIC on the left, NTC asm on the right (textEditor.js) |
| `js/ntc_compiler.js` | The compiler. `ntcCompile(source, options)` returns `{ asm, errors, stats }` |
| `js/ntc_lib.js` | The `.asm` files as JS strings (`NTC_LIB_ASM`, `NTC_PLATFORMS`) |
| `js/ntc_gui.js`, `css/ntc_gui.css` | GUI code and style |
| `asm/ntc_lib.asm` | Keyword library, sections marked `;## name deps` |
| `asm/ntc_plat_cpc.asm` | CPC platform layer |
| `bas/ntc_test.bas` | Self-checking test program |
| `tinyz80b.xfrm` | Transformer plugin (compiler + library in one) |
| `tinyz80b.txt` | Syntax and keyword reference |
| `analyser/` | listRenderer / formRenderer / parsers, as the base for the project panel |

The GUI has no project or file list yet. It compiles what's in the editor, and the
examples are built into `ntc_gui.js`.

---

## 3. Two modes: turbo (NTC) and normal (IRQ)

One library, written with mode placeholders. Turbo mode is NTC. Normal mode keeps
interrupts on.

- `Option Turbo` (like `Option Explicit`) builds the whole project in turbo.
- `Turbo On` / `Turbo Off` switch modes at runtime, e.g. to let a user choose whether a
  shell sort runs in turbo. The thread layout is the same in both modes, so the switch is
  cheap: On = `di`, BC -> SP, `ret`. Off = SP -> BC, real stack back, `ei`, next.
- The keywords differ per mode, so the compiler tracks the mode line by line. Code that can
  run in both modes (after a runtime `If ... Turbo On`, or a Sub called from both) is
  generated twice, one copy per mode. Only keywords used in each mode are linked.
- While turbo is on, interrupts are off.

| | NTC mode (fast) | IRQ mode (interrupts on) |
|---|---|---|
| Thread pointer | SP | BC |
| Interrupts | off | on |
| SP | the thread | a normal stack, so interrupt handlers can run |
| Dispatch | `ret`, 10 T | 7 instructions, 38 T |
| Argument fetch | `pop`, 10 T | 34 T |
| Speed | full | slower, mainly in dispatch and argument fetch |

### Why IRQ mode

Some platforms need interrupts left on: interrupt-driven keyboard, timers, music, or
hardware that expects regular servicing. IRQ mode runs the same program there. NTC mode
stays the fast one.

### Is IRQ mode p-code?

No. It is still direct threading. The thread words are the machine code addresses of the
keywords, the same as NTC mode. Nothing decodes byte opcodes or looks things up in a table.
The only change is how the next address is reached: a short fetch through BC instead of
`ret`. Only the dispatcher changes.

### Library placeholders

Keywords get written once using placeholders, and the mode switch expands them:

| Placeholder | NTC mode | IRQ mode |
|---|---|---|
| `@next` | `ret` | `ld a,(bc) / inc bc / ld l,a / ld a,(bc) / inc bc / ld h,a / jp (hl)` |
| `@arg rr` | `pop rr` | `ld a,(bc) / inc bc / ld lo,a / ld a,(bc) / inc bc / ld hi,a` |
| `@jump` (target in HL) | `ld sp,hl` then `ret` | `ld b,h / ld c,l` then `@next` |
| `@savebc` / `@restbc` | nothing | `ld (ntc_bcsave),bc` / `ld bc,(ntc_bcsave)` |

`@savebc` / `@restbc` go around any keyword or shared routine that uses BC for its own work,
such as `ldir` in the string keywords. BC is saved to RAM, not pushed, so keywords follow the
same no-push rule in both modes.

### What else changes in IRQ mode

- **Start:** `ld bc, main_thread`, then `@next`. No `di`.
- **GOTO stub:** `l_go: ld bc, l / @next`.
- **GOSUB keyword form:** `l_gs: ld (l_rs), bc / ld bc, l / @next`, and
  `l_rt: ld bc, (l_rs) / @next`.
- **`kw_gosub` / `kw_return`:** save and restore BC on the GOSUB stack instead of SP.
- **`kw_stop`:** restores the caller's SP and returns, the same as now.
- **BREAK:** `bp_name: @next`. In IRQ mode the thread position is in BC, not SP.
- **`CALL addr` (literal):** the user's code runs as a keyword, so it must end with `@next`.
  Code written for one mode won't run in the other unless it uses the same ending.

### Estimated costs (counted by hand, not measured)

| Operation | NTC | IRQ |
|---|---|---|
| Dispatch | 10 T | 38 T |
| Argument | 10 T | 34 T |
| GOTO | 30 T | ~86 T |
| GOSUB (keyword form) | 50 T | ~106 T |
| RETURN (keyword form) | 40 T | ~96 T |

IRQ mode is not built yet.

---

## 4. VB5 / VB6 front end

### Approach

A new front end written in JS, taking its parsing approach from VBCC instead of regex. The
self-compiling ability is dropped. Only Z80 output is generated, with no target plugins.

What comes from VBCC:

- **Prefix dispatch:** the first token of a line picks the statement handler.
- **StrTok tokenizer:** splits a line into tokens in one pass.
- **Context flags:** global, module, function, object (class), UDT. The same word means
  different things in different contexts.
- **Statement records:** each parsed line becomes a record handed to code generation.
- **Element table:** symbols (variables, constants, routines, types) with scope and type.

It is still line by line, with no tree and no recursive descent. Expressions still go
through `IFtoPF` (shunting yard). VBCC's own infix to postfix method was never right, so it
gets replaced. Code generation goes to the same NTC keywords and library, so both modes work
for VB programs too.

### How VB maps to NTC

| VB | NTC | Compromise |
|---|---|---|
| `Integer` | 16 bit signed, as now | none |
| `Byte` | 8 bit, own keywords | none |
| `Boolean` | -1 / 0, as now | none |
| `Long` | 32 bit, own keyword set | later |
| `Single` / `Double` / `Currency` | not in the first cut | no floating point at first |
| `String` | fixed maximum length, temporary string slots for expressions | not dynamic like VB, so length is capped |
| `Variant`, late binding | not supported | VB code using them must declare types |
| `Const` | folded at compile time | none |
| `Sub` / `Function` | become keywords, called the same way as GOSUB keyword targets | no recursion (see below) |
| Parameters | popped from the thread into fixed parameter slots for that routine | static slots, not a stack frame |
| `ByRef` / `ByVal` | ByRef passes the address, ByVal passes the value | none |
| Function result | a fixed result slot per function | none |
| Locals | fixed slots, zeroed on entry (VB starts locals at 0 / "") | not reentrant |
| `Static` locals | fixed slots, not zeroed | none |
| `Exit Sub` / `Exit Function` | jump to the routine's return stub | none |
| `Select Case` | compare-and-branch chain | none |
| `If` / `ElseIf`, `While` / `Wend`, `Do` / `Loop`, `For` / `Next` | as now | none |
| `GoTo` / `GoSub` / labels / line numbers | as now | none |
| `Dim a(n)` | as now, base 0 | multi-dimension and `ReDim` later |
| `Type ... End Type` (UDT) | fixed layout, field offsets worked out at compile time | later |
| `#Const` / `#If` (VBCC `#define` / `#if`) | compile time only | none |
| Modules (`.bas`) | one program, public symbols shared through the element table | none |
| Classes (`.cls`) | syntactic sugar: a named group of variables and routines, resolved at compile time to prefixed names (`cFoo_Method`) | no runtime instance machinery for now |
| `Print` / `Debug.Print` | ZOSCII output, as PRINT now | none |
| Forms, events, `WithEvents` | not supported | forms planned as a separate structured form creator application |
| `On Error` | not in the first cut | — |

**Recursion:** VB allows it, NTC routines don't. Each routine has one return slot and one
set of parameter and local slots. The call graph is checked. A routine that can call itself,
directly or through others, is reported as an error, or falls back to a stack form, the same
as GOSUB does now.

### Build order

1. Modules, `Sub` / `Function` as keywords with parameters, locals zeroed on entry, `Const`,
   `Byte` / `Integer` / `Boolean`, `Exit`, `Select Case`.
2. String built-ins with temporary string slots (`Left$`, `Mid$`, `Right$`, `Chr$`, `Asc`,
   `Str$`, `Val`, `InStr` ...).
3. UDTs and `Long`.
4. Classes.

### Project panel

The `analyser/` files are the base for the IDE's project side:

- listRenderer for the list of project files (modules, classes), with drag-drop and remove.
- `parseVB6` for each file's routines (name, kind, access, arguments, line range), to give
  a module → Sub / Function tree.
- formRenderer for a later form designer.
- Bundle save / load (JSON) as the project file until there is a proper one.

None of this is wired into `ntc.html` yet.

---

## 5. Open decisions

- Classes: one instance only, or a copy of the variables per `Dim x As New cFoo`.
- FUTURE: `Option ClassSize <kilobytes>` to keep classes within a size for banking.

Progress is tracked in `todo.md`.
