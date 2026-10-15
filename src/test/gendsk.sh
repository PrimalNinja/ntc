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
      case $b in CYBORGOS*|CYBADD*) continue;; esac   # CyborgOS has its own disc (cyborgos.dsk, below)
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
# CyborgOS: built from their own sources - cos-disk1/2/3.dsk (bas/cyborgos320kb: 320K or more,
# three discs that carry it to IDE:, below) and cyborgos128k.dsk (bas/cyborgos128kb: the 128K version, kept as it was). Each has
# CYBORGOS.BIN (128K also CYBADD.BIN; 320K uses PREP add/remove), its programs and commands (HELP, COPY, ERA, TYPE, PREP,
# RENAME; on the 320K one RAMDISC, the CyborgOS commands and MON, apps/mon, with its SYSTEM.MAP) - cpm builds as .CYB, with an AMSDOS header (AMSDOS reads a headerless file as ASCII
# text, to the first #1A) - CRUNCH again as a plain .COM, and FILES.DIR. INSTALL.BAS (320K:
# tools/): RUN"INSTALL with this disc in B - its files erased on, then copied to, IDE: (|ERA, |COPY)
rm -f ../build/dsk/cyborgos.dsk
cyb_cls() {   # the class a CyborgOS command is built with: CybDir (FILES.DIR), CybSys (BDOS 131), none
  case $2 in PS|KILL|RESET|FG|WAIT|TOP|MEM|MODE) echo $1/cmds/CybSys.cls;; CD|RAMDISC|HELP) ;; *) echo $1/cmds/CybDir.cls;; esac
}
for v in 320 128; do
  b=../bas/cyborgos${v}kb; w=t/dsk_cyb$v; rm -rf $w; mkdir -p $w
  c="COPY ERA TYPE PREP RENAME"; [ $v == 320 ] && c="$c RAMDISC DIR CD PS KILL RESET FG WAIT TOP MEM MODE"
  node cli.js $b/Main.bas $b/Hyp.cls $b/Hot.cls $b/Ent.cls --platform=cpcfw --amsdos=CYBORGOS --name=CYBORGOS > $w/CYBORGOS.ASM 2>/dev/null
  cg=CYBORGOS                                    # 320K drops CYBADD (PREP add / remove replaces it)
  [ $v != 320 ] && { node cli.js $b/tools/CYBADD.bas $b/Ent.cls --platform=cpcfw --amsdos=CYBADD --name=CYBADD > $w/CYBADD.ASM 2>/dev/null; cg="CYBORGOS CYBADD"; }
  for g in $cg; do (cd $w && $SJ --nologo --msg=err --sym=$g.SYM $g.ASM > /dev/null) || { echo "gendsk: $v: $g did not assemble"; fail=1; }; done
  for g in TICKER CRUNCH LINES; do node cli.js $b/tasks/$g.bas --platform=cpm > $w/$g.ASM 2>/dev/null; done
  node cli.js $b/cmds/HELP.bas --platform=cpm > $w/HELP.ASM 2>/dev/null
  for g in $c; do node cli.js $b/cmds/$g.bas $(cyb_cls $b $g) --platform=cpm > $w/$g.ASM 2>/dev/null; done
  ap=""; [ $v == 320 ] && ap="MON"      # the applications (apps/: MON, with its classes)
  [ -n "$ap" ] && cp $b/apps/mon/SYSTEM.MAP $w/   # (MON's map: a text file)
  [ $v == 320 ] && cp $b/tools/INSTALL.BAS $w/     # (ASCII BASIC: this disc in B to IDE:)
  [ -n "$ap" ] && node cli.js $b/apps/mon/MON.bas $b/apps/mon/Bml.cls $b/apps/mon/Mouse.cls $b/cmds/CybSys.cls --platform=cpm > $w/MON.ASM 2>/dev/null
  for g in TICKER CRUNCH LINES $c HELP $ap; do
    (cd $w && $SJ --nologo --msg=err --raw=$g.COM $g.ASM > /dev/null) || { echo "gendsk: $v: $g did not assemble"; fail=1; }
    python3 -c "import sys; sys.path.insert(0, '.'); import ntcrun; d = open('$w/$g.COM', 'rb').read(); open('$w/$g.CYB', 'wb').write(ntcrun.amsdos_header(d, 0x100) + d)"
  done
  if [ $v == 320 ]; then
    # CYBORGOS.Z: the files CyborgOS copies to its system drive Z (the slow way: CYBORGOS.BIN run
    # on its own, or a Z file missing). CYBORGOS.Z1 ...: Z ready-made - packz.py boots CyborgOS
    # once the slow way and writes Z's pages (32K a file) for the pages after the hypervisor's.
    # COSLOAD.BIN (tools/COSLOAD.ASM, built for these): loads them into those pages - or keeps Z when a
    # reset left it there - then CYBORGOS.BIN; CYBORGOS.BAS runs it
    printf '%s\r\n' HELP.CYB $(for g in $c; do echo $g.CYB; done) > $w/CYBORGOS.Z
    rm -rf $w/zb; mkdir -p $w/zb; cp $w/*.CYB $w/CYBORGOS.Z $w/zb/
    python3 packz.py $w/zb $w $b/Main.bas $b/Hyp.cls $b/Hot.cls $b/Ent.cls --sym=$w/CYBORGOS.SYM || { echo "gendsk: $v: packz failed"; fail=1; }
    rm -rf $w/zb
    cp $b/tools/COSLOAD.ASM $w/
    (cd $w && $SJ --nologo --msg=err COSLOAD.ASM > /dev/null) || { echo "gendsk: $v: COSLOAD did not assemble"; fail=1; }
    d=../build/dsk/cos-disk1.dsk
  else
    d=../build/dsk/cyborgos${v}k.dsk
  fi
  rm -f $d
  dskform -type dsk -format cpcdata $d > /dev/null 2>&1
  # CYBORGOS.BAS (320K): RUN"CYBORGOS from BASIC - CyborgOS's command line ("CYB d", then words:
  # KEYREP n) to #BE80, then COSLOAD.BIN (Z ready-made, then CYBORGOS.BIN). ASCII BASIC: edit d$ for
  # another boot drive, o$ for words
  [ $v == 320 ] && printf '10 REM CyborgOS 320K: its command line to &BE80 (the boot drive - CYBORGOS.Z, the commands -, then words), then COSLOAD (Z ready-made, then CyborgOS)\r\n20 d$="A"\r\n25 o$="":REM o$=" KEYREP 10": keys repeating 10 times slower (WinAPE at 1000%%)\r\n30 a$="CYB "+d$+o$:FOR i=1 TO LEN(a$):POKE \x26BE7F+i,ASC(MID$(a$,i,1)):NEXT:POKE \x26BE80+LEN(a$),0\r\n40 RUN"COSLOAD.BIN"\r\n\x1a' > $w/CYBORGOS.BAS
  # FILES.DIR: every file on the disc (but itself). The CPC programs (CYBORGOS.BIN; 128K CYBADD.BIN:
  # run from BASIC) as "other", not run by CyborgOS; the .CYB programs (run by their names) with
  # their length as CP/M reads them (the AMSDOS header left out), their names as long names (so
  # COPY, ERA, TYPE, RENAME find them by those too); CRUNCH as a CP/M .COM with no header (long
  # name BIGCRUNCH): RUN BIGCRUNCH runs it through its entry
  python3 -c "
import sys, os; sys.path.insert(0, '.'); import ntcrun
w = '$w'; e = b''
def size(f): return os.path.getsize(os.path.join(w, f))
bins = ('CYBORGOS.BIN',) if '$v' == '320' else ('CYBORGOS.BIN', 'CYBADD.BIN')   # 128K keeps CYBADD
for f in bins:
    e += ntcrun.cyb_entry(f, size(f) - 128, f.split('.')[0], what=0, flags=0, load=0x40, exe=0x40)
for g in ['TICKER', 'CRUNCH', 'LINES', 'HELP'] + '$c'.split() + '$ap'.split():
    e += ntcrun.cyb_entry(g + '.CYB', size(g + '.CYB') - 128, g, what=0)
e += ntcrun.cyb_entry('CRUNCH.COM', size('CRUNCH.COM'), 'BIGCRUNCH')
open(os.path.join(w, 'FILES.DIR'), 'wb').write(e)
if '$v' == '320':      # (FILES.DIR, on cos-disk1, lists the files of all three discs)
    e += ntcrun.cyb_entry('COSLOAD.BIN', size('COSLOAD.BIN') - 128, 'COSLOAD', what=0, flags=0, load=0x40, exe=0x40)
    for f in sorted((f for f in os.listdir(w) if f.startswith('CYBORGOS.Z') and f[10:].isdigit()), key=lambda f: int(f[10:])):
        e += ntcrun.cyb_entry(f, size(f) - 128, '', what=0, flags=0, load=0x1000, exe=0x1000)
    for f in ('CYBORGOS.BAS', 'CYBORGOS.Z', 'SYSTEM.MAP', 'INSTALL.BAS'):
        e += ntcrun.cyb_entry(f, size(f), '', what=0, flags=0)
    open(os.path.join(w, 'FILES.DIR'), 'wb').write(e)
"
  x="$w/CYBADD.BIN"; [ $v == 320 ] && x=""
  if [ $v == 320 ]; then
    # three discs carry it to IDE: (RUN"INSTALL with each in B): cos-disk1 CyborgOS, COSLOAD, FILES.DIR
    # (all three discs' files), the programs and MON; cos-disk2 the commands Z has (CYBORGOS.Z
    # names them); cos-disk3 Z ready-made (CYBORGOS.Z1 ...). Each has an INSTALL.BAS for its files
    f1="CYBORGOS.BAS COSLOAD.BIN CYBORGOS.BIN CYBORGOS.Z FILES.DIR SYSTEM.MAP TICKER.CYB CRUNCH.CYB LINES.CYB CRUNCH.COM $(for g in $ap; do echo $g.CYB; done)"
    f2="$(for g in HELP $c; do echo $g.CYB; done)"
    f3="$(ls $w | grep -E '^CYBORGOS\.Z[0-9]+$' | sort -t Z -k2 -n)"
    for n in 1 2 3; do
      dn=../build/dsk/cos-disk$n.dsk; eval fl=\$f$n
      [ $n != 1 ] && { rm -f $dn; dskform -type dsk -format cpcdata $dn > /dev/null 2>&1; }
      grep -v '^1000 ' $b/tools/INSTALL.BAS > $w/INSTALL.BAS
      echo $fl | tr ' ' '\n' | paste -d, - - - - - - | sed 's/,*$//; s/[^,]*/"&"/g' | awk '{printf "%d DATA %s\r\n", 1000 + NR * 10, $0}' >> $w/INSTALL.BAS
      printf '2000 DATA "*"\r\n' >> $w/INSTALL.BAS
      for f in $fl INSTALL.BAS; do cpmcp -f cpcdata -T dsk $dn $w/$f 0:$f || { echo "gendsk: cos-disk$n: $f did not fit"; fail=1; }; done
      echo "build/dsk/cos-disk$n.dsk: $(cpmls -f cpcdata -T dsk $dn | grep -vc '^[0-9]*:$') files"
    done
  else
  for f in $w/CYBORGOS.BIN $x $w/TICKER.CYB $w/CRUNCH.CYB $w/LINES.CYB $(for g in $c $ap; do echo $w/$g.CYB; done) $w/HELP.CYB $w/CRUNCH.COM $w/FILES.DIR $(ls $w/CYBORGOS.Z $w/CYBORGOS.BAS $w/SYSTEM.MAP $w/INSTALL.BAS 2>/dev/null); do cpmcp -f cpcdata -T dsk $d $f 0:$(basename $f) || fail=1; done
  echo "build/dsk/cyborgos${v}k.dsk: $(cpmls -f cpcdata -T dsk $d | grep -vc '^[0-9]*:$') files"
  fi
  rm -rf $w
done
exit $fail
