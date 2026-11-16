# NTC memory map: how it should work

(c) 2026 Cyborg Unicorn Pty Ltd

## Terms

A memory word that is not fully explicit (for example "Next bank") is the NTC / COS / CPC term.

| What it is | NTC / COS | CPC | Next | MSX |
|---|---|---|---|---|
| 8K piece of RAM | - | - | page | - |
| 16K piece of RAM | page | block | bank | segment (memory mapper) |
| 64K of RAM switched as one | slot | bank | - | (a slot's whole 64K) |
| position in the address space | - | - | slot (8K) | page (16K, 0 to 3) |
| where the memory comes from | - | - | - | slot (primary / sub-slot) |

## The rules

1. **Safe code goes in the Safe areas,** all of them, not just the first. Place it procedure by
   procedure, first fit, each procedure whole in one range. A procedure that fits in no range is an
   error that names it.
2. **Unused Safe space goes back to Available.** Any part of a Safe range, or a whole range, that
   safe code doesn't use is shrunk or dropped.
3. **Report what went where:** each page and where its paged code went, the Safe ranges and what's in
   them, and where the main program, its data and the stack ended up.
4. **Fill from the org upward, skipping only Reserved.** Available is implicit: everything not
   Reserved is available. A programmer may write `Option Memory Available` for documentation, but
   doesn't have to.
   - **Reserved** is a gap of its size that the build goes round.
   - **Safe** is available memory that's never under a page: an explicit Available.
   - **Paged** is where pages swap in. Only code may sit under it, never data, the stack or the
     switching code. See the notes.

## Reserved

`Option Memory Reserved` *start*`,` *size* [`,` *start*`,` *size*] ...

One form. The gap is in the built file, filled with 0 at build time, and the file loads and runs
as it is. (ZeroFill | Skip are gone, 20261116-1: there is no packed file and no loader that moves
code up.) Reserve a range for a reason - a second screen, firmware RAM, a ROM's workspace, a load
area. Memory that is not Reserved is used.

## A typical CPC map (cpcmin)

| Range | Kind | Notes |
|---|---|---|
| #0040-#3FFF | Safe | |
| #4000-#7FFF | Paged | paging from 1 |
| #4000-#7FFF (base block 1) | Reserved if paging starts at 0; not reserved if paging starts at 1 | a good place for video RAM |
| #8000-#A5FF | Safe | |
| #A600-#BFFF | Reserved | the firmware |
| #C000-#FFFF | Safe, for 16K more code; or Reserved, for more video RAM | |

**Double buffering:** two video RAMs, base block 1 at #4000 and #C000. Draw into one while the CRTC
shows the other, and flip with R12 (&10 shows #4000, &30 shows #C000).

## Notes

- **Video RAM in base block 1** works because the CRTC always reads the base 64K, whatever the gate
  array has in the window. The screen stays on while a page is in. Drawing to it needs base block 1
  in the window, so paging has to start at 1, and the map needs a way to say so.
  `Option Memory Paged startbank, addr, size` says so: `Option Memory Paged 1, &H4000, &H4000`
  (the start bank first and always there, as the old `Option Page` had it: 20261116-3).
- **Firmware RAM:** on `cpcmin` it's #A600-#BFFF, not #A000. On `cpc` (no firmware) there's nothing
  to reserve there.
- **Never under Paged:**
  - variables, strings, literals, arrays, the stack, the library's buffer: paged code reads them
    while its page is in;
  - the stubs, `ntc_ovl_enter`, `mem_sel`, the Memory class's switch, interrupt handlers and the
    Tick dispatch: they must be Safe.
- **Code under Paged** is page 0. A call from it to a paged procedure works, because the stub puts
  page 0 back on return. A call from it to a paged asm keyword (`ntc_ovl_kwin` / `kwback`) works
  too since 20261107-6: kwin copies the call's words (the keyword, its args, kwback) to a buffer in
  main RAM before switching the page, so the keyword pops its args from memory that stays mapped,
  and kwback goes on with the thread after them (the same for one page calling another page's
  keyword, and on the Small scheme where the area is loaded over). That was the open page-to-page
  bug.
- **Platforms should state their own fixed areas as default Reserved ranges**, instead of asserts or
  nothing:
  - cpcmin: #A600-#BFFF;
  - cpc and cpcmin: the screen at #C000, unless the program frees it;
  - zxn: #BA00-#BFFF.

  Today `cpc` and `cpcmin` let a program run into #A600 and #C000 with no error, and `zxn` stops at
  #BA00 with an assert.
## How the compiler does it (20261107-6)

The assembler does the calculation. `holeLayout` (ntc_compiler.js) cuts the program into parts -
the main thread, each procedure, the stubs, the `#asm` blocks, each variable, each string, each
keyword-library section - and at every cut emits a guard the assembler evaluates with the sizes
from its earlier pass (`fwdref-ok`):

- **Two passes (20261116-5)**, when there is safe memory and something that must be in it: the
  parts that must be there (the safe classes' procedures; in a paging program the stubs, `#asm`,
  the data, the library and the procedures a page calls - `decidePinned` finds those) are moved in
  front, each placed in the first Safe range with room (`ntc_saN_ed` is how far range N is used:
  `IF (ntc_pl == 0) && (ntc_saN_ed + size <= end)` / `org ntc_saN_ed`). Then `org ntc_fb` goes
  back to the end of the start code and the rest fills upward. A part that fits in no range is an
  `ASSERT` with its name. The memory image is what gets saved, so this needs the assembler's
  device: an AMSDOS build and the Next have it, and a CPC build without an AMSDOS name gets it
  too and saves the image as `NTCIMAGE.BIN` (`ntc_image equ 1` says so; the test harness reads
  that file).
- **Reserved** (`ntc_rgN` guards): `IF ($ < end) && (next part reaches start)`: the gap is padded
  (`ds end - $`). There is no Skip (the packing code went in 20261116-5).
- **Used safe memory**: the same guard, `org ntc_saN_ed` over `start .. ntc_saN_ed`. The rest of
  the Safe range is filled like any memory.
- **Paged**: not a hole for code. With no safe memory given, each part that must stay in sight is
  checked when it ends: inside the Paged range it is an `ASSERT` that names it and asks for
  `Option Memory Safe`. With `Option Memory Heap Main` (a page is loaded into the window in
  place) or `startbank 0` (the window is a swap page) nothing may be under it: it is a hole for
  every part, like Reserved. The arrays (`@@BSS@@`) and the Memory class's tables never go in it.
- **Page 1 under Paged code**: the Memory class's page 1 is main RAM's own `#4000-#7FFF`. With
  page 0 code under the window that block holds code, so the compiler emits `NTC_WINPAGED 1`
  and the table build (`mem_tb_ports`) marks page 1 taken (`'P'` in the RAT) when `ntc_end`
  reaches past `#4000`: `Memory.AllocPage` and the page loader never hand it out. (Without
  this the first page loaded landed on the code under the window.)
- **Safe without the device** (cpm and the other one-pass builds): each safe procedure (`; @safe`
  ... `; @endsafe`) is a macro `ntc_sfN`, placed when the fill reaches a Safe range (first fit),
  the fill going on after it.
- **Platform Reserved**: `;@reserved start,size ...` in the platform file (`cpc`, `cpcmin`,
  `zxn`), applied as Reserved ranges less the program's `Available` ranges (and `#C000-#FFFF`
  under `Option HighCode`). `NTC_PLATRSV 1` turns the old top-of-RAM asserts off; the map's
  own asserts take over.
- **The report**: `DISPLAY "NTC memory: ..."` lines at `ntc_end` (sjasmplus prints them):
  program / arrays / stack, each hole, each Safe range with its safe code span, how far each is used.
- `NTC_WINHOLE` is 1 when the window `#4000-#7FFF` is Reserved **or** Paged (the library takes
  the program's free RAM as above the window; the Memory class's tables go above it).
  `; @window` data still needs it Reserved.
