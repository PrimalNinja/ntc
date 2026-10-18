# JS flavour - plan

**Status (2026-10-13): first version built** - `ntcPrep` and the flavour factory
(`ntc_compiler.js`), the JS flavour (`js/ntc_flavour_js.js`), `.js` files in the GUI, an example
(bas/js_demo), regression tests (test/jsf). What is in it: user guide, Option Flavour. Not yet:
the ES5 class form, `'#` hints in VB, `Dim n = 0` start values, `+` joining a number and text in
the compiler, the GUI's view of the VB text, the four decisions below.

A JS syntax over NTC, the way JSCC does it: NTC does not compile JavaScript, it reads a
JS-shaped source and builds exactly what the VB5 flavour builds. Familiar, close enough to
move code between them, not a JS engine. ES5 and ES6 forms both accepted.

## The ground rules

- **Per module.** `Option Flavour JS` (in a JS file: `//# Option Flavour JS`) on a module's or class's first line (`Option Flavour
  VB5` is the default and need not be written). Modules of both flavours mix freely in one
  project.
- **A flavour preprocessor: JS -> VB5 text -> the one parser.** A JS module is translated to VB5 source, line for line,
  and that text goes through the existing parser and compiler. There is one parser and one
  compiler to debug: once they work for VB, they work for JS. The JS side only rewrites
  syntax. The translated VB can be shown next to the JS (GUI), which also shows whether a fault
  is in the translation or the compiler.
- **Names ignore case** when compiling, as in VB. `Total` and `total` are the same name.
- **Types.** A variable's type comes from its start value or use, the same rule NTC already
  has for undeclared variables: text -> String, anything else -> Integer. Outside that, a
  type hint at the end of the line: `//#long`, `//#byte`, `//#bool`, `//#string`,
  `//#string*20`, `//#stringmax 80`. The VB flavour gets the same with `'#`:
  ```
  let n = 0;      //#long
  var b = 0;      //#byte
  Dim n = 0       '#long
  ```
  A hint is a JS comment, so the source stays valid JS.
- **One object per class** (as NTC classes are now): no prototype, no inheritance, no
  constructor. `new X()` is a second name for the class's one set of members. Setup is an
  ordinary public method the program calls.
- **Not everything NTC has.** Only the JS forms listed; VB-only statements stay VB-only.
- **Integers.** `/` divides whole numbers (as VB `\`). No floating point anywhere.
- **NTC's own lines stay valid JS.** Inline assembly is a block comment, so a browser skips it:
  ```
  /* #asm
              ld hl, ({total})
              inc hl
              ld ({total}), hl
  */
  ```
  The preprocessor turns `/* #asm` into `#asm` and the closing `*/` into `#endasm`, line for
  line; `{name}` works as in VB. A function whose whole body is such a block is an asm keyword
  procedure, as in VB. Other NTC lines (`Option ...`, `Turbo On` / `Off`, `#If` / `#Const`) are
  a `//#` comment on a line of their own: `//# Option Page Level1 = Title`, `//# Turbo On`. A
  `//#` after code on the same line is a type hint (`let n = 0; //#long`).
- **A JS-flavour file stays valid JS - always.** Everything NTC adds is a comment (`//#`,
  `/* #asm */`), so the same file can also run in a browser. Not a goal now, but the door
  stays open: later, browser versions of the library classes and run time checks of an `NTC`
  flag (`if (NTC) ...`, as `#If NTC`) would let one source run both ways. Nothing in the JS
  flavour may break this rule.

## VB5 (what NTC supports) and the JS flavour

### Program structure

| VB5 | JS flavour | Notes |
|---|---|---|
| module (`.bas`) | a `.js` file with functions and variables at the top | module = the file |
| class module (`.cls`) | a `.js` file holding one `class X { }` (ES6) or `function X() { }` (ES5) | the class's name = its module |
| top level code | statements at the top of the file | |
| `Sub Main` | `function main()` | runs after the top level code, as in VB |
| `Rem`, `'` | `//`, `/* */` | |
| `:` (several statements) | `;` | |
| line numbers, labels | - | VB only |

### Variables and constants

| VB5 | JS flavour | Notes |
|---|---|---|
| `Dim n As Integer` | `let n = 0;` / `var n = 0;` | Integer by default |
| `Dim n As Long` | `let n = 0; //#long` | |
| `Dim b As Byte` | `let b = 0; //#byte` | |
| `Dim f As Boolean` | `let f = false;` | true / false = -1 / 0, as VB |
| `Dim s As String` | `let s = "";` | |
| `String * n`, `String Max n` | `let s = ""; //#string*20`, `//#stringmax 80` | |
| `Const MAX = 10` | `const MAX = 10;` | |
| `Private` (module level) | `let` / `var` / `const` / `function` at the top of a module | |
| `Public`, `Global` | `export let ...`, `export function ...` | ES6 export = Public |
| `Static` (in a procedure) | - | leave out (a module level `let` does the job) |
| `Option Explicit` | `"use strict";` or `Option Explicit` | every name declared before use |
| undeclared variables | allowed unless `"use strict"` | the same typing rule |
| `Let`, `Set` | plain `=` | |
| `Enum ... End Enum` | `const Color = { Red: 0, Green: 1 };` (an Enum, not an object) | members as `Color.Red` |
| `Type ... End Type` | - | first version: VB only (an object literal shape could come later) |
| `True`, `False` | `true`, `false` | |
| `&H1F`, `&O17`, `&X101` | `0x1F`, `0o17`, `0b101` | |

### Arrays

| VB5 | JS flavour | Notes |
|---|---|---|
| `Dim a(9) As Integer` | `let a = new Array(10);` | 10 elements, 0-9 |
| `Dim a(9) As Long` | `let a = new Array(10); //#long` | |
| `Dim a(2, 3)` | `let a = new Array(3, 4);` | NTC's two dimensions (not JS meaning, documented) |
| `a(i)`, `a(i, j)` | `a[i]`, `a[i][j]` or `a[i, j]` | |
| `Dim a() ... ReDim a(n)` | `let a = [];` then `a.length = n + 1;` | dynamic arrays |
| `ReDim Preserve` | `a.length = n;` keeps the contents | |
| `Erase a` | `a.fill(0);` | |
| `LBound(a)`, `UBound(a)` | `0`, `a.length - 1` | |
| array parameters | the same | |
| `For Each x In a` | - | left out (`for (i...)` instead) |
| `Option Base` | - | always 0 |
| `Split`, `Join` | `s.split(",")`, `a.join(",")` | |

### Calculations

| VB5 | JS flavour | Notes |
|---|---|---|
| `+ - *` | `+ - *` | `+` with a string on either side joins |
| `/`, `\` | `/` | whole numbers |
| `Mod` | `%` | |
| `^` | `**`, `Math.pow(a, b)` | |
| `Abs`, `Sgn`, `Sqr` | `Math.abs`, `Math.sign`, `Math.sqrt` | |
| `Int`, `Fix` | `Math.floor`, `Math.trunc` | (no-ops on integers, accepted) |
| `Rnd`, `Randomize` | `Math.random()` -> `Rnd`, `Math.seed(n)` | NTC's Rnd range, documented |
| `CInt`, `CLng`, `CByte`, `CBool` | `parseInt(x)` / `Number(x)` -> CInt, `//#long` on the target, `Boolean(x)` | |
| `+=` style | `+= -= *= /= %=`, `++`, `--` | |
| `And`, `Or`, `Xor`, `Not` (bits) | `& | ^ ~` | |
| `And`, `Or`, `Not` (logic) | `&& || !` | **no short cut**: both sides are worked out, as in VB (documented) |
| - | `<< >>` | `x << n` -> `x * 2^n`, `x >> n` -> `x \ 2^n` (constant n) |

### Comparison and choice

| VB5 | JS flavour | Notes |
|---|---|---|
| `= <> < <= > >=` | `== === != !== < <= > >=` | `==` and `===` the same |
| `Like` | - | VB only |
| `Option Compare Text` | the same line | |
| `IIf(c, a, b)` | `c ? a : b` | |
| `Choose(i, a, b, c)` | - | VB only (`switch` or an array) |
| `StrComp` | `a.localeCompare(b)` | |

### Strings

| VB5 | JS flavour |
|---|---|
| `&` | `+` |
| `Len(s)` | `s.length` |
| `Left$(s, n)` | `s.substring(0, n)`, `s.slice(0, n)` |
| `Right$(s, n)` | `s.slice(-n)` |
| `Mid$(s, i, n)` | `s.substr(i, n)` (0 based: becomes `Mid$(s, i + 1, n)`) |
| `Mid$` statement | - (VB only) |
| `InStr(s, t)` | `s.indexOf(t)` (0 based, -1 = not found: `InStr - 1`) |
| `InStrRev` | `s.lastIndexOf(t)` |
| `UCase$`, `LCase$` | `s.toUpperCase()`, `s.toLowerCase()` |
| `Trim$`, `LTrim$`, `RTrim$` | `s.trim()`, `s.trimStart()`, `s.trimEnd()` |
| `Space$(n)`, `String$(n, c)` | `" ".repeat(n)`, `c.repeat(n)` |
| `Chr$(n)`, `Asc(s)` | `String.fromCharCode(n)`, `s.charCodeAt(0)` |
| `Str$`, `CStr` | `String(n)`, `n.toString()` |
| `Val` | `parseInt(s)`, `Number(s)` |
| `Hex$`, `Oct$` | `n.toString(16)`, `n.toString(8)` |
| `Replace` | `s.replace(a, b)` (every one, as VB: documented) / `s.replaceAll(a, b)` |
| `StrReverse` | `s.split("").reverse().join("")` (recognised as one) |
| `Format$` | - (VB only) |
| `LSet`, `RSet` | `s.padEnd(n)`, `s.padStart(n)` |
| template text | `` `n=${n}` `` -> `"n=" & n` |

### Flow

| VB5 | JS flavour | Notes |
|---|---|---|
| `If ... Then ... ElseIf ... Else ... End If` | `if (...) { } else if (...) { } else { }` | |
| `Select Case` | `switch (x) { case 1: ... break; default: ... }` | each `case` must end in `break` (no fall through), several `case`s before one body allowed |
| `For i = a To b [Step s] ... Next` | `for (let i = a; i <= b; i++)` (or `i += s`, `i--`) | a counting `for` -> For / Next |
| other `For` | `for (init; cond; step)` in any other form | -> While with the step at the end |
| `While ... Wend` | `while (...) { }` | |
| `Do ... Loop` (all forms) | - | VB only |
| `Exit For`, `Exit While` | `break;` | |
| - | `continue;` | -> a jump to the loop's end |
| `GoTo`, `GoSub`, `On ... GoTo/GoSub` | - | VB only |
| `With ... End With` | - | VB only |
| `End`, `Stop` | `exit();` | |

### Procedures

| VB5 | JS flavour | Notes |
|---|---|---|
| `Sub X(a, b)` | `function x(a, b) { }` (no value returned) | |
| `Function X(a) As Long` | `function x(a) { return ...; } //#long` | a `return value` makes it a Function |
| `ByVal` | the default | |
| `ByRef` | `//#byref` after the parameter | |
| `Optional a = 5` | `function x(a = 5)` | ES6 default value |
| `Exit Sub`, `Exit Function` | `return;` | |
| `Call X(1)`, `X 1` | `x(1);` | |
| `AddressOf X` | `x` used as a value (no `()`) | |
| `CallAddr(p, ...)` | `call(p, ...)` | |
| recursion | - | as NTC: not supported |

### Classes

| VB5 | JS flavour (ES6) | JS flavour (ES5) |
|---|---|---|
| class module `Counter.cls` | `class Counter { }` | `function Counter() { }` |
| `Private total As Integer` | `#total = 0;` | `var total = 0;` |
| `Public total As Integer` | `total = 0;` | `this.total = 0;` |
| `Private Sub X` | `#x() { }` | `function x() { }` |
| `Public Sub X` | `x() { }` | `this.x = function() { };` |
| `Property Get / Let` | `get x() { }`, `set x(v) { }` | - |
| `Me.total` | `this.total` | `this.total` (or plain `total`) |
| `Dim c As New Counter` | `let c = new Counter();` | the same |
| `c.Add 7`, `Counter.Add 7` | `c.add(7)`, `Counter.add(7)` | the same |
| `Option Class Overlay`, `Option Page` | the same lines | |
| `Option Class Interrupt` + `Sub Tick` | the same line + `tick() { }` | |

### Screen, keys, machine

| VB5 | JS flavour |
|---|---|
| `Print a; b` | `console.log(a, b)` (a new line after), `print(a, b)` (no new line) |
| `Debug.Print` | `console.debug(...)` |
| `Input "?", n` | `n = input("?");` |
| `Inkey`, `Inkey$` | `inkey()`, `inkeyStr()` |
| `Cls`, `Locate x, y`, `Mode n`, `Tab`, `Beep`, `Frame` | `cls()`, `locate(x, y)`, `mode(n)`, `tab(n)`, `beep()`, `frame()` |
| `Peek`, `Poke`, `Deek`, `Doke` | `peek(a)`, `poke(a, v)`, `deek(a)`, `doke(a, v)` |
| `Inp`, `Out` | `inp(p)`, `out(p, v)` |
| `Call &HBB5A` | `call(0xBB5A)` |
| `Ticks`, `Timer` | `ticks()`, `timer()` |
| `Interrupt X`, `DoEvents` | `interrupt(x)`, `doEvents()` |
| `Debug.Assert c` | `console.assert(c)` |
| `Error n` | `throw n;` (stops with that error, no catch) |
| `StdIO`, `System`, `FileSystem`, `Graphics`, `Memory`, `List` classes | the same classes, methods in any case: `FileSystem.load(...)` |
| `#asm` ... `#endasm` | `/* #asm` ... `*/` |
| `Turbo On`, `Turbo Off`, `#If`, `#Const`, `Option ...` | `//# Turbo On`, `//# Option ...` on a line of their own |

## Refused in the JS flavour (a plain message each)

Closures and arrow functions that use outer variables, object literals (other than the Enum
form), `try` / `catch`, `prototype`, `extends` / `super`, a constructor or arguments to
`new`, `this` outside a class, destructuring, spread, generators, `async`, `do ... while`,
`for ... of` / `for ... in`, `switch` fall through, `typeof`, `delete`, regular expressions,
floating point numbers.

## Plan

**Step 1 - ntcPrep, the flavour preprocessor, and what VB needs anyway** (small)
- `ntcPrep(input, options)`: the same input as `ntcCompile` (one text or `[{ name, text }]`),
  returns `{ files: [{ name, text }], errors: [{ file, line, msg }] }` - every file as VB5 text,
  same names (a class file under a `.cls` name), same line numbers. `ntcCompile` calls it
  first, so callers need not; the GUI also calls it to show the translated VB.
- Which flavour: a file's own first line (`//# Option Flavour JS`, `Option Flavour JS`) wins,
  else `options.flavour` (the default for files without the line), else `vb5`.
- Flavours by a factory: `NTC_FLAVOURS = { vb5: <passes the text through>, js: ntcFlavourJs }`
  (vb5 is an entry like any other, so there is no special case) - each entry is a function
  `(file, options) -> { text, errors }`. `ntcPrep` looks the name up and calls it; an unknown
  name is an error. A new flavour (BBC, C64, Locomotive ...) is one more function and one
  more entry, nothing else changes. Each in its own file (`js/ntc_flavour_js.js`).
- `Option Flavour JS | VB5` read on a file's first line; before `ntcParse`, a JS file is
  translated to VB5 text (a class file goes in under a `.cls` name). GUI: `.js` files in the
  project explorer, a new file can be JS, a view of the translated VB.
- VB additions the translation uses (and VB programmers get too): `Dim n = 0` (a start value),
  `'#type` hints (`Dim n = 0 '#long`), `+` joining when either side is text.

**Step 2 - the JS reader: tokens and structure** (about 300 lines)
- Tokens: names, numbers (`0x`, `0b`, `0o`), strings (both quotes, template text), operators,
  `{ } ( ) [ ] ; ,`, comments (keeping `//#` hints and the line numbers for messages).
- Statements by braces and `;`, any number of lines each.
- Structure errors caught here, in JS words: unbalanced braces, a `case` without `break`, every
  refused form. Only rare faults reach the VB parser's own messages.

**Step 3 - statements to VB5 lines** (about 500 lines)
- Line for line: each JS line's VB goes on the same line number (several statements joined
  with `:`, a statement over several lines on its first line with blank lines after), so every
  message from the parser and compiler names the right JS line with no mapping.
- `let` / `var` / `const` with the type rule and hints; arrays; `export`.
- `function` (Sub / Function from `return value`), defaults, `//#byref`.
- `if` / `else` -> `If` / `ElseIf` / `Else` / `End If`, `while` -> `While` / `Wend`, `for` (counting
  -> `For` / `Next`, else -> `While`), `break` -> `Exit For` / `Exit While`, `continue` -> `GoTo` a
  label the translator puts before `Next` / `Wend`, `switch` -> `Select Case`, `return` ->
  `Exit Sub` / the Function's value.
- ES6 `class` and the ES5 `function X() { var ...; function ...; this.x = function ...; }` form
  as class modules; `new` as a second name.
- NTC lines: `/* #asm` ... `*/` -> `#asm` ... `#endasm`, `//# ...` on its own line -> that line.

**Step 4 - expressions to VB5 expressions** (about 400 lines)
- JS operators to NTC's (`===` -> `=`, `!==` -> `<>`, `&&` -> `And`, `%` -> `Mod`, `**` -> `^`,
  `? :` -> `IIf`, `<< >>` with a constant).
- Methods and built-ins to NTC functions (the string, Math, console and machine tables above),
  with the 0 based / 1 based changes.
- `[i]` to `(i)`, template text to `&`.

**Step 5 - tests**
- Translation checks: JS in, the expected VB5 text out (cheap, exact, no running needed).
- JS copies of the self tests (vb_test, vb_test_long, a class test, the string tests) that
  must print the same as the VB ones, every platform, both modes, in the regression run.
- Mixed projects: a VB main with a JS class and the other way round.
- Each refused form gives its message (one regression line each).

**Step 6 - docs and examples**
- User guide: a JS flavour section (this table, cut to what is built), the `//#` / `'#` hints.
- Tutorial pages for JS; a few examples in JS in the GUI's Example list (guess, sieve, a class
  demo, the cube's main module).

**Later, if wanted:** `Type` as an object shape, `for ... of`, a constructor (with NTC
`Class_Initialize`), `Static`, BBC / C64 / Locomotive flavours on the same switch.

**Decisions before starting**
1. `Public` in a JS module: ES6 `export`, or everything at the top of a module public (as a
   VB `Global`)?
2. `console.log(a, b)`: VB's `Print a; b` (nothing between) or a space between as JS does?
3. Two dimension arrays: `a[i][j]` only (JS look), or also `a[i, j]`?
4. File naming: `.js` for both modules and classes (the reader sees `class` / ES5 form), or
   `.cls.js` for classes?
