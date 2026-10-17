# CVM - the CyborgOS virtual machine (draft)

(c) 2026 Cyborg Unicorn Pty Ltd - MIT License

A Z80 with only what CyborgOS needs and none of the CPC's baggage: no gate array, CRTC, floppy
controller, firmware, UniDOS or M4. One small host core, written in portable C, runs it
everywhere:

- a Windows console or window;
- Linux, including the planned minimal kernel that boots straight into it;
- a browser (the core as WebAssembly);
- the Xbox One (a UWP app in Developer Mode).

NTC gets a platform for it, `cvm`, beside `cpcfw`, `cpm` and `zxn`. CyborgOS is rebuilt for it,
and its `.CYB` programs run unchanged: they only see the BDOS and BIOS, which the hypervisor
gives them.

Draft: the numbers below are proposals, to be settled before the core is written.

## 1. The CPU

- A Z80, all its documented and undocumented instructions (the `chips` z80.h core: zlib licence).
- Clock: the host's choice, from 4MHz (a CPC's speed, for testing) up to as fast as the host
  goes. A frame is 1/50 s of Z80 time, however fast it runs.
- Interrupts: IM 1 (RST #38), a timer at a rate set by the program (50Hz to start; the
  hypervisor's time slices). NMI: unused.
- HALT waits for the next interrupt, and the host idles meanwhile (no busy loop on a battery or
  a console).

## 2. Memory

- 16K pages, up to 4096 of them: 64MB. The host decides how many are there (4MB to start).
- Four windows: #0000, #4000, #8000, #C000. Any page can go in any window, and the same page in
  two at once.
- At reset, pages 0-3 are in windows 0-3, and the boot image is loaded at #0000 (section 6).
- No ROMs: nothing is read-only, nothing is paged in by the hardware.

## 3. Ports

8-bit port numbers (A0-A7; the upper byte is ignored unless a port says so). All the rest is
done by host calls (section 4), so the ports stay few.

| Port | Out | In |
|---|---|---|
| #00-#03 | window 0-3's page, low byte | the page there, low byte |
| #04-#07 | window 0-3's page, high byte (4 bits): takes effect with it | the high byte |
| #08 | - | the number of pages there, low byte |
| #09 | - | the number of pages there, high byte |
| #10 | a host call's block address, low byte | - |
| #11 | the block address, high byte: the host call runs now | the last host call's status (0 done) |
| #20 | the timer's rate in Hz (0 off) | - |
| #21 | - | the 1/300 s clock, low byte (latched with #22) |
| #22 | - | the clock, high byte |
| #30 | the text screen's page (section 5) | its page |
| #31 | the screen's mode: 0 text, 1 bitmap (later) | the mode |
| #40 | - | a key waiting (0 none): its code, taken |
| #41 | - | the shift, control and alt state (bits 0-2) |
| #FF | a byte to the host's debug log | - |

A page change is immediate: an `out` to #04-#07 maps the new page before the next instruction
runs.

## 4. Host calls

The program puts a block in memory and writes its address to #10 and #11. The host does the work
before the next instruction, as the M4 board does but with no waiting. The block:

| Offset | |
|---|---|
| +0 | the call's number (2 bytes) |
| +2 | the status back (2 bytes: 0 done, else an error) |
| +4 | the call's own fields |

Addresses in a block are Z80 addresses, as mapped when the call is made.

| Number | Call | Fields |
|---|---|---|
| #0001 | the host's name and version | address, length: the text back |
| #0002 | the date and time | 7 bytes back: year (2), month, day, hours, minutes, seconds |
| #0003 | the VM's speed | its MHz (2 bytes) in or out |
| #0100 | open a file | name address (a host path, `/` separated, under the VM's root), mode (read, write, update, append) -> handle |
| #0101 | read | handle, address, length -> length read |
| #0102 | write | handle, address, length -> length written |
| #0103 | seek, tell | handle, position (4 bytes) |
| #0104 | close | handle |
| #0105 | a directory's next entry | folder name address, index -> name, length, kind (file, folder), date |
| #0106 | delete, rename, make a folder, remove one | names |
| #0107 | a file's size, date, kind | name -> size, date, kind |
| #0200 | a socket | kind (TCP) -> handle |
| #0201 | name lookup | name address -> IPv4 address (4 bytes) |
| #0202 | connect | handle, address, port |
| #0203 | send | handle, address, length -> length sent |
| #0204 | receive (not waiting) | handle, address, length -> length received (0 none yet) |
| #0205 | close | handle |
| #0206 | listen, accept | handle, port -> a new handle (servers: the BBS, a web server) |
| #0300 | pages in one go | from page and offset, to page and offset, length: a block copy without mapping |
| #0400 | sound (later) | - |

The file calls work on the host's own folders: CyborgOS's drives become folders under the VM's
root (`A/`, `Z/`, `IDE/`...), and long names, folders and dates come for free. There are no disc
images and no sectors.

## 5. The screen

- **Text mode:** the screen is a page set by #30. Its first 8K is the text: up to 128 columns ×
  32 rows, a character byte and an attribute byte each (ink, paper: 16 colours). Its next bytes
  are the columns, the rows, the cursor (column, row, on or off) and a 16-entry palette (RGB, a
  byte each).
- **Rendering:** the host draws that page every frame, with its own font (the CPC's 8×8, or any
  other), scaled to the window or the TV. The hypervisor writes a slot's text page there, and
  switching slots is a copy or a change of #30. Double buffering is two pages and a change of #30.
- **Bitmap mode (later):** 320×200 or 640×400 at 4 bits a pixel, over two pages. It's for
  graphics programs, not the console.

## 6. Booting

- The host loads `BOOT.BIN` (the hypervisor) from the root into page 0 at #0000 and starts it
  there. The command line can go at a fixed place, as `CYB A` does now at #BE80.
- No firmware: the hypervisor sets its own stack and interrupt vector, and everything it needs is
  in the ports and host calls.

## 7. What changes in CyborgOS

- **The hypervisor:**
  - bank switching by #00-#07 instead of the gate array;
  - its console renderer writes the text page instead of CPC screen memory, with no CRTC;
  - drives and folders through the file calls instead of AMSDOS and UniDOS;
  - the network through the socket calls instead of the M4.
- **Unchanged:** the slots, the BDOS and BIOS the programs see, ports, claims and the RAM discs.
  RAM discs become plain pages.
- **Gone:**
  - FLOPPY;
  - the CRTC screen modes: MODE becomes the text page's size;
  - hardware the CPC had and the VM has no port for.
- **Unchanged programs:** RAT, MODEL, RATBOX, RVDU, MON and YING. Their `.CYB` files are the same
  for both builds.

## 7a. What stays the same, and what grows

It is still a Z80 inside, on the Xbox too. Every program sees 64K, every limit that comes from
that stays:

- a program's code and data in its slot's 64K bank;
- a page seen through a 16K window;
- the text screen within one page;
- YING's and YANG's page buffers, the 128-byte port messages, NTC's string sizes.

A program that fits a CPC fits CVM, and nothing gets bigger for a program.

What grows is how many there are, and how fast they run:

- **Slots.** A slot is a 64K bank, 4 pages. 4MB gives 60-odd, 64MB about 1000. With the Z80
  running at hundreds of MHz on the host, hundreds of slots each get a usable share. That's many
  programs and services side by side: a model per kind of creature, servers, viewers, tools.
- **The hypervisor's tables** must grow with it. The slot table, the claims, the ports (8 now, 64
  or more) and the ready queue are sized for 20 slots today. A slot number that fits a byte allows
  250; more needs two bytes in BDOS 131's answers. The scheduler must stay cheap with hundreds of
  slots: only the slots that are ready get a turn, so a sleeping one (waiting on a port, a key,
  the clock) costs nothing.
- **Switching slots.** Slots 1-20 keep the hotkeys as now: Control + 1-9 and 0, the number twice
  for 11-20. Past 20 a slot is reached only by FG *n*. Those slots are meant for things that run
  in the background: models, services, servers. TOP pages through all of them.
- **RAM discs and LUNs.** RAM discs can be much bigger. MODEL's LUNs stay inside its 64K: a swarm
  of 250 a model. More creatures means more MODEL slots, one a breed or one a box.

## 8. Hosts

Windows and the Xbox are one host, one source: the core plus a C++ layer with conditional
compilation.

- `CVM_UWP` builds the Xbox's UWP app. The same package also runs on Windows 10 and 11.
- Without it, the build is a plain Win32 program (`cvm.exe`): no Store, no sideloading.

What differs is behind a few small functions: the window and the drawing surface, the keys and
pad, the files' root folder, sockets (Winsock in both), and the timer. Everything else is shared.
With `cvm.exe` there's no need for WinAPE to run CyborgOS on Windows. WinAPE, or a real CPC, stays
only for testing the CPC build.

| Host | Screen | Keys | Files | Network |
|---|---|---|---|---|
| Windows (Win32, first: the fastest to test) | a window (Direct2D) | the keyboard | a folder | Winsock |
| Linux, and the minimal-kernel boot | a window (SDL) or a framebuffer | the keyboard | a folder | sockets |
| Browser | a canvas | the keyboard | IndexedDB or downloads | WebSocket relay (browsers have no raw sockets) |
| Xbox One (UWP, Developer Mode) | a texture, scaled to the TV | USB keyboard, the on-screen keyboard, the pad mapped to keys | the app's local folder | UWP sockets |

## 9. Order of work

1. This spec, settled.
2. The core in C: the Z80, memory, ports and host calls, plus a test host that runs `.BIN` files
   with the console in a terminal. NTC's `cvm` platform layer, and the regression suite's
   programs on it.
3. CyborgOS on `cvm`: the hypervisor's CPC parts replaced, booting to its command line, the
   `.CYB` programs running.
4. The Windows host (Win32), written so that `CVM_UWP` builds the same source for the Xbox.
5. Then the Xbox build of that same host (packaging, the pad, the TV), Linux and the browser.

## 10. Questions to settle

- The page count to start with: 4MB, or as much as the host allows (64MB: about 1000 slots)?
- The slot limit: 250 (a byte, BDOS 131 unchanged), or two-byte slot numbers for more?
- The text screen's largest size: 128 × 32 is enough for MON2's 96 × 21 and 84 × 24. More for a TV?
- Should the timer rate be fixed at 300Hz (CyborgOS's clock) and the slices counted from it?
- Sound: an AY-style port (the CPC's chip: CyborgOS's claims already know `SOUND 0`), or host
  calls that play buffers?
