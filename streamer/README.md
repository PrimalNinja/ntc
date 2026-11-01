# Streamer - a UniDOS node: devices as paths

NTC BASIC's sibling project: the node ROM that gives Locomotive BASIC (and any CPC program) the VDPs,
the Pi's stores and sound as UniDOS devices, written to and read from like files. One device a VDP
target (V9938, V9990, ZXN, MD, PI 720 / 1080 / 2160), each its own commands and asset format; the
Pi's V9990 and the others emulated behind the same interface as the real chip.

- src/      the node's source (Z80, sjasmplus)
- build/    build.bat and the ROM output
- docs/     the design, the device protocols, ANALYSIS.LOG
- test/     the tests (the node against NTC's harness and its V9990 model)
- _old/     the 2023 node as it was (proved DAC sound from BASIC; nothing of it is kept)
