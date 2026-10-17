#!/bin/bash
# regression: every program in both modes on the CPC, then on the host platforms (test,
# cpcfw, cpm), then the platform classes (needs python3 + z80 module, sjasmplus, node + acorn)
cd "$(dirname "$0")"
P=../bas
fail=0
mkdir -p t/m2 t/cls t/ex
check() { # name expected-grep output - and the program must have ended (not waiting for a key)
  if echo "$3" | grep -q "$2" && echo "$3" | grep -q "^--- halted"; then echo "ok   $1"; else echo "FAIL $1"; echo "$3" | tail -5; fail=1; fi
}
# the small test programs (hook, for, gs ... wrap) are built for every platform and mode: each
# build in a folder of its own, out/PLATFORM[_turbo][_rom] (the .asm, .bin, .sym side by side
# to compare), the .bas copied there for the run and taken away after
outd() { # platform mode: the folder
  local d=out/$1; case "$2" in *turbo*) d=${d}_turbo;; esac; case "$2" in *library=rom*) d=${d}_rom;; esac
  mkdir -p $d; echo $d
}
# Interrupt hook: normal mode only (turbo has no interrupts)
d=$(outd cpc ""); cp hook.bas $d/
o=$(timeout 60 python3 cpcrun.py $d/hook.bas '' 2>&1 | grep -v "^--- "); rm -f $d/hook.bas
if [ "$o" == "$(cat ref/hook.txt)" ]; then echo "ok   hook normal"; else echo "FAIL hook normal"; fail=1; fi
for m in --turbo ""; do
  mn=${m:-normal}
  cp $P/vb_test.bas t/vb.bas; o=$(timeout 100 python3 cpcrun.py t/vb.bas 'x' $m 2>&1); check "vb_test $mn" "64 tests, 0 failed" "$o"
  cp $P/ntc_test.bas t/old.bas; o=$(timeout 100 python3 cpcrun.py t/old.bas 'Bob\n7\nx' $m 2>&1); check "ntc_test $mn" "36 tests, 0 failed" "$o"
  cp $P/vb_test2/*.bas t/m2/; o=$(timeout 100 python3 cpcrun.py t/m2/Main.bas 'x' t/m2/Module2.bas $m 2>&1); check "vb_test2 $mn" "30 tests, 0 failed" "$o"
  cp $P/vb_test3.bas t/v3.bas; o=$(timeout 100 python3 cpcrun.py t/v3.bas '~x' $m 2>&1); check "vb_test3 $mn" "11 tests, 0 failed" "$o"
  cp $P/vb_test_long.bas t/lg.bas; o=$(timeout 200 python3 cpcrun.py t/lg.bas 'x' $m 2>&1); check "long $mn" "58 tests, 0 failed" "$o"
  cp $P/vb_test4.bas t/v4.bas; o=$(timeout 200 python3 cpcrun.py t/v4.bas 'x' $m 2>&1); check "vb_test4 $mn" "16 tests, 0 failed" "$o"
  mkdir -p t/v5; cp $P/vb_test5/* t/v5/; o=$(timeout 200 python3 cpcrun.py t/v5/Main.bas 'x' t/v5/Pool.cls $m 2>&1); check "vb_test5 $mn" "18 tests, 0 failed" "$o"
  cp $P/vb_test6.bas t/v6.bas; o=$(timeout 200 python3 cpcrun.py t/v6.bas 'x' $m 2>&1); check "vb_test6 $mn" "22 tests, 0 failed" "$o"
  cp $P/vb_test7.bas t/v7.bas; o=$(timeout 200 python3 cpcrun.py t/v7.bas 'x' $m 2>&1); check "vb_test7 $mn" "16 tests, 0 failed" "$o"
  cp $P/vb_test8.bas t/v8.bas; o=$(timeout 200 python3 cpcrun.py t/v8.bas 'x' $m 2>&1); check "vb_test8 $mn" "5 tests, 0 failed" "$o"
  cp $P/vb_test11.bas t/v11.bas; o=$(timeout 200 python3 cpcrun.py t/v11.bas 'x' $m 2>&1); check "vb_test11 $mn" "17 tests, 0 failed" "$o"
  cp $P/vb_test12.bas t/v12.bas; o=$(timeout 200 python3 cpcrun.py t/v12.bas 'abcdefgh\nx' $m 2>&1); check "vb_test12 $mn" "33 tests, 0 failed" "$o"
  cp $P/vb_test9.bas t/v9.bas; o=$(timeout 200 python3 cpcrun.py t/v9.bas 'x' $m 2>&1); check "vb_test9 $mn" "34 tests, 0 failed" "$o"
  mkdir -p t/v10; cp $P/vb_test10/* t/v10/; o=$(timeout 200 python3 cpcrun.py t/v10/Main.bas 'x' t/v10/Bag.cls $m 2>&1); check "vb_test10 $mn" "33 tests, 0 failed" "$o"
  mkdir -p t/argfn; cp argfn/*.bas argfn/*.cls t/argfn/; o=$(timeout 100 python3 cpcrun.py t/argfn/Main.bas 'x' t/argfn/A2.cls $m 2>&1); o="$(echo "$o" | grep -v "^---" | head -3 | tr "\n" "/")"$'\n'"$(echo "$o" | grep "^--- halted")"; check "fn args $mn" "^123040567080/12345678/123040567080/" "$o"
  cp $P/class_demo/* t/cls/; o=$(timeout 100 python3 cpcrun.py t/cls/Main.bas 'x' t/cls/Counter.cls $m 2>&1); check "class $mn" "x=12" "$o"
  cp $P/sieve.bas t/ex/; o=$(timeout 100 python3 cpcrun.py t/ex/sieve.bas 'x' $m 2>&1); check "sieve $mn" "168 primes" "$o"
  cp $P/shellsort.bas t/ex/; o=$(timeout 100 python3 cpcrun.py t/ex/shellsort.bas '300\ntnx' $m 2>&1); check "shellsort $mn" "^6 8 9 26 26 31 34 34 34 35" "$o"
  cp $P/sievetime.bas t/ex/; o=$(timeout 200 python3 cpcrun.py t/ex/sievetime.bas '1\ntnx' $m 2>&1); check "sievetime $mn" "1007 primes below 8000" "$o"
  cp $P/guide.bas t/ex/; o=$(timeout 100 python3 cpcrun.py t/ex/guide.bas 'Ann\nx' $m 2>&1); check "guide $mn" "ANN!" "$o"
  for f in for gs gs2 scr0 scr2 diag1 diag2 vbprint cmptext tiny wrap; do
    d=$(outd cpc "$m"); cp $f.bas $d/
    o=$(timeout 40 python3 cpcrun.py $d/$f.bas '' $m 2>&1 | grep -v "^--- "); rm -f $d/$f.bas
    if [ "$o" == "$(cat ref/$f.txt)" ]; then echo "ok   $f $mn"; else echo "FAIL $f $mn"; fail=1; fi
  done
done
# the same programs on the host platforms (test harness console, CPC firmware, CP/M)
host() { # platform mode
  pl=$1; m=$2; mn="$pl ${m:-normal}"; R="timeout 200 python3 ntcrun.py"
  cp $P/vb_test.bas t/vb.bas; check "vb_test $mn" "64 tests, 0 failed" "$($R t/vb.bas 'x' --platform=$pl $m 2>&1)"
  cp $P/ntc_test.bas t/old.bas; check "ntc_test $mn" "36 tests, 0 failed" "$($R t/old.bas 'Bob\n7\nx' --platform=$pl $m 2>&1)"
  cp $P/vb_test2/*.bas t/m2/; check "vb_test2 $mn" "30 tests, 0 failed" "$($R t/m2/Main.bas 'x' t/m2/Module2.bas --platform=$pl $m 2>&1)"
  cp $P/vb_test3.bas t/v3.bas; check "vb_test3 $mn" "11 tests, 0 failed" "$($R t/v3.bas '~x' --platform=$pl $m 2>&1)"
  cp $P/vb_test_long.bas t/lg.bas; check "long $mn" "58 tests, 0 failed" "$($R t/lg.bas 'x' --platform=$pl $m 2>&1)"
  cp $P/vb_test4.bas t/v4.bas; check "vb_test4 $mn" "16 tests, 0 failed" "$($R t/v4.bas 'x' --platform=$pl $m 2>&1)"
  mkdir -p t/v5; cp $P/vb_test5/* t/v5/; check "vb_test5 $mn" "18 tests, 0 failed" "$($R t/v5/Main.bas 'x' t/v5/Pool.cls --platform=$pl $m 2>&1)"
  cp $P/vb_test6.bas t/v6.bas; check "vb_test6 $mn" "22 tests, 0 failed" "$($R t/v6.bas 'x' --platform=$pl $m 2>&1)"
  cp $P/vb_test7.bas t/v7.bas; check "vb_test7 $mn" "16 tests, 0 failed" "$($R t/v7.bas 'x' --platform=$pl $m 2>&1)"
  cp $P/vb_test8.bas t/v8.bas; check "vb_test8 $mn" "5 tests, 0 failed" "$($R t/v8.bas 'x' --platform=$pl $m 2>&1)"
  cp $P/vb_test9.bas t/v9.bas; check "vb_test9 $mn" "34 tests, 0 failed" "$($R t/v9.bas 'x' --platform=$pl $m 2>&1)"
  mkdir -p t/v10; cp $P/vb_test10/* t/v10/; check "vb_test10 $mn" "33 tests, 0 failed" "$($R t/v10/Main.bas 'x' t/v10/Bag.cls --platform=$pl $m 2>&1)"
  cp $P/vb_test11.bas t/v11.bas; check "vb_test11 $mn" "17 tests, 0 failed" "$($R t/v11.bas 'x' --platform=$pl $m 2>&1)"
  cp $P/vb_test12.bas t/v12.bas; check "vb_test12 $mn" "33 tests, 0 failed" "$($R t/v12.bas 'abcdefgh\nx' --platform=$pl $m 2>&1)"
  cp $P/class_demo/* t/cls/; check "class $mn" "x=12" "$($R t/cls/Main.bas 'x' t/cls/Counter.cls --platform=$pl $m 2>&1)"
  cp $P/sieve.bas t/ex/; check "sieve $mn" "168 primes" "$($R t/ex/sieve.bas 'x' --platform=$pl $m 2>&1)"
  cp $P/shellsort.bas t/ex/; check "shellsort $mn" "^6 8 9 26 26 31 34 34 34 35" "$($R t/ex/shellsort.bas '300\ntnx' --platform=$pl $m 2>&1)"
  cp $P/sievetime.bas t/ex/; check "sievetime $mn" "1007 primes below 8000" "$($R t/ex/sievetime.bas '1\ntnx' --platform=$pl $m 2>&1)"
  cp $P/guide.bas t/ex/; check "guide $mn" "ANN!" "$($R t/ex/guide.bas 'Ann\nx' --platform=$pl $m 2>&1)"
  L="for gs gs2 scr0 scr2 diag1 diag2 vbprint cmptext tiny wrap"
  [ "$pl" == cpm ] && L="for gs gs2 diag1 diag2 vbprint cmptext tiny"	# a stream: no Locate / Mode
  for f in $L; do
    d=$(outd $pl "$m"); cp $f.bas $d/
    o=$($R $d/$f.bas '' --platform=$pl $m 2>&1 | grep -v "^--- "); rm -f $d/$f.bas
    rf=ref/$f.txt; case "$m" in *library=rom*) [ -f ref/${f}_rom.txt ] && rf=ref/${f}_rom.txt;; esac   # ROM: strings up to 255
    if [ "$o" == "$(cat $rf)" ]; then echo "ok   $f $mn"; else echo "FAIL $f $mn"; fail=1; fi
  done
}
for pl in test cpcfw cpm zxn; do for m in --turbo ""; do host $pl "$m"; done; done
# Library: ROM (cpcfw): the keywords in NTCFW.ROM (the harness puts its image in slot 6)
for pl in cpc cpcmin cpcfw; do for m in "--turbo --library=rom" "--library=rom"; do host $pl "$m"; done; done
# StdIO / System platform classes on every platform, and a project's own StdIO
for pl in cpc cpcmin test cpcfw cpm zxn; do
  cp stdio.bas t/stdio.bas; o=$(timeout 100 python3 ntcrun.py t/stdio.bas 'Bo\nZ' --platform=$pl 2>&1 | grep -v "^--- ")
  if [ "$o" == "$(cat ref/stdio.$pl.txt)" ]; then echo "ok   stdio $pl"; else echo "FAIL stdio $pl"; fail=1; fi
done
for f in term_vt52 term_ansi; do	# CP/M Option Terminal
  cp $f.bas t/; o=$(timeout 100 python3 ntcrun.py t/$f.bas '' --platform=cpm 2>&1 | grep -v "^--- ")
  if [ "$o" == "$(cat ref/$f.txt)" ]; then echo "ok   $f cpm"; else echo "FAIL $f cpm"; fail=1; fi
done
# FileSystem: CP/M (BDOS files), CPC firmware (Load / Save), no files (test, cpc); both modes
for m in --turbo ""; do
  # test platform ref [harness option]: fs_fw2 without Option RomEnable - RUN" (tape) and CALLed (disc)
  for c in "fs_cpm cpm fs_cpm" "fs_fw cpcfw fs_fw" "fs_fw2 cpcfw fs_fw2" "fs_fw2 cpcfw fs_fw2c --called" "fs_none test fs_none" "fs_none zxn fs_none" "fs_none cpc fs_none_cpc" "fs_fw cpcmin fs_fw" "fs_fw2 cpcmin fs_fw2"; do
    set -- $c; rm -rf t/files; cp $1.bas t/
    o=$(timeout 100 python3 ntcrun.py t/$1.bas '' --platform=$2 $4 $m 2>&1 | grep -v "^--- ")
    if [ "$o" == "$(cat ref/$3.txt)" ]; then echo "ok   $3 $2 ${m:-normal}"; else echo "FAIL $3 $2 ${m:-normal}"; echo "$o" | head -5; fail=1; fi
  done
  for pl in cpcmin cpcfw; do   # AMSDOS through the firmware: cpcmin hands back for each file call
    rm -rf t/files; cp $P/amsdos.bas t/ex/
    check "amsdos $pl ${m:-normal}" "^done" "$(timeout 200 python3 ntcrun.py t/ex/amsdos.bas '~x~x~x~b~x' --platform=$pl $m 2>&1)"
  done
  for pl in cpm cpcfw test; do
    rm -rf t/files; cp $P/files.bas t/ex/
    check "files $pl ${m:-normal}" "Press a key" "$(timeout 100 python3 ntcrun.py t/ex/files.bas '~x' --platform=$pl $m 2>&1)"
  done
done
# FileSystem on the CPC with the firmware: one open file (Open / ReadByte / WriteLine ... CAS IN / OUT CHAR)
for m in --turbo ""; do
  for pl in cpcfw cpcmin; do
    rm -rf t/files; cp seq_t.bas t/
    o=$(timeout 100 python3 ntcrun.py t/seq_t.bas '' --platform=$pl $m 2>&1 | grep -v "^--- ")
    if [ "$o" == "$(cat ref/seq.txt)" ]; then echo "ok   sequential files $pl ${m:-normal}"; else echo "FAIL sequential files $pl ${m:-normal}"; echo "$o" | head -5; fail=1; fi
  done
done
# Keys class: Down(n) / Joystick(n) from the keyboard matrix ({n} = the harness holds key n)
for m in --turbo ""; do
  for pl in cpc cpcmin cpcfw; do
    cp keys_t.bas t/
    o=$(timeout 100 python3 ntcrun.py t/keys_t.bas '{47}{69}{77}{73}{50}' --platform=$pl $m 2>&1 | grep -v "^--- ")
    if [ "$o" == "$(cat ref/keys.txt)" ]; then echo "ok   keys $pl ${m:-normal}"; else echo "FAIL keys $pl ${m:-normal}"; echo "$o" | head -5; fail=1; fi
  done
done
# Keys on the ZX Spectrum Next (zxn): its own key numbers (half row * 8 + bit), Kempston joysticks
for m in --turbo ""; do
  cp keys_zxn.bas t/
  o=$(timeout 100 python3 ntcrun.py t/keys_zxn.bas '{56}{8}{60}{28}{56}' --platform=zxn $m 2>&1 | grep -v "^--- ")
  if [ "$o" == "$(cat ref/keys_zxn.txt)" ]; then echo "ok   keys zxn ${m:-normal}"; else echo "FAIL keys zxn ${m:-normal}"; echo "$o" | head -5; fail=1; fi
done
# the same with Library: ROM (the keyword ROMs; cpcmin's sequential file code is not in its ROM -
# the program has its own copy, @ramonly): banks, keys, sequential files, 8 interrupt classes
for pl in cpc cpcmin cpcfw; do
  cp bank_t.bas keys_t.bas seq_t.bas t/
  o=$(timeout 200 python3 ntcrun.py t/bank_t.bas '' --library=rom --platform=$pl --ram=576 2>&1 | grep -v "^--- ")
  if [ "$o" == "$(cat ref/bank_576.txt)" ]; then echo "ok   ROM: memory banks $pl"; else echo "FAIL ROM: memory banks $pl"; echo "$o" | head -5; fail=1; fi
  o=$(timeout 100 python3 ntcrun.py t/keys_t.bas '{47}{69}{77}{73}{50}' --library=rom --platform=$pl 2>&1 | grep -v "^--- ")
  if [ "$o" == "$(cat ref/keys.txt)" ]; then echo "ok   ROM: keys $pl"; else echo "FAIL ROM: keys $pl"; echo "$o" | head -5; fail=1; fi
  if [ $pl != cpc ]; then
    rm -rf t/files
    o=$(timeout 100 python3 ntcrun.py t/seq_t.bas '' --library=rom --platform=$pl 2>&1 | grep -v "^--- ")
    if [ "$o" == "$(cat ref/seq.txt)" ]; then echo "ok   ROM: sequential files $pl"; else echo "FAIL ROM: sequential files $pl"; echo "$o" | head -5; fail=1; fi
  fi
done
# Memory class: whole 64K banks - AllocBank, CallBank (the bank as all 64K), FreeBank
for m in --turbo ""; do
  for c in "64 cpc" "128 cpcmin" "128 cpcfw" "576 cpc"; do
    set -- $c; cp bank_t.bas t/
    o=$(timeout 200 python3 ntcrun.py t/bank_t.bas '' --platform=$2 --ram=$1 $m 2>&1 | grep -v "^--- ")
    if [ "$o" == "$(cat ref/bank_$1.txt)" ]; then echo "ok   memory banks $1K $2 ${m:-normal}"; else echo "FAIL memory banks $1K $2 ${m:-normal}"; echo "$o" | head -5; fail=1; fi
  done
done
# Memory class: RAM pages probed on a 64K, 128K, 576K and 4MB CPC; the same on cpcmin / cpcfw; both modes
for m in --turbo ""; do
  for c in "64 cpc" "128 cpc" "576 cpc" "4160 cpc" "128 cpcmin" "128 cpcfw"; do
    set -- $c; cp mem_t.bas t/
    o=$(timeout 200 python3 ntcrun.py t/mem_t.bas '' --platform=$2 --ram=$1 $m 2>&1 | grep -v "^--- ")
    if [ "$o" == "$(cat ref/mem_$1.txt)" ]; then echo "ok   memory $1K $2 ${m:-normal}"; else echo "FAIL memory $1K $2 ${m:-normal}"; echo "$o" | head -5; fail=1; fi
  done
done
# Option Buffer Size: Memory.Copy 64 bytes at a time (the same results); FileSystem with less than 2K refused
{ printf 'Option Buffer Size 64\n'; cat mem_t.bas; } > t/mem_b.bas
o=$(timeout 200 python3 ntcrun.py t/mem_b.bas '' --platform=cpc --ram=576 2>&1 | grep -v "^--- ")
if [ "$o" == "$(cat ref/mem_576.txt)" ]; then echo "ok   Option Buffer Size: Memory.Copy"; else echo "FAIL Option Buffer Size: Memory.Copy"; echo "$o" | head -5; fail=1; fi
printf 'Option Buffer Size 128\nPrint FileSystem.Exists("A.TXT")\n' > t/buf_fs.bas
node cli.js t/buf_fs.bas --platform=cpcfw > t/buf_fs.asm 2>/dev/null; (cd t && ${SJASMPLUS:-sjasmplus} --nologo --msg=err buf_fs.asm 2>&1) | grep -q "FileSystem needs the whole 2K buffer" && echo "ok   Option Buffer Size: FileSystem refused" || { echo "FAIL Option Buffer Size: FileSystem refused"; fail=1; }
cp $P/memmap.bas t/ex/
check "memmap cpc 64K" "^After Free: 0 pages free" "$(timeout 200 python3 ntcrun.py t/ex/memmap.bas '~x~x' --platform=cpc --ram=64 2>&1)"
check "memmap cpc 576K" "^Bank 8 " "$(timeout 200 python3 ntcrun.py t/ex/memmap.bas '~x~x' --platform=cpc --ram=576 2>&1)"
check "memmap cpc 4MB" "^&7E DD---" "$(timeout 300 python3 ntcrun.py t/ex/memmap.bas '~x~x' --platform=cpc --ram=4160 2>&1)"
check "memmap cpcfw 128K" "^Pages UCU--" "$(timeout 200 python3 ntcrun.py t/ex/memmap.bas '~x~x' --platform=cpcfw 2>&1)"
# a program ending near #4000 with Option Reserve over the window: the page tables go above it (all 4MB)
printf 'Option Reserve &H4000, &H4000\nDim big(5800) As Integer\nIf Memory.Pages() = 257 And Memory.TableEnd() > &H8000 Then Print "tables fit"\n' > t/lim.bas
check "memory tables after Option Reserve" "^tables fit" "$(timeout 200 python3 ntcrun.py t/lim.bas '' --platform=cpc --ram=4160 2>&1)"
# Option Memory Small: a heap in main RAM, on every platform; both modes
for m in --turbo ""; do
  for pl in cpc cpcfw cpm test zxn; do
    cp mem_s.bas t/; o=$(timeout 200 python3 ntcrun.py t/mem_s.bas '' --platform=$pl $m 2>&1 | grep -v "^--- ")
    if [ "$o" == "$(cat ref/mem_small.txt)" ]; then echo "ok   memory small $pl ${m:-normal}"; else echo "FAIL memory small $pl ${m:-normal}"; echo "$o" | head -5; fail=1; fi
  done
done
# Option Memory CPCExpansion n caps the pages (1: no probe at all); CPCExpansion is refused off the CPC
printf 'Option Reserve &H4000, &H4000\nOption Memory CPCExpansion 5\nPrint "pages"; Memory.Pages()\n' > t/cap5.bas
check "Option Memory CPCExpansion 5 on 576K" "^pages5" "$(timeout 200 python3 ntcrun.py t/cap5.bas '' --platform=cpc --ram=576 2>&1)"
printf 'Option Reserve &H4000, &H4000\nOption Memory CPCExpansion 1\nPrint "pages"; Memory.Pages()\n' > t/cap1.bas
check "Option Memory CPCExpansion 1 on 576K" "^pages1" "$(timeout 200 python3 ntcrun.py t/cap1.bas '' --platform=cpc --ram=576 2>&1)"
printf 'Option Memory CPCExpansion\nPrint Memory.Pages()\n' > t/capx.bas
node cli.js t/capx.bas --platform=cpm > /dev/null 2> t/capx.err; grep -q "Option Memory CPCExpansion is for the CPC platforms" t/capx.err && echo "ok   Option Memory CPCExpansion refused on cpm" || { echo "FAIL Option Memory CPCExpansion refused on cpm"; fail=1; }
for pl in test cpm zxn; do check "memmap $pl" "^No paging - heap" "$(timeout 200 python3 ntcrun.py t/ex/memmap.bas '~x~x' --platform=$pl 2>&1)"; done
check "memmap cpm main map" "^Free main RAM: [0-9]" "$(timeout 200 python3 ntcrun.py t/ex/memmap.bas '~x~x' --platform=cpm 2>&1)"
check "memmap cpcfw summary" "^128K, 5 pages: main + 1 banks" "$(timeout 200 python3 ntcrun.py t/ex/memmap.bas '~x~x' --platform=cpcfw 2>&1)"
# overlay classes (Option Class Overlay): built into .PAG files in the same compile, loaded into
# C pages on the first call; cpcmin / cpcfw, both modes; 64K: no page free, a message
for m in --turbo ""; do
  for pl in cpcmin cpcfw; do
    rm -rf t/files t/ovl; mkdir -p t/ovl; cp ovl/* t/ovl/
    o=$(timeout 200 python3 ntcrun.py t/ovl/Main.bas '' t/ovl/Level1.cls t/ovl/Level2.cls --platform=$pl $m 2>&1 | grep -v "^--- ")
    if [ "$o" == "$(cat ref/ovl.txt)" ]; then echo "ok   overlays $pl ${m:-normal}"; else echo "FAIL overlays $pl ${m:-normal}"; echo "$o" | head -5; fail=1; fi
  done
done
rm -rf t/files; check "overlays 64K" "^No RAM page free" "$(timeout 200 python3 ntcrun.py t/ovl/Main.bas '~x' t/ovl/Level1.cls t/ovl/Level2.cls --platform=cpcmin --ram=64 2>&1)"
printf 'Option Class Overlay\nPublic Sub X()\nEnd Sub\n' > t/ovl/Bad.cls; printf 'Bad.X\n' > t/ovl/b.bas; printf 'Option Memory Small\nBad.X\n' > t/ovl/b2.bas
node cli.js t/ovl/b.bas t/ovl/Bad.cls --platform=cpc 2>&1 >/dev/null | grep -q "Option Class Overlay needs a platform" && node cli.js t/ovl/b.bas t/ovl/Bad.cls --platform=test 2>&1 >/dev/null | grep -q "Option Class Overlay needs a platform" && echo "ok   overlays refused (cpc, test)" || { echo "FAIL overlays refused"; fail=1; }
# one overlay area (Option Memory Small, CP/M): classes take turns at #4000; a return loads the
# caller's class again; Load / Unload from the area refused; cpm, cpcmin, cpcfw (also 64K)
for m in --turbo ""; do
  for c in "cpm 128" "cpcmin 128" "cpcfw 128" "cpcmin 64"; do
    set -- $c
    rm -rf t/files t/ovls; mkdir -p t/ovls; cp ovls/* t/ovls/
    o=$(timeout 200 python3 ntcrun.py t/ovls/Main.bas '' t/ovls/A.cls t/ovls/B.cls --platform=$1 --ram=$2 $m 2>&1 | grep -v "^--- ")
    if [ "$o" == "$(cat ref/ovls.txt)" ]; then echo "ok   overlay area $1 ${2}K ${m:-normal}"; else echo "FAIL overlay area $1 ${2}K ${m:-normal}"; echo "$o" | head -5; fail=1; fi
  done
done
printf 'Option Memory Small\nPrint "del"; FileSystem.Delete("OVB.PAG")\nPrint B.Chain(1)\nPrint "not here"\nSub Note(ByVal t As String)\nEnd Sub\n' > t/ovls/gone.bas
o=$(timeout 200 python3 ntcrun.py t/ovls/gone.bas 'x' t/ovls/A.cls t/ovls/B.cls --platform=cpm 2>&1)
echo "$o" | grep -q "^Overlay not loaded: OVB.PAG" && echo "$o" | grep -q "^The file didn't load" && ! echo "$o" | grep -q "not here" && echo "ok   overlay area: file gone" || { echo "FAIL overlay area: file gone"; echo "$o" | tail -4; fail=1; }
# pages (Option Page): classes packed into pages, a class copied into two pages (paged variables
# separate per copy; main calls use the home copy), calls inside a page without a page switch,
# a class used by a page but in none (main RAM); RAM pages on cpcmin / cpcfw, one overlay area
# on cpm and cpcmin with Option Memory Small (paged variables are ordinary variables there)
PF="t/pg/Title.cls t/pg/Level1.cls t/pg/Level2.cls t/pg/Shared.cls t/pg/Counter.cls t/pg/Credits.cls t/pg/Util.cls t/pg/OnlyOne.cls"
for m in --turbo ""; do
  for c in "Main cpcmin pages" "Main cpcfw pages" "Main cpm pages_small" "MainS cpcmin pages_small"; do
    set -- $c
    rm -rf t/files t/pg; mkdir -p t/pg; cp pages/* t/pg/
    sed 's/^Option Reserve/Option Memory Small\nOption Reserve/' t/pg/Main.bas > t/pg/MainS.bas
    o=$(timeout 200 python3 ntcrun.py t/pg/$1.bas '' $PF --platform=$2 $m 2>&1 | grep -v "^--- ")
    if [ "$o" == "$(cat ref/$3.txt)" ]; then echo "ok   pages $1 $2 ${m:-normal}"; else echo "FAIL pages $1 $2 ${m:-normal}"; echo "$o" | head -5; fail=1; fi
  done
done
o=$(node cli.js t/pg/Main.bas $PF --platform=cpcmin --layout 2>&1)
echo "$o" | grep -q "dw p_shared_sum_cl__level2" && echo "$o" | grep -q "dw p_shared_sum_c, lit_10" && echo "$o" | grep -q "^p_counter_bump_ct:.db 1" && echo "$o" | grep -q "^LAYOUT Page LEVEL2 (MAIN.003): level2 [0-9]*, shared [0-9]* (copy), counter [0-9]* (copy)" && echo "$o" | grep -q "^LAYOUT Main RAM, called from pages: util" && echo "ok   pages: local calls, layout" || { echo "FAIL pages: local calls, layout"; fail=1; }
pe() { # name, expected message, main source
  printf "$3" > t/pg/E.bas
  node cli.js t/pg/E.bas $PF --platform=cpcmin 2>&1 >/dev/null | grep -q "$2" && echo "ok   pages refused: $1" || { echo "FAIL pages refused: $1"; fail=1; }
}
pe "no class" "no class Nope in the project" 'Option Page "A" = Nope\n'
pe "twice" 'Option Page "A" is declared twice' 'Option Page "A" = Title\nOption Page "A" = Util\n'
pe "class twice" "title is in it twice" 'Option Page "A" = Title, Title\n'
pe "home" "Option Home: shared is not in page CREDITS" 'Option Page "L1" = Shared\nOption Page "L2" = Shared\nOption Home Shared = "CREDITS"\n'
pe "empty" 'Option Page "E": no classes in it' 'Option Page "E" = \n'
node cli.js t/pg/Main.bas $PF --platform=cpc 2>&1 >/dev/null | grep -q "Option Page / Option Class Overlay needs a platform" && echo "ok   pages refused: cpc" || { echo "FAIL pages refused: cpc"; fail=1; }
rm -rf t/files t/dv; mkdir -p t/dv; cp drv/* t/dv/
check "pages: a page class with a Tick" "^ticks in a second: about 50" "$(timeout 300 python3 ntcrun.py t/dv/Main.bas '' t/dv/Drv.cls --platform=cpcmin 2>&1)"
printf 'Option Memory Small\n' | cat - t/dv/Main.bas > t/dv/S.bas
node cli.js t/dv/S.bas t/dv/Drv.cls --platform=cpcmin 2>&1 >/dev/null | grep -q "its Tick would load it from disc" && echo "ok   pages: Tick refused with one overlay area" || { echo "FAIL pages: Tick refused with one overlay area"; fail=1; }
mkdir -p t/st; printf 'Public Function F() As Integer\n  F = 7\nEnd Function\n' > t/st/C.cls; printf 'Option Page "STALE.PAG" = C\nOption Reserve &H4000, &H4000\nPrint C.F()\nPrint "after"\n' > t/st/Main.bas
rm -rf t/files; o1=$(timeout 100 python3 ntcrun.py t/st/Main.bas '' t/st/C.cls --platform=cpm 2>&1); printf 'Option Page "STALE.PAG" = C\nOption Reserve &H4000, &H4000\nPrint "new build"\nPrint C.F()\nPrint "after"\n' > t/st/Main.bas
o=$(NTC_KEEPPAGES=1 timeout 100 python3 ntcrun.py t/st/Main.bas 'x' t/st/C.cls --platform=cpm 2>&1)
echo "$o1" | grep -q "^7" && echo "$o" | grep -q "^The file is from another build" && echo "$o" | grep -q "^Overlay not loaded: STALE.PAG" && ! echo "$o" | grep -q "^after" && echo "ok   pages: a page file from another build refused" || { echo "FAIL pages: a page file from another build refused"; echo "$o" | tail -4; fail=1; }
printf 'Option Page "STALE.PAG" = C\nOption RomEnable 7\nOption Reserve &H4000, &H4000\nPrint C.F()\nPrint "after"\n' > t/st/Main.bas
rm -rf t/files; o1=$(timeout 100 python3 ntcrun.py t/st/Main.bas '' t/st/C.cls --platform=cpcmin 2>&1)
printf 'Option Page "STALE.PAG" = C\nOption RomEnable 7\nOption Reserve &H4000, &H4000\nPrint "load"; C.Load()\nPrint C.F()\nPrint "after"\n' > t/st/Main.bas
o=$(NTC_KEEPPAGES=1 timeout 100 python3 ntcrun.py t/st/Main.bas 'x' t/st/C.cls --platform=cpcmin 2>&1)
echo "$o1" | grep -q "^7" && echo "$o" | grep -q "^load-14" && echo "$o" | grep -q "^The file is from another build" && ! echo "$o" | grep -q "^after" && echo "ok   pages: a page file from another build refused (RAM pages, Load -14)" || { echo "FAIL pages: stale page RAM pages"; echo "$o" | tail -4; fail=1; }
rm -rf t/files t/pd; mkdir -p t/pd; cp ../bas/pages/* t/pd/
check "pages demo cpcmin (bare page names)" "^Final score 128 - thanks for playing" "$(timeout 200 python3 ntcrun.py t/pd/Main.bas '~x' t/pd/Title.cls t/pd/Level1.cls t/pd/Level2.cls t/pd/Maths.cls t/pd/Stars.cls t/pd/Credits.cls t/pd/Score.cls --platform=cpcmin 2>&1)"
rm -rf t/files; o=$(timeout 100 python3 ntcrun.py t/pd/Main.bas 'x' t/pd/Title.cls t/pd/Level1.cls t/pd/Level2.cls t/pd/Maths.cls t/pd/Stars.cls t/pd/Credits.cls t/pd/Score.cls --platform=cpm 2>&1 | head -0; rm -f t/files/A/MAIN.002; NTC_KEEPPAGES=1 timeout 100 python3 ntcrun.py t/pd/Main.bas 'x' t/pd/Title.cls t/pd/Level1.cls t/pd/Level2.cls t/pd/Maths.cls t/pd/Stars.cls t/pd/Credits.cls t/pd/Score.cls --platform=cpm 2>&1)
echo "$o" | grep -q "^Overlay not loaded: Stage1 (MAIN.002)" && echo "ok   pages: the message names the page and its file" || { echo "FAIL pages: the message names the page and its file"; echo "$o" | tail -4; fail=1; }
mkdir -p t/sj; printf 'Option Class Overlay "LEVEL1"\nPublic Function F() As Integer\n  F = 5\nEnd Function\n' > t/sj/Extra.cls; printf 'Public Function G() As Integer\n  G = Extra.F() + 1\nEnd Function\n' > t/sj/Lv.cls; printf 'Option Page "LEVEL1" = Lv\nOption Reserve &H4000, &H4000\nPrint Lv.G(); Extra.F()\n' > t/sj/Main.bas
rm -rf t/files; o=$(node cli.js t/sj/Main.bas t/sj/Extra.cls t/sj/Lv.cls --platform=cpm --layout 2>&1 >/dev/null; timeout 100 python3 ntcrun.py t/sj/Main.bas '' t/sj/Extra.cls t/sj/Lv.cls --platform=cpm 2>&1)
echo "$o" | grep -q "^LAYOUT Page LEVEL1 (MAIN.001): lv [0-9]*, extra [0-9]*;" && echo "$o" | grep -q "^65" && echo "ok   pages: Option Class Overlay joins an Option Page" || { echo "FAIL pages: Option Class Overlay joins an Option Page"; fail=1; }
rm -rf t/files t/od; mkdir -p t/od; cp $P/overlays/* t/od/
check "overlays demo cpcmin" "^Unload level 1: 0 - pages -C" "$(timeout 200 python3 ntcrun.py t/od/Main.bas '~x' t/od/Level1.cls t/od/Level2.cls --platform=cpcmin 2>&1)"
rm -rf t/files; check "overlays demo cpm" "^Unload level 2: 0 - level 2 0" "$(timeout 200 python3 ntcrun.py t/od/Main.bas '~x' t/od/Level1.cls t/od/Level2.cls --platform=cpm 2>&1)"
# interrupt classes (Option Class Interrupt rate | Frame): Tick at safe points, normal mode; cpc / cpcmin
# (NTC's interrupt handler) and cpcfw (a firmware fast ticker event)
for pl in cpc cpcmin cpcfw; do
  rm -rf t/isl; mkdir -p t/isl; cp isl/* t/isl/
  o=$(timeout 200 python3 ntcrun.py t/isl/Main.bas '' t/isl/Music.cls t/isl/Fast.cls t/isl/Slow.cls t/isl/Frames.cls --platform=$pl 2>&1 | grep -v "^--- ")
  if [ "$o" == "$(cat ref/isl.txt)" ]; then echo "ok   interrupt classes $pl"; else echo "FAIL interrupt classes $pl"; echo "$o" | head -5; fail=1; fi
done
# more than 4 interrupt classes, and shared ones (Share n: turns, by weight, in the interrupts the fixed ones leave)
I2="t/isl2/F50.cls t/isl2/F10.cls t/isl2/S1a.cls t/isl2/S1b.cls t/isl2/S2a.cls t/isl2/S2b.cls t/isl2/S3a.cls t/isl2/S3b.cls"
for pl in cpc cpcmin cpcfw; do
  rm -rf t/isl2; mkdir -p t/isl2; cp isl2/* t/isl2/
  o=$(timeout 200 python3 ntcrun.py t/isl2/Main.bas '' $I2 --platform=$pl 2>&1 | grep -v "^--- ")
  if [ "$o" == "$(cat ref/isl2.txt)" ]; then echo "ok   interrupt classes: 8, shared by weight $pl"; else echo "FAIL interrupt classes: 8, shared $pl"; echo "$o" | head -5; fail=1; fi
  o=$(timeout 200 python3 ntcrun.py t/isl2/Main.bas '' $I2 --library=rom --platform=$pl 2>&1 | grep -v "^--- ")
  if [ "$o" == "$(cat ref/isl2.txt)" ]; then echo "ok   interrupt classes: 8, shared by weight $pl ROM"; else echo "FAIL interrupt classes: 8, shared $pl ROM"; echo "$o" | head -5; fail=1; fi
done
# the ZX Spectrum Next (zxn): the line interrupt every 52 lines (6 a frame, 300 a second, as the
# CPC's); its Frame really waits a frame (50 a second), so the 300 a second class is checked in a
# loop without Frame (Tick runs at safe points: a Frame wait has none); 8 classes; the Interrupt hook
rm -rf t/isl; mkdir -p t/isl; cp isl/* t/isl/; sed -i 's/^Do : Frame : Loop/Do : i = i + 1 : Loop/' t/isl/Main.bas
o=$(timeout 300 python3 ntcrun.py t/isl/Main.bas '' t/isl/Music.cls t/isl/Fast.cls t/isl/Slow.cls t/isl/Frames.cls --platform=zxn 2>&1 | grep -v "^--- ")
if [ "$o" == "$(cat ref/isl.txt)" ]; then echo "ok   interrupt classes zxn"; else echo "FAIL interrupt classes zxn"; echo "$o" | head -5; fail=1; fi
rm -rf t/isl2; mkdir -p t/isl2; cp isl2/* t/isl2/; sed -i 's/^Do : Frame : Loop/Do : t0 = t0 + 0 : Loop/' t/isl2/Main.bas
o=$(timeout 300 python3 ntcrun.py t/isl2/Main.bas '' $I2 --platform=zxn 2>&1 | grep -v "^--- ")
if [ "$o" == "$(cat ref/isl2.txt)" ]; then echo "ok   interrupt classes: 8, shared by weight zxn"; else echo "FAIL interrupt classes: 8, shared zxn"; echo "$o" | head -5; fail=1; fi
cp hook.bas t/hook.bas; o=$(timeout 60 python3 ntcrun.py t/hook.bas '' --platform=zxn 2>&1 | grep -v "^--- ")
if [ "$o" == "$(cat ref/hook.txt)" ]; then echo "ok   hook zxn"; else echo "FAIL hook zxn"; echo "$o" | head -3; fail=1; fi
printf 'Dim t0 As Integer, n As Integer\nt0 = Ticks\nDo : Frame : n = n + 1 : Loop Until Ticks - t0 >= 300\nPrint "frames"; n > 45; n < 56\n' > t/zfr.bas
check "Frame and Ticks zxn: 50 frames, 300 ticks a second" "^frames-1-1" "$(timeout 300 python3 ntcrun.py t/zfr.bas '' --platform=zxn 2>&1)"
# the NEX file and the start stub: the NMI buttons off (NextReg 6 bits 3, 4), DivMMC's automatic
# paging off (10 bit 4), 28MHz (7 = 3), the slots (pages 16-21, then bank 5: 10, 11), the
# tilemap (#6B: on, 40 x 32, text mode), its palette, the line interrupt, a soft reset at the end
printf 'Print "Next"\n' > t/znex.bas
o=$(NTC_ZXNREGS=1 timeout 100 python3 ntcrun.py t/znex.bas '' --platform=zxn 2>&1)
python3 -c "
import sys; sys.path.insert(0, '.'); import zxnrun
b, pc, sp, e = zxnrun.read_nex('t/NTC.NEX')
sys.exit(0 if sorted(b) == [5, 8, 9, 10] and pc == 0x7E00 and sp == 0xBFFE else 1)" && echo "$o" | grep -q "^Next$" && echo "$o" | grep -q "^--- mmu 16 17 18 19 20 21 10 11$" \
  && echo "$o" | grep -q "^--- nextregs 02=01 06=00 07=03 0A=00 " && echo "$o" | grep -q " 6B=A9 6C=00 6E=20 6F=2C" && echo "$o" | grep -q "^--- palette 3/0=02 3/1=FC$" \
  && echo "$o" | grep -q "^--- halted (a soft reset: NextReg 2)" && echo "ok   zxn: the NEX file, the start stub (NMI off), the tilemap" || { echo "FAIL zxn: the NEX file, the start stub"; echo "$o" | tail -6; fail=1; }
node cli.js t/isl/Main.bas t/isl/Music.cls --platform=cpm 2>&1 >/dev/null | grep -q "Option Class Interrupt needs a CPC platform" && echo "ok   interrupt classes refused (cpm)" || { echo "FAIL interrupt classes refused"; fail=1; }
cp hook.bas t/hook.bas; o=$(timeout 60 python3 ntcrun.py t/hook.bas '' --platform=cpcfw 2>&1 | grep -v "^--- ")
if [ "$o" == "$(cat ref/hook.txt)" ]; then echo "ok   hook cpcfw"; else echo "FAIL hook cpcfw"; echo "$o" | head -3; fail=1; fi
# Library: ROM - the ROM is made from the library and the registry adds nothing (else: run
# genrom.js, which appends the new entries, then gen.js); the cpcfw demos and tests on the ROM
for pl in cpcfw cpc cpcmin; do
  o=$(node genrom.js $pl 2>&1); echo "$o" | grep -q "0 added, 0 gone" && echo "ok   ROM: $pl, registry unchanged" || { echo "FAIL ROM $pl: $o"; fail=1; }
done
R="timeout 200 python3 ntcrun.py"
for pl in cpc cpcmin cpcfw; do
  rm -rf t/isl; mkdir -p t/isl; cp isl/* t/isl/
  o=$($R t/isl/Main.bas '' t/isl/Music.cls t/isl/Fast.cls t/isl/Slow.cls t/isl/Frames.cls --platform=$pl --library=rom 2>&1 | grep -v "^--- ")
  if [ "$o" == "$(cat ref/isl.txt)" ]; then echo "ok   ROM: interrupt classes $pl"; else echo "FAIL ROM: interrupt classes $pl"; echo "$o" | head -5; fail=1; fi
done
rm -rf t/files; cp fs_fw.bas t/; o=$($R t/fs_fw.bas '' --platform=cpcmin --library=rom 2>&1 | grep -v "^--- ")
if [ "$o" == "$(cat ref/fs_fw.txt)" ]; then echo "ok   ROM: files cpcmin"; else echo "FAIL ROM: files cpcmin"; echo "$o" | head -5; fail=1; fi
rm -rf t/files; check "ROM: pages demo cpcmin" "^Final score 128 - thanks for playing" "$($R t/pd/Main.bas '~x' t/pd/Title.cls t/pd/Level1.cls t/pd/Level2.cls t/pd/Maths.cls t/pd/Stars.cls t/pd/Credits.cls t/pd/Score.cls --platform=cpcmin --library=rom 2>&1)"
rm -rf t/files; check "ROM: overlays demo cpcmin" "^Unload level 1: 0 - pages -C" "$($R t/od/Main.bas '~x' t/od/Level1.cls t/od/Level2.cls --platform=cpcmin --library=rom 2>&1)"
cp $P/memmap.bas t/ex/; check "ROM: memmap cpc" "^128K, 5 pages: main + 1 banks" "$($R t/ex/memmap.bas '~x~x' --platform=cpc --library=rom 2>&1)"
o=$(timeout 60 python3 ntcrun.py t/hook.bas '' --platform=cpcfw --library=rom 2>&1 | grep -v "^--- ")
if [ "$o" == "$(cat ref/hook.txt)" ]; then echo "ok   ROM: hook"; else echo "FAIL ROM: hook"; echo "$o" | head -3; fail=1; fi
rm -rf t/files; cp fs_fw.bas t/; o=$($R t/fs_fw.bas '' --platform=cpcfw --library=rom 2>&1 | grep -v "^--- ")
if [ "$o" == "$(cat ref/fs_fw.txt)" ]; then echo "ok   ROM: files (AMSDOS)"; else echo "FAIL ROM: files"; echo "$o" | head -5; fail=1; fi
rm -rf t/files; check "ROM: pages demo" "^Final score 128 - thanks for playing" "$($R t/pd/Main.bas '~x' t/pd/Title.cls t/pd/Level1.cls t/pd/Level2.cls t/pd/Maths.cls t/pd/Stars.cls t/pd/Credits.cls t/pd/Score.cls --platform=cpcfw --library=rom 2>&1)"
rm -rf t/files; check "ROM: overlays demo" "^Unload level 1: 0 - pages -C" "$($R t/od/Main.bas '~x' t/od/Level1.cls t/od/Level2.cls --platform=cpcfw --library=rom 2>&1)"
cp $P/memmap.bas t/ex/; check "ROM: memmap" "^128K, 5 pages: main + 1 banks" "$($R t/ex/memmap.bas '~x~x' --platform=cpcfw --library=rom 2>&1)"
printf 'Print "x"\n' > t/nr.bas
check "ROM: not fitted" "^ROM NTC CPCFW (NTCFW.ROM) not found" "$(NTC_XROM=  $R t/nr.bas 'x' --platform=cpcfw --library=rom 2>&1)"
printf 'Option Library ROM\nPrint "x"\n' > t/nr2.bas
node cli.js t/nr2.bas --platform=cpcfw 2>/dev/null | grep -q "^ntc_rj_block:" && node cli.js t/nr2.bas --platform=cpm 2>&1 >/dev/null | grep -q "no keyword library ROM for cpm" && echo "ok   ROM: Option Library ROM (cpcfw; refused on cpm)" || { echo "FAIL ROM: Option Library ROM"; fail=1; }
# Graphics in a Library: ROM program (the Graphics code is in the program, @ramonly, with the ROM
# off around its screen work); the sums of #C000 read the ROM there, so only the #4000 ones count
for pl in cpc cpcmin; do
  cp gfx/lines.bas t/; o=$($R t/lines.bas '' --platform=$pl --library=rom 2>&1 | grep -v "^--- " | awk '{sub(/:.*/, ":", $1); print $1, $2, $3}')
  if [ "$o" == "$(awk '{sub(/:.*/, ":", $1); print $1, $2, $3}' ref/gfx_lines.txt)" ]; then echo "ok   ROM: Graphics lines $pl"; else echo "FAIL ROM: Graphics lines $pl"; echo "$o" | head -4; fail=1; fi
done
# keyword ROM sets of more than one ROM: forced with --cap (the @far sections move to ROM 2) and
# --place (4 ROMs, far calls between ROMs 2, 3, 4), the harness fits them in slots 6, 5, 4, 3;
# Memory, List, banks, interrupt classes while far calls run (normal mode), 8 interrupt classes
rm -rf t/romset2 t/romset4
for pl in cpc cpcmin cpcfw; do
  node genrom.js $pl --cap=13000 --out=t/romset2 > /dev/null || { echo "FAIL ROM set: build $pl --cap"; fail=1; }
  node genrom.js $pl --out=t/romset4 --place=ntc_memcore2:1,ntc_mem:2,ntc_memcopy:2,ntc_list:3,ntc_listsort:3 > /dev/null || { echo "FAIL ROM set: build $pl --place"; fail=1; }
done
cp list_t.bas mem_t.bas bank_t.bas t/; rm -rf t/irqfar t/isl2; cp -r irqfar isl2 t/
for d in romset2 romset4; do
  [ -f t/$d/NTCMIN2.ROM ] && [ -f t/$d/NTCFW2.ROM ] && [ -f t/$d/NTCCPC2.ROM ] && echo "ok   ROM set $d: more than one ROM" || { echo "FAIL ROM set $d: one ROM"; fail=1; }
  for m in --turbo ""; do
    for c in "cpc 128 list_cpc" "cpcmin 576 list_cpc"; do
      set -- $c; o=$(NTC_ROMDIR=t/$d timeout 300 python3 ntcrun.py t/list_t.bas '' --library=rom --platform=$1 --ram=$2 $m 2>&1 | grep -v "^--- ")
      if [ "$o" == "$(cat ref/$3.txt)" ]; then echo "ok   ROM set $d: list $1 ${m:-normal}"; else echo "FAIL ROM set $d: list $1 ${m:-normal}"; echo "$o" | head -5; fail=1; fi
    done
    for c in "576 cpc" "128 cpcfw" "128 cpcmin"; do
      set -- $c; o=$(NTC_ROMDIR=t/$d timeout 300 python3 ntcrun.py t/mem_t.bas '' --library=rom --platform=$2 --ram=$1 $m 2>&1 | grep -v "^--- ")
      if [ "$o" == "$(cat ref/mem_$1.txt)" ]; then echo "ok   ROM set $d: memory $1K $2 ${m:-normal}"; else echo "FAIL ROM set $d: memory $1K $2 ${m:-normal}"; echo "$o" | head -5; fail=1; fi
    done
    for pl in cpc cpcmin cpcfw; do
      o=$(NTC_ROMDIR=t/$d timeout 200 python3 ntcrun.py t/bank_t.bas '' --library=rom --platform=$pl --ram=576 $m 2>&1 | grep -v "^--- ")
      if [ "$o" == "$(cat ref/bank_576.txt)" ]; then echo "ok   ROM set $d: banks $pl ${m:-normal}"; else echo "FAIL ROM set $d: banks $pl ${m:-normal}"; echo "$o" | head -5; fail=1; fi
    done
  done
  for pl in cpc cpcmin cpcfw; do
    o=$(NTC_ROMDIR=t/$d timeout 300 python3 ntcrun.py t/irqfar/Main.bas '' t/irqfar/Count.cls --library=rom --platform=$pl --ram=576 2>&1 | grep -v "^--- ")
    if [ "$o" == "$(cat ref/irqfar.txt)" ]; then echo "ok   ROM set $d: interrupts during far calls $pl"; else echo "FAIL ROM set $d: interrupts during far calls $pl"; echo "$o" | head -5; fail=1; fi
    o=$(NTC_ROMDIR=t/$d timeout 200 python3 ntcrun.py t/isl2/Main.bas '' $I2 --library=rom --platform=$pl 2>&1 | grep -v "^--- ")
    if [ "$o" == "$(cat ref/isl2.txt)" ]; then echo "ok   ROM set $d: 8 interrupt classes $pl"; else echo "FAIL ROM set $d: 8 interrupt classes $pl"; echo "$o" | head -5; fail=1; fi
  done
done
mkdir -p t/romset1; cp t/romset2/NTCFW.ROM t/romset1/
check "ROM set: a part missing" "^ROM NTCFW<n>.ROM not found: n = #0002" "$(NTC_ROMDIR=t/romset1 $R t/nr.bas 'x' --platform=cpcfw --library=rom 2>&1)"
# JS flavour (a flavour preprocessor: JS -> VB5 text -> the one parser): a JS program, a VB main
# with a JS class and module, a JS main with a JS class (#asm, Turbo), on the platforms, both modes;
# the translation itself (JS in, VB5 text out); the refused forms (one message each, the JS line)
rm -rf t/jsf; mkdir -p t/jsf; cp jsf/* t/jsf/
for pl in test cpc cpcfw cpm; do for m in --turbo ""; do
  o=$(timeout 100 python3 ntcrun.py t/jsf/demo.js '' --platform=$pl $m 2>&1 | grep -v "^--- ")
  if [ "$o" == "$(cat ref/jsf_demo.txt)" ]; then echo "ok   JS: demo $pl ${m:-normal}"; else echo "FAIL JS: demo $pl ${m:-normal}"; echo "$o" | head -5; fail=1; fi
  o=$(timeout 100 python3 ntcrun.py t/jsf/Mixed.bas '' t/jsf/Counter.js t/jsf/Util.js --platform=$pl $m 2>&1 | grep -v "^--- ")
  if [ "$o" == "$(cat ref/jsf_mixed.txt)" ]; then echo "ok   JS: VB main, JS class $pl ${m:-normal}"; else echo "FAIL JS: VB main, JS class $pl ${m:-normal}"; echo "$o" | head -5; fail=1; fi
  o=$(timeout 100 python3 ntcrun.py t/jsf/m2.js '' t/jsf/Counter.js --platform=$pl $m 2>&1 | grep -v "^--- ")
  if [ "$o" == "$(cat ref/jsf_m2.txt)" ]; then echo "ok   JS: JS main, class, #asm $pl ${m:-normal}"; else echo "FAIL JS: JS main, class, #asm $pl ${m:-normal}"; echo "$o" | head -5; fail=1; fi
done; done
o=$(node cli.js t/jsf/demo.js --platform=test --vb 2>&1)
if [ "$o" == "$(cat ref/jsf_demo_vb.txt)" ]; then echo "ok   JS: translation"; else echo "FAIL JS: translation"; diff <(echo "$o") ref/jsf_demo_vb.txt | head -5; fail=1; fi
o=$( (node cli.js t/jsf/bad.js --platform=test; node cli.js t/jsf/arrow.js --platform=test) 2>&1 >/dev/null | sed 's/^ERR [^:]*:/ERR X:/')
if [ "$o" == "$(cat ref/jsf_bad.txt)" ]; then echo "ok   JS: refused forms"; else echo "FAIL JS: refused forms"; echo "$o" | head -5; fail=1; fi
# Locomotive BASIC flavour (the CPC's BASIC -> VB5 text): a type-in style listing (DATA / READ /
# RESTORE, DEF FN, SWAP, a / a% / a$, MID$ on the left, ON GOSUB, line number targets) on the
# platforms, both modes - with its warnings (the lines NTC can't do are left out); the translation
rm -rf t/loc; mkdir -p t/loc; cp loc/* t/loc/
for pl in test cpc cpcmin cpcfw cpm; do for m in --turbo ""; do
  o=$(timeout 100 python3 ntcrun.py t/loc/classic.loc '' --platform=$pl $m 2>&1 | grep -v "^--- ")
  if [ "$o" == "$(cat ref/loc_classic.txt)" ]; then echo "ok   Locomotive: classic $pl ${m:-normal}"; else echo "FAIL Locomotive: classic $pl ${m:-normal}"; echo "$o" | head -5; fail=1; fi
done; done
# Locomotive files and keys: OPENOUT / PRINT #9 / CLOSEOUT, OPENIN / LINE INPUT #9 / EOF, INKEY(n), JOY(n)
for pl in cpcfw cpcmin; do for m in --turbo ""; do
  rm -rf t/files
  o=$(timeout 100 python3 ntcrun.py t/loc/files.loc '{47}~~{76}' --platform=$pl $m 2>&1 | grep -v "^--- ")
  if [ "$o" == "$(cat ref/loc_files.txt)" ]; then echo "ok   Locomotive: files and keys $pl ${m:-normal}"; else echo "FAIL Locomotive: files and keys $pl ${m:-normal}"; echo "$o" | head -5; fail=1; fi
done; done
o=$(node cli.js t/loc/classic.loc --platform=test --vb 2>/dev/null)
if [ "$o" == "$(cat ref/loc_classic_vb.txt)" ]; then echo "ok   Locomotive: translation"; else echo "FAIL Locomotive: translation"; diff <(echo "$o") ref/loc_classic_vb.txt | head -5; fail=1; fi
# ROMDISC (volume R: read-only files in ROMs, made by ntcRomDisc / genromdisc.js, here 2 ROMs with
# a file across them, in slots 10, 11): directory, Load, Open / ReadLine / Read / Eof, Exists, Size;
# cpc (its only volume), cpcmin, cpcfw, both modes, Library: ROM; beside AMSDOS (cpcmin, cpcfw: drive
# A and R, a disc file and a ROM file open at once); a part of the disc missing: no disc
rm -rf t/rddisc t/rdhalf; node genromdisc.js t/rddisc rd/HELLO.TXT rd/BIG.BIN rd/SMALL.DAT > /dev/null
[ -f t/rddisc/NTCDISC2.ROM ] && echo "ok   ROMDISC: two ROMs" || { echo "FAIL ROMDISC: two ROMs"; fail=1; }
cp rd/rd_t.bas rd/rd_m.bas t/
for pl in cpc cpcmin cpcfw; do for m in --turbo "" "--library=rom"; do
  o=$(NTC_ROMDISC=t/rddisc/NTCDISC.ROM timeout 120 python3 ntcrun.py t/rd_t.bas '' --platform=$pl $m 2>&1 | grep -v "^--- ")
  if [ "$o" == "$(cat ref/romdisc.txt)" ]; then echo "ok   ROMDISC $pl ${m:-normal}"; else echo "FAIL ROMDISC $pl ${m:-normal}"; echo "$o" | head -5; fail=1; fi
done; done
for pl in cpcmin cpcfw; do for m in "" "--library=rom"; do
  rm -rf t/files; o=$(NTC_ROMDISC=t/rddisc/NTCDISC.ROM timeout 120 python3 ntcrun.py t/rd_m.bas '' --platform=$pl $m 2>&1 | grep -v "^--- ")
  if [ "$o" == "$(cat ref/romdisc_m.txt)" ]; then echo "ok   ROMDISC beside AMSDOS $pl ${m:-normal}"; else echo "FAIL ROMDISC beside AMSDOS $pl ${m:-normal}"; echo "$o" | head -5; fail=1; fi
done; done
mkdir -p t/rdhalf; cp t/rddisc/NTCDISC.ROM t/rdhalf/
check "ROMDISC: a part missing" "^select R -2" "$(NTC_ROMDISC=t/rdhalf/NTCDISC.ROM timeout 120 python3 ntcrun.py t/rd_t.bas '' --platform=cpc 2>&1)"
# Option PressAnyKeyOnEnd "message": at End (here in a Sub), Error and the last line, the message
# and a key; without a key it waits (not halted)
printf 'Option PressAnyKeyOnEnd "Done - press a key"\nPrint "a";\nQuit\nPrint "b"\nSub Quit()\n  End\nEnd Sub\n' > t/pak1.bas
printf 'Option PressAnyKeyOnEnd\nPrint "c"\n' > t/pak2.bas
printf 'Option PressAnyKeyOnEnd "Oops - a key"\nError "bad"\n' > t/pak3.bas
for pl in test cpc cpcfw cpm; do
  check "PressAnyKeyOnEnd End in a Sub $pl" "^Done - press a key" "$(timeout 60 python3 ntcrun.py t/pak1.bas 'x' --platform=$pl 2>&1)"
  check "PressAnyKeyOnEnd last line $pl" "^Press any key" "$(timeout 60 python3 ntcrun.py t/pak2.bas 'x' --platform=$pl 2>&1)"
  check "PressAnyKeyOnEnd Error $pl" "^Oops - a key" "$(timeout 60 python3 ntcrun.py t/pak3.bas 'x' --platform=$pl 2>&1)"
done
o=$(NTC_NOENDKEY=1 timeout 60 python3 ntcrun.py t/pak1.bas '' --platform=cpm 2>&1)
echo "$o" | grep -q "^--- NOT halted" && ! echo "$o" | grep -q "^b" && echo "ok   PressAnyKeyOnEnd waits for the key" || { echo "FAIL PressAnyKeyOnEnd waits for the key"; fail=1; }
check "PressAnyKeyOnEnd ROM cpcfw" "^Done - press a key" "$(timeout 60 python3 ntcrun.py t/pak1.bas 'x' --platform=cpcfw --library=rom 2>&1)"
# Option NoTurbo: one copy of everything (normal mode), Turbo On / Off do nothing; still runs
(echo "Option NoTurbo"; cat $P/shellsort.bas) > t/ssn.bas; cp $P/shellsort.bas t/ss.bas
node cli.js t/ss.bas > t/ss.asm 2>/dev/null; node cli.js t/ssn.bas > t/ssn.asm 2> t/ssn.err
if [ $(grep -c "^p_shellsort" t/ssn.asm) -lt $(grep -c "^p_shellsort" t/ss.asm) ] && grep -q "Turbo On does nothing" t/ssn.err; then echo "ok   Option NoTurbo one copy"; else echo "FAIL Option NoTurbo one copy"; fail=1; fi
check "Option NoTurbo runs" "^6 8 9 26 26 31 34 34 34 35" "$(timeout 100 python3 cpcrun.py t/ssn.bas '300\ntnx' 2>&1)"
# List class: linked lists in the heap (D pages, or Small's main RAM); both modes
for m in --turbo ""; do
  for c in "cpc 128 list_cpc" "cpcmin 576 list_cpc" "cpc 64 list_64" "cpm 128 list_cpm" "test 128 list_test"; do
    set -- $c; cp list_t.bas t/
    o=$(timeout 300 python3 ntcrun.py t/list_t.bas '' --platform=$1 --ram=$2 $m 2>&1 | grep -v "^--- ")
    if [ "$o" == "$(cat ref/$3.txt)" ]; then echo "ok   list $1 ${2}K ${m:-normal}"; else echo "FAIL list $1 ${2}K ${m:-normal}"; echo "$o" | head -5; fail=1; fi
  done
done
cp $P/lists.bas t/ex/
for pl in cpc cpcfw cpm test; do check "lists demo $pl" "^235 players with 5000 or more" "$(timeout 300 python3 ntcrun.py t/ex/lists.bas '~x' --platform=$pl 2>&1)"; done
# Function calls inside expressions: the caller's temps survive (both modes, cpc and cpm)
for m in --turbo ""; do for pl in test cpm; do
  cp temps.bas t/; o=$(timeout 60 python3 ntcrun.py t/temps.bas '' --platform=$pl $m 2>&1 | grep -v "^--- ")
  if [ "$o" == "$(cat ref/temps.txt)" ]; then echo "ok   temps across calls $pl ${m:-normal}"; else echo "FAIL temps across calls $pl ${m:-normal}"; echo "$o" | head -5; fail=1; fi
done; done
# System.HasCapability / CommandLine: CP/M has the command tail (kept over a disc call), the CPC asks
cp $P/cmdline.bas t/ex/
check "command line cpm" "^3 words" "$(timeout 60 python3 ntcrun.py t/ex/cmdline.bas '' --platform=cpm --cmdline='hello there  world' 2>&1)"
check "command line cpc asks" "^2 words" "$(timeout 60 python3 ntcrun.py t/ex/cmdline.bas 'a bb\n' --platform=cpc 2>&1)"
printf 'Dim cl As String\ncl = System.CommandLine\nPrint FileSystem.Exists("NONE.TXT"); "["; cl; "]"; System.HasCapability("files"); System.HasCapability("x")\n' > t/cl2.bas
check "command line after a disc call" "^0\[FILE.TXT\]-10" "$(timeout 60 python3 ntcrun.py t/cl2.bas '' --platform=cpm --cmdline='file.txt' 2>&1)"
# the tutorial's examples compile, and print what the pages say
o=$(timeout 900 python3 tutcheck.py 2>&1); if [ $? -eq 0 ]; then echo "ok   tutorial examples ($(echo "$o" | tail -1))"; else echo "FAIL tutorial examples"; echo "$o" | tail -12; fail=1; fi
# interrupt classes at the real CPC's speed (cpctime.py): no interrupts lost while text is drawn
# (it held them off: 1 tick in 4 got through), and the frame class runs 50 times a second
rm -rf t/ir; mkdir -p t/ir; cp $P/interrupts/*.cls t/ir/; sed 's/^Loop Until Inkey <> 0/Loop Until Ticks >= 600/' $P/interrupts/Main.bas > t/ir/Main.bas
o=$(timeout 600 python3 cpctime.py t/ir/Main.bas '' t/ir/Clock.cls t/ir/Star.cls --platform=cpcmin 2>&1)
st=$(echo "$o" | sed -n 's/^Clock ticked 2 times, the star \([0-9]*\).*/\1/p'); tm=$(echo "$o" | sed -n 's/.*CPC time \([0-9.]*\) s/\1/p')
if [ -n "$st" ] && [ "$st" -ge 85 ] && awk "BEGIN { exit !($tm < 2.1) }"; then echo "ok   interrupt classes on time (star $st in ${tm}s)"; else echo "FAIL interrupt classes on time"; echo "$o" | tail -3; fail=1; fi
# Vector3D (bas/cube3d): turns and perspective to known pixels; the demo runs on cpc and, with
# Spin as an overlay class in a RAM page, on cpcmin
cp v3d/proj.bas t/; o=$(timeout 60 python3 ntcrun.py t/proj.bas '' $P/cube3d/Vector3D.cls --platform=cpc 2>&1 | grep -v "^--- ")
if [ "$o" == "$(cat ref/v3d.txt)" ]; then echo "ok   Vector3D projection"; else echo "FAIL Vector3D projection"; echo "$o" | head -4; fail=1; fi
rm -rf t/c3 t/files; mkdir -p t/c3; cp $P/cube3d/* t/c3/
for pl in cpc cpcmin; do check "cube3d demo $pl" "^Bye" "$(timeout 300 python3 ntcrun.py t/c3/Main.bas '3~~~D~~~A~~~C~~~T~~~4~~~X' t/c3/Vector3D.cls t/c3/Spin.cls --platform=$pl 2>&1)"; done
# cpm (an Amstrad CPC): CP/M 2.2 draws on #C000, CP/M Plus on block 1 from its copy in common
# memory (C1 / C2); the shape off again at the end: no screen byte left set
for v in 22 31; do o=$(NTC_CPMVER=$v NTC_GFXCHK=1 timeout 300 python3 ntcrun.py t/c3/Main.bas '3~~~D~~~A~~~C~~~T~~~4~~~X' t/c3/Vector3D.cls t/c3/Spin.cls --platform=cpm 2>&1)
  check "cube3d demo cpm $v" "^Bye" "$o"; check "cube3d demo cpm $v screen clean" "screen bytes set: 0$" "$o"; done
# CITY3D (bas/city3d): a few frames on cpcfw with the keys held (turn, climb, roll), then Q
rm -rf t/city; mkdir -p t/city; cp $P/city3d/* t/city/
check "city3d demo cpcfw" "^Bye" "$(timeout 300 python3 ntcrun.py t/city/Main.bas " {8}{8}{63}{63}{31}{31}~~~~{67}" t/city/City.cls --platform=cpcfw 2>&1)"
# AUCKLAND (bas/auckland, tools/s3dmake): a made-up town (s3d/mkcut.py) through the converter
# (s3d/make.js runs s3dmake.html's code), then the demo reads it (4MB) and flies a few frames: view
# 2, a pause (P, P), then Q - the frames and the most lines drawn in one
python3 s3d/mkcut.py t/syn.txt.gz && node s3d/make.js ../../tools/s3dmake/s3dmake.html t/syn.txt.gz t/SYN.DAT TESTTOWN > t/syn.log 2>&1
check "s3dmake test town" "576 buildings" "$(cat t/syn.log)
--- halted"
# made smaller ("At most" 22K): minor roads, then small buildings, then trees go (the 1MB Next's 528K)
check "s3dmake fitted: trees last" "to fit: 6 minor road pieces, 109 small buildings and 81 trees left out" "$(node s3d/make.js ../../tools/s3dmake/s3dmake.html t/syn.txt.gz t/SYN2.DAT TESTTOWN 22 2>&1)
--- halted"
# a start of one's own: a street's name (s3dmake's "Start at")
check "s3dmake start at a street" "start: Test Street (its end at 0, 900)" "$(node s3d/make.js ../../tools/s3dmake/s3dmake.html t/syn.txt.gz t/SYN3.DAT TESTTOWN 3968 'test street' 2>&1)
--- halted"
# an area of its own (s3dmake's "Only the area round"): a 1 km square round Test Hill, every detail
check "s3dmake area" "world 1.2 x 1.2 km: 3 x 3 tiles" "$(node s3d/make.js ../../tools/s3dmake/s3dmake.html t/syn.txt.gz t/SYN4.DAT TESTTOWN 3968 '' 'test hill' 1 2>&1)
--- halted"
rm -rf t/akm t/s3df; mkdir -p t/akm t/s3df/A; cp $P/auckland/* t/akm/; cp t/SYN.DAT t/s3df/A/AUCKLAND.DAT
o=$(NTC_FILES=$PWD/t/s3df NTC_AMSDOS=1 timeout 300 python3 ntcrun.py t/akm/Main.bas " ~~~~~~~~~~~~~~~~~~~~~~~~2~~~~~~~~~~~~p~~~~~~~~p~~~~~~~~~~~~{67}{67}{67}" t/akm/S3d.cls --platform=cpcfw --ram=4160 2>&1)
check "auckland demo cpcfw" "^Bye - [3-9][0-9]* frames, up to [1-9][0-9][0-9][0-9]* lines" "$o"
# the same on the ZX Spectrum Next (zxn): the town's 2 blocks in the NEX file (Option NexData), Layer 2,
# Q held at the end ({16*}); a picture of view 2 with lines on it
rm -rf t/akn; mkdir -p t/akn; cp $P/auckland/Main.bas $P/auckland/S3d.cls t/akn/; cp t/SYN.DAT t/akn/AUCKLAND.DAT
sed -i 's/^Option NexData "AUCKLAND.DAT", 94/Option NexData "AUCKLAND.DAT", 2/' t/akn/Main.bas
o=$(NTC_LIMIT=40000 timeout 600 python3 ntcrun.py t/akn/Main.bas " ~~~~~~~~~~~~~~~~~~~~~~~~2~~~~~~~~~~~~p~~~~~~~~p~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{16*}" t/akn/S3d.cls --platform=zxn 2>&1)
check "auckland demo zxn" "^Bye - [3-9][0-9]* frames, up to [1-9][0-9][0-9][0-9]* lines" "$o"
# the ternary back-face test's copy (bas/auckland_tern): the same flight, walls facing away left out
rm -rf t/akt; mkdir -p t/akt; cp $P/auckland_tern/Main.bas $P/auckland_tern/S3d.cls t/akt/; cp t/SYN.DAT t/akt/AUCKLAND.DAT
sed -i 's/^Option NexData "AUCKLAND.DAT", 94/Option NexData "AUCKLAND.DAT", 2/' t/akt/Main.bas
o=$(NTC_PEEK=w_cull NTC_LIMIT=40000 timeout 600 python3 ntcrun.py t/akt/Main.bas " ~~~~~~~~~~~~~~~~~~~~~~~~2~~~~~~~~~~~~p~~~~~~~~p~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{16*}" t/akt/S3d.cls --platform=zxn 2>&1)
if echo "$o" | grep -qE "^Bye - [3-9][0-9]* frames" && echo "$o" | grep -qE "^--- peek w_cull = [1-9][0-9]*"; then echo "ok   auckland_tern zxn: walls left out"; else echo "FAIL auckland_tern zxn"; echo "$o" | tail -5; fail=1; fi
# the blocks' copy (bas/auckland_block, the Next): the buildings as solid blocks over a floating
# horizon, nearest first - the same flight; Layer 2 well covered (the blocks' fills)
rm -rf t/akb; mkdir -p t/akb; cp $P/auckland_block/Main.bas $P/auckland_block/S3d.cls t/akb/; cp t/SYN.DAT t/akb/AUCKLAND.DAT
sed -i 's/^Option NexData "AUCKLAND.DAT", 94/Option NexData "AUCKLAND.DAT", 2/' t/akb/Main.bas
o=$(NTC_LIMIT=40000 timeout 600 python3 ntcrun.py t/akb/Main.bas " ~~~~~~~~~~~~~~~~~~~~~~~~2~~~~~~~~~~~~p~~~~~~~~p~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{16*}" t/akb/S3d.cls --platform=zxn 2>&1)
o2=$(NTC_SHOT=t/akb/s.png NTC_LIMIT=6000 timeout 600 python3 ntcrun.py t/akb/Main.bas " ~~~~~~~~~~~~2" t/akb/S3d.cls --platform=zxn 2>&1)
if echo "$o" | grep -qE "^Bye - [3-9][0-9]* frames" && echo "$o2" | grep -qE "^--- layer 2: [1-9][0-9]{3,} pixels set"; then echo "ok   auckland_block zxn: blocks"; else echo "FAIL auckland_block zxn"; echo "$o" | tail -4; echo "$o2" | tail -3; fail=1; fi
# the wall masks' copy (bas/auckland_mask): S3D2 data (s3dmake's masks: a byte a wall, the directions
# it is seen from); the same flight, walls facing away left out, and the original refuses S3D2
node s3d/make.js ../../tools/s3dmake/s3dmake.html t/syn.txt.gz t/SYN2M.DAT TESTTOWN 3968 '' '' 3 masks > /dev/null 2>&1
rm -rf t/akk; mkdir -p t/akk; cp $P/auckland_mask/Main.bas $P/auckland_mask/S3d.cls t/akk/; cp t/SYN2M.DAT t/akk/AUCKLAND.DAT
sed -i 's/^Option NexData "AUCKLAND.DAT", 94/Option NexData "AUCKLAND.DAT", 2/' t/akk/Main.bas
o=$(NTC_PEEK=w_cull NTC_LIMIT=40000 timeout 600 python3 ntcrun.py t/akk/Main.bas " ~~~~~~~~~~~~~~~~~~~~~~~~2~~~~~~~~~~~~p~~~~~~~~p~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~{16*}" t/akk/S3d.cls --platform=zxn 2>&1)
rm -rf t/akr; mkdir -p t/akr; cp t/akn/Main.bas t/akn/S3d.cls t/akr/; cp t/SYN2M.DAT t/akr/AUCKLAND.DAT
o2=$(NTC_LIMIT=8000 timeout 600 python3 ntcrun.py t/akr/Main.bas " ~~" t/akr/S3d.cls --platform=zxn 2>&1)
if echo "$o" | grep -qE "^Bye - [3-9][0-9]* frames" && echo "$o" | grep -qE "^--- peek w_cull = [1-9][0-9]*" && echo "$o2" | grep -q "not S3D data"; then echo "ok   auckland_mask zxn: wall masks (S3D2)"; else echo "FAIL auckland_mask zxn"; echo "$o" | tail -5; echo "$o2" | tail -3; fail=1; fi
o=$(NTC_SHOT=t/akn/s.png NTC_LIMIT=6000 timeout 600 python3 ntcrun.py t/akn/Main.bas " ~~~~~~~~~~~~2" t/akn/S3d.cls --platform=zxn 2>&1)
echo "$o" | grep -qE "^--- layer 2: [1-9][0-9]{3,} pixels set" && echo "$o" | grep -q "^SPEED [0-9]*M  HEIGHT 150M  FPS" && echo "ok   auckland zxn: Layer 2 drawn" || { echo "FAIL auckland zxn: Layer 2 drawn"; echo "$o" | tail -4; fail=1; }
# AUCKLINK (tools/s3dpi, bas/aucklink): the coprocessor's engine in C - the link simulated (packets,
# the status block, the lists in the card's ROM) on the made-up town; then the CPC side, with no
# card, draws the list sim wrote (FRAME.LST)
gcc -O2 -o t/s3dsim ../../tools/s3dpi/sim.c ../../tools/s3dpi/card.c ../../tools/s3dpi/s3dpi.c 2> t/s3dsim.err
o=$(t/s3dsim t/SYN.DAT 1 3 t/syn 2>&1; echo "--- halted")
check "s3dpi: the link simulated" "^frame 2: seq 3, list 1, [1-9][0-9]* lines" "$o"
rm -rf t/alk; mkdir -p t/alk/A; cp $P/aucklink/* t/alk/; cp t/syn.LST t/alk/A/FRAME.LST
o=$(NTC_LIMIT=4000 NTC_FILES=$PWD/t/alk NTC_AMSDOS=1 NTC_GFXCHK=1 timeout 300 python3 ntcrun.py t/alk/Main.bas "" t/alk/Link.cls --platform=cpcfw 2>&1)
check "aucklink: a card's list drawn (no card)" "drawing FRAME.LST" "$(echo "$o"; echo '--- halted')"
# Option Reserve builds round the range: a program too big for #0040-#3FFF goes on above #8000
cp hole.bas t/
for pl in cpc cpcmin cpcfw; do check "Option Reserve round the hole $pl" "^a3 7 big at .* end [89]" "$(timeout 60 python3 ntcrun.py t/hole.bas '' --platform=$pl 2>&1)"; done
# Rnd(variable), Randomize variable: their keywords on their own (they share Rnd(literal)'s and Randomize literal's code)
cp rndv_t.bas t/
for pl in cpm cpcfw; do
  o=$(timeout 100 python3 ntcrun.py t/rndv_t.bas '' --platform=$pl 2>&1 | grep -v "^--- " | tr '\n' ' ')
  if [ "$o" == "rnd-1-1 " ]; then echo "ok   Rnd, Randomize with variables $pl"; else echo "FAIL Rnd, Randomize with variables $pl: $o"; fail=1; fi
done
# FileSystem ForReadRaw: a headerless file read to its last record, #1A bytes kept; Eof reads ahead
for pl in cpcfw cpcmin; do
  rm -rf t/files; mkdir -p t/files/A; cp raw_t.bas t/
  python3 -c "d = bytearray((i * 7 + 1) & 0x7F for i in range(300)); d[10] = 0x1A; d[200] = 0x1A; d[299] = 0x55; open('t/files/A/RAW.COM', 'wb').write(d)"
  o=$(timeout 120 python3 ntcrun.py t/raw_t.bas '' --platform=$pl 2>&1 | grep -v "^--- " | tr '\n' ' ')
  if echo "$o" | grep -q "text10 raw38426782685 eof384-1"; then echo "ok   FileSystem ForReadRaw $pl"; else echo "FAIL FileSystem ForReadRaw $pl: $o"; fail=1; fi
done
# CyborgOS (bas/cyborgos): CP/M programs (.CYB: a cpm build with an AMSDOS header) in 64K banks
# under the hypervisor (cpcfw): CRUNCH (stopped only by interrupts) in slot 2, TICKER (a BDOS
# call a loop) in slot 3 brought to the front and ended with a key, WAIT for CRUNCH, QUIT. 576K:
# 4 slots; 128K (a 6128): 1 slot, the two in turn
rm -rf t/cy t/files; mkdir -p t/cy t/files/A; cp $P/cyborgos320kb/*.bas $P/cyborgos320kb/*.cls t/cy/
for g in TICKER CRUNCH; do
  node cli.js $P/cyborgos320kb/tasks/$g.bas --platform=cpm > t/cy/$g.asm 2>/dev/null
  (cd t/cy && ${SJASMPLUS:-sjasmplus} --nologo --msg=err --raw=$g.COM $g.asm > /dev/null)
  python3 -c "import ntcrun; d = open('t/cy/$g.COM', 'rb').read(); open('t/files/A/$g.CYB', 'wb').write(ntcrun.amsdos_header(d, 0x100) + d)"
done
node cli.js str9.bas --platform=cpm > t/cy/STR9.asm 2>/dev/null
(cd t/cy && ${SJASMPLUS:-sjasmplus} --nologo --msg=err --raw=STR9.COM STR9.asm > /dev/null)
python3 -c "import ntcrun; d = open('t/cy/STR9.COM', 'rb').read(); open('t/files/A/STR9.CYB', 'wb').write(ntcrun.amsdos_header(d, 0x100) + d)"
node cli.js $P/cyborgos320kb/tasks/LINES.bas --platform=cpm > t/cy/LINES.asm 2>/dev/null
(cd t/cy && ${SJASMPLUS:-sjasmplus} --nologo --msg=err --raw=LINES.COM LINES.asm > /dev/null)
python3 -c "import ntcrun; d = open('t/cy/LINES.COM', 'rb').read(); open('t/files/A/LINES.CYB', 'wb').write(ntcrun.amsdos_header(d, 0x100) + d)"
# the commands (cmds: PS, MEM, DIR, CD, COPY ... - .CYB programs, run by their names; CyborgOS
# starts by running RAMDISC Z SYSTEM, which finds no CYBORGOS.Z here: the commands come from A)
mkdir -p t/cmd; cp $P/cyborgos320kb/cmds/* t/cmd/
CYBCMDS="COPY ERA TYPE RENAME HELP RAMDISC DIR CD CV MKDIR RMDIR DRIVE FLOPPY PS KILL RESET FG WAIT TOP MEM MODE CLAIMS NET"
for g in $CYBCMDS; do
  case $g in PS|KILL|RESET|FG|WAIT|TOP|MEM|MODE|CLAIMS) c=t/cmd/CybSys.cls;; NET) c="t/cmd/Http.cls t/cmd/CybSys.cls";; CD|CV) c=t/cmd/CybVol.cls;; RAMDISC|HELP|MKDIR|RMDIR|DRIVE|TYPE|RENAME) c="";; *) c=t/cmd/CybDir.cls;; esac
  node cli.js t/cmd/$g.bas $c --platform=cpm > t/cmd/$g.asm 2>/dev/null
  (cd t/cmd && ${SJASMPLUS:-sjasmplus} --nologo --msg=err --raw=$g.COM $g.asm > /dev/null)
  python3 -c "import ntcrun; d = open('t/cmd/$g.COM', 'rb').read(); open('t/files/A/$g.CYB', 'wb').write(ntcrun.amsdos_header(d, 0x100) + d)"
done
W=$(printf '~%.0s' $(seq 1 40))
# 200 lines: the page and the screen scroll (written straight into screen memory), all of them shown
o=$(timeout 300 python3 ntcrun.py t/cy/Main.bas "run LINES\n~~~~~~~~~~" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
if echo "$o" | grep -q "^line199 the quick" && echo "$o" | grep -q "^line200 the quick" && echo "$o" | grep -q "^lines done"; then echo "ok   CyborgOS 200 lines scroll"; else echo "FAIL CyborgOS 200 lines scroll"; echo "$o" | tail -5; fail=1; fi
# BDOS 9: a "$" string over 128 bytes (fetched with Memory.Copy in pieces), the screen left showing
o=$(timeout 300 python3 ntcrun.py t/cy/Main.bas "run STR9\n${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
if echo "$o" | grep -q "^s9 tail ok"; then echo "ok   CyborgOS BDOS 9 string"; else echo "FAIL CyborgOS BDOS 9 string"; echo "$o" | tail -5; fail=1; fi
# CP/M calls (cpm/cpmt.asm): the default FCBs from the tail, TAB, the BIOS's CONOUT, BDOS 12, 24, 35,
# 36, 17 / 18 (UniDOS's listing: NTC_UNIDOS), 10 (a line, DEL rubbing out), 1; the Library: ROM build too
${SJASMPLUS:-sjasmplus} --nologo --msg=err --raw=t/cy/CPMT.COM cpm/cpmt.asm
python3 -c "
import ntcrun
d = open('t/cy/CPMT.COM', 'rb').read(); open('t/files/A/CPMT.CYB', 'wb').write(ntcrun.amsdos_header(d, 0x100) + d)
open('t/files/A/README.TXT', 'wb').write(b'line one\r\nline two\r\n'); open('t/files/A/NOTES.TXT', 'wb').write(b'n' * 300)"
for lib in ram rom; do
  o=$(NTC_UNIDOS=IDE timeout 600 python3 ntcrun.py t/cy/Main.bas "run cpmt readme.txt b:*.dat\n${W}helx\\x7flo\n${W}q${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 --library=$lib 2>&1)
  r=ok; for x in "F1=0README  TXT F2=2????????DAT" "T>      <XY" "V=22 L=01" "S=00 01" "R=01" "D=README  TXT 01" "D=NOTES   TXT 03" "got>hello<" "key? q k=71" "[CPMT.CYB ended]"; do echo "$o" | grep -qF "$x" || r="no: $x"; done
  if [ "$r" == ok ]; then echo "ok   CyborgOS CP/M calls ($lib)"; else echo "FAIL CyborgOS CP/M calls ($lib) $r"; echo "$o" | tail -14; fail=1; fi
done
rm -f t/files/A/CPMT.CYB t/files/A/README.TXT t/files/A/NOTES.TXT
# BBC BASIC's files (cpm/bbct.asm): made at one FCB, written and closed through the program's copy
# of it (its channel's), random write with zero fill (40); opened, read through a copy. Twice: the
# second run's copies at the first's addresses (no old file's FCB in the way)
${SJASMPLUS:-sjasmplus} --nologo --msg=err --raw=t/cy/BBCT.COM cpm/bbct.asm
python3 -c "
import ntcrun
d = open('t/cy/BBCT.COM', 'rb').read(); open('t/files/A/BBCT.CYB', 'wb').write(ntcrun.amsdos_header(d, 0x100) + d)"
o=$(NTC_UNIDOS=IDE timeout 600 python3 ntcrun.py t/cy/Main.bas "bbct\n${W}bbct\n${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
if [ "$(echo "$o" | grep -cF "C=00/00 00/00 01/00 00/00 00/00 00/00 00/00 00/00")" == 2 ] && [ "$(echo "$o" | grep -c "^R=SECND")" == 2 ]; then echo "ok   CyborgOS BBC BASIC's files (a copied FCB)"; else echo "FAIL CyborgOS BBC BASIC's files (a copied FCB)"; echo "$o" | tail -6; fail=1; fi
rm -f t/files/A/BBCT.CYB t/files/A/T.BBC
# the console's VT52 (cpm/vt52t.asm - what editors such as VDE send): ESC K (to the end of the
# row), M (a row deleted), L (one put in), A and C (up, right), J (to the end of the page)
${SJASMPLUS:-sjasmplus} --nologo --msg=err --raw=t/cy/VT.COM cpm/vt52t.asm
python3 -c "
import ntcrun
d = open('t/cy/VT.COM', 'rb').read(); open('t/files/A/VT.CYB', 'wb').write(ntcrun.amsdos_header(d, 0x100) + d)"
o=$(NTC_LIMIT=30000 timeout 1500 python3 ntcrun.py t/cy/Main.bas "vt\n${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
if echo "$o" | grep -A6 "^ \{80\}\[1\]$" | tr '\n' '|' | grep -qF "AA    X|CCCCCCCC|D|||vt52 done|"; then echo "ok   CyborgOS console VT52 (K J L M A C)"; else echo "FAIL CyborgOS console VT52"; echo "$o" | tail -12; fail=1; fi
rm -f t/files/A/VT.CYB
# 4MB: 20 slots; Control + 3 twice (Control held) is slot 13, Control + 0 once is slot 10
o=$(timeout 300 python3 ntcrun.py t/cy/Main.bas "run 12 CRUNCH\n~~~~~~~~~~{23,57}{23}{23,57}~~~~~~~~~~ps\n~~~~~~~~~~" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=4160 2>&1)
if echo "$o" | grep -q "^13> ps" && echo "$o" | grep -q "^ 13 \* PS.CYB" && echo "$o" | grep -q "^ 12   CRUNCH.CYB"; then echo "ok   CyborgOS 20 slots, Control + a number twice"; else echo "FAIL CyborgOS 20 slots, Control + a number twice"; echo "$o" | tail -5; fail=1; fi
o=$(timeout 300 python3 ntcrun.py t/cy/Main.bas "~~~~~~~~~~{23,32}${W}${W}ps\n~~~~~~~~~~" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=4160 2>&1)
if echo "$o" | grep -q "^10> ps" && echo "$o" | grep -q "^ 10 \* PS.CYB"; then echo "ok   CyborgOS 20 slots, Control + 0 once"; else echo "FAIL CyborgOS 20 slots, Control + 0 once"; echo "$o" | tail -5; fail=1; fi
# RESET: slot 2's program stopped and the slot closed; RESET on its own: this slot as new
o=$(timeout 300 python3 ntcrun.py t/cy/Main.bas "run 2 CRUNCH\n${W}reset 2\nps\n${W}reset\n${W}ps\n${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
if echo "$o" | grep -q "^  2   -" && [ "$(echo "$o" | grep -c "^CyborgOS slot 1 of 4")" == 1 ] && ! echo "$o" | grep -q "reset 2"; then echo "ok   CyborgOS RESET"; else echo "FAIL CyborgOS RESET"; echo "$o" | tail -5; fail=1; fi
# CLAIMS: CLAIMT in slot 2 claims SOUND 0 (PS shows it), slot 3's claim refused, CLAIMS TAKE takes
# it back (slot 2 sees it lost); then claimed again in slot 2, KILL 2 frees it
node cli.js $P/cyborgos320kb/tasks/CLAIMT.bas t/cmd/CybSys.cls --platform=cpm > t/cy/CLAIMT.asm 2>/dev/null
(cd t/cy && ${SJASMPLUS:-sjasmplus} --nologo --msg=err --raw=CLAIMT.COM CLAIMT.asm > /dev/null)
python3 -c "import ntcrun; d = open('t/cy/CLAIMT.COM', 'rb').read(); open('t/files/A/CLAIMT.CYB', 'wb').write(ntcrun.amsdos_header(d, 0x100) + d)"
o=$(timeout 300 python3 ntcrun.py t/cy/Main.bas "run 2 CLAIMT\n${W}claims\n${W}claims take sound\n${W}claims\n${W}run 2 CLAIMT\n${W}kill 2\n${W}claims\n${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
o2=$(timeout 300 python3 ntcrun.py t/cy/Main.bas "run 2 CLAIMT\n${W}run 3 CLAIMT\n${W}fg 3\n${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
o3=$(timeout 300 python3 ntcrun.py t/cy/Main.bas "run 2 CLAIMT\n${W}claims take sound 0\n${W}fg 2\n${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
o4=$(timeout 300 python3 ntcrun.py t/cy/Main.bas "run 2 CLAIMT\n${W}ps\n${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
if echo "$o" | grep -qE "^SOUND +0 +2  CLAIMT.CYB" && echo "$o4" | grep -q "^  2   CLAIMT.CYB  \[SOUND 0\]" && echo "$o" | grep -q "^SOUND 0 taken from slot 2" \
  && [ "$(echo "$o" | grep -c "^No claims")" == 2 ] && echo "$o2" | grep -q "^SOUND 0 busy: slot 2" && echo "$o3" | grep -qE "^SOUND 0 lost to slot (1|254)$"; then echo "ok   CyborgOS CLAIMS: claim, refused, take, freed by KILL"; else echo "FAIL CyborgOS CLAIMS"; echo "$o" | tail -30; echo "$o2" | tail -6; echo "$o3" | tail -6; echo "$o4" | tail -6; fail=1; fi
rm -f t/files/A/CLAIMT.CYB
# the ports and the rat (apps/rat): MODEL RATMODEL in slot 2 (the port RATMODEL), RAT in slot 3 (the
# port RAT), RATS asking RAT 20 times in slot 4: R first (tv or play), a necessity low (food or bed
# below 25) over it, the habit saved (MODEL: every 10 picks, L up a point each); RATS without RAT,
# RAT without the model
mkdir -p t/rat
for g in MODEL RAT RATS NEURAL ASK WATCH PET PROBE GREEN; do
  node cli.js $P/cyborgos320kb/apps/rat/$g.bas t/cmd/CybSys.cls --platform=cpm > t/rat/$g.asm 2>/dev/null
  (cd t/rat && ${SJASMPLUS:-sjasmplus} --nologo --msg=err --raw=$g.COM $g.asm > /dev/null)
  python3 -c "import ntcrun; d = open('t/rat/$g.COM', 'rb').read(); open('t/files/A/$g.CYB', 'wb').write(ntcrun.amsdos_header(d, 0x100) + d)"
done
cp $P/cyborgos320kb/apps/rat/RATMODEL.MDL t/files/A/
W8=$(for i in $(seq 1 150); do printf '%s' "$W"; done)
o=$(NTC_LIMIT=300000 timeout 900 python3 ntcrun.py t/cy/Main.bas "run 2 model ratmodel\n${W}run 3 rat\n${W}run 4 rats 20\n${W8}fg 3\n${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
lsum=$(python3 -c "
t = open('t/files/A/RATMODEL.MDL').read().split('\n'); c = ''; n = 0
for l in t:
  if l[:1] in 'NRLD' and l[:1] != '': c = l[:1]
  elif c == 'L' and l.startswith(' '): n += int(l.split()[1])
print(n)")
o2=$(timeout 300 python3 ntcrun.py t/cy/Main.bas "rats 3\n${W}${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
o3=$(timeout 300 python3 ntcrun.py t/cy/Main.bas "run 3 rat\n${W}rats 2\n${W}${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
if echo "$o" | grep -qE "^1: RATMODEL bed:70 food:60 play tv -> (tv 28|play 30)" && echo "$o" | grep -qE "^20: RATMODEL bed:[0-9]+ food:[0-9]+ play tv -> " \
  && echo "$o" | grep -qE "(bed:([0-9]|1[0-9]|2[0-4]) .* -> bed|food:([0-9]|1[0-9]|2[0-4]) .* -> food) [0-9]+" && [ "$lsum" == 175 ] \
  && echo "$o2" | grep -q "^No RAT service (RUN 2 MODEL RATMODEL, RUN 3 RAT)" && echo "$o3" | grep -q "^2: ?"; then echo "ok   CyborgOS ports: MODEL, RAT, RATS"; else echo "FAIL CyborgOS ports: MODEL, RAT, RATS ($lsum)"; echo "$o" | tail -24; echo "$o2" | tail -4; echo "$o3" | tail -4; fail=1; fi
# ORC (brave: flee 10) and GOBLIN (fearful: flee 60) through RAT, ASK'd: the role, the threshold
# (ask: the services run, the asks made; the answers, | after each - 4 at most: the screen shows them)
ask() { s="$1"; shift; c=""; for a in "$@"; do c="$c${a}\n${W}"; done; NTC_LIMIT=60000 timeout 600 python3 ntcrun.py t/cy/Main.bas "$s$c" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1 | grep -A1 "^1> ask" | grep -v "^--" | grep -v "^1> ask" | tr '\n' '|'; }
cp $P/cyborgos320kb/apps/rat/ORC.MDL $P/cyborgos320kb/apps/rat/GOBLIN.MDL t/files/A/
o=$(ask "run 2 model orc\n${W}run 4 rat\n${W}" "ask rat orc attack flee:80 hide shout" "ask rat orc attack flee:8 hide shout" "ask foo x")
o2=$(ask "run 3 model goblin\n${W}run 4 rat\n${W}" "ask rat goblin attack flee:80 hide shout" "ask rat goblin attack flee:50 hide shout" "ask rat goblin investigate wait flee:90")
if [ "$o" == "attack 60|flee 20|No port FOO|" ] && [ "$o2" == "shout 35|flee 17|wait 40|" ]; then echo "ok   CyborgOS RAT: ORC, GOBLIN (thresholds, roles), ASK"; else echo "FAIL CyborgOS RAT: ORC, GOBLIN: $o $o2"; fail=1; fi
# NEURAL DUNGEON: queries (text, numbers by nearness, prop?, val*), training (a new record, an old one
# again: *2), saved by E; WATCH: CyborgOS's numbers asked of NEURAL SYS, and taught (say=calm)
cp $P/cyborgos320kb/apps/rat/DUNGEON.NN $P/cyborgos320kb/apps/rat/SYS.NN t/files/A/
o=$(ask "run 2 neural dungeon\n${W}" "ask dungeon Q action? sense=see dist=2 hp=30 courage=high" "ask dungeon Q action? sense=see dist=2 hp=70 courage=high" "ask dungeon Q sense=hear dist=4 hp=50 courage=low" "ask dungeon Q action? sense=sm* courage=low")
o1=$(ask "run 2 neural dungeon\n${W}" "ask dungeon Q sense=dragon" "ask dungeon T sense=dragon dist=1 hp=80 courage=high action=run" "ask dungeon T sense=smell dist=6 hp=80 courage=low action=sniff" "ask dungeon E")
o3=$(ask "run 2 neural dungeon\n${W}" "ask dungeon Q action? sense=dragon")
o2=$(timeout 300 python3 ntcrun.py t/cy/Main.bas "run 2 neural sys\n${W}watch\n${W}${W}q${W}watch say=calm\n${W}ask sys E\n${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
if [ "$o" == "93 action=flee|93 action=attack|81 sense=hear dist=6 hp=80 courage=low action=wait|100 action=sniff|" ] && [ "$o1" == "?|ok 12|ok 12|end|" ] && [ "$o3" == "100 action=run|" ] \
  && grep -q "^sense=smell dist=6 hp=80 courage=low action=sniff \*2" t/files/A/DUNGEON.NN && grep -q "^sense=dragon dist=1 hp=80 courage=high action=run" t/files/A/DUNGEON.NN && grep -q "^' DUNGEON:" t/files/A/DUNGEON.NN \
  && echo "$o2" | grep -qE "^1: free=[0-9]+ progs=[0-9]+ -> [0-9]+ free=[0-9]+ progs=[0-9]+ say=" && echo "$o2" | grep -qE "^free=[0-9]+ progs=[0-9]+ say=calm: ok 6" && grep -qE "^free=[0-9]+ progs=[0-9]+ say=calm" t/files/A/SYS.NN; then echo "ok   CyborgOS NEURAL: queries, training saved; WATCH"; else echo "FAIL CyborgOS NEURAL: $o / $o1 / $o3"; echo "$o2" | tail -12; cat t/files/A/DUNGEON.NN; fail=1; fi
# PET: a new pet, 400 tenths of a second - F fills the bowl, T the TV on, - scolds (its model: X), M
# medicine; saved to PET.SAV (bowl 5, TV on) and back; without RAT: the message
cp $P/cyborgos320kb/apps/rat/PET.MDL t/files/A/
o=$(NTC_LIMIT=60000 timeout 900 python3 ntcrun.py t/cy/Main.bas "run 2 model pet\n${W}run 3 rat\n${W}pet new Tom 400\n${W}${W}ft-${W}${W}m" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
sv=$(tr -d ' \r' < t/files/A/PET.SAV | tr '\n' ',')
o2=$(NTC_LIMIT=60000 timeout 900 python3 ntcrun.py t/cy/Main.bas "run 2 model pet\n${W}run 3 rat\n${W}pet 50\n" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
o3=$(timeout 300 python3 ntcrun.py t/cy/Main.bas "pet 10\n${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
if echo "$o" | grep -q "^Tom is saved (PET.SAV), aged 0 days." && echo "$sv" | grep -qE "^Tom,0,400,([0-9]+,){5}5,1," && echo "$o" | grep -q "^F food  T TV  C clean  M medicine  + praise  - scold  Q quit" \
  && echo "$o2" | grep -q "^Tom is saved (PET.SAV), aged 0 days." && echo "$o3" | grep -q "^No RAT service (RUN 2 MODEL PET, RUN 3 RAT)"; then echo "ok   CyborgOS PET: kept, saved, back"; else echo "FAIL CyborgOS PET: $sv"; echo "$o" | tail -24; echo "$o2" | tail -6; echo "$o3" | tail -4; fail=1; fi
# PROBE: its own command line - PORTS (BDOS 131 op 34), decisions with their plans (dry: nothing
# learnt; RUN: the habit learnt, the deadband keeps the last pick), SHOW (MODEL's D n, W), ASK
# NEURAL; FOOD.MDL: multilevel - RAT goes down the tree (MODEL's C, W @path) to food.fruit.x,
# every level's pick kept by the deadband; SET (MODEL's V: a weight set from outside, as a sensor
# would); ORC: one command from CyborgOS's command line
cp $P/cyborgos320kb/apps/rat/PET.MDL $P/cyborgos320kb/apps/rat/ORC.MDL $P/cyborgos320kb/apps/rat/FOOD.MDL $P/cyborgos320kb/apps/rat/DUNGEON.NN t/files/A/
o=$(timeout 600 python3 ntcrun.py t/cy/Main.bas "run 2 model pet\n${W}run 3 rat\n${W}run 4 neural dungeon\n${W}probe\n${W}ports\n${W}pet bed:80 play:70 tv wander food:60\n${W}run pet bed:80 play:70 tv wander food:60\n${W}run pet bed:80 play:70 tv wander food:60\n${W}show pet play tv\n${W}ask dungeon Q action? sense=hear dist=3 hp=40 courage=low\n${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
o1=$(timeout 600 python3 ntcrun.py t/cy/Main.bas "run 2 model food\n${W}run 3 rat\n${W}probe try food food:20 sleep:80\n${W}probe run food food:60 sleep:60\n${W}probe run food food:60 sleep:60\n${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
o3=$(timeout 600 python3 ntcrun.py t/cy/Main.bas "run 2 model food\n${W}run 3 rat\n${W}probe\n${W}set food food\\fruit\\apple\\20\n${W}set food N\\sleep\\90\n${W}try food food:60 sleep:60\n${W}set food food\\xyz\\5\n${W}show food sleep apple\n${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
o2=$(timeout 600 python3 ntcrun.py t/cy/Main.bas "run 2 model orc\n${W}run 3 rat\n${W}probe orc attack flee:8 hide shout\n${W}probe show orc attack hide\n${W}probe ports\n${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
if echo "$o" | grep -q "^PET      slot 2" && echo "$o" | grep -q "^DUNGEON  slot 4" && echo "$o" | grep -q "^   LD play=40 tv=40 +3 rnd/2" && echo "$o" | grep -q "^   dry" && echo "$o" | grep -qE "^   LD play=4[01] tv=4[01] \+3 kept" \
  && echo "$o" | grep -qE "^(play +20 +- +42|tv +- +- +42) " && echo "$o" | grep -q "^74 action=wait" \
  && echo "$o1" | grep -qE "^-> food.fruit.(apple|orange) 34" && echo "$o1" | grep -q "^   N food=66" && echo "$o1" | grep -q "^   LD apple=60 orange=55 +3 rnd/2" && echo "$o1" | grep -q "^   LD food=41 +1 kept" && echo "$o1" | grep -qE "^   LD apple=6[01] orange=5[56] \+3 kept" \
  && [ "$(echo "$o3" | grep -c "^set$")" == 2 ] && echo "$o3" | grep -q "^-> sleep 34" && echo "$o3" | grep -q "^? (no such branch)" && echo "$o3" | grep -qE "^sleep +90 +- +30 +-" && echo "$o3" | grep -qE "^apple +- +- +20 +-" \
  && echo "$o2" | grep -q "^-> flee 20" && echo "$o2" | grep -q "^   N flee=80" && echo "$o2" | grep -qE "^attack +- +60 +50 +-" && echo "$o2" | grep -qE "^hide +- +- +- +40" \
  && echo "$o2" | grep -q "^ORC      slot 2" && echo "$o2" | grep -q "^RAT      slot 3"; then echo "ok   CyborgOS PROBE: plans, multilevel, deadband, TRY / RUN, SHOW, ASK, PORTS"; else echo "FAIL CyborgOS PROBE"; echo "$o" | tail -30; echo "$o1" | tail -24; echo "$o3" | tail -16; echo "$o2" | tail -20; fail=1; fi
# GREEN (an IO board's bridge - docs/cyborgos-decisions.md 9): its model - water when dry, wait
# when not; SET holds off watering; the bridge's call (the harness's ports read 255: hot)
cp $P/cyborgos320kb/apps/rat/GREEN.MDL t/files/A/
o=$(timeout 600 python3 ntcrun.py t/cy/Main.bas "run 2 model green\n${W}run 3 rat\n${W}probe try green water:20 cool:60 lamp:80 wait\n${W}probe set green N\\water\\10\n${W}probe try green water:20 cool:60 lamp:80 wait\n${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
o2=$(timeout 600 python3 ntcrun.py t/cy/Main.bas "run 2 model green\n${W}run 3 rat\n${W}green\n${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
if echo "$o" | grep -q "^-> water 34" && echo "$o" | grep -q "^-> wait 50" && echo "$o2" | grep -q "^cool 100"; then echo "ok   CyborgOS GREEN: an IO board's bridge and its model"; else echo "FAIL CyborgOS GREEN"; echo "$o" | tail -20; fail=1; fi
rm -f t/files/A/GREEN.CYB t/files/A/MODEL.CYB t/files/A/RAT.CYB t/files/A/RATS.CYB t/files/A/NEURAL.CYB t/files/A/ASK.CYB t/files/A/WATCH.CYB t/files/A/PET.CYB t/files/A/PROBE.CYB t/files/A/*.MDL t/files/A/*.NN t/files/A/PET.SAV
# CyborgOS's command line at #BE80 (NTC_POKE): CYB A KEYREP 10 - KM SET DELAY with the start delay
# and the repeat 10 times as long (30 -> 255 at most, 2 -> 20); RUN 2 CRUNCH 3 - a slot first, the
# program's tail after it
o=$(NTC_POKE="BE80=CYB A KEYREP 10" timeout 300 python3 ntcrun.py t/cy/Main.bas "run 2 crunch 3\n${W}ps\n${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
if echo "$o" | grep -q "^--- keys: start 255, repeat 20" && echo "$o" | grep -q "^CRUNCH.CYB runs in slot 2" && echo "$o" | grep -q "^  2   CRUNCH.CYB"; then echo "ok   CyborgOS KEYREP, RUN slot name"; else echo "FAIL CyborgOS KEYREP, RUN slot name"; echo "$o" | tail -8; fail=1; fi
# the TOP command: the table printed into the slot's console
o=$(timeout 300 python3 ntcrun.py t/cy/Main.bas "run 2 CRUNCH\n${W}top\n${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
if echo "$o" | grep -q "^  2   running        CRUNCH.CYB" && echo "$o" | grep -q "^SLOT  STATE" && echo "$o" | grep -q "^CyborgOS TOP$" && echo "$o" | grep -q "^Total memory: 576 KB   Free memory: 224 KB" && ! echo "$o" | grep -q "^[-B]\{32\}"; then echo "ok   CyborgOS TOP command"; else echo "FAIL CyborgOS TOP command"; echo "$o" | tail -5; fail=1; fi
# MEM: main RAM as a table, the map (TOP has none: 32 pages a group, two groups a line), the totals
o=$(timeout 300 python3 ntcrun.py t/cy/Main.bas "mem\n${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=4160 2>&1)
if echo "$o" | grep -q "^#0040-#3FFF  CyborgOS" && echo "$o" | grep -q "^#C000-#FFFF  screen" && echo "$o" | grep -q "^Total memory: 4160 KB   Free memory: 2784 KB" && echo "$o" | grep -q "^-\{32\}  -\{32\}$" && echo "$o" | grep -q "^UU--B\{28\}  B\{32\}$"; then echo "ok   CyborgOS MEM map"; else echo "FAIL CyborgOS MEM map"; echo "$o" | tail -8; fail=1; fi
# a CP/M program with no header (.COM), with UniDOS: read to its real end - by its name (BIGC:
# BIGC.COM: no BIGC.CYB), RUN TICKER.COM (16 #1A bytes in it), TICKER from B;
# DIR FULL its exact size; CD C: no such drive; A: alone and CD B: as CD A, CD B
cp t/cy/TICKER.COM t/files/A/; cp t/cy/CRUNCH.COM t/files/A/BIGC.COM
SZ=$(python3 -c "import os; print(os.path.getsize('t/files/A/BIGC.COM'))")
mkdir -p t/files/B; cp t/cy/TICKER.COM t/files/B/
o=$(NTC_UNIDOS=IDE timeout 600 python3 ntcrun.py t/cy/Main.bas "bigc\n${W}run ticker.com\n${W}x" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
o2=$(NTC_UNIDOS=IDE timeout 600 python3 ntcrun.py t/cy/Main.bas "dir bigc.com full\n${W}cv c\n${W}cv b\n${W}ticker\n${W}x" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
if echo "$o" | grep -q "^Crunch: 450015000" && echo "$o" | grep -q "^Ticker done" && echo "$o2" | grep -q "^Ticker done" && echo "$o2" | grep -q "^BIGC.COM  *$SZ " && echo "$o2" | grep -q "^C: no such drive" && echo "$o2" | grep -q "^drive B"; then echo "ok   CyborgOS a plain .COM, DIR, CD"; else echo "FAIL CyborgOS a plain .COM, DIR, CD"; echo "$o" | tail -8; echo "$o2" | tail -12; fail=1; fi
o=$(timeout 300 python3 ntcrun.py t/cy/Main.bas "b:\na:\ncv b:\n" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
if [ "$(echo "$o" | grep -c "^drive B")" == 2 ] && echo "$o" | grep -q "^drive A"; then echo "ok   CyborgOS B: alone, CV B:"; else echo "FAIL CyborgOS B: alone, CV B:"; echo "$o" | tail -8; fail=1; fi
rm -rf t/files/A/*.COM t/files/B
# the commands (cmds: COPY, ERA, TYPE, RENAME - .CYB programs, run by their names, the rest of the
# line their command tail; found on A when the slot's drive hasn't got them), on any file the drive
# has (UniDOS's listing, a RAM disc's directory - no FILES.DIR): COPY to B (the same name, a new
# name), TYPE there, CD B, DIR FULL, ERA, RUN TYPE, a name that is nowhere; COPY *.TXT C (a
# pattern, to a RAM disc), DIR C: (its own directory), ERA C:*.TXT (a pattern)
rm -rf t/files/B; mkdir -p t/files/B; printf 'line one\r\nline two\r\n' > t/files/A/README.TXT; printf 'notes\r\n' > t/files/A/NOTES.TXT
W2=$(printf '~%.0s' $(seq 1 30))
o=$(NTC_UNIDOS=IDE NTC_LIMIT=40000 timeout 1500 python3 ntcrun.py t/cy/Main.bas "copy readme.txt b:\n${W2}copy a:readme.txt b:new.txt\n${W2}type b:new.txt\n${W2}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
o2=$(NTC_UNIDOS=IDE NTC_LIMIT=40000 timeout 1500 python3 ntcrun.py t/cy/Main.bas "cv b\ndir full\nera new.txt\n${W2}run type readme.txt\n${W2}foo\n" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
o5=$(NTC_UNIDOS=IDE NTC_LIMIT=40000 timeout 1500 python3 ntcrun.py t/cy/Main.bas "ramdisc c 64\n${W2}copy *.txt c\n${W2}${W2}dir c:\n${W2}era c:*.txt\n${W2}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
if echo "$o" | grep -q "^A:README.TXT to B:README.TXT: 20 bytes" && echo "$o" | grep -q "^A:README.TXT to B:NEW.TXT: 20 bytes" && echo "$o" | grep -q "^line two" && echo "$o2" | grep -q "^NEW.TXT  " && echo "$o2" | grep -q "^B:NEW.TXT deleted" && echo "$o2" | grep -q "^line two" && echo "$o2" | grep -q "^? FOO (HELP)" && [ ! -e t/files/B/NEW.TXT ] \
  && echo "$o5" | grep -q "^2 of 2 files copied" && echo "$o5" | grep -q "^NOTES.TXT    README.TXT" && echo "$o5" | grep -q "^C:NOTES.TXT deleted" && echo "$o5" | grep -q "^C:README.TXT deleted"; then echo "ok   CyborgOS commands COPY ERA TYPE (no FILES.DIR)"; else echo "FAIL CyborgOS commands COPY ERA TYPE (no FILES.DIR)"; echo "$o" | tail -8; echo "$o2" | tail -10; echo "$o5" | tail -14; fail=1; fi
rm -f t/files/A/NOTES.TXT
# TYPE a page at a time: 60 lines, the console's 24 rows - 23, then "-- more --" waits; Q ends it
python3 -c "open('t/files/A/LONG.TXT', 'wb').write(b''.join(b'line %d\r\n' % i for i in range(1, 61)))"
o=$(NTC_LIMIT=40000 timeout 1500 python3 ntcrun.py t/cy/Main.bas "type long.txt\n${W2}q${W2}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
rm -f t/files/A/LONG.TXT
if echo "$o" | grep -q "^line 23$" && ! echo "$o" | grep -q "^line 24$" && echo "$o" | grep -q "^\[TYPE.CYB ended\]"; then echo "ok   CyborgOS TYPE a page at a time"; else echo "FAIL CyborgOS TYPE a page at a time"; echo "$o" | tail -8; fail=1; fi
# RENAME: any file; another volume refused
o=$(NTC_UNIDOS=IDE NTC_LIMIT=40000 timeout 1500 python3 ntcrun.py t/cy/Main.bas "rename b:readme.txt b:notes.txt\n${W2}rename b:notes.txt a:x.txt\n${W2}cv b\ndir full\n" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
if echo "$o" | grep -q "^B:README.TXT is B:NOTES.TXT now" && echo "$o" | grep -q "^RENAME can't move a file to another volume" && echo "$o" | grep -q "^NOTES.TXT  " && [ -e t/files/B/NOTES.TXT ] && [ ! -e t/files/B/README.TXT ]; then echo "ok   CyborgOS command RENAME"; else echo "FAIL CyborgOS command RENAME"; echo "$o" | tail -10; fail=1; fi
# HELP: a program on the disc (HELP.CYB), not in the hypervisor - its text from HELP.HLP, HELP name
# from NAME.HLP (on A: here), a name with none; then (UniDOS) from A's HELP folder, where the
# installer puts them (a free letter's path for a moment)
cp $P/cyborgos320kb/help/*.HLP t/files/A/
o=$(timeout 600 python3 ntcrun.py t/cy/Main.bas "help\n${W2} ${W2}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
o2=$(timeout 600 python3 ntcrun.py t/cy/Main.bas "help rename\n${W2}help foo\n${W2}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
rm -f t/files/A/*.HLP; mkdir -p t/files/A/HELP; cp $P/cyborgos320kb/help/*.HLP t/files/A/HELP/
o3=$(NTC_UNIDOS=IDE timeout 600 python3 ntcrun.py t/cy/Main.bas "help copy\n${W2}cd\n${W2}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
rm -rf t/files/A/HELP
if echo "$o" | grep -q "^MODE \[m\]  " && echo "$o2" | grep -q "^RENAME \[v:\]name newname" && echo "$o2" | grep -q "^No help for FOO.HLP" && echo "$o" | grep -q "^\[HELP.CYB ended\]" && echo "$o3" | grep -q "^COPY \[v1:\]pattern v2" && echo "$o3" | grep -q "^  Copies a file to drive v2 (B or B:), as newname or the same name; a$" && ! echo "$o3" | grep -q "^  [C-P]: --> "; then echo "ok   CyborgOS HELP from the disc, from A:HELP/"; else echo "FAIL CyborgOS HELP from the disc"; echo "$o" | tail -6; fail=1; fi
# MODE: each slot its own screen mode (the CRTC's widths and the hardware scroll, CyborgOS's own):
# P in slot 1 (64 x 32; LINES' 200 lines scroll), slot 2 opened (MODE S, the default: 80 x 24
# and the status strip on the right), back to slot 1 (its page drawn again); MODE lists the modes,
# the console's size from BDOS 49 (CP/M 3's system control block). UW in slot 1, then slot 2
o=$(NTC_LIMIT=40000 timeout 1500 python3 ntcrun.py t/cy/Main.bas "mode p\n${W2}run lines\n${W}${W}${W}~~{23,65}${W2}~~{23,64}${W2}mode\n${W2}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
o2=$(NTC_LIMIT=40000 timeout 1500 python3 ntcrun.py t/cy/Main.bas "mode uw\n${W2}mode\n${W2}~~{23,65}${W2}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
if echo "$o" | grep -q "^line200 the quick" && echo "$o" | grep -q "^Now: MODE P - the console 64 x 32" && echo "$o2" | grep -qE "^CyborgOS slot 2 of 4 .{59}\[2\]$"; then echo "ok   CyborgOS MODE"; else echo "FAIL CyborgOS MODE"; echo "$o" | tail -10; echo "$o2" | tail -6; fail=1; fi
# MON (apps/mon: Bml.cls lays out its 8BML pages, Mouse.cls the Amiga mouse; its pages from
# SYSTEM.MAP): MODE F, the Main RAM page (tool 8), Enter on its first link: 1K of main RAM in hex
# (BDOS 131 op 10; the lines in its store: ops 12-14). With the mouse (the harness's: NTC_MOUSE,
# {mdx,dy,b}): 12 cells left, 11 up onto the toolbar's rOms, a click - the ROMs page (op 15's
# table 2). TEST.MAP 2 with LIST in slot 2 (a linked list at #8000): walk, a slot's memory (op
# 10 kind 3)
mkdir -p t/mon; A=$P/cyborgos320kb/apps/mon
node cli.js $A/MON.bas $A/Bml.cls $A/Mouse.cls $P/cyborgos320kb/cmds/CybSys.cls --platform=cpm > t/mon/MON.asm 2>/dev/null
(cd t/mon && ${SJASMPLUS:-sjasmplus} --nologo --msg=err --raw=MON.COM MON.asm > /dev/null)
python3 -c "import ntcrun; d = open('t/mon/MON.COM', 'rb').read(); open('t/files/A/MON.CYB', 'wb').write(ntcrun.amsdos_header(d, 0x100) + d)"
cp $A/SYSTEM.MAP t/files/A/
printf '; MON test map\ncat "Test"\nnode chain "Chain"\nsrc slot {s} #8000 64\nrec 8\nwalk w 0\nf "Addr" a\nf "Value" w 2\nf "Name" s 4 4\nview list\n' > t/files/A/TEST.MAP
printf 'Option Explicit\nDim j As Integer, a As Integer, n As Integer\nFor j = 0 To 4\n  a = &H8000 + j * 8 : n = a + 8\n  If j = 4 Then n = 0\n  Poke a, n And 255 : Poke a + 1, (n And &HFF00) \\ 256\n  Poke a + 2, j * 10 : Poke a + 3, 0\n  Poke a + 4, 78 : Poke a + 5, 48 + j : Poke a + 6, 0 : Poke a + 7, 0\nNext\nDo\nLoop Until Inkey <> 0\n' > t/mon/LIST.bas
node cli.js t/mon/LIST.bas --platform=cpm > t/mon/LIST.asm 2>/dev/null
(cd t/mon && ${SJASMPLUS:-sjasmplus} --nologo --msg=err --raw=LIST.COM LIST.asm > /dev/null)
python3 -c "import ntcrun; d = open('t/mon/LIST.COM', 'rb').read(); open('t/files/A/LIST.CYB', 'wb').write(ntcrun.amsdos_header(d, 0x100) + d)"
o=$(NTC_LIMIT=40000 timeout 2500 python3 ntcrun.py t/cy/Main.bas "mon\n${W}${W}8${W}\n${W}${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
o2=$(NTC_MOUSE=1 NTC_LIMIT=30000 timeout 2500 python3 ntcrun.py t/cy/Main.bas "mon\n${W}${W}${W}${W}${W}${W}${W}{m-36,-33,0}${W}{m0,0,1}${W}{m0,0,0}${W}${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
o3=$(NTC_LIMIT=40000 timeout 2500 python3 ntcrun.py t/cy/Main.bas "run 2 list\n${W}mon test.map 2\n${W}${W}\n${W}${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
if echo "$o" | grep -q "^+- Hex: main 0 #0000 " && echo "$o" | grep -q "^|0040  18 0C " && echo "$o2" | grep -q "^+- ROMs " && echo "$o2" | grep -q "BASIC (on board)" && echo "$o3" | grep -qE "^\|#8020 +40 +N4 "; then echo "ok   CyborgOS MON"; else echo "FAIL CyborgOS MON"; echo "$o" | head -8; echo "$o2" | head -8; echo "$o3" | tail -24; fail=1; fi
rm -f t/files/A/MON.CYB t/files/A/SYSTEM.MAP t/files/A/TEST.MAP t/files/A/LIST.CYB
# YING, YANG (apps/ying, apps/yang: the web browsers - Web.cls, MON's / MON2's screen): HOME.8BM
# from the disc, Enter on its first link (KEYS.8BM: a file, its Home link from its drive); G and
# an address (DEL rubs out the one there): no network yet - its page says so; https: not supported
mkdir -p t/web; B=$P/cyborgos320kb/apps
for g in YING YANG; do
  node cli.js $B/$(echo $g | tr A-Z a-z)/$g.bas $B/ying/Web.cls $B/mon/Bml.cls $B/mon/Mouse.cls $P/cyborgos320kb/cmds/Http.cls $P/cyborgos320kb/cmds/CybSys.cls --platform=cpm > t/web/$g.asm 2>/dev/null
  (cd t/web && ${SJASMPLUS:-sjasmplus} --nologo --msg=err --sym=$g.sym --raw=/dev/null $g.asm > /dev/null)
  [ $((16#$(grep -E '^ntc_free:' t/web/$g.sym | grep -oE '[0-9A-F]{4}$'))) -le $((0xB500)) ] || { echo "FAIL CyborgOS $g: the program reaches its buffers (#B500)"; fail=1; }
  (cd t/web && ${SJASMPLUS:-sjasmplus} --nologo --msg=err --raw=$g.COM $g.asm > /dev/null)
  python3 -c "import ntcrun; d = open('t/web/$g.COM', 'rb').read(); open('t/files/A/$g.CYB', 'wb').write(ntcrun.amsdos_header(d, 0x100) + d)"
done
cp $B/ying/*.8BM t/files/A/
DL=$(printf '\\x7f%.0s' $(seq 1 30))
o=$(NTC_LIMIT=60000 timeout 2500 python3 ntcrun.py t/cy/Main.bas "ying\n${W}${W}\n${W}${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
o2=$(NTC_LIMIT=60000 timeout 2500 python3 ntcrun.py t/cy/Main.bas "ying\n${W}${W}g${W}${DL}example.com/a/b.8bml?x=1#top\n${W}${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
o3=$(NTC_LIMIT=60000 timeout 2500 python3 ntcrun.py t/cy/Main.bas "yang\n${W}${W}g${W}${DL}https://x.org/\n${W}${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
o4=$(NTC_LIMIT=60000 timeout 2500 python3 ntcrun.py t/cy/Main.bas "yang\n${W}${W}\n${W}${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
if echo "$o" | grep -q "^+- Keys -" && echo "$o" | grep -q "^| HOME.8BM " && echo "$o2" | grep -q "^|No network (NET M4) " && echo "$o2" | grep -q "^|http://example.com/a/b.8bml?x=1#top " && echo "$o2" | grep -q "^+- Can't fetch it -" \
  && echo "$o3" | grep -q "^https isn't supported - http only:" && echo "$o4" | grep -qE "^1:Back 2:Reload 3:Home 4:Go to 5:Quit \| HOME.8BM +1 / 24$"; then echo "ok   CyborgOS YING, YANG (web browsers)"; else echo "FAIL CyborgOS YING, YANG (web browsers)"; echo "$o" | tail -6; echo "$o2" | tail -24; echo "$o3" | tail -8; echo "$o4" | tail -4; fail=1; fi
# the network (NTC_M4: the harness's M4 - real sockets - and websrv.py, a web server here): NET
# off, NET M4 (the M4 found by its ROM's name, claimed as M4 0 by CyborgOS), NET GET a redirect
# (/moved: to /echo?moved=1 - the address's small letters kept), NET TEST, NET OFF; YING: a page
# with a form - its fields typed (a password shown as *), a select's next choice, Send: GET
# /echo?name=...&action=Send (the server shows the parameters); Send with a mandatory field empty:
# that field chosen
WP=18765; rm -rf t/www; mkdir -p t/www
printf '%s' '-"1","Form":p"Contact":n:t"Name *":y"name","20","m","":t"Password":y"pw","10","p","":t"Message":z"msg","30","2","","":t"Computer *":w"comp","a","m","a","Amstrad CPC","c","Commodore 64":n:x"/echo","Send":.' > t/www/form.8bm
python3 websrv.py $WP t/www > /dev/null 2>&1 & WS=$!
sleep 1; T=$(printf '\t')
o=$(NTC_M4=1 timeout 900 python3 ntcrun.py t/cy/Main.bas "net\n${W}net m4\n${W}${W}claims\n${W}net get localhost:$WP/moved\n${W}${W}${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
o1=$(NTC_M4=1 timeout 900 python3 ntcrun.py t/cy/Main.bas "net m4\n${W}${W}net test 127.0.0.1:$WP/big?n=3000 2\n${W}${W}${W}${W}net off\n${W}net\n${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
o2=$(NTC_M4=1 NTC_LIMIT=90000 timeout 3000 python3 ntcrun.py t/cy/Main.bas "net m4\n${W}${W}ying http://localhost:$WP/form.8bm\n${W}${W}${W}\n${W}Jo Ann\n${W}${T}${W}\n${W}x&y\n${W}${T}${W}\n${W}hi there\n${W}${T}${W}\n${W}${T}${W}\n${W}${W}${W}${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
o3=$(NTC_M4=1 NTC_LIMIT=90000 timeout 3000 python3 ntcrun.py t/cy/Main.bas "net m4\n${W}${W}yang http://localhost:$WP/form.8bm\n${W}${W}${W}${T}${W}\n${W}x&y\n${W}${T}${W}${T}${W}\n${W}${T}${W}\n${W}${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
kill $WS 2>/dev/null
if echo "$o" | grep -q "^No network (NET M4 turns it on through an M4 board)" && echo "$o" | grep -q "^Network on: M4 (ROM 3)" && echo "$o" | grep -qE "^M4 +0 +255" \
  && echo "$o" | grep -q "^HTTP 200, 36 bytes (moved to http://localhost:$WP/echo?moved=1)" && echo "$o" | grep -q 't"moved=1"' && echo "$o1" | grep -qE "^2: HTTP 200, 3091 bytes, [0-9]+ ms" \
  && echo "$o1" | grep -q "^Average " && echo "$o1" | grep -q "^Network off" && echo "$o1" | grep -q "^No network (NET M4" \
  && grep -q "^GET /moved HTTP/1.0" t/www/requests.log && grep -q "^GET /echo?moved=1 HTTP/1.0" t/www/requests.log \
  && echo "$o2" | grep -q "^|name=Jo Ann " && echo "$o2" | grep -q "^|pw=x&y " && echo "$o2" | grep -q "^|msg=hi there " && echo "$o2" | grep -q "^|comp=c " && echo "$o2" | grep -q "^|action=Send " \
  && grep -q "^GET /form.8bm?8bml=7 HTTP/1.0" t/www/requests.log && grep -qF "GET /echo?name=Jo%20Ann&pw=x%26y&msg=hi%20there&comp=c&action=Send&8bml=7 HTTP/1.0" t/www/requests.log \
  && echo "$o3" | grep -q "Fill in name first" && echo "$o3" | grep -q "^|\*\*\*_______|" && echo "$o3" | grep -q "^\[ Commodore 64 v\]"; then echo "ok   CyborgOS NET M4 (the harness's M4), YING / YANG forms"; else echo "FAIL CyborgOS NET M4, YING / YANG forms"; echo "$o" | tail -30; echo "$o1" | tail -14; echo "$o2" | tail -24; echo "$o3" | tail -24; cat t/www/requests.log; fail=1; fi
rm -f t/files/A/YING.CYB t/files/A/YANG.CYB t/files/A/*.8BM
# VDU (tools/vdu: vdu.php, PHP's own server on t/vdu) and RVDU (apps/rvdu: the remote VDU console):
# the server - a screen made, lines put, got from a pointer, from -1 (its last MODE), past the end
# after a wipe (from 0 again), ping, events; text.php's grid, dumb.php's rolling log. Then RVDU on
# CyborgOS through the harness's M4: RVDU SERVER, the screen live (its text where LOCATE put it, a
# window scrolled) with a key sent back (KEY 120), ROLL (a rolling log), TEST (the CPC writing a
# count in place; a tap on its QUIT zone - put in as a viewer would - comes back and ends it)
if command -v php > /dev/null && command -v curl > /dev/null; then
VP=18766; rm -rf t/vdu; mkdir -p t/vdu; cp ../../tools/vdu/*.php ../../tools/vdu/*.js ../../tools/vdu/*.html ../../tools/vdu/*.css t/vdu/
php -S 127.0.0.1:$VP -t t/vdu > /dev/null 2>&1 & VS=$!
sleep 1; VU=http://127.0.0.1:$VP/vdu.php
vr=$(curl -s "$VU?a=new&t=Reg%20test"); vid=$(echo $vr | cut -d' ' -f2); vk=$(echo $vr | cut -d' ' -f3)
v1=$(curl -s "$VU?a=put&s=$vid&k=$vk&c=MODE%201%0APRINT%20Hello%20from%20the%20server%0ALOCATE%2010%205%0APRINT%20at%2010,5%0AWINDOW%201%2020%208%2010%0APRINT%20w1%0APRINT%20w2%0APRINT%20w3%0APRINT%20w4%0ALOCATE%201%201%0APRINT%20first;%0APRINT%20%20same%20line")
v2=$(curl -s "$VU?a=put&s=$vid&k=bad&c=x"); v3=$(curl -s "$VU?a=get&s=$vid&n=10&m=1"); v4=$(curl -s "$VU?a=get&s=$vid&n=-1&m=1")
v5=$(curl -s "$VU?a=ping&w=$vid:12,$vid:3"); v6=$(curl -s "$VU?a=event&s=$vid&e=TOUCH%20ok%201%202"); v7=$(curl -s "$VU?a=events&s=$vid&k=$vk&n=0")
v8=$(curl -s "http://127.0.0.1:$VP/text.php?s=$vid"); v9=$(curl -s "http://127.0.0.1:$VP/dumb.php?s=$vid")
node cli.js $P/cyborgos320kb/apps/rvdu/RVDU.bas t/cmd/Http.cls t/cmd/CybSys.cls --platform=cpm > t/cmd/RVDU.asm 2>/dev/null
(cd t/cmd && ${SJASMPLUS:-sjasmplus} --nologo --msg=err --raw=RVDU.COM RVDU.asm > /dev/null)
python3 -c "import ntcrun; d = open('t/cmd/RVDU.COM', 'rb').read(); open('t/files/A/RVDU.CYB', 'wb').write(ntcrun.amsdos_header(d, 0x100) + d)"
o=$(NTC_M4=1 NTC_LIMIT=60000 timeout 2500 python3 ntcrun.py t/cy/Main.bas "net m4\n${W}${W}rvdu server 127.0.0.1:$VP/vdu.php\n${W}${W}rvdu $vid\n${W}${W}${W}${W}x${W}${W}\\x1b${W}${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
o2=$(NTC_M4=1 NTC_LIMIT=60000 timeout 2500 python3 ntcrun.py t/cy/Main.bas "net m4\n${W}${W}rvdu server\n${W}${W}rvdu $vid roll\n${W}${W}${W}${W}\\x1b${W}${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
vw=$(curl -s "$VU?a=events&s=$vid&k=$vk&n=0"); va=$(curl -s "$VU?a=wipe&s=$vid&k=$vk"); vb=$(curl -s "$VU?a=get&s=$vid&n=12")
(until curl -s "$VU?a=get&s=$vid&n=0&m=1000" | grep -q "Count: 2"; do sleep 1; done; curl -s "$VU?a=event&s=$vid&e=TOUCH%20quit%20500%2090" > /dev/null) & VI=$!
o3=$(NTC_M4=1 NTC_LIMIT=150000 timeout 2500 python3 ntcrun.py t/cy/Main.bas "net m4\n${W}${W}rvdu test $vid $vk\n${W}${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
kill $VI 2>/dev/null; vc=$(curl -s "$VU?a=get&s=$vid&n=0&m=1000"); kill $VS 2>/dev/null
if [ "$v1" == "ok 12 0" ] && echo "$v2" | grep -q "^error" && [ "$v3" == "$(printf 'ok 10 11 12\nPRINT first;')" ] && [ "$v4" == "$(printf 'ok 0 1 12\nMODE 1')" ] \
  && [ "$v5" == "ok $vid" ] && [ "$v6" == "ok 1" ] && [ "$v7" == "$(printf 'ok 0 1 1\nTOUCH ok 1 2')" ] && echo "$v8" | grep -q ">Hello from the server" \
  && echo "$v9" | grep -q "^first same line<br>" && echo "$o2" | grep -q "^Network on: M4" && echo "$o2" | grep -q "^Server: http://127.0.0.1:$VP/vdu.php$" \
  && echo "$o" | grep -q "^         at 10,5" && echo "$o" | grep -A1 "^first same line" | grep -q "^w4" && echo "$o" | grep -q "^RVDU: line 12 of 12" \
  && echo "$o2" | grep -q "^RVDU $vid - rolling" && echo "$o2" | grep -q "^w4" && echo "$o2" | grep -q "^first same line" && echo "$vw" | grep -q "^KEY 120" \
  && [ "$va" == "ok 0" ] && [ "$vb" == "ok 0 0 0" ] && echo "$o3" | grep -q "^Event: TOUCH quit 500 90" && echo "$vc" | grep -q "^PRINT The CPC's test has ended." \
  && echo "$vc" | grep -q "^PRINT The CPC got: TOUCH quit"; then echo "ok   VDU server (tools/vdu) and RVDU (CyborgOS, the harness's M4)"
else echo "FAIL VDU server and RVDU"; echo "[$v1][$v2][$v3][$v4][$v5][$v6][$v7][$va][$vb][$vw]"; echo "$v9"; echo "$o" | tail -30; echo "$o2" | tail -14; echo "$o3" | tail -10; echo "$vc" | tail -8; fail=1; fi
rm -f t/files/A/RVDU.CYB t/files/A/RVDU.CFG
else echo "ok   VDU server and RVDU: skipped (no php or curl)"; fi
# RAWYING, RAWYANG (YING, YANG built with apps/rawying/Bml.cls: raw pages - laid out by the server,
# tools/rawpage/8bml2raw.py - no 8BML of their own): HOME.RAW, KEYS.RAW (8bml2raw --local of the
# 8BM pages) from the disc, Enter on the first link; the form from websrv with &raw=78 (RAWYANG
# &raw=80): typed, sent (the request with raw=78), RAWYANG's mandatory field
for g in YING YANG; do
  node cli.js $B/$(echo $g | tr A-Z a-z)/$g.bas $B/ying/Web.cls $B/rawying/Bml.cls $B/mon/Mouse.cls $P/cyborgos320kb/cmds/Http.cls $P/cyborgos320kb/cmds/CybSys.cls --platform=cpm > t/web/RAW$g.asm 2>/dev/null
  (cd t/web && ${SJASMPLUS:-sjasmplus} --nologo --msg=err --sym=RAW$g.sym --raw=RAW$g.COM RAW$g.asm > /dev/null)
  [ $((16#$(grep -E '^ntc_free:' t/web/RAW$g.sym | grep -oE '[0-9A-F]{4}$'))) -le $((0xB500)) ] || { echo "FAIL CyborgOS RAW$g: the program reaches its buffers (#B500)"; fail=1; }
  python3 -c "import ntcrun; d = open('t/web/RAW$g.COM', 'rb').read(); open('t/files/A/RAW$g.CYB', 'wb').write(ntcrun.amsdos_header(d, 0x100) + d)"
done
for f in HOME KEYS; do python3 ../../tools/rawpage/8bml2raw.py --local $B/ying/$f.8BM 78 t/files/A/$f.RAW; done
WP=18766; rm -rf t/www; mkdir -p t/www
printf '%s' '-"1","Form":p"Contact":n:t"Name *":y"name","20","m","":t"Password":y"pw","10","p","":t"Message":z"msg","30","2","","":t"Computer *":w"comp","a","m","a","Amstrad CPC","c","Commodore 64":n:x"/echo","Send":.' > t/www/form.8bm
python3 websrv.py $WP t/www > /dev/null 2>&1 & WS=$!
sleep 1
o=$(NTC_LIMIT=60000 timeout 2500 python3 ntcrun.py t/cy/Main.bas "rawying\n${W}${W}\n${W}${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
o1=$(NTC_LIMIT=60000 timeout 2500 python3 ntcrun.py t/cy/Main.bas "rawyang\n${W}${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
o2=$(NTC_M4=1 NTC_LIMIT=90000 timeout 3000 python3 ntcrun.py t/cy/Main.bas "net m4\n${W}${W}rawying http://localhost:$WP/form.8bm\n${W}${W}${W}\n${W}Jo Ann\n${W}${T}${W}\n${W}x&y\n${W}${T}${W}\n${W}hi there\n${W}${T}${W}\n${W}${T}${W}\n${W}${W}${W}${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
o3=$(NTC_M4=1 NTC_LIMIT=90000 timeout 3000 python3 ntcrun.py t/cy/Main.bas "net m4\n${W}${W}rawyang http://localhost:$WP/form.8bm\n${W}${W}${W}${T}${W}\n${W}x&y\n${W}${T}${W}${T}${W}\n${W}${T}${W}\n${W}${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
kill $WS 2>/dev/null
if echo "$o" | grep -q "^+- Keys -" && echo "$o" | grep -q "^|Tab, right       the next link " && echo "$o" | grep -q "^| HOME.RAW " \
  && echo "$o1" | grep -qE "^1:Back 2:Reload 3:Home 4:Go to 5:Quit \| KEYS.RAW +1 / 25$" && echo "$o1" | grep -q "^->>The keys<" \
  && echo "$o2" | grep -q "^|name=Jo Ann " && echo "$o2" | grep -q "^|pw=x&y " && echo "$o2" | grep -q "^|msg=hi there " && echo "$o2" | grep -q "^|comp=c " && echo "$o2" | grep -q "^|action=Send " \
  && grep -q "^GET /form.8bm?8bml=7&raw=78 HTTP/1.0" t/www/requests.log && grep -qF "GET /echo?name=Jo%20Ann&pw=x%26y&msg=hi%20there&comp=c&action=Send&8bml=7&raw=78 HTTP/1.0" t/www/requests.log \
  && grep -q "^GET /form.8bm?8bml=7&raw=80 HTTP/1.0" t/www/requests.log && echo "$o3" | grep -q "Fill in name first" && echo "$o3" | grep -q "^|\*\*\*_______|" && echo "$o3" | grep -q "^\[ Commodore 64 v\]"; then echo "ok   CyborgOS RAWYING, RAWYANG (raw pages)"; else echo "FAIL CyborgOS RAWYING, RAWYANG (raw pages)"; echo "$o" | tail -24; echo "$o1" | tail -4; echo "$o2" | tail -24; echo "$o3" | tail -24; cat t/www/requests.log; fail=1; fi
rm -f t/files/A/RAWYING.CYB t/files/A/RAWYANG.CYB t/files/A/*.RAW
# RAM discs (RAMDISC: the driver into a page of its own, the hypervisor's file calls offered to
# it first): J and L made, files copied there, DIR of one, RDT (cpm/rdt.asm: random reads and
# writes in place, sizes, searches, delete) run from L (the slot's drive); then the list
# empty, one made and dropped, dropped again (not a RAM disc), more than there is
${SJASMPLUS:-sjasmplus} --nologo --msg=err --raw=t/cmd/RDT.COM cpm/rdt.asm
python3 -c "
import ntcrun
d = open('t/cmd/RDT.COM', 'rb').read(); open('t/files/A/RDT.CYB', 'wb').write(ntcrun.amsdos_header(d, 0x100) + d)"
o=$(NTC_UNIDOS=IDE NTC_LIMIT=60000 timeout 1500 python3 ntcrun.py t/cy/Main.bas "ramdisc j 64k\n${W2}ramdisc l 32\n${W2}copy readme.txt j:\n${W2}copy rdt.cyb l:\n${W2}cls\nramdisc\n${W2}dir j: full\n${W2}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
o2=$(NTC_UNIDOS=IDE NTC_LIMIT=60000 timeout 1500 python3 ntcrun.py t/cy/Main.bas "ramdisc l 32\n${W2}copy rdt.cyb l:\n${W2}cv l\n${W2}cls\nrdt\n${W2}${W2}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
r=ok; for x in "J: 64K, 1 files, 60K free" "L: 32K, 1 files, 30K free" "README.TXT         128" "1 files"; do echo "$o" | grep -qF "$x" || r="no: $x"; done
for x in "r25=00 1919" "r5=XX X06" "size=0028 place=07" "s=00 TEST    DAT 28FF" "del=00FF" "[RDT.CYB ended]"; do echo "$o2" | grep -qF "$x" || r="no: $x"; done
if [ "$r" == ok ]; then echo "ok   CyborgOS RAM discs: files, random access"; else echo "FAIL CyborgOS RAM discs: files, random access $r"; echo "$o" | tail -16; echo "$o2" | tail -14; fail=1; fi
o=$(NTC_LIMIT=40000 timeout 1500 python3 ntcrun.py t/cy/Main.bas "ramdisc\n${W2}ramdisc j 32\n${W2}ramdisc j 0\n${W2}ramdisc j 0\n${W2}ramdisc\n${W2}ramdisc k 1mb\n${W2}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
if [ "$(echo "$o" | grep -c "^No RAM discs")" == 2 ] && echo "$o" | grep -q "^J: RAM disc, 32K" && echo "$o" | grep -q "^J: dropped" && echo "$o" | grep -q "^J: not a RAM disc" && echo "$o" | grep -q "^Not enough free memory for 1024K (208K free"; then echo "ok   CyborgOS RAMDISC made, dropped, too big"; else echo "FAIL CyborgOS RAMDISC made, dropped, too big"; echo "$o" | tail -20; fail=1; fi
# the system drive Z: CYBORGOS.Z on A names the commands; CyborgOS copies them to Z at start and
# runs them from there (DIR Z: lists them: its own directory); keys typed meanwhile wait. C/PS.CYB:
# from A's folder C (UniDOS - where the installer puts the commands)
printf 'C/PS.CYB\r\nDIR.CYB\r\nMEM.CYB\r\nNOSUCH.CYB\r\n' > t/files/A/CYBORGOS.Z
mkdir -p t/files/A/C; mv t/files/A/PS.CYB t/files/A/C/
o=$(NTC_UNIDOS=IDE NTC_LIMIT=40000 timeout 1500 python3 ntcrun.py t/cy/Main.bas "ps\n${W2}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
o2=$(NTC_UNIDOS=IDE NTC_LIMIT=40000 timeout 1500 python3 ntcrun.py t/cy/Main.bas "dir z: full\n${W2}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
mv t/files/A/C/PS.CYB t/files/A/; rm -rf t/files/A/C
if echo "$o" | grep -q "Z: system drive, 3 commands" && echo "$o" | grep -q "^  1 \* PS.CYB" && echo "$o2" | grep -q "^PS.CYB  " && echo "$o2" | grep -q "^MEM.CYB  " && echo "$o2" | grep -q "^3 files"; then echo "ok   CyborgOS system drive Z"; else echo "FAIL CyborgOS system drive Z"; echo "$o" | tail -14; echo "$o2" | tail -10; fail=1; fi
# reset survival: boot (Z built from disc), keep the expansion RAM as a reset would, boot again -
# the RAM discs are reclaimed from the pages that survived (the driver page's CYBD signature and
# D_POOL checksum), no file loading the second time
o=$(NTC_LIMIT=60000 timeout 2000 python3 resettest.py t/cy/Main.bas t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --ram=576 2>/dev/null)
if echo "$o" | grep -q "opens2=0 zletter=Z " && echo "$o" | grep -q "zfiles=.*PSCYB" && ! echo "$o" | grep -q "opens1=0"; then echo "ok   CyborgOS reset survival (RAM discs reclaimed)"; else echo "FAIL CyborgOS reset survival"; echo "$o"; fail=1; fi
rm -f t/files/A/CYBORGOS.Z
rm -rf t/files/A/RDT.CYB t/files/A/README.TXT t/files/A/FILES.DIR t/files/B
# UniDOS (the harness's stand-in, NTC_UNIDOS: devices as folders, its Ctrl J): CD IDE:GAMES (A is
# UniDOS's own: C gets the path), DIR (a folder, files), TYPE / COPY / RENAME / ERA with no FILES.DIR,
# CD .., CD (the paths, the devices), DIR FULL (any size), CD D: SD:, CD D: -, a folder that isn't
# there; then the CP/M calls' directory search (17, 18) from UniDOS's listing, no FILES.DIR
rm -rf t/files/IDE t/files/SD; mkdir -p t/files/IDE/GAMES/ACTION t/files/SD
printf 'game list\r\nline two\r\n' > t/files/IDE/GAMES/LIST.TXT; head -c 70000 /dev/zero | tr '\0' x > t/files/IDE/BIG.DAT
printf 'sd file\r\n' > t/files/SD/SDFILE.TXT
o=$(NTC_UNIDOS=IDE,SD NTC_LIMIT=30000 timeout 2000 python3 ntcrun.py t/cy/Main.bas "cv ide:games\n${W}dir\n${W}type list.txt\n${W}copy list.txt a:l2.txt\n${W}${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
o3=$(NTC_UNIDOS=IDE,SD NTC_LIMIT=40000 timeout 2000 python3 ntcrun.py t/cy/Main.bas "cv ide:games\n${W}rename list.txt list2.txt\n${W}${W}era list2.txt\n${W}${W}dir\n${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
o2=$(NTC_UNIDOS=IDE,SD NTC_LIMIT=30000 timeout 2000 python3 ntcrun.py t/cy/Main.bas "cv ide:games\n${W}cd ..\n${W}dir full\n${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
o4=$(NTC_UNIDOS=IDE,SD NTC_LIMIT=40000 timeout 2000 python3 ntcrun.py t/cy/Main.bas "cv ide:\n${W}cv d: sd:\n${W}cv\n${W}cv d: -\n${W}cv ide:nothere\n${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
if echo "$o" | grep -q "^drive C: --> IDE:GAMES/" && echo "$o" | grep -q "^ACTION/      LIST.TXT" && echo "$o" | grep -q "^line two" && echo "$o" | grep -q "^C:LIST.TXT to A:L2.TXT: 21 bytes" && echo "$o3" | grep -q "^C:LIST.TXT is C:LIST2.TXT now" && echo "$o3" | grep -q "^C:LIST2.TXT deleted" && echo "$o3" | grep -q "^ACTION/ *$" && [ -e t/files/A/L2.TXT ] && [ ! -e t/files/IDE/GAMES/LIST2.TXT ] \
  && echo "$o2" | grep -q "^drive C: --> IDE:$" && echo "$o2" | grep -q "^BIG.DAT  *70000 " && echo "$o2" | grep -q "^GAMES/  *<DIR>" && echo "$o4" | grep -q "^drive D: --> SD:" && echo "$o4" | grep -q "^  C: --> IDE:" && echo "$o4" | grep -q "^Devices: IDE: SD:$" && echo "$o4" | grep -q "^D: its path dropped" && echo "$o4" | grep -q "^IDE:NOTHERE: not a folder"; then echo "ok   CyborgOS UniDOS: CD IDE:, DIR, TYPE COPY RENAME ERA in a folder"; else echo "FAIL CyborgOS UniDOS: CD IDE:, DIR, TYPE COPY RENAME ERA in a folder"; echo "$o" | tail -14; echo "$o3" | tail -10; echo "$o2" | tail -10; echo "$o4" | tail -14; fail=1; fi
# CD with a letter alone: a folder of that name here first (CD C into CYBORGOS/C), else the drive;
# with ":" (CD A:) always the drive; from A (no folder C there) CD C is drive C
mkdir -p t/files/IDE/C
o=$(NTC_UNIDOS=IDE,SD NTC_LIMIT=30000 timeout 2000 python3 ntcrun.py t/cy/Main.bas "cv ide:\n${W}cd c\n${W}cv a:\n${W}cv c\n${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
if [ "$(echo "$o" | grep -c "^drive C: --> IDE:C/")" == 2 ] && echo "$o" | grep -q "^drive A:$"; then echo "ok   CyborgOS UniDOS: CD C (a folder C), CD A: (the drive)"; else echo "FAIL CyborgOS UniDOS: CD C (a folder C), CD A: (the drive)"; echo "$o" | tail -14; fail=1; fi
rm -rf t/files/IDE/C
# IDE: alone (any word ending ":" is CD that), MKDIR, CD IDE (a device's name without ":"), DRIVE
# (DRIVE: the letters, the devices by UniDOS's names), a plain .COM with no entry run from a folder (UniDOS
# reads it to its real end), CD DFB: (a floppy UniDOS can't examine: taken as it is)
cp t/cy/CRUNCH.COM t/files/IDE/GAMES/
o=$(NTC_UNIDOS=IDE,SD,DFB,ZERO NTC_UNIDOS_NOEX=DFB NTC_LIMIT=40000 timeout 2000 python3 ntcrun.py t/cy/Main.bas "ide:\n${W}mkdir work\n${W}cv ide\n${W}cd games\n${W}crunch\n${W}${W}${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
o2=$(NTC_UNIDOS=IDE,SD,DFB,ZERO NTC_UNIDOS_NOEX=DFB NTC_LIMIT=30000 timeout 2000 python3 ntcrun.py t/cy/Main.bas "cv dfb:\n${W}drive\n${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
if echo "$o" | grep -q "^drive C: --> IDE:$" && echo "$o" | grep -q "^IDE:WORK/ made" && [ -d t/files/IDE/WORK ] && echo "$o" | grep -q "^Crunch: 450015000" && echo "$o" | grep -q "^\[CRUNCH.COM ended\]" \
  && echo "$o2" | grep -q "^drive C: --> DFB:" && echo "$o2" | grep -q "^  C: --> DFB:" && echo "$o2" | grep -q "^  IDE:     Emulated IDE  *120M free" && echo "$o2" | grep -q "^  ZERO:    Emulated ZERO"; then echo "ok   CyborgOS UniDOS: IDE: alone, MKDIR, CD IDE, a plain .COM, CD DFB:, DRIVE"; else echo "FAIL CyborgOS UniDOS: IDE: alone, MKDIR, CD IDE, a plain .COM, CD DFB:, DRIVE"; echo "$o" | tail -14; echo "$o2" | tail -14; fail=1; fi
# RMDIR: an empty folder only (UniDOS's |ERA takes a folder with all it holds)
o=$(NTC_UNIDOS=IDE NTC_LIMIT=40000 timeout 2000 python3 ntcrun.py t/cy/Main.bas "ide:\n${W}mkdir old\n${W}rmdir games\n${W}rmdir old\n${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
if echo "$o" | grep -q "^IDE:GAMES/ is not empty" && echo "$o" | grep -q "^IDE:OLD/ removed" && [ -d t/files/IDE/GAMES ] && [ ! -e t/files/IDE/OLD ]; then echo "ok   CyborgOS UniDOS: RMDIR"; else echo "FAIL CyborgOS UniDOS: RMDIR"; echo "$o" | tail -12; fail=1; fi
# COPY into a folder (its name, or name/ - never written over: once COPY made a file of the folder,
# its delete answered Y and UniDOS took the folder and all it held); a CP/M delete (ERA) of a
# folder: the hypervisor answers N - only RMDIR's (BDOS 30 op 8) may take one
mkdir -p t/files/IDE/KEEP; printf 'keep\r\n' > t/files/IDE/KEEP/K.TXT; printf 'one\r\n' > t/files/IDE/S.TXT; printf 'two\r\n' > t/files/IDE/T.TXT
o=$(NTC_UNIDOS=IDE NTC_LIMIT=40000 timeout 2000 python3 ntcrun.py t/cy/Main.bas "ide:\n${W}copy s.txt keep\n${W}copy t.txt keep/\n${W}copy *.txt keep\n${W}era keep\n${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
if [ -d t/files/IDE/KEEP ] && [ -f t/files/IDE/KEEP/K.TXT ] && [ "$(head -c 3 t/files/IDE/KEEP/S.TXT)" == "one" ] && [ -f t/files/IDE/KEEP/T.TXT ] && echo "$o" | grep -q "^2 of 2 files copied"; then echo "ok   CyborgOS COPY into a folder, a folder never deleted by ERA"; else echo "FAIL CyborgOS COPY into a folder"; echo "$o" | tail -16; ls -laR t/files/IDE | head -20; fail=1; fi
# COPY v1:name . - to where this slot is (CV IDE:, CD KEEP, then from A: to .)
printf 'dot\r\n' > t/files/A/DOT.TXT
o=$(NTC_UNIDOS=IDE NTC_LIMIT=40000 timeout 2000 python3 ntcrun.py t/cy/Main.bas "ide:\n${W}cd keep\n${W}copy a:dot.txt .\n${W}${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
if [ "$(head -c 3 t/files/IDE/KEEP/DOT.TXT 2>/dev/null)" == "dot" ]; then echo "ok   CyborgOS COPY a:name . (here: a folder)"; else echo "FAIL CyborgOS COPY a:name ."; echo "$o" | tail -10; fail=1; fi
rm -f t/files/A/DOT.TXT t/files/IDE/KEEP/DOT.TXT
# COPY's count with a file over 32K (its byte count once went into an Integer: "0 of 1 copied")
head -c 40000 /dev/zero | tr '\0' y > t/files/IDE/BIGF.DAT
o=$(NTC_UNIDOS=IDE NTC_LIMIT=40000 timeout 2000 python3 ntcrun.py t/cy/Main.bas "ide:\n${W}copy bigf.* keep\n${W}${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
if echo "$o" | grep -q "^1 of 1 files copied" && cmp -s -n 40000 t/files/IDE/BIGF.DAT t/files/IDE/KEEP/BIGF.DAT; then echo "ok   CyborgOS COPY a file over 32K: counted"; else echo "FAIL CyborgOS COPY a file over 32K"; echo "$o" | tail -10; fail=1; fi
rm -f t/files/IDE/BIGF.DAT t/files/IDE/KEEP/BIGF.DAT
rm -rf t/files/IDE/KEEP t/files/IDE/S.TXT t/files/IDE/T.TXT
# FLOPPY (the harness's floppy controller, NTC_FDC: .DSK images in drives A and B): a data format
# disc listed, its files (one over 16K, one with an AMSDOS header) copied into a folder it makes,
# each the disc's records exactly; a system format disc (a user 3 file); no disc in the drive
rm -rf t/files/IDE/FLOP
python3 -c "
import ntcrun, random
random.seed(5); big = bytes(random.randrange(256) for _ in range(20864)); g = bytes(range(256)) * 4
ntcrun.make_dsk('t/fda.dsk', [(0, 'BIG.DAT', big), (0, 'READ.TXT', b'floppy text\\r\\n\\x1a'), (0, 'GAME.BIN', ntcrun.amsdos_header(g, 0x4000) + g)])
ntcrun.make_dsk('t/fdb.dsk', [(0, 'READ.TXT', b'sys\\r\\n'), (3, 'OTHER.DAT', big)], 'system')
open('t/big.dat', 'wb').write(big); open('t/game.bin', 'wb').write(ntcrun.amsdos_header(g, 0x4000) + g)"
o=$(NTC_UNIDOS=IDE NTC_FDC=t/fda.dsk,t/fdb.dsk NTC_LIMIT=60000 timeout 2000 python3 ntcrun.py t/cy/Main.bas "ide:\n${W}floppy dfa flop\n${W}${W}floppy fdb\n${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
o2=$(NTC_FDC=t/fda.dsk NTC_LIMIT=100000 timeout 3000 python3 ntcrun.py t/cy/Main.bas "floppy a\n${W}floppy b\n${W}floppy a b:img.dsk\n${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
if echo "$o2" | grep -q "^BIG.DAT  *20864" && echo "$o2" | grep -q "^3 files, 22K on A (data format)" && echo "$o" | grep -q "^IDE:FLOP/ made" && echo "$o" | grep -q "^GAME.BIN to IDE:FLOP/GAME.BIN: 1152 bytes" && echo "$o" | grep -q "^3 of 3 files copied" \
  && cmp -s -n 20864 t/big.dat t/files/IDE/FLOP/BIG.DAT && cmp -s -n 1152 t/game.bin t/files/IDE/FLOP/GAME.BIN && echo "$o" | grep -q "^OTHER.DAT  *20864  (user 3)" && echo "$o" | grep -q "on FDB (system format)" && echo "$o2" | grep -q "^no disc in B" \
  && echo "$o2" | grep -q "^A to B:IMG.DSK: 40 tracks, 194816 bytes" && python3 -c "
import ntcrun, sys; x = ntcrun.Fdc.load('t/fda.dsk'); y = ntcrun.Fdc.load('t/files/B/IMG.DSK')
sys.exit(0 if open('t/files/B/IMG.DSK', 'rb').read(34) == b'EXTENDED CPC DSK File\\r\\nDisk-Info\\r\\n' and all(sorted((q[2], q[4]) for q in x[k]) == sorted((q[2], q[4]) for q in y[k]) for k in x) else 1)"; then echo "ok   CyborgOS FLOPPY: a disc listed, INSTALL into a folder, DSK (its controller driven)"; else echo "FAIL CyborgOS FLOPPY"; echo "$o" | tail -16; echo "$o2" | tail -10; fail=1; fi
rm -rf t/fda.dsk t/fdb.dsk t/big.dat t/game.bin t/files/IDE/FLOP t/files/B/IMG.DSK
# FLOPPY the other way (FLOPPY from A, as COPY): a folder's files onto a data disc (READ.TXT there
# replaced; PROG.BIN's AMSDOS header with it - the disc ROM's copy, BDOS 30 #C7; HUGE.DAT 3
# extents), then read back - each the same as its source to its end; a .DSK image onto a disc with
# nothing on it (each track formatted as the image has it), its sectors the image's
rm -rf t/files/IDE/SRC t/files/IDE/BACK t/fdn.dsk; mkdir -p t/files/IDE/SRC
python3 -c "
import ntcrun, random
random.seed(9); d = bytes(random.randrange(256) for _ in range(3000))
open('t/files/IDE/SRC/PROG.BIN', 'wb').write(ntcrun.amsdos_header(d, 0x4000) + d)
open('t/files/IDE/SRC/READ.TXT', 'wb').write(b'new text\r\n' * 30)
open('t/files/IDE/SRC/HUGE.DAT', 'wb').write(bytes(random.randrange(256) for _ in range(40000)))
ntcrun.make_dsk('t/fdw.dsk', [(0, 'BIG.DAT', bytes(range(256)) * 20), (0, 'READ.TXT', b'old\r\n')])"
o=$(NTC_UNIDOS=IDE NTC_FDC=t/fdw.dsk,t/fdn.dsk NTC_LIMIT=120000 timeout 3000 python3 ntcrun.py t/cy/Main.bas "floppy ide:src a\n${W}${W}floppy a ide:back\n${W}${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
o2=$(NTC_UNIDOS=IDE NTC_FDC=t/fdw.dsk,t/fdn.dsk NTC_LIMIT=150000 timeout 3000 python3 ntcrun.py t/cy/Main.bas "floppy a ide:img.dsk\n${W}floppy ide:img.dsk b\n${W}${W}floppy b\n${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
r=ok
for x in PROG.BIN READ.TXT HUGE.DAT; do n=$(stat -c %s t/files/IDE/SRC/$x); cmp -s -n $n t/files/IDE/SRC/$x t/files/IDE/BACK/$x || r="no: $x"; done
echo "$o" | grep -q "^3 of 3 files copied" || r="no: 3 of 3"; echo "$o" | grep -q "^4 of 4 files copied" || r="no: 4 of 4 back"
echo "$o2" | grep -q "^IDE:IMG.DSK to B: 40 tracks$" || r="no: image to B"; echo "$o2" | grep -q "^4 files, .* on B (data format)" || r="no: B listed"
python3 -c "
import ntcrun, sys; x = ntcrun.Fdc.load('t/fdw.dsk'); y = ntcrun.Fdc.load('t/fdn.dsk')
sys.exit(0 if all(sorted((q[2], bytes(q[4])) for q in x[k]) == sorted((q[2], bytes(q[4])) for q in y[k]) for k in x) else 1)" || r="no: B's sectors"
if [ "$r" == ok ]; then echo "ok   CyborgOS FLOPPY onto a disc: a folder's files, a .DSK image"; else echo "FAIL CyborgOS FLOPPY onto a disc $r"; echo "$o" | tail -14; echo "$o2" | tail -10; fail=1; fi
rm -rf t/fdw.dsk t/fdn.dsk t/files/IDE/SRC t/files/IDE/BACK t/files/IDE/IMG.DSK
# a plain .COM on a RAM disc runs by its name (the RAM disc driver's own open: NAME.CYB, else
# NAME.COM): FLOPPY A E: puts CRUNCH.COM there, E:, CRUNCH; then FLOPPY GAMES A (onto it): a folder needs UniDOS
python3 -c "
import ntcrun
ntcrun.make_dsk('t/fdc.dsk', [(0, 'CRUNCH.COM', open('t/cy/CRUNCH.COM', 'rb').read())])"
o=$(NTC_FDC=t/fdc.dsk NTC_LIMIT=60000 timeout 2000 python3 ntcrun.py t/cy/Main.bas "ramdisc e 64\n${W}floppy a e:\n${W}e:\n${W}crunch\n${W}${W}floppy games a\n${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
if echo "$o" | grep -q "^CRUNCH.COM to E:CRUNCH.COM: 1024 bytes" && echo "$o" | grep -q "^Crunch: 450015000" && echo "$o" | grep -q "^\[CRUNCH.COM ended\]" && echo "$o" | grep -q "^Folders need UniDOS"; then echo "ok   CyborgOS a plain .COM run from a RAM disc"; else echo "FAIL CyborgOS a plain .COM run from a RAM disc"; echo "$o" | tail -12; fail=1; fi
rm -f t/fdc.dsk
# a RAM disc's letter that had a path: the RAM disc wins (RAMDISC drops the path; CD F shows none,
# DIR F lists the RAM disc, not IDE:); CD IDE: from it takes another letter
o=$(NTC_UNIDOS=IDE NTC_LIMIT=50000 timeout 2000 python3 ntcrun.py t/cy/Main.bas "cv f: ide:\n${W}ramdisc f 64\n${W}${W}cv f\n${W}dir\n${W}cv ide:\n${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
if echo "$o" | grep -q "^F: RAM disc, 64K" && echo "$o" | grep -q "^drive F:$" && ! echo "$o" | grep -q "^GAMES/" && echo "$o" | grep -q "^drive C: --> IDE:$"; then echo "ok   CyborgOS UniDOS: a RAM disc's letter has no path"; else echo "FAIL CyborgOS UniDOS: a RAM disc's letter has no path"; echo "$o" | tail -16; fail=1; fi
printf 'line one\r\nline two\r\n' > t/files/A/README.TXT; python3 -c "open('t/files/A/NOTES.TXT', 'wb').write(b'n' * 300)"; rm -f t/files/A/FILES.DIR
python3 -c "
import ntcrun
d = open('t/cy/CPMT.COM', 'rb').read(); open('t/files/A/CPMT.CYB', 'wb').write(ntcrun.amsdos_header(d, 0x100) + d)"
o=$(NTC_UNIDOS=IDE timeout 600 python3 ntcrun.py t/cy/Main.bas "run cpmt readme.txt b:*.dat\n${W}helx\\x7flo\n${W}q${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)
if echo "$o" | grep -qF "D=README  TXT 01" && echo "$o" | grep -qF "D=NOTES   TXT 03" && echo "$o" | grep -qF "[CPMT.CYB ended]"; then echo "ok   CyborgOS UniDOS: directory search (17, 18) with no FILES.DIR"; else echo "FAIL CyborgOS UniDOS: directory search (17, 18) with no FILES.DIR"; echo "$o" | tail -14; fail=1; fi
rm -rf t/files/IDE t/files/SD t/files/A/L2.TXT t/files/A/CPMT.CYB t/files/A/README.TXT t/files/A/NOTES.TXT
# Option Memory in a #If: only the one that is on counts (CyborgOS: fewer pages with Library: ROM)
printf '#If NTC_LIBRARY_ROM Then\nOption Memory CPCExpansion 33\n#Else\nOption Memory CPCExpansion 193\n#End If\nPrint 1\n' > t/memif.bas
a1=$(node cli.js t/memif.bas --platform=cpcfw 2>/dev/null | grep "^NTC_MEMBANKS"); a2=$(node cli.js t/memif.bas --platform=cpcfw --library=rom 2>/dev/null | grep "^NTC_MEMBANKS")
if echo "$a1" | grep -q "equ 48" && echo "$a2" | grep -q "equ 8"; then echo "ok   Option Memory in #If"; else echo "FAIL Option Memory in #If: $a1 / $a2"; fail=1; fi
check "CyborgOS 4 slots" "^CyborgOS ended, " "$(timeout 600 python3 ntcrun.py t/cy/Main.bas "run 2 CRUNCH\nrun 3 TICKER\nfg 3\n${W}xwait\nquit\n" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 2>&1)"
check "CyborgOS 2 slots (320K)" "^CyborgOS ended, " "$(timeout 600 python3 ntcrun.py t/cy/Main.bas "run 2 CRUNCH\nrun TICKER\n${W}xwait\nquit\n" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=320 2>&1)"
check "CyborgOS refused on 128K" "^CyborgOS needs 320K" "$(timeout 100 python3 ntcrun.py t/cy/Main.bas "x" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=128 2>&1)"
check "CyborgOS 4 slots, Library: ROM" "^CyborgOS ended, " "$(timeout 600 python3 ntcrun.py t/cy/Main.bas "run 2 CRUNCH\nrun 3 TICKER\nfg 3\n${W}xwait\nquit\n" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 --library=rom 2>&1)"
# Graphics: XOR lines in modes 0, 1, 2 on #C000 and on #4000 (double buffering), cpc and cpcmin
for pl in cpc cpcmin; do
  cp gfx/lines.bas t/; o=$(timeout 300 python3 ntcrun.py t/lines.bas '' --platform=$pl 2>&1 | grep -v "^--- ")
  if [ "$o" == "$(cat ref/gfx_lines.txt)" ]; then echo "ok   Graphics lines $pl"; else echo "FAIL Graphics lines $pl"; echo "$o" | head -4; fail=1; fi
done
# Graphics on the ZX Spectrum Next (zxn, Layer 2): the pixels of the buffer shown - one buffer: 518;
# double buffering, a line drawn twice (off again), one of 91 flipped: 91
for c in "1 518 0" "2 91 -1"; do
  set -- $c; cp gfx/lines_zxn.bas t/
  o=$(NTC_SHOT=t/lz.png timeout 120 python3 ntcrun.py t/lines_zxn.bas "$1" --platform=zxn 2>&1)
  echo "$o" | grep -q "^--- layer 2: $2 pixels set" && echo "$o" | grep -q "^width320 back0 buffering$3" && echo "ok   Graphics lines zxn ($2)" || { echo "FAIL Graphics lines zxn ($2)"; echo "$o" | tail -4; fail=1; }
done
# For loops up to 32767 / down to -32768 end (they looped for ever when the step wrapped)
for m in --turbo ""; do
  cp for_end.bas t/; o=$(timeout 60 python3 ntcrun.py t/for_end.bas '' --platform=test $m 2>&1 | grep -v "^--- " | tr '\n' ' ')
  if [ "$o" == "a8-32768 b3 c8 d9 e2 f3 g55 h22 " ]; then echo "ok   for at the Integer ends ${m:-normal}"; else echo "FAIL for at the Integer ends ${m:-normal}: $o"; fail=1; fi
done
# the sort timing demo: 300 nodes, a turbo and a normal sort, both in order
cp $P/sorttime.bas t/ex/
for pl in cpc cpcmin cpm test; do
  o=$(timeout 300 python3 ntcrun.py t/ex/sorttime.bas '300\nTNX' --platform=$pl 2>&1)
  if [ "$(echo "$o" | grep -c '^in order')" == "2" ] && ! echo "$o" | grep -q "NOT IN"; then echo "ok   sorttime $pl"; else echo "FAIL sorttime $pl"; echo "$o" | tail -5; fail=1; fi
done
# Private Paged variables and local memory in an overlay class (with a List); both modes
for m in --turbo ""; do
  for pl in cpcmin cpcfw; do
    rm -rf t/files t/pvar; mkdir -p t/pvar; cp pvar/* t/pvar/
    o=$(timeout 300 python3 ntcrun.py t/pvar/Main.bas '' t/pvar/Shop.cls --platform=$pl $m 2>&1 | grep -v "^--- ")
    if [ "$o" == "$(cat ref/pvar.txt)" ]; then echo "ok   paged variables $pl ${m:-normal}"; else echo "FAIL paged variables $pl ${m:-normal}"; echo "$o" | head -5; fail=1; fi
  done
done
printf 'Private Paged x As Integer\nPublic Sub A()\nx = 1\nEnd Sub\n' > t/pvar/Rx.cls; printf 'Rx.A\n' > t/pvar/rmain.bas
node cli.js t/pvar/rmain.bas t/pvar/Rx.cls --platform=cpcmin 2>&1 >/dev/null | grep -q "go in a class in a page" && echo "ok   paged variables refused outside an overlay class" || { echo "FAIL paged variables refused"; fail=1; }
# arrays after the program (not in its file): the file stays small, too big a set stops with a message
printf 'Dim a(5000) As Integer\na(4999) = 7\nPrint "a"; a(4999); a(0)\n' > t/bss1.bas
node cli.js t/bss1.bas --platform=cpm > t/bss1.asm && (cd t && ${SJASMPLUS:-sjasmplus} --nologo --msg=err --raw=bss1.com bss1.asm > /dev/null)
if [ $(stat -c %s t/bss1.com) -lt 2000 ]; then echo "ok   arrays not in the file ($(stat -c %s t/bss1.com) bytes)"; else echo "FAIL arrays not in the file"; fail=1; fi
check "arrays after the program run" "^a70" "$(timeout 60 python3 ntcrun.py t/bss1.bas '' --platform=cpm 2>&1)"
printf 'Dim a(30000) As Integer\nPrint "ran"\n' > t/bss2.bas
for pl in cpm cpc cpcfw; do check "arrays too big $pl" "^Not enough memory for the arrays" "$(timeout 60 python3 ntcrun.py t/bss2.bas '' --platform=$pl 2>&1)"; done
mkdir -p t/via; cp via/* t/via/; o=$(timeout 100 python3 ntcrun.py t/via/Main.bas 'Bo\n7\n' t/via/StdIO.cls --platform=test 2>&1 | grep -v "^--- ")
if [ "$o" == "$(cat ref/via.txt)" ]; then echo "ok   own StdIO"; else echo "FAIL own StdIO"; fail=1; fi
# build/: regenerate, then check every file assembles the way build.bat does it
SJ=${SJASMPLUS:-sjasmplus}
node genbuild.js > /dev/null || fail=1
rm -rf t/bc; mkdir -p t/bc; cp -r ../build/cpc ../build/cpcmin ../build/cpcfw ../build/cpm ../build/test ../build/cpcrom ../build/cpcminrom ../build/cpcfwrom ../build/rom t/bc/
b=0; n=0
for p in cpc cpcmin cpcfw cpcrom cpcminrom cpcfwrom cpm test rom; do
  for f in t/bc/$p/*.ASM; do
    g=$(basename $f .ASM); n=$((n+1))
    case $p in cpm) o="--raw=$g.COM";; test) o="--raw=$g.BIN";; *) o="";; esac
    (cd t/bc/$p && $SJ --nologo --msg=err $o $g.ASM > /dev/null) || { echo "FAIL build $p/$g"; b=1; }
  done
  if [ $p == cpm ]; then x=COM; elif [ $p == rom ]; then x=ROM; else x=BIN; fi
  [ $(ls t/bc/$p/*.$x 2>/dev/null | wc -l) == $(ls t/bc/$p/*.ASM | wc -l) ] || { echo "FAIL build $p: not every file written"; b=1; }
done
if [ $b == 0 ]; then echo "ok   build/ ($n files assemble)"; else echo "FAIL build/"; fail=1; fi
# the overlay files from an AMSDOS build carry an AMSDOS header (AMSDOS won't CAS IN DIRECT a file without one)
o=$(python3 -c "import ntcrun; print([ntcrun.amsdos_header_of(open('t/bc/cpcmin/'+f,'rb').read()) for f in ('OVERLAYS.001','OVERLAYS.002')])" 2>&1)
if echo "$o" | grep -q "^\[(16384, [0-9]*), (16384, [0-9]*)\]"; then echo "ok   overlay files have AMSDOS headers"; else echo "FAIL overlay files have AMSDOS headers: $o"; fail=1; fi
# build/dsk/: a CPC data format disc per platform with its programs (needs cpmtools + libdsk)
if command -v dskform > /dev/null && command -v cpmcp > /dev/null; then
  SJASMPLUS=$SJ bash gendsk.sh > t/dsk.txt 2>&1 && echo "ok   build/dsk ($(grep -c files t/dsk.txt) images)" || { echo "FAIL build/dsk"; cat t/dsk.txt; fail=1; }
else
  echo "skip build/dsk (no cpmtools / libdsk)"
fi
# Option Reserve: a range above the program assembles, one at its start stops the assembly, one
# inside it is built round (res4: the program goes on after #02FF and runs)
printf 'Option Reserve &HC000, &H4000\nPrint 1\n' > t/res1.bas; printf 'Option Reserve &H0100, &H100\nPrint 1\n' > t/res2.bas
printf 'Option Reserve &H0200, &H100\nPrint 1\n' > t/res4.bas
check "Option Reserve built round" "^1$" "$(timeout 100 python3 ntcrun.py t/res4.bas '' --platform=cpm 2>&1)"
node cli.js t/res1.bas --platform=cpm > t/res1.asm && (cd t && $SJ --nologo --msg=err --raw=res1.com res1.asm > /dev/null) && r1=ok || r1=bad
node cli.js t/res2.bas --platform=cpm > t/res2.asm && (cd t && $SJ --nologo --msg=err --raw=res2.com res2.asm 2>&1 | grep -q "Option Reserve #0100-#01FF") && r2=ok || r2=bad
if [ $r1 == ok ] && [ $r2 == ok ]; then echo "ok   Option Reserve"; else echo "FAIL Option Reserve ($r1 $r2)"; fail=1; fi
# Option Stack: End comes back to the caller's stack on every host platform; a stack in the program stops the assembly
printf 'Option Stack &H9000\nPrint "stack ok"\n' > t/stk1.bas
for pl in test cpm cpcfw; do check "Option Stack $pl" "stack ok" "$(timeout 60 python3 ntcrun.py t/stk1.bas '' --platform=$pl 2>&1)"; done
printf 'Option Stack &H0150\nPrint 1\n' > t/stk2.bas
node cli.js t/stk2.bas --platform=cpm > t/stk2.asm && (cd t && $SJ --nologo --msg=err --raw=stk2.com stk2.asm 2>&1 | grep -q "Option Stack #0150") && echo "ok   Option Stack in the program" || { echo "FAIL Option Stack in the program"; fail=1; }
# the Small C sieve (compare/smallc) runs on the CP/M host and finds 1007 primes
o=$(timeout 200 python3 -c "import ntcrun; h = ntcrun.Host('cpm', open('t/bc/cpm/SIEVEC.COM', 'rb').read(), 0x100, 'xx'); h.run(); print(h.scr.text()); print('--- halted' if h.m.halted else '--- NOT halted')" 2>&1)
check "Small C sieve cpm" "^01007" "$o"
for f in ../js/ntc_parser.js ../js/ntc_compiler.js ../js/ntc_flavour_js.js ../js/ntc_flavour_loco.js ../js/ntc_gui.js ../js/ntc_lib.js ../js/ntc_examples.js; do
  node -e "require('acorn').parse(require('fs').readFileSync('$f','utf8'),{ecmaVersion:5})" || { echo "FAIL ES5 $f"; fail=1; }
done
echo "ES5 checked"
rm -f *.asm *.bin *.sym; rm -rf t/*
[ $fail == 0 ] && echo "ALL PASS" || echo "SOME FAILED"
