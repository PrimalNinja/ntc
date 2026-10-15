# CyborgOS - todo

What has been done and what is next for CyborgOS (see [cyborgos-readme.md](cyborgos-readme.md)).
Items for NTC BASIC itself, the compiler CyborgOS is built with, are in [todo.md](todo.md).
Newest first. The 128K version is frozen (changed only when asked for); new work is the 320K
version.

---

## done

- 2026-10-16 Under 576K: no system drive Z (made only with 8 expansion banks or more; COSLOAD's Z
  doesn't fit on 320K either) - the commands run from the boot drive; on 320K 96K left free (C6,
  C7, bank 4) for RAM discs, stores and the like. No main RAM cost

- 2026-10-16 COSLOAD's loader and its 2K buffer in screen RAM (#C780, #E000) instead of past
  CYBORGOS.BIN's end: COSLOAD needed the ROMs' RAM above about #A31D, CyborgOS itself only above
  its arrays' end + 16 (#9DC4) - with more ROMs than AMSDOS COSLOAD refused where CYBORGOS.BIN ran.
  Now the same limit as CyborgOS (KL ROM WALK with DE = its ntc_free). gendsk prints CyborgOS's
  main RAM end each build

- 2026-10-16 MON, MON2: the map (SYSTEM.MAP) closed once read (BDOS 16). Left open, it held
  CyborgOS's one read file for as long as MON ran: in every other slot CD said "no such drive,
  or no FILES.DIR there" and DIR listed nothing. Still open: any CP/M program that reads a file
  and doesn't close it (CP/M doesn't need the close) does the same while it runs - FileCall's 15
  refuses another slot's open (fin). A fix would be in the hypervisor (main RAM)

- 2026-10-16 MON2 (apps/mon2/MON2.bas, with apps/mon's Bml, Mouse and SYSTEM.MAP): MON on the whole
  screen - row 0 the toolbar (tools, the link's URL, line / lines), rows 1-23 the page (80
  columns), column 81 the current line's <, column 83 the scroll bar. A line at a time the page
  scrolls with the console's hardware scroll (LF on row 23 on, ESC I on row 0 back; the toolbar
  drawn again after); further, drawn again. ESC Y sent raw (Locate stops at column 80, Print
  turns ESC into ?). 40 lines down from the top: 4.85 s (MON 13.41 s, its window redrawn)
- 2026-10-16 The console: VT52 ESC I (reverse line feed: on the top row the page ring and the
  screen scroll back a row - the hardware scroll the other way). 100 bytes of main RAM
- 2026-10-16 MON: its 8BML writers in Z80 (asm keywords E, EQ, H2, H4, NmU, HexRows, TextRows -
  the BASIC kept as '| comments) and Bml's r lines straight into the line (Put): the hex page
  18.8 s -> 7.7 s, the text page 8.0 s -> 4.3 s (emulator, from MON's map home). Same screens
  (test/monnw/cmp: cmp.sh, timing.py). Next: Bml's NextP / Put / NewLine / Emit in Z80 (half
  the hex page's time now; the base of the web browser)
- 2026-10-16 Fast boot: COSLOAD.BIN (tools/COSLOAD.ASM, built per build) loads Z ready-made from
  CYBORGOS.Z1 ... (test/packz.py: Z's pages, 32K a file) into the pages the slow way gives it (C6,
  C7, the bank after the slots - worked out from a bank probe as the Memory class does; D_POOL
  and its checksum written for them), keeps Z after a reset, then CYBORGOS.BIN (a loader put
  past its end). Z not loaded when it doesn't fit (320K: 9 pages, 6 free) or a file is missing:
  CyborgOS makes Z from CYBORGOS.Z as before. CyborgOS itself unchanged. Three discs carry it to
  IDE: cos-disk1 (CyborgOS, COSLOAD, the apps, FILES.DIR of all three), cos-disk2 (the commands
  Z has), cos-disk3 (the Z files), each with its own INSTALL.BAS (replaces cyborgos320k.dsk)

- 2026-10-16 PREP keeps FILES.DIR (replaces the AMSDOS CYBADD, which is dropped from the 320K disc):
  PREP [v:]pattern ADD / REMOVE, wildcards (* ?). ADD sees a RAM disc's real directory (Z and
  RAMDISC drives); a floppy's own catalogue is still unread. CybDir.AddFile; CRUNCH.COM folded
  back onto the one 320K disc (no cyborgos320k2.dsk). Test "CyborgOS PREP add / remove"
- 2026-10-16 RAM discs survive a reset. The driver page carries a signature at #7F00 ("CYBD", a
  magic word, and a checksum of D_POOL - the page ownership, which file writes don't change),
  written whenever a disc or a page is made or dropped (dr_sig). At boot, before RAMDISC runs,
  Main's ProbeDiscs scans the free pages for it; on a match it reclaims the driver page and every
  page D_POOL lists (Hyp.ClaimPage - CyborgOS's own, marks a free RAT page TypeUser; not in the
  library, so the shared ROM is untouched), and Z and any other RAM disc are back with no loading.
  Only a cold start (no signature) makes Z from the disc as before. Test "CyborgOS reset survival"
  (two boots sharing the expansion RAM: the second loads nothing). Still to come: fast cold load
  of Z from ready-made 16K chunks (CYBORGOS.Z1 ...) and the IDE tool that builds them
- 2026-10-15 CyborgOS's command line at #BE80 (CYB d, then words): KEYREP n (KM SET DELAY, the keys'
  start delay and repeat n times as long - WinAPE at 1000%); CYBORGOS.BAS's o$. RUN [slot] name
  [args] (was RUN name slot, which lost the tail). Harness: NTC_POKE, KM SET / GET DELAY. Test
  "CyborgOS KEYREP, RUN slot name"
- 2026-10-15 Harness: a stand-in's own out (n), a with A = #BC / #BD was taken for a CRTC write (the
  MODE test's screen read 6 characters off when an interrupt came at the wrong moment); stand-ins
  are now told apart by where they are (STANDPC)
- 2026-10-15 The services out of main RAM: BDOS 131 ops 10, 11, 13, 14, 15 (memory reads, the
  pointer, the store's blocks, the tables) as Z80 in a page of the hypervisor's own (C5, the
  service page: Hyp.Svc, window data from #6000) - they had been BASIC in main RAM (MemRead,
  Tables, Ptr, RomRead: 2K). CyborgOS ends at #969A (was #9E2C): main RAM free 3K on 576K (was
  1.1K), 2.3K on 4MB. One page more taken (UU-- in MEM)
- 2026-10-15 4MB again: Option Memory CPCExpansion 257 (it was 193 - 48 banks, 3136K - since
  2026-10-14, when main RAM had no room for all 64 banks' tables; there is now: #A451-#A5EF free
  on 4MB with AMSDOS alone). Test "CyborgOS MEM map": 4160 KB
- 2026-10-15 DIR: the names alone across the screen (by the console's width, none split); DIR FULL the
  old listing (bytes, long names, counts); a pattern (CybDir.Fits public)
- 2026-10-15 INSTALL.BAS on the 320K disc (tools/): Locomotive BASIC - the disc's files erased on, then
  copied from B to, IDE: (DATA read twice)
- 2026-10-15 COPY with a pattern (`COPY *.CYB B:`: * and ?, disc names and long names; CybDir.Match,
  Keep, Back), the target's FILES.DIR written once. Test: COPY *.TXT C
- 2026-10-15 cyborgos320k2.dsk: CYBADD.BIN and CRUNCH.COM (with their own FILES.DIR) off the
  first 320K disc, which was full (10K free now)
- 2026-10-15 MON from a map: its pages are no longer in its code - SYSTEM.MAP (a text file, made
  and changed by hand; MON MY.MAP 2 maps a program running in slot 2) says where the data is (a
  CyborgOS table, a page, a ROM, main RAM, a slot's memory, a drive's files), how its records are
  laid out (columns: numbers, hex, strings, names, enums), how it is shown (list, data, hex, text,
  words) and where each row leads; walk follows linked lists, deref pointers. MON makes only the
  page asked for (a list 48 rows at a time). CyborgOS: op 15 (a whole table raw into the slot), op
  10 kind 3 (a slot's memory), a turn up to 3 slices. Fixed: Far twice in one statement (one
  result for both: the slot table's names and modes went wrong - and the mode was written into
  the other slot). Test "CyborgOS MON": TEST.MAP walks a list in slot 2
- 2026-10-15 MON (apps/mon), the first application: SCOUT-like pages (slots, memory and its
  pages, hex of any 1K, ROMs and their names, RAM discs, Z, the firmware jumpblock) as 8BML laid
  out by Bml.cls (a class for the web browser later; CyborgOS's own command r - a line as it is),
  the Amiga mouse (Mouse.cls, the mouse card's ports) with a pointer CyborgOS draws (BDOS 131 op
  11: an XOR checkerboard on a cell), Tab / arrows / Enter. CyborgOS: MODE F (84 x 24, all the
  program's), op 10 (up to 2K of a page, an upper ROM or main RAM), ops 12-14 (a slot's store:
  its own 16K pages, 512K at most, 2K blocks through its buffer; freed when its program ends).
  Harness: the screen read from main RAM's page 3 wherever it is (a slot running), a mouse
  ({mdx,dy,b}, NTC_MOUSE). Test "CyborgOS MON". RAM build ends at #9C52 (about 2.4K free on 320K)
- 2026-10-15 MODE per slot (MODE.CYB on Z, BDOS 131 op 9): 2 80 x 25, S 84 x 24 (the console
  80 x 24 and a status strip of 4 columns on the right - the default), W 88 x 23, UW 96 x 21, P
  64 x 32. CyborgOS sets the CRTC itself (Hyp.Scr) and Hyp.Con draws and scrolls by the slot's
  columns and rows (in its bank at #F687; the text page a ring of up to 2K, #F700-#FEFF - room
  since the first stack moved to #F2FC: the TPA unchanged); the bank's BDOS answers 49 (CP/M 3's
  SCB: width - 1, rows). TOP in MODE 2. MODE clears the console. The harness reads the CRTC
  (width, rows, start) for the screen's text. Test "CyborgOS MODE"; the COPY and HELP tests
  split / changed for 24 rows. RAM build ends at #956D (about 4.1K free on 320K)
- 2026-10-15 Main RAM back: the bank image (page zero, the stubs) and FileCall's disc code moved
  into the hypervisor's page (#5300 on), as window data - NTC's new `; @window` ... `; @endwindow`
  in #asm: put in the window hole of the file, copied into the page at the start (FileCall 99);
  FileCall keeps in main RAM only its entry, the RAM disc driver's turn, the window-switching
  copies and its exit. The strings: ob Max 82 (was 130; the longest string sizes every
  parameter, result and temp - 13 buffers), records in rb(127). RAM build ends at #9279 (was
  #9D80): about 4.9K free on 320K, 4.4K with 48 banks (was 2.1K, 1.6K). The Library: ROM build
  ends below #4000 (was #874C against #8800)
- 2026-10-15 System drive Z and almost no built-in commands: at start CyborgOS runs RAMDISC Z
  SYSTEM d (d the boot drive: "CYB d" at #BE80, put there by CYBORGOS.BAS, else A), which copies
  the files d:CYBORGOS.Z names (one a line) to a RAM disc Z that grows a page at a time; keys
  wait meanwhile. Names typed are looked for on Z, then the slot's drive, then the boot drive.
  Built in now only RUN, CLS, QUIT; FG, PS, TOP, KILL, RESET, WAIT, MEM, DIR, CD are programs
  (cmds/*.bas; CybSys.cls asks the hypervisor through BDOS 131) - 1.5K of main RAM back (RAM build
  ends at #9D80, was #A38A). Z is for CyborgOS's programs: the cpm FileSystem takes drives A-Z
  (was A-P), the driver takes FCB drives up to 26 and never Z as a slot's own drive. Test "CyborgOS
  system drive Z"; the tests' expectations for PS (its own slot shows PS.CYB) and DIR (DIR.CYB)
  changed. Fixed on the way: a program's own `call 5` (the commands' Bdos functions) now has ei
  before, di after - the BDOS came back with interrupts on and an interrupt pushed its return
  address over the threaded code (SP), which skipped a later BDOS call (Z lost pages: FS_FULL);
  a slot's first stack moved from #FEFC (44 bytes above the text page) to #F2FC (#F240-#F2FF)
- 2026-10-15 CyborgOS 320K RAM discs: RAMDISC v size (KB / MB, 16K steps, 4MB in all), RAMDISC v 0,
  RAMDISC (the list); any number of them (8). Real CP/M file calls on them (15-23, 33-36, 40):
  read / write in place, any number of files open, true sizes, searches of their own
  directory (extents), DIR lists it; programs run from them. The driver lives in a page of its
  own (cmds/RAMDISC.bas carries it; BDOS 130); Hyp.FileCall offers it each call first; Hyp.Drive
  knows its letters. Main RAM's page 1 is now kept (allocated at start) so no page of it goes to a
  RAM disc. Fix found on the way: two FarPtr results in one statement are one variable (Far's
  inner FarPtr) - the driver copy took a temporary. Tests "CyborgOS RAM discs: files, random
  access" (cpm/rdt.asm), "CyborgOS RAMDISC made, dropped, too big". Test programs moved to
  src/test/cpm (regress.sh's cleanup deleted src/test/*.asm)
- 2026-10-15 CyborgOS 320K CP/M compatibility: a CP/M 2.2 BIOS jump table at (#0001) (console
  entries work, BOOT / WBOOT end the program, disc entries answer "no drive" / error); BDOS 1
  waits in the bank (the slot sleeps: far call #81), 3-5, 7, 8, 10 (line editor), 27-31, 37 in
  the bank; 17 / 18 search FILES.DIR, 24, 35 (size), 36 (random record), 40; the default FCBs
  filled from the command tail before #0100; TAB in the console. The bank: stubs at #EF00 (TPA
  #0100-#EEFF), the font at #F300 (from the hypervisor's page: 768 bytes of main RAM back).
  Main's dead BDOS 1/2/6/9/11 BASIC and PutMem kept as comments. Fix: CLng(VarPtr(x)) of an
  address from #8000 up is negative - not a page 0 far pointer (NearP). Test "CyborgOS CP/M
  calls" (cpmt.asm, RAM and Library: ROM). Harness: CAS IN OPEN of a folder name is "not found"
- 2026-10-15 Two CyborgOS discs, each built from its own sources: build/dsk/cyborgos320k.dsk and
  build/dsk/cyborgos128k.dsk (cyborgos.dsk gone)
- 2026-10-15 CyborgOS 320K (`bas/cyborgos320kb`, now the one built and tested; the 128K version
  kept as `bas/cyborgos128kb`): 320K at least; the hypervisor's own page (the first expansion
  bank's page 0) taken before the slots' banks - the disc buffers there, main RAM's own
  #4000-#7FFF left free (a second screen); up to 20 slots (Control + 1-9, 0; twice 11-20); TOP
  fits 25 rows with 20. Tests: 20 slots, Control + 0, 2 slots on 320K, refused on 128K.
  Harness: a held matrix key ({n}) lasts 12 scans and at least 2 frames (a program looking at
  many keys scans many times a frame)
- 2026-10-15 CyborgOS: HELP is a program on the disc (cmds/HELP.bas, HELP.CYB), its text out of the
  hypervisor (823 bytes of RAM back). Test "CyborgOS HELP from the disc"
- 2026-10-15 CyborgOS: B: alone is CD B (as in CP/M), CD B: is CD B
- 2026-10-15 CyborgOS file speed: a slot's file calls run on in the same turn (up to 32), and a
  record goes into / out of the slot with one ldir when it is in one 16K page (38K COPY: about
  35 s of CPC time down to about 22 s, in the harness). Library: ROM build: 4 slots at most (its
  per-slot arrays sized to that)
- 2026-10-14 CyborgOS output tidied: TOP's first line just "CyborgOS TOP", "(last second)" (fits 80
  columns), "Total memory: n KB   Free memory: n KB" (TOP and MEM); MEM's main RAM as a table
  (address range, what is there), blank lines round the map; HELP: the names with commas, then a
  line each. Main RAM's own page 1 (the disc buffers) taken at the start, so it isn't counted free
- 2026-10-14 CyborgOS: RENAME (cmds/RENAME.bas: on the disc and in FILES.DIR; the hypervisor's BDOS 23
  through the disc ROM's |REN); the disc's FILES.DIR lists every file on it (test "CyborgOS
  command RENAME"). Built round the window, variables are laid out one by one as strings are
  (a section moving whole above the hole wasted 2.7K below it). Library: ROM build of CyborgOS:
  no CD / DIR, shorter HELP (room)
- 2026-10-14 CyborgOS: the memory map moved from TOP to MEM - main RAM's breakdown, then the banks'
  pages 32 a group, two groups a line (test "CyborgOS MEM map")
- 2026-10-14 CyborgOS's 128K version archived in `bas/cyborgos128kb` (not built or tested). Next:
  320K minimum - the hypervisor's data in the first expansion bank's pages (C4 first), main
  RAM's #4000-#7FFF left free, slots = banks - 1
- 2026-10-14 CyborgOS: programs run by their names (not a command: NAME [args] runs NAME from
  the slot's drive, else from A; the rest of the line is the CP/M command tail at #0080); RUN
  NAME [args] forces the disc's (RUN CLS runs CLS.CYB), RUN NAME slot as before. Disc commands
  COPY, ERA, TYPE, PREP (`bas/cyborgos/cmds`, cpm builds with CybDir.cls; only files in
  FILES.DIR). Hypervisor BDOS file calls 13-16, 19-22, 25, 26, 32-34 (Hyp.FileCall, Z80 on the
  cassette calls); RUN, DIR, CD read through it too (FileSystem and Option Buffer left out).
  Test "CyborgOS commands COPY ERA TYPE PREP"
- 2026-10-14 CyborgOS and CYBADD start every background ROM (`Option RomEnable All`: IDE / SD
  interfaces' ROMs too). Option RomEnable: when the ROMs take more RAM than AMSDOS's, cpcfw
  moves its top (event block, heap / Memory tables limit) under it; it stops (with the address
  the ROMs reached) only when the program itself would overlap
- 2026-10-14 CyborgOS: MEM as TOP's first line (slots, banks, free pages); TOP shows the memory
  (KB) and its page map under the slots
- 2026-10-14 CyborgOS: plain CP/M .COM files (no AMSDOS header) run when FILES.DIR or NAME.HDR
  has a 64 byte entry for them (disc name, length, long name ...; RUN by a long name too);
  CYBADD.BIN (a CPC program) writes FILES.DIR, `DIR` lists it, `CD` picks a slot's drive (the
  disc system's |letter); a .COM without an entry is not run. The entry code is Z80
  (Hyp.cls). AMSDOS's messages kept off the console (TXT VDU DISABLE). Program names moved into
  each bank. Tests "CyborgOS .COM with FILES.DIR / .HDR" and on the real ROMs (realcpc)
- 2026-10-14 CyborgOS: RESET [slot] (the slot as before its command line was first opened: its
  program stopped, nothing kept; this slot opens again at once); Option Memory CPCExpansion 193
  (48 banks: the page tables no longer fit for all 64 of 4MB). Test "CyborgOS RESET"
- 2026-10-14 CyborgOS: up to 16 slots (half the extra banks: 16 on 2MB or more); Control + a
  number twice quickly (Control held, 0.3 s) is slots 9-16, a single press waits 0.3 s only when
  there are more than 8 slots; each slot's command line kept in its bank (#F68F / #F690 - 16
  in BASIC arrays did not fit the Library: ROM build). Harness: {n,m} holds keys together;
  realcpc: down / up (8A: Control). Tests: 16 slots, Control + 3 twice / once
- 2026-10-14 CyborgOS: the TOP screen drawn straight into screen memory (Hyp.Say: about 0.1 s,
  was about 0.7 s through TXT OUTPUT); the TOP command back, printing the table once into the
  slot's console (test "CyborgOS TOP command")
- 2026-10-14 CyborgOS console in Z80 (Hyp.Con, Hyp.Show): the slot's page 3 in the window once,
  the characters read where the program collected them, page (ring) and screen written in one
  routine, page / screen pointers stepped along a run, the glyph loop unrolled, screen addresses
  from SCR GET LOCATION (was SCR CHAR POSITION per character), SCR HW ROLL to scroll (was 4 TXT
  calls); the console state in the bank (#F682). The BASIC it replaced (Collected / Out / PutC /
  NewLine / RowA / ClsT / ToFront) kept in Main.bas as comments, with why. The bank no longer
  hands over at each line end (at the slice's end: one BASIC turn per line less). Real ROMs: 16
  lines a second (was 8; harness: about 100,000 T a line, was 216,000). realcpc PROF=file: a
  profile by address (main RAM, bank, lower / upper ROM), "profon" in the script restarts it
- 2026-10-14 CyborgOS speed and fixes: text for the front slot written straight into screen
  memory (Hyp.Text: the firmware's matrices via TXT SET M TABLE, SCR CHAR POSITION; mode 2),
  the slot's page a ring of 25 rows (no copy to scroll), the control-code scan in Z80
  (Hyp.Printable); keys answered in the bank (#F681: BDOS 1, 6, 11 with no switch); time
  slices of 6 interrupts handled in Hyp.Run (no BASIC between); BDOS 9 fetched with
  Memory.Copy. Fixes: the screen didn't scroll on the real ROMs (the firmware scrolls only at the
  next character below the last line); TOP closed at once (the ESC of Control + ESC) and
  refreshed - now drawn once, Control + ESC / Control + a slot go back, the TOP command is gone;
  firmware calls come back with interrupts on (di after them, or an interrupt is pushed into the
  thread); the upper ROM is off while a program runs (Library: ROM had the keyword ROM over the
  bank's top 16K). Library: ROM: Option Buffer has no buffer to place (the ROM has its own), and
  the ROM's Memory tables start at the end of the program below the window when the arrays went
  after an Option Reserve range. Harness: screen memory text (mode 2) for cpcfw, the RAM under
  the keyword ROM, TXT SET M TABLE / SCR CHAR POSITION / ROM enable stand-ins, NTC_PROF
  (a profile), NTC_LIMIT, NTC_PEEK; realcpc: Control + 1-8 / ESC (\c1 ... \ce). Measured on the
  real ROMs: about 8 lines a second (was 3)
- 2026-10-14 CyborgOS: the front slot gets half the turns, a program with no key gives up its
  turns until the clock moves, characters out collected in the bank (128) and written in runs,
  the system keys from an interrupt class (Hot.cls; Control held, numbers in turn), TOP
  (Control + ESC), every register kept for the programs (IX, IY, alternates). 4MB: 64 banks
- 2026-10-14 **CyborgOS** first version (`bas/cyborgos`, cpcfw, `build/dsk/cyborgos.dsk`): slots in
  whole 64K banks running cpm-built programs (.CYB = with an AMSDOS header) at #0100; BDOS at
  #0005 as far calls into the hypervisor; interrupts stop a program and hand back; per-slot text
  pages, a shared command line (RUN / FG / PS / KILL / WAIT ...), Control + 1-8. Checked in the
  harness and on the real 6128 ROMs. See docs/cyborgos.md for what is next (the interrupt classes
  as the scheduler, files, drivers, speed). Core: the bank switch at #0040-#004C in every cpc /
  cpcmin / cpcfw start code; `Option Buffer address` (the 2K buffer out of the program); cpcfw
  FileSystem Read / ReadByte read a #1A in a binary file as a byte (AMSDOS reports it as a soft
  end of file); the harness gives #0F (hard end) at the end of a binary file

---

## todo

- Folders on RAM discs (the directory entry has a folder byte already): CD J:\WORK, a slot's
  folder, MD / RD, paths in COPY, ERA, TYPE, RENAME
- Read the disc's own directory (record counts: file sizes; CP/M Plus / cpmtools keep the last
  record's byte count in byte 13 of an entry - exact sizes), random access on discs (AMSDOS's
  sector commands #84 / #85, as the RAM disc driver does records); then FILES.DIR only for long
  names (with spaces) and virtual directories
- The printer and the punch (BDOS 4, 5; the BIOS's LIST, PUNCH) - drivers, like RAM discs
- RAM disc: save / load a whole RAM disc as one disc file; QUIT warns when one holds files
- 128K version (only when asked): the BIOS jump table and the default FCBs are the parts worth
  bringing back for console programs that work the hardware
- MODE S's status strip: what it shows (now only the slot's number)
- MON: speed (a page takes 2-3 s to make, 1 s to draw: its map, 8BML and layout in BASIC a
  character at a time; the firmware's interrupts and the hypervisor take a third), forms, a
  disassembler (view dis) and a detailed memory map as overlays, far pointers in walk (a page and
  an address), text view by a width (a console's page), names for the firmware's entries;
  CyborgOS handing the mouse to one slot at a time
- MON's map tool (separate from NTC BASIC, so it can change and be fixed on its own): hints put
  in the source before the assembler (a hints file beside it), then the hints and the
  assembler's output (any assembler that gives symbols - NTC BASIC relies on none) into the tool:
  a map for MON, and map.log (what matched, what disappeared ...)
- A debug wedge class compiled into a program: MON takes control through it (a low part in the
  program, a high part that can flex) - watches, and breaks using NTC BASIC's breakpoints; the
  state comes back raw as the rest does
- NTC's cpm platform: its 80 columns (Tab) from BDOS 49 when CyborgOS answers it
- More text files beside CYBORGOS.Z (settings ...); the ROM disc as a source for Z
- Faster boot: prebuilt Z images (CYBORGOS.Z1, .Z2 ...: the RAM disc's 16K pages ready to load,
  made by a tool) instead of copying file by file; CYBORGOS.Z (text) stays for flexibility
