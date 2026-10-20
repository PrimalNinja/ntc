# Porting CyborgOS to the ZX Spectrum Next — porting notes

Living notes for the CyborgOS → ZX Spectrum Next port. Kept as the work goes so later ports (other
Z80 machines, the planned CPC-free virtual Z80) can reuse the hardware map and the decisions.
Started 2026-10-18.

## What CyborgOS is (the thing being ported)

The CPC 320K build (`src/bas/cyborgos320kb/`), in NTC BASIC:

- `Main.bas` (~1150 lines) — the hypervisor entry: the slot table, the keyboard hotkeys
  (Ctrl+1..0 to the front, Ctrl+ESC the TOP screen), the round-robin scheduler, the command
  dispatch.
- `Hyp.cls` (~5700 lines) — the hypervisor proper: bank/slot management, the far-call BDOS a task
  makes (console, keys, files, exit), per-slot text pages, the context switch, services (ports).
- `Ent.cls`, `Hot.cls` — entry/hotkey helpers.
- `apps/` (ying, yang, mon, rvdu, rat, pluto), `cmds/` (PS, DIR, CD, COPY, …), `tasks/`, `tools/`.

The model: up to 20 slots, **each its own 64K bank**; a slot is a command line or a `.CYB` CP/M
program running from `#0100`; programs run round-robin (front slot gets half the time); each BDOS
call is a far call into the hypervisor; characters out are collected per bank and sent a line at a
time; an interrupt stops a task and returns the CPU to the hypervisor.

So CyborgOS is **three things stacked**: (1) a banked-memory manager, (2) a round-robin scheduler
with a per-task context switch, (3) a syscall (BDOS) + console/keyboard/file service layer. The
port has to re-seat all three on Next hardware.

## The hardware map — CPC → ZX Spectrum Next

| Concern | CPC (now) | ZX Spectrum Next | Port impact |
|---|---|---|---|
| CPU | Z80 | Z80N (extra ops, optional) | none — NTC zxn uses no Z80N ops (works on any assembler/harness) |
| Base map | firmware ROM + 64K RAM, screen `#C000` | NTC zxn maps 8K MMU pages **to look CPC-like**: pages 16-21 at `#0000-#BFFF`, screen bank 5 at `#C000` | **the per-slot 64K already looks like the CPC** — big head start |
| Banking | gate array, 16K pages into `#4000-#7FFF` (`Option Memory CPCExpansion`) | **8K MMU**, 8 slots (NextReg `#50-#57`), any 8K page to any slot; up to 2MB = 256 pages | the window-switch primitive **exists** (`zxn_sel`, maps a 16K bank → MMU slots 2,3 / NextReg `#52,#53`); the **allocation scheme does not** (zxn `Memory` is Small-only — "8K pages come later") |
| Window | `#4000-#7FFF` reserved (`Option Reserve`) | same `#4000-#7FFF` = MMU slots 2,3 | unchanged — CyborgOS's window model maps straight onto two Next MMU slots |
| Text screen | CPC mode 2, 80×25 | Next **tilemap text, 80×32** (Mode 2), over the ULA | better than the CPC (80×32); per-slot text pages port directly |
| Keyboard | PPI matrix (`#F6`/PSG 14) | 8×5 matrix (`#xxFE`) + extended keys | NTC zxn already reads it; hotkeys (Ctrl+…) need the Next's Caps/Symbol-shift mapping |
| Storage | AMSDOS / UniDOS / IDE / M4, via background ROMs (`Option RomEnable All`) | NextZXOS / esxDOS on SD (FatFS) | the file layer (`Hyp.FileCall`, the `.CYB` loader) must retarget to NextZXOS file hooks — **no CPC disc ROM** |
| Firmware | CPC firmware jumpblocks (cpcfw build) | **none** | CyborgOS's cpcfw build leans on firmware for files; the Next build must be firmware-free (NTC zxn is already native/no-firmware) |
| Timing / IRQ | 300Hz / 50Hz | 50Hz (`IM 1`, `#0038`) | the scheduler's interrupt classes port; the clock divisor differs |
| Boot | RUN"/disc, AMSDOS header | `NAME.NEX` (SAVENEX), loaded by NextZXOS | the boot/loader (`COSLOAD.BIN`) → a `.NEX` start stub |

## What NTC's `zxn` target already gives us (verified in `asm/ntc_plat_zxn.asm`, `lib/zxn/`)

- A **CPC-like flat 64K** per program: MMU pages 16-21 at `#0000-#BFFF`, stack at `#BE00` down,
  screen bank 5 at `#C000-#FFFF`.
- **80×32 tilemap text** (Mode 2), font `font8x8_basic`, yellow-on-blue; `Mode`, `Locate`, `Print`,
  `Cls` all work.
- **Keyboard** read (`#xxFE`, Caps/Symbol shift mapping).
- **The window-switch primitive `zxn_sel`**: HL = a 16K bank → mapped into `#4000-#7FFF` (MMU slots
  2,3, NextReg `#52`/`#53`); bank 0 restores the program's own pages (bank 9 = pages 18,19). Keeps
  BC/DE/HL, re-asserted by the interrupt handler. Today it serves `Option NexData` (static data
  blocks); it is exactly the primitive a banked allocator needs.
- **NextReg access via ports `#243B`/`#253B`** (no Z80N opcodes) — portable to any assembler/harness.
- `.NEX` output via SAVENEX; the start stub turns off the NMI buttons, DivMMC auto-paging and
  DivMMC memory, sets 28MHz + IM 1, maps the slots, jumps to `ntc_start`.

## The gaps (what the port has to build)

1. **A Next MMU page-allocation scheme** (the keystone). NTC's zxn `Memory` is Small (no paging).
   CyborgOS needs to allocate 64K banks (= 8 × 8K Next pages) for slots, hold free/used page lists,
   and switch a bank into the window. The `zxn_sel` primitive is the bottom of this; the allocator
   (probe RAM size, free list, AllocPage/Free, Far pointers, Copy-through-window) is missing. Either
   extend the core `Memory` class with a `zxn` banking scheme (compiler support like
   `cpcexpansion`), or give CyborgOS-Next its own banking class with the same API the hypervisor
   already calls.
2. **The context switch** on the Next MMU. The CPC switches a slot by paging its 64K bank; the Next
   switch remaps MMU slots to the task's 8 pages. A full-64K task (not just a window) means mapping
   slots 0-5 (`#0000-#BFFF`) to the task's pages while the hypervisor's own pages are saved/restored
   — different from the CPC's "keep main RAM, page the window" dance.
3. **The file/BDOS layer** retargeted to NextZXOS (no CPC disc ROM); the `.CYB` loader → load from
   SD.
4. **Boot**: a `.NEX` that brings up the hypervisor (the CPC's COSLOAD/CYBORGOS.BIN chain → a Next
   loader).

## Plan (staged, foundation-first)

1. **Next MMU banking foundation** — ✅ DONE (2026-10-18). `src/bas/cyborgosnext/`: `bank_proof.bas`
   proves a 64K bank = 8 isolated 8K MMU pages through the window; `Banks.cls` wraps it (MapWin a
   16K bank, Probe RAM, Slots, SlotBank); `cap_proof.bas` reports **111 usable 16K banks = 27 ×
   64K slots** isolated on a 2MB Next (more than CyborgOS's 20-slot cap). All run on the `zxn`
   harness.
2. Fit it to the `Memory` class API the hypervisor uses (AllocPage, Pages, Far, Copy), so `Hyp.cls`
   can call it unchanged where possible. *(next)*
3. The context switch on the MMU; a round-robin proof (tasks switched on the interrupt, each in its
   own bank, each with its own state/text page). *(design below)*
4. The console/keyboard/BDOS service layer on Next text + keyboard.
5. The file layer on NextZXOS; the `.CYB`-equivalent loader.
6. Boot `.NEX`; fold the apps/cmds in.

## The context switch on the Next MMU (design)

The CPC switch is one atomic `out (c),c` at `#0044` that swaps the whole 64K bank; `#0046` in each
bank holds that bank's own `jp` to its receiver, so execution continues in the new bank. The Next
has no single-OUT full-64K swap — remapping takes up to 8 NextReg writes (`#50-#57`), and the code
doing them pages itself out mid-sequence. Two ways to re-seat it:

- **Fixed window layout (what the foundation uses, simplest).** Slots 0-1 + 4-7 (`#0000-#3FFF`,
  `#8000-#FFFF`) stay the **hypervisor + screen/text** (`#C000-#FFFF` is the Next's ULA screen +
  tilemap text already); slots 2-3 (`#4000-#7FFF`) are the **window** a task's bank is mapped into.
  Small tasks run from the window; the hypervisor never pages itself out. This is cooperative and
  bounded to 16K-at-a-time task code, but needs no switch-glue trick. Good for services and the
  command line.
- **Full-bank tasks (CP/M-style, the real goal).** A task is `#0000-#DFFF` (seven 8K pages = **56K**;
  only `#E000-#FFFF` is the system/tilemap region). The switch is **two-stage** (Julian's): enable
  the one 8K page holding the task's receiver, `jp` into it, and from there the receiver enables the
  other 48K. Per-task, like the CPC's `#0046` landing — details in "The Next re-seating" below.

**Task size note:** a full-bank task is **56K** (`#0000-#DFFF`), not the CPC's 64K, because
`#E000-#FFFF` is the tilemap/system region. CP/M's ~61K TPA shrinks to ~55K. Record as a
compatibility delta.

### The CPC switch mechanism, exactly (from `Hyp.cls`)

Every task bank and main RAM hold the **same** switch glue at the same low addresses:
- `#0000 jp WBOOT`, `#0005 jp STUB` (BDOS entry), `#0038 jp` the interrupt save.
- `#0044 out (c), c` — the gate-array bank flip (B = the `#7Fxx` port, C = the bank value).
- `#0046 jp` the landing: `ld sp, (#FFFE) : ret`.

`Run(setting)` preloads BC with the port+bank, jumps to `#0044`; the `out (c),c` flips the whole 64K
in one instruction, and because `#0040-#0048` is identical on both sides, the **next** byte executed
is `#0046` *in the new bank*, which loads that side's SP from its own `#FFFE` and `ret`s into it.
**Only SP changes** — A, DE, HL pass straight through as the far-call message. A task runs until it
calls BDOS (`call 5` → `#0005` → `STUB` at `#EF00`, a far call back: `Run` returns 1, Fn = C, Arg =
DE; the next `Run` answers with `Reply`'s A/HL) or an interrupt stops it (`Run` returns 0). The
per-slot text page is at `BUF #F700`; stubs at `STUB #EF00`; the slot's next key at `KEY #F681`.

### The Next re-seating, exactly (Julian's two-stage switch)

The Next has no one-instruction 64K flip — remapping takes several NextReg writes, and the code
doing them pages itself out when it rewrites its own slot. The CPC solves "continue in the new bank"
with the atomic `out (c),c` landing at `#0046`; the Next does it **in two stages — enable one 8K
page, jump into it, then from there enable the rest:**

1. **Enable the receiver 16K (two 8K blocks).** The natural Next unit is the 16K bank = two 8K MMU
   pages (both window slots, `#52`+`#53`) — the same two blocks `MapWin` enables. Each task bank has
   its **receiver** (the landing code) in its first 16K; the hypervisor maps **those two 8K blocks**
   into their slots (two NextReg writes), then `jp` to the receiver — now executing the new task's
   **own** 16K.
2. **The receiver enables the rest.** Running from the just-mapped receiver 16K (never paged out,
   because it is where execution is), the receiver maps the task's **remaining 8K pages** into their
   slots, loads the task's SP, and jumps into the task proper.

That is the whole trick: you never remap the slot you are executing from until you no longer need it.
It keeps the receiver **per-task** (the CPC's per-bank `#0046` idea), not in a shared system region.

Layout this implies:
- **A task is 56K** (`#0000-#DFFF`, MMU slots 0-6, seven 8K pages) — not 48K. Only **slot 7**
  (`#E000-#FFFF`) is system: the tilemap (`#E000-#E9FF`), tiles (`#EC00-#F3FF`), and the switch /
  stubs / hypervisor stack in `#F400-#FFFF`. (Text is the tilemap; the ULA screen isn't used, so
  `#C000-#DFFF` is task RAM.) The receiver page is one of the seven task pages — map it first.
- **Per-task SP** lives wherever the receiver can reach it (the task's own bank, or the slot table) —
  the CPC's `#FFFE` is in slot 7 (system) on the Next, so SP moves off `#FFFE`.
- **The BDOS stub** (`#0005 jp STUB`) and `BUF` (the text page) move out of the CPC's `#EF00`/`#F700`
  (which collide with the Next tilemap/tiles) to fit the slot-7 system map above.
- **Interrupts** still stop a task and return to the hypervisor; the IM 1 handler at `#0038` lives in
  a task page (slot 0) and re-asserts the hypervisor's map on the way back — the zxn platform already
  re-asserts `ntc_zxsel` from the handler, extended to the task's slots.

**Net:** the switch ports as the CPC mechanism re-seated — `out (c),c` + `#0046` becomes *enable the
receiver 16K (two 8K blocks) → jp → receiver enables the rest*. Task size is **56K**. No new NTC core
support — `Hyp.cls` asm + the Next memory-map constants.

## Proven so far (2026-10-18, on the `zxn` harness)

`src/bas/cyborgosnext/`:
- `Banks.cls` — the banking + allocation API the hypervisor needs: `MapWin` a 16K bank into
  `#4000-#7FFF`; `Probe` RAM; `Banks`/`Slots`/`SlotBank`; `Init`/`Alloc`/`Free` (a 64K-slot free
  list); `Copy` (cross-bank byte copy through a resident buffer, the way the hypervisor moves data
  between slots — cf. KEYMAN's SlotRead/SlotWrite). NextReg via ports `#243B`/`#253B`.
- `bank_proof.bas` — a 64K bank = 8 isolated 8K MMU pages through the window. **BANKING OK.**
- `cap_proof.bas` — **111 usable 16K banks = 27 × 64K slots**, all isolated (2MB Next).
- `sched_proof.bas` — round-robin over 3 tasks, each state in its own bank; counters advance
  independently (4 / 8 / 12 over 4 passes). The scheduler loop + per-task banked state proven.
- `alloc_proof.bas` — Alloc/Free (free-list reuse) and a 20-byte cross-bank Copy verified.

So **stage 1 (banking) is done and stage 2 (the Memory-style API: alloc, slots, cross-bank copy) is
substantially there.** What is NOT yet done (the real remainder): the asm register/SP context switch
(NTC's SP-as-IP model makes this the delicate bit — the switch is asm, not BASIC), the
BDOS/console/keyboard/file service layer on Next hardware, the boot `.NEX`, and folding
`Hyp.cls`/`Main.bas` onto this base.

## What breaks on compile (the inventory — `cli.js Main.bas Hyp.cls Ent.cls Hot.cls --platform=zxn`)

Only **7 errors** — the port's compile-blockers are concentrated in the banking layer and one CPC
routine, not spread through the hypervisor:

1. `Option Memory CPCExpansion is for the CPC platforms, not zxn` — needs a **zxn banking scheme**
   (the Next-MMU equivalent). Either add it to the core `Memory` class or teach `Option Memory` a
   `zxn`/`NextExpansion` scheme.
2. `Memory.Banks` / `Memory.AllocBank` / `Memory.BankPage` **unknown on zxn** — the banking API
   `Hyp.cls`/`Main.bas` call. These are exactly what `cyborgosnext/Banks.cls` already does:
   - CPC `Banks()` = number of 64K banks; `AllocBank()` = allocate one; `BankPage(bank,n) =
     4*bank-2+n` (a CPC 64K bank is 4 × 16K pages). On the Next a 64K slot is 4 × 16K banks too, so
     the same shape holds — `Banks.cls`'s `Slots`/`SlotBank`/`Alloc` are the Next versions.
   - **Path:** add `Banks`/`AllocBank`/`BankPage` (+ the `SelectPage`/`Far`/`Copy`/`ReadByte…` the
     hypervisor uses) to the **zxn `Memory` class**, presenting **16K "pages"** (each = two Next 8K
     MMU pages) so the CPC's 16K-page abstraction holds and the window maps via `zxn_sel`. This is
     the "fit to the Memory API" stage, done as a real NTC feature (`lib/zxn/Memory.cls` currently
     Small-only).
3. `not in library: ntc_plat_rmr` — the CPC gate-array **ROM/mode byte reader** (`#8x`), used by the
   hypervisor's asm to save/restore the mode/ROM state around a bank switch. The Next has no gate
   array; provide a zxn `ntc_plat_rmr` stub (return the Next's equivalent, or make the two Hyp.cls
   asm sites that use it `#If`-guarded for zxn).

Everything else (the ~20 warnings) is benign: `Option RomEnable` is a no-op on zxn, and the
unchecked `Copy`/`SelectPage` results are style warnings.

**So the critical path to a compiling Next CyborgOS is small and known:** (1) a zxn banking `Memory`
scheme presenting 16K pages over the Next MMU (the `Banks.cls` model, promoted into `lib/zxn/`), (2)
an `ntc_plat_rmr` stub, (3) retarget `Option Memory CPCExpansion` → the zxn scheme. *Compiling* is
not *running* — the switch asm (above), the BDOS/console/file layer and boot still need the Next
re-seating — but the banking wall, the thing that looked biggest, is essentially down.

## Generalizing: porting to any Z80 target (MSX and beyond)

The value of the inventory above is that it is the **same for every target** — only the mechanism
per layer changes. What is **portable, untouched** on any Z80 machine: NTC BASIC itself, the whole
hypervisor *logic* (`Hyp.cls`/`Main.bas` minus the hardware pokes), and **all the apps** (ying, yang,
mon, mon2, rvdu, rat, pluto) — they use abstractions, not hardware (mouse aside, now switchable). A
port is: re-seat these layers, leave everything else.

| Layer | CPC (source) | ZX Spectrum Next | MSX (sketch) |
|---|---|---|---|
| **Banking** | gate array `#7Fxx`, 16K pages | 8K MMU (`#50-#57`), two 8K = a 16K page | **memory mapper** ports `#FC-#FF`, native 16K pages into the 4 slots — *closest to the CPC model, easiest* |
| **Display / text** | CRTC `#BCxx` + firmware SCR | tilemap 80×32 (NextReg) | **VDP** (V9938/V9958) text mode via ports `#98-#9B`, VRAM |
| **Keyboard** | PPI matrix (platform) | `#xxFE` (platform) | PPI `#A9`/`#AA` / BIOS (platform) |
| **Files** | AMSDOS/UniDOS ROMs, CAS pack | NextZXOS/esxDOS (SD) | MSX-DOS / disk BIOS |
| **Clock / IRQ** | `KL TIME PLEASE` 300 Hz | 50 Hz frame / Next counter | VDP 50/60 Hz interrupt, optional RTC |
| **Mouse** | Amiga card `#F991/4/5` (now off) | Kempston `#FADF/FBDF/FFDF` | general-purpose (joystick) port via the PSG |
| **Network** | M4 WiFi `#FE00/#FC00` | Next WiFi (ESP/UART) | cartridge-specific / none |

The per-target work is always: **banking first** (everything depends on it), then **display +
files + clock** for a running system, then mouse/network as add-ons. For NTC specifically the
banking is the `mem_*` platform-asm routines (`asm/ntc_plat_<target>.asm`) behind the standard
`Memory` class — so a new target that fills in `mem_*` (16K pages over its mapper) and a text/file
back-end gets CyborgOS largely for free. MSX is notably the least work for banking: its memory
mapper is already 16K-paged like the CPC's.

## Install / boot on the Next

**Mechanism (already proven).** An NTC `zxn` build produces a `NAME.NEX` (SAVENEX). NextZXOS loads a
`.NEX` straight off the SD card and runs it — the start stub turns off the NMI buttons and DivMMC
auto-paging, sets 28 MHz + IM 1, maps the MMU slots, and jumps to the program. So *any* zxn program,
including the foundation proofs in `cyborgosnext/`, installs by **copying its `.NEX` to the SD and
running it** (the NextZXOS Browser → select it, the `.nex` dot-command, or autoboot). No installer.

**CyborgOS on the Next (the target shape):**
- `CYBORGOS.NEX` — the hypervisor (`Main.bas`+`Hyp.cls` built for zxn), carrying its core banks. Put
  it in a folder on the SD, e.g. `/CYBORGOS/`.
- The **apps and commands** (the `.CYB` equivalents — MON, YING, PS, DIR, …) as ordinary **files in
  that SD folder**, loaded on demand through the NextZXOS file layer (this replaces the CPC's
  IDE-drive `.CYB` loading).
- **Run / autoboot:** launch `CYBORGOS.NEX` from the NextZXOS Browser, or have the Next autostart it
  (NextZXOS `autoexec.bas`, or a per-folder autostart) so the machine boots straight into CyborgOS.

**Vs the CPC install:** the CPC chain was `COSLOAD.BIN` loading `CYBORGOS.Z1…` + `CYBORGOS.BIN` from
an IDE drive (cos-disk1/2/3, each with `INSTALL.BAS`, `FILES.DIR`). The Next collapses that to **one
`.NEX` + an SD folder of app files** — NextZXOS does what COSLOAD did, so there is no custom loader
to port.

**Status:** this is stage 6 (boot `.NEX`) on top of stage 5 (the NextZXOS file layer) — not built
yet. The `.NEX` packaging is free (every zxn build makes one); what it waits on is the hypervisor
*compiling* on zxn (the `mem_*` banking + display/file re-seat) so there is a `CYBORGOS.NEX` to copy,
and the command/app loader retargeting to NextZXOS file calls.

## Prior art

**SymbOS** already runs its banked, pre-emptive multitasking on the ZX Spectrum Next (as well as the
CPC and MSX). That is the proof the approach is **tractable, not research** — banked tasks + an MMU
context switch + a message/syscall layer are a solved shape on this hardware. The two-stage MMU
switch (enable the receiver 16K = two 8K blocks, jump, enable the rest) is established technique, not a novel
risk. Treat the CyborgOS-Next port as an engineering port of a known pattern, not an open problem.

## The banking port, scoped exactly (what "close the 7 errors" means)

`Memory.cls` is a **thin wrapper**: every method (`Pages`, `AllocPage`, `SelectPage`, `Copy`,
`Banks`, `AllocBank`, `ReadByte`…) is a few lines of inline asm that put the args in
`mem_a1`/`mem_a2`/`mem_a3` and `jp mem_go`/`mem_go0`/`mem_go4` to a routine pointer (`mem_pages`,
`mem_allocpage`, `mem_selpage`, `mem_copy`, `mem_bankcount`, `mem_allocbank`, …). **The real memory
manager — the page lists, the RAM probe, the window switch, Copy, the 64K-bank logic — lives in the
platform asm** (`asm/ntc_plat_cpc.asm`, the `mem_*` routines), not in the `.cls`.

So the banking port is: **re-implement the `mem_*` routines in `asm/ntc_plat_zxn.asm`**, the CPC
gate-array memory manager re-seated on the Next MMU (the window switch becomes NextReg `#52`/`#53`
writes, the probe becomes a Next RAM probe, a 16K "page" = two 8K MMU pages). The `.cls` wrapper is
then essentially the CPC one. The 19 methods CyborgOS uses (`WriteByte`, `Copy`, `WriteWord`,
`ReadByte`, `SelectPage`, `AllocPage`, `BankPage`, `ReadWord`, `FreePage`, `Pages`, `Banks`,
`Top`, `TableEnd`, `RamSize`, `PageType`, `Map`, `FreePages`, `AllocBank`, + the Type consts) are
the surface to cover. Plus the `ntc_plat_rmr` stub.

**`src/bas/cyborgosnext/Banks.cls` is the proven BASIC prototype of this `mem_*` logic** — the
window map, the probe, the slot/bank allocation and the cross-bank copy all work there on the real
Next target. Porting it to the platform-asm `mem_*` contract is mechanical but delicate (register
conventions, the `mem_go`/`mem_a1`/`mem_res` marshalling) and wants runtime testing against a
running hypervisor, which is why it is the next focused job rather than a session-tail rush.

## CPC-specific hardware inventory (searched — every `out`/`in` and firmware call)

Inline-asm `out`/`in` lives in only `Hyp.cls` and `cmds/FLOPPY.bas`. But **port access also comes
through the `Inp()`/`Out` built-ins** (BASIC, not asm) — the apps use those for the **mouse**, so
the apps are *not* fully clean. Full picture (searched both asm `out`/`in` and the `Inp`/`Out`
built-ins): the hardware is in `Hyp.cls`, `cmds/FLOPPY.bas`, `apps/mon/Mouse.cls`, and one rat demo.
The eight CPC-specific subsystems to re-seat:

1. **Banking** — gate array `#7FC0` (`out (c),c`, the bulk of the hits) + `KL ROM SELECT`/`DESELECT`
   (`#B90F`/`#B918`). → **Next MMU** (the `mem_*` port, already scoped). Most `out (c),c` are this.
2. **Display / screen** — the **CRTC** (`#BC00`/`#BC0C`/`#BC0D`: R12/R13 screen-base, offset/scroll)
   and `TXT SET M TABLE` (`#BBAB`, the font matrices). → the Next **tilemap / Layer 2** base and
   scroll via NextReg, and the zxn font. This is "which slot's screen is shown" + double-buffer +
   scroll. (The console/display layer.)
3. **Files** — the **CAS pack** firmware (`#BC7A` CAS IN CLOSE, `#BC8C` OUT OPEN, `#BC8F` OUT CLOSE,
   `#BC92` OUT ABANDON, `#BC95` OUT CHAR) + the disc ROM. → **NextZXOS / esxDOS** file calls on SD.
   (The file layer.)
4. **Command lookup** — `KL FIND COMMAND` (`#BCD4`) finds RSX commands in background ROMs. → the
   Next has no expansion ROMs; the "run a `.CYB` by name" path stays (load from SD), the
   external-ROM-command path drops.
5. **Clock / timing** — `KL TIME PLEASE` (`#BD0D`, 300 Hz). → the Next timer (50 Hz frame count, or
   the Next's own counter). Affects the scheduler slice length and TOP's per-second stats.
6. **Network — NET M4** (`#FE00`/`#FC00`, `outi`): the CPC's M4 WiFi board (packets out, answer in
   the M4's ROM). → the Next's own WiFi (ESP via UART/NextReg) or a stubbed `NET`. A separate driver;
   not needed for first boot.
7. **Floppy — `cmds/FLOPPY.bas`** (the µPD765 FDC: `#FB7E`/`#FA7E`, `in a,(c)`, `outi`, direct sector
   writes). → the Next has no CPC FDC. **Drop it** (or rewrite for SD) — CPC-floppy-only, not a core
   dependency.
8. **Mouse — `apps/mon/Mouse.cls`** (used by MON, MON2, YING, YANG): the **dual Amiga mouse card**,
   read with `Inp()` — `#F994` X, `#F995` Y (signed deltas), `#F991` buttons (bits 4/5/6).
   **2026-10-18: the mouse reading is now commented out** in `Mouse.cls` (`Present()` returns False,
   `Poll()` is a no-op) so the apps build keyboard-only on **both CPC and Next** for now; all four
   apps still compile clean. To bring it back: uncomment the `Inp()` reads for the CPC, or add a
   Next back-end — the Next's **Kempston mouse** (`#FBDF` X, `#FFDF` Y — *absolute* 0-255 counters,
   so Poll computes the delta, `#FADF` buttons). The apps call `Mouse.Present/Poll/MoveX/MoveY/
   Buttons` and are unchanged either way. (Also: `apps/rat/GREEN.bas` reads an ADC sensor via
   `Inp(ADCDAT)` — a demo, droppable.) Other `Inp`/`Peek(&HF6xx)` in the apps read CyborgOS's own
   per-slot memory (console cols/rows, command tail), not hardware — they move with the hypervisor.

**So the port's hardware work, in order:** banking (`mem_*`, scoped) → display (CRTC → tilemap) +
files (CAS → NextZXOS) + clock (TIME → Next timer) for a running system → then NET, floppy and the
mouse (`Mouse.cls` → Kempston) are small/optional add-ons. The apps need no change beyond `Mouse.cls`
getting a Next back-end. Keyboard is already the platform's (no raw PPI reads in CyborgOS).

## Decisions / gotchas log

- *2026-10-18* — The Next's per-program environment is already CPC-shaped by NTC's zxn platform, so
  the port is **not** a from-scratch rewrite of the single-task layer; it is a re-seat of the
  **banking + scheduler + syscall** layers. Start at banking because everything else depends on it.
- *2026-10-18* — `zxn_sel` maps a **16K** bank to the window (two 8K MMU pages). CyborgOS banks are
  64K; through a 16K window that is four window-loads, same as the CPC pages a 64K bank in 16K
  pieces. The Next's 8K granularity also allows finer maps if wanted later.
- *2026-10-18* — Keep NextReg writes through ports `#243B`/`#253B` (not Z80N `nextreg`) so the build
  stays assembler- and harness-agnostic, matching the rest of the zxn platform.
- *2026-10-18* — **Memory abstraction decision: 16K pages** (each = two Next 8K MMU pages), not
  native 8K. This keeps `BankPage(bank,n)=4*bank-2+n` and the whole CPC 16K-page model, so `Hyp.cls`
  compiles unchanged — a *port*, not a redesign. 8K-native would be a different OS.
- *2026-10-18* — **Context switch** is the CPC's `out (c),c`/`#0046` re-seated as Julian's two-stage
  MMU switch: enable the receiver 16K (two 8K blocks), `jp` in, then the receiver enables the rest.
  Task = 56K (`#0000-#DFFF`); slot 7 is the tilemap/system region.
- *2026-10-18* — **SymbOS** already runs banked pre-emptive multitasking on the Next (and CPC/MSX):
  this port is a known pattern, not research. Build it as engineering, not an open problem.
