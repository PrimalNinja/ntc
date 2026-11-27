#!/bin/bash
# gfxregress.sh - the Graphics class on the platforms whose class is BASIC (tools/graphics/gen.js):
# test/graphics/gfx.bas built for each, run where NTC's tests have a machine for it, and the
# picture compared dot for dot with test/graphics/expect.py. The X68000, the MEGA65 and the TI-89
# are built and assembled only (set NTC_X68CORE / NTC_XEMU and run their own tools for a picture).
#   bash test/gfxregress.sh        (from test/; the same environment as the other regressions)
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
cd "$(dirname "$0")"
fail=0; G=graphics; T=t/gfx; mkdir -p $T
say() { if echo "$2" | grep -q "PASS"; then echo "ok   Graphics $1"; else echo "FAIL Graphics $1"; echo "$2" | tail -2; fail=1; fi; }

for p in trs80 system80 ti83 test baremetal; do say $p "$(timeout 900 python3 $G/z80mem.py $p 2>&1)"; done
for p in zxndot zxndotl; do say $p "$(timeout 900 python3 $G/dotmem.py $p 2>&1)"; done
for p in msx msxcard msx9990 sc3000 colecovision; do say $p "$(timeout 900 python3 $G/tmsmem.py $p 2>&1 | grep -v 'inks used')"; done

if [ -n "$NTC_EPCORE" ]; then
  node epbuild.js $G/gfx.bas --out=$PWD/$T/EP.COM --img >/dev/null 2>&1
  timeout 600 python3 eprun.py $T/EP.img --frames=3500 "--keys=300: ,400: " --shot=$T/ep.png >/dev/null 2>&1
  say "ep128 (128K)" "$(python3 $G/shot.py ep128 $T/ep.png 320 200 --at=64,42 --scale=2,1 --skip=0,0,79,7 2>&1)"
  node epbuild.js $G/gfx.bas --out=$PWD/$T/E64.COM --img --ram=64 >/dev/null 2>&1
  timeout 600 python3 eprun.py $T/E64.img --frames=3500 "--keys=300: ,400: " --shot=$T/e64.png >/dev/null 2>&1
  say "ep128 (an Enterprise 64: 64K)" "$(python3 $G/shot.py ep64 $T/e64.png 320 200 --at=64,42 --scale=2,1 --skip=0,0,79,7 2>&1)"
else echo "skip Graphics ep128 (NTC_EPCORE not set)"; fi

if [ -n "$NTC_AMIGACORE" ]; then
  node amigabuild.js $G/gfx.bas --out=$PWD/$T/AG.adf >/dev/null 2>&1
  timeout 900 python3 amigarun.py $T/AG.adf --model=A500 --frames=6000 --shot=$T/ami.png >/dev/null 2>&1
  say amiga "$(python3 $G/shot.py amiga $T/ami.png 640 256 --at=40,18 --min=600 --skip=0,0,79,7 2>&1)"
else echo "skip Graphics amiga (NTC_AMIGACORE not set)"; fi

if [ -n "$NTC_MDCORE" ]; then
  python3 mdbuild.py $G/gfx.bas --out=$PWD/$T/MG.md >/dev/null 2>&1
  timeout 600 python3 mdrun.py $T/MG.md --frames=1500 --shot=$T/md.png >/dev/null 2>&1
  say md "$(python3 $G/shot.py md $T/md.png 320 224 --skip=0,0,79,7 2>&1)"
else echo "skip Graphics md (NTC_MDCORE not set)"; fi

if [ -n "$NTC_TSUGARU" ]; then
  node townsbuild.js $G/gfx.bas --out=$PWD/$T/TG.bin >/dev/null 2>&1
  timeout 300 python3 townsrun.py $T/TG.bin --secs=25 --shot=$T/towns.png >/dev/null 2>&1
  say towns "$(python3 $G/shot.py towns $T/towns.png 256 240 --at=0,2 --scale=2,2 --skip=0,0,255,12 2>&1)"
else echo "skip Graphics towns (NTC_TSUGARU not set)"; fi

if [ -n "$NTC_NGCORE" ]; then
  node ngbuild.js $G/gfx.bas --out=$PWD/$T/NG.neo >/dev/null 2>&1
  timeout 600 python3 ngrun.py $T/NG.neo --frames=900 --shot=$T/ng.png >/dev/null 2>&1
  say neogeo "$(python3 $G/shot.py neogeo $T/ng.png 80 112 --at=0,8 --scale=4,2 --min=300 --skip=0,0,19,3 2>&1)"
else echo "skip Graphics neogeo (NTC_NGCORE not set)"; fi

if [ -n "$NTC_C64CORE" ]; then
  node c64build.js $G/gfx.bas --out=$PWD/$T/CG.PRG >/dev/null 2>&1
  timeout 800 python3 c64run.py $T/CG.PRG --frames=1500 --shot=$T/c64.png >/dev/null 2>&1
  say c64reu "$(python3 $G/shot.py c64reu $T/c64.png 80 50 --at=32,35 --scale=4,4 --min=600 --skip=0,0,15,1 2>&1)"
else echo "skip Graphics c64reu (NTC_C64CORE not set)"; fi

# built and assembled only
o=$(node x68build.js $G/gfx.bas --out=$PWD/$T/XG.xdf 2>&1); if echo "$o" | grep -q "bytes of program"; then echo "ok   Graphics x68000 builds"; else echo "FAIL Graphics x68000 build"; fail=1; fi
o=$(python3 m65build.py $G/gfx.bas --out=$PWD/$T/M65G.PRG 2>&1); if echo "$o" | grep -q "bytes"; then echo "ok   Graphics m65 builds"; else echo "FAIL Graphics m65 build"; fail=1; fi
node cli.js $G/gfx.bas --platform=ti89 > $T/t89.s 2>/dev/null; if ${NTC_VASM:-vasmm68k_mot} -spaces -Fbin -quiet -o $T/t89.bin $T/t89.s >/dev/null 2>&1; then echo "ok   Graphics ti89 builds"; else echo "FAIL Graphics ti89 build"; fail=1; fi
if [ $fail == 0 ]; then echo "ALL PASS"; else echo "FAILURES"; fi
exit $fail
