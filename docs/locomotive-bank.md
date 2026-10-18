# Locomotive BASIC in a bank, with a client in another — what it takes

2026-10-18. Analysis only, no code. Based on the BASIC 1.1 unassembly (the uploaded
`locomotive.zip`, unpacked disassembly in `cpcbasic2/t/`), the firmware jumpblock includes, and
the CyborgOS / MCP / Flipper banking model (docs/cyborgos.md, memory: mcp, flipper,
locomotive-shell).

Short version: BASIC is welded to a fixed memory map and the firmware. You cannot run two live
BASICs at the same fixed addresses at once; the proven path (Flipper, MCP) is **one whole BASIC per
bank, swapped** — the upper ROM stays shared, you copy the live RAM workspace in and out. A true
**client/service split** (a client posts lines, a BASIC service runs them and returns results) is a
different and bigger job: it only works as a *batch* executor with the output stream redirected, and
it throws away everything interactive. Feasible, but limited, and not what Flipper/MCP do.

## 1. The memory map BASIC assumes

BASIC 1.1 is the **upper ROM**, `org $C000`, 16K at `#C000–#FFFF`, ROM header `defb $80`
(foreground ROM), name `BASIC` (`Initialisation.asm`). Not `#0000–#3FFF` — that is the lower
(firmware) ROM.

Everything else BASIC touches is at **absolute RAM addresses** it never relocates
(`Includes/MemoryBASIC.txt`, `MemoryBASIC.asm`):

- `#0000–#003F` — the firmware RST block. BASIC makes heavy use of it (50 `rst` sites): RST 1
  `LOW_JUMP` (`#0008`), RST 2 `SIDE_CALL` (`#0010`), the far-call restarts. Floating-point maths
  lives in the **lower ROM** and is reached through these (`REAL_…` jumpblock entries). This block
  must be the firmware's and must be live.
- `#AC00–#B0C7` — the **BASIC OS reserved area** (fixed): stream state, the AUTO/FOR/WHILE/event
  blocks, the `ON SQ` / `AFTER`/`EVERY` ticker blocks, the 256-byte line input area
  (`BASIC_input_area_for_lines_ EQU $AC8A`), error vars, the SOUND parameter block, the variable
  linked-list heads, `HIMEM` (`HIMEM_ EQU $AE5E`), the memory-model pointers (program end, vars,
  arrays, free space), the **execution stack** (`#AE70`, `&1FF` bytes — GOSUB/FOR/WHILE), the
  **string stack**, and the **virtual accumulator** (`#B0A0`). All fixed.
- The **program text, variables, arrays, free space and string space** live in low RAM from after
  the firmware area up to **HIMEM** (default top of free RAM ≈ `#A6FB`, just under the reserved
  area, leaving room for UDGs). These float with HIMEM but the *pointers* to them are the fixed
  words in `#AE5E…#AE6C`.
- The **CPU stack is reset to `#C000`** on every run / return to the command line (README,
  `Execution.asm`) — it grows down from `#C000` through the `#Bxxx` firmware/BASIC area.
- `#B100–#BFFF` — firmware RAM: system variables and the **high jumpblock** (`#B900+`:
  `KL_U_ROM_ENABLE #B900`, `KL_ROM_SELECT #B90F`, …). BASIC calls these to manage ROM state.
- `#C000–#FFFF` — screen RAM (and the address window the upper ROM shadows).

So BASIC's state is not a tidy blob. It is: a fixed `#AC00–#B0C7` control block, a fixed exec/string
stack and accumulator, a set of pointers into a low-RAM program/variable/string heap bounded by
HIMEM, the firmware RAM at `#B100+`, and the stack under `#C000`. One fixed map, one BASIC.

## 2. Firmware dependencies

BASIC is a thin language on top of the firmware. 188 jumpblock calls across the modules, every
group:

- **REAL_…** — floating-point maths is in the *lower ROM*; BASIC owns none of it
  (`Maths*.asm`, `ExprEvaluator.asm` call out for every real operation).
- **KL_…** — kernel: `KL_ROM_WALK`, `KL_ROM_SELECT`/`ENABLE`/`DISABLE`/`RESTORE` (`#B900–#B915`),
  event and ticker management (`KL_DEL_TICKER`, `KL_DONE_SYNC`), far calls.
- **TXT_… / SCR_… / GRA_…** — all screen output, windows, modes, graphics (`TextOutput.asm`,
  `Screen.asm`, `Graphics.asm`). BASIC's "output" *is* VDU characters to a stream, not a value.
- **KM_…** — keyboard, INKEY, the break key.
- **CAS_…** — cassette/disc I/O (`FileIO.asm`, `LoadSaveRun.asm`).
- **SOUND_…** — the sound chip, driven through events.
- **MC_START_PROGRAM** — restart.

Why this matters for banking: a firmware jumpblock is a **RAM vector** (`#B900+`, `#BB00+`,
`#BD00+`) that the firmware itself fixes up and that pages the right ROM in and out around the call.
So a call to `TXT_OUTPUT` or `REAL_ADD` works **from any bank** — *provided* the firmware RAM
(`#B100–#BFFF`), the RST block (`#0000–#003F`) and the lower ROM are present in the common address
space during the call. The hard-to-virtualise parts are the ones tied to the live machine: the
**screen** (one set of VDU matrices and one screen memory), **interrupts / tickers / events** (one
firmware event queue, `KL_` and the `#AC1E…#AC92` blocks), **INKEY and timing** (real time, one
keyboard). These are singletons; they don't fork per bank.

## 3. Putting BASIC in one bank, a client in another

### Can the ROM image just be copied into a RAM bank and run there?

Not usefully. BASIC runs at `#C000–#FFFF`. On the CPC that window is the **screen RAM** and, in a
64K-bank model, the bank's top page. Running BASIC *code* from RAM at `#C000` collides with the
screen and with where CyborgOS maps a slot's high page. The firmware's whole design is that BASIC is
the **upper ROM, paged in over** that window; reads at `#C000+` come from ROM, writes go to the RAM
(screen) behind it. You keep BASIC as the shared upper ROM. You do **not** get a second concurrent
BASIC by giving it a second code copy in a bank — you get it by giving it a second **workspace** and
swapping which workspace is live.

### What must stay in common / live RAM

- `#0000–#003F` firmware RST block (CyborgOS already needs `#0000–#003F` for CP/M vectors, but it
  puts its **bank switch at `#0044–#0048`** — that part is fine, BASIC doesn't use `#0040+`; the RST
  entries below it must be the firmware's).
- `#B100–#BFFF` firmware RAM + jumpblocks.
- The screen `#C000–#FFFF`.
- The upper ROM (BASIC) paged in while BASIC runs; the lower ROM reachable for the jumpblock calls.
- The stack region just under `#C000`.

### What is "a BASIC instance"

The swappable state is: the `#AC00–#B0C7` reserved block, the exec stack `#AE70+`, the string stack,
the accumulator, **and** the program/variable/string heap from the low-RAM base up to that
instance's HIMEM. To switch instances you save the live copy of all of that to a bank and restore
another bank's copy — exactly "don't trash important RAM at the time" (memory: locomotive-shell).
That is what **Flipper** does (swap between many CPC BASICs) and what **MCP** does (tasks in 16K
banks, switched from a ticker). The ROM is shared; the RAM map is swapped.

### The hard parts

- **Absolute addresses.** Two instances cannot both be live at `#AC00`/`#AE70`/HIMEM at once; only
  the mapped one is. So it is swap, not coexist. A copy of ~`#AC00–#B0C7` (≈1.2K) plus the heap up
  to HIMEM (potentially tens of K) moves on each switch. MCP keeps instances in 16K banks and
  accepts the copy cost on the ticker switch.
- **ROM / HIMEM selection.** Each instance's HIMEM and ROM-select state (`#AC24`, the event blocks'
  ROM-select bytes) must travel with it.
- **The screen.** One screen, one set of VDU matrices. Either the front instance owns it (CyborgOS
  already does this per slot — the front slot draws, the others collect characters in their bank),
  or each instance writes to its own captured stream.
- **Interrupts / events / tickers.** One firmware event chain. AFTER/EVERY/ON SQ/ON BREAK blocks
  live in each instance's `#AC1E–#AC92`. A background instance's timers would keep firing against
  the live chain unless they are detached on switch-out (`KL_DEL_TICKER`) and re-armed on
  switch-in. This is the fiddly bit and the one most likely to "trash important RAM during I/O".
- **Self-reset to `#C000`.** The stack reset on every run assumes `#C000` is free stack space, not a
  bank boundary — fine as long as the common map keeps `#C000` as stack/screen.

## 4. The service split — client posts lines, BASIC answers

This is the thing the brief floats ("maybe it can work like a service"). It is **not** what
Flipper/MCP do, and it is harder, because BASIC has no "evaluate and return" API — it has a REPL
that reads a line, tokenises it, executes it, and **prints to the screen**.

What a service *could* look like:

- The client (another bank / slot) posts a request through a CyborgOS **port** (8 named 128-byte
  mailboxes, docs/cyborgos.md) or a shared buffer: "run these program lines", or "execute this
  direct command", or "give me the value of this expression".
- The BASIC service, in its bank, drops the line into the **line input area `#AC8A`** (the same
  256-byte buffer the REPL fills), calls the tokeniser (`Tokenising.asm`) and the executor
  (`Execution.asm`), with its **output stream redirected** away from the screen to a file/printer
  stream or a hooked `TXT_OUTPUT`, so the printed result lands in a buffer instead of on screen
  (streams already support screen/printer/file — `Streams.asm`, `StreamIO.asm`).
- It returns the captured text plus `ERR`/`DERR` (`#ADAA`) through the port.

What crosses the boundary cleanly: a line of program text in, captured PRINT output + an error
number out. What does **not** survive:

- **Interactive editing** — EDIT, AUTO, the line editor (which lives in the lower ROM and talks to
  the live keyboard and screen). A service is batch only.
- **INKEY / JOY / real-time events / AFTER / EVERY / ON BREAK** — these need the live keyboard,
  timer and event chain of the *front* machine; a backgrounded service bank doesn't have them in any
  meaningful real-time sense.
- **Timing** — anything using `TIME`, SOUND durations, or frame timing is wrong when the service
  only runs in the slices the scheduler gives it.
- **Graphics / direct screen** — a redirected text stream captures PRINT, not PLOT/DRAW or direct
  screen pokes.

So the realistic service is: **a headless BASIC batch evaluator** — "here is some BASIC, run it,
here is the text it printed and whether it errored." Useful as a scripting/compute service (compute
a value, run a data-processing program, generate text), useless as interactive BASIC. It is a
custom shim around the tokeniser + executor + stream redirection, perhaps 1–2 pages of glue, plus
the port protocol — not a rewrite of BASIC, but real work and real limits.

## 5. Recommendation

- **Feasible, two ways, pick by goal.**
- **If the goal is "run several BASICs, switch between them" (interactive):** do what Flipper/MCP
  already prove — **one whole BASIC per bank, shared upper ROM, swap the live RAM workspace**
  (`#AC00–#B0C7` + exec/string stacks + the heap to HIMEM) on switch, detach/re-arm tickers and
  events across the switch, and let the front instance own the screen. CyborgOS already does the
  bank-copy and front-slot-owns-screen dance for its CP/M slots; a "BASIC slot" is that plus the
  upper-ROM-stays-paged and fixed-workspace-swap handling. **Modest effort**, known-good, the
  natural fit. Main risk: the event/ticker chain and disc I/O windows — switching mid-I/O or with a
  timer armed is where it bites ("don't trash important RAM at the time").
- **If the goal is "a BASIC service a program can call to run code and get text back" (batch):**
  build the headless shim — port in, line into `#AC8A`, tokenise + execute with the output stream
  redirected to a buffer, text + `ERR` out. **Bigger, bounded, and lossy** (no interactivity,
  INKEY, events, timing, graphics). Worth it only if you actually want BASIC-as-a-scripting-engine.
- **Do not** try to run a second BASIC from a code copy in a bank at `#C000`, or to have two
  workspaces live at the fixed addresses at once. The fixed map forbids it; everything above is a
  way around that one fact.
- **Cheapest useful first step:** a single BASIC instance as one CyborgOS slot (shared upper ROM,
  its own banked workspace, it owns the screen when in front), proving the ROM-paging + fixed-
  workspace handling. Multiple instances (Flipper-style swap) and the batch service are increments
  on top of that.
