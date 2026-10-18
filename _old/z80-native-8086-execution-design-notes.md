# Z80 Native 8086 Execution — Design Notes

Working notes on running 8086 code on a Z80 using a decode-free dispatch trick,
not a conventional emulator. For future continuation.

---

## The core idea

Every byte value 0x00–0xFF is a valid Z80 instruction (documented or
undocumented). So any x86 binary is also a valid Z80 binary — the same bytes,
read by two different decoders, are two different native programs at once. This
is the whole foundation. Nothing is translated; the meaning is a function of
which decoder looks at the bytes.

Proven already with a polyglot boot trampoline: one image where the first few
bytes vector a Z80, an 8086, and a 6502 each to their own entry point, because
the same bytes decode as a jump on each chip.

## Decode-free dispatch (the "double the bytes" method)

Goal: turn an opcode byte into "start running its handler" without ever
examining the byte. That is what makes it native rather than emulation — a
real silicon decoder wires opcode bits straight to a microcode entry; there is
no fetch-then-branch.

Method: interleave each x86 byte so it becomes the high byte of a 16-bit word,
low byte 0x00. So opcode NN sits as the word 0xNN00 — which *is* the address of
its handler page. Handlers live at 0x0100, 0x0200, ... 0xFF00, one 256-byte page
each (or fall through / RET for no-ops).

The engine is three instructions:

    di
    ld sp, start
    ret

SP is pointed at the interleaved image and becomes the instruction pointer. RET
pops 0xNN00 straight into PC — the RET *is* the dispatch. Each handler ends with
its own RET to pull the next opcode. DI because SP is now the IP; an interrupt
would push PC into the middle of the thread.

This is NTC (Native Threaded Code) pointed at an x86 image instead of a
hand-built thread. The thread already exists — it's the x86 binary, expanded.
The opcode value and the handler address are forced to be the same number by the
layout, so there is no mapping to compute.

### Why doubling is mandatory, not a choice

Opcode is 8-bit, handler address is 16-bit. To make opcode-value == handler-
address *physical*, the opcode must occupy the high byte and something must fill
the low byte. That filler is the second byte — that is the double. You cannot
have physical identity between an 8-bit value and a 16-bit address without
spending the other 8 bits. The doubling is those 8 bits falling out of the
requirement.

LD HL,(x) / JP (HL) is the *only* other dispatch route, and it has a decode step:
HL holds a *value* you then have to *use*. That inspection step is the emulation
signature. RET has no such step: SP holds a pointer that already *is* the thread.
That structural difference is exactly the native/emulation line. There is no
third mechanism to get a byte into PC on a Z80.

The one thing that retires the doubling: a bus-side PLD that presents 0xNN00 when
the walk reads a single-density real byte — moving the low 8 bits from RAM into
silicon. Same 8 bits, paid in a chip.

## Low-byte value (settled: 0x00)

Explored 0x01/0x02/0x03/0x04 as the filler. Landed on 0x00 — the word is the
handler address directly, no arithmetic, no offsets. Table:

    x86 byte | Z80 ptr addr | stored word | high byte | low byte
    0x01     | 0x0000       | 0x0100      | 0x01      | 0x00
    0x02     | 0x0002       | 0x0200      | 0x02      | 0x00
    0x03     | 0x0004       | 0x0300      | 0x03      | 0x00
    0x04     | 0x0006       | 0x0400      | 0x04      | 0x00

Physical bytes, little-endian: 00 01 00 02 00 03 00 04 ...

(Do NOT reintroduce a "load an address" step — RET off SP is the dispatch, no
LD HL / JP (HL). That was a wrong turn.)

## Memory map (Amstrad CPC, 4MB)

- First 64KB = CPC main RAM + video RAM.
- 2nd 64KB through to the rest of 4MB = 256 × 64KB banks.
- Full 64KB bank swap in a single hit (MCP-style ~300 T-state remap).
- To simulate a 512KB 8086: ~1MB for the doubled code image + a 2nd MB for data.

### Two apertures — asymmetric

- **Code aperture:** doubled, page-geometried, RET dispatches, segment = bank.
  The constraint buys automatic execution.
- **Data aperture:** 1:1, linear, seg<<4 + offset, paragraph-granular. NO
  doubling — data doesn't need it. This is a key refinement: data runs at single
  density, so a MB of data holds twice as much, and paragraph-granular segment
  overlap (DS = CS+0x1000 etc.) becomes expressible again.

A 64KB Z80 page = half an 8086 segment once doubled (0x8000 real bytes). So a
full 8086 segment = two Z80 pages, and the segment boundary falls on a page
boundary — segment loads become bank switches, not seg<<4 arithmetic, for the
code walk. Data still does honest seg<<4+offset.

## The state model

- Z80 SP = the thread/IP. NEVER used as a stack.
- 8086 register file: pinned into Z80 register pairs where possible, rest in
  fixed memory. Static, resident allocation — no stack to save/restore to.
- 8086 flags: kept as a verbatim byte, Z80 native flags are just scratch used to
  derive them. Flag *bit position* is irrelevant — treat the 8086 flag byte as
  authoritative and simulate on the Z80's. **Lazy flags** (compute the specific
  flag only when a conditional consults it) is the highest-leverage optimisation;
  the 256-byte-per-opcode room pays for it.
- 8086 stack: SS:SP is a separate, mutable segment. Simulated as data (pointer in
  IX or fixed memory), NOT the Z80 hardware stack. PUSH/POP/CALL/RET are explicit
  LD/INC/DEC against the data aperture.
- Handlers may NOT use the Z80 stack for scratch either — PUSH HL would corrupt
  the thread pointer. Same rule as NTC. Scratch is registers and fixed memory.

## The classification problem and how it's dodged

Can't tell code from data at load time — parsing to find out *is* emulation
(it's writing a disassembler). Dodged spatially and by operation class:

- **Sequential flow:** automatic. Each handler knows its own opcode's length
  (it got there *by* the opcode), so it advances SP past its own operands and
  lands exactly on the next boundary. Boundary discovery is a side effect of
  dispatch, not a pass. Mid-instruction splits are structurally impossible
  because detection only happens at a handler's operand-consume completion,
  which is by definition a boundary.
- **Memory reads:** pick the data aperture. Never need the code image, a
  boundary, or f().
- **Memory writes:** update BOTH apertures. If it was data, the code-image copy
  is never walked (harmless). If it was code (SMC), the code image is now
  correct. No intent-detection needed — the ambiguous case is made correct in
  both readings, same trick as the doubling itself.
- **Control transfers (RET/JMP/CALL/Jcc/INT/IRET):** the ONLY class that must
  resolve a target and possibly cross/reseat. These check.

So the only runtime consumer of f(guest-addr → physical) is control transfers
(and the code-half of writes in the SMC build). A minority of instructions.

## Segment / bank crossing

Mechanism: a sentinel at the boundary that traps into a fix-up, not a per-op
boundary check. Same discipline as everywhere: don't test the hot path, put a
thing at the edge that dispatches when reached. Complete 64KB bank swap in one
hit; no memory copy — banking moves the window to the bytes, the bytes never
travel.

- Forward straight-line crossing: automatic (the handler that steps past the
  edge detects it via guest-IP vs. segment-limit, which it's computing anyway).
- Sequential "go next" including auto segment-crossing: solved.
- Backward / computed / indirect targets: NOT solved by the forward walk —
  they land from elsewhere and need f(target guest-addr → physical). This is the
  reverse map.

### The open pivot: is placement formulaic?

If physical = f(guest linear IP) is a clean formula (fixed stride ×2, adjusted
for skip zones), then BOTH directions are automatic — forward by lockstep
advance, backward/computed by evaluating f(target) on the spot, no map, no table.
If variable instruction length forces an arbitrary dense pack, forward is
automatic but computed targets need a bounded lookup.

**This is the main unresolved design question.** Everything reduces to whether f
can be arithmetic.

### Control-flow-driven discovery (if not formulaic)

Only need boundaries where control flow actually goes. Discover by following
jumps from entry (recursive descent), not by linear byte scan — visits only real
code, never data, sidesteps code/data ambiguity. Basic blocks are far shorter
than a 32KB-real bank, so straight-line runs fit within a bank and bank crossings
land on branches, which are boundaries by definition. Indirect/computed branches
fall to a lazy runtime path: resolve target, decode that one boundary once, cache.

Requires a known entry point + direct-branch graph to seed. Fine for packaged
code; arbitrary cold-start binaries fall entirely to the lazy path (still works,
pays first-touch decode per unique boundary).

## Stack segmentation + return addresses

The sentinel is also the reconciliation point between the two address worlds
(physical-thread vs. guest CS:IP). Between sentinels: fast physical returns. At a
sentinel: reconcile once, in bulk, rarely.

Fork on what a CALL pushes:
- **Guest CS:IP** — correct for code that inspects its own return addresses
  (PIC, stack walking); needs IP→physical on RET, but the resident-bounded stack
  makes that a small in-view lookup, not a 1MB paged map.
- **Physical thread address** — fast, map-free; breaks the instant guest code
  reads its own stacked return address mid-segment. Named exclusion.

Stack kept resident and contiguous between sentinels (a 64KB Z80 page holds a
full 64KB real data segment, no doubling tax, so one stack segment fits). May
want the data side to bank DS and SS independently so neither seams mid-op.

## SMC build variants (precedent: UAE / Amiga emulators had the toggle)

SMC-vs-not is a property of the target program, not a runtime state — so it's a
build-time variant.

- **Full-SMC:** writes hit both apertures always. Constant write tax.
- **No-SMC:** writes hit data only; direct transfers pre-baked to physical at
  load; code image immutable. Faster. Wrong on self-modifying guests
  (predictably wrong — walks the stale byte, not a crash).
- **No-SMC-after-init:** both apertures during load/init (covers .EXE relocation
  and decrunch-then-run, which was near-universal on Amiga), then data-only for
  steady state. Probably the real-world default.

Detection trick (better than UAE's per-title compatibility lists): instrument a
no-SMC build so writes assert/log if they hit a code region. Run once — if
nothing trips, the fast build is proven safe for that binary. Classification
becomes measured, not guessed.

Positional-doubling handles SMC MORE cheaply than a JIT: one-byte update, no
block to invalidate, no recompilation storm. Z80's lack of cache/pipeline means
a write completes before the subsequent read that walks it — naturally ordered,
safe where a cached host wouldn't be.

## Performance

Per-instruction budget: ~20 T dispatch (RET in + handler's RET out, the RET doing
double duty as next fetch) wrapping every instruction, plus body.

- Register 8086 ops map ~1:1 onto Z80 if state is register-pinned.
- The tax was going to be eager flags — but lazy flags kills it. With lazy flags
  + register-pinned state, a common instruction is ~15–20 T body.
- Expect ~45,000–65,000 8086 IPS on a 4MHz Z80. Mix-dependent.

Ratio: at equal clock, NOT >0.25x — the ~20 T dispatch alone caps near 0.3–0.4x
even with a zero-cost body. Realistic ~0.06–0.15x of a same-clock 8086
(≈8–15x slowdown). Useful for I/O-bound / interpreter / text / CP/M-86 tool code
that had slack anyway; not for code that was already CPU-bound on real hardware.

### JIT / handler-stitching (upgrade path)

Full JIT: 2–3x on hot code from dispatch elimination, but needs a hot-path
detector, a code cache eating scarce banked address space, dual-engine
complexity, and re-introduces SMC block-invalidation (forfeits the cheap-SMC
advantage). Worth it specifically to reach CPU-bound workloads the interpreter
can't, not as a general speedup.

Middle path — **handler-stitching / block-linking:** concatenate existing handler
bodies with the inter-handler RETs removed, patch the last to jump to the next
block. No instruction selector, no register allocation — just inline the handler
bodies already written. ~90% of the JIT reward (dispatch elimination) for ~30% of
the difficulty. Probably the sweet spot. 4MB provides the cache room.

## Why Z80 is the format-native host (and 68000 is not)

Both Z80 and 8086 descend from the Intel 8080 (Z80 by binary superset; 8086 by
8080-asm source translation, e.g. XLT86 — NOT binary-compatible with each other,
8080 *siblings*). That shared parent is why they share three things the technique
exploits:

1. **Byte-opcode encoding** — both have fully-populated 256-entry primary maps.
   This is what makes 0xNN00 == handler-address expressible. The 68000 is a
   word-opcode ISA; the doubling identity CANNOT be constructed on it. The trick
   is structurally unavailable to a 68000, regardless of its power.
2. **Little-endian** — Z80 agrees with 8086, zero byte-swaps. 68000 is
   big-endian: swaps on most 16-bit operands and all 16-bit memory traffic,
   forever, on the hot path.
3. **Register-pair idiom** — 8080's register pairs → Z80 BC/DE/HL and 8086's
   AX/AL/AH; handler mapping is tractable.

Where 68000 keeps real advantages: register width/count (holds whole 8086 state
resident) and cheap seg<<4+offset. Those are situational (only bite register-
pressure-heavy and addressing-heavy code). The Z80's wins are per-instruction-
universal. So on compute/control/small-operand code the Z80 matches or beats a
68000-hosted 8086; on pointer/data-heavy code it trails.

### Transformer (Amiga 8088 software emulator) comparison

Transformer was slow for structural reasons, not (only) bad C: naive fetch-decode
loop (no dispatch amortisation), eager flags, per-reference segmentation, CGA→
bitplane screen conversion, AND big-endian byte swaps. The Z80 escapes #1
(RET-walk), #2 (lazy flags), and #5 (endianness) for free. It does NOT escape
screen conversion — the CPC has no blitter, the A500 does, so on screen-heavy
software the Z80 could lose despite CPU parity. Fair-fight benchmark: a pure-
compute, no-screen 8086 kernel, IPS measured directly.

4MB advantage: does NOT speed the hot path (that's decided in the bottom 64KB).
It (a) eliminates the floppy-paging cliff that dominated Transformer's felt
slowness on real-sized programs, (b) makes the doubling tax affordable at real
program sizes — the enabling condition, impossible on a period 512KB A500,
(c) provides code-cache room for the stitching upgrade. The technique was stupid
in 1986 (RAM too dear) and viable now for the one reason that changed: memory
price.

## "Bittage is a property of reading, not of software"

Settled position from the thread. A binary is just bytes; bytes have no bitness.
"8-bit"/"16-bit software" names a *relationship* between a byte stream and a
chosen decoder, not a property the bytes carry.

Proofs, four independent:
- **Polyglot:** same bytes are a live Z80, 8086 and 6502 program at once. If
  bitness were in the software, one stream couldn't be all three.
- **Authoring:** author 8086 code on a Z80 (8-bit machine), save it, run it on an
  8086 as 16-bit — bit-identical throughout, copied not converted. A copy that
  preserves every bit can't change a property that lives in the bits.
- **Notation:** using 8086 instructions as an *authoring alphabet* to write
  software the Z80 runs natively — the instruction-set-of-authorship and the
  target disagree on purpose, so no single bitness value exists.
- **Simultaneous native execution:** the same bytes run natively on the Z80 AND
  on an 8086 — two native executions, two decoders, no host, no conversion,
  neither primary. Not "8-bit modelling 16-bit" — genuinely both, fully, at once.

Gemini's error: calling the bytes "fundamentally 16-bit software" reifies the
shorthand into an essence, and does so about a case (Z80 running it natively)
that actively disproves it — erasing the 8-bit execution literally occurring.
Correct statement: the 8086 ISA's *operations* are 16-bit; the *software* is just
bytes structured so a 16-bit-operation decoder produces the intended behaviour.

Conclusion: **just software** — running natively as whatever reads it, on every
chip that can, out of one unchanged byte stream.

---

## Open questions to resume on

1. **Is f(guest-addr → physical) formulaic?** The one load-bearing unknown.
   Formulaic ⇒ whole machine is closed-form, no map, both flow directions
   automatic. Arbitrary-pack ⇒ bounded lookup for computed targets.
2. **8086 register → Z80 allocation:** pin the four hottest (AX + addressing
   pair for [BX/SI/DI]) into BC/DE/HL/IX and memory the rest, or lean on EXX for
   two banks of four?
3. **Return-address form:** guest CS:IP (correct, bounded lookup) vs. physical
   (fast, excludes self-inspecting-stack code).
4. **Target model:** small/tiny (SS=DS, one resident page, frictionless) vs. full
   segmented .EXE (data/stack banking to trampoline — the annoying ~5%).
5. **Screen/device translation:** the sleeper cost. What does target software do
   to the screen? Text-mode maps cheaply; CGA graphics inherits Transformer's
   actual nemesis with no blitter.
6. **Proof kernel:** pick a compute kernel (checksum loop, bytewise REP scan),
   hand-count Z80 T-states per iteration, derive predicted IPS, set beside a
   68000-interpreter count for the same loop. Turns "plausibly matches
   Transformer" into a number.
7. **Deployment guest:** is 8086 the actual target (specific DOS/CP/M-86
   software), or the stress-test proving ground for a cleaner deployment guest
   (a VM, a fixed-width retro CPU, or an ISA designed to fit the doubling with
   none of the four 8086 taxes)?