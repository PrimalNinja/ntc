# MON speed tests (not delivered builds)

Both are MON.bas with a changed copy of apps/mon/Bml.cls; the real MON is untouched. On
build/dsk/mon-test.dsk (RUN"INSTALL with it in B: to IDE:). Run as MONNW / MONFR in CyborgOS.

- MONNW.CYB (monnw/Bml.cls): no word wrap - Flow puts a text parameter on one line as it is, cut
  at the width
- MONFR.CYB (its source now gone: the change is in apps/mon/Bml.cls itself): MONNW plus `r` lines (hex dumps, lists) copied straight from
  the page into the line (Put) instead of PT() -> Txt (a string built a character at a time) ->
  Emit (poked a character at a time)

prof.sh: CyborgOS in the harness runs mon, 8 (Hex), a link; NTC_PROF samples (SP every 13333 T)
counted by BASIC sub. Bml's samples: MON 2324 (Txt 1352, Emit 351, NextP 326, Flow 153),
MONNW 2303 (Flow 103), MONFR 1209 (Txt 32, Emit 49, Put 416). Same screens.

## 2026-10-16: MON's 8BML in Z80

MON.bas's 8BML writers are asm keywords now (E, EQ, H2, H4, NmU, and HexRows / TextRows - VHex's and
VText's rows), and Bml.cls's `r` lines go straight into the line (the MONFR change). cmp/: the old
MON (cmp/MON.bas, OLD.COM) against the new (NEW.COM): cmp.sh compares the screens of four runs
(index + hex, a list, a text page, a hex page - the same), timing.py the time to each page:

| (emulator, 4MHz) | MON map home | hex page | text page |
|---|---|---|---|
| old MON | 1.87 s | 18.82 s | 7.96 s |
| asm 8BML writers | 1.85 s | 12.63 s | 5.53 s |
| + Bml fast r lines | 1.84 s | 7.68 s | 4.31 s |
