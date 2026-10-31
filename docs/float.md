# Float and Fixed - real numbers for NTC BASIC on the Z80 (built in)

Two library classes, in `src/lib/z80/`, that every Z80 platform has (not the 68000's or the
45GS02's). Like StdIO or System, they join a program when it names them: nothing to add to the
project. Using Fixed brings Float in too, since Fixed uses it.

| File | What |
|---|---|
| `Float.cls` | floating point: IEEE 754 **single** (32 bit, in a `Long`) and **half** (16 bit, in an `Integer`), plus `MulDiv` (a × b / c on Longs through 64 bits) |
| `Fixed.cls` | fixed point: **scaled integers**, the decimal point implied (1234 with 2 places is 12.34), 16 bit (`Integer`) and 32 bit (`Long`). Needs `Float.cls` |
| `test/float/FloatDemo.bas` | a short demo of both, arrays and matrices included |
| `test/float/` | the checks they were built against (below) |

NTC has no floating point type, so a value is just its bits in an ordinary variable:

```
Dim x As Long, y As Long
x = Float.FromText("3.14159")
y = Float.Multiply(x, Float.FromInt(2))
Print Float.ToText(y)                       ' 6.28318
```

## The shim: one class, any backend

The class compiled into a program is a **shim**. Every operation goes through one private
procedure, `Op`, which jumps through the class's own **jump block**: a table in RAM, one address
per operation (add, subtract, multiply, divide, the conversions, MulDiv, the array loop, the
matrix product). It's filled once, at the first operation:

- **The Z80 engine:** every entry points at the Z80 routines in the class. That's the default,
  and the only choice on platforms other than CyborgOS.
- **A coprocessor:** on CyborgOS the shim asks once with BDOS 131 op 40. If something answers,
  those entries point at the coprocessor forwarder instead. It fills a 48-byte request block (the
  operation, A, B, C, and for arrays their addresses, sizes and element operation) and makes one
  BDOS call per operation, whole arrays and matrix products included.

Who answers op 40:

| Machine | The coprocessor |
|---|---|
| vCPC | the vCPC itself, in C on its host (done) |
| CPC or Next with a Pi | C0 passes the request over the link to the Pi's `float` service (the service is done; C0's side of the link is CyborgOS's next step) |
| anything else | nobody: 255, so the Z80 engine |

The same `.CYB` runs on all of them, unchanged. If a coprocessor stops answering, the shim
switches itself back to the Z80 engine.

```
Float.UseEngine 0     ' auto (the default): a coprocessor if one answers, else the Z80 engine
Float.UseEngine 1     ' the Z80 engine only
Float.UseEngine 2     ' the coprocessor if there is one
Print Float.Backend() ' 1 the Z80 engine, 2 a coprocessor
```

All the backends give the same answers: IEEE single with no denormals and no NaNs, and Fixed's
rounding. The one difference: on an exact tie the last bit can differ, because the Z80 engine
rounds halves up while C and the Pi round them to even.

**Why a class and not native.** Native code would fix the arithmetic at compile time. The shim's
jump block lets the same compiled program use whatever is there. IEEE single was chosen because
that's what coprocessors and hosts speak, so nothing is converted on the way. The cost is a call
per operation, which the array and matrix calls spread over whole arrays. If NTC later gets a
native `Single`, the compiler could map `+ - * /` onto these calls and keep the seam.

The Z80 engine is one block in the class: NTC drops procedures nobody calls, so helpers in
procedures of their own would vanish.

## The Pi's float service

`pi/svc/float.js` in CyborgOS, served by `cosd` (the protocol is `docs/cyborgos-pi.md`). It's a
text request plus a binary body, little end first, answered with `OK` plus the result's bytes and
an overflow byte:

| Request | Body | Answer's body |
|---|---|---|
| `OP n` (n as the engine: 1-4 + - × /, 5 from a Long, 6 to a Long, 7 negate, 8 absolute, 9/10 half, 11 MulDiv) | A, B, C | the answer, overflow |
| `ARR eop es bk n` | scale, k, A (n elements), B (n elements, unless bk = 1) | D, overflow |
| `MAT eop es r k c` | scale, A (r × k), B (k × c), rows first | D (r × c), overflow |

- **eop:** 1-4 single + - × /, 5-8 fixed + - × / (scale = 10^places).
- **es:** 4 for Long elements, 2 for Integer (read sign extended, written back clamped).
- **The fixed matrix product** sums the exact products and rounds once, as the engine does.

It's ES5, with the 64-bit integer parts done exactly in 16-bit pieces. CyborgOS's
`pi/test/run.js` checks it over a link: divide, overflow, MulDiv and its clamp, half, a matrix
product, the fixed dot product's single rounding, and 16-bit clamping.

## Float: single (32 bit) and half (16 bit)

| | single | half |
|---|---|---|
| bits: sign / exponent / mantissa | 1 / 8 (bias 127) / 23 (+ hidden 1) | 1 / 5 (bias 15) / 10 (+ hidden 1) |
| significant digits | about 7 (ToText shows 6) | about 3 |
| range | 1.2E-38 to 3.4E+38 | 6.1E-05 to 65504 |
| kept in | `Long` | `Integer` |

**Single:** `FromInt`, `ToInt` (towards zero), `ToIntRound` (nearest, halves away from zero),
`Add`, `Subtract`, `Multiply`, `Divide`, `Negate`, `Absolute`, `Compare` (-1 / 0 / 1), `IsZero`,
`ToText`, `FromText` (`-12.5`, `.25`, `1.5E-3`), `Overflow`.

**Half:** `ToHalf` / `FromHalf` (single to half and back), `HFromInt`, `HToInt`, `HAdd`,
`HSubtract`, `HMultiply`, `HDivide`, `HToText`, `HFromText`. Half is worked as a single and
rounded back: tiny code, exact results for the format.

**MulDiv(a, b, c):** a × b / c on Longs, with a 64-bit product in the middle, rounded. It's what
Fixed uses for its 32-bit multiply and divide, and useful on its own (scaling, percentages).

**Behaviour:**
- **Rounding:** to nearest, halves up. IEEE says halves to even, so on an exact tie the last bit
  can differ by one.
- **Accuracy:** checked against IEEE single computed independently in Python, bit for bit, on
  random operands across magnitudes and signs (`tests/chk.py`). Every add, subtract, multiply and
  divide was exact or within 1 unit in the last place.
- **Limits:** no denormals (too small becomes 0) and no NaNs. Too big, or dividing by zero, gives
  infinity.
- **Overflow:** `Overflow()` is True when an answer didn't fit (infinity, or a whole number that
  was clamped). It stays set until you ask, so one check after a whole calculation covers every
  step, and asking clears it.

**Speed** at 4 MHz, including the BASIC call: Add about 1 ms, Multiply and Divide about 3.3 ms,
MulDiv about 9 ms. This is the first, straightforward version. Multiply and divide run as
memory-based loops and can be made several times faster with a register-based inner loop.

## Binary scales: to and from the 3D engine's numbers

E3 (NTC3D) keeps its numbers as binary fixed point: the camera's matrix in s1.14 (16384 is 1),
positions in 24.8, model directions in s.7. Float converts to and from these exactly, because
multiplying or dividing by a power of two only moves the exponent:

| | |
|---|---|
| `ToBinScaled(f, bits)` | a single × 2^bits, rounded to a whole number (halves away from zero), as a Long |
| `FromBinScaled(n, bits)` | a whole number ÷ 2^bits, as a single |
| `MToBinScaled d, a, bits` | a whole array of singles into an Integer array in one call (clamped to ±32767, `Overflow`), e.g. a 3×3 matrix to s1.14 |
| `MToBinScaledL d, a, bits` | the same into a Long array, e.g. positions to 24.8 |

The array conversions run in the Z80 engine and are never sent to a coprocessor: they're cheap,
and a round trip would cost more than they do.

The intended split for a 3D game:
1. **In Float:** the maths that needs range or precision, done less often: orbits, physics,
   camera paths, building a matrix from several rotations.
2. **Converted once** per frame or per object with one array call.
3. **Handed to E3,** which keeps doing the per-vertex work in its own fast integers. Float is far
   too slow for per-vertex work on a Z80.

```
Dim m(2, 2) As Long, mm(2, 2) As Integer, p(2) As Long, pp(2) As Long, k As Integer
' ... m: the camera's rows (right, up, forward) as singles; p: its position ...
Float.MToBinScaled mm, m, 14
For k = 0 To 8
  E3.cm(k) = mm(k \ 3, k Mod 3)
Next
E3.CamSet                                  ' squared up, its copies worked out
Float.MToBinScaledL pp, p, 8
E3.CamPosL pp(0), pp(1), pp(2)
```

This was checked inside a running ROCKS on the Next emulator. Every frame, the camera went out of
E3, through Float and back: the conversions were exact both ways (s1.14 and 24.8), and `CamSet`'s
squaring-up moved the matrix by at most 2/16384.

In s.7, 1.0 comes out as 128, while E3's 8-bit values stop at 127 (its sine table's 1.0). E3's
entry for an object's own matrix, its next step, will clamp to 127.

## Whole arrays and matrices: one call

Each operation also works on whole arrays at once. The loop runs in Z80 inside the engine, so
there's no BASIC call per element. Arrays can have 1 or 2 dimensions (2-D is stored row by row),
fixed or dynamic. The destination may be one of the sources.

| | Float (single, `Long` arrays) | Fixed 32 (`Long` arrays) | Fixed 16 (`Integer` arrays) |
|---|---|---|---|
| D(i) = A(i) + B(i) | `MAdd D, A, B` | `MAdd32` | `MAdd16` |
| D(i) = A(i) - B(i) | `MSubtract` | `MSub32` | `MSub16` |
| D(i) = A(i) × B(i) (element by element) | `MMultiply` | `MMul32` | `MMul16` |
| D(i) = A(i) / B(i) | `MDivide` | `MDiv32` | `MDiv16` |
| D(i) = A(i) × k | `MScale D, A, k` | `MScale32` | `MScale16` |
| D(i) = A(i) + k | `MOffset D, A, k` | `MOffset32` | `MOffset16` |
| matrix product: D (R×C) = A (R×K) · B (K×C) | `MatMul(D, A, B)` | `MatMul32` | `MatMul16` |
| dot product: Σ A(i) × B(i) | `Dot(A, B)` | `Dot32` | `Dot16` |

- **Counts:** the element-by-element operations cover D's elements (A and B need at least as many).
- **Matrix product:** `MatMul` returns False, doing nothing, when the sizes don't fit together.
- **Fixed sums of products:** the matrix and dot products add the **exact** products in 64 bits
  and round to the places once per result, so 0.625 + 1.25 + 1.875 + 2.5 gives 6.25, not the 6.26
  that rounding each product would give.
- **Clamping:** results that don't fit are clamped and reported by `Float.Overflow()` /
  `Fixed.Ok()`, as for single values. 16-bit results clamp to ±32767.
- **Integer maths:** with `Fixed.SetPlaces 0`, the Fixed versions are plain integer arithmetic:
  integer matrix products, element-wise operations and dot products, clamped instead of wrapping.

```
Dim a(1, 2) As Long, b(2, 1) As Long, d(1, 1) As Long
' ... fill a and b with Float values ...
If Float.MatMul(d, a, b) Then Print Float.ToText(d(0, 0))
```

**Speed:** a 4×4 single-precision matrix product is about 108 ms at 4 MHz in one call, against
about 194 ms through 64 Multiply and 64 Add calls from BASIC. The saving is the call overhead; the
arithmetic is the same.

The array calls are also the natural unit for a coprocessor: a whole matrix product handed over
in one request instead of 128.

## Fixed: scaled integers

A Fixed value is an ordinary `Integer` or `Long` holding the number × 10^places. Adding,
subtracting and comparing are BASIC's own `+ - < =`, at whole-number speed. The class provides
what needs the point put back: multiply, divide, conversions and text. All of it rounds halves
away from zero.

```
Fixed.SetPlaces 2                           ' everything after uses 2 places (money)
a = Fixed.Val32("19.99") : n = Fixed.FromInt32(3)
Print Fixed.Text32(Fixed.Mul32(a, n))       ' 59.97
```

**What fits,** the largest value either way:

| places | 16 bit (`Integer`) | 32 bit (`Long`) |
|---|---|---|
| 0 | 32767 | 2147483647 |
| 1 | 3276.7 | 214748364.7 |
| 2 | 327.67 | 21474836.47 |
| 3 | 32.767 | 2147483.647 |
| 4 | 3.2767 | 214748.3647 |
| 5-9 | left out | 21474.83647 down to 2.147483647 |

16-bit with 5 or more places has nothing left of the decimal point, so it isn't offered: those
calls return 0 and set `Ok()` False. Anything else that doesn't fit is clamped to the largest
value and sets `Ok()` False, which, like `Float.Overflow`, stays set until asked.

**Methods,** each with a 16 and a 32 version:
- `Add`, `Sub`: the overflow-checked forms; plain `+` and `-` are fine when you know it fits.
- `Mul`, `Div`.
- `FromInt`, `ToInt` (towards zero), `Round`.
- `Text`, `Val`.
- `Float` and `FromFloat` (to and from a Float single).

`SetPlaces`, `Places`, `Scale` and `Ok` are shared. The places default to 2 if never set.

`Mul16` and `Div16` work in 32 bits; `Mul32` and `Div32` in 64 bits (`Float.MulDiv`). Nothing is
lost on the way, only the final rounding to the places.

## BCD: discussion

BCD keeps each decimal digit in a nibble (packed: two digits a byte).

**For it:**
- **Exact decimals.** 0.1 is exactly 0.1, and money adds up the way people expect. Neither
  binary float nor any binary format can do that.
- **Cheap text.** Printing a BCD number is reading nibbles, with none of the multiply/divide by
  ten that `Float.ToText` does. For programs that mostly display numbers, that matters.
- **The Z80 helps.** `DAA` corrects A after a binary add or subtract into two BCD digits, and
  `RLD` / `RRD` rotate nibbles between A and memory, which is exactly a digit shift. BCD add and
  subtract are short, quick loops.
- **Calculator behaviour.** Rounding happens where a person would expect it.
- **Precision is just length.** 14 digits costs 7 bytes of digits; more digits, more bytes.
- **The MSX already speaks it.** MSX-BASIC's numbers are BCD floats: single is 4 bytes for 6
  digits, double 8 bytes for 14 digits. The MSX BIOS has a maths pack for them. On an MSX, a BCD
  class could hand its work to the BIOS through the same kind of `Op` seam as Float: the BIOS acts
  as the coprocessor. MSX-BASIC's own data would also read straight in.

**Against:**
- **Multiply and divide are slower:** digit-serial, repeated adds and subtracts per digit.
- **Less dense:** 100 values per byte against 256, so a 4-byte BCD single holds 6 digits where a
  binary single holds about 7.
- **No hardware help elsewhere:** coprocessors and hosts don't work in BCD. The x87 could only
  load and store it.
- **Doesn't fit NTC's types.** A 4-byte BCD fits a `Long`, like Float. An 8-byte one would need a
  `String * 8` or a Byte array with ByRef parameters.

**Where each fits:**
- **Float:** science, graphics, physics, anything where range matters more than exact decimals.
- **Fixed:** money and measurements within its range. With 2 places in 32 bits, amounts up to
  ±21 million are exact and at whole-number speed. This covers most of what BCD is usually wanted
  for.
- **BCD:** exact decimals beyond Fixed's range, calculator-style programs, or MSX compatibility.

**If BCD is wanted,** I'd suggest the MSX formats: a 4-byte single (6 digits, in a `Long`) and an
8-byte double (14 digits). Each would have a Z80 engine behind one `Op`, the same as Float, using
`DAA` / `RLD`, with the MSX BIOS maths pack as its "coprocessor" on the MSX.

## Testing

The classes were built and checked with NTC's test harness (`test/ntcrun.py --platform=test`, a
plain Z80 with a text screen):

- `test/float/chk.py [seed]`: random add, subtract, multiply and divide, compared with IEEE single
  computed in Python. Run it from anywhere with the NTC test folder at
  `/home/claude/ntc/test`; change the path at the top for yours.
- `test/float/t3.bas` (Float: conversions, text, half, MulDiv, overflow), `test/float/t5.bas` (Fixed),
  `test/float/t7.bas` (Float arrays and matrix product) and `test/float/t8.bas` (Fixed arrays: integers,
  16 and 32 bit), `test/float/t9.bas` (binary scales), with their expected output in `test/float/*.txt`.

On CyborgOS the same test sums were also run through the shim on a vCPC, with the Z80 engine and
then the vCPC's coprocessor (op 40): the outputs were identical, matrix products and clamping
included.

Checked with the NTC of 31 October 2026 (the one with Galaxy3D and Radar3D). The only compiler features used are `#asm`
keyword procedures, `@`-free local labels (`NAME: EQU`), `ntc_ip` / `ntc_csp` and `Long`, all
long-standing.

(c) 2026 Cyborg Unicorn Pty Ltd - MIT License
