# NTC BASIC - the components, numbered (refer to them by number)

## The compiler (src/js, runs in the browser IDE and under node)
1. ntc_parser.js - the parser (tokens, statements, expressions, classes, #If)
2. ntc_compiler.js - the compiler: threaded code, the keyword table, the memory model (pages, overlays,
   banks), the library class join, the platform defines, the sjasmplus source it writes
3. ntc_lib.js - the library classes as text (generated from src/lib by test/gen.js)
4. ntc_examples.js - the examples (generated)
5. ntc_flavour_loco.js, ntc_flavour_js.js, ntc_flavour_php.js - the Locomotive, JS and PHP flavours
6. ntc_gui.js, formRenderer.js, listRenderer.js, textEditor.js - the IDE (projects, modules, the
   editor, the forms designer)
7. src/ntc.html, src/css, src/3p - the IDE's page, styles and third-party pieces; hosted/ its
   published form (tools/hosted/build.js makes it)

## The runtime (src/asm, Z80 and the others)
8. ntc_lib.asm - the Z80 runtime: the keywords, strings, numbers, Long, the thread engine
9. ntc_lib_cpc.asm, ntc_lib_msx.asm, ntc_lib_nxt.asm - a machine's own parts (the CPC's banks and
   firmware, the MSX's mapper, the Next's MMU and esxDOS)
10. ntc_lib_vdp.asm - the V9938 / V9958 / V9990 and tilemap console pieces
11. ntc_lib_gen.asm - generated tables (from the compiler)
12. ntc_lib_68k.asm - the Mega Drive (68000) runtime; ntc_lib_m65.asm - the MEGA65 (45GS02)
13. The platform files ntc_plat_*.asm: cpc, cpcfw, cpcmin, cpccard, cpc9990, cpm, cyborgos,
    cyborgoshh, msx, msxdos, msxcard, msx9990, zxn, sc3000, colecovision, baremetal, test, md, m65
14. ntc_rom_cpc.txt, ntc_rom_cpcfw.txt, ntc_rom_cpcmin.txt - the ROM builds' layouts

## The library classes (src/lib, one folder a platform; a class is joined when a program uses it)
15. System.cls, StdIO.cls - every platform (the console, the command line, the clock)
16. FileSystem.cls - cpc, cpcfw, cpcmin, cpm, msx, sc3000, zxn, baremetal, test
17. Memory.cls - cpc, cpcfw, cpcmin, cpm, msx, msxdos, sc3000, zxn, baremetal, test (banks, pages,
    the window, RamSize / Pages)
18. Keys.cls - cpc, cpcfw, cpcmin, msx, sc3000, zxn (key states; the Next's matrix)
19. List.cls - the list type, where it exists
20. Graphics.cls - cpc, cpcfw, cpcmin, cpm, zxn
21. VDP.cls, V9990.cls - the MSX, the CPC's Powergraph, msxcard's VDP
22. z80/Float.cls, z80/Fixed.cls - the built-in floating point and 24.8 fixed point (every Z80 platform)
23. cyborgos/CybSys.cls, System.cls - the CyborgOS platform's own
24. m65/Joy, Sid, Vic; md/Pad, Psg, Vdp - the MEGA65's and the Mega Drive's

## 3D and hardware libraries
25. src/ntc3d - E3.cls (the engine: camera, CamSet / CamPosL, objects), Obj3D, Fly3D, Galaxy3D,
    Hud3D, Radar3D, Nx.cls; FRAMEWORK.md; its examples and tools
26. src/hwlib - the hardware library (its own lib, build, tests, tools, README)
27. src/jscompile/iftopf.js - the JS flavour's compile step

## The example programs (src/bas)
28. The classics and tests: amsdos, cmdline, console_classes, files, filestep, guess, guide, keys_test,
    lists, memmap, ntc_test, interrupts, class_demo, js_demo, loco_demo
29. The games and demos: auckland (and its parts), aucklink, chip8, city3d, cube3d, cyswarm (and
    cyswarm_m65), m65_test, md_test

## The tests (test/)
30. cli.js - the command-line compiler (compile a .bas with its classes for a platform)
31. ntcrun.py, cpcrun.py, cpcvdp.py, cpctime.py, v9990.py - the CPC harness on the Z80 core
32. msxrun.py - the MSX harness; zxnrun.py - the Next (a .NEX, no esxDOS)
33. m65run.py, m65build.py, m65regress.sh - the MEGA65; mdrun.py, mdbuild.py, mdregress.sh - the
    Mega Drive; coleco/ - the ColecoVision
34. regress.sh - the Z80 regression (the .bas tests with their .txt expected screens)
35. gen.js, genbuild.js, genrom.js, genromdisc.js, gendsk.sh - the generators (ntc_lib.js, the
    builds, the ROMs, the discs)
36. float/ - the Float and Fixed tests (t3, t5, t7, t8, t9, chk.py, FloatDemo)
37. guitest*.py, shot.py, tutcheck.py - the IDE's and the tutorial's checks
38. realcpc.c, realcpcbin.sh - a real CPC through its serial link

## Tools
39. tools/ntccheck - compare.js (every program compiled before and after a compiler change,
    byte for byte), romwhy.js
40. tools/hosted/build.js - the hosted IDE
41. tools/s3dtools, s3dmake, s3dpi - the 3D data tools; tools/osmcut - the map cutter; tools/coleco
42. sjasmplus/ - the assembler; build/ - build.bat, the dsk and rom outputs; src/compare - bench,
    smallc (other compilers to compare against)

## Documents (docs/)
43. NTC.md (the language), userguide.md, tutorial/ (1.1 on), architecture.md
44. float.md, m65.md, md.md, locomotive-bank.md, locomotive_flavour.md, js_flavour.md,
    php_flavour.md, requirements.md
45. todo.md (open work, by component), done.md (what is done), buglist.md (bugs, by component)
46. components.md (this)
47. ANALYSIS.LOG - each turn's work, the model's name and a UTC time in front

## Future components (no code yet - each keeps its number when it is built)
48. Sound - an AY class, a music player (the todo's sound items)
49. More targets - the ZX Spectrum (48K / 128K), the PRIMAL target list
50. File devices as classes - Disk, RamDisk, Printer, Serial
51. A text buffer class (lines of text in the heap)
52. The language, possibly future - ReDim from variables, overflow checks, 3+ dimension array
    parameters, Format$ patterns
