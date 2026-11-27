# NTC BASIC - the components, numbered (refer to them by number)

A component keeps its number. 48 to 52 are future components (no code yet). 53 on were added on
2026-11-26 for what had been built since the list was first written; they sit in their sections,
not at the end, so the numbers in a section are not all in a row.

## The compiler (src/js, runs in the browser IDE and under node)
1. ntc_parser.js - the parser (tokens, statements, expressions, classes, #If)
2. ntc_compiler.js - the compiler: threaded code, the keyword table, the memory model (pages, overlays,
   banks, Reserve and Safe, the C64's windows and lots), the library class join, the platform
   defines, the assembler source it writes (sjasmplus for the Z80, vasm for the 68000 and the
   6502 / 45GS02, nasm for the 80386)
3. ntc_lib.js - the library classes as text (generated from src/lib by test/gen.js)
4. ntc_examples.js - the examples (generated)
5. ntc_flavour_loco.js, ntc_flavour_js.js, ntc_flavour_php.js, ntc_flavour_natural.js - the Locomotive, JS, PHP and Natural flavours
6. ntc_gui.js, formRenderer.js, listRenderer.js, textEditor.js - the IDE (projects, modules, the
   editor, the forms designer)
7. src/ntc.html, src/css, src/3p - the IDE's page, styles and third-party pieces; hosted/ its
   published form (tools/hosted/build.js makes it)

## The runtime (src/asm)
8. ntc_lib.asm - the Z80 runtime: the keywords, strings, numbers, Long, the thread engine
9. ntc_lib_cpc.asm, ntc_lib_msx.asm, ntc_lib_nxt.asm, ntc_lib_dot.asm, ntc_lib_ep.asm - a machine's
   own parts (the CPC's banks and firmware - and the paging manager the Enterprise shares, the
   MSX's mapper, the Next's MMU and esxDOS, a Next dot command's pages from NextZXOS's allocator,
   the Enterprise's segments)
10. ntc_lib_vdp.asm - the V9938 / V9958 / V9990 and tilemap console pieces
11. ntc_lib_gen.asm - generated tables (from the compiler)
12. ntc_lib_68k.asm - the 68000 runtime (the Mega Drive, the X68000, the Neo Geo and Neo Geo CD,
    the Amiga, the TI-89 skeleton); ntc_lib_m65.asm - the 45GS02 and 6502 runtime (the MEGA65, and
    the Commodore 64 with an REU inside `ifd NTC_C64`: the windows, the lots)
53. ntc_lib_x86.asm - the 80386 runtime (the FM Towns): every section of the 68000 library in
    nasm, ESP the thread
54. neogeo_sound_z80.asm - the Neo Geo's Z80 sound driver (the M1 ROM: the SSG, FM registers,
    ADPCM-A samples, ADPCM-B songs, CD audio requests); not threaded code
13. The platform files ntc_plat_*.asm:
    - Z80: cpc, cpcfw, cpcmin, cpccard, cpc9990, cpm, cyborgos, cyborgoshh, msx, msxdos, msxcard,
      msx9990, zxn, zxndot, zxndotl, sc3000, colecovision, ep128, pcw16, ti83, trs80, system80,
      baremetal, test
    - 68000: md, x68000, neogeo, neocd, amiga, ti89
    - 45GS02: m65. 6502: c64reu. 80386: towns
14. ntc_rom_cpc.txt, ntc_rom_cpcfw.txt, ntc_rom_cpcmin.txt - the ROM builds' layouts

## The library classes (src/lib, one folder a platform; a class is joined when a program uses it)
15. System.cls, StdIO.cls - every platform (the console, the command line, the clock)
16. FileSystem.cls - cpcfw, cpcmin, cpm, msx, sc3000, zxn, baremetal, test (the disc and tape
    through the firmware on the CPC; not on cpc since 20261116-5)
56. ROMDiscFS.cls - cpc, cpcfw, cpcmin: the ROM disc, with FileSystem's method names
55. Loader.cls - a file from where the program was run and nothing else of FileSystem: cpc,
    cpcfw, cpcmin, cpm, msx, sc3000, zxn, baremetal, test (NotSupported where there are no files);
    the Amiga's own (its discs)
17. Memory.cls - cpc, cpcfw, cpcmin, cpm, msx, msxdos, sc3000, zxn, zxndot, ep128, baremetal, test
    (banks, pages, the window, RamSize / Pages); amiga and towns (blocks of the machine's RAM as
    Long addresses)
18. Keys.cls - cpc, cpcfw, cpcmin, msx, msxdos, sc3000, zxn, zxndot, ep128, md, x68000, towns,
    neogeo, amiga, c64reu (keys held; Joystick(n) with the same bits on every machine)
19. List.cls - cpc, cpcfw, cpcmin, cpm, msx, sc3000, zxn, zxndot, ep128, baremetal, test;
    cyborgos/COSList.cls (the same calls, the nodes in the hypervisor's heap)
20. Graphics.cls - cpc, cpcfw, cpcmin, cpm, zxn (machine code); msx, sc3000, colecovision, md,
    neogeo, x68000, towns, amiga, ep128, m65, c64reu, trs80, ti83, ti89 (BASIC, made by
    tools/graphics/gen.js; test/gfxregress.sh, test/graphics/)
21. VDP.cls, V9990.cls - the MSX, the CPC's Powergraph, msxcard's VDP, the SC-3000
22. z80/Float.cls, z80/Fixed.cls - the built-in floating point and 24.8 fixed point (every Z80 platform)
57. z80/Trit.cls (ternary values), z80/Tiny.cls (8 bit scaled numbers), z80/Tree.cls (a tree of
    behaviours gated by trits), z80/Net.cls (a ternary GRU: GEN's model) - every Z80 platform;
    zxn/Stream.cls (music streamed from the SD card to the Next's DACs)
23. cyborgos/CybSys.cls, System.cls - the CyborgOS platform's own
24. m65/Joy, Sid, Vic; md/Pad, Psg, Vdp, Z80, Pcm - the MEGA65's and the Mega Drive's
58. The other machines' own classes:
    - c64reu: Reu, Task, Disk, Vic, Sid, Joy
    - neogeo (and neocd): Vdp, Pad, Pcm, Psg, Fm, Cdda, Sound
    - towns: Vdp, Pcm
    - x68000: Vdp, Pcm, Opm
    - amiga: Loader (see 55)
    - pcw16, ti83, ti89, trs80, system80: System only (drafts)

## 3D and hardware libraries
25. src/ntc3d - E3.cls (the engine: camera, CamSet / CamPosL, objects), E3W.cls (wireframe),
    Obj3D, Fly3D, Galaxy3D, Hud3D, Radar3D, Nx.cls; FRAMEWORK.md; its examples and tools
26. src/hwlib - the hardware library (its own lib, build, tests, tools, README)
27. src/jscompile/iftopf.js - the JS flavour's compile step

## The example programs (src/bas)
28. The classics and tests: amsdos, cmdline, console_classes, files, filestep, filestpn, guess, guide,
    keys_test, lists, memmap, ntc_test, numbered, shellsort, sieve, sievetime, sorttime, interrupts,
    overlays, pages, own_stdio, class_demo, js_demo, php_demo, loco_demo, natural_demo, vb_test
    (and vb_test2 to vb_test12, vb_test_long), the vdp and v9990 demos
29. The games and demos: auckland (and its parts), aucklink, chip8, city3d, cube3d, cyswarm (and
    cyswarm_m65), m65_test, md_test; the Commodore 64's: c64_test, c64_tasks, c64_world, c64_film,
    c64_sprites, c64_dungeon, c64_lots

## The tests (test/)
30. cli.js - the command-line compiler (compile a .bas with its classes for a platform)
31. ntcrun.py, cpcrun.py, cpcvdp.py, cpctime.py, v9990.py - the CPC harness on the Z80 core
32. msxrun.py - the MSX harness; zxnrun.py - the Next (a .NEX, no esxDOS); dotrun.py - the Next's dot commands (zxndot, zxndotl: a NextZXOS stand-in on zxnrun's Next)
33. A machine's build, run and regression set:
    - m65build.py, m65run.py, m65regress.sh - the MEGA65 (Xemu)
    - mdbuild.py, mdrun.py, mdregress.sh - the Mega Drive (Genesis Plus GX); coleco/ - the ColecoVision
    - x68build.js, x68run.py, x68regress.sh - the X68000 (px68k)
    - townsbuild.js, townsrun.py, townsregress.sh, tsugaru-padset.patch - the FM Towns (Tsugaru)
    - ngbuild.js, ncdbuild.js, ngrun.py, ngregress.sh, ngbios.s, ngsys/ - the Neo Geo and Neo Geo CD
      (Geolith, NTC's stand-in BIOS)
    - amigabuild.js, amigarun.py, amigaregress.sh - the Amiga (PUAE)
    - epbuild.js, eprun.py, epregress.sh - the Enterprise 128 (ep128emu)
    - c64build.js, c64run.py, c64regress.sh, c64/ - the Commodore 64 with an REU (VICE x64sc)
34. regress.sh - the Z80 regression (the .bas tests with their .txt expected screens)
35. gen.js, genbuild.js, genrom.js, genromdisc.js, gendsk.sh - the generators (ntc_lib.js, the
    builds, the ROMs, the discs)
36. float/ - the Float and Fixed tests (t3, t5, t7, t8, t9, chk.py, fixchk.py, FloatDemo);
    tritchk.py - Trit
37. guitest*.py, shot.py, tutcheck.py - the IDE's and the tutorial's checks
38. realcpc.c, realcpcbin.sh - a real CPC through its serial link

## Tools
39. tools/ntccheck - compare.js (every program compiled before and after a compiler change,
    byte for byte), romwhy.js
40. tools/hosted/build.js - the hosted IDE
41. tools/s3dtools, s3dmake, s3dpi - the 3D data tools; tools/osmcut - the map cutter; tools/coleco
59. Tools for the other machines and classes: tools/neogeo (ngtiles.js: PNG to tiles and palettes;
    ngpcm.js: WAV to the V ROM), tools/adpcm/okiadpcm.js (songs for Pcm on the FM Towns and
    X68000), tools/md (dpcm.js, z80pcm.asm: the Mega Drive's), tools/trscmd.js (a TRS-80 /CMD),
    tools/gen (GEN's model: qgru.py, fgru.py), tools/tiny, tools/byref-bench, tools/znc-compare,
    tools/graphics (gen.js, parts.js: the BASIC Graphics classes, a file a platform)
42. sjasmplus/ - the assembler; build/ - build.bat, the dsk and rom outputs; src/compare - bench,
    smallc (other compilers to compare against)

## Documents (docs/)
43. NTC.md (the language), userguide.md, tutorial/ (1.1 on), architecture.md
44. float.md, locomotive-bank.md, locomotive_flavour.md, js_flavour.md, php_flavour.md,
    natural_flavour.md, requirements.md, requirements-user.md, memory-map.md, library-size.md,
    portable-ntc-basic.md, pi-bridge.md, potentjs-gaps.md, targets.md (every platform in one
    place), and a document a machine: m65.md, md.md, x68000.md, towns.md, neogeo.md, amiga.md,
    ep128.md, c64reu.md
45. todo.md (open work, by component), done.md (what is done), buglist.md (bugs, by component)
46. components.md (this)
47. ANALYSIS.LOG - each turn's work, the model's name and a UTC time in front
60. build-info.txt - every build, newest first, with what changed and what was and was not run

## Future components (no code yet - each keeps its number when it is built)
48. Sound on the CPC - an AY class, a music player (the todo's sound items). Other machines have
    theirs: see 24 and 58
49. More targets - the ZX Spectrum (48K / 128K), the PRIMAL target list, a Commodore 64 without
    an REU, the candidates in targets.md section 5
50. File devices as classes - Disk, RamDisk, Printer, Serial
51. A text buffer class (lines of text in the heap)
52. The language, possibly future - ReDim from variables, overflow checks, 3+ dimension array
    parameters, Format$ patterns
