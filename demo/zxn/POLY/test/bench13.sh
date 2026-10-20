#!/bin/sh
# bench13.sh - the city view test (t13) with the engine as it is now: its frame rate
cd "$(dirname "$0")/.." && cp E3.cls E3Data.cls test/t13/ && node test/nb.js test/t13 | tail -1 && python3 test/fpsv.py test/t13/build/T13.NEX | head -1
