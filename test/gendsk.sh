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
  # the examples and demos (with their page files) on one set of discs, the self tests on another;
  # a 178K data disc that fills spills onto the next ($p2.dsk, $p3.dsk ...)
  for k in "" test; do
    rm -f ../build/dsk/$p$k.dsk ../build/dsk/$p$k[2-9].dsk
    seq=1; d=../build/dsk/$p$k.dsk
    dskform -type dsk -format cpcdata $d > /dev/null 2>&1 || { echo "gendsk: dskform failed"; exit 1; }
    put() {   # put $1 (named $2) on the current disc; on "device full" open the next disc and retry
      cpmcp -f cpcdata -T dsk $d "$1" 0:"$2" 2> /dev/null && return 0
      cpmrm -f cpcdata -T dsk $d 0:"$2" 2> /dev/null   # a file that didn't fit can be left half written: off this disc
      seq=$((seq + 1)); d=../build/dsk/$p$k$seq.dsk
      dskform -type dsk -format cpcdata $d > /dev/null 2>&1 || { echo "gendsk: dskform failed"; exit 1; }
      cpmcp -f cpcdata -T dsk $d "$1" 0:"$2" || { echo "gendsk: $p$k: $2 did not fit even on a fresh disc"; fail=1; }
    }
    for f in $w/*.$x $(for n in $pages; do echo $w/$n; done); do
      b=$(basename $f)
      if echo "$b" | grep -qE '^(NTCTEST|VBTEST|LONGTEST)'; then t=test; else t=""; fi
      [ "$t" == "$k" ] || continue
      put $f $b
    done
    # Library: ROM programs: the ROM image on the disc too (for ROM tools / ROM boards)
    case $p in cpcrom) r=NTCCPC;; cpcminrom) r=NTCMIN;; cpcfwrom) r=NTCFW;; *) r="";; esac
    [ -n "$r" ] && [ "$k" == "" ] && put ../build/rom/$r.ROM $r.ROM
    tot=0
    for dd in ../build/dsk/$p$k.dsk ../build/dsk/$p$k[2-9].dsk; do
      [ -f "$dd" ] || continue
      nn=$(cpmls -f cpcdata -T dsk "$dd" | grep -vc '^[0-9]*:$'); tot=$((tot + nn))
      echo "build/dsk/$(basename $dd): $nn files ($(du -k "$dd" | cut -f1)K image)"
    done
    [ "$tot" -gt 0 ] || { echo "gendsk: $p$k.dsk: no files on it (the disc tools wrote nothing?)"; fail=1; }
  done
  rm -rf $w
done
exit $fail
