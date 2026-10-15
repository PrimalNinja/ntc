' HELP: CyborgOS's commands, in CyborgOS (build for cpm) - on the disc, not in the hypervisor
' (its text took RAM CyborgOS is short of)
Option Explicit
Print "Built in: RUN, CLS, QUIT. On the system drive Z (from the boot disc): FG, PS,"
Print "TOP, KILL, RESET, WAIT, MEM, DIR, CD, HELP, COPY, ERA, TYPE, PREP, RENAME,"
Print "RAMDISC, MODE"
Print
Print "name [args]       runs that program (from Z, the slot's drive, the boot drive)"
Print "RUN [slot] name [args]   the same, even when a command has that name;"
Print "                  with a slot: runs it there (RUN 2 CRUNCH)"
Print "FG slot           that slot to the front"
Print "KILL slot         stops its program"
Print "RESET [slot]      that slot (or this one) as new"
Print "PS, TOP           the slots; with their speed"
Print "MEM               the memory: main RAM, the banks"
Print "DIR [v:][*.CYB] [FULL]   the names (FULL: sizes, long names); CD v the drive"
Print "WAIT, CLS, QUIT   until no program runs; clear; end CyborgOS"
Print "MODE [m]          this slot's screen: 2 80x25, S 84x24 (80x24 and a status"
Print "                  strip), W 88x23, UW 96x21, P 64x32"
Print
Print "COPY [v:]name v[:newname]   COPY [v:]pattern v (*.CYB, T?.*: same names)"
Print "ERA [v:]name   TYPE [v:]name   PREP v (PREP [v:]pat ADD / REMOVE keeps FILES.DIR)"
Print "RENAME [v:]name newname     (only files in the volume's FILES.DIR)"
Print "RAMDISC [v size | v 0]      a RAM disc as drive v (64K, 1MB ...); dropped; list"
Print
Print "Control + 1-9, 0: that slot to the front (more than 10 slots: the number"
Print "twice for 11-20)   Control + ESC: TOP"
