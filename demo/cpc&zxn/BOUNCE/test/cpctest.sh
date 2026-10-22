#!/bin/bash
# cpctest.sh - BOUNCE on the CPC's CyborgOS in NTC's harness (4MB): RUN 2 BOUNCE, Control + 2 to
# it, then what the screen holds at the end as a picture (both screens: test/shotm2.py).
#   bash test/cpctest.sh <NTC src> <CyborgOS folder> <out prefix> [extra typed text] [limit]
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
set -e
NTC=$(cd "${1:?NTC src}" && pwd); COS=$(cd "${2:?CyborgOS}" && pwd); OUT=${3:?out prefix}
HERE=$(cd "$(dirname "$0")/.." && pwd)
C=$COS/src/bas/cyborgos320kb
cd $NTC/test
T=t/bounce_$(basename $OUT); rm -rf $T; mkdir -p $T/cy $T/files/A
cp $C/*.bas $C/*.cls $T/cy/
cp $HERE/build/BOUNCE.CYB $T/files/A/
W=$(printf '~%.0s' $(seq 1 200))
NTC_SHOT=$OUT.bin NTC_FILES=$T/files NTC_LIMIT=${5:-900000} python3 ntcrun.py $T/cy/Main.bas \
  "run 2 bounce\n${W}{23,65}${W}${4}" $T/cy/Hyp.cls $T/cy/Hot.cls $T/cy/Ent.cls --platform=cpcfw --ram=4160 2>&1 | grep -v "^WARN" | grep -v "^ *$" | tail -30
python3 $HERE/test/shotm2.py $OUT.bin $OUT.png
