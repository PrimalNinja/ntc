# NTC library: what drags in what

(c) 2026 Cyborg Unicorn Pty Ltd

Two things make a program carry library code it has no use for. Both are listed here so they can be
fixed one at a time. The figures were measured on 16 November 2026 (cpcfw unless it says otherwise) by
compiling a program that makes the one call and taking away a program that makes none.

How the removal works today:

| What | Left out when unused? |
|---|---|
| a BASIC `Sub` / `Function`, class methods included | yes: compiled for its errors, then dropped |
| a library section (`;## name` in `src/asm/ntc_lib*.asm`) | yes: only the sections used are linked |
| the routines inside one section | no: a section comes whole or not at all |
| the code inside one `#asm` block | no: a block is one piece |

So the unit of removal is the procedure and the section. Anything bigger than one job in a single
section or a single `#asm` block is carried whole.

## 1. Calls between classes that should not be there

A class that calls another class brings that class's code with it.

| From | To | Calls | What it drags in | Cost |
|---|---|---|---|---|
| `Fixed` (`Mul32`, `Div32`, the array, matrix and dot routines, the float conversions) | `Float` (`MulDiv`, `ArrayOp32`, `ArrayOpK32`, `MatOp32`, `DotOp32`, `ArrayOp16`, `FromInt`, `Divide`, `Multiply`, `ToIntRound`, `Overflow`) | 50 | the whole floating point engine, for a 64 bit multiply / divide | about 4.5K (4302 bytes of code, 248 of work arrays) for one `Fixed.Mul32` |
| `List` (every method) | the Memory class's core (`ntc_memcore`) | - | all of Memory: the heap, the page handling, its tables | 2.2K of the 3.4K one `List.Create` adds |
| `FileSystem` on cpcfw / cpcmin (`Load`, `Open`, `Read` ...) | the ROM disc code written into the same methods | - | the ROM disc routing | was 1.1K to 1.3K in every program that used files. **Done 20261116-5:** the ROM disc is the `ROMDiscFS` class; `FileSystem` has none of it |
| `Memory.Copy`, `List.Sort` | the library's 2K buffer | - | the buffer | 2K (`Option Buffer address, size` moves or shrinks it; `List.Sort` needs all of it) |

Not wastage (only the routines called are linked): `Net` -> `Trit` (`Dot`), `Tree` -> `Trit`
(`ToByte`, `FromByte`), `Net` -> `Tiny`. `Fixed.Mul16` / `Div16` carry their own small multiply and
divide and do not touch `Float`.

What each needs:

- **Fixed -> Float:** the 64 bit multiply / divide (`md_mul`, `md_div` and their helpers) as a
  piece of its own that both classes use, so Fixed never brings the float engine.
- **List -> Memory:** follows from splitting Memory (below).
- **FileSystem -> ROM disc:** done (20261116-5). The ROM disc is a class of its own, `ROMDiscFS`;
  `FileSystem` has no ROM disc code and `Option NoRomDisc` is gone. (A `RAMDiscFS` of the same
  shape can follow later.)

## 2. Big assembly blocks that hold several functions

Each of these should have a conditional round each function, so that only the ones the program
calls are assembled. The way to do it without cutting the block up: the compiler writes a symbol
for every procedure that is left after removal (for example `NTC_USED_Float_Add equ 1`) at the top
of the assembly, and the block tests them (`IFDEF NTC_USED_Float_Add` ... `ENDIF`; a shared helper
tests every routine that uses it; a jump table is conditional entry by entry). The library already
does this in two smaller ways: sections marked `@if:` (the Memory class's scheme) and
`IFDEF NTC_ZXNDOTL` / `NTC_DOT_FS` in the dot platform.

| Where | What is in the one block | Any one call brings | Cost seen |
|---|---|---|---|
| `Float.cls`, `Private Function Op` (one `#asm` block) | the whole engine: add, subtract, multiply, divide, compare, the conversions, `MulDiv`, the array / matrix / dot operations, the jump table, the coprocessor forwarder | all of it | about 4.3K; with a coprocessor in use the Z80 engine is still all there (about 4K unused) |
| `ntc_lib.asm` / `ntc_lib_cpc.asm`, section `ntc_mem` (CPCExpansion: about 1,000 lines) with `ntc_memcore`, `ntc_membank` | pages (`AllocPage`, `FreePage`, `SelectPage`, the probe, the tables), the heap (`Alloc`, `Free`, `Largest`), the 64K banks (`AllocBank`, `CallBank` ...) | all of it | 2185 bytes for `Memory.Alloc` alone, 2181 for `Memory.AllocPage` alone (777 with `Option Memory Heap Main`) |
| section `ntc_list` | every List routine | all of it | about 1.2K |
| section `ntc_gfx` (CPC), the Next's `ntc_gfx` | `Plot`, `Line`, `Pen`, `Clip`, the buffer code | all of it | 892 bytes for `Plot`, 902 for `Line` |
| `ntc_plat_cls` on cpm (20261116-4) | Cls and Locate for all four terminals | all four when `StdIO.SetTerminal` is used, or any `Option Terminal` | about 250 bytes |

Clean already: the keywords (each `kw_` routine is its own section: a `Print` only program is a few
hundred bytes), `Keys.Down` (161 bytes), the Trit operations.

Not measured yet: the Next's, the MSX's and the other platforms' classes, `V9990`, `VDP`, `Sound`.
