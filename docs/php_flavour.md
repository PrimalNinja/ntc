# PHP flavour - guide

**Status (2026-10-18): first version built** - rides on the same `ntcPrep` and flavour factory
(`ntc_compiler.js`) as the JS flavour, the PHP flavour in `js/ntc_flavour_php.js`, `.php` files on
the command line (`cli.js`) and through `ntcrun.py`, an example (bas/php_demo), regression tests
(test/phpf). It is the JS flavour's technique over a PHP 5.4-shaped syntax: a defined subset, not a
PHP engine. Almost all of the JS flavour's rules hold; this doc lists what PHP writes differently.

A PHP syntax over NTC: NTC does not run PHP, it reads a PHP-shaped source and builds exactly what
the VB5 flavour builds. Familiar, close enough to move code between the flavours, not an
interpreter. Only the subset below is accepted.

## The ground rules

- **Per module.** `Option Flavour PHP` - in a PHP file as `//# Option Flavour PHP` on the first
  line, or just name the file `.php`. Modules of every flavour (VB, JS, PHP, Locomotive) mix
  freely in one project; a VB main can use a PHP class and the other way round.
- **A flavour preprocessor: PHP -> VB5 text -> the one parser.** A PHP module is translated to VB5
  source, line for line, and that text goes through the existing parser and compiler. One parser,
  one compiler to debug. `--vb` shows the translated VB next to the PHP.
- **Names ignore case** when compiling, as in VB. A `$` on a variable is part of the syntax, not
  the name: `$total` is the variable `total`. (A variable name that clashes case-insensitively
  with a Const still breaks the compile, as everywhere in NTC.)
- **Types.** A variable's type comes from its first value or its use, the same rule NTC has for
  undeclared variables: text -> String, anything else -> Integer. A parameter joined with `.` or
  passed to a string function is String. Otherwise a type hint at the end of the line: `//#long`,
  `//#byte`, `//#bool`, `//#string`, `//#string*20`, `//#stringmax 80`.
- **One object per class** (as NTC classes are now): no constructor, no inheritance, no `static`
  members. `new X()` is a second name for the class's one set of members. Setup is an ordinary
  public method the program calls.
- **Integers.** `/` divides whole numbers (as VB `\`). No floating point anywhere.
- **PHP's own tags are stripped.** `<?php`, `<?=`, `<?` and `?>` are removed; code between them is
  the program. NTC's lines stay valid PHP: inline assembly is a `/* #asm ... */` block comment,
  and directives are `//#` comments, so a PHP linter skips them.

## PHP and the VB5 the flavour builds

### Program structure

| VB5 | PHP flavour | Notes |
|---|---|---|
| module (`.bas`) | a `.php` file with functions and variables at the top | module = the file |
| class module (`.cls`) | a `.php` file holding one `class X { }` | the class's name = its module |
| top level code | statements at the top of the file | |
| `Sub Main` | `function main()` | runs after the top level code, as in VB |
| `Rem`, `'` | `//`, `#`, `/* */` | `#` to end of line is a comment too |
| `:` (several statements) | `;` | |

### Variables and constants

| VB5 | PHP flavour | Notes |
|---|---|---|
| `Dim n As Integer` | `$n = 0;` | first assignment declares; Integer by default |
| `Dim n As Long` | `$n = 0; //#long` | |
| `Dim b As Byte` | `$b = 0; //#byte` | |
| `Dim f As Boolean` | `$f = false;` | true / false = -1 / 0, as VB |
| `Dim s As String` | `$s = "";` | |
| `String * n`, `String Max n` | `$s = ""; //#string*20`, `//#stringmax 80` | |
| `Const MAX = 10` | `const MAX = 10;` | also `define("MAX", 10);` |
| `Option Explicit` | `//# Option Explicit` | every name declared before use |
| `True`, `False`, (`Null`) | `true`, `false`, `null` | null is 0 |
| `&H1F`, `&O17` | `0x1F`, `017` | |

### Arrays

| VB5 | PHP flavour | Notes |
|---|---|---|
| `Dim a(9) As Integer` | `$a = array_fill(0, 10, 0);` | 10 elements, 0-9 |
| literal | `$a = array(1, 2, 3);` or `$a = [1, 2, 3];` | |
| `a(i)` | `$a[$i]` | |
| `UBound(a)` | `count($a) - 1` | `count` / `sizeof` -> `UBound + 1` |
| `Split`, `Join` | `explode(",", $s)`, `implode(",", $a)` | argument order swapped for VB |

### Calculations

| VB5 | PHP flavour | Notes |
|---|---|---|
| `+ - *` | `+ - *` | text joins with `.`, not `+` |
| `/`, `\` | `/` | whole numbers |
| `Mod` | `%` | |
| `^` | `**`, `pow(a, b)` | |
| `Abs`, `Sqr` | `abs`, `sqrt` | |
| `Rnd` | `rand(n)`, `mt_rand(n)` | NTC's Rnd range |
| `+=` style | `+= -= *= /= %= .=`, `++`, `--` | `.=` joins text |
| `And`, `Or`, `Xor`, `Not` (bits) | `& | ^ ~` | |
| `And`, `Or`, `Not` (logic) | `&& || !`, `and or` | **no short cut**: both sides are worked out, as VB |
| - | `<< >>` | `x << n` -> `x * 2^n` (constant n) |

### Comparison and choice

| VB5 | PHP flavour | Notes |
|---|---|---|
| `= <> < <= > >=` | `== === != !== <> < <= > >=` | `==` and `===` the same |
| `IIf(c, a, b)` | `c ? a : b` | |

### Strings

| VB5 | PHP flavour |
|---|---|
| `&` | `.` |
| `Len(s)` | `strlen($s)` |
| `Mid$(s, i, n)` | `substr($s, i, n)` (0 based: becomes `Mid$(s, i + 1, n)`) |
| `Left$(s, n)` | `substr($s, 0, n)` |
| `InStr(s, t)` | `strpos($s, t)` (0 based, -1 = not found: `InStr - 1`) |
| `InStrRev` | `strrpos($s, t)` |
| `UCase$`, `LCase$` | `strtoupper($s)`, `strtolower($s)` |
| `Trim$`, `LTrim$`, `RTrim$` | `trim($s)`, `ltrim($s)`, `rtrim($s)` |
| `String$(n, c)` | `str_repeat(c, n)` |
| `Chr$(n)`, `Asc(s)` | `chr(n)`, `ord($s)` |
| `Str$`, `CStr` | `strval(n)` |
| `Val` | `intval($s)` |
| `Hex$`, `Oct$` | `dechex(n)`, `decoct(n)` |
| `Replace` | `str_replace(search, replace, subject)` (every one, as VB; args reordered) |
| `StrReverse` | `strrev($s)` |
| `LSet`, `RSet` | `str_pad($s, n)`, `str_pad($s, n, " ", STR_PAD_LEFT)` |
| template text | `"n=$n"`, `"n={$expr}"` -> `"n=" & n` |

### Flow

| VB5 | PHP flavour | Notes |
|---|---|---|
| `If ... ElseIf ... Else ... End If` | `if (...) { } elseif (...) { } else { }` | `else if` also accepted |
| `Select Case` | `switch (x) { case 1: ... break; default: ... }` | each `case` ends in `break` (no fall through); stacked `case`s with one body allowed |
| `For i = a To b [Step s]` | `for ($i = a; $i <= b; $i++)` (or `$i += s`, `$i--`) | a counting `for` -> For / Next |
| other `for` | any other `for (init; cond; step)` | -> While with the step at the end |
| `For Each` | `foreach ($a as $v)`, `foreach ($a as $k => $v)` | over `0 .. UBound`, the value (and key) assigned each pass |
| `While ... Wend` | `while (...) { }` | |
| `Exit For`, `Exit While` | `break;` | |
| - | `continue;` | -> a jump to the loop's end |
| `End`, `Stop` | `exit();` / `die();` | |

### Procedures

| VB5 | PHP flavour | Notes |
|---|---|---|
| `Sub X(a, b)` | `function x($a, $b) { }` (nothing returned) | |
| `Function X(a) As Long` | `function x($a) { return ...; } //#long` | a `return value` makes it a Function |
| `ByVal` | the default | |
| `ByRef` | `//#byref` after the parameter, or `&$a` | |
| `Optional a = 5` | `function x($a = 5)` | default value |
| `Exit Sub`, `Exit Function` | `return;` | |
| `Call X(1)`, `X 1` | `x(1);` | |
| `CallAddr(p, ...)` | `call_addr(p, ...)` | |

### Classes

| VB5 | PHP flavour | Notes |
|---|---|---|
| class module `Counter.cls` | `class Counter { }` | one class a file |
| `Private total As Integer` | `private $total = 0;` | |
| `Public total As Integer` | `public $total = 0;` | |
| `Private Sub X` | `private function x() { }` | |
| `Public Sub X` | `public function x() { }` | `function x()` defaults to public |
| member start value + hint | `public $total = 0; //#long` | |
| `Me.total` | `$this->total` | |
| `Dim c As New Counter` | `$c = new Counter();` | |
| `c.Add 7`, `Counter.Add 7` | `$c->add(7)`, `Counter::add(7)` | `->` and `::` both reach members |

### Screen, keys, machine

| VB5 | PHP flavour |
|---|---|
| `Print a; b` | `echo a, b;` / `print a;` (no new line; add `"\n"`) |
| `Inkey`, `Inkey$` | `inkey()`, `inkey_str()` |
| `Cls`, `Locate x, y`, `Mode n` | `cls()`, `locate(x, y)`, `mode(n)` |
| `Peek`, `Poke`, `Deek`, `Doke` | `peek(a)`, `poke(a, v)`, `deek(a)`, `doke(a, v)` |
| `Inp`, `Out` | `inp(p)`, `out(p, v)` |
| `Call &HBB5A` | `call_addr(0xBB5A)` |
| `Ticks`, `Timer` | `ticks()`, `timer()` |
| `StdIO`, `System`, `FileSystem`, `Graphics`, `Memory`, `List` classes | the same classes, methods in any case: `FileSystem::load(...)` |
| `#asm` ... `#endasm` | `/* #asm` ... `*/` |
| `Turbo On`, `Turbo Off`, `Option ...` | `//# Turbo On`, `//# Option ...` on a line of their own |

## Refused in the PHP flavour (a plain message each)

`do ... while`, `try` / `catch` / `throw`, closures (`function` / `fn` as a value) and anonymous
functions, a function inside a function, `namespace` / `use` / `trait` / `interface`, `extends`,
`static` members, `switch` fall through, the `[]` append form, floating point numbers. A class
goes in a file of its own.
