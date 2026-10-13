# Locomotive BASIC flavour - plan

**Status (2026-10-13): step 1 built** - `js/ntc_flavour_loco.js` (the `locomotive` entry in the
flavour factory), `.loc` files and "+ Locomotive" in the GUI, an example (bas/loco_demo),
regression tests (test/loc). Defaults taken for the open decisions: marked by the first line or
a `.loc` name; plain variables Integer (`'#long` for more); print zones as `Option VBPrint`
(14); a plain `RND` a warning; every platform (text programs work on cpm and test too). In the
VB text only line numbers something jumps to are kept; GOSUB stays GOSUB (a Locomotive
"subroutine" is a line, not a block: code falls into it, it can GOTO out, share a tail, or
GOSUB itself - NTC's GOSUB does all of that natively). Graphics (step 2) waits for the plans for
a graphics library.

The Amstrad CPC's own BASIC (Locomotive BASIC 1.1, CPC 664 / 6128) as an NTC flavour: a
flavour preprocessor, like the JS one - Locomotive text in, VB5 text out, line for line, then
NTC's one parser and compiler. The aim is that a CPC owner feels at home and that simple
listings from books and magazines compile with few or no changes. It is not a recreation of
the interpreter: no floating point, no editor commands, and anything that does not map onto
NTC becomes a warning (the line is left out, the compiler lists it).

## The ground rules

- **Per module.** A file says `'# Option Flavour Locomotive` (or `REM #Option Flavour
  Locomotive`) on its first line, or `options.flavour` is `locomotive`, or its name ends in
  `.loc` (decision 1). It mixes with VB5 and JS files in one project.
- **One program per file**, top level code, as typed in: line numbers, `:` between statements.
  Line numbers are optional (an NTC extension), so a listing can be tidied without them.
- **Whole numbers only.** A plain variable (`a`) is a real number in Locomotive BASIC; here it
  is an Integer (decision 2). `a%` is an Integer, `a$` a String; a line with `a!` (real),
  `SIN`, `COS`, `LOG` ... or a number with a decimal point becomes a warning.
- **Type hints, as in the JS flavour:** `'#type` at the end of a line - a Locomotive comment, so
  the listing still runs on a real CPC:
  ```
  10 DIM x '#long
  20 DIM tbl(100) '#byte
  30 total = 0 '#long
  ```
  `'#long`, `'#byte`, `'#bool`, `'#string`, `'#string*20`, `'#stringmax 80`. On a `DIM` it types
  the names in it; on any other line, the variable assigned there (from its first use on).
  Without a hint: `%` Integer, `$` String, a plain name Integer.
- **`a`, `a%` and `a$` are three variables** in Locomotive BASIC. VB has one name per variable,
  so the preprocessor renames: `a` -> `a`, `a%` -> `a_i`, `a$` -> `a_s` (only when the same
  name is used with more than one suffix; otherwise the name stays and gets its type).
- **`DEFINT` / `DEFSTR` / `DEFREAL`** are warnings: types come from the suffix (`%`, `$`) or
  the default (Integer).
- **Arrays** used without `DIM` get `DIM name(10)`, as Locomotive BASIC does.
- **Printing as on the CPC:** `Option VBPrint` is on for a Locomotive file - a number gets a
  space before it (if 0 or more) and one after; `,` moves to the next print zone (decision 3).
  `ZONE n` is a warning.
- **Graphics coordinates as on the CPC:** 640 x 400, (0, 0) at the bottom left, whatever the
  mode; the preprocessor scales to NTC's Graphics class (pixels from the top left).
- **The platforms:** cpc, cpcmin and cpcfw (the CPC's own BASIC belongs there); cpm and test
  only for what has no CPC hardware in it.
- **Unsupported = a warning, not a stop.** Locomotive BASIC is a small language, so the
  preprocessor keeps going: a line using a keyword or function NTC doesn't have (`a = 3 *
  COS(x)`, `INK 1, 24`) becomes a comment in the VB5 text, keeping its line number so GOTOs to
  it still land - `100 ' WARNING: unsupported COS: a = 3 * COS(x)` - and the compiler lists it
  with its line among its warnings. The program compiles and runs without that line; the
  warnings say which lines to look at. (Not for the JS flavour: that one is a designed subset,
  and anything outside it is an error.)
- **Later as classes.** Most of what is missing now (colours, keys, sound, timers, files) will
  come as classes; once one is a core class (like List and Memory), its keywords map onto it
  and stop being warnings.
- **NTC extensions allowed:** `Option ...`, `Turbo On` / `Off`, `#asm` ... `#endasm`, `#If` and
  the VB form of calling a class (`Graphics.DoubleBuffer 1`) work in a Locomotive file.

## Locomotive BASIC and what it becomes

Built = NTC has it now; Helper = the preprocessor writes a few VB lines or a small Sub;
Warning = the line becomes a comment and the compiler lists it (later: mostly through a class).

### Program and flow

| Locomotive | Becomes | Status |
|---|---|---|
| `10 PRINT "HI"` (line numbers) | numbered lines | Built |
| `:` between statements | `:` | Built |
| `REM`, `'` | `'` | Built |
| `GOTO n`, `GOSUB n`, `RETURN` | the same | Built |
| `ON x GOTO a, b, c`, `ON x GOSUB ...` | `On x GoTo ...` | Built |
| `IF c THEN s [ELSE s]` (one line) | single line `If` | Built |
| `IF c THEN 100 ELSE 200` | `If c Then GoTo 100 Else GoTo 200` | Helper |
| `FOR i = a TO b [STEP s] ... NEXT [i]` | the same (`NEXT i, j` -> two `Next`) | Built |
| `WHILE c ... WEND` | the same | Built |
| `END`, `STOP` | `End`, `Stop` | Built |
| `DEF FN name(x) = expr`, `FN name(x)` | a Function `fn_name` at the end of the module | Helper |
| `DATA`, `READ`, `RESTORE [n]` | a hidden table of the DATA items and a read position; `RESTORE n` -> the first item at or after line n | Helper |
| `ON ERROR GOTO`, `RESUME`, `ERR`, `ERL`, `ERROR n` | `ERROR n` -> `Error n` (stops); the rest | Warning (no error trapping) |
| `ON BREAK ...`, `CONT`, `TRON` / `TROFF` | | Warning |
| `CHAIN`, `CHAIN MERGE`, `MERGE`, `RUN "file"` | | Warning (later: pages) |
| `CLEAR`, `MEMORY`, `HIMEM`, `FRE` | | Warning (`Option Reserve` and the Memory class do these jobs) |
| `AUTO`, `LIST`, `RENUM`, `DELETE`, `EDIT`, `NEW`, `LOAD` (a program), `SAVE` (a program) | editor commands | Warning |

### Variables and arithmetic

| Locomotive | Becomes | Status |
|---|---|---|
| `a`, `a%`, `a$` | Integer, Integer, String (renamed when they clash) | Helper |
| `a!`, `DEFREAL` | | Warning (no real numbers) |
| `DEFINT a-z`, `DEFSTR s` | | Warning (types from `%` / `$`, else Integer) |
| `DIM a(10)`, `DIM b$(5, 5)`, `ERASE a` | the same | Built |
| `LET a = 1` | `a = 1` | Built |
| `SWAP a, b` | three lines through a temporary of the same type | Helper |
| `+ - * \ MOD ^`, `/` | the same; `/` divides whole numbers | Built |
| `AND OR XOR NOT`, `= <> < <= > >=` | the same | Built |
| `ABS SGN SQR INT FIX CINT UNT ROUND` | `Abs Sgn Sqr Int Fix CInt`; `UNT(x)` -> `x And &HFFFF`; `ROUND(x)` -> `x` | Built / Helper |
| `MAX(a, b, ...)`, `MIN(...)` | nested `IIf` | Helper |
| `RND`, `RANDOMIZE [n]` | `INT(RND * n)` -> `Rnd(n)`; `RANDOMIZE` -> `Randomize`; a plain `RND` (a fraction) -> Warning | Helper |
| `SIN COS TAN ATN EXP LOG LOG10 PI DEG RAD CREAL` | | Warning (no real numbers) |
| `&FF`, `&HFF`, `&X1010` | the same (NTC reads the CPC forms already) | Built |

### Text

| Locomotive | Becomes | Status |
|---|---|---|
| `LEFT$ RIGHT$ MID$ LEN INSTR CHR$ ASC VAL STR$ HEX$ SPACE$ STRING$` | the same | Built |
| `UPPER$`, `LOWER$` | `UCase$`, `LCase$` | Built |
| `MID$(a$, i, n) = b$` | the `Mid$` statement (NTC has it: `Mid$` on the left, which few BASICs allow) | Built |
| `BIN$(n [, d])` | a small Function | Helper |
| `DEC$(n, "##.##")`, `PRINT USING` | | Warning |
| `COPYCHR$(#0)` | | Warning |

### Screen and keyboard

| Locomotive | Becomes | Status |
|---|---|---|
| `PRINT a; b, c` (with `Option VBPrint`), `?` | `Print` | Built |
| `PRINT TAB(n)`, `SPC(n)` | the same | Built |
| `ZONE n` | | Warning |
| `INPUT ["prompt";] a`, `LINE INPUT a$` | `Input` | Built |
| `INKEY$` | `Inkey$` | Built |
| `INKEY(n)` (is key n held down) | `(-1 - Keys.Down(n))` | Built: 0 held, -1 not (the values with Shift / Control, 32 and 128 ..., aren't given) |
| `JOY(0)`, `JOY(1)` | `Keys.Joystick(n)` | Built (the same bits) |
| `CLS`, `MODE n`, `LOCATE x, y` | the same | Built |
| `PEN n`, `PAPER n`, `INK n, c [, c2]`, `BORDER c [, c2]` | | Warning (later: a Screen class) |
| `POS(#0)`, `VPOS(#0)` | `POS` -> `StdIO.Column`; `VPOS` | Built / Warning |
| `WINDOW`, `WINDOW SWAP`, `#1` ... `#7` streams | | Warning |
| `SYMBOL n, ...`, `SYMBOL AFTER n` | | Warning (later: the Screen class) |
| `SPEED KEY / INK / WRITE`, `KEY`, `KEY DEF`, `CURSOR` | | Warning |
| `FRAME` | `Frame` | Built |

### Graphics

NTC's Graphics class today (cpc, cpcmin, cpcfw) was shaped by the cube demo: XOR lines and
points in a pen, clipping, double buffering. Locomotive's graphics draw by overwriting (XOR
only as an ink mode), and clear and read pixels, so Step 2 grows the class first - as a core
class every flavour gets.

| Locomotive | Becomes | Status |
|---|---|---|
| `PLOT x, y [, pen [, mode]]`, `PLOTR` | `Graphics.Plot` (scaled; R = relative to the graphics cursor) | Helper + Graphics: a draw mode (set / XOR / AND / OR - Locomotive's ink modes; set is the default) |
| `DRAW x, y [, pen [, mode]]`, `DRAWR` | `Graphics.Line` from the graphics cursor | Helper + the draw mode |
| `MOVE x, y`, `MOVER` | the graphics cursor (two hidden variables) | Helper |
| `ORIGIN x, y` | an offset added to every point | Helper |
| `GRAPHICS PEN n` | `Graphics.Pen n` | Built |
| `XPOS`, `YPOS` | the hidden cursor variables | Helper |
| `CLG [pen]` | `Graphics.Clear [pen]` | Graphics: Clear |
| `TEST(x, y)`, `TESTR` | `Graphics.Point(x, y)` | Graphics: Point |
| `GRAPHICS PAPER n` | `Graphics.Paper n` (what Clear fills with) | Graphics: Paper |
| `FILL n`, `MASK`, `TAG` / `TAGOFF` | | Warning (later: Graphics) |

### Machine, files, timers, sound

| Locomotive | Becomes | Status |
|---|---|---|
| `PEEK`, `POKE`, `INP`, `OUT` | the same | Built |
| `CALL addr` | `Call addr` | Built |
| `CALL addr, a, b` | | Warning |
| `WAIT port, mask [, inv]` | a loop on `Inp` | Helper |
| `TIME` | `Ticks` (both 1/300 s) | Built |
| `\|DISC`, `\|TAPE`, `\|A`, `\|B`, `\|DIR` ... | `FileSystem.SelectDevice` / `SelectVolume` / `System.Command` | Built (devices, volumes) / Helper |
| `\|name, args` (any RSX) | | Warning |
| `LOAD "f", addr`, `SAVE "f", b, addr, len` | `FileSystem.Load` / `Save` | Built |
| `OPENIN`, `OPENOUT`, `CLOSEIN`, `CLOSEOUT`, `EOF` | `loco_fi = FileSystem.Open(f, 1)`, `loco_fo = FileSystem.Open(f, 2)`, `FileSystem.Close`, `FileSystem.Eof(loco_fi)` | Built (cpcfw, cpcmin; CP/M too). NTC's CPC FileSystem has one file open at a time, so a file read and one written at once (OPENIN and OPENOUT together) doesn't work |
| `PRINT #9, items` | `FileSystem.WriteLine(loco_fo, ...)` | Built: the items joined into one line, numbers as PRINT shows them (`Str$(n) & " "`), no zones for `,`; a PRINT #9 ending with `;` or `,` is a warning (each one writes a whole line) |
| `INPUT #9, v`, `LINE INPUT #9, a$` | `v = Val(FileSystem.ReadLine(loco_fi))`, `a$ = FileSystem.ReadLine(loco_fi)` | Built: one line of the file for each variable (INPUT #9 doesn't split a line at commas) |
| `WRITE #9` | | Warning |
| `CAT` | | Warning |
| `EVERY t [, n] GOSUB l`, `AFTER t [, n] GOSUB l`, `REMAIN(n)`, `DI`, `EI` | | Warning (later: timers through NTC's interrupt hook) |
| `SOUND`, `ENV`, `ENT`, `SQ`, `RELEASE`, `ON SQ GOSUB` | | Warning (later: a Sound class) |
| `PRINT #8` (printer), `WIDTH` | | Warning |

## Plan

**Step 1 - the core** (about 600 lines, no NTC changes)
- The `locomotive` entry in the flavour factory (`js/ntc_flavour_loco.js`): line numbers, `:`,
  `REM` / `'`, the line for line output.
- Variables: the suffix renaming, `'#type` hints, the declarations at the top (each mapped to
  the line it was first used on), arrays without `DIM`.
- Flow: `IF` / `THEN` / `ELSE` (with line numbers after THEN / ELSE), `FOR` / `NEXT i, j`,
  `WHILE` / `WEND`, `GOTO` / `GOSUB` / `ON`, `END` / `STOP`.
- `DATA` / `READ` / `RESTORE` (a hidden table), `DEF FN`, `SWAP`, `MAX` / `MIN`, `BIN$`, `WAIT`,
  `INT(RND * n)`.
- The text and maths functions under their CPC names; `PRINT` with `Option VBPrint`, `INPUT`,
  `LINE INPUT`, `INKEY$`, `CLS`, `MODE`, `LOCATE`, `PEEK` / `POKE` / `CALL` / `INP` / `OUT`, `TIME`,
  `LOAD` / `SAVE` (binary), `|DISC` / `|TAPE` / `|A` / `|B`.
- Unsupported lines: kept as `' WARNING: unsupported X: ...` comments (line number kept), and a
  compiler warning per line (`ntcPrep` passes the flavour's warnings on; the result's
  `warnings` list names the module and line).
- Tests: classic listings (a guess-the-number, a times table, a sort with DATA, a menu with
  ON GOSUB, a DEF FN maths quiz) on cpc, cpcmin and cpcfw, both modes, against references;
  translation checks (Locomotive in, VB5 out).

**Step 2 - graphics** (the Graphics class grows, then about 150 lines in the flavour)
- Graphics (a core class, for VB and JS too): a draw mode - set (the default for new code),
  XOR (what Vector3D uses), AND, OR; `Clear [pen]`, `Paper`, `Point(x, y)`. The cube demo keeps
  working (it asks for XOR).
- The flavour: `PLOT` / `DRAW` / `MOVE` and the `R` forms with pen and mode, `ORIGIN`,
  `GRAPHICS PEN` / `PAPER`, `CLG`, `TEST`, `XPOS` / `YPOS`, the 640 x 400 scaling.
- Tests: a box, a star, a filled-by-lines shape, `TEST` reading back what was drawn, on cpc,
  cpcmin and cpcfw.

**Step 3 - later, as classes** (each useful for VB and JS too; when one becomes a core class,
its Locomotive keywords map onto it and stop being warnings)
- A Screen class (`PEN`, `PAPER`, `INK`, `BORDER`, `SYMBOL`), Graphics `Clear` / `Point`
  (`CLG`, `TEST`), timers (`EVERY`, `AFTER`), a Sound class (`SOUND`, `ENV`, `ENT`).
- Done: the Keys class (`INKEY(n)`, `JOY`) and FileSystem's one open file on the CPC
  (`OPENIN` / `OPENOUT`, `PRINT #9`, `LINE INPUT #9`, `EOF`) - see the table above; tested by
  `test/loc/files.loc` on cpcfw and cpcmin.

**Step 4 - docs and examples**
- A user guide section (this table, cut to what is built), a tutorial page, Locomotive examples
  in the GUI's Example list (a type-in listing from a CPC magazine style, a graphics demo).

## Decisions before starting

1. **How a file is marked:** the first line only (`'# Option Flavour Locomotive`), or also a
   file name ending (`.loc`? `.lbas`?) - a CPC listing saved as ASCII is usually `.BAS`, which
   NTC already reads as VB5.
2. **Plain variables:** Integer (16 bit, fast - the usual NTC choice, `'#long` where a real
   number held something bigger), or Long by default?
3. **Print zones:** Locomotive's 13 columns (as the CPC), or NTC's `Option VBPrint` 14?
4. **`RND`:** a plain `RND` (a fraction) as a warning, or give it a meaning (a whole number 0-32767)?
5. **cpm / test platforms:** allow a Locomotive file there at all (text programs only), or
   CPC platforms only?
