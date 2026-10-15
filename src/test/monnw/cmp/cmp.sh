#!/bin/bash
# old MON (MON.bas as it was, monnw/cmp/MON.bas) and new (asm 8BML writers): the same keys, the screens compared
cd "$(dirname "$0")/../.."
P=../bas; A=$P/cyborgos320kb/apps/mon
rm -rf t; mkdir -p t/cy t/files/A t/mon; cp $P/cyborgos320kb/*.bas $P/cyborgos320kb/*.cls t/cy/; cp $A/SYSTEM.MAP t/files/A/
printf '; MON test map\ncat "Test"\nnode chain "Chain"\nsrc slot {s} #8000 64\nrec 8\nwalk w 0\nf "Addr" a\nf "Value" w 2\nf "Name" s 4 4\nview list\n' > t/files/A/TEST.MAP
printf '; text and hex\ntitle "T"\ntool tx "Text"\ntool hx "Hex"\nnode tx "Text"\ntitle "Text"\nsrc slot 1 #F700\nview text\nnode hx "Hex"\ntitle "Hex"\nsrc main 0 #0040\nview hex\n' > t/files/A/TT.MAP
printf 'Option Explicit\nDim j As Integer, a As Integer, n As Integer\nFor j = 0 To 4\n  a = &H8000 + j * 8 : n = a + 8\n  If j = 4 Then n = 0\n  Poke a, n And 255 : Poke a + 1, (n And &HFF00) \\ 256\n  Poke a + 2, j * 10 : Poke a + 3, 0\n  Poke a + 4, 78 : Poke a + 5, 48 + j : Poke a + 6, 0 : Poke a + 7, 0\nNext\nDo\nLoop Until Inkey <> 0\n' > t/mon/LIST.bas
node cli.js t/mon/LIST.bas --platform=cpm > t/mon/LIST.asm 2>/dev/null; (cd t/mon && sjasmplus --nologo --msg=err --raw=LIST.COM LIST.asm > /dev/null)
python3 -c "import ntcrun; d = open('t/mon/LIST.COM', 'rb').read(); open('t/files/A/LIST.CYB', 'wb').write(ntcrun.amsdos_header(d, 0x100) + d)"
W=$(printf '~%.0s' $(seq 1 40))
for v in ${VERS:-OLD NEW}; do
  python3 -c "import ntcrun; d = open('monnw/cmp/$v.COM', 'rb').read(); open('t/files/A/MON.CYB', 'wb').write(ntcrun.amsdos_header(d, 0x100) + d)"
  NTC_LIMIT=40000 python3 ntcrun.py t/cy/Main.bas "mon\n${W}${W}8${W}\n${W}${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1 | grep -v "^---\|^WARN\|TIMEOUT" > t/$v.1
  NTC_LIMIT=40000 python3 ntcrun.py t/cy/Main.bas "run 2 list\n${W}mon test.map 2\n${W}${W}\n${W}${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1 | grep -v "^---\|^WARN\|TIMEOUT" > t/$v.2
  NTC_LIMIT=40000 python3 ntcrun.py t/cy/Main.bas "ps\n${W}dir\n${W}mon tt.map\n${W}${W}1${W}${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1 | grep -v "^---\|^WARN\|TIMEOUT" > t/$v.3
  NTC_LIMIT=40000 python3 ntcrun.py t/cy/Main.bas "mon tt.map\n${W}${W}2${W}${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1 | grep -v "^---\|^WARN\|TIMEOUT" > t/$v.4
done
for k in 1 2 3 4; do if cmp -s t/OLD.$k t/${NV:-NEW}.$k; then echo "same $k"; else echo "DIFFERENT $k"; diff t/OLD.$k t/${NV:-NEW}.$k | head -10; fi; done
