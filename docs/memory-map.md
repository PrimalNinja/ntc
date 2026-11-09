# NTC memory map: how it should work

(c) 2026 Cyborg Unicorn Pty Ltd

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

## Reserved: ZeroFill or Skip

`Option Memory Reserved ZeroFill | Skip` *start*`,` *size* ...

- **ZeroFill:** the gap is in the built file, filled with 0 at build time. The file loads and runs
  as it is.
- **Skip:** the file is packed, with no gap in it. Addresses are still built as if the gap were
  there, so the code after the gap is in the file straight after the code before it. A loader has
  to move it up to its real address before it runs, which puts the gap back.
  - The loader runs first, from code below the first Skip gap, before anything above a gap is used.
  - With more than one gap, it moves the blocks highest first, copying each from its top end down
    (`lddr`). Each destination is above its source, so the blocks overlap.
  - It has nothing to do for a gap at the very end of the program, or for formats that already load
    each part to its own address (a NEX file's banks).
  - It doesn't work for code run in place from a cartridge ROM. There it's ZeroFill, or copying to
    RAM.
- Suggested default: ZeroFill, today's behaviour, so existing programs don't change.

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
  `Option Memory Paged` lost its start bank, so add one back, for example
  `Option Memory Paged &H4000, &H4000, 1`.
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

- **Reserved** (`ntc_rgN` guards): `IF ($ < end) && (next part reaches start)`: ZeroFill pads
  (`ds end - $`); Skip packs on (`DISP end`, the code assembled for above the gap but put in
  the file straight on). The start code's mover (`ntc_sk*`, constant size, `ld bc, 0` means
  "not there") copies each Skip block up, highest first, `lddr`. `ntc_fileend` is the packed
  file's end (`SAVEAMSDOS` uses it); `ntc_end` stays the run-time end.
- **Paged**: the same guard, but only for the parts that may not be under a page: data, the
  stubs, `#asm`, the library, the arrays (`@@BSS@@`), the Memory class's tables, and the
  procedures a page calls bare or that run at any time (Tick, hooks, `AddressOf`) plus what
  those call (`decidePinned`). A procedure thread nobody pins goes straight through. With
  `Option Memory Small` (a page is loaded into the window in place) or `startbank 0` (the
  window is a swap page) nothing goes under it. When code may go under the window the pinned
  parts are laid out **first** (stubs, library, data, the pinned procedures, then the threads,
  the keyword library's data last), so they land below `#4000` and only page 0 threads fill
  through the window; the parts are cut at the `; ====` headings (`isCut`).
- **Page 1 under Paged code**: the Memory class's page 1 is main RAM's own `#4000-#7FFF`. With
  page 0 code under the window that block holds code, so the compiler emits `NTC_WINPAGED 1`
  and the table build (`mem_tb_ports`) marks page 1 taken (`'P'` in the RAT) when `ntc_end`
  reaches past `#4000`: `Memory.AllocPage` and the page loader never hand it out. (Without
  this the first page loaded landed on the code under the window.)
- **Safe**: each safe procedure (`; @safe` ... `; @endsafe`, one pair per procedure) becomes a
  macro `ntc_sfN`. The first major guard whose part reaches a Safe range (or would cross its
  start) pads to the start and runs the placement: for each block not yet placed,
  `IF (ntc_sfN_p == 0) && ($ + size <= end)` expands it and marks the range. The fill goes on
  after. Ranges the fill never reaches are placed before `ntc_end`. `ASSERT ntc_sfN_p != 0`
  names a procedure that fits nowhere. Converges in sjasmplus's three passes (sizes are
  position-independent).
- **Platform Reserved**: `;@reserved start,size ...` in the platform file (`cpc`, `cpcmin`,
  `zxn`), applied as Reserved ranges less the program's `Available` ranges (and `#C000-#FFFF`
  under `Option HighCode`). `NTC_PLATRSV 1` turns the old top-of-RAM asserts off; the map's
  own asserts take over.
- **The report**: `DISPLAY "NTC memory: ..."` lines at `ntc_end` (sjasmplus prints them):
  program / arrays / stack, each hole, each Safe range with its safe code span, each safe
  block's address and size, each Skip block's file position and size.
- `NTC_WINHOLE` is 1 when the window `#4000-#7FFF` is Reserved **or** Paged (the library takes
  the program's free RAM as above the window; the Memory class's tables go above it).
  `; @window` data still needs it Reserved.
