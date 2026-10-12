#!/bin/bash
# writes build/dsk/<platform>.dsk (examples, demos) and <platform>test.dsk (the self tests):
# every program in build/<platform>/ assembled and put on a
# CPC data format disc (CPCEMU .DSK: 40 tracks, 9 x 512 byte sectors #C1-#C9, 64 directory
# entries - AMSDOS, CP/M 2.2 and CP/M Plus on the CPC all read it, as does WinAPE).
# cpc, cpcmin, cpcfw: the .BIN files (AMSDOS header from SAVEAMSDOS) and overlay classes'
# .PAG files; cpm: the .COM files.
# Scratch tool, not delivered: needs sjasmplus and cpmtools with libdsk (dskform, cpmcp, cpmls).
# Run after genbuild.js (regress.sh does both).
cd "$(dirname "$0")"
SJ=${SJASMPLUS:-sjasmplus}
fail=0
mkdir -p ../build/dsk
for p in cpc cpcmin cpcfw cpm; do
  w=t/dsk_$p; rm -rf $w; mkdir -p $w; cp ../build/$p/*.ASM $w/
  if [ $p == cpm ]; then x=COM; else x=BIN; fi
  for f in $w/*.ASM; do
    g=$(basename $f .ASM)
    o=""; [ $p == cpm ] && o="--raw=$g.COM"
    (cd $w && $SJ --nologo --msg=err $o $g.ASM > /dev/null) || { echo "gendsk: $p/$g did not assemble"; fail=1; }
  done
  # two discs: the examples and demos (with their overlay .PAG files), and the self tests
  for k in "" test; do
    d=../build/dsk/$p$k.dsk
    rm -f $d
    dskform -type dsk -format cpcdata $d > /dev/null 2>&1 || { echo "gendsk: dskform failed"; exit 1; }
    for f in $w/*.$x $(ls $w/*.PAG 2>/dev/null); do
      b=$(basename $f)
      if echo "$b" | grep -qE '^(NTCTEST|VBTEST|LONGTEST)'; then t=test; else t=""; fi
      [ "$t" == "$k" ] || continue
      cpmcp -f cpcdata -T dsk $d $f 0:$b || { echo "gendsk: $p$k: $b did not fit"; fail=1; }
    done
    n=$(cpmls -f cpcdata -T dsk $d | grep -icE "\.($x|PAG)")
    echo "build/dsk/$p$k.dsk: $n files ($(du -k $d | cut -f1)K image)"
  done
  rm -rf $w
done
exit $fail
