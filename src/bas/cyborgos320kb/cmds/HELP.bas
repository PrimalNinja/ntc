' HELP: CyborgOS's commands, in CyborgOS (build for cpm) - on the disc, not in the hypervisor
' (its text took RAM CyborgOS is short of)
Option Explicit
Print "Commands: RUN, FG, PS, TOP, KILL, RESET, WAIT, CLS, MEM, DIR, CD, QUIT"
Print "On the disc: HELP, COPY, ERA, TYPE, PREP, RENAME"
Print
Print "name [args]       runs the program name (this slot's drive, then A)"
Print "RUN name [args]   the same, even when a command has that name"
Print "RUN name slot     runs it in that slot"
Print "FG slot           that slot to the front"
Print "KILL slot         stops its program"
Print "RESET [slot]      that slot (or this one) as new"
Print "PS, TOP           the slots; with their speed"
Print "MEM               the memory: main RAM, the banks"
Print "DIR, CD [drive]   the files in FILES.DIR; this slot's drive (B: alone: CD B)"
Print "WAIT, CLS, QUIT   until no program runs; clear; end CyborgOS"
Print
Print "COPY [v:]name v[:newname]   ERA [v:]name   TYPE [v:]name   PREP v"
Print "RENAME [v:]name newname     (only files in the volume's FILES.DIR)"
Print
Print "Control + 1-9, 0: that slot to the front (more than 10 slots: the number"
Print "twice for 11-20)   Control + ESC: TOP"
