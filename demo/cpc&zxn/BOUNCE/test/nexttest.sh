#!/bin/bash
# nexttest.sh - BOUNCE on CyborgOS-Next in NTC's emulator (nextemu's picture; test/cosbot.py is
# the driver, the SD card a folder): CD BOUNCE, RUN 2 BOUNCE, Shift + 2, Shift + 1, Shift + 2, Q.
#   bash test/nexttest.sh <dir with CyborgOS-Next's NTC.NEX + Main.sym> <out prefix>
# (the NEX and its .sym from CyborgOS's tools/nexarc/build.sh: build/next/CYBORGOS.NEX, .sym)
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
set -e
COS=${1:?the CyborgOS-Next NEX folder}; OUT=${2:?out prefix}
HERE=$(cd "$(dirname "$0")/.." && pwd)
SD=$(mktemp -d); mkdir -p $SD/BOUNCE; cp $HERE/build/BOUNCE.CYB $SD/BOUNCE/
python3 $HERE/test/cosbot.py $COS 'CD BOUNCE\nRUN 2 BOUNCE\n' sd=$SD frames=1600 \
  keys='600-606:0,25;900-906:0,24;1100-1106:0,25;1350-1354:16' shots=850,1000,1300,1550 texts=1590 out=$OUT
rm -rf $SD
