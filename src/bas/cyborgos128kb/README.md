# CyborgOS - the 128K version (archived)

The last CyborgOS that runs on a 128K CPC (a 6128: one slot) and up, as a proof of concept:
slots in 64K banks, programs run by name with a command tail, the hypervisor's CP/M file calls,
and the disc commands COPY, ERA, TYPE, PREP. Kept as it was on 2026-10-14; it is not built or
tested any more. CyborgOS carries on in `../cyborgos`, needing 320K (a 256K expansion) or more:
the hypervisor takes the first expansion bank's pages (C4, then C5 ...) for its own data, and
main RAM's #4000-#7FFF is left free (a second screen).

Build: Main.bas, Hyp.cls, Hot.cls, Ent.cls - cpcfw (USERGUIDE.md: the user guide as it was then).
