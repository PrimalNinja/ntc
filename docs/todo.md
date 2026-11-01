# NTC - todo

Open work for NTC BASIC, by component - the numbers are [components.md](components.md)'s; bugs are
in [buglist.md](buglist.md) under the same numbers; what is done is in [done.md](done.md). 48 on:
future components (no code yet) - one keeps its number when it is built. Decisions and design notes
kept for reference are at the end.

## 2 ntc_compiler.js - the compiler
- [ ] Scalar strings' buffers (variables, locals, params, results, temps) after the program like
      the arrays, not in its file - their capacity bytes set at the start from a small table:
      a program's file 3K or so smaller (MON's 31K has 36 buffers of 82 bytes), loading faster
      (the 320K disc is full)
- [ ] **`Interrupts` class - interrupt handlers as separately compiled frames** (decided in
      discussion 2026-10-11; replaces the `Interrupt MySub` statement).
      Background - how interrupts work now: keywords run with interrupts off; an interrupt
      is only taken at a safe point (`ntc_xn` window between keywords: branches in normal
      mode and `kw_irq` every 32 straight keywords) or inside the windows of long keywords
      (Cls, scroll, key wait, frame wait, host calls - all switch SP to `ntc_csp` first, so
      SP is always the real stack when an interrupt comes). The CPC handler (`ntc_irq`)
      only counts ticks and sets `ntc_hookpend`; `ntc_xnh` then runs the hook Sub as normal
      thread code at the next safe point; `ntc_hookon` stops it re-entering itself.
      Problems with running a BASIC Sub in the main program's frame (found 2026-10-11):
      1. temps (`tmpN` / `stmpN` / `ltmpN`) can be live across a safe point (`kw_irq` can
         land mid-expression) - the hook's expressions overwrite them
      2. BUG NOW: `kw_irq` can land between a compare and its branch (the compare counts
         as a straight keyword); plain `ntc_xn` keeps the flags, but with a hook the hook's
         code runs in between and the branch goes the wrong way. Fix even before the class:
         put `kw_irq` only at statement starts (or never between a compare and its branch)
      3. procedures / GOSUB targets called from both main code and the hook: one set of
         params, locals and one `_rs` return point each (no recursion), so the hook's call
         overwrites the main program's - the recursion check (call graph cycles) does not
         catch main + hook sharing
      Design:
      - the handler is a Sub compiled as its own FRAME: a third compile mode (`_i`) - the
        Sub and every procedure it calls get their own copies AND their own storage
        (params, locals, `_rs`, ByRef words), their own temps (`itmpN` ...), own GOSUB
        return points / stack. Shared with main: global / module variables only. Asm
        keyword procedures (body only #asm, no storage) need no `_i` copy - both sides call
        the same one. So a handler can be all BASIC, BASIC with #asm, or effectively all
        asm (`dw fn_x` + `dw kw_iret`, ~60-80 T over a raw asm handler)
      - running: an interrupt at a safe point between keywords -> the platform handler saves
        AF (fixes problem 2 for good) and the thread position, runs the frame's thread with
        interrupts off, `kw_iret` restores. An interrupt inside a long keyword's window ->
        only mark the frame pending, it runs at the next safe point (library scratch such as
        `ntc_ip`, `ntc_sptr` is in use mid keyword). Library keywords are shared code: safe
        because the frame only runs between keywords
      - placement: a frame is its own allocation unit, so it can be placed apart (a fixed
        address e.g. below #4000 on the CPC, a ROM, a bank that is never paged out, or left
        next to the program). An ISOLATED frame (music player, interrupt driven I/O
        buffers) gets its own copies of the library sections it uses, placed with it, so
        nothing it needs can be paged out (bank window, upper ROM / #C000 games) - an
        ORDINARY frame (game logic, timers) shares the program's library. Same mechanism,
        only placement differs. Fits the range allocator planned under Memory map (every
        jump between units already goes through stubs). A resident frame can outlive the
        main program (TSR style), found by a header
      - communication: a MAILBOX at the start of the frame: +0 command (0 = none), +2
        parameter, +4 status / reply (optionally a signature + version word in front). Main
        writes the parameter, then the command (inside one keyword, interrupts off, so the
        frame never sees half a command); the frame acts, writes the status, clears the
        command (= done, `Busy` = command <> 0). A ring of slots if commands can come faster
        than the frame runs. The caller only needs the frame's base address: a label (same
        build), `Option Frame <name> At #xxxx`, or found by signature (resident / ROM)
      - as a class, e.g. `Music.cls`: `Play tune`, `Stop`, `Volume v` (asm keywords that
        only write the mailbox, ~the cost of a Poke), `Busy()`, `Position()` (the status);
        the class's handler Sub is the frame. The same shape is the general interrupt
        driven driver class (e.g. Serial: the frame fills a receive ring, GetChar / Ready
        read it, Baud posts a command)
      - API sketch: `Interrupts.Every n, AddressOf Sub` (every n ticks, CPC EVERY),
        `Interrupts.After n, AddressOf Sub` (once, CPC AFTER), `Interrupts.Frame AddressOf
        Sub` (every vsync - 1 in 6 interrupts on the CPC), `Interrupts.Off`; a small fixed
        timer table; `Interrupts.Fast AddressOf AsmSub` for work that must run even inside
        long keywords' windows: strict rules - asm only, no library code (the compiler can
        warn when a handler's asm names a library label), short, save IX / IY (the platform
        saves the rest with exx / ex af,af' - nothing in the library uses the alternate set
        on the CPC hardware platform; the CPC firmware uses BC' itself)
      - `AddressOf` gives the stub for the mode at that line; a handler always runs in its
        own frame, so `Interrupts.*` must give the frame's entry, not a turbo / normal stub
      - platforms: cpc - the program owns #38, works directly. cpcfw - register the frame /
        Fast handler as a firmware event (KL NEW FAST TICKER, KL NEW FRAME FLY, KL ADD
        TICKER), with the pending rule. cpm / test - none (`System.HasHook` /
        `Interrupts.Available` False, using it is a compile error). Turbo mode: no
        interrupts, handlers only run in normal mode
      - rule for every platform handler, to write in NTC.md: the interrupt handler itself
        never calls library code - it only counts, marks pending, or runs a frame between
        keywords
      - then remove the `Interrupt` statement (or keep it as sugar for
        `Interrupts.Every 1, AddressOf Sub`); update hook.bas / ref, userguide 12, NTC.md
- [ ] FUTURE: `Option ClassSize <kilobytes>` - keep a class's code within a size so classes
      can be used as banking units. Accepted, not enforced.
- [ ] decide: keep `Dim c As Counter` (it only aliases the one set of members) or make it an
      error now that classes are namespaces
- [ ] an If on a constant (StdIO.CanPosition ...) could drop the dead branch instead of
      jumping over it
- [ ] `Option CPM`, `Option <target>` ... for target specific things, or loadable drivers /
      libraries (like PRIMAL modules) that applications in this dialect use
- [ ] `Option RAM <from>-[<to>][, ...]` and `Option ROM <from>-<to>`. No options: as now (all
      RAM from Org). With ROM: code, thread, library code and read-only data go in ROM; variables,
      temps, library data, `_rs` / `_a` words, GOSUB stack go in the RAM ranges (first range
      that fits). Error when something does not fit
- [ ] FUTURE: `Option RAMBanks <from>-<to>` (CPC 6128 #4000-#7FFF window), with
      `Option ClassSize` as the banking unit. Do not shoot ourselves in the foot meanwhile:
      the allocator works on ranges, nothing may assume code and data are next to each other,
      and every jump between code sections goes through a stub (GOTO stub, call stub) so a
      bank switch can go in the stub later
- [ ] keep the compiler's memory model like PRIMAL's memory table (`type, from, to` records:
      RAM, pageable, video, reserved, ROM) so `Option RAM / ROM / RAMBanks` and a platform's
      defaults all become the same list, and a PRIMAL target could hand its table over later
- [ ] pageable classes: compiled at #4000 into a C page, called through a stub outside the
      window (save page, switch, run, switch back); strings returned land outside the window
- [ ] compiled sprites in C pages: the compiler packs sprite data into a 16K page image with
      an address table at #4000 (same layout for every level's file, so the class code works
      with any loaded set); one page switch per Draw of all instances; PUSH drawing with
      interrupts off; inline next-line step; 2 / 4 / 8 shifted copies per mode; skip
      transparent bytes, masks for partial ones; clipping / erase choices
- [ ] code past the window: the compiler continues the program at #8000 when it reaches #4000
      (a thread jump over the gap), so a big program can still page
- [ ] overlay classes, next: `Implements` (an interface class; several files built against
      it, `ILevel.Load("LEVEL" & n)` swaps the file behind it - a jump table at #4000 in
      each); stand-alone DLLs on the library jumpblock; overlays on cpc (no files: put them
      after the program in its file and copy them into pages at start?); library keywords
      used only by an overlay inside its page; a warning when overlay classes call each
      other (64K reloads)
- [ ] the Small heap uses the RAM on both sides of a reserved range (with overlays it stops at
      #4000 now, wasting #8000 up to the BDOS on CP/M)
- [ ] overlay classes: reusing a C page when none is free (CPCExpansion on 64K - the Small
      overlay area is done); Paged variables saved across swaps in the overlay area
- [ ] interrupt classes, next: Tick in a page (I pages, a paged interrupt class); asm-only
      Ticks run inside the interrupt itself (music players: no wait for a safe point);
      cpcfw (firmware frame flyback / ticker events); flags kept across a hook / Tick run
      at a safe point (a compare then kw_irq then a branch); harness vertical sync timing
      (it toggles per read, so Frame classes run in bursts there)
- [ ] Relocatable driver files (built once, loaded into a shared page at run time,
      256-byte aligned, a fixed interface per driver type, a resident registry) - design talk
      2026-10-12
- [ ] **For loops, counter not used**: if the body and the code after the loop never read
      the loop variable, use a hidden down-counter: one keyword `dec` 16 bit + branch if not
      zero (about 45 T) instead of `kw_next1l` (about 120 T: inc in memory, load, signed
      compare with the limit). If the variable is read after the loop, set its final value
      once at the exit
- [ ] **For loops, Step 1 / -1, constant limit**: the loop always ends at exactly limit + 1
      (limit - 1), so the end test can be "equal to" (two byte compares) instead of signed
      <=; one check on entry that the loop runs at all. About 30-40 T per pass, nearly every
      For loop
- [ ] **Loop rotation**: `Do While c ... Loop` / `While ... Wend` / `Do Until`: test at the
      bottom (one jump to it on entry) instead of test at the top + jump back: one branch
      keyword per pass instead of two. About 20 T turbo, about 110 T normal (the jump back
      also went through `ntc_xn`)
- [ ] **Merged keywords for common pairs** (pattern match on the thread, one keyword for
      two): compare + conditional branch ("jump if var > literal" etc.: about 40 T - every
      If and loop test); array read + compare (`If f(i) = 1`: no temp written and read
      back); `x = x + y` / `x = x - y` with the same target (one pop and one address load
      fewer, about 25 T); literal values inline in the thread instead of a pointer to a
      constant (`f(j) = 0`: about 7 T). Pick the pairs by counting them in bas/ and the
      bench programs
- [ ] **Normal mode: interrupts on every 4th branch**: a counter at the branch (`dec`, skip
      unless zero, about 20 T) and the full `ntc_xn` window only every 4th time. Interrupts
      still get in every few hundred T; normal mode's extra on tight loops from 55% to about
      15%. Check the worst case latency against the CPC's 300 Hz interrupt (it waits for an
      ack, two missed in a row lose one)
- [ ] **Constant shortcuts in maths**: `x \ 2^n` -> shift, `x Mod 2^n` -> `And` (sign fix for
      negatives, or only when known positive, e.g. a loop counter); `x * 2^n` and small
      constants (`* 3`, `* 5`, `* 10`) -> shifts and adds (SDCC does `i * 5` this way);
      divide by a constant below 256 -> an 8 bit divisor routine
- [ ] **Thread-level inlining** of small BASIC procedures: copy the procedure's thread into
      the caller with the arguments put in directly (`s = Add2(i, 3)` ->
      `dw kw_add, var_i, lit_3, var_s`): no call stub, no argument copying, no return
      point. Only for small procedures (thread size grows per copy); a ByVal parameter that
      is assigned needs a temp copy of the argument; each copy needs its own locals (or safe
      sharing - no recursion, so possible); a Function's result goes straight to the
      caller's target. SDCC is 3.7 x faster on calls
- [ ] **Keywords made for one site** (fabricated by the compiler, like the loop jump-back
      `do4_t_go` already is): the statement's addresses and constants built into the code
      (`ld hl,(var_j) / ld de,(var_i) / add hl,de / ld (var_j),hl / ret` = 73 T against
      `kw_add` 119 T), the thread still one `dw`. No pops, no loads through pointers. Sieve
      inner loop about 366 T -> 220 T. Costs 10-15 bytes per site against 6-8 bytes of thread:
      inner loops only, or an option per procedure
- [ ] **Whole loop body as one piece of code** (the step after site keywords): the loop's
      variables loaded into registers once (`j` in DE, `i` in BC) and stored back on exit,
      the body straight code - native code for that loop, about SDCC's 107 T for the sieve,
      the rest of the program still threaded. Only for loops whose body the compiler can do
      this way (no calls, few variables)
- [ ] **Call stub - look at the whole procedure** (like the old single stack allocation for
      all Dims): today each local is cleared on its own (`ld hl,0 / ld (var_i),hl / ld hl,0 /
      ld (var_j),hl`, an `ldir` per local array). Lay a procedure's locals out together and
      clear them in one block (one `ldir`, or `ld (nn),hl` with HL loaded once); skip locals
      that are always assigned before they are read (the sieve's `i` and `j`: no clear at
      all - VB's "locals start empty" only matters for a local read before written); a ByVal
      parameter never assigned in the procedure can read the caller's value, no copy.
      Cheaper argument passing for small procedures (registers for one or two Integers)

## 5 The flavours (Locomotive, JS, PHP)
- [ ] JS flavour, next (docs/js_flavour.md): the ES5 class form, the four open decisions,
      VB `'#` hints and `Dim n = 0`, `+` joining a number and text, the GUI view of the VB text
- [ ] Keys: the Shift / Control forms of INKEY(n) (32, 128 ...) for the Locomotive flavour

## 6 The IDE
- [ ] FUTURE: formRenderer for project forms (structured form creator)

## 8 ntc_lib.asm - the Z80 runtime
- [ ] split every library / platform section into code and data (53 data labels sit inside
      code sections now, e.g. `ntc_tabcol`, `ntc_pidx`, `ntc_kprev`); data with a start value
      gets a copy in ROM and an ldir to RAM at start, the rest is zeroed
- [ ] interrupt handler: when I blocks or paged code exist, switch to a private stack, call
      each I block (with a divider: every 6th interrupt = 50 Hz), put the page back from
      `mem_cur`. Nested di / ei count (PRIMAL style); the handler sets it to 1, ei; ret at
      the end
- [ ] library jumpblock at #8000 (shared build mode): fixed 3 byte slot per library keyword,
      RAM or ROM targets, version check; standalone build stays the default (no extra 10 T)
- [ ] long string work and Long divide still hold interrupts off while they run (short:
      40 chars, 32 steps); Cls, scroll and Mode let them in
- [ ] **Faster 16 bit divide**: z88dk's and SDCC's are 1.6-1.85 x faster (`divide`, most of
      `factor`). Unrolled loop; a quick path when both values fit in 8 bits. Every `\`,
      `Mod`, `/`
- [ ] `x++` / `x--`: `kw_inc` / `kw_dec` are already about as fast as a separate keyword can be
      (31 T usually); gains only when folded into a bigger keyword (a loop's own step)

## 9 A machine's own runtime parts (cpc, msx, nxt)
- [ ] check in WinAPE that the firmware / AMSDOS leave the RAM setting alone during a file
      call on cpcfw / cpcmin (a load into a selected page); if not, re-select from `mem_cur`
- [ ] zxn: the harness (zxnrun.py) runs a .NEX only, no esxDOS, so nothing here exercises
      ntc_lib_nxt's file calls; CyborgOS's ZEsarUX harness is the only test (moved from the
      buglist 2026-11-01: a test not written, not a fault found)

## 12 The Mega Drive and MEGA65 runtimes
- [ ] m65: pages - `Option Page Name Loaded n` with MAP's 8K blocks of the 384K chip RAM (main
      RAM kept for code, 16K pages for screens, sprites, music or more code); the attic RAM
      (8MB) by DMA for data
- [ ] m65: files through the hypervisor's DOS calls (the SD card's FAT32)
- [ ] m65: colour text on the console (`CanColour`), the 40 column console mode's font
- [ ] m65: try it on a real MEGA65 (so far Xemu only; the SIDs never listened to)

## 13 The platform files
- [ ] zxn: other Next targets later (a dot command, a NextZXOS-friendly build that returns)
- [ ] CP/M: more terminal types (ADM-3A ...) if wanted; Ticks from the CP/M 3 clock where
      there is one
- [ ] the platform file gives the defaults: usable RAM ranges, screen, start stack, bank
      window and bank port list (CPC: from primal/src/ams_*.asm)
- [ ] cpm: the start code checks the TPA reaches #8000 when there are overlay classes (a clear
      message instead of a crash on a small TPA / SymbOS window); find out which BDOS calls
      SymbOS has (random records 33-36 for Seek)
- [ ] `asm/ntc_plat_test.asm` is left over from the removed Python harness - delete?
- [ ] cpcfw: a Tick waits for the end of a statement, and the firmware's text takes about
      3.4 ms a character, so a Frame class that prints, beside a main loop that prints, runs
      20-25 times a second (two dues in one Print run as one). Options: a due count instead
      of a flag (catch up - right for game logic at a fixed rate, wrong for "once a frame"),
      or NTC's own glyph drawing on cpcfw (about 0.4 ms a character on cpc). (Moved back
      from the buglist 2026-11-01: the firmware's speed, a design choice)

## 14 The ROM builds
- cpcfw, Library: ROM, a set of 4 ROMs (test/irqfar with romset4): a program that ends below about
  #0300 runs off into the stack while interrupt classes run during far calls. Hidden today by the CPC's
  bank switch glue at #0040 (14 bytes) pushing the end past it. Find why.
- [ ] **library in ROM, next** (done 2026-10-13: cpc, cpcmin, cpcfw - `Option Library ROM`,
      jump block patched at start, NTCCPC / NTCMIN / NTCFW.ROM, registries
      `asm/ntc_rom_<platform>.txt`). Left: the 10 T per keyword (sieve timing +25%) could go
      with load time patching of the threads (item 4 below: a list of thread words, patched
      once - main RAM at start, page files when loaded); BASIC RSX commands in the ROM;
      NTCMIN.ROM has about 0.8K free.
- [ ] FUTURE (CPC, main target): **library in ROM** - a second CPC build next to the RAM one
      (RAM only for now; keep this possible). Why: many CPC users have ROM boards (and the M4
      has ROM slots); the library is half to nine tenths of a typical program (measured
      2026-10-11: guide 2424 of 2806 bytes, guess 2490 / 2800, shellsort 2610 / 3832,
      vb_test 2815 / 6194; the whole library ~8 KB without normal copies, so 8-16 KB of RAM
      back as it grows). An NTC thread is already a tokenised program, so it is a BASIC
      interpreter's layout (keywords in ROM, tokens in RAM) without the interpreter loop.
      Plan (discussed 2026-10-11):
      1. ROM / RAM split first (see Memory map): library working storage at a fixed RAM
         address given by the platform file (like an interpreter's system variables), data
         with start values copied at start, nothing writes into library code
      2. a keyword number list: add-only, versioned (major = breaks compatibility, additions
         don't) - the contract between programs and ROM versions
      3. the NTC ROM: one 16K image (every section, turbo + normal copies, CPC platform,
         font), header (signature, version, count), export table (keyword number ->
         address, could be in PRIMAL style levels), a standard sideways ROM header with an
         RSX `|NTC,"PROG"` that loads, links and runs
      4. link at LOAD time, not through a jump table: the program file holds keyword numbers
         in the thread + a bitmap (1 bit per thread word: "this is a keyword number") + a
         short fixup list for code (stubs, #asm); the loader finds the ROM (scan slots for
         the signature), checks the version, writes the real addresses into the thread once
         - no run time cost. No register (IY) kept for it: the table is only read while
         loading (and IY belongs to the ROM on the Spectrum anyway). A RAM `jp` table
         (10 T per keyword) only for a thread that is itself in ROM and must work with any
         compatible core
      5. ROM missing / too old: a plain message (two builds, RAM and ROM, rather than one
         file with the library bundled - the program's layout is fixed at compile time, so
         a bundled fallback saves no RAM the program could use)
      Watch: the upper ROM covers the screen at #C000 - reads give the ROM, so scroll (the
      one routine that reads the screen) must use hardware scroll or a small routine copied
      to RAM that switches the ROM off around the copy; writes (glyphs, Cls) are fine. The
      #38 interrupt handler is in RAM and calls nothing - normal mode unaffected. On cpcfw
      the firmware switches upper ROMs during its calls, so the call wrapper must be in RAM
      and select the NTC ROM again. Test: cpcrun.py needs the gate array ROM enable bit, the
      #DFxx ROM select port and a ROM image in a slot, then the whole regression runs in
      "library in ROM" mode too. Later: the standard classes (StdIO / System - asm keywords,
      no storage) in the ROM as well; a cartridge style build (thread in ROM too, only
      variables in RAM - CPC Plus / GX4000 cartridges)
- [ ] CPC: code in upper ROM (#C000) over the screen at #C000 is a FEATURE (Julian): the
      code runs from ROM with its own sprite / font / table data in ROM, and its writes to
      #C000-#FFFF go straight through to screen RAM - 16k of code + data and the full 16k
      screen at the same addresses, no address games. What to design around: from that
      code the screen is write only (reads give the ROM). So plain sprite / text output,
      fills and hardware scroll (CRTC R12/R13) work as they are; anything that reads the
      screen (copy scroll, XOR / masked sprites that read the background, Point) needs a
      routine outside #C000 that turns the upper ROM off for the read, a shadow copy of the
      background in RAM, or drawing into a back buffer at #4000 / #8000 and flipping the
      screen base
- [ ] decide where the start stack (`ntc_csp`) lives when there is a ROM option
- [ ] ROMDISC, next: overlay classes and page files loading from it (volume R for their files);
      compressed files (the flag is there); a GUI builder (ntcRomDisc is ES5, in the compiler)
- [ ] ROM sets: one set for all three CPC platforms (the platform layer in the program's RAM, a
      call table) - later
- [ ] ROM sets: far call stubs made by the patcher from a 3 byte table (saves RAM image space)

## 16 FileSystem.cls
- [ ] FileSystem, next:
      - `Capability` with a literal name folded when compiling (the platform is known), and
        the If on a constant dropping its dead branch; in an `If`, the flag form (Z = true,
        PRIMAL style) straight into the branch with no value stored
      - `Capability` for `System` and `StdIO` too, in place of the CanPosition / HasHook ...
        constants (one pattern for every platform class and later drivers)
      - [x] CPC firmware: SEQUENTIAL through CAS IN CHAR / CAS OUT CHAR - one file open at a
        time (done 2026-10-13). Later: one in and one out at once (a second 2K buffer)
      - CPC firmware: DELETE / RENAME through AMSDOS's |ERA / |REN (RSX, only with AMSDOS)
      - [x] CPC hardware with the firmware for files: done as the cpcmin platform (2026-10-12).
        An own FDC (uPD765) driver for `cpc` - later, if ever
      - cpcmin: check in WinAPE (AMSDOS test); messages on/off as an option (CAS NOISY #BC6B
        for tape; not AMSDOS's #BE78 - ROM-internal, differs by model: jumpblocks only); System.Command with arguments
      - CPC (cpcfw / cpcmin), later: a directory listing (CAS CATALOG / |DIR print to the screen;
        names back into the program needs more); Delete / Rename via |ERA / |REN once Command
        takes arguments
      - MSX: the cpm build under MSX-DOS 1 / 2 (BDOS-compatible: console and FCB files) - try
        it, check Option Terminal VT52 there (cursor ESC Y; clear screen may be Ctrl-L);
        an `msx` platform through the MSX BIOS (CHPUT, CHGET, CHSNS, POSIT, CLS) for
        programs without MSX-DOS
      - check on a real CPC / WinAPE: CAS calls with IY as NTC leaves it (AMSDOS is believed to
        load its own IY), tape messages, disc errors (Retry / Cancel) mid-load; that AMSDOS's
        CAS IN OPEN entry really starts with #DF (the "AMSDOS is running" test); the
        |TAPE / |DISC / |A / |B calls through KL FAR PCALL; Option RomEnable 7 after RUN"
      - CPC: CurrentDevice when CALLed is "DISC" - AMSDOS's current drive could be read from
        its workspace (needs the layout)
      - third party mass storage (IDE, SD card interfaces: random access) - needs research,
        not Amstrad standard; possibly later, as their own FileSystem variants
      - CPC firmware: the 2K buffer CAS IN / OUT OPEN need is in the program now (`fs_buf`);
        a way to put it elsewhere, often #C000 (the screen) - e.g. `Option FileBuffer &HC000`
        (an equ the platform file tests: no `ds 2048` then), checked against the program
        like Option Reserve
      - cpc (no firmware): `End` that resets (`rst 0`) instead of returning, for programs that use
        the firmware's / BASIC's RAM (#A700-#BFFF) - there is nothing intact to return to then
      - Option Reserve: lay the program out around a range (skip it between sections) instead
        of only stopping the assembly
      - `Option Files n` for MAXOPEN (now fixed at 2 on CP/M), VB style statements
        (`Open ... As #n`, `Print #`, `Line Input #`, `Close #`) as a front on the class
      - Spectrum +3 = +3DOS; later a simple NTC file system
- [ ] zxn: files through NextZXOS / esxDOS (DivMMC paged in for the call, as cpcmin hands back to
      the firmware)
- [ ] CP/M files through BDOS FCBs (with the file device classes)
- [ ] `FileSystem.LoadPage(name, page)`: load into a page through the window, cut at the 16K
      boundary and carry on in the next page (files over 16K)

## 17 Memory.cls
- [ ] zxn: Memory pages - the Next's 8K pages into a slot (the interrupt lands in slot 0's page
      and can bring the others in); CallBank-style whole 64K maps
- [ ] if reading RAM under a ROM is needed: a keyword / library routine that copies x bytes
      from under the ROM into a shared RAM buffer (ROM off, ldir, ROM back on). It must sit
      outside the ROM area it switches off. (The firmware has RAM LAM - RST 4 at #0020,
      `ld a,(hl)` with the ROMs off - one byte per call; a block copy is better.) Graphics /
      I/O classes are decided when we get to them
- [ ] ROM pages (upper ROM at #C000, port #DF) as their own class: sprites from ROM write the
      screen under it; no screen reads while the ROM is in
- [ ] virtual memory: whole 16K pages to SD / CompactFlash / USB (or floppy). Per page:
      resident, changed (set by WriteByte / WriteWord / Copy / SelectPage of D or U), the
      file it came from; C pages and U pages loaded from a file are never written back.
      Least recently used order in the type lists. One file per page (`P0012.PAG`) works
      with AMSDOS now; a swap file with 16K slots needs random access (M4, IDE, USB)
- [ ] check the 4MB ports (#78-#7E, A10 low) against other expansion hardware in WinAPE

## 19 List.cls
- [ ] List, next: faster calls (GetWord / NextOf as plain keywords without mem_go and the
      argument checks); fields as Strings; a node of another list or a deleted one isn't
      caught; Memory.SavePage / LoadPage (a data page out to a file and back)

## 20 Graphics.cls
- [ ] Graphics (CPC): Plot, Draw / Line (Bresenham), Circle, Fill, Point (read), Ink /
      Paper / Pen / Border, sprites (masked, pre shifted). Screen address: row * 80 +
      (line in char) * #800 + x bytes; inks and border are gate array (#7Fxx), not the CRTC
- [ ] Double buffering without the wait: the flip waits for the sync and then sets R12, about
      10 ms a frame doing nothing in CUBE3D. The CRTC takes R12 at the start of the next frame
      wherever it is written, so the flip can set R12 at once and the program wait only before
      it draws on the other screen - and the next Turn (about 32 ms, longer than a frame) runs
      in between, so no wait at all. CUBE3D: about 7.7 -> 8.4 frames a second. Check the CRTC
      types (1 is said to differ on R12 / R13 mid-frame). One screen: `Frame` before the draw
      costs the same 10 ms and can't stop the flicker (the draw takes about 4 frames)

## 22 Float.cls, Fixed.cls
- [ ] bit-identical ties with a coprocessor: the Z80 engine rounds halves away from zero (an
      8-bit guard byte, no sticky bit), C and the Pi round to even, so a tie can differ by an
      ulp between backends. Needs a sticky bit through the engine's add, multiply and divide
      (asked 2026-11-01; the tie tests in test/float/chk.py check the engine's rule now)

## 25 src/ntc3d (E3 and the rest)
- [ ] E3 objects get a matrix (roll, any orientation): an object is placed by position and
      yaw / pitch only; the camera has CamSet / CamPosL. Analysed, not built (moved from the
      buglist 2026-11-01: a feature)

## 29 The games and demos
- [ ] zxn: the Melbourne demo, CyborgOS

## 38 A real CPC through its serial link
- [ ] test on a real CPC (both modes, Turbo On / Off)

## 48 Sound (an AY class, a music player)
- [ ] Sound (CPC AY-3-8912): reached through the PPI, not directly: PSG data on PPI port A
      (#F4xx), PSG control on PPI port C (#F6xx: #C0 = select register, #80 = write, #40 =
      read, #00 = inactive), PPI port B is #F5xx (vsync etc.). Registers 0-5 tone, 6 noise,
      7 mixer, 8-10 volume, 11-12 envelope period, 13 envelope shape, 14 = keyboard row in
      (shared with the keyboard scan - sound and key scans must not interleave). Sound /
      Envelope / Volume / Noise; music player from the interrupt (ties to the interrupt hook)
- [ ] AY music player class as an I block (player + tune in main RAM out of the window;
      Stop flag, load a new tune, Play). Keyboard scan moves into the interrupt (the AY and
      the keys share the PPI)

## 49 More targets (the ZX Spectrum, the PRIMAL list)
- [ ] more hosts: ZX Spectrum, then more (the PRIMAL target list is the guide)
- [ ] Spectrum: ROM at #0000-#3FFF (IM 1 handler is in ROM), screen at #4000 (attribute
      layout, 32x24 text), keyboard ports #xxFE; 128k paging at #C000 only

## 50 File devices as classes (Disk, RamDisk, Printer, Serial)
- [ ] file devices as classes (Disk / RamDisk / Printer / Serial, the standard set
      MaxFiles / Ready / CanRead / CanWrite / CanSeek; `Open ... As #n` and `Print #n`
      onto them; handles from `Option Files n`; status, not errors). `Print #n` needs byte
      text on every platform, glyph platforms included

## 51 A text buffer class
- [ ] a text buffer class (optional; discussed for CyborgOS): lines of text in the heap, insert /
      delete / get / set a line - for editors and CLIs

## 52 The language, possibly future
- [ ] `ReDim` with bounds from variables - needs a heap (or a declared most size). Not now
- [ ] Overflow is not checked (Integer and Long wrap). With no error handling this stays,
      write it in NTC.md as the rule
- [ ] 3+ dimension array parameters (not planned unless needed)
- [ ] `Format$` with dates / text patterns (`@`, `>`, `<`), `%`; Split's most parts (16)
      could be an option

## Decisions and design notes (kept for reference - not open work)

### Decisions (2026-10-11, from Julian's notes)
- **No error handling. Never `On Error`, no exceptions.** It makes lazy programmers and runs
  slower; it would also need the thread return points tracked and unwound, which NTC does
  not do (SP is the thread, GOSUB stack is per target). Fallible routines return a status
  (Function result), the caller checks it. Convention to write down: 0 = ok, negative =
  error (or document per library). Diagnostics are a different thing and are wanted:
  an `Error` statement (print and stop), maybe `Assert`, maybe a trace
- **NTC gets File I/O, Graphics and Sound** - as libraries / platform drivers, not as
  language changes
- **I/O as classes, with `#asm` / `#endasm`** to write their hot paths
- **Classes stay syntactic sugar: one set of members per class** (this answers the old
  "copy per `Dim x As New`" question). Several instances are the class's own job, Amiga
  `serial.library` style: `h = Serial.Open(...)` returns a handle (an Integer index), every
  method takes the handle, the class keeps per instance state in its own arrays (or an
  array of a Type) and has a fixed number of slots. Singletons (screen, keyboard, sound
  chip, gate array) just use scalars. No vtables, no allocation, direct calls
### Libraries / drivers (as classes)
Note on the source notes (AI written): several Z80 examples in them are not valid Z80
(`add hl, a`, `ld de, hl`, `in a, (c)` with the port in HL), they treat parameters as
pointers (they are values), they put PSG ports at #F5 / #F6 directly and inks on the CRTC.
Corrected above.
### Direction (2026-10-11)
Focus is the language. Not a new system now. Later goal: code the rest of a cool OS in this
BASIC dialect.
### Memory map (ROM / RAM / banks)
CPC memory facts to design against (Julian has more ideas to add later):
- gate array port #7Fxx, value bits 7-6: `00` pen select, `01` colour, `10` screen mode +
  ROM enable (bit 2 = lower ROM off, bit 3 = upper ROM off, bit 4 = interrupt counter
  reset), `11` RAM config (6128 / expansions). Upper ROM number: port #DFxx
- RAM configs (low 3 bits, CPU view of #0000/#4000/#8000/#C000): C0 = 0,1,2,3 (normal),
  C1 = 0,1,2,7, C2 = 4,5,6,7, C3 = 0,3,2,7, C4-C7 = 0,n,2,3 with n = 4..7 (the #4000
  window). Bits 5-3 = which 64k of an expansion (see PRIMAL notes above)
- ROM over RAM: with a ROM on, reads come from ROM, writes go to the RAM under it (lower ROM
  #0000-#3FFF, upper #C000-#FFFF). So screen writes work with the upper ROM on, screen reads
  (scroll) do not
- the video always reads the base 64k (banks 0-3), whatever the RAM config. The screen can
  be at #0000 / #4000 / #8000 / #C000 (CRTC R12 bits 5-4), 16k. A screen at #4000 clashes
  with the C4-C7 bank window (the CPU sees the extra bank there, the video still shows bank
  1) - so with banking the screen stays at #C000 or #8000
- hardware scroll (CRTC R12 / R13 start address) instead of copying: no screen reads, so it
  works with code in the upper ROM; text output then has to follow the moving start address
- #0000-#003F: restart vectors, #38 = interrupt (IM 1); with the lower ROM on, #38 is read
  from ROM - NTC turns ROMs off and puts its own handler at #38
- code running in the bank window can not switch its own bank: bank switch stubs and the
  keywords that do it must be outside the window (e.g. #0040-#3FFF or #8000-#BFFF)
- ideas for banked NTC: thread + keywords of a class in one bank, a GOTO / call stub to
  another class = `ld bc, port / out (c), c / ld sp, target / ret` (stub outside the
  window); data arrays in banks reached by bank switching keywords (aget / aset with a
  bank); a copy buffer outside the window for bank to bank copies, like PRIMAL; interrupts
  must not change the bank (or must put it back)
Whole 64k switching (Julian's tip, CPC specific - FUTURE, NTC and / or a PRIMAL / CP/M idea):
- one OUT can swap the whole 64k (config C2 = banks 4,5,6,7 of an expansion block:
  #7FC2, #7FCA, #7FD2 ... and the lower port high bytes over 512k). The code keeps running
  at the next address in the new 64k, so that address must hold the same code in every 64k
- fastest context switch: every 64k has the same switcher at the same address:
  `ld (save_sp), sp / out (c), c / ld sp, (save_sp) / ret` - save_sp is at the same address
  in each 64k, so after the OUT it reads the new system's SP. Each system's stack holds its
  own registers. Full 64k programs, not just 16k banks
- set each 64k up first through the 16k window (C4-C7 style configs), then switch to it
- idea: up to 8 systems (Ctrl+1 .. Ctrl+8), Ctrl+9 a CLI, Ctrl+0 a monitor. Keep the base
  64k for the switcher / drivers / screen ("hypervisor") and put the 8 systems in a 512k
  expansion: 8 blocks = 8 systems
- the video only shows the base 64k, so a system in C2 can not draw on the real screen.
  C1 = base 0,1,2 + the block's bank 7 at #C000; C3 = base 0, base 3 at #4000, base 2,
  block's bank 7 at #C000. So the base code can reach each system's top 16k (C1), and a
  system's #C000 copy can be ldir'd to the real screen at #4000 (C3). Better for text
  systems: console output goes to the base code, which keeps an 80x25 text buffer per system
  and redraws on a switch
- the interrupt handler (#38) and the switcher must be in every 64k at the same address;
  lower ROM off (CP/M needs RAM at #0000)
- shared hardware (FDC, printer, serial): switching from the interrupt in the middle of a
  disk access breaks it - drivers live in the base 64k with a lock, or switching only
  happens at safe points
- other machines: MSX2 memory mapper (ports #FC-#FF, one per 16k page) can swap all 4 pages
  with 4 OUTs - switch the 3 pages the code is not in first, the code's page last (same
  rule: next address must match); some mappers can not be read back. Spectrum 128 only
  pages #C000 (#7FFD); +2A / +3 special all RAM modes (#1FFD) give 4,5,6,7 - two 64k at most
- Julian's model: context switch = push all registers on the current 64k's stack, swap
  banks, pop all registers, ret. Round robin from the interrupt, so every system keeps
  running behind, not just the visible one
- each system opens an 80x25 text screen by default (2000 bytes each). Writes when not
  visible only update the buffer; the visible one also updates the real screen at once; a
  switch redraws from the buffer. Keyboard: the selector keys are always watched, only the
  visible system gets the other keys
- the base 64k holds the real device drivers; reaching them from a system is a bank switch
CP/M compatible (or mostly) system idea - device model, not decided:
- CP/M 2.2: logical CON: RDR: PUN: LST: mapped by the IOBYTE (#0003) to physical TTY: CRT:
  BAT: UC1: / PTR: UR1: UR2: / PTP: UP1: UP2: / TTY: CRT: LPT: UL1:. Page zero: jp WBOOT at
  #0000, IOBYTE #0003, drive #0004, jp BDOS #0005, FCB #005C, DMA #0080, TPA from #0100
- CP/M 3: named character devices in a device table (up to 12, DEVICE command, baud rates),
  banked BIOS, disks through XDPH
- a way: programs see CP/M 3 style named devices (and the IOBYTE for 2.2 programs); behind
  them a driver table in the base 64k, each driver a module (init, status, in, out, ioctl).
  New hardware (serial, network, SD / M4) = more named devices or drives. New for multi
  system: pipes between systems (system 1 LST: -> system 2 RDR:)
- most CP/M programs only use BDOS calls; the ones that call the BIOS or hardware directly
  are the compatibility risk. DDT uses RST 38h for breakpoints, which is the IM 1 interrupt
  address
### Optimisations
Background (NTC.md section 3, 2026-10-12): one pass of the sieve's inner loop is 366 T in
NTC turbo against 107 T for SDCC. The work itself is the same (110 T against 107 T); the
rest is NTC's: variables loaded and stored in memory by every keyword (115 T), operand
addresses popped from the thread (90 T), and the `ret` / `jp` between keywords (51 T).
Normal mode adds about 90 T per branch (`ntc_xn`). Each item below cuts one of these.
Generic first: they help nearly every program. Gains are estimates from keyword T counts -
measure each with the bench set (`compare/bench/`) before and after.
