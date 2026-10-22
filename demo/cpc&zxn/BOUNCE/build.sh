#!/bin/bash
# build.sh - BOUNCE.CYB: the ball (tools/mkball.py: BallGfx.cls from gfx/ball.png), then the
# program for NTC's cyborgos platform. The one file runs on CyborgOS on the CPC and on the Next.
#   bash build.sh <NTC src folder>
# Out: build/BOUNCE.CYB (and its .ASM, .sym)
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
set -e
NTC=$(cd "${1:?the NTC src folder}" && pwd)
HERE=$(cd "$(dirname "$0")" && pwd)
mkdir -p $HERE/build
python3 $HERE/tools/mkball.py
cd $HERE
node $NTC/test/cli.js BOUNCE.bas ZxnScr.cls CpcScr.cls BallGfx.cls --platform=cyborgos --name=BOUNCE > build/BOUNCE.ASM 2> build/err.txt || { grep -v WARN build/err.txt; exit 1; }
grep -v WARN build/err.txt || true
(cd build && sjasmplus --nologo --msg=err --sym=BOUNCE.sym BOUNCE.ASM)
rm -f build/err.txt
grep "^ntc_free" build/BOUNCE.sym
ls -la build/BOUNCE.CYB
