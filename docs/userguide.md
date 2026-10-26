# NTC BASIC User Guide

(c) 2026 Cyborg Unicorn Pty Ltd - MIT License

The complete language reference for NTC BASIC: a VB5 / VB6 style BASIC that compiles to
NTC (Native Threaded Code) for the Z80, with the Amstrad CPC as the first target.

The same program builds for several platforms: the Amstrad CPC (straight to the hardware,
or through its firmware), CP/M, and a test harness. Every keyword has its form, what it
does, a small example and, where NTC BASIC is not the same as VB5 / VB6, a **VB:** line
saying what is different. Keywords are grouped by topic.
An alphabetical index is at the end.
New to NTC BASIC? The [tutorial](tutorial/README.md) goes through it a small step at a time.

---

## Contents

1. [About NTC BASIC](#1-about-ntc-basic)
2. [Writing a program](#2-writing-a-program)
3. [Data types, variables and constants](#3-data-types-variables-and-constants)
4. [Arrays](#4-arrays)
5. [Calculations](#5-calculations)
6. [Comparison and logic](#6-comparison-and-logic)
7. [Strings](#7-strings)
8. [Program flow](#8-program-flow)
9. [Procedures](#9-procedures)
10. [Classes](#10-classes)
11. [Screen and keyboard](#11-screen-and-keyboard)
12. [Memory, ports and machine code](#12-memory-ports-and-machine-code)
13. [Speed: turbo and normal mode](#13-speed-turbo-and-normal-mode)
14. [Inline assembly](#14-inline-assembly)
15. [Diagnostics](#15-diagnostics)
16. [Compiler directives and options](#16-compiler-directives-and-options)
17. [Platforms and the console classes](#17-platforms-and-the-console-classes) (StdIO, System, FileSystem, Memory, List, Graphics, Keys, VDP, V9990; cartridge ROMs)
18. [Not in NTC BASIC](#18-not-in-ntc-basic)
19. [Keyword index](#19-keyword-index)

### How forms are written

| Written | Means |
|---|---|
| `Print` | type the keyword (upper, lower or mixed case - all the same) |
| *number* | any number expression |
| *text* | any string expression |
| *name* | a variable, procedure or label name |
| `[ ... ]` | may be left out |
| `{ a \| b }` | one of a or b |
| `...` | the part before can repeat |

In examples, `' prints:` shows what appears on the screen.

---

## 1. About NTC BASIC

A program is compiled into a **thread**: a list of addresses of small machine code
routines (keywords), each followed by its arguments. The Z80 stack pointer walks the
thread, and each keyword ends with `ret`, which jumps straight to the next one. There is
no interpreter loop and no `call` / `push` in the run time. On the CPC hardware platform
there is no firmware either; on CP/M and the CPC firmware platform, only the console
routines call the system (see [section 17](#17-platforms-and-the-console-classes)).

What this means when writing BASIC:

- Programs are fast and small, and the compiled program can live in ROM. Variables and
  scratch live in RAM.
- Numbers are whole numbers: `Integer` (16 bit) and `Long` (32 bit). There is no floating
  point.
- Strings are fixed buffers: 40 characters unless declared longer or shorter
  (`String * n`, `String Max n`, up to 255). There is no heap.
- Procedures can't call themselves (no recursion): each has one set of parameters and
  locals.
- There is no error trapping. Routines that can fail return a status.
- Two speeds: **turbo** (interrupts off the whole time) and **normal** (interrupts let in
  at safe points). See [section 13](#13-speed-turbo-and-normal-mode).

A project is one or more `.bas` modules and `.cls` classes. They are compiled together
into one program, for the platform chosen in the GUI (or `--platform=` on the command
line).

---

## 2. Writing a program

### Lines, statements and comments

```
' this is a comment
Rem so is this
Print "one" : Print "two"     ' : puts several statements on one line
x = 1 + _
    2                         ' _ at the end joins the next line on
```

- Case does not matter: `PRINT`, `print` and `Print` are the same.
- `'` or `Rem` starts a comment that runs to the end of the line.
- `:` separates statements on one line (not inside quotes).
- ` _` at the end of a line continues the statement on the next line.

### Top level code and Sub Main

Statements outside any procedure are the main program and run from the top, as in
classic BASIC. If there is a `Sub Main`, it runs after the top level code - the compiler calls
it when the top level code reaches its end (not after an `End`). With no top level code, `Sub
Main` runs straight away.

```
Print "starting"
' ... then Sub Main runs

Sub Main()
  Print "in Main"
End Sub
```

**VB:** a VB module can't have top level statements; the program starts in `Sub Main`
or a form. In NTC BASIC both work.

### Line numbers and labels

A line can start with a number or a label (a name followed by `:`). `GoTo`, `GoSub`,
`On ... GoTo` and `{label}` in `#asm` can jump to them.

```
10 Print "Hi"
20 GoTo done
30 Print "not printed"
done:
Print "end"
```

Labels belong to their procedure: a `GoTo` can't leave or enter a procedure.

### Modules and classes

- A `.bas` file is a module. Its name comes from `Attribute VB_Name = "..."`, or the file
  name.
- A `.cls` file is a class (see [section 10](#10-classes)).
- `Private` names are seen only in their own module. `Public` / `Global` names are seen
  everywhere.
- A name can be given in full as `Module.Name`.

VB header lines (`VERSION`, `BEGIN ... END`, `Attribute ...`) are accepted and skipped,
so `.bas` and `.cls` files from VB5 / VB6 can be loaded as they are. A `.vbp` project can be
opened in the GUI; forms are left out.

---

## 3. Data types, variables and constants

### Data types

| Type | Size | Range / contents | Suffix |
|---|---|---|---|
| `Integer` | 2 bytes | -32768 .. 32767 | `%` |
| `Long` | 4 bytes | -2147483648 .. 2147483647 | `&` |
| `Byte` | 2 bytes (1 in an array) | 0 .. 255 (not checked as a variable) | |
| `Boolean` | 2 bytes | `True` (-1) / `False` (0) | |
| `String` | 42 bytes | up to 40 characters | `$` |
| `String Max n` | n + 2 bytes | up to n characters (n = 1 .. 255) | |
| `String * n` | n + 2 bytes | exactly n characters, padded with spaces (n = 1 .. 255) | |
| a `Type` | the sum of its fields | see [Type](#type--end-type) | |
| a class | - | see [section 10](#10-classes) | |

**VB:** no `Single`, `Double`, `Currency`, `Date`, `Variant` or `Object` values. A String
holds 40 characters unless declared with `String Max n` or `String * n`: anything longer
is cut to fit. A Byte variable is 2 bytes and
keeps whatever is put in it (`y = 300` keeps 300); a Byte array element is 1 byte and keeps
the low 8 bits.

### Number literals

| Written | Value |
|---|---|
| `123` | decimal |
| `&HFF`, `&FF`, `#FF` | hexadecimal (the last two are CPC BASIC style) |
| `&O17` | octal |
| `&X101` | binary (CPC BASIC style) |
| `1000&`, `&HFFFF&` | Long, whatever the size |
| `True`, `False` | -1, 0 |

A literal over 65535 is a Long.

**VB:** `&FF`, `#FF` and `&X101` are additions.

### String literals

Text in double quotes. Two quotes inside stand for one: `"say ""hi"""`.

### Dim

`Dim` *name* [`As` *type*] [, *name* [`As` *type*]] ...

Declares variables. At module level, `Dim` is private to the module. Inside a procedure,
`Dim` makes a local.

```
Dim count As Integer, total As Long
Dim nm As String, flags As Byte
Dim code As String * 4
```

Numbers start at 0 and strings at "" (a `String * n` starts as n spaces). Locals are
cleared again on every call.

**VB:** the same.

### Undeclared variables

Without `Option Explicit`, a name can be used without `Dim`. Its type comes from its
suffix (`a$`, `n%`, `big&`), or from how it is used: assigned or compared with text, read
with `Input` into text, joined with `&` → String; otherwise Integer.

```
nm$ = "Ann"
n = 5
Print nm$; n
' prints: Ann5
```

**VB:** an undeclared variable is a `Variant` in VB. NTC BASIC picks a fixed type
instead.

### Private, Public, Global

`Private` *name* [`As` *type*] ... / `Public` *name* [`As` *type*] ... / `Global` *name* [`As` *type*] ...

Module level declarations. `Private` is seen only in its module; `Public` and `Global` are
seen in every module.

```
Public Score As Integer
Private mSeed As Long
```

### Static

`Static` *name* [`As` *type*] ...

Inside a procedure: a local that keeps its value between calls.

```
Sub Tick()
  Static n As Integer
  n = n + 1
  Print n;
End Sub
```

`Static Sub` / `Static Function` makes every local in it static.

### Const

[`Public` | `Private`] `Const` *name* [`As` *type*] `=` *value* [, ...]

A name for a fixed value, worked out when compiling. It can use other constants.

```
Const WIDTH = 40, HALF = WIDTH \ 2
Const TITLE = "NTC"
Print TITLE; HALF
' prints: NTC20
```

### Enum ... End Enum

```
Enum Colour
  Black
  Blue = 4
  Red
End Enum
```

Each member is a constant, starting at 0 and going up by 1; `= value` sets one. Use them
as `Red` or `Colour.Red`.

```
Enum Colour
  Black
  Blue = 4
  Red
End Enum
Print Black; Red; Colour.Blue
' prints: 054
```

### Type ... End Type

```
Type Point
  x As Integer
  y As Integer
End Type
```

A record of fields. Fields can be numbers, Strings, Longs, arrays of a fixed size and
other Types.

```
Type Point
  x As Integer
  y As Integer
End Type
Dim p As Point
p.x = 3 : p.y = 4
Print p.x + p.y
' prints: 7
```

`Private Type` / `Public Type` are allowed, also in a class.

### Let and Set

[`Let`] *name* `=` *value* / `Set` *name* `=` *value*

Assignment. `Let` can be left out. `Set` is accepted and works like `Let`.

**VB:** `Set` assigns an object reference in VB. There are no run time objects in NTC
BASIC, so it is a plain assignment.

---

## 4. Arrays

### Dim (arrays)

`Dim` *name*`(`[*low* `To`] *high* [, ...]`)` [`As` *type*]

A fixed array. Bounds must be constants. Without `To`, the low bound is 0 (or 1 under
`Option Base 1`). Any number of dimensions.

```
Dim a(10) As Integer           ' 11 elements, 0 .. 10
Dim b(1 To 5) As Long
Dim grid(3, 4) As Byte          ' Byte arrays use 1 byte per element
Dim names(9) As String
Dim pts(5) As Point             ' then pts(2).x
a(3) = 42
Print a(3)
' prints: 42
```

There is no bounds check: an index out of range reads or writes other memory.

**Where arrays go:** after the program, not in its file - a `Dim a(5000) As Integer` adds 10,000
bytes of memory but nothing to the `.COM` / `.BIN`. When the program starts it checks they fit
below the top of free memory (CP/M: the BDOS; CPC: `#A600`, or under the stack) and clears
them; if they don't fit it prints `Not enough memory for the arrays` and stops. So one build
runs on CP/M 2.2 or CP/M Plus, and says so when it doesn't fit. For data bigger than the
program's memory, use a [List](#list).

**VB:** VB stops with "Subscript out of range". NTC BASIC does not check.

### Option Base

`Option Base` { `0` | `1` }

Sets the default low bound for arrays declared without `To` in this module.

### Dynamic arrays and ReDim

`Dim` *name*`()` [`As` *type*]
`ReDim` [`Preserve`] *name*`(`[*low* `To`] *high*`)`

An array whose bounds are set at run time by `ReDim`. Without `Preserve` the elements are
cleared; with `Preserve` they are kept.

```
Dim list() As Integer
ReDim list(1 To 5)
list(5) = 9
ReDim Preserve list(1 To 8)
Print list(5); UBound(list)
' prints: 98
```

**VB:** the bounds must be constants (there is no heap). The array's storage is as big as
the biggest `ReDim` of it anywhere in the program. One dimension only.

### Erase

`Erase` *name* [, *name*] ...

Clears every element of a fixed array to 0 / "". On a dynamic array, it also drops the
bounds.

```
Dim a(3) As Integer
a(1) = 5
Erase a
Print a(1)
' prints: 0
```

### LBound and UBound

`LBound(`*array* [, *dimension*]`)` / `UBound(`*array* [, *dimension*]`)`

The lowest / highest index of an array, for dimension 1 unless given.

```
Dim g(1 To 3, 5) As Integer
Print LBound(g); UBound(g); UBound(g, 2)
' prints: 135
```

On a fixed array the compiler works the value out; on a dynamic array or an array
parameter it is read at run time.

### Arrays as parameters

See [section 9](#arrays-and-types-as-parameters).

---

## 5. Calculations

All arithmetic is on whole numbers. Integer arithmetic is 16 bit. An expression with a
Long in it (a Long variable, function, array element or literal) is worked out in 32 bits,
with the Integer parts widened.

**VB:** there is no overflow check: Integer and Long arithmetic wraps
(`32767 + 1` = -32768). VB stops with "Overflow". A Long put into an Integer keeps the low
16 bits.

Order of operations, highest first:

| Order | Operators |
|---|---|
| 1 | `^` |
| 2 | `-` (minus sign) |
| 3 | `*` `/` `\` `Mod` |
| 4 | `+` `-` |
| 5 | `&` |
| 6 | `=` `<>` `<` `<=` `>` `>=` `Like` |
| 7 | `Not` |
| 8 | `And` |
| 9 | `Or` `Xor` |

Brackets change the order.

### Add, subtract, multiply

*a* `+` *b* / *a* `-` *b* / *a* `*` *b*

Add, subtract, multiply. `-`*a* is the minus sign.

```
Print 7 + 3; ","; 7 - 10; ","; 6 * 7
' prints: 10,-3,42
```

Integer × Integer stays 16 bit, as in VB. For a Long result, make one side Long:
`CLng(a) * b` or `a * 1000&`.

### Divide

*a* `/` *b* / *a* `\` *b*

Divide. Both give a whole number, cut toward 0.

```
Print 7 / 2; ","; -7 \ 2
' prints: 3,-3
```

**VB:** `/` gives a fraction in VB (`7 / 2` = 3.5, rounded when stored in an Integer). In
NTC BASIC `/` is the same as `\`.

### Mod

*a* `Mod` *b*

The remainder of *a* `\` *b*. It has the sign of *a*.

```
Print 17 Mod 5; ","; -7 Mod 2
' prints: 2,-1
```

### Power

*a* `^` *b*

*a* to the power *b*, a whole number. A negative power gives 0. `-2 ^ 2` is -4 (power
first, as in VB).

```
Print 2 ^ 10
' prints: 1024
```

**VB:** VB gives a fraction for a negative power.

### Abs

`Abs(`*number*`)`

The number without its sign.

```
Print Abs(-37)
' prints: 37
```

### Sgn

`Sgn(`*number*`)`

1 if the number is above 0, 0 if it is 0, -1 if it is below 0.

```
Print Sgn(-9); Sgn(0); Sgn(5)
' prints: -101
```

### Int and Fix

`Int(`*number*`)` / `Fix(`*number*`)`

The whole number part. Numbers are already whole, so both give the number back. Given
text, they read it as a number like `Val`.

**VB:** `Int(-2.5)` = -3 and `Fix(-2.5)` = -2 in VB. With no fractions, NTC BASIC has
nothing to cut.

### Sqr

`Sqr(`*number*`)`

The whole number square root (rounded down). 0 for a negative number.

```
Print Sqr(17)
' prints: 4
```

**VB:** VB gives a fraction (`Sqr(17)` = 4.123...).

### Rnd and Randomize

`Rnd(`*n*`)` / `Randomize` [*seed*]

`Rnd(n)` gives a random whole number from 0 to n-1 (0 if n is 0 or less). `Randomize seed`
starts the sequence from *seed*; `Randomize` on its own uses the tick count.

```
Randomize
Print Rnd(6) + 1               ' a dice throw, 1 .. 6
```

**VB:** VB's `Rnd` gives a fraction from 0 to just under 1, and its argument picks the
mode. NTC BASIC's `Rnd(n)` is CPC style: the range.

### CInt, CLng, CByte, CBool

`CInt(`*value*`)` / `CLng(`*value*`)` / `CByte(`*value*`)` / `CBool(`*value*`)`

Change the type. `CInt` gives an Integer (the low 16 bits of a Long; text is read as a
number). `CLng` gives a Long (text is read as a 32 bit number). `CByte` keeps the low 8
bits. `CBool` gives `True` (-1) for anything but 0.

```
Dim n As Long
n = CLng(300) * 300
Print n; ","; CByte(300); ","; CBool(5)
' prints: 90000,44,-1
```

**VB:** `CByte(300)` stops with "Overflow" in VB; here it keeps the low 8 bits.

---

## 6. Comparison and logic

### Compare

*a* `=` *b*, *a* `<>` *b*, *a* `<` *b*, *a* `<=` *b*, *a* `>` *b*, *a* `>=` *b*

Compare two numbers or two strings. The result is `True` (-1) or `False` (0). Strings
compare character by character by code; a shorter string that matches the start of a
longer one is smaller.

```
Print 3 < 5; ","; "abc" = "abd"
' prints: -1,0
```

Under `Option Compare Text`, string compares ignore case.

### And, Or, Xor, Not

*a* `And` *b*, *a* `Or` *b*, *a* `Xor` *b*, `Not` *a*

Bit by bit operations on the whole number. `True` is -1 (all bits set), so they also work
as logical operators on compare results.

```
Print 5 And 3; ","; 5 Or 3; ","; 5 Xor 3; ","; Not 0
' prints: 1,7,6,-1
If x > 0 And x < 10 Then Print "in range"
```

**VB:** both sides are always worked out, as in VB (no short cut).

### Like

*text* `Like` *pattern*

`True` if the text matches the pattern:

| In the pattern | Matches |
|---|---|
| `*` | any run of characters, also none |
| `?` | one character |
| `#` | one digit |
| `[abc]`, `[a-z]` | one of these characters |
| `[!abc]` | one character that is not one of these |
| anything else | itself |

```
Print "abc" Like "a*"; ","; "a1" Like "a#"; ","; "abc" Like "A*"
' prints: -1,-1,0
```

Case matters unless the module has `Option Compare Text`.

### Option Compare Text

`Option Compare Text`

In this module, string compares, `Like`, `InStr`, `InStrRev`, `StrComp` and `Select Case` on
strings ignore case. `Option Compare Binary` (the default) is accepted.

### IIf

`IIf(`*condition*`,` *a*`,` *b*`)`

*a* if the condition is true, else *b*. Numbers, Longs or strings.

```
Print IIf(1 > 2, "yes", "no")
' prints: no
```

Both *a* and *b* are worked out first, as in VB.

### Choose

`Choose(`*n*`,` *a*`,` *b* [, ...]`)`

The *n*th value (1 = *a*). Up to 8 values.

```
Print Choose(2, "a", "b", "c")
' prints: b
```

**VB:** out of range gives `Null` in VB; here it gives 0 or "".

---

## 7. Strings

A String holds up to 40 characters, stored as bytes ending in a 0 byte. `String Max n`
and `String * n` give any length from 1 to 255, longer or shorter. Joining or assigning
more than a string holds keeps what fits. On the CPC hardware platform the program draws text
itself, with the CPC's own font (copied from the machine's ROM when the program starts); on
the other platforms the system draws it.

How long strings are:

| Where | Holds |
|---|---|
| `Dim s As String` (variables, locals, Type fields, array elements) | 40 |
| `Dim s As String Max n` / `As String * n` | n (1 .. 255) |
| parameters, function results, and the working space for joins and functions | the longest string declared anywhere in the program (at least 40) |

So a long value passes through procedures and functions whole, and is only cut when it
is stored into something shorter. Each string takes its length + 2 bytes (array
elements: + 1), so a short `String Max n` saves memory: `Dim names(99) As String Max 12`
takes 1.3 KB instead of 4.1 KB.

**VB:** VB strings grow as needed (no heap here). `String Max n` is NTC BASIC's own.

Functions are written with or without `$`: `Left$` and `Left` are the same.

### Join strings

*a* `&` *b*

Joins two strings. A number on either side is turned into text first.

```
Dim n As Integer
n = 5
Print "n=" & n
' prints: n=5
```

`+` also joins two strings.

### Len

`Len(`*text*`)`

The number of characters.

```
Print Len("hello")
' prints: 5
```

### Left$, Right$

`Left$(`*text*`,` *n*`)` / `Right$(`*text*`,` *n*`)`

The first / last *n* characters (the whole text if it is shorter).

```
Print Left$("hello", 2); Right$("hello", 3)
' prints: hello
```

### Mid$ (function)

`Mid$(`*text*`,` *start* [`,` *length*]`)`

*length* characters from position *start* (1 = first), or the rest of the text.

```
Print Mid$("hello", 2, 2); ","; Mid$("hello", 3)
' prints: el,llo
```

### Mid$ (statement)

`Mid$(`*variable*`,` *start* [`,` *length*]`) =` *text*

Replaces characters of the variable from *start*, in place. The length of the variable
does not change.

```
Dim s As String
s = "hello"
Mid$(s, 2, 3) = "ipp"
Print s
' prints: hippo
```

### InStr

`InStr(`[*start*`,`] *text*`,` *find*`)`

The position of *find* in *text*, searching from *start* (default 1). 0 if not found.

```
Print InStr("hello", "l"); ","; InStr(4, "hello", "l")
' prints: 3,4
```

**VB:** VB's fourth argument (compare mode) is not taken; use `Option Compare Text`.

### InStrRev

`InStrRev(`*text*`,` *find* [`,` *start*]`)`

The position of the last *find* in *text*, searching back from *start* (default: the
end). 0 if not found.

```
Print InStrRev("hello", "l")
' prints: 4
```

### StrComp

`StrComp(`*a*`,` *b*`)`

-1 if *a* sorts before *b*, 0 if they are the same, 1 if after.

```
Print StrComp("a", "b"); StrComp("b", "a"); StrComp("a", "a")
' prints: -110
```

### UCase$, LCase$

`UCase$(`*text*`)` / `LCase$(`*text*`)`

The text in capitals / small letters.

```
Print UCase$("abc"); LCase$("DEF")
' prints: ABCdef
```

### Trim$, LTrim$, RTrim$

`Trim$(`*text*`)` / `LTrim$(`*text*`)` / `RTrim$(`*text*`)`

The text without spaces at both ends / the left / the right.

```
Print "["; Trim$("  x  "); "]"
' prints: [x]
```

### Space$, Spc, String$

`Space$(`*n*`)` / `String$(`*n*`,` *char*`)`

*n* spaces / *n* copies of a character (given as text, first character used, or as a
code).

```
Print "["; Space$(3); "]"; String$(4, "*"); String$(2, 65)
' prints: [   ]****AA
```

`Spc(n)` is `Space$(n)`, mostly used in `Print`.

### Chr$, Asc

`Chr$(`*code*`)` / `Asc(`*text*`)`

The character with that code / the code of the first character (0 for "").

```
Print Chr$(65); Asc("B")
' prints: A66
```

### Str$, CStr

`Str$(`*number*`)` / `CStr(`*value*`)`

A number as text. `Str$` puts a space in front of a number that is 0 or more (room for
the sign); `CStr` does not.

```
Print "["; Str$(5); "]["; CStr(5); "]["; Str$(-5); "]"
' prints: [ 5][5][-5]
```

### Val

`Val(`*text*`)`

Reads a number from the start of the text: spaces skipped, an optional `-`, then digits up
to the first character that is not a digit. 0 if there is none.

```
Print Val("12abc"); ","; Val("  -3")
' prints: 12,-3
```

**VB:** VB's `Val` also reads fractions, exponents and `&H` numbers. Into a Long, `Val`
reads 32 bit numbers.

### Hex$, Oct$

`Hex$(`*number*`)` / `Oct$(`*number*`)`

The number in hexadecimal / octal, no leading zeros. An Integer is taken as 16 bits; a
Long as 32.

```
Print Hex$(255); ","; Hex$(-1); ","; Oct$(8)
' prints: FF,FFFF,10
```

### Replace

`Replace(`*text*`,` *find*`,` *with*`)`

The text with every *find* replaced by *with*.

```
Print Replace("aXbXc", "X", "--")
' prints: a--b--c
```

**VB:** VB's start, count and compare arguments are not taken.

### StrReverse

`StrReverse(`*text*`)`

The text backwards.

```
Print StrReverse("abc")
' prints: cba
```

### Format$

`Format$(`*number*`,` *pattern*`)`

The number as text, laid out by the pattern. The pattern must be a constant string.

| In the pattern | Means |
|---|---|
| `0` | a digit, always shown (gives the least number of digits) |
| `#` | a digit, shown only if needed |
| `,` | group the digits in threes |
| text before the first / after the last `0` or `#` | kept as it is |

```
Print Format$(42, "0000"); " "; Format$(1234567, "#,##0"); " "; Format$(5, "$0.00")
' prints: 0042 1,234,567 $5.00
```

`Format$(number)` with no pattern is `CStr(number)`.

**VB:** whole numbers only (`.00` is copied as text). No named formats (`"Currency"`), no
dates, no `;` sections.

### LSet, RSet

`LSet` *variable* `=` *text* / `RSet` *variable* `=` *text*

Puts the text at the left / right of the variable's current length, padded with spaces
(cut if too long). Mostly used with `String * n`.

```
Dim f As String * 6
RSet f = "42"
Print "["; f; "]"
' prints: [    42]
```

### String * n

`Dim` *name* `As String *` *n*

A string that is always exactly *n* characters (1 .. 255). It starts as *n* spaces, and
every assignment or `Input` pads it with spaces or cuts it to *n*. This is VB's fixed-length
string.

```
Dim code As String * 4
code = "ab"
Print "["; code; "]"
' prints: [ab  ]
```

### String Max n

`Dim` *name* `As String Max` *n*

A string of at most *n* characters (1 .. 255), not padded. Use it for text longer than 40
(a line buffer, a long message) or shorter, to save memory. Works for variables, locals,
arrays (each element) and Type fields.

```
Dim lineBuf As String Max 200
Dim code As String Max 4
lineBuf = String$(150, "-")
code = "abcdefg"
Print Len(lineBuf); ","; code
' prints: 150,abcd
```

**VB:** not in VB (VB strings have no limit). `String * n` is VB's fixed-length string.

### Join

`Join(`*array* [`,` *separator*]`)`

The elements of a 1 dimension String array joined into one string, with the separator
between them (default a space).

```
Dim w(2) As String
w(0) = "a" : w(1) = "b" : w(2) = "c"
Print Join(w, "-")
' prints: a-b-c
```

### Split

*array* `= Split(`*text* [`,` *separator*]`)`

Fills a dynamic String array with the parts of the text between separators (default a
space), from index 0.

```
Dim parts() As String
parts = Split("red,green,blue", ",")
Print UBound(parts); parts(1)
' prints: 2green
```

**VB:** no heap: the array holds at most 16 parts, or more if a `ReDim` of it somewhere
in the program is bigger. Extra parts are dropped. VB's limit and compare arguments are
not taken.

---

## 8. Program flow

### If ... Then ... Else

```
If condition Then statement [Else statement]

If condition Then
  ...
[ElseIf condition Then
  ...] ...
[Else
  ...]
End If
```

Runs statements when the condition is true (not 0). The one line form can hold several
statements joined with `:`.

```
x = 7
If x > 5 Then Print "big" Else Print "small"
If x Mod 2 = 0 Then
  Print "even"
ElseIf x = 7 Then
  Print "seven"
Else
  Print "odd"
End If
' prints: big
' prints: seven
```

`End If` can be written `EndIf`, and `ElseIf` as `Else If`.

### Select Case

```
Select Case expression
  Case value [, value] ...
    ...
  [Case Else
    ...]
End Select
```

Runs the first `Case` that matches. A value can be a number or string, `a To b` (a range),
or `Is` *compare* *value* (`Is > 10`).

```
Select Case 7
  Case 1, 2: Print "low"
  Case 3 To 6: Print "mid"
  Case Is > 6: Print "high"
  Case Else: Print "other"
End Select
' prints: high
```

### For ... Next

```
For variable = start To end [Step step]
  ...
Next [variable]
```

Counts *variable* from *start* to *end*, adding *step* (default 1) each time. With a
negative step it counts down. If *start* is already past *end*, the loop does not run.
*end* and *step* are worked out once, at the start.

```
For i = 10 To 1 Step -3
  Print i;
Next
' prints: 10741
```

`Next i, j` closes two loops. A Long variable can count past 32767. An Integer loop that
runs to 32767 (or down to -32768) ends there: the step that would go past the Integers ends
the loop, and the variable is left wrapped round (VB stops with an overflow error).

### For Each ... Next

```
For Each variable In array
  ...
Next [variable]
```

*variable* takes each element of a 1 dimension array in turn: fixed, dynamic or an array
parameter.

```
Dim a(2) As Integer
a(0) = 4 : a(1) = 5 : a(2) = 6
For Each v In a
  Print v;
Next
' prints: 456
```

**VB:** arrays only - there are no collections. Not an array of a Type.

### While ... Wend

```
While condition
  ...
Wend
```

Repeats while the condition is true. `End While` is the same as `Wend`.

```
n = 1
While n < 100
  n = n * 2
Wend
Print n
' prints: 128
```

### Do ... Loop

```
Do [{While | Until} condition]
  ...
Loop [{While | Until} condition]
```

Repeats. The test can be at the top, at the bottom, or neither (then only `Exit Do` or a
jump leaves). `While` keeps going while true; `Until` keeps going until true.

```
n = 0
Do
  n = n + 3
Loop Until n > 10
Print n
' prints: 12
```

### Exit

`Exit For` / `Exit Do` / `Exit While` / `Exit Sub` / `Exit Function` / `Exit Property`

Leaves the innermost loop of that kind, or the procedure, straight away.

```
For i = 1 To 100
  If i * i > 50 Then Exit For
Next
Print i
' prints: 8
```

**VB:** `Exit While` is an addition (VB has no way out of a `While` loop).

### GoTo

`GoTo` *label*

Jumps to a label or line number in the same procedure (or in the main program).
`Go To` also works.

```
GoTo skip
Print "not printed"
skip:
Print "here"
```

### GoSub ... Return

`GoSub` *label* / `Return`

Jumps to a label and comes back to the statement after the `GoSub` at the next `Return`.

```
GoSub hello
GoSub hello
End
hello:
  Print "hi ";
  Return
' prints: hi hi
```

GoSub works inside procedures too (the label must be in the same procedure).

**VB:** the same as VB. Most GoSubs compile to a direct jump that remembers one return
point; where one return point might not be enough, the compiler uses a small GoSub stack
instead.

### On ... GoTo, On ... GoSub

`On` *number* `GoTo` *label*, *label*, ... / `On` *number* `GoSub` *label*, *label*, ...

Jumps to the first label if *number* is 1, the second if 2, and so on. Any other number
carries on with the next statement.

```
x = 2
On x GoTo one, two
Print "none"
one: Print "one" : End
two: Print "two"
' prints: two
```

### End, Stop

`End` / `Stop`

Ends the program.

**VB:** `Stop` pauses in the VB IDE. In NTC BASIC it ends the program, the same as `End`.
To stop at a place for a debugger, use `Break`.

### With ... End With

```
With name
  .member = value
  ...
End With
```

Inside, a name starting with `.` belongs to *name*. Works with Type variables, Type array
elements and classes. Can be nested.

```
Dim p As Point
With p
  .x = 3
  .y = .x * 2
End With
Print p.y
' prints: 6
```

### No error handling

There is no `On Error`, `Resume`, `Err` or `Erl`, and there won't be. A routine that can fail
returns a status (for example 0 = ok, a negative number = an error) and the caller checks
it. For checking a program while writing it, see [Diagnostics](#15-diagnostics).

**VB:** `On Error` gives a compile error explaining this.

---

## 9. Procedures

### Sub ... End Sub

```
[Public | Private | Friend] [Static] Sub name([parameters])
  ...
End Sub
```

A procedure that does something. Call it as `name args` or `Call name(args)`.

```
Sub Greet(ByVal who As String)
  Print "Hello "; who
End Sub

Greet "Ann"
Call Greet("Bob")
```

### Function ... End Function

```
[Public | Private | Friend] [Static] Function name([parameters]) [As type]
  ...
  name = value
End Function
```

A procedure that gives back a value. Inside, assign the result to the function's name.
The result starts at 0 / "" on each call.

```
Function Twice(ByVal n As Integer) As Integer
  Twice = n * 2
End Function

Print Twice(21)
' prints: 42
```

Calling a function as a statement (throwing the result away) gives a warning: with no
error handling, a status that is never looked at is worth seeing.

### Parameters: ByVal, ByRef, Optional

`[Optional] [ByVal | ByRef]` *name*[`()`] [`As` *type*] [`=` *default*]

- `ByRef` (the default): the procedure works on the caller's variable. If the procedure
  changes the parameter, the caller's variable changes when the procedure ends.
- `ByVal`: the procedure gets a copy.
- `Optional`: may be left out; it then gets *default* (or 0 / "").

```
Sub Bump(n As Integer, Optional ByVal by As Integer = 1)
  n = n + by
End Sub

x = 5
Bump x
Bump x, 10
Print x
' prints: 16
```

**VB:** a ByRef parameter is copied back when the procedure ends, not changed straight
away, so the caller's variable changes at the end of the call rather than during it. The
result is the same unless the procedure also changes that variable another way (as a
global) before it ends. No `ParamArray`.

### Exit Sub, Exit Function, Exit Property

Leaves the procedure straight away. See [Exit](#exit).

### Call

`Call` *name*[`(`*arguments*`)`]

Calls a Sub (or a Function, throwing the result away). `Call` with a number instead of a
name runs machine code - see [Call (machine code)](#call-machine-code).

### No recursion

A procedure can't call itself, directly or through other procedures. Each procedure has
one set of parameters and locals and one return point; the compiler reports a call that
would come back round.

**VB:** VB allows recursion.

### Static locals

See [Static](#static). Locals that are not `Static` (including local arrays) are cleared on
every call, as in VB.

### Arrays and Types as parameters

`Sub` *name*`(`*arr*`() As` *type*`)` / `Sub` *name*`(` [`ByVal`] *p* `As` *TypeName*`)`

An array parameter takes any array of that type with 1 or 2 dimensions: fixed, dynamic or
another array parameter. It is always ByRef. `LBound` / `UBound` work on it.

```
Function Sum(a() As Integer) As Integer
  Dim i As Integer
  For i = LBound(a) To UBound(a)
    Sum = Sum + a(i)
  Next
End Function

Dim v(3) As Integer
v(0) = 1 : v(1) = 2 : v(2) = 3 : v(3) = 4
Print Sum(v)
' prints: 10
```

A Type parameter takes a variable of that Type. Arrays of a Type can be passed too
(`a() As Point`, then `a(i).x`).

**VB:** array parameters of 3 or more dimensions are not supported.

### Property Get, Property Let, Property Set

```
[Public | Private] Property Get name([arguments]) [As type]
  name = value
End Property

[Public | Private] Property Let name([arguments,] ByVal value As type)
  ...
End Property
```

A value that runs code when it is read (`Get`) or written (`Let`; `Set` is the same). Mostly
used in classes. They can take arguments, like an array.

```
Private mItems(9) As Integer

Public Property Get Item(ByVal i As Integer) As Integer
  Item = mItems(i)
End Property

Public Property Let Item(ByVal i As Integer, ByVal v As Integer)
  mItems(i) = v
End Property
```

Then `Bag.Item(3) = 42` and `x = Bag.Item(3)`.

### AddressOf, CallAddr

`AddressOf` *procedure* / `CallAddr` *address* [`,` *argument*] ...

`AddressOf` gives a number: the address of a procedure's entry. It can be stored in a
variable or array and passed around. `CallAddr` calls the procedure at that address, with
arguments.

```
Dim table(1) As Integer
table(0) = AddressOf SayA
table(1) = AddressOf SayB
CallAddr table(1)
End

Sub SayA()
  Print "A"
End Sub

Sub SayB()
  Print "B"
End Sub
' prints: B
```

The arguments must match the procedure's parameters; the compiler can't check that through
an address.

**VB:** VB's `AddressOf` is only for passing to Windows API calls, and VB has no
`CallAddr`. Here they are for driver and command tables.

### VarPtr

`VarPtr(`*variable*`)` / `VarPtr(`*array*`)`

The address of a variable's value (a String: its first character), or of a fixed size
array's first element. For `FileSystem.Load` / `Save` and `#asm`. An element's address is
worked out from the first: element `i` of an Integer array is `VarPtr(a) + i * 2`.

```
Dim scores(9) As Integer
r = FileSystem.Save("SCORES.DAT", VarPtr(scores), 20)
```

**VB:** VB6's `VarPtr` also takes an element (`VarPtr(a(3))`); here it takes a name.

---

## 10. Classes

A `.cls` file is a class: its variables and procedures are its members.

```
' Counter.cls
Private mTotal As Integer

Public Sub Add(ByVal v As Integer)
  mTotal = mTotal + v
End Sub

Public Property Get Total() As Integer
  Total = mTotal
End Property
```

```
' Main.bas
Dim c As New Counter
c.Add 5
c.Add 7
Print c.Total
Print Counter.Total
' prints: 12
' prints: 12
```

- `Dim` *name* `As New` *Class*, then *name*`.Member`. The class name works too:
  `Counter.Total`.
- `Public` members are seen outside the class; `Private` ones only inside.
- `Me.member` inside the class means its own member.
- `Property Get` / `Let` / `Set` work as in VB.

**VB:** there are no objects made at run time. A class has **one** set of members, shared
by every variable declared as that class, so two variables `As New Counter` share one
total. No `Set x = Nothing`, `Is`, `TypeOf`, `Class_Initialize` / `Class_Terminate`,
events (`Event`, `RaiseEvent`, `WithEvents`) or `Implements`. A class that needs several
copies of its data keeps them itself (in arrays).

### Option Class

`Option Class Resident` | `Option Class Overlay` [*Name* | `"FILE.EXT"`] | `Option Class Interrupt` *rate* | `Option Class Interrupt Frame` | `Option Class Interrupt Share` *weight*

In a `.cls` file: what kind of class it is. Without it (or `Resident`) the class is part of
the program as above.

**Overlay** (cpcmin, cpcfw, cpm): two ways, depending on `Option Memory` - RAM pages
(cpcmin, cpcfw with `Option Memory CPCExpansion`, the default there), described first, or
[one overlay area](#one-overlay-area) (cpm, and cpcmin / cpcfw with `Option Memory Small`).

With RAM pages, the class's
code is built, in the same compile, into its own file - its page (named *Name*, or the class
name when no name is given) - to run at `#4000` in a RAM page (a C page, see
[Memory](#memory)). Its variables stay in the program, so they keep their values when the
page goes. Calling one of its procedures switches its page into the window and back again
afterwards (the page that was there before - a data page the program selected stays
selected); the first call loads the file into a free C page. So a program can be bigger than
memory, a module or a level at a time.

```
' Level1.cls
Option Class Overlay Level1
Public Function Play(ByVal score As Integer) As Integer
  Banner "Level 1"            ' a Sub in the main program
  Play = 100
End Function

' Main.bas
Option RomEnable 7              ' RUN" drops AMSDOS: start it, the overlays load from disc
Option Reserve &H4000, &H4000   ' the program stays out of the window overlays run in
score = Level1.Play(0)          ' loads its page file into a RAM page, then runs Play
```

The compiler adds these members to an overlay class (so these names are taken):

| Member | Does |
|---|---|
| `Load()` | loads its file now (nothing if it is loaded): `OK` (0), a FileSystem status (`NotFound` -2, `TooBig` -8 ...), -12 (no page free) or -14 (the file is from another build) |
| `Unload()` | its page back to free; the next call loads the file again |
| `Loaded()` | True when it is in RAM |
| `Page()` | the page it is in, 0 = not loaded |
| `LocalStart()`, `LocalSize()` | its local memory: the rest of its page |
| `LocalAlloc(size)`, `LocalFree(address)` | blocks of its local memory |

- **Page files are numbered:** `PROGRAM.001`, `PROGRAM.002` ... (PROGRAM: the program's name -
  the project's name in the GUI, `NAME` in `build/`, `cli.js --name=` or the main file's name),
  in the order of the pages in the source (`Option Page` lines first, then `Option Class
  Overlay`). So two programs on one disc never write the same file. The page's name (a plain
  word, like a class name) is for the source, the lists and the messages. To choose the file
  yourself give it in quotes, with its extension: `Option Class Overlay "LEVEL1.PAG"` (a quoted
  name without an extension is a plain name, as before). The layout list (below) says which
  number each page got.
- **Every page file carries the build's stamp** (a CRC of the program, its first word): a file
  from another build of the program (an old `.001` left on the disc) is refused - `-14`.
- A call that has to load and can't prints `Overlay not loaded: Level1 (PROGRAM.001)` - the
  page and its file - why (`No RAM
  page free` / `The file didn't load` / `The file is from another build`) and `Press a key`,
  then ends the program (a program started with `RUN"` then resets). Call `Load()` first to
  handle it yourself.
- Keep the page files on the disc with the program's `.BIN`. They are binary files with an
  AMSDOS header (load address `#4000`) - AMSDOS takes a file without a header for text and
  won't load it into memory. The program must end below
  `#4000` (checked when assembling) and needs AMSDOS (`Option RomEnable 7` after `RUN"`).
- An overlay class can call the main program, resident classes and other overlay classes;
  each call puts back the page it found. On a 64K machine there is only one page, so two
  overlay classes calling each other means loading again.
- Procedures whose body is only `#asm` stay in the main program (they are keywords).
- **Page variables:** `Private Paged` *name* `As` *type* (or `Dim Paged`) in an overlay class
  puts that variable in the class's page, after its code, instead of in the program: it costs
  no main memory, and starts fresh (0, "") each time the class is loaded - right for a level's
  own data. Variables that must keep their values stay as normal ones (in the program).
  Paged variables are `Private` only: they are there only while the class's page is in the
  window, so only the class's own code can use them. Paged Strings are in the page file
  (their capacity byte goes with them); other paged variables are not in the file - they are
  cleared when it loads.
- **Local memory:** the rest of the page, after the code and page variables, is the class's
  own: `LocalStart()` and `LocalSize()` say where, and `LocalAlloc(size)` / `LocalFree(address)`
  hand out blocks of it (plain addresses, 0 = no room). Only from the class's own code (from
  anywhere else `LocalAlloc` gives 0). Copy a list node in with
  `Memory.Copy(List.Data(node), CLng(Page()) * 65536 + address, size)`.
- Not yet: one interface for several files (VB's `Implements`, for levels that swap), and
  classes built on their own for any program (like DLLs).
- Several classes can share one page, and a class can be copied into several pages:
  [Option Page](#option-page). `Option Class Overlay Name` is the short form of
  `Option Page Name = ThisClass`; two classes naming the same page share it.

#### One overlay area

On CP/M, and on cpcmin / cpcfw with `Option Memory Small` (a 64K CPC, or a program that wants
no RAM pages), there is one overlay area, `#4000-#7FFF`, and one overlay class in it at a
time. A call to a class that isn't there loads its file over the one that was. When the call
returns into another overlay class's code that was swapped out meanwhile, that class is
loaded again first. So level 2 calling level 1 loads level 1's page, and the return loads
level 2's again: calls between overlay classes cost a disc load each way. Calls from the
main program (or resident classes) to the class already in the area cost nothing extra.

The same source works both ways (`bas/overlays/`). What is different:

| | RAM pages | one overlay area |
|---|---|---|
| Classes in memory | each its own page, until `Unload()` | one, until another is called |
| `Load()` | into a free page | into the area; from code in the area: -13 (it would overwrite it) |
| `Unload()` | its page back to free | the area is empty; from code in the area: -13 |
| `Loaded()` | True when in RAM | True when it is the one in the area |
| `Page()` | its page | 0 |
| `Private Paged` | in its page, fresh at each load | ordinary variables in the program (they keep their values) |
| Local memory | until `Unload()` | fresh (one free block) at each load |
| The program | must end below `#4000` | must end below `#4000`; the heap (`Memory`, `List`) is the RAM between the program's end and `#4000` |
| Files | `PROGRAM.001` ... with an AMSDOS header | the same on the CPC; plain bytes on CP/M (next to the `.COM`) |

The compiler keeps the program and the Memory heap out of `#4000-#7FFF` for overlay
classes (as `Option Reserve &H4000, &H4000`). A file that isn't there stops the program with
`Overlay not loaded: Level1 (PROGRAM.001)` / `The file didn't load` / `Press a key`.

#### Option Page

`Option Page` *Name* | `"FILE.EXT"` [`Loaded` *n*] `=` *Class* [`,` *Class*] ...

Where each class goes, in one place (by custom in the main file): the classes listed are
built together into one file (`PROGRAM.001` ..., numbered as above; `"FILE.EXT"` instead of a
name gives the file), each at its own fixed address in it.
The page is loaded and switched in as a whole, the same way as an overlay class's page (RAM
pages, or [the overlay area](#one-overlay-area)).

```
Option Page Title   = Title
Option Page Level1  = Level1, Maths, Stars
Option Page Level2  = Level2, Maths, Stars
Option Page Credits = Credits
```

- **A class in no page is in main RAM**, as always - a class every page uses (a score, a
  print routine) goes there.
- **A class in several pages is copied into each** (`Maths`, `Stars` above): a level calls the
  copy in its own page, with no page switch. That is what copies are for - calls from inside
  the page.
- **Calls between classes of the same page switch nothing** (the call goes through a local
  entry in the page). Calls into another page switch it in, as for an overlay class. Measured
  (Z80 T states a call, more than a call to a class in main RAM): about 60 inside a page,
  about 320 with a page switch (RAM pages, page already loaded). Calls between procedures of
  one overlay class used to pay the switch too; now they are inside its page.
- **Calls from main RAM (or another page) to a copied class** go to its **home copy** - the
  first page that lists it, or the one `Option Home` *Class* `=` *Page* names. A class with no
  paged variables (every copy alike) may instead use a copy whose page is in the window at
  the time.
- **Variables:** a copied class's ordinary variables are in the program, so every copy sees the
  same ones. Its `Private Paged` variables are in each page: **each copy has its own** (with
  one overlay area paged variables are ordinary variables, so the copies share them). If one
  set must always be the one used, list the class in one page only.
- `Load()`, `Unload()`, `Loaded()` and `Page()` act on the class's page (its home page if it
  is copied): unloading a page unloads every class in it. `LocalStart()` / `LocalSize()`:
  the room after the whole page's code and paged variables.
- A page holds at most 16K (code and paged variables), checked when compiling (about) and
  when assembling (exactly). The compiler lists each page with its classes and their sizes
  (in the GUI's messages; `cli.js --layout`), and the classes in main RAM that pages call:

```
Page Level1 (PAGES.002): level1 104, maths 10 (home), stars 14 (home); paged variables 2; about 16210 bytes free
Page Level2 (PAGES.003): level2 90, maths 10 (copy), stars 14 (copy); paged variables 2; about 16224 bytes free
Main RAM, called from pages: score
```

  Assembling prints the exact sizes the same way (sjasmplus `DISPLAY` lines).
- **A class in a page can also be an interrupt class** (`Option Class Interrupt` in it): a
  driver with its own page, its state in paged variables, and a `Tick` - each Tick switches
  its page in and back, like any call from outside (about 320 T states). RAM pages only:
  with one overlay area a Tick would load the class from disc, so it is refused there.
- An `#asm` block of a copied class must not name the class's own thread labels (the block is
  in main memory, shared by the copies).
- Two programs on one disc can't clash (numbered files carry the program's name); for names you
  give yourself (`"NAME.EXT"`) `build/gendsk.sh` checks.

The example `bas/pages/` has a title, two levels sharing copied classes, credits, and a class
in main RAM that every page calls.

##### Loaded pages (the ZX Spectrum Next)

`Option Page` *Name* `Loaded` *n* `=` ... builds the page as usual - its classes' code, resolved
against the program, at `#4000` - but the program doesn't load it: it is already in RAM page *n*
when the program starts, and its class block starts out holding *n*, so a call only switches the
page into the window and jumps. Everything else is the same as any page: the stubs, calls inside a
page without a switch, copied classes and their home copies, paged variables.

**zxn** (so far the only platform): the Next has no page files (no file system yet), so every page
there is `Loaded`. Page *n* is the NEX file's bank `20 + n` (Option Memory CPCExpansion's numbering
on the Next: page 2 is bank 22; with Option NexData past 7 blocks everything moves up past the
data's banks, as the Memory class's banks do), filled by NextZXOS when it loads the NEX - nothing to copy. Its
page variables are cleared in the bank. The program needs the window kept free (`Option Reserve
&H4000, &H4000`); Option Memory CPCExpansion is chosen by itself when there are pages. At the start
the Memory class marks the pages taken (C), so `AllocPage` never hands one out.

```
Option Page Intro  Loaded 20 = Title
Option Page Stage1 Loaded 21 = Level1, Maths, Stars
Option Page Stage2 Loaded 22 = Level2, Maths, Stars
Option Reserve &H4000, &H4000
```

- *n*: 2 - 91 (banks 22 - 111: a 2MB Next); 2 - 27 on a 1MB Next. Two pages on one *n* are refused,
  and so is a bank Option NexData uses.
- `Loaded()` is True from the start. `Unload()` frees the page - the next call stops with `Overlay
  not loaded`, as there is no file to load it from. `Load()` on an unloaded page says NotSupported.
- On zxn a page without `Loaded` is refused ("on zxn a page is Option Page Name Loaded n"), and
  `Loaded` on the other platforms is refused for now.
- The banks are the Memory class's RAM pages, so its probe (on the first call into a page, or the
  first Memory call) writes a marker at each bank's first byte: a page's first word is the build
  stamp, which a Loaded page doesn't use.

**Interrupt** *rate* / **Interrupt Frame** / **Interrupt Share** *weight* (cpc, cpcmin, cpccard,
cpc9990, zxn: NTC's own interrupt handler; cpcfw: a firmware fast ticker event, as for
[Interrupt](#interrupt); msx, msxcard, msx9990, sc3000: the frame interrupt): the class's
`Sub Tick()` (no parameters - it must have one) runs *rate* times a second (1 - 300; 1 - 50 on
msx and sc3000, where there is one interrupt a frame - an NTSC machine's 60 frames make them
run a fifth faster), or once a frame (just after the vertical sync), or as its share of the
time the fixed ones leave (below), while the program does its own thing.

```
' Clock.cls
Option Class Interrupt 1
Public Seconds As Integer
Public Sub Tick()
  Seconds = Seconds + 1
End Sub
```

- Up to 16 interrupt classes. The interrupt (300 a second) only counts and marks a class as
  due; `Tick` runs at the program's next safe point, like [Interrupt](#interrupt) - so it is
  ordinary BASIC, and can use anything. Classes of the same rate take turns (they don't fall
  on the same interrupt).
- **Fixed and shared.** A class with a rate or `Frame` is *fixed*: it gets its rate, whatever
  the others do. A class with `Share` *weight* (1 - 100) is *shared*: the shared classes split
  what is left between them by weight. At an interrupt where no fixed class falls due, one
  shared class is marked due; each shared class gets *weight* turns in a row, then the next one
  does. So with `Share 1`, `Share 2` and `Share 3` the third gets three times the turns of the
  first. You choose the split: put the classes that must keep time (music, a clock, game
  movement) at a rate, and the rest (background work, an animation, a status line) as shares.
  The shares get what the fixed classes leave, so the more fixed classes fall due, the less the
  shared ones run - they slow down, they never hold up a fixed one.

```
' Music.cls - fixed: 50 a second whatever else runs
Option Class Interrupt 50
' Clouds.cls / Status.cls - shared: Clouds gets 3 turns for each 1 of Status
Option Class Interrupt Share 3
Option Class Interrupt Share 1
```

- Normal mode only: in turbo mode there are no safe points, so `Tick` waits.
- A `Tick` that is still running when it is due again runs again after it returns.
- Keep `Tick` short: it runs between the program's own statements.
- Interrupts wait while a keyword runs. Text drawing (cpc, cpcmin) lets a waiting interrupt in
  after each character, so printing doesn't hold them off; a `Frame` class counts 6
  interrupts a frame as well as watching the sync, so it keeps 50 a second when an interrupt
  is taken late.
- cpcfw: the firmware draws the text, about 3.4 ms a character (measured with the 6128 ROM),
  and a `Tick` only runs between keywords, so a `Print` of a dozen characters holds every Tick
  back for about 40 ms. A Tick that falls due twice in that time runs once: a Frame class that
  prints, with a main loop that prints too, runs about 20-25 times a second instead of 50
  (the interrupts example). The counting itself is exact (a 1 a second clock keeps time).
- Game logic can go in a `Tick` (movement at a fixed 50 a second, whatever the drawing does),
  with the main loop drawing. If the drawing reads what `Tick` changes, keep two copies and
  switch between them when `Tick` is done, so a sprite is never drawn half moved.

---

## 11. Screen and keyboard

What the console can do depends on the platform (see
[section 17](#17-platforms-and-the-console-classes)). On the CPC hardware platform the
screen is driven directly: the program sets mode 1, turns the ROMs off and clears the screen
when it starts. On the CPC firmware platform the firmware draws the text and the screen is
left as it was. On CP/M the console is a stream: text goes out, nothing can be moved back.

The console statements here are the platform's `StdIO` class underneath, and a project
can supply its own (see [Your own StdIO](#your-own-stdio)).

### Print

`Print` [*item*] [{`;` | `,`} *item*] ... [`;` | `,`]

Shows numbers and text at the cursor.

- `;` between items: nothing between them.
- `,` between items: one space.
- `;` or `,` at the end: the cursor stays on the line; otherwise a new line follows.
- `Print` on its own prints a new line.
- `?` and `Debug.Print` are the same as `Print`.
- Text that reaches the right edge carries on at the start of the next line. A line exactly
  as wide as the screen followed by a new line doesn't leave an empty line (as on the CPC).

```
Print "a"; 1; "b", 2
Print "no new line";
Print "!"
' prints: a1b 2
' prints: no new line!
```

**VB:** VB puts a space before a number that is 0 or more and one after every number,
and `,` moves to the next 14 column zone. `Option VBPrint` makes NTC BASIC do the same. In
VB, `Print` writes to a form or `Debug.Print` to the Immediate window; here both go to the
screen.

### Tab, Spc

`Tab(`*column*`)` / `Spc(`*n*`)` (in `Print`)

`Tab` moves the cursor to a column (1 = left edge) on this line. `Spc` prints *n* spaces.

```
Print "a"; Tab(10); "b"; Spc(3); "c"
' prints: a        b   c
```

### Option VBPrint

`Option VBPrint`

Print spacing as in VB: a number printed on its own gets a space before it if it is 0 or
more, and one after it (`" 5 "`, `"-3 "`); `,` moves to the next 14 column zone. Numbers
joined with `&` stay as they are.

### Input

`Input` [*prompt* {`;` | `,`}] *variable* [`,` *variable*] ...

Waits for a line typed on the keyboard, ended with Enter, and puts it into the variable.
For a number variable, the line is read as a signed whole number. With several variables,
each gets its own line. The prompt is printed first; `;` after it adds `"? "`, and `,` adds
nothing. With no prompt, `"? "` is printed.

```
Dim nm As String, age As Integer
Input "Name"; nm
Input "Age, "; age
Print nm; " is "; age
```

**VB:** VB has no `Input` statement for the keyboard (only `Input #` for files, and
`InputBox`). This is the classic BASIC `Input`.

### Cls

`Cls`

Clears the screen and puts the cursor at the top left. On a stream console (CP/M without
`Option Terminal`) it starts a new line instead.

### Locate

`Locate` *column*`,` *row*

Moves the cursor. 1, 1 is the top left. On a stream console (CP/M without
`Option Terminal`) it does nothing.

```
Cls
Locate 10, 5
Print "here"
```

**VB:** VB has no `Locate`. Note the order is column then row, as in CPC BASIC (QBasic's
`LOCATE` is row then column).

### Mode

`Mode` *number*

Sets the CPC screen mode (0 = 20 columns, 1 = 40, 2 = 80) and clears the screen. On CP/M it
does nothing.

### Inkey, Inkey$

`Inkey` / `Inkey$`

The key pressed since the last look: `Inkey` gives its code (0 if none), `Inkey$` gives it
as text ("" if none). Neither waits.

```
Do
  k$ = Inkey$
Loop While k$ = ""
Print "you pressed "; k$
```

For keys held down (games: several at once, no auto repeat) and the joysticks, see the
[Keys](#keys) class.

**VB:** these are from classic BASIC; VB uses key events.

### Frame

`Frame`

Waits for the start of the next frame flyback (50 a second on a CPC). Use it to time
animation and avoid flicker.

**VB:** not in VB (from CPC BASIC's `FRAME`).

### Beep

`Beep`

Accepted, does nothing yet (no sound driver).

---

## 12. Memory, ports and machine code

### Peek, Deek

`Peek(`*address*`)` / `Deek(`*address*`)`

The byte / the 16 bit word (low byte first) at an address.

```
Print Peek(&H4000); Deek(&H4000)
```

**VB:** not in VB. `Deek` is from other 8 bit BASICs.

### Poke, Doke

`Poke` *address*`,` *value* / `Doke` *address*`,` *value*

Writes a byte / a 16 bit word to an address.

```
Poke &HC000, 255               ' a line of pixels on the CPC screen
Doke &H8000, 1234
```

### Inp, Out

`Inp(`*port*`)` / `Out` *port*`,` *value*

Reads / writes an I/O port. The port is 16 bits (on the CPC the high byte selects the
device).

```
Out &H7F00, &H8D               ' gate array: mode 1, ROMs off
```

**VB:** not in VB (from QBasic / CPC BASIC).

### Call (machine code)

`Call` *address*

Runs machine code at *address* as a keyword: when it starts, SP points into the thread and
interrupts are off. It must end with `ret` in turbo mode and `jp ntc_xn` in normal mode, and
must not use `call` or `push` unless it first switches to the real stack (see
[section 14](#14-inline-assembly)).

```
Call &HA000
```

For machine code written in the program, `#asm` is easier.

### Ticks, Timer

`Ticks` / `Timer`

A tick count:

| Platform | Ticks |
|---|---|
| CPC hardware | interrupts, 300 a second, moving only in normal mode (turbo has no interrupts) |
| CPC firmware | the firmware's clock, 300 a second, in both modes |
| CP/M | always 0 (no clock to share) |
| test harness | 300 a second of emulated time |
| MSX (msx, msxcard, msx9990) | the BIOS's JIFFY: the frames, 50 a second (60 on an NTSC MSX), moving while interrupts get in (normal mode, and while waiting for a key or `Frame`) |
| SC-3000 | the frames, 50 a second (60 on an NTSC machine), as on the MSX |
| CPC with a card (cpccard, cpc9990) | as CPC hardware |

`System.TicksPerSecond` says which: 0 means there is no clock.

```
t = Ticks
' ... work ...
Print "took "; Ticks - t; " ticks"
```

**VB:** VB's `Timer` is seconds since midnight, as a fraction.

### Interrupt

`Interrupt` *SubName* / `Interrupt Off`

Runs a Sub (with no parameters) after interrupts: the interrupt only marks it as due, and
the program calls it at the next safe point. When it returns, it can run again.
`Interrupt Off` stops it. Normal mode only, on the CPC platforms: cpc and cpcmin (NTC's own
interrupt handler) and cpcfw (a firmware fast ticker event, 300 a second, marks it due - the
firmware keeps its own handler for keys, sound and AMSDOS). `System.HasHook` says whether it
works. On cpcfw the event's block sits at `#A5F0`, so the program and its arrays must end
below it, and `Memory.Top()` is `#A5F0`. A cpcfw program that uses neither `Interrupt` nor
interrupt classes sets no event and keeps the RAM up to `#A600`.

```
Dim beats As Integer
Interrupt Beat
' ... the program runs; Beat runs after interrupts ...
Interrupt Off
End

Sub Beat()
  beats = beats + 1
End Sub
```

For Subs that run at a set rate, see interrupt classes ([Option Class](#option-class)).

**VB:** not in VB (it is like CPC BASIC's `EVERY` / `AFTER`).

### DoEvents

`DoEvents`

A safe point: in normal mode, interrupts get in here. In turbo mode it does nothing. Use it
in long straight runs of code that need interrupts to keep up.

**VB:** in VB it lets Windows handle other events.

---

## 13. Speed: turbo and normal mode

The same program runs in two modes:

| | Turbo | Normal |
|---|---|---|
| Interrupts | off the whole time | let in at safe points |
| Straight line code | full speed | full speed |
| Jumps, loops, calls | full speed | a little slower (a safe point at each) |
| `Ticks`, `Interrupt`, key and frame waits with interrupts | no | yes |

How much slower normal mode is depends on the program: from about 2% (division) to 55%
(an empty loop); a sieve or a sort 25-40%. A program whose time goes into library keywords and
`#asm` gains nothing from turbo: the 3D demo (`bas/cube3d`, 93% of its time in Z80 code) runs
7.7 frames a second in normal mode and 7.8 in turbo - keep normal mode there, and interrupts,
`Ticks` and interrupt classes keep working. `NTC.md` section 3 has the measurements, with
NTC compared to Small C, BBC BASIC and hand-written Z80.

The compiler knows the mode at every line, and a procedure called from both modes is
compiled twice.

### Option Turbo

`Option Turbo` / `Option Turbo Off`

The program starts in turbo mode / in normal mode (the default unless the build says
otherwise).

### Option NoTurbo

`Option NoTurbo`

Normal mode only, to save memory. A procedure called in both modes is normally built twice
(a turbo copy and a normal copy), and so are the library's branch keywords; with
`Option NoTurbo` there is one copy of each, in normal mode. `Turbo On` and `Turbo Off` then do
nothing (a warning says so), and `Option Turbo` or the build's turbo setting is ignored. The
shell sort example (`bas/shellsort.bas`, which switches mode at run time) comes out 314 bytes
smaller. Interrupts keep getting in at safe points everywhere, so it suits programs with
interrupt classes too.

### Turbo On, Turbo Off

`Turbo On` / `Turbo Off`

Switch mode while running. A block (`If`, loop, `Select`) and a procedure must end in the
mode they started in, so the mode is always known. When a part of a block doesn't (`Turbo On`
... `Turbo Off` in a program that started in turbo mode), the compiler switches back to the
block's mode at its end and gives a warning:

```
If fast Then
  Turbo On
  SortAll
  Turbo Off
Else
  SortAll
End If
```

**VB:** not in VB.

---

## 14. Inline assembly

### #asm ... #endasm

```
#asm
  Z80 assembly lines
#endasm
```

Z80 code written in the program. Each block becomes one keyword: the thread gets one word
and the code goes with the compiler's other code. The compiler adds the `ret` at the end;
a `ret` in the middle leaves early.

```
Dim n As Integer
n = 20
#asm
            ld hl, ({n})
            inc hl
            ld ({n}), hl
#endasm
Print n
' prints: 21
```

In the block:

- `{name}` is replaced by the label of a variable, parameter, local or array (a dynamic
  array or array parameter gives its descriptor), the value of a `Const`, or a BASIC label
  or line number (`ld sp, {label}` then `ret` jumps there). `{result}` is the function's
  result. `{p.x}` reaches a field of a Type.
- Always use `{name}` for BASIC names, never the label the compiler makes (`var_n`); those
  can change when the BASIC changes, `{name}` can't go stale. A hand written generated label
  gives a warning.
- Labels in a block are local to it. A label written `@name:` (sjasmplus's global label) is
  not: every block can name it (`name`, without the `@`), so one block's routine or value can
  be reached from another (`@fl_peek_g: EQU fl_peek` in one block, `call fl_peek_g` in
  another). It must be the one definition in the program.
- Library routines the block names are linked in.
- The rules of the run time apply: SP is the thread, so no `call` / `push` unless SP is
  first switched to the real stack (`ld (ntc_ip), sp` / `ld sp, (ntc_csp)` / ... /
  `ld sp, (ntc_ip)`); no register keeps its value between keywords; interrupts are off.
- A block that loads SP with a label or HL (`ld sp, {label}`, `ld sp, hl`) is a jump; the
  compiler makes a normal mode copy of it, where `ret` becomes `jp ntc_xn`. Switching to the
  real stack and back (`ld sp, (ntc_csp)` ... `ld sp, (saved)`) is not a jump: the block's own
  `call` / `ret` on the real stack stay as written, so it can have subroutines (see
  `bas/cube3d/Vector3D.cls`).

Each asm line carries its BASIC file and line number as a comment, so an assembler error
points back to the source. Every compile also makes a map of the labels it generated
(`Save .map` in the GUI).

**VB:** not in VB.

### Asm keyword procedures

A Sub or Function whose whole body is one `#asm` block, and which doesn't use `{param}` or
`{result}`, becomes a keyword itself. It is called straight from the thread with its
argument addresses, and a Function gets the address for its result last:

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

Print Add3(10)
' prints: 13
```

`Print Add3(10)` compiles to `dw fn_add3, lit_10, var_add3_add3`, and `a = Add3(5)` stores
straight into `a`. There is no procedure call stub, no copying and no saved return point.

- Every argument arrives as an address, in order:

  | Parameter | The address points at |
  |---|---|
  | Integer, Byte, Boolean | its 2 byte value |
  | Long | its 4 bytes, low byte first |
  | String | its first character (ends with a 0 byte) |
  | array | its descriptor |
  | Type | one address per field |

- ByVal and ByRef look the same. ByRef means the block may write through the address (a
  literal or expression passed ByRef goes through a temporary first).
- A Function gets the result address last (Integer 2 bytes, Long 4, String a buffer). A Sub
  gets none.
- The block must pop exactly the words the call passes, and not move SP otherwise.
- `{Const}`, `{globalvar}` and `{label}` still work.
- These stay ordinary procedures: a body that also has BASIC lines, a block that uses
  `{param}` or `{result}`, a block with `ld sp,`, a procedure used with `AddressOf` or
  `Interrupt`, and Property procedures.

---

## 15. Diagnostics

### Error

`Error` *text*

Prints `Error: text (file line n)` and stops the program. For conditions that should never
happen.

```
If count < 0 Then Error "count went negative"
```

**VB:** VB's `Error n` raises a run time error that `On Error` can catch. Here there is
nothing to catch it: it reports and stops.

### Debug.Assert

`Debug.Assert` *condition*

If the condition is false, prints `Assert failed: condition (file line n)` and stops.

```
Debug.Assert total >= 0
```

**VB:** VB drops `Debug.Assert` from a built program; NTC BASIC keeps it.

### Break

`Break` [*name*]

Puts a breakpoint marker in the program: `dw bp_name` in the thread, which does nothing
but can be stopped at in an emulator's or monitor's debugger. Without a name it is
`bp_line<n>`.

```
Break loop_top
```

**VB:** not in VB.

### Warnings

Warnings don't stop the build. Now: a Function called as a statement ("the result of F is
not used"), and a generated label written by hand in `#asm`.

---

## 16. Compiler directives and options

### Option Explicit

`Option Explicit`

Every variable in this module must be declared before use.

### Option Base, Option Compare, Option VBPrint, Option Turbo

See [Option Base](#option-base), [Option Compare Text](#option-compare-text),
[Option VBPrint](#option-vbprint), [Option Turbo](#option-turbo). `Option Terminal` is
below.

### Option Terminal

`Option Terminal` { `VT52` | `ANSI` | `None` }

CP/M only. Tells the program which codes the terminal understands, so `Cls` clears and
`Locate` moves the cursor:

- `VT52`: Amstrad CP/M on the CPC and PCW, and many other machines (`ESC E`, `ESC Y`);
- `ANSI`: most CP/M emulators and modern terminals (`ESC [2J`, `ESC [row;colH`);
- `None` (the default): a stream - `Cls` starts a new line, `Locate` does nothing.

With a terminal set, `StdIO.CanPosition` and `StdIO.CanClear` are True and `StdIO.Rows` is
24. On other platforms it gives a warning and does nothing.

```
Option Terminal VT52
Cls
Locate 10, 3
Print "here"
```

**VB:** not in VB.

### Option Buffer

`Option Buffer` *address* [`,` *size*]  /  `Option Buffer Size` *size*

The library's 2K buffer - the one FileSystem's files (the CPC firmware's cassette buffer) and
`Memory.Copy` (page to page) use - at that address instead of inside the program. The program
gets 2K smaller, and the range is kept out of like an `Option Reserve` range. Use free main RAM
outside the program and outside the `#4000` window (a copy between pages goes through it),
e.g. `Option Buffer &H8000` on cpcfw. With `Option Library ROM` it does nothing (the 2K buffer
is the ROM's own, in its RAM) and its range is free for the program.

A size (32 - 2048) makes the buffer smaller: `Memory.Copy` then copies that much at a time
(PRIMAL's copy buffer is 128 bytes: a page-to-page copy is still `ldir`s, a little more
switching). Only for a program that copies but has no files: FileSystem on a CPC (the
firmware's cassette buffer) and `List.Sort` need the whole 2K, and the assembly stops with a
message if the buffer is smaller. `Option Buffer Size 128` keeps it in the program;
`Option Buffer &H8000, 128` puts it there.

### Option Reserve

`Option Reserve` *start*`,` *size* [`,` *start*`,` *size*] ...

Memory the program must keep out of: a screen, an area that `FileSystem.Load` fills (a
level, graphics), firmware RAM, a buffer. Numbers (`&HC000`, `#C000`, `49152`), as many
pairs as needed, in any module. When the program is assembled, it is checked against each
range: if the program (its code, thread, library and variables, from the org to the end)
reaches into one, the assembler stops with

`the program reaches into Option Reserve #8000-#BFFF (main.bas line 1)`

and the fix is a smaller program, a different range or a different org.

```
Option Reserve &H8000, &H4000      ' #8000-#BFFF: the level loaded from disc
r = FileSystem.Load("LEVEL1.DAT", &H8000, &H4000)
```

The program is built round a reserved range above its org: it starts at the org and goes up,
and when the next part of it (a procedure's thread, a library section, the variables, the
strings) would reach into the range, that part and the rest go on after it. The arrays and the
Memory class's tables go after it too. So a program with `Option Reserve &H4000, &H4000` (a
second screen, the RAM page window) can be bigger than 16K: it fills `#0040-#3FFF`, then
carries on at `#8000`. The file holds the hole as zeros (16K more to load). A range below the
org, or one the program never reaches, changes nothing. On the `cpc` platform the font copy
code goes to #C000 for a moment when the screen is first used (a warning says so when a
range covers #C000).

**VB:** not in VB.

### Option HighCode, Option Place

`Option HighCode` (cpcfw only, with `Option Reserve &H4000, &H4000`): the program's code may also
go in `#C000-#FFFF`, and the screen moves to `#4000` (main RAM's page 1: the CRTC shows main RAM
whatever the CPU has paged in there, so the window still works). The code that doesn't fit
below `#4000` is put in the file at `#4000-#7FFF` - round any `; @window` data, at the same
offsets - and the start code copies `#4000-#7FFF` up to `#C000` and calls SCR SET BASE before the
program runs. The layout:

| | |
|---|---|
| `#0040-#3FFF` | the start code, the keyword library's code, the `Option Place` classes, then as much of the rest as fits |
| `#C000-#FFFF` | the rest of the code (procedures, other classes' `#asm`) |
| `#8000` on | the variables, strings, the library's data, code that didn't fit up there, then the arrays and the Memory class's tables |

`Option Place` *class* [`,` *class*] ...: those classes' code (their procedures and `#asm`) never
goes to `#C000-#FFFF` - for code that runs while something else is there: a ROM selected at
`#C000` (KL ROM SELECT), a bank's page paged in at `#C000` (RAM layout 1). Clear the screen
(`Mode`, `Cls`) only after window data in `#4000-#7FFF` has been copied out: the screen is there
now. Not with `Library: ROM` (the keyword ROM is at `#C000`).

```
Option Reserve &H4000, &H4000
Option HighCode
Option Place Hyp, Ent
```

**VB:** not in VB.

### Option NexData

`Option NexData "`*FILE*`",` *blocks*

The ZX Spectrum Next (`zxn`) only: *FILE*'s first *blocks* x 16K go into the NEX file, in the
Next's 16K banks 1-4, 6, 7, 11, then 22-111 (97 at most; a bank past 47 makes the NEX ask for a
2MB Next). NextZXOS loads them with the program, so there is nothing to read at run time. The
assembler reads *FILE* (next to the `.asm`): it must hold all the blocks. The program finds them at
`ntc_nexdata` (`#asm`): the count, then each block's bank; `zxn_sel` (HL = a bank, 0 = the
program's own pages) puts one in `#4000-#7FFF`, as a CPC program puts a RAM page in its window -
keep the program out of that range (`Option Reserve &H4000, &H4000`).

```
Option NexData "AUCKLAND.DAT", 94     ' bas/auckland on the Next
```

### Option RomEnable

`Option RomEnable All` / `Option RomEnable` *rom* [`,` *rom*] ...

CPC firmware platforms (`cpcfw`, `cpcmin`) only. `RUN"NAME` of a binary resets the firmware, and the
background ROMs - AMSDOS (ROM 7) and any others - are dropped. With this option the program
starts them again before anything else: `All` starts every background ROM (KL ROM WALK), a
list starts those ROM numbers (KL INIT BACK). The ROMs take their RAM from `#ABFF` down, so
the program must end below `#A600` (checked when assembling). If the ROMs started take more
than AMSDOS's `#A700`-`#ABFF` (several ROMs: an IDE or SD interface's beside AMSDOS), cpcfw
moves its top under their RAM - the interrupt event block, and with it the top of free RAM
(the heap, the Memory class's tables: fewer pages if they don't fit) - and stops only when the
program and its arrays reach their RAM: "The ROMs' RAM reaches down to #xxxx: no room for this
program". cpcmin and Library: ROM programs (the keyword ROM's RAM is fixed below `#A5F0`) need
the ROMs to stay at `#A600` and above, else the same message. If the ROMs are still running
(the program was loaded from BASIC and CALLed), nothing is started again.

Without the option nothing is started: a program started with `RUN"` has no AMSDOS (files
go to tape); one CALLed from BASIC keeps whatever was running.

```
Option RomEnable 7          ' AMSDOS: FileSystem.Load / Save go to disc after RUN"
```

On other platforms it gives a warning and does nothing.

**VB:** not in VB.

### Option NoRomDisc

`Option NoRomDisc`

CPC firmware platforms (`cpcfw`, `cpcmin`): `FileSystem` without the ROMDISC (volume R) - its
methods go straight to the disc or tape, and the ROMDISC's code (about 1.1K) is left out.
`Capability("ROMDISC")` gives 0; `Exists` and `Size` give `NotSupported`, `DirEntry` `""`.
For a program short of room that doesn't read files from ROMs (CyborgOS). Elsewhere it does
nothing.

**VB:** not in VB.

### Option Flavour

`Option Flavour JS` / `Option Flavour VB5` (in a JS file: `//# Option Flavour JS`)

On a file's first line: the syntax that file is written in. `VB5` (everything in this guide)
is the default; a file named `.js` is JS without the line. Files of both flavours mix in one
project: a VB main can use a JS class and the other way round. A JS file is turned into VB5
text, line for line, and compiled like any other module (a flavour preprocessor), so messages
name the JS file and line.

The JS flavour is a JS syntax over NTC (as JSCC does it), not a JavaScript engine: ES5 / ES6
forms that map onto what NTC has. The full table, and what comes later, is in
`docs/js_flavour.md`. In this first version:

```
//# Option Flavour JS
const MAX = 10;
let total = 0;            //#long
let squares = new Array(MAX);

function square(n)
{
	return n * n;
}

for (let i = 0; i < MAX; i++)
{
	squares[i] = square(i);
	total += squares[i];
}
console.log(`total ${total}`);
```

- **Variables:** `let` / `var` / `const`; the type from the start value (text: String, else
  Integer) or a hint after the line: `//#long`, `//#byte`, `//#bool`, `//#string`,
  `//#string*20`, `//#stringmax 80`. Arrays: `new Array(n)` (0 .. n-1), `new Array(n, m)`.
  Names ignore case.
- **Functions:** `function name(a, b = 5)`; a `return` with a value makes it a Function (its
  type from what it returns, or `//#long` after the `)`); a parameter used as text is a String,
  else Integer, or `/*#long*/` / `/*#byref*/` after it. `export function` = Public.
- **Flow:** `if` / `else if` / `else`, `while`, `for (;;)` (a counting one becomes For / Next),
  `break`, `continue`, `switch` (each `case` ends with `break`), `return`.
- **Classes:** one `class Name { }` per file (ES6). Fields `x = 0;` (Public), `#x = 0;`
  (Private), methods, `#method()`, `get x()` / `set x(v)`, `this.x`. `let c = new Name();` is a
  second name for the class's one set of members (no constructors: give the class a method to
  set it up).
- **Expressions:** the JS operators (`===` / `==` are `=`, `&&` / `||` work out both sides, `%`,
  `**`, `? :`, `<<` / `>>` by a number), template text, `s.length`, `toUpperCase`, `substr`,
  `indexOf`, `charCodeAt`, `String.fromCharCode`, `Math.abs` ... and
  `Math.floor(Math.random() * n)` (= `Rnd(n)`). Whole numbers only: `/` divides whole numbers.
- **Statements:** `console.log(a, b)` (= `Print a; b`), `print(a)` (no new line), `cls()`,
  `locate(x, y)`, `mode(n)`, `poke(a, v)`, `peek(a)`, `inkey()`, `exit()` ...
- **NTC lines stay comments,** so the file is still valid JS: `//# Turbo On`,
  `//# Option Page ...`, `//# #If NTC_CPC Then` on a line of their own; inline assembly as
  `/* #asm ... */`.
- **Refused with a message:** closures and arrow functions, `do ... while`, `try` / `catch`,
  object and array literals, `extends`, constructors, `null`, floating point, `switch` falling
  through, a function inside a function.

**The Locomotive BASIC flavour** (`'# Option Flavour Locomotive` / `REM #Option Flavour
Locomotive` on the first line, or a `.loc` file) takes the CPC's own BASIC as typed in: line
numbers, `:` between statements, whole numbers only. A line NTC can't do (`a = 3 * COS(x)`,
`INK 1, 24`, `DEFINT a-z`) becomes a comment and a warning - the program compiles without it,
and the warnings name the lines. The full table is in `docs/locomotive_flavour.md`; in this
first version:

```
10 DIM sc(5), nm$(5)
20 total = 0 '#long
30 FOR i = 1 TO 5: READ nm$(i), sc(i): total = total + sc(i): NEXT i
40 DEF FNdbl(x) = x * 2
50 PRINT "Total"; total; FNdbl(21)
60 GOSUB 1000: END
1000 PRINT "in a GOSUB": RETURN
2000 DATA Ann, 50, Bob, 60, "Cy, Jr", 70, Dee, 80, Eve, 90
```

- `a`, `a%` and `a$` are three variables (renamed in the VB text when they clash: `a`, `a_i`,
  `a_s`); a plain name is an Integer; `'#long` (`'#byte` ...) after a line is a type hint, also on
  `DIM`. Arrays used without `DIM` are `DIM name(10)`.
- `PRINT` spaces numbers as the CPC does (`Option VBPrint`); `INPUT`, `LINE INPUT`, `INKEY$`,
  `CLS`, `MODE`, `LOCATE`, `GOTO` / `GOSUB` / `ON ... GOTO / GOSUB`, `IF ... THEN line / ELSE`, `FOR`
  / `NEXT i, j`, `WHILE` / `WEND`, `DATA` / `READ` / `RESTORE n`, `DEF FN`, `SWAP`, `MID$(a$, i, n) =`,
  `MAX` / `MIN`, `BIN$`, `HEX$(n, d)`, `INT(RND * n)`, `TIME`, `PEEK` / `POKE` / `INP` / `OUT` / `CALL`,
  `WAIT`, `LOAD` / `SAVE` (binary), `END` / `STOP`.
- Warnings (left out): real numbers and `SIN` / `COS` ..., `DEFINT` / `DEFSTR`, colours (`INK`,
  `PEN`, `PAPER`, `BORDER`), graphics, sound, `EVERY` / `AFTER`, streams and files other than
  `LOAD` / `SAVE`, error trapping, editor commands. Most will come later as classes.

`test/cli.js file.js --vb` (or `file.loc`) shows the VB5 text a file becomes; only the line
numbers something jumps to are kept.

**VB:** not in VB.

### Option Library

`Option Library ROM` / `Option Library RAM`

The CPC platforms (`cpc`, `cpcmin`, `cpcfw`). With `ROM`, the keyword library is not put
into the program: it is in a ROM, one per platform:

| Platform | ROM name | File |
|---|---|---|
| `cpc` | NTC CPC | `build/rom/NTCCPC.ROM` |
| `cpcmin` | NTC CPCMIN | `build/rom/NTCMIN.ROM` |
| `cpcfw` | NTC CPCFW | `build/rom/NTCFW.ROM` |

Each is 16K with an AMSDOS header (16512 bytes), for a ROM board, an M4 / ROM emulator or
WinAPE's ROM slots. When a platform's library no longer fits in 16K, it becomes a **set**:
`NTCMIN.ROM` (the main one) plus `NTCMIN2.ROM`, `NTCMIN3.ROM` ... (see *ROM sets* below);
today each platform's library fits in one. They have different names, so all three can be fitted at once; a
program finds the one for its platform. The ROMs are not interchangeable: the platforms
share the keyword core, but screen, keys and interrupts are different code (cpcfw goes
through the firmware, cpc and cpcmin drive the hardware themselves).

The program gets a small jump block instead of the library: one `jp` for each library
routine it uses. Each entry starts as `jp <number>`. At the start the program looks for the
ROM in slots 0-31 (KL ROM SELECT - the firmware is still there at that point on every CPC
platform) and calls the ROM's patcher with the jump block, which puts the ROM's address in
place of each number. The rest of the program is built exactly as before. `RAM` (the
default) puts the library in the program; the GUI's **Library** list has the same choice
(**in ROM (CPC)**), and the source wins.

```
Option Library ROM
Print "Hello"          ' a few hundred bytes: the jump block, the start code, the program
```

- **Smaller programs.** On cpcfw GUESS goes from 1539 bytes to 661, SIEVE from 1588 to 680,
  the pages demo from 7819 to 1285 (cube3d: 13079 to 5344). The difference is the library code.
- **The start code is only on disc.** Finding the ROM set and patching the jump block (about
  460 bytes with its messages) runs once, so it goes last in the program and the arrays (and
  the Memory class's tables) start on it: they take that RAM back once it has run. `Print
  "Hello"` is 529 bytes on disc, and its free RAM starts after the first 73.
- **Slower.** Every keyword goes through the jump block: 10 T more each time. On short
  keywords that is a lot - the sieve timing takes about 25% longer.
- **Turbo still works.** The ROM holds both copies of every keyword (turbo and normal), so
  `Turbo On` / `Off` cost no program RAM for the library. `Option NoTurbo` still saves the
  program's own second copies: ROM + NoTurbo is the smallest program, RAM library with
  both modes the fastest (shellsort on cpcfw: 1673 bytes / 14.1M T against 3111 bytes /
  8.5M T; ROM with both modes: 1895 bytes / 10.1M T).
- **The ROM's RAM.** The ROM keeps its variables in `#8800-#A5EF`, so the program and its
  arrays must end below `#8800` (checked when assembling), and the Memory class's heap stops
  there. A program CALLed from BASIC needs `MEMORY &87FF` (or lower) first, or BASIC's strings
  and the ROM's variables overwrite each other. `End` puts the caller's ROM selection back.
  A program built round `Option Reserve &H4000, &H4000` (its code from #0040 and on from
  #8000) works with the ROM too: the Memory class sees its free RAM starts above the window
  and puts its tables there, up to #8800 - so give it `Option Memory CPCExpansion` few enough
  pages (3 bytes each) to fit. `#If NTC_LIBRARY_ROM Then` round two `Option Memory` lines
  picks a smaller number for the ROM build only.
- **The screen.** The upper ROM covers the screen's RAM at `#C000` for reading. On cpc and
  cpcmin the ROM stays on and NTC turns it off only while it reads the screen (scroll, Cls,
  Graphics), from code it runs in RAM; on cpcfw the Graphics routines do the same through
  the firmware.
- **Strings up to 255.** The ROM's buffers are built for 255 characters, so the program's
  string temporaries are too (more RAM for programs with many of them).
- **Not found.** Without the ROM the program prints `ROM NTC CPCFW (NTCFW.ROM) not found`
  (its own platform's name); with an older ROM that hasn't a routine the program uses, `ROM
  NTC CPCFW too old: no routine #nnnn`. Then it waits for a key and goes back.
- **The ROMs can change.** Numbers never change: each ROM's registry
  (`src/asm/ntc_rom_<platform>.txt`) only grows. A new ROM can move every routine and fix
  anything inside - programs built before still work. Variables keep fixed addresses.
- **#asm.** Inline assembly can use the library routines and variables in the registry
  (what the compiler's own code and the platform classes use: section names, `kw_...`,
  `gfx_...`, `ntc_csp` and the like). Anything else in the library is the ROM's own and
  stops the compile ("the cpcfw ROM has no ...").
- Firmware and AMSDOS calls made from the ROM come back to it (cpcfw, and cpcmin's file
  calls), and cpcfw's interrupt event runs in it.
- **Graphics is not in the ROM.** A program that uses `Graphics` carries that code itself, so
  other graphics classes can sit beside it later; it turns the ROM off around its screen work
  as before. cpcmin's sequential-file code is not in its ROM either (the program carries it).

**ROM sets.** The keyword ROMs are built as one *set* per platform: a main ROM, and as many
more as the library needs, all from one build (they find each other by the set's stamp). The
program's start code finds the main ROM, then the rest of its set, in any slots - fit them
where there is room (the main one need not be first). Missing one: `ROM NTCMIN<n>.ROM not found: n = #0002` (its
number, the main ROM being 1).

- The main ROM holds the keywords and everything a keyword reaches directly. Only real stack
  code - Memory, List and the like - moves to the other ROMs.
- A call into another ROM of the set is a *far call* through RAM (always in sight, whichever
  ROM is in): it selects the other ROM, calls, selects the first one again - about 200 T
  states, registers and flags passed both ways. A program's jump block entry for a routine in
  another ROM points at its far call, so programs don't change: a program built for a one-ROM
  set runs with a three-ROM set of a later build, and the other way round.
- The sections that call each other a lot stay together in one ROM (Memory and List go
  together), so a far call happens once per method call, not once per byte.
- cpc and cpcmin select the ROM straight on the hardware (`#DFxx`); their interrupt handler
  puts the main ROM in for the interrupt classes and the ROM that was in back after. cpcfw goes
  through the firmware (KL ROM SELECT), so the firmware's own record of the ROM in - which its
  events put back after their far calls - stays right.
- Each far call stub takes 10 bytes of the ROM's RAM (`#8800-#93FF`).

**VB:** not in VB.

### Option PressAnyKeyOnEnd

`Option PressAnyKeyOnEnd` [*"message"*]

At the program's end - `End` (anywhere, in a Sub too), `Error`, a failed `Debug.Assert`, or the
last line - shows the message on a line of its own and waits for a key, then ends. Without a
message: `Press any key`. A program started with `RUN"NAME` from AMSDOS resets the machine when
it ends, and the screen goes with it: this keeps it until a key, without a "press a key" in
every program.

```
Option PressAnyKeyOnEnd "Done - press a key"
Print "Hello"
```

In the Locomotive BASIC flavour: `'# Option PressAnyKeyOnEnd "Press a key"` on a line of its own;
in the JS flavour: `//# Option PressAnyKeyOnEnd "Press a key"`. Every example in `bas/` has it.

**VB:** not in VB.

### Option Org

`Option Org` *address*

Where the program is built to run: the `org` of the assembly. Each platform has its own
(`#0040` on the CPC, `#0100` for CP/M and CyborgOS, `#0000` for Bare Metal) and that is right
for a program loaded the platform's way; `Option Org` is for the others - a ROM, a program a
loader of your own puts at a fixed address, a Bare Metal board whose RAM starts elsewhere.
`cli.js --org=#8000` does the same from the command line.

```
Option Org &H8000                  ' built to run from #8000
```

### Option Stack

`Option Stack` *address*

Where the program's stack starts: it grows down from *address*. Without it the program keeps
the stack it was started with (the firmware's, below `#C000`, on the CPC; its own on CP/M).
Use it to free memory for the program - on the `cpc` platform, with no firmware, everything
from `#0040` up to the stack is the program's - or to put the stack in a reserved area:

```
Option Reserve &H3F00, &H100       ' #3F00-#3FFF: the stack, nothing else goes there
Option Stack &H4000                ' grows down from #3FFF
```

NTC itself needs only a little stack (the start code, the interrupt handler, firmware and
BDOS calls). `End` still returns to whatever started the program: the caller's stack is
kept and switched back to. The address must be below the program's start or at least 64
bytes above its end (checked when assembling). On `cpcfw` a stack in `#A600-#BFFF` (the
firmware's and AMSDOS's RAM) gives a warning.

**The order of options.** All `Option` lines are read first, wherever they are, and the
program then starts in a fixed order: `Option Stack` (the stack is set), `Option
RomEnable` (the ROMs are started, using that stack), then the program. `Option Reserve` is
a check made when assembling.

**VB:** not in VB.

### Option Memory

`Option Memory Small` | `Option Memory CPCExpansion` [*maxpages*]

How the [Memory](#memory) class reaches RAM. Decided when compiling: only that scheme's code
is in the program, and the class's methods are the same either way, so a program builds with
either.

| Scheme | What | Where |
|---|---|---|
| `CPCExpansion` | 16K pages through the `#4000-#7FFF` window, up to a 4MB expansion (257 pages); a heap in D pages | cpc, cpcmin, cpcfw (the default there) |
| `Small` | no paging: one heap over the free main RAM | every platform (the default on cpm and test) |

*maxpages* (1 - 257, `CPCExpansion` only) is the most pages the class looks for: `5` for a
6128, `33` for a 512K expansion, `1` for main RAM only. It also shrinks the class's fixed data
(about 190 bytes at 257). `CPCExpansion` on cpm or test is an error.

`Small` is the least code (about 900 bytes against 2,100 for `CPCExpansion`): for a program
that only wants `Alloc` / `Free`, or for a 64K machine.

Overlay classes ([Option Class](#option-class)) follow the scheme: a RAM page each with
`CPCExpansion`, [one overlay area](#one-overlay-area) at `#4000` with `Small`.

### Option ClassSize

`Option ClassSize` *kilobytes*

Accepted, not checked yet. It is for keeping a class's code within a size, so classes can be
used as banking units.

### #Const

`#Const` *name* `=` *value*

A constant for `#If`.

### #If ... #End If

```
#If condition Then
  ...
[#ElseIf condition Then
  ...]
[#Else
  ...]
#End If
```

Compiles one part and skips the others. Useful to keep VB and NTC versions of a routine in
one file.

```
#If NTC Then
  Print "built by NTC BASIC"
#Else
  Debug.Print "built by VB"
#End If
```

NTC BASIC defines two constants itself: `NTC`, and `NTC_` plus the platform name
(`NTC_CPC`, `NTC_CPCFW`, `NTC_CPM`, `NTC_CYBORGOS` - with `NTC_CPM` as well, a slot being
CP/M -, `NTC_BAREMETAL`, `NTC_TEST`, `NTC_ZXN`). `cli.js --const=NAME` (or
`--const=NAME=value`) defines one more for that build (`#If DEMO Then`). With `Option Terminal` it also defines
`NTC_TERM_VT52` or `NTC_TERM_ANSI`, and `NTC_TERM_POS`. VB doesn't have them, so in VB they
are 0 and the `#Else` part is used.

```
#If NTC_CPM Then
  Print "running under CP/M"
#End If
```

---

## 17. Platforms and the console classes

### Platforms

| Platform | Name | Program | Text | Console |
|---|---|---|---|---|
| Amstrad CPC, no firmware | `cpc` | a binary at `#0040` (`RUN"name` from AMSDOS), ROMs off, own interrupt handler; no firmware at all - every byte from `#0040` to the stack is the program's; files from a ROMDISC only | drawn by the program, with the CPC's own font (copied from the ROM at start) | full screen, keys from the matrix |
| Amstrad CPC, minimal firmware | `cpcmin` | as `cpc` (own screen, keys, interrupts), but the firmware is kept alive (its RAM `#A700-#BFFF` left alone) and handed back for each firmware call: discs and tape (`FileSystem`), other ROMs' commands (`System.Command`) | as `cpc` | as `cpc` |
| Amstrad CPC, full firmware | `cpcfw` | a binary at `#0040` (`RUN"name`), firmware left running (AMSDOS, RSXs, windows) | firmware `TXT OUTPUT` | full screen, firmware keys |
| CP/M 2.2 / 3 | `cpm` | a `.COM` file at `#0100`, ends with a warm boot | BDOS direct console I/O | a stream, or 80 x 24 with [Option Terminal](#option-terminal) |
| CyborgOS | `cyborgos` | a program in a slot of the CyborgOS hypervisor (Amstrad CPC, ZX Spectrum Next): the `cpm` platform - a slot is CP/M 2.2 - plus what CyborgOS adds. The output is a `.CYB` (the program with its AMSDOS header; the same file runs on both machines). `CybSys` is a platform class: the hypervisor's services (the slot, the clock, claims, ports, the drive paths, `Host()` - which machine it is). `#If NTC_CYBORGOS` (and `NTC_CPM`) | BDOS, as `cpm` | 80 columns, VT52 codes: `Option Terminal VT52` is the default |
| Bare Metal | `baremetal` | a machine NTC BASIC doesn't know: built from its org (`#0000`, or [Option Org](#option-org)), nothing set up or assumed. The platform routines (`asm/ntc_plat_baremetal.asm`: a character out, a key in, the clock ...) and the platform classes (`StdIO`, `System`, `FileSystem` ...) are empty ones to fill in for your machine; a copy of a class in the project replaces the platform's. Build with `Option Turbo` unless you put an interrupt handler at `#0038` | yours to write | yours to write |
| Test harness | `test` | for the emulator in `test/ntcrun.py` | I/O ports | 40 x 25, like CPC mode 1 |
| MSX | `msx` | a cartridge ROM, `NAME.ROM` (16K or 32K at `#4000`, see [Cartridge ROMs](#cartridge-roms-msx-sc3000)); the BIOS stays (its keys, its interrupt); `End` goes back to the BIOS (MSX-BASIC). `#If NTC_MSX` | the MSX's own video chip (TMS9918 on an MSX1, V9938 / V9958 from the MSX2): mode 1 = 40 x 24, mode 0 = 32 x 24, mode 2 = 80 x 24 (MSX2 and up), the BIOS's font | the BIOS's keyboard (its layout, auto repeat) |
| MSX + V9938 card | `msxcard` | as `msx`, the console on a V9938 card at ports `#88`-`#8B` (Sharp HB-4000, Gradiente CT-80E, Neos MA-20V: an MSX1's 80 columns). `#If NTC_MSXCARD` (and `NTC_MSX`) | the card: modes as `msx`'s (80 columns on any MSX) | as `msx` |
| MSX + V9990 | `msx9990` | as `msx`, the console on a V9990 at `#60`-`#6F` (GFX9000, Video9000, Powergraph, TRH9000). `#If NTC_MSX9990` (and `NTC_MSX`) | a bit map (B1 / B3) with the BIOS's font: modes 0 and 1 = 40 x 24, mode 2 = 80 x 24 | as `msx` |
| Sega SC-3000 | `sc3000` | a cartridge ROM, `NAME.SC` (16K, 32K or 48K at `#0000`); 2K of RAM (`#C000`-`#C7FF`) for the variables, the arrays and the stack; the RESET key starts the program again; `End` stops it. `#If NTC_SC3000` | the TMS9918A / TMS9929A: mode 1 (and 2) = 40 x 24, mode 0 = 32 x 24, NTC's own 6 x 8 font | full screen, keys from the matrix (new presses, no auto repeat) |
| Amstrad CPC + MSX V9938 card | `cpccard` | as `cpc` (no firmware, a binary at `#0040`), the console on an MSX V9938 card through the AMSDAP MSX cartridge adapter: MSX port nn is the CPC's `&FFnn`, so the card is at `&FF88`. `#If NTC_CPCCARD` (and `NTC_CPC`) | the card's own monitor: modes as `msxcard`'s, NTC's 6 x 8 font | as `cpc` |
| Amstrad CPC + V9990 | `cpc9990` | as `cpc`, the console on a V9990 at `&FF60`: an MSX V9990 cartridge through the AMSDAP adapter, or the CPC Powergraph. `#If NTC_CPC9990` (and `NTC_CPC`) | the V9990's own monitor: as `msx9990`'s, NTC's 6 x 8 font | as `cpc` |

The BASIC is the same on all of them. What changes is the start-up, the console and what
the `StdIO`, `System` and `FileSystem` classes report.

The three CPC platforms are three amounts of firmware: `cpcfw` uses it for everything (the
easiest, and all ROMs work); `cpcmin` draws and reads the keyboard itself (faster text, NTC's
own interrupt handler) and keeps the firmware only for discs, tape and ROM commands; `cpc`
uses none (all the RAM; files from a ROMDISC only). On `cpcfw` and `cpcmin`, `RUN"` of a binary drops AMSDOS
and the other ROMs: [Option RomEnable](#option-romenable) starts them again. While a
`cpcmin` firmware call runs, the screen may show the firmware's mode, and firmware messages
(disc missing, Retry / Cancel, Press PLAY) appear on the screen; afterwards NTC's mode,
screen start and interrupt handler are back.

On the MSX platforms the program is a cartridge and the BIOS stays in page 0: its interrupt
handler reads the keyboard into its buffer and counts JIFFY, and `Inkey` / `Input` take keys
from that buffer (with interrupts let in for the call, as on the firmware platforms). The
consoles of msx, msxcard, msx9990, sc3000, cpccard and cpc9990 are the same library code
(`asm/ntc_lib_vdp.asm`) on different chips: the console's chip is also there for the
[VDP](#vdp) or [V9990](#v9990) class to draw on (`Mode` or `Cls` gives the text back).

On the firmware and CP/M platforms, console calls go to the system on the real stack with
interrupts on during the call (the system scans keys on interrupts). The thread itself still
never uses `call` or `push`. In turbo mode on these platforms, interrupts get in only during
those calls.

### StdIO

The console as a class. It is part of the platform: name `StdIO` in a program and the
platform's own `StdIO.cls` joins the project. Every method body is `#asm` only, so each call
is a keyword with no procedure overhead, and the methods use the same routines as `Print`,
`Input` and the other console statements, so the two can be mixed.

| Member | What it does |
|---|---|
| `PutStr s` | print text, no new line |
| `PutChar c` | print one character by code (13 = a new line) |
| `PutInt n` | print an Integer |
| `NewLine` | new line |
| `Tab col` | spaces up to a column, like `Tab` in `Print` |
| `GetLine s` | read a typed line into a String (like `Input`) |
| `GetChar()` | wait for a key, give its code |
| `GetKey()` | the key pressed, or 0 (like `Inkey`) |
| `Cls`, `Locate x, y`, `Mode m` | as the statements |
| `Cols()` | text columns now |
| `Column()`, `Row()` | the cursor, 1 based |

Constants (what this console can do):

| Constant | cpc | cpcfw | cpm | test |
|---|---|---|---|---|
| `CanPosition` - `Locate` works | True | True | False* | True |
| `CanClear` - `Cls` clears | True | True | False* | True |
| `CanInput` - there is a keyboard | True | True | True | True |
| `CanPoll` - `GetKey` doesn't wait | True | True | True | True |
| `CanColour` - pen / paper | False | False | False | False |
| `Glyphs` - the program draws the text itself (ZOSCII glyphs) | True | False | False | False |
| `Rows` - text rows, 0 = a stream | 25 | 25 | 0* | 25 |

\* With `Option Terminal VT52` or `ANSI`: True, True and 24.

msx, msxcard, msx9990, sc3000, cpccard, cpc9990: `CanPosition`, `CanClear`, `CanInput`,
`CanPoll` True, `CanColour` and `Glyphs` False, `Rows` 24.

```
If StdIO.CanPosition Then
  Locate 1, StdIO.Rows : Print "Score: "; score;
Else
  Print "Score: "; score
End If
```

The constants are worked out when compiling, so a test like this costs at most one jump.

### System

What the machine is. The same members on every platform; 0 / False means "not here".

| Member | cpc | cpcfw | cpm | cyborgos | baremetal | test | zxn |
|---|---|---|---|---|---|---|---|
| `Platform` | "CPC" | "CPC firmware" | "CP/M" | "CyborgOS" | "Bare Metal" | "Test" | "ZXN" |
| `CpuClock` (kHz, 0 = not known) | 4000 | 4000 | 0 | 0 | 0 | 4000 | 28000 |
| `TicksPerSecond` (0 = no clock) | 300 | 300 | 0 | 0 (`CybSys.Clock`: 300) | 0 | 300 | 300 |
| `FrameRate` (0 = not known) | 50 | 50 | 0 | 0 | 0 | 0 | 50 |
| `HasInterrupts` (normal mode lets interrupts in) | True | True | True | True | False | True | True |
| `HasHook` (the `Interrupt` statement) | True | True | False | False | False | False | True |
| `HasScreen` (rows and columns, not a stream) | True | True | False* | True | False | True | True |
| `HasKeyboard` | True | True | True | True | False | True | True |
| `MaxHandles` (file handles, `FileSystem.Open`) | 0 | 0 | 2 | 2 | 0 | 0 | 0 |
| `Ticks()` | the tick count, the same as `Ticks` | | | |
| `Command(name)` | run a ROM's command (an RSX, `|NAME`, no arguments) - cpcfw and cpcmin only: 0, or -2 when no ROM has it; -1 elsewhere | | | |
| `HasCapability(name)` | True (-1) when the platform can do it, else False - see below | | | |
| `CommandLine()` | what was typed after the program's name - CP/M only (`A>PROG FILE.TXT` gives `"FILE.TXT"`, in capitals as CP/M passes it); "" elsewhere | | | |

The new platforms: msx, msxcard and msx9990 have `Platform` "MSX", sc3000 "SC-3000" -
`CpuClock` 3580, `TicksPerSecond` and `FrameRate` 50 (60 on an NTSC machine: the frames),
`HasInterrupts`, `HasHook`, `HasScreen`, `HasKeyboard` True, `MaxHandles` 0; their
`HasCapability`: SCREEN, KEYBOARD, CLOCK, HOOK, INTERRUPTCLASSES. cpccard and cpc9990 have the
cpc platform's `System` (`Platform` "CPC").

```
Print "running on "; System.Platform
If System.TicksPerSecond = 0 Then Print "(no clock here)"
```

`System.HasCapability(`*name*`)` (case does not matter; an unknown name is False):

| Name | Means | cpc | cpcmin | cpcfw | cpm | test |
|---|---|---|---|---|---|---|
| `COMMANDLINE` | `System.CommandLine` has the command tail | - | - | - | True | - |
| `SCREEN` | rows and columns, not a stream | True | True | True | with `Option Terminal` | True |
| `KEYBOARD` | keys | True | True | True | True | True |
| `CLOCK` | `Ticks` counts | True | True | True | - | True |
| `HOOK` | the `Interrupt` statement | True | True | True | - | - |
| `INTERRUPTCLASSES` | `Option Class Interrupt` | True | True | True | - | - |
| `PAGES` | RAM pages (`Option Memory CPCExpansion`) | True | True | True | - | - |
| `FILES` | `FileSystem` Load / Save (more: `FileSystem.Capability`) | - (a ROMDISC: `FileSystem.Capability("ROMDISC")`) | True | True | True | - |
| `ROMCOMMANDS` | `System.Command` | - | True | True | - | - |
| `OVERLAYS` | `Option Class Overlay` | - | True | True | True | - |

```
If System.HasCapability("COMMANDLINE") Then
  cl = System.CommandLine
Else
  Input "File name"; cl          ' no command line here: ask
End If
```

The CP/M start code copies the command tail (at `#80`) aside before anything can overwrite
it, only when the program uses `CommandLine`. See `bas/cmdline.bas`.

### FileSystem

Files. Every platform has a `FileSystem` class with the same methods, so a program that
uses files compiles everywhere; what the platform can really do comes from `Capability`:

`FileSystem.Capability(`*name*`)`

gives the value for that name (case does not matter), or 0 (False) when this platform
hasn't got it. Yes / no capabilities are True (-1); some are numbers.

| Name | Means | cpc | cpcfw | cpm | test |
|---|---|---|---|---|---|
| `LOAD`, `SAVE` | whole file to / from memory | `LOAD` (ROMDISC) | True (cpcmin too) | True | - |
| `SEQUENTIAL` | `Open`, read and write in order | True (reading: ROMDISC) | True (cpcmin too) | True | - |
| `RANDOMACCESS` | `Seek` anywhere, read and write | - | - | True | - |
| `DELETE`, `RENAME`, `EXISTS`, `SIZE` | those methods | `EXISTS`, `SIZE` | - (`Exists`, `Size` on volume R) | True | - |
| `MULTIPLE` | more than one file open at once | - | - | True | - |
| `DEVICES` | `Devices`, `SelectDevice`, `CurrentDevice` | True (`ROM`) | True | True | - |
| `VOLUMES` | `Volumes`, `SelectVolume`, `CurrentVolume` | True (`R`) | True | True | - |
| `ROMDISC` | volume R: files kept in ROMs (below) | True | True (cpcmin too) | - | - |
| `CPMVERSION` | BDOS's version: `&H22` CP/M 2.2, `&H31` CP/M 3 | - | - | yes | - |
| `MAXOPEN` | how many files can be open | 1 | 1 (and a ROMDISC file beside it) | 2 | 0 |
| `RECORDSIZE` | the disc's record size | - | - | 128 | - |

A name the platform doesn't know is 0, so a program can ask for anything.

The methods all return a number: 0 or more is a result (a count, a handle, a byte), less than
0 is a status - `FileSystem.NotSupported` (-1, this platform can't), `NotFound` (-2),
`Full` (-3), `BadName` (-4), `NoHandle` (-5), `BadHandle` (-6), `EndOfFile` (-7),
`TooBig` (-8), `Failed` (-9), `AlreadyExists` (-10), `BadMode` (-11).

| Method | Does |
|---|---|
| `Load(name, address, maxlen)` | the file into memory; its length (`TooBig`: longer than `maxlen`) |
| `Save(name, address, length)` | a new file with those bytes |
| `Delete(name)`, `Exists(name)`, `Rename(old, new)` | `Exists` gives True / False |
| `Size(name)` | bytes (a Long) |
| `Open(name, mode)` | a handle; mode `ForRead` (1), `ForWrite` (2, a new file), `ForUpdate` (3, read and write), `ForReadRaw` (4: `ForRead`, but a file with no header is read to its last record - a #1A byte is data, not the end; CP/M and the ROMDISC: the same as `ForRead`) |
| `Close(h)` | |
| `ReadByte(h)`, `WriteByte(h, b)` | `ReadByte` gives 0-255 or `EndOfFile` |
| `Read(h, address, count)`, `Write(h, address, count)` | bytes to / from memory; `Read` gives how many it got |
| `Seek(h, position)` | the next read or write is at that byte (a Long, 0 = the start) |
| `Eof(h)` | True when there is nothing more to read |
| `ReadLine(h)`, `WriteLine(h, text)` | a line of text (CR LF or LF ends it, not kept) |
| `DirEntry(n)` | the ROMDISC's n-th file, `"NAME.EXT"` (1 = the first), `""` past the last (other platforms: `""`) |
| `Devices()` | how files travel, as text: `"TAPE,DISC"` (CPC with a DOS), `"TAPE"`, `"DISC"` (CP/M) |
| `SelectDevice(name)` | `"TAPE"` or `"DISC"`; `NotFound` if this platform hasn't got it |
| `CurrentDevice()` | `"TAPE"` or `"DISC"` |
| `Volumes()` | the volumes known so far, as text: `"A,B,C"` |
| `SelectVolume(name)` | the volume for names without one: `"B"`, `"C:"`, `"M"` ...; `NotFound` if not there |
| `CurrentVolume()` | the volume last selected (`""` = not known) |

**Devices and volumes.** A device is how files travel: `TAPE` or `DISC`. A volume is a
drive on the disc device: `A`, `B`, and whatever else the disc system offers - `C` and `M`
on an M4, more with UniDOS, USB or CompactFlash interfaces; `A` to `P` on CP/M. Neither
AMSDOS nor CP/M can list the volumes that exist, so `Volumes()` lists the ones this program
knows of: what the platform knows from the start, and every volume used successfully (by
`SelectVolume`, or by a `Load` / `Save` with `"C:NAME"` in its name) joins it. A program can
try names in a loop to build the list:

```
For c = 65 To 90
  r = FileSystem.SelectVolume(Chr$(c))
Next
Print FileSystem.Volumes()
```

On the CPC that is quick (it looks up the DOS's commands `|A` ... `|Z`, no disc access) but
it shows the volumes the DOS offers, not that a disc is in the drive. On CP/M each try reads
the drive (it shows the drive is there, a second or so each); on CP/M 2.2 a drive that
isn't there stops the program with BDOS's error, so loop only when
`FileSystem.Capability("CPMVERSION") >= &H30`.

```
Dim hs(9) As Integer
If FileSystem.Capability("SAVE") Then
  r = FileSystem.Save("HISCORE.DAT", VarPtr(hs), 20)
End If

h = FileSystem.Open("NOTES.TXT", FileSystem.ForRead)
Do While Not FileSystem.Eof(h)
  Print FileSystem.ReadLine(h)
Loop
r = FileSystem.Close(h)
```

- **CP/M** (`cpm`): everything above, through BDOS. Names `NAME.EXT` or `B:NAME.EXT`
  (8.3, no `*` or `?`). CP/M keeps whole 128 byte records, not an exact length: `Save`
  pads the last record with ^Z (26), `Load` and `Size` count whole records, and text ends
  at the first ^Z (`Eof`, `ReadLine`). Two files open at once.
- **CPC firmware** (`cpcfw`): `Load` and `Save`, through the firmware's cassette calls - to
  the selected disc drive with AMSDOS, else to tape, as BASIC's `LOAD` and `SAVE` do, with
  the firmware's own messages. A saved file is a binary file: BASIC can
  `LOAD "HISCORE.DAT", &4000` it. Uses a 2K buffer.

  **One open file** (`SEQUENTIAL`, `MAXOPEN` 1): `Open` gives handle 1. `ForRead` reads any
  file byte by byte (`ReadByte`, `Read`, `ReadLine`, `Eof`): a file with no header is text to
  AMSDOS, ending at its first #1A; `ForReadRaw` reads one to the end of its last 128 byte record
  (a CP/M `.COM`, say), each #1A a byte. `Eof` reads one byte ahead (the firmware's CAS TEST
  EOF loses bytes at a #1A). `ForWrite` makes a new text file
  (`WriteByte`, `Write`, `WriteLine`) - the kind BASIC's `OPENOUT` / `PRINT #9` make, so
  BASIC's `OPENIN` / `LINE INPUT #9` read it back. `ForUpdate` and `Seek` are
  `NotSupported`, as are `Delete`, `Exists`, `Rename` and `Size`. A second `Open` while one is
  open gives `NoHandle`; `Load` and `Save` give `Failed` while a file is open (they share the
  2K buffer). `Close` a written file, or its last part isn't written. Devices `TAPE` and `DISC` (`|TAPE`,
  `|DISC`); volumes: any name the disc system has a command for (`|A`, `|B`, `|C` ...).

  **Disc or tape?** `RUN"NAME` of a binary resets the firmware, and that drops AMSDOS: files
  then go to tape. Two ways to keep the disc:
  - `Option RomEnable 7` (or `All`): the program starts AMSDOS again when it starts (drive A).
  - Build at a higher org and start it from BASIC with `CALL`, which keeps AMSDOS running:
    `MEMORY &1FFF : LOAD "NAME" : CALL &2000` for a program built at `#2000`
    (`CurrentVolume` is then `""`: AMSDOS's drive, whichever it is).

  The program must end below `#A600` when it uses files (AMSDOS's RAM is above): checked
  when assembling.
- **CP/M** has one device, `DISC`; the volumes are the drives. `Volumes` gives the ones CP/M
  has used so far and the current one; `SelectVolume "B"` makes B the drive for names
  without a drive letter. CP/M 3 returns `NotFound` for a drive that isn't there; CP/M 2.2
  stops with its own BDOS error.
- **CPC minimal firmware** (`cpcmin`): the same as `cpcfw` (Load / Save, one open file, devices,
  volumes), each call handed to the firmware for its length. Its keyword ROM has no room for
  the open-file code: with `Option Library ROM` the program carries that part itself (about
  450 bytes).
- **CPC, no firmware** (`cpc`): the ROMDISC is its only volume (below). **test**: no files -
  every method returns `NotSupported`.

**The ROMDISC (volume R)** - files kept in ROMs, read only, on cpc, cpcmin and cpcfw. A
ROMDISC is one or more ROMs (`NTCDISC.ROM`, `NTCDISC2.ROM` ..., up to 8, in any ROM slots)
made from a list of files by `ntcRomDisc` (in `ntc_compiler.js`; `test/genromdisc.js
outdir FILE ...` writes them). Names are 8.3. ROM 0 holds the directory, read until an entry
flagged as the end; each entry has the name, a flags byte (bit 0 = compressed - none are yet),
the ROM and address where the file starts, and its length; a file may run on from one ROM into
the next.

It isn't a disc system: no drive, no catalogue screen, no Retry / Cancel - FileSystem's
methods simply go to the ROMDISC's routines when the volume is R:

- a name `"R:NAME.EXT"`, or a name with no volume while the volume in use is R
  (`SelectVolume "R"`): `Load`, `Open` (`ForRead` only: it gives handle 2), `Exists`, `Size`;
- handle 2: `ReadByte`, `Read`, `ReadLine`, `Eof`, `Close`;
- `DirEntry(n)` lists the files.

Writing (`Save`, `Open ForWrite`, `WriteByte` ...), `Delete`, `Rename` and `Seek` return
`NotSupported` on R. On cpcmin and cpcfw a ROMDISC file (handle 2) can be open beside a disc file
(handle 1), and `"A:NAME"` still reaches the disc while R is in use. On cpc, R is the only volume.
No ROMDISC fitted (or a part of it missing): `NotFound`, `Volumes` `""` on cpc. Reading selects
the ROMDISC's ROM for a moment (cpc and cpcmin: on the hardware; cpcfw and cpcmin's file calls:
KL ROM SELECT), so this code is never in the keyword ROM: a `Library: ROM` program carries it
(about 1.2K) when it uses volume R.

```
r = FileSystem.SelectVolume("R")
n = 0
Do
  n = n + 1 : s = FileSystem.DirEntry(n)
  If s <> "" Then Print s; " "; FileSystem.Size(s)
Loop Until s = ""
r = FileSystem.Load("TITLE.SCR", &HC000, 16384)     ' a screen straight from ROM
```

See `bas/files.bas`.

**VB:** VB has `Open ... For ... As #n`, `Print #`, `Input #`, `Get` / `Put` and `EOF()`, and
raises errors. Here files are methods of a class that return a status, and what works
depends on the platform.

### Memory

RAM for the program to hand out while it runs: whole 16K pages, and a heap (`Alloc` /
`Free`). [Option Memory](#option-memory) picks how the RAM is reached; the methods are the
same either way.

**`CPCExpansion`** (the default on cpc, cpcmin, cpcfw): 16K pages switched into
`#4000-#7FFF` (the window) by the gate array, up to a 4MB expansion. The first call probes
what is fitted.

| Machine | Pages | Model |
|---|---|---|
| 64K (464, 664) | 1: main RAM `#4000` | small |
| 128K (6128, or 464 + 64K) | 5 | medium |
| up to a 512K expansion (576K) | 9 - 33 | large |
| up to a 4MB expansion (4160K) | 37 - 257 | huge |

Page 1 is main RAM `#4000-#7FFF`; pages 2 on are 4 for each 64K bank found (a 6128's second
64K is pages 2-5), the standard 512K (port `&7F`) first, then the 512K blocks on ports `&7E`
down to `&78`. A program asks for what it wants; 0 back means it isn't there, and the
program carries on without it (no music on 64K, say).

Every page has a type:

| Type | Letter | For | What the class does with it |
|---|---|---|---|
| `TypeCode` | C | code: overlay classes ([Option Class](#option-class)), compiled sprites later | overlay classes load into these |
| `TypeData` | D | the heap | `Alloc` / `Free` work inside these; one left empty goes back to free |
| `TypeIrq` | I | interrupt handler blocks | a label for now |
| `TypeUser` | U | the program's own: music, level data, anything it manages itself | a label: the program uses the page as it likes |
| `TypeBank` | B | the 4 pages of a whole 64K bank (`AllocBank`) | `CallBank` runs code in it |
| `TypeFree` | - | not allocated | |

Every page is on one list: free, C, D, I, U or B. Free pages come from two lists - main RAM and
the standard 512K for C, I and U pages, the blocks above it for D pages (the heap) - and each
falls back to the other. So on a big machine a growing heap uses the upper blocks and leaves
the standard 512K for code, music and levels; on 576K or less it is all one list.

The program, and its stack, must be out of the window - switching a page in would hide
them. `Option Reserve &H4000, &H4000` checks that when assembling. A program in the window
gets `Pages() = 0`. Anything the program reads or writes in the window (`Poke`, `Peek`,
`FileSystem.Load`) goes to the page in it at that moment: that is how a page is filled from
a file. Use `Memory.WindowStart` and `Memory.WindowSize` rather than `&H4000`: they are
constants, worked out when compiling.

The class's tables (3 bytes a page: a 6128 15 bytes, 4MB 771 - each page's type, the RAT that
`Map` shows, and the 2 bytes that select it) go from the program's end
up, made by the first Memory call - so don't keep your own data straight after the program.
`TableEnd()` gives the first byte after them. When they don't fit below `#4000` (or below
the stack), the class keeps fewer pages.

**`Small`** (the default on cpm and test; any platform): no paging. One heap over the free
main RAM, from the program's end up to the first of: the platform's top (CPC `#A600` - the
firmware's and AMSDOS's RAM is above; CP/M the BDOS, from address 6), 256 bytes under the
stack, an `Option Reserve` range. `HeapStart()` / `HeapEnd()` say where. Far pointers are
plain addresses (page 0); `Pages()` is 0 and the page methods give 0 or `BadPage`. The same
`Alloc` / `Free` code works with both schemes.

**Far pointers** are Longs: the low word is the address, the high word the page (page 0 =
plain memory, nothing switched). `Alloc` gives them; `CLng(page) * 65536 + address` makes one.

| Method | Does |
|---|---|
| `Pages()` | pages this machine has: 0, 1, 5, 9, 17, 33 ... 257 (`Small`: 0) |
| `FreePages()` | pages not allocated |
| `RamSize()` | K of RAM found (64 ... 4160), 0 = no paging so not probed |
| `Model()` | `ModelNone` (0: `Small`, or no paging), `ModelSmall` (1), `ModelMedium` (2), `ModelLarge` (3), `ModelHuge` (4) |
| `HeapStart()`, `HeapEnd()` | `Small`: the heap's RAM (`HeapEnd` is the first byte past it); `CPCExpansion`: the window |
| `TableEnd()` | the first byte after the class's tables (`Small`: the program's end) |
| `ProgramStart()`, `ProgramEnd()` | where the program is (`ProgramEnd`: the first byte after it and its arrays) |
| `Top()` | the platform's top of free RAM: CPC `#A600` (the firmware above; cpcfw `#A5F0` with `Interrupt` or interrupt classes), CP/M the end of the TPA (the BDOS), test `#C000` |
| `StackTop()` | where the real stack starts (it grows down) |
| `PageType(page)` | its type character |
| `Map(first, count)` | one character per page from page `first`: `"UCUDD"` (as many as the string holds) |
| `AllocPage(kind)` | a free page, now of that kind (`TypeCode`, `TypeData`, `TypeIrq`, `TypeUser`); 0 = none left |
| `FreePage(page)` | back to free (`BadPage` if it is free already) |
| `SelectPage(page)` | into the window; gives `WindowStart` |
| `CurrentPage()` | the page in the window |
| `Alloc(size)` | a far pointer to `size` bytes (up to 16382), 0 = no room |
| `Free(ptr)` | a block back; a heap page with nothing left in it goes back to free |
| `Largest()` | the biggest block `Alloc` could give now |
| `PageOf(ptr)`, `Address(ptr)` | the page; `Address` switches it in and gives the address |
| `ReadByte(ptr)`, `ReadWord(ptr)` | |
| `WriteByte ptr, value`, `WriteWord ptr, value` | |
| `Copy(src, dst, length)` | far pointer to far pointer; past the end of a page it carries on at the start of the next page |
| `Banks()` | whole 64K banks there are (bank 1 = pages 2-5, bank 2 = pages 6-9 ...); 0 = none |
| `AllocBank()` | a bank whose 4 pages are all free, now `TypeBank`; 0 = none left |
| `FreeBank(bank)` | its 4 pages back to free (`BadPage`: not a bank, or not taken with `AllocBank`) |
| `BankPage(bank, n)` | the page number of the bank's part n (0 = its `#0000-#3FFF` ... 3 = `#C000-#FFFF`), to fill it with `SelectPage`, `WriteByte`, `Copy`, `FileSystem.Load` |
| `CallBank(bank, address, value)` | runs the bank's code at `address` with the whole 64K being that bank; it gets `value` in HL and gives back HL |
| `BankStub()` | where `CallBank` puts its switch code in the bank (`BankStubSize` bytes) |

**Whole banks.** `AllocBank` takes the 4 pages of one 64K bank together, and `CallBank` runs
machine code in it with the gate array's RAM setting C2: all 64K, `#0000` to `#FFFF`, is that
bank - none of the program, the screen or the firmware is in sight. Fill the bank first
through the window (`BankPage` gives each part's page), then call it:

```
b = Memory.AllocBank()
If b = 0 Then Print "No spare 64K"
p = CLng(Memory.BankPage(b, 0)) * 65536 + &H5000      ' the bank's #1000, seen in the window
Memory.WriteByte p, &H23 : Memory.WriteByte p + 1, &HC9 ' inc hl : ret
r = Memory.CallBank(b, &H1000, 41)                      ' 42
```

- `CallBank` copies its switch code (16 bytes, at `BankStub()`: the same address it has in
  the program) into the bank first, so keep the bank's own code and data off those bytes.
- While the bank's code runs: interrupts off, both ROMs off, the stack starts at the bank's
  top (`#FFFF` down). It ends with `ret` (HL is the result) and must keep the alternate
  registers (`BC'`, `DE'`, `HL'` - the firmware's interrupt uses them). Main RAM, the page in
  the window, the ROMs and the interrupts are put back as they were.
- `Small`, or a machine without a second 64K: `Banks()` and `AllocBank()` are 0, the others
  `BadPage`.

Constants: `WindowStart`, `WindowSize` (`CPCExpansion`: `&H4000`, `&H4000`; `Small`: 0, 0).
With `CPCExpansion`, `Alloc` uses D pages - the one in the window first, then the others,
then it takes a free page.

Only `SelectPage` and `Address` change the page in the window; the other methods put it
back. `End` puts main RAM back in the window (for BASIC, after a `CALL`). Statuses:
`Memory.OK` (0), `Memory.BadPage` (-2: not a page this machine has, or not a block in use).

```
music = Memory.AllocPage(Memory.TypeUser)
If music = 0 Then Print "No music on this machine"
a = Memory.SelectPage(music)
r = FileSystem.Load("TUNE.BIN", Memory.WindowStart, Memory.WindowSize)   ' into the page

p = Memory.Alloc(1000)
Memory.WriteWord p, 1234
r = Memory.Free(p)
```

Free blocks are at most 16K (joined neighbours stop there), so with `Small` a big heap is
several 16K stretches: the biggest single `Alloc` is 16382 bytes. `Copy` uses the same 2K
buffer as FileSystem. The 4MB blocks use ports `&78xx-&7Exx`, which also have address line
A10 low, as expansion hardware does: the low byte (`&C4-&FF`) keeps the disc controller out of
it, but an unusual interface could react. Interrupts are left as they are (off in turbo mode
and inside keywords), so a long `Copy` can hold the 300 Hz ticks back. See `bas/memmap.bas`.

### List

Linked lists in the Memory class's heap - D pages with `Option Memory CPCExpansion`, the free
main RAM with `Option Memory Small` - so a list can be far bigger than the program's own
memory. Prefer lists to big arrays where you can: an array takes its whole size in the
program's memory, a list takes 4 bytes there however long it is.

A list is a handle (a Long), so a program can have as many as it likes. Its nodes are far
pointers (Longs) too; each node has a next and a previous node and *size* bytes of data.

```
Const ID = 0, SCORE = 2
h = List.Create(4)                       ' 4 data bytes a node: two words
n = List.Append(h)
List.SetWord n, ID, 1 : List.SetWord n, SCORE, 950
r = List.Sort(h, SCORE)
n = List.First(h)
Do While n <> 0
  Print List.GetWord(n, ID); List.GetWord(n, SCORE)
  n = List.NextOf(n)
Loop
r = List.Destroy(h)
```

| Method | Does |
|---|---|
| `Create(size)` | a new empty list, *size* data bytes a node (up to 15988); 0 = no room |
| `Append(h)`, `Prepend(h)` | a new node (cleared) at the end / the start; 0 = no room |
| `InsertAfter(h, node)` | a new node after that one (node 0: at the start) |
| `Delete(h, node)` | out of the list; its memory goes back to the list's free chain |
| `First(h)`, `Last(h)`, `NextOf(node)`, `PrevOf(node)` | a node, or 0 |
| `Count(h)` | the nodes in it |
| `GetWord(node, offset)`, `GetByte(node, offset)` | from its data |
| `SetWord node, offset, value`, `SetByte node, offset, value` | into its data |
| `Data(node)` | a far pointer to its data (for `Memory.Copy`, `Memory.ReadWord` ...) |
| `Search(h, offset, value)` | the first node whose data has that word at *offset*, or 0 |
| `Sort(h, offset)` | in order of the (signed) word at *offset*, equal ones keeping their order (a radix sort: two passes over the list, the 2K buffer for the buckets) |
| `Destroy(h)` | the list's memory back to the heap |

A list takes its nodes from blocks of up to 16000 bytes at a time, cut into nodes on its own
free chain, so `Append` and `Delete` are a pointer swap and nothing fragments. A handle or node
that is 0 or not a page this machine has gives `Memory.BadPage` (-2) - but a node of another
list, or one already deleted, is not caught. Each call costs about 600 microseconds (it
switches pages and checks its arguments). `Sort` of 500 nodes takes about 0.4 seconds, of 5,000
nodes (spread over four pages of a 6128) 4.2 to 4.8 seconds, the same in turbo and normal mode -
see `bas/sorttime.bas`. Every
platform has it (cpc, cpcmin, cpcfw with either memory scheme; cpm and test with `Small`).
See `bas/lists.bas`.

### Graphics

Drawing on the CPC screen: `cpc`, `cpcmin` and `cpcfw` (and `cpm` on a CPC, mode 2: see the
end of this section). On cpcfw the class still writes the
screen memory itself (the firmware only draws the text): set the mode with `Mode` first (that
tells the class the mode), and don't let the firmware scroll the text while drawing - a
scroll moves the screen's start and the lines would land in the wrong place. Lines in any mode - 0 (160 x 200, 16 pens), 1 (320 x 200, 4 pens), 2 (640 x 200,
2 pens) - in a pen, drawn with XOR: drawing the same line again takes it off and leaves what
was under it, text included. One drawing loop serves every mode (a marker of the pixel's bits
moves one pixel per step), so mode 0 lines are the quickest (fewer pixels across) and mode 2
the slowest.

On the ZX Spectrum Next (`zxn`) the same class draws on Layer 2 (320 x 256, 256 colours), in the
CPC's mode 1 size - 320 x 200, centred 28 rows down - so a CPC program's coordinates carry over:
XOR lines, `DoubleBuffer` with two Layer 2 buffers (banks 12-16 and 17-21) and `Flip` at Layer 2's
flyback. Layer 2 comes on with the first line (or `DoubleBuffer`), `Mode` turns it off. A pen is a
Layer 2 palette entry (0-255; set them through NextRegs `#43`, `#40`, `#41`). Text stays on the
tilemap, over Layer 2 (its paper see-through meanwhile), so `CopyText` has nothing to do.

| Member | Does |
|---|---|
| `Line x0, y0, x1, y1` | a line in the pen, in pixels of the current mode |
| `Plot x, y` | one pixel |
| `Pen p` | the pen (mode 0: 0-15, mode 1: 0-3, mode 2: 0-1) |
| `Clip on` | on (the default): a line with an end off the screen isn't drawn. Off: no checks - fastest, but a point off the screen writes over memory |
| `Width()` | the screen's width in this mode (160, 320, 640) |
| `DoubleBuffer on` | two screens: `#C000` and main RAM's own `#4000-#7FFF`. The one not shown is drawn on; `Flip` shows it |
| `Flip` | wait for the frame flyback, show the screen just drawn, draw on the other one |
| `Back()` | the screen drawn on: 0 = `#C000`, 1 = `#4000` |
| `Buffering()` | True while double buffering is on |
| `CopyText rows` | the top rows of text copied from `#C000` to the other screen (`Print` always writes to `#C000`) |

**Double buffering and RAM pages.** The CRTC always shows main RAM, whatever RAM page the Z80
has in the window, so the second screen at main RAM's `#4000` stays on show while code or data
pages are switched in. Drawing puts main RAM in the window only while it writes, then puts back
the page that was there (the Memory class keeps it in `ntc_rampt`). So overlay classes and
data pages still work: take page 1 first (`Memory.AllocPage(Memory.TypeUser)` gives it first)
so nothing else is put there. On a 64K CPC page 1 is the only page.

```
Graphics.DoubleBuffer 1
Do
  ' ... draw the frame with Graphics.Line (on the screen not shown) ...
  Graphics.Flip                  ' show it at the next flyback
Loop
```

See `bas/cube3d/` (Vector3D draws through it) and `bas/city3d/` (a wireframe city to fly through, cpcfw).

`bas/auckland/` (AUCKLAND.BIN, cpcfw, a 4 MB CPC) is the big one: Auckland from OpenStreetMap -
234,000 buildings, the roads, the coast, 50,000 trees, the Sky Tower, the Harbour Bridge and the
volcanoes, read from AUCKLAND.DAT (3.8 MB) into the expansion RAM. The data is made in a browser:
`tools/osmcut` cuts an OpenStreetMap .osm.pbf, `tools/s3dmake` turns the cut into the .DAT (see
their READMEs). It starts 200 m up out in the gulf, flying in at Auckland with Rangitoto ahead on
the right. Keys 1-9: the views; B: the line budget (600, 1200, 2400 a frame); S: frames skipped (0, 4, 8 -
faster over the ground); P: pause. A compass arrow (bottom right) points to the city's centre (the Sky Tower).

**Graphics on CP/M (an Amstrad CPC).** The `cpm` platform has the class too, for CP/M on a
CPC: mode 2 only (the console's mode: 640 x 200, pens 0-1), one screen (`DoubleBuffer`, `Flip`
and `CopyText` do nothing, `Back()` is 0). It writes to the screen memory itself, not through
CP/M or the firmware; it asks BDOS 12 which CP/M it is on at the first line drawn:

- CP/M 2.2: the screen is `#C000-#FFFF` of the program's own 64K: drawn there.
- CP/M Plus (6128): programs run in RAM configuration C2 (blocks 4-7) and the screen is block 1,
  which is at `#4000` only in C1 (blocks 0, 1, 2, 7) - and C1 leaves nothing of the program but
  `#C000-#FFFF` (block 7, common memory). So the first line copies the line loop (about 380
  bytes) to `#C000`, and each line is drawn from there: C1 in, the line, C2 back, interrupts
  off meanwhile. The program must end below `#C000` (the assembler checks), and the Memory
  class's `Small` heap stays below it from then on.

Clear the screen before drawing (`Cls` with `Option Terminal VT52`): the lines assume the
screen starts at its first byte, and a console that has scrolled has moved that start. It
writes the CPC's screen memory, so it is for an Amstrad CPC only (on other CP/M machines it
writes over memory).

### Keys

Keys held down, and the joysticks (cpc, cpcmin, cpcfw, cpccard, cpc9990, zxn, msx, msxcard, msx9990, sc3000). `Inkey` / `Inkey$` give the characters
typed; `Keys` tells whether a key is down right now - several at once, held keys, no auto
repeat - which is what games want. The keyboard matrix is read from the hardware at every
call, so it works with and without the firmware, in turbo and normal mode.

| Method | Does |
|---|---|
| `Down(key)` | True (-1) while that key is held down, else False (0; also for a number not 0-79) |
| `Joystick(n)` | joystick 0 or 1: the directions and fire buttons held, as bits (0 = none) |

Key numbers are the CPC's own, the same as Locomotive BASIC's `INKEY(n)` (the manual's key
number chart). Constants for the usual ones: `KeyUp` (0), `KeyRight` (1), `KeyDown` (2),
`KeyLeft` (8), `KeyCopy` (9), `KeyEnter` (6, the small one), `KeyReturn` (18), `KeyShift`
(21), `KeyControl` (23), `KeySpace` (47), `KeyEsc` (66), `KeyTab` (68), `KeyCaps` (70),
`KeyDel` (79), and `KeyQ`, `KeyA`, `KeyW`, `KeyS`, `KeyD`, `KeyZ`, `KeyX`. Joystick bits:
`JoyUp` (1), `JoyDown` (2), `JoyLeft` (4), `JoyRight` (8), `JoyFire2` (16), `JoyFire1` (32) -
the same as Locomotive BASIC's `JOY(n)`. Joystick 1 shares its wires with the keys 6, 5, R,
T, G, F (48-53), as on any CPC.

On the ZX Spectrum Next (zxn) the key numbers are the Spectrum keyboard's: half row * 8 + bit
(0-63; bits 0-4) - `KeyCaps` (0), `KeyZ` (1) ... `KeyA` (8) ... `Key1` (24) ... `Key0` (32) ...
`KeyEnter` (48) ... `KeySpace` (56), `KeySymbol` (57), `KeyM` ... `KeyB` (60); a constant for
every key. The CPC names are there too: `KeyLeft` / `KeyDown` / `KeyUp` / `KeyRight` are 5, 6, 7,
8 (the Next's cursor keys press Caps Shift with them), `KeyReturn` Enter, `KeyShift` Caps Shift,
`KeyControl` and `KeyCopy` Symbol Shift, `KeyEsc` Space (Break is Caps + Space), `KeyDel` 0. `Inkey`
gives the CPC firmware's codes for the cursor keys (Caps Shift + 5-8, which the Next's cursor keys
are): up 240, down 241, left 242, right 243; Caps + 0 (Delete) 127, Caps + Space (Break) 27.
`Joystick(0)` and `(1)` read the Kempston ports `#1F` and `#37` (the Next's joystick ports set
to Kempston).

On the MSX (msx, msxcard, msx9990) the key numbers are the keyboard matrix's: row * 8 + bit
(rows 0-10, as the BIOS's `SNSMAT` and `NEWKEY`), read from the PPI. Rows 6-8 are the same on
every MSX: `KeyShift` (48), `KeyControl` (49), `KeyGraph` (50), `KeyCaps` (51), `KeyCode`
(52), `KeyF1` (53), `KeyEsc` (58), `KeyTab` (59), `KeyStop` (60), `KeyBS` (61), `KeySelect`
(62), `KeyReturn` (63), `KeySpace` (64), `KeyHome` (65), `KeyIns` (66), `KeyDel` (67),
`KeyLeft` (68), `KeyUp` (69), `KeyDown` (70), `KeyRight` (71). The letters (`KeyA` 22, `KeyD`
25, `KeyQ` 38, `KeyS` 40, `KeyW` 44, `KeyX` 45, `KeyZ` 47) are the international layout's - a
Japanese or AZERTY keyboard has others there. `Joystick(0)` and `(1)` read joystick ports 1
and 2 through the PSG (trigger A = `JoyFire1`, B = `JoyFire2`). `Inkey` comes from the BIOS's
buffer, so its codes are the BIOS's: the cursor keys 28-31, BS 8, ESC 27.

On the SC-3000 the key numbers are the matrix's: row * 16 + bit, port A's bits 0-7 and port
B's 8-11 (rows 0-6): `KeyUp` (102), `KeyDown` (69), `KeyLeft` (85), `KeyRight` (101),
`KeyReturn` (86), `KeySpace` (20), `KeyShift` (107), `KeyControl` (106), `KeyGraph` (105),
`KeyFunc` (91), `KeyBreak` (104), `KeyDel` (52), `KeyHome` (36), `KeyEng` (4), and `KeyQ`,
`KeyA`, `KeyW`, `KeyS`, `KeyD`, `KeyZ`, `KeyX`. `Joystick(0)` and `(1)` are the two joypads
(row 7: button 1 = `JoyFire1`, button 2 = `JoyFire2`). `Inkey`: new presses only, the ASCII
the key shows (Shift for the second sign), INS/DEL = 127, BREAK = 27, the cursor keys 0.

```
Do
  If Keys.Down(Keys.KeyLeft) Then x = x - 1
  If Keys.Down(Keys.KeyRight) Then x = x + 1
  j = Keys.Joystick(0)
  If j And Keys.JoyFire1 Then Fire
  Frame
Loop
```

### VDP

A TMS9918 / V9938 / V9958 video chip on its ports, for graphics (msx, msxcard, msx9990,
sc3000; cpc, cpcmin, cpcfw, cpccard, cpc9990 with an MSX V9938 card through the AMSDAP
adapter). The chip is the platform's: the MSX's own at `#98` (msx9990 too), the card's at
`#88` (msxcard) or `&FF88` (the CPC platforms), the SC-3000's at `#BE`. `VDP.Port` and
`VDP.Chip` move the class to another one. Every method is a keyword (`#asm` only); the work
is the library's (`asm/ntc_lib_vdp.asm`), on the real stack.

| Member | Does |
|---|---|
| `Screen m` | a graphics screen, cleared: 2 = 256 x 192 (any chip), 5 = 256 x 212 16 colours, 6 = 512 x 212 4 colours, 7 = 512 x 212 16 colours, 8 = 256 x 212 256 colours (V9938 / V9958). On the console's chip `Mode` (or the next `Cls`) gives the text back |
| `PSet x, y, c` | a dot (Screen 5-8: the chip's PSET; Screen 2: the pattern bit, ink c for its 8 dots) |
| `Point(x, y)` | a dot's colour (Screen 5-8) |
| `Box x, y, w, h, c` | a filled box (Screen 5-8: the chip's LMMV) |
| `Line x1, y1, x2, y2, c` | a line (Screen 5-8: the chip's LINE) |
| `Copy sx, sy, dx, dy, w, h` | a block copied (Screen 5-8: LMMM) |
| `Palette n, r, g, b` | colour n (0-15) = red, green, blue 0-7 (V9938 / V9958) |
| `VPoke addr, v`, `VPeek(addr)` | a VRAM byte (the first 64K) |
| `Fill addr, count, v`, `Write addr, from, count`, `Read addr, to, count` | VRAM filled; RAM to VRAM; VRAM to RAM |
| `Reg r, v`, `Status(n)` | a register; status register n (S#n on a V9938, S#0 on a TMS9918) |
| `Port p`, `Chip t` | the data port (control: the next); the chip (0 = TMS9918, 1 = V9938 / V9958) |
| `Wait` | until the chip has finished a command (the methods wait before each one) |
| `DefaultPort`, `DefaultChip` | constants: the platform's chip |

```
VDP.Screen 5
VDP.Box 10, 10, 100, 50, 4
VDP.Line 0, 0, 255, 211, 15
```

The commands keep the frame interrupt as the platform has it: on msx and sc3000 the console's
chip is the clock (`Ticks`, `Frame`), so a screen set by the class keeps its interrupt; a card's
chip has none. A V9938 card with 16K of VRAM (the HB-4000) has the text modes only.

### V9990

The V9990 on its ports, for graphics (msx and msx9990 at `#60`: GFX9000, Video9000,
Powergraph; cpc, cpcmin, cpcfw, cpccard and cpc9990 at `&FF60`: an MSX V9990 cartridge through
the AMSDAP adapter, or the CPC Powergraph). The chip draws `Box`, `Line`, `Copy` and `PSet`
itself.

| Member | Does |
|---|---|
| `Screen m` | a bit map, cleared: 1 = 256 x 212 16 colours, 2 = 512 x 212 16 colours, 3 = 256 x 212 256 colours (the first 16 colours: the MSX2's). `Mode` gives msx9990's / cpc9990's console back |
| `PSet x, y, c`, `Box x, y, w, h, c`, `Line x1, y1, x2, y2, c`, `Copy sx, sy, dx, dy, w, h` | the chip's PSET, LMMV, LINE, LMMM |
| `Palette n, r, g, b` | colour n (0-63) = red, green, blue 0-31 |
| `Page n`, `VPoke addr, v`, `VPeek(addr)` | a VRAM byte in 64K page n (0-7) of the 512K |
| `Reg r, v`, `Status()` | a register (R#0-R#54); the status port (P#5) |
| `Port p` | the port base (P#0) |
| `Wait` | until the chip has finished a command |

```
V9990.Screen 1
V9990.Box 10, 10, 100, 50, 4
V9990.Line 0, 0, 255, 211, 15
```

### Cartridge ROMs (msx, sc3000)

The MSX and SC-3000 platforms (msx, msxcard, msx9990, sc3000) build a cartridge: the
assembler writes `NAME.ROM` / `NAME.SC` (sjasmplus `OUTPUT`), padded to the cartridge's size -
16K or 32K at `#4000` on the MSX (an `"AB"` header; the INIT puts the cartridge in page 2 too
for 32K), 16K, 32K or 48K at `#0000` on the SC-3000 (its restart vectors). The code, the
threads, the strings and the numbers passed by address stay in the ROM; everything the program
writes goes to RAM:

- the Variables part and the temporaries, the library's variables (a label with data after
  it, the @data sections) and the data in `#asm` blocks are built for RAM (`#C010` on) into an
  image after the ROM's code, which the start code copies to RAM. A variable that is only
  `ds` (no value) takes no ROM: it is placed after the image and cleared.
- the sections marked @romram run from RAM (copied with the variables).
- the arrays and the Memory class's heap come after the variables, up to the stack.

A table in a `#asm` block that nothing writes can stay in the ROM: `; @const` on its label's
line (or a section marked @const in the library). RAM is the limit on the SC-3000: 2K for the
variables, the arrays and the stack (the assembler stops with a message when the variables
do not fit; arrays that don't fit stop the program with "Not enough memory for the arrays").
The MSX has from `#C010` to the BIOS's stack (about 12K). `Option Reserve`, `Option Page`,
overlays and `Library: ROM` are not for these platforms. `Peek` / `Poke` of the ROM area read
the ROM and do nothing.

### Your own StdIO

A project can have its own `StdIO.cls`. It then replaces the platform's, and the console
statements in the rest of the project call its methods:

| Statement | Calls |
|---|---|
| `Print` | `PutStr` for text and numbers, `Tab` for `Tab(n)`, `NewLine` at the end |
| `Input` | `PutStr` for the prompt, `GetLine` for each variable (numbers are read with `Val`) |
| `Inkey` / `Inkey$` | `GetKey` (`Inkey$` gives `Chr$` of it, "" for 0) |
| `Cls`, `Locate`, `Mode` | `Cls`, `Locate`, `Mode` |

Only the methods a program uses need to exist; a missing one is a compile error that names
it. Inside `StdIO` itself the statements are the built-in ones, so a class can add to the
standard console:

```
' StdIO.cls - every line printed is counted, and text goes out in capitals
Public Lines As Integer

Public Sub PutStr(ByVal s As String)
  Print UCase$(s);
End Sub

Public Sub NewLine()
  Print
  Lines = Lines + 1
End Sub
```

The platform classes are in `lib/<platform>/` (`StdIO.cls`, `System.cls`): copy one into
a project to start your own. `Option VBPrint` spacing is not applied through your own
`StdIO`.

---

## 18. Not in NTC BASIC

These VB5 / VB6 features are not supported. Each was left out on purpose (no heap, no
floating point, SP as the thread), or is planned as a library rather than a language
change.

| VB feature | In NTC BASIC |
|---|---|
| `Single`, `Double`, `Currency`, `Date`, `Variant` | whole numbers only (Integer, Long) |
| `On Error`, `Resume`, `Err`, `Erl` | none, by decision - return a status |
| recursion | not allowed (one set of locals per procedure) |
| `ParamArray` | no |
| `Declare` (DLL calls) | no - use `#asm` or `Call` |
| objects made at run time, `Nothing`, `Is`, `TypeOf` | a class is one set of members |
| `Event`, `RaiseEvent`, `WithEvents`, `Implements` | no |
| collections, `For Each` over objects | arrays only |
| forms, controls, `MsgBox`, `InputBox` | screen and keyboard statements instead |
| file I/O (`Open`, `Print #`, `Get`, `Put`...) | planned as libraries |
| graphics, sound | planned as libraries / platform classes |
| date and time functions, `Format$` dates | no |
| `ReDim` with bounds from variables | constant bounds only |
| array parameters of 3+ dimensions | 1 or 2 dimensions |
| strings that grow as needed | fixed lengths: 40, or `String * n` / `String Max n` up to 255 |
| `Line Input` | `Input` into a String |
| overflow and subscript checks | none: numbers wrap, indexes are not checked |

---

## 19. Keyword index

| Keyword | Section |
|---|---|
| `#asm`, `#endasm` | [14](#asm--endasm) |
| `#Const` | [16](#const-1) |
| `#If`, `#ElseIf`, `#Else`, `#End If` | [16](#if--end-if) |
| `NTC`, `NTC_CPC`, `NTC_CPCFW`, `NTC_CPM`, `NTC_TEST` | [16](#if--end-if) |
| `&` | [7](#join-strings) |
| `+ - *` | [5](#add-subtract-multiply) |
| `/`, `\` | [5](#divide) |
| `^` | [5](#power) |
| `= <> < <= > >=` | [6](#compare) |
| `Abs` | [5](#abs) |
| `AddressOf` | [9](#addressof-calladdr) |
| `And` | [6](#and-or-xor-not) |
| `Asc` | [7](#chr-asc) |
| `Beep` | [11](#beep) |
| `Break` | [15](#break) |
| `ByRef`, `ByVal` | [9](#parameters-byval-byref-optional) |
| `Call` | [9](#call), [12](#call-machine-code) |
| `CallAddr` | [9](#addressof-calladdr) |
| `CBool`, `CByte`, `CInt`, `CLng` | [5](#cint-clng-cbyte-cbool) |
| `Chr$` | [7](#chr-asc) |
| `Choose` | [6](#choose) |
| `Cls` | [11](#cls) |
| `Const` | [3](#const) |
| `CStr` | [7](#str-cstr) |
| `Debug.Assert` | [15](#debugassert) |
| `Debug.Print` | [11](#print) |
| `Deek` | [12](#peek-deek) |
| `Dim` | [3](#dim), [4](#dim-arrays) |
| `Do`, `Loop` | [8](#do--loop) |
| `DoEvents` | [12](#doevents) |
| `Doke` | [12](#poke-doke) |
| `Else`, `ElseIf`, `End If` | [8](#if--then--else) |
| `End` | [8](#end-stop) |
| `Enum` | [3](#enum--end-enum) |
| `Erase` | [4](#erase) |
| `Error` | [15](#error) |
| `Exit` | [8](#exit) |
| `Fix` | [5](#int-and-fix) |
| `For`, `Next`, `Step` | [8](#for--next) |
| `For Each` | [8](#for-each--next) |
| `Format$` | [7](#format) |
| `Frame` | [11](#frame) |
| `Function` | [9](#function--end-function) |
| `Global` | [3](#private-public-global) |
| `GoSub`, `Return` | [8](#gosub--return) |
| `GoTo` | [8](#goto) |
| `Hex$` | [7](#hex-oct) |
| `If`, `Then` | [8](#if--then--else) |
| `IIf` | [6](#iif) |
| `Inkey`, `Inkey$` | [11](#inkey-inkey) |
| `Inp` | [12](#inp-out) |
| `Input` | [11](#input) |
| `InStr` | [7](#instr) |
| `InStrRev` | [7](#instrrev) |
| `Int` | [5](#int-and-fix) |
| `Interrupt` | [12](#interrupt) |
| `Join` | [7](#join) |
| `LBound` | [4](#lbound-and-ubound) |
| `LCase$` | [7](#ucase-lcase) |
| `Left$` | [7](#left-right) |
| `Len` | [7](#len) |
| `Let` | [3](#let-and-set) |
| `Like` | [6](#like) |
| `Locate` | [11](#locate) |
| `LSet` | [7](#lset-rset) |
| `LTrim$` | [7](#trim-ltrim-rtrim) |
| `Me` | [10](#10-classes) |
| `Mid$` | [7](#mid-function), [7](#mid-statement) |
| `Mod` | [5](#mod) |
| `Mode` | [11](#mode) |
| `New` | [10](#10-classes) |
| `Not` | [6](#and-or-xor-not) |
| `Oct$` | [7](#hex-oct) |
| `On ... GoTo`, `On ... GoSub` | [8](#on--goto-on--gosub) |
| `Optional` | [9](#parameters-byval-byref-optional) |
| `Option Base` | [4](#option-base) |
| `Option ClassSize` | [16](#option-classsize) |
| `Option Compare Text` | [6](#option-compare-text) |
| `Option Explicit` | [16](#option-explicit) |
| `Option Class` | [10](#option-class) |
| `Option Memory` | [16](#option-memory) |
| `Option Page`, `Option Home` | [10](#option-page) |
| `Option Buffer` | [16](#option-buffer) |
| `Option Reserve` | [16](#option-reserve) |
| `Option HighCode`, `Option Place` | [16](#option-highcode-option-place) |
| `Option Flavour` | [16](#option-flavour) |
| `Option Library` | [16](#option-library) |
| `Option RomEnable` | [16](#option-romenable) |
| `Option NoRomDisc` | [16](#option-noromdisc) |
| `Option Stack` | [16](#option-stack) |
| `Option Terminal` | [16](#option-terminal) |
| `Option NoTurbo` | [13](#option-noturbo) |
| `Option Turbo` | [13](#option-turbo) |
| `Option VBPrint` | [11](#option-vbprint) |
| `Or` | [6](#and-or-xor-not) |
| `Out` | [12](#inp-out) |
| `Peek` | [12](#peek-deek) |
| `Poke` | [12](#poke-doke) |
| `Print`, `?` | [11](#print) |
| `Private`, `Public` | [3](#private-public-global) |
| `Property Get / Let / Set` | [9](#property-get-property-let-property-set) |
| `Randomize` | [5](#rnd-and-randomize) |
| `ReDim`, `Preserve` | [4](#dynamic-arrays-and-redim) |
| `Rem`, `'` | [2](#lines-statements-and-comments) |
| `Replace` | [7](#replace) |
| `Right$` | [7](#left-right) |
| `Rnd` | [5](#rnd-and-randomize) |
| `RSet` | [7](#lset-rset) |
| `RTrim$` | [7](#trim-ltrim-rtrim) |
| `Select Case` | [8](#select-case) |
| `Set` | [3](#let-and-set) |
| `Sgn` | [5](#sgn) |
| `Space$`, `Spc` | [7](#space-spc-string) |
| `Split` | [7](#split) |
| `Sqr` | [5](#sqr) |
| `Static` | [3](#static) |
| `StdIO` | [17](#stdio) |
| `Stop` | [8](#end-stop) |
| `Str$` | [7](#str-cstr) |
| `StrComp` | [7](#strcomp) |
| `String$` | [7](#space-spc-string) |
| `String * n` | [7](#string--n) |
| `String Max n` | [7](#string-max-n) |
| `StrReverse` | [7](#strreverse) |
| `Sub` | [9](#sub--end-sub) |
| `System` | [17](#system) |
| `Tab` | [11](#tab-spc) |
| `Ticks`, `Timer` | [12](#ticks-timer) |
| `Trim$` | [7](#trim-ltrim-rtrim) |
| `True`, `False` | [3](#number-literals) |
| `Turbo On`, `Turbo Off` | [13](#turbo-on-turbo-off) |
| `Type` | [3](#type--end-type) |
| `UBound` | [4](#lbound-and-ubound) |
| `UCase$` | [7](#ucase-lcase) |
| `Val` | [7](#val) |
| `While`, `Wend` | [8](#while--wend) |
| `With` | [8](#with--end-with) |
| `Xor` | [6](#and-or-xor-not) |
