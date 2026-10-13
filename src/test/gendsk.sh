#!/bin/bash
# writes build/dsk/<platform>.dsk (examples, demos) and <platform>test.dsk (the self tests):
# every program in build/<platform>/ assembled and put on a
# CPC data format disc (CPCEMU .DSK: 40 tracks, 9 x 512 byte sectors #C1-#C9, 64 directory
# entries - AMSDOS, CP/M 2.2 and CP/M Plus on the CPC all read it, as does WinAPE).
# cpc, cpcmin, cpcfw: the .BIN files (AMSDOS header from SAVEAMSDOS) and overlay classes'
# page files (NAME.001 ...); cpm: the .COM files and the page files (no header).
# Scratch tool, not delivered: needs sjasmplus and cpmtools with libdsk (dskform, cpmcp, cpmls).
# Run after genbuild.js (regress.sh does both).
cd "$(dirname "$0")"
SJ=${SJASMPLUS:-sjasmplus}
fail=0
mkdir -p ../build/dsk
for p in cpc cpcmin cpcfw cpcrom cpcminrom cpcfwrom cpm; do
  w=t/dsk_$p; rm -rf $w; mkdir -p $w; cp ../build/$p/*.ASM $w/
  if [ $p == cpm ]; then x=COM; else x=BIN; fi
  # two programs writing a page file of the same name would overwrite each other's on the disc
  # the page files each program writes (OUTPUT "NAME.001" / SAVEAMSDOS "NAME.001", ovl_...)
  pf() { grep -E '^\s+(OUTPUT "|SAVEAMSDOS "[^"]*", ovl_)' $1 | grep -o '"[^"]*"' | head -999 | grep -v '\.BIN"$' | tr -d '"' | sort -u; }
  for f in $w/*.ASM; do pf $f; done | sort | uniq -d | while read n; do echo "gendsk: $p: page file $n is written by more than one program"; done | grep . && fail=1
  pages=$(for f in $w/*.ASM; do pf $f; done | sort -u)
  for f in $w/*.ASM; do
    g=$(basename $f .ASM)
    o=""; [ $p == cpm ] && o="--raw=$g.COM"
    (cd $w && $SJ --nologo --msg=err $o $g.ASM > /dev/null) || { echo "gendsk: $p/$g did not assemble"; fail=1; }
  done
  # two discs: the examples and demos (with their page files), and the self tests
  for k in "" test; do
    d=../build/dsk/$p$k.dsk
    rm -f $d
    dskform -type dsk -format cpcdata $d > /dev/null 2>&1 || { echo "gendsk: dskform failed"; exit 1; }
    for f in $w/*.$x $(for n in $pages; do echo $w/$n; done); do
      b=$(basename $f)
      if echo "$b" | grep -qE '^(NTCTEST|VBTEST|LONGTEST)'; then t=test; else t=""; fi
      [ "$t" == "$k" ] || continue
      cpmcp -f cpcdata -T dsk $d $f 0:$b || { echo "gendsk: $p$k: $b did not fit"; fail=1; }
    done
    # Library: ROM programs: the ROM image on the disc too (for ROM tools / ROM boards)
    case $p in cpcrom) r=NTCCPC;; cpcminrom) r=NTCMIN;; cpcfwrom) r=NTCFW;; *) r="";; esac
    [ -n "$r" ] && [ "$k" == "" ] && { cpmcp -f cpcdata -T dsk $d ../build/rom/$r.ROM 0:$r.ROM || fail=1; }
    n=$(cpmls -f cpcdata -T dsk $d | grep -vc '^[0-9]*:$')
    echo "build/dsk/$p$k.dsk: $n files ($(du -k $d | cut -f1)K image)"
  done
  rm -rf $w
done
# CyborgOS: CYBORGOS.BIN (cpcfw) and its programs - cpm builds as .CYB, with an AMSDOS header
# (AMSDOS reads a headerless file as ASCII text, to the first #1A)
w=t/dsk_cyb; rm -rf $w; mkdir -p $w; cp ../build/cpcfw/CYBORGOS.ASM $w/
(cd $w && $SJ --nologo --msg=err CYBORGOS.ASM > /dev/null) || { echo "gendsk: CYBORGOS did not assemble"; fail=1; }
for g in TICKER CRUNCH LINES; do
  cp ../build/cpm/$g.ASM $w/
  (cd $w && $SJ --nologo --msg=err --raw=$g.COM $g.ASM > /dev/null) || { echo "gendsk: $g did not assemble"; fail=1; }
  python3 -c "import sys; sys.path.insert(0, '.'); import ntcrun; d = open('$w/$g.COM', 'rb').read(); open('$w/$g.CYB', 'wb').write(ntcrun.amsdos_header(d, 0x100) + d)"
done
d=../build/dsk/cyborgos.dsk; rm -f $d
dskform -type dsk -format cpcdata $d > /dev/null 2>&1
for f in $w/CYBORGOS.BIN $w/TICKER.CYB $w/CRUNCH.CYB $w/LINES.CYB; do cpmcp -f cpcdata -T dsk $d $f 0:$(basename $f) || fail=1; done
echo "build/dsk/cyborgos.dsk: $(cpmls -f cpcdata -T dsk $d | grep -vc '^[0-9]*:$') files"
rm -rf $w
exit $fail
