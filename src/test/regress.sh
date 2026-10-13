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
# Interrupt hook: normal mode only (turbo has no interrupts)
o=$(timeout 60 python3 cpcrun.py hook.bas '' 2>&1 | grep -v "^--- ")
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
  cp $P/class_demo/* t/cls/; o=$(timeout 100 python3 cpcrun.py t/cls/Main.bas 'x' t/cls/Counter.cls $m 2>&1); check "class $mn" "x=12" "$o"
  cp $P/sieve.bas t/ex/; o=$(timeout 100 python3 cpcrun.py t/ex/sieve.bas 'x' $m 2>&1); check "sieve $mn" "168 primes" "$o"
  cp $P/shellsort.bas t/ex/; o=$(timeout 100 python3 cpcrun.py t/ex/shellsort.bas '300\ntnx' $m 2>&1); check "shellsort $mn" "^6 8 9 26 26 31 34 34 34 35" "$o"
  cp $P/sievetime.bas t/ex/; o=$(timeout 200 python3 cpcrun.py t/ex/sievetime.bas '1\ntnx' $m 2>&1); check "sievetime $mn" "1007 primes below 8000" "$o"
  cp $P/guide.bas t/ex/; o=$(timeout 100 python3 cpcrun.py t/ex/guide.bas 'Ann\nx' $m 2>&1); check "guide $mn" "ANN!" "$o"
  for f in for gs gs2 scr0 scr2 diag1 diag2 vbprint cmptext tiny wrap; do
    o=$(timeout 40 python3 cpcrun.py $f.bas '' $m 2>&1 | grep -v "^--- ")
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
    o=$($R $f.bas '' --platform=$pl $m 2>&1 | grep -v "^--- ")
    rf=ref/$f.txt; case "$m" in *library=rom*) [ -f ref/${f}_rom.txt ] && rf=ref/${f}_rom.txt;; esac   # ROM: strings up to 255
    if [ "$o" == "$(cat $rf)" ]; then echo "ok   $f $mn"; else echo "FAIL $f $mn"; fail=1; fi
  done
}
for pl in test cpcfw cpm; do for m in --turbo ""; do host $pl "$m"; done; done
# Library: ROM (cpcfw): the keywords in NTCFW.ROM (the harness puts its image in slot 6)
for pl in cpc cpcmin cpcfw; do for m in "--turbo --library=rom" "--library=rom"; do host $pl "$m"; done; done
# StdIO / System platform classes on every platform, and a project's own StdIO
for pl in cpc cpcmin test cpcfw cpm; do
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
  for c in "fs_cpm cpm fs_cpm" "fs_fw cpcfw fs_fw" "fs_fw2 cpcfw fs_fw2" "fs_fw2 cpcfw fs_fw2c --called" "fs_none test fs_none" "fs_none cpc fs_none_cpc" "fs_fw cpcmin fs_fw" "fs_fw2 cpcmin fs_fw2"; do
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
cp $P/memmap.bas t/ex/
check "memmap cpc 64K" "^After Free: 0 pages free" "$(timeout 200 python3 ntcrun.py t/ex/memmap.bas '~x~x' --platform=cpc --ram=64 2>&1)"
check "memmap cpc 576K" "^Bank 8 " "$(timeout 200 python3 ntcrun.py t/ex/memmap.bas '~x~x' --platform=cpc --ram=576 2>&1)"
check "memmap cpc 4MB" "^&7E DD---" "$(timeout 300 python3 ntcrun.py t/ex/memmap.bas '~x~x' --platform=cpc --ram=4160 2>&1)"
check "memmap cpcfw 128K" "^Pages UCU--" "$(timeout 200 python3 ntcrun.py t/ex/memmap.bas '~x~x' --platform=cpcfw 2>&1)"
# a program ending near #4000: the page tables only take what fits, so fewer pages
printf 'Option Reserve &H4000, &H4000\nDim big(5800) As Integer\nIf Memory.Pages() > 1 And Memory.Pages() < 257 And Memory.TableEnd() <= &H4000 Then Print "tables fit"\n' > t/lim.bas
check "memory tables near #4000" "^tables fit" "$(timeout 200 python3 ntcrun.py t/lim.bas '' --platform=cpc --ram=4160 2>&1)"
# Option Memory Small: a heap in main RAM, on every platform; both modes
for m in --turbo ""; do
  for pl in cpc cpcfw cpm test; do
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
for pl in test cpm; do check "memmap $pl" "^No paging - heap" "$(timeout 200 python3 ntcrun.py t/ex/memmap.bas '~x~x' --platform=$pl 2>&1)"; done
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
# Graphics: XOR lines in modes 0, 1, 2 on #C000 and on #4000 (double buffering), cpc and cpcmin
for pl in cpc cpcmin; do
  cp gfx/lines.bas t/; o=$(timeout 300 python3 ntcrun.py t/lines.bas '' --platform=$pl 2>&1 | grep -v "^--- ")
  if [ "$o" == "$(cat ref/gfx_lines.txt)" ]; then echo "ok   Graphics lines $pl"; else echo "FAIL Graphics lines $pl"; echo "$o" | head -4; fail=1; fi
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
# Option Reserve: a range the program stays out of assembles, one it reaches into stops the assembly
printf 'Option Reserve &HC000, &H4000\nPrint 1\n' > t/res1.bas; printf 'Option Reserve &H0200, &H100\nPrint 1\n' > t/res2.bas
node cli.js t/res1.bas --platform=cpm > t/res1.asm && (cd t && $SJ --nologo --msg=err --raw=res1.com res1.asm > /dev/null) && r1=ok || r1=bad
node cli.js t/res2.bas --platform=cpm > t/res2.asm && (cd t && $SJ --nologo --msg=err --raw=res2.com res2.asm 2>&1 | grep -q "Option Reserve #0200-#02FF") && r2=ok || r2=bad
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
