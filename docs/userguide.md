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
17. [Platforms and the console classes](#17-platforms-and-the-console-classes) (StdIO, System, FileSystem)
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
classic BASIC. If there is a `Sub Main`, it runs after the top level code.

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

`Option Class Resident` | `Option Class Overlay` [`"FILE"`] | `Option Class Interrupt` *rate* | `Option Class Interrupt Frame`

In a `.cls` file: what kind of class it is. Without it (or `Resident`) the class is part of
the program as above.

**Overlay** (cpcmin, cpcfw, cpm): two ways, depending on `Option Memory` - RAM pages
(cpcmin, cpcfw with `Option Memory CPCExpansion`, the default there), described first, or
[one overlay area](#one-overlay-area) (cpm, and cpcmin / cpcfw with `Option Memory Small`).

With RAM pages, the class's
code is built, in the same compile, into its own file `FILE.PAG` (the class name, up to 8
characters, when no name is given), to run at `#4000` in a RAM page (a C page, see
[Memory](#memory)). Its variables stay in the program, so they keep their values when the
page goes. Calling one of its procedures switches its page into the window and back again
afterwards (the page that was there before - a data page the program selected stays
selected); the first call loads the file into a free C page. So a program can be bigger than
memory, a module or a level at a time.

```
' Level1.cls
Option Class Overlay "LEVEL1"
Public Function Play(ByVal score As Integer) As Integer
  Banner "Level 1"            ' a Sub in the main program
  Play = 100
End Function

' Main.bas
Option RomEnable 7              ' RUN" drops AMSDOS: start it, the overlays load from disc
Option Reserve &H4000, &H4000   ' the program stays out of the window overlays run in
score = Level1.Play(0)          ' loads LEVEL1.PAG into a page, then runs Play
```

The compiler adds these members to an overlay class (so these names are taken):

| Member | Does |
|---|---|
| `Load()` | loads its file now (nothing if it is loaded): `OK` (0), a FileSystem status (`NotFound` -2, `TooBig` -8 ...), or -12 (no page free) |
| `Unload()` | its page back to free; the next call loads the file again |
| `Loaded()` | True when it is in RAM |
| `Page()` | the page it is in, 0 = not loaded |
| `LocalStart()`, `LocalSize()` | its local memory: the rest of its page |
| `LocalAlloc(size)`, `LocalFree(address)` | blocks of its local memory |

- A call that has to load and can't prints `Overlay not loaded: LEVEL1.PAG`, why (`No RAM
  page free` / `The file didn't load`) and `Press a key`, then ends the program (a program
  started with `RUN"` then resets). Call `Load()` first to handle it yourself.
- Keep the `.PAG` files on the disc with the program's `.BIN`. They are binary files with an
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
  window, so only the class's own code can use them. Paged Strings are in the `.PAG` file
  (their capacity byte goes with them); other paged variables are not in the file - they are
  cleared when it loads.
- **Local memory:** the rest of the page, after the code and page variables, is the class's
  own: `LocalStart()` and `LocalSize()` say where, and `LocalAlloc(size)` / `LocalFree(address)`
  hand out blocks of it (plain addresses, 0 = no room). Only from the class's own code (from
  anywhere else `LocalAlloc` gives 0). Copy a list node in with
  `Memory.Copy(List.Data(node), CLng(Page()) * 65536 + address, size)`.
- Not yet: one interface for several files (VB's `Implements`, for levels that swap), and
  classes built on their own for any program (like DLLs).

#### One overlay area

On CP/M, and on cpcmin / cpcfw with `Option Memory Small` (a 64K CPC, or a program that wants
no RAM pages), there is one overlay area, `#4000-#7FFF`, and one overlay class in it at a
time. A call to a class that isn't there loads its file over the one that was. When the call
returns into another overlay class's code that was swapped out meanwhile, that class is
loaded again first. So level 2 calling level 1 loads `LEVEL1.PAG`, and the return loads
`LEVEL2.PAG` again: calls between overlay classes cost a disc load each way. Calls from the
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
| Files | `.PAG` with an AMSDOS header | the same on the CPC; plain bytes on CP/M (`LEVEL1.PAG` next to the `.COM`) |

The compiler keeps the program and the Memory heap out of `#4000-#7FFF` for overlay
classes (as `Option Reserve &H4000, &H4000`). A file that isn't there stops the program with
`Overlay not loaded: LEVEL1.PAG` / `The file didn't load` / `Press a key`.

**Interrupt** *rate* / **Interrupt Frame** (cpc, cpcmin: NTC's own interrupt handler): the
class's `Sub Tick()` (no parameters - it must have one) runs *rate* times a second (1 - 300),
or once a frame (just after the vertical sync), while the program does its own thing.

```
' Clock.cls
Option Class Interrupt 1
Public Seconds As Integer
Public Sub Tick()
  Seconds = Seconds + 1
End Sub
```

- Up to 4 interrupt classes. The interrupt (300 a second) only counts and marks a class as
  due; `Tick` runs at the program's next safe point, like [Interrupt](#interrupt) - so it is
  ordinary BASIC, and can use anything. Classes of the same rate take turns (they don't fall
  on the same interrupt).
- Normal mode only: in turbo mode there are no safe points, so `Tick` waits.
- A `Tick` that is still running when it is due again runs again after it returns.
- Keep `Tick` short: it runs between the program's own statements.
- Interrupts wait while a keyword runs. Text drawing (cpc, cpcmin) lets a waiting interrupt in
  after each character, so printing doesn't hold them off; a `Frame` class counts 6
  interrupts a frame as well as watching the sync, so it keeps 50 a second when an interrupt
  is taken late.
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
`Interrupt Off` stops it. Normal mode only, and only on the CPC hardware platform (it needs
the program's own interrupt handler; `System.HasHook` says whether it works).

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
(an empty loop); a sieve or a sort 25-40%. `NTC.md` section 3 has the measurements, with
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
- Labels in a block are local to it.
- Library routines the block names are linked in.
- The rules of the run time apply: SP is the thread, so no `call` / `push` unless SP is
  first switched to the real stack (`ld (ntc_ip), sp` / `ld sp, (ntc_csp)` / ... /
  `ld sp, (ntc_ip)`); no register keeps its value between keywords; interrupts are off.
- A block that loads SP (`ld sp, ...`) is a jump; the compiler makes a normal mode copy of
  it.

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

The program is not moved around a reserved range: it starts at the org and goes up, so a
range has to be above its end (or below its start). On the `cpc` platform the font copy
code goes to #C000 for a moment when the screen is first used (a warning says so when a
range covers #C000).

**VB:** not in VB.

### Option RomEnable

`Option RomEnable All` / `Option RomEnable` *rom* [`,` *rom*] ...

CPC firmware platforms (`cpcfw`, `cpcmin`) only. `RUN"NAME` of a binary resets the firmware, and the
background ROMs - AMSDOS (ROM 7) and any others - are dropped. With this option the program
starts them again before anything else: `All` starts every background ROM (KL ROM WALK), a
list starts those ROM numbers (KL INIT BACK). The ROMs take their RAM from `#ABFF` down, so
the program must end below `#A600` (checked when assembling). If the ROMs are still running
(the program was loaded from BASIC and CALLed), nothing is started again.

Without the option nothing is started: a program started with `RUN"` has no AMSDOS (files
go to tape); one CALLed from BASIC keeps whatever was running.

```
Option RomEnable 7          ' AMSDOS: FileSystem.Load / Save go to disc after RUN"
```

On other platforms it gives a warning and does nothing.

**VB:** not in VB.

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
(`NTC_CPC`, `NTC_CPCFW`, `NTC_CPM`, `NTC_TEST`). With `Option Terminal` it also defines
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
| Amstrad CPC, no firmware | `cpc` | a binary at `#0040` (`RUN"name` from AMSDOS), ROMs off, own interrupt handler; no firmware at all - every byte from `#0040` to the stack is the program's; no files | drawn by the program, with the CPC's own font (copied from the ROM at start) | full screen, keys from the matrix |
| Amstrad CPC, minimal firmware | `cpcmin` | as `cpc` (own screen, keys, interrupts), but the firmware is kept alive (its RAM `#A700-#BFFF` left alone) and handed back for each firmware call: discs and tape (`FileSystem`), other ROMs' commands (`System.Command`) | as `cpc` | as `cpc` |
| Amstrad CPC, full firmware | `cpcfw` | a binary at `#0040` (`RUN"name`), firmware left running (AMSDOS, RSXs, windows) | firmware `TXT OUTPUT` | full screen, firmware keys |
| CP/M 2.2 / 3 | `cpm` | a `.COM` file at `#0100`, ends with a warm boot | BDOS direct console I/O | a stream, or 80 x 24 with [Option Terminal](#option-terminal) |
| Test harness | `test` | for the emulator in `test/ntcrun.py` | I/O ports | 40 x 25, like CPC mode 1 |

The BASIC is the same on all of them. What changes is the start-up, the console and what
the `StdIO`, `System` and `FileSystem` classes report.

The three CPC platforms are three amounts of firmware: `cpcfw` uses it for everything (the
easiest, and all ROMs work); `cpcmin` draws and reads the keyboard itself (faster text, NTC's
own interrupt handler) and keeps the firmware only for discs, tape and ROM commands; `cpc`
uses none (all the RAM, no files). On `cpcfw` and `cpcmin`, `RUN"` of a binary drops AMSDOS
and the other ROMs: [Option RomEnable](#option-romenable) starts them again. While a
`cpcmin` firmware call runs, the screen may show the firmware's mode, and firmware messages
(disc missing, Retry / Cancel, Press PLAY) appear on the screen; afterwards NTC's mode,
screen start and interrupt handler are back.

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

| Member | cpc | cpcfw | cpm | test |
|---|---|---|---|---|
| `Platform` | "CPC" | "CPC firmware" | "CP/M" | "Test" |
| `CpuClock` (kHz, 0 = not known) | 4000 | 4000 | 0 | 4000 |
| `TicksPerSecond` (0 = no clock) | 300 | 300 | 0 | 300 |
| `FrameRate` (0 = not known) | 50 | 50 | 0 | 0 |
| `HasInterrupts` (normal mode lets interrupts in) | True | True | True | True |
| `HasHook` (the `Interrupt` statement) | True | False | False | False |
| `HasScreen` (rows and columns, not a stream) | True | True | False* | True |
| `HasKeyboard` | True | True | True | True |
| `MaxHandles` (file handles, `FileSystem.Open`) | 0 | 0 | 2 | 0 |
| `Ticks()` | the tick count, the same as `Ticks` | | | |
| `Command(name)` | run a ROM's command (an RSX, `|NAME`, no arguments) - cpcfw and cpcmin only: 0, or -2 when no ROM has it; -1 elsewhere | | | |
| `HasCapability(name)` | True (-1) when the platform can do it, else False - see below | | | |
| `CommandLine()` | what was typed after the program's name - CP/M only (`A>PROG FILE.TXT` gives `"FILE.TXT"`, in capitals as CP/M passes it); "" elsewhere | | | |

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
| `HOOK` | the `Interrupt` statement | True | True | - | - | - |
| `INTERRUPTCLASSES` | `Option Class Interrupt` | True | True | - | - | - |
| `PAGES` | RAM pages (`Option Memory CPCExpansion`) | True | True | True | - | - |
| `FILES` | `FileSystem` Load / Save (more: `FileSystem.Capability`) | - | True | True | True | - |
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
| `LOAD`, `SAVE` | whole file to / from memory | - | True (cpcmin too) | True | - |
| `SEQUENTIAL` | `Open`, read and write in order | - | - | True | - |
| `RANDOMACCESS` | `Seek` anywhere, read and write | - | - | True | - |
| `DELETE`, `RENAME`, `EXISTS`, `SIZE` | those methods | - | - | True | - |
| `MULTIPLE` | more than one file open at once | - | - | True | - |
| `DEVICES` | `Devices`, `SelectDevice`, `CurrentDevice` | - | True | True | - |
| `VOLUMES` | `Volumes`, `SelectVolume`, `CurrentVolume` | - | True | True | - |
| `CPMVERSION` | BDOS's version: `&H22` CP/M 2.2, `&H31` CP/M 3 | - | - | yes | - |
| `MAXOPEN` | how many files can be open | 0 | 0 | 2 | 0 |
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
| `Open(name, mode)` | a handle; mode `ForRead` (1), `ForWrite` (2, a new file), `ForUpdate` (3, read and write) |
| `Close(h)` | |
| `ReadByte(h)`, `WriteByte(h, b)` | `ReadByte` gives 0-255 or `EndOfFile` |
| `Read(h, address, count)`, `Write(h, address, count)` | bytes to / from memory; `Read` gives how many it got |
| `Seek(h, position)` | the next read or write is at that byte (a Long, 0 = the start) |
| `Eof(h)` | True when there is nothing more to read |
| `ReadLine(h)`, `WriteLine(h, text)` | a line of text (CR LF or LF ends it, not kept) |
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
  `LOAD "HISCORE.DAT", &4000` it. Uses a 2K buffer. Devices `TAPE` and `DISC` (`|TAPE`,
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
- **CPC minimal firmware** (`cpcmin`): the same as `cpcfw` (Load / Save, devices, volumes), each
  call handed to the firmware for its length.
- **CPC, no firmware** (`cpc`) and **test**: no files - every method returns `NotSupported`.

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
| `TypeFree` | - | not allocated | |

Every page is on one list: free, C, D, I or U. Free pages come from two lists - main RAM and
the standard 512K for C, I and U pages, the blocks above it for D pages (the heap) - and each
falls back to the other. So on a big machine a growing heap uses the upper blocks and leaves
the standard 512K for code, music and levels; on 576K or less it is all one list.

The program, and its stack, must be out of the window - switching a page in would hide
them. `Option Reserve &H4000, &H4000` checks that when assembling. A program in the window
gets `Pages() = 0`. Anything the program reads or writes in the window (`Poke`, `Peek`,
`FileSystem.Load`) goes to the page in it at that moment: that is how a page is filled from
a file. Use `Memory.WindowStart` and `Memory.WindowSize` rather than `&H4000`: they are
constants, worked out when compiling.

The class's tables (3 bytes a page: a 6128 15 bytes, 4MB 771) go from the program's end
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
| `Top()` | the platform's top of free RAM: CPC `#A600` (the firmware above), CP/M the end of the TPA (the BDOS), test `#C000` |
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
| `Option Reserve` | [16](#option-reserve) |
| `Option RomEnable` | [16](#option-romenable) |
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
