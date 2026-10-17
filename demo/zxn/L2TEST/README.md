# L2TEST - a check of Frame and the Layer 2 swap on a real Next

(c) 2026 Cyborg Unicorn Pty Ltd - MIT License

Run `build/L2TEST.NEX`. Buffer A (bank 16) is blue, buffer B (bank 19) red, and every frame it
does `Frame`, then `L2.Flip` (NextReg #12). Keys 1-4 set the CPU to 3.5, 7, 14 or 28MHz.

What you see tells which part fails:
- **A steady red/blue flicker, the same at every speed:** both work.
- **Solid red or solid blue:** the swap (NextReg #12) isn't taking effect.
- **Red and blue bands, rolling or jumping, different at each speed:** `Frame` isn't waiting for
  the end of the frame.

The text:
- **lines after Frame:** the raster line read straight after 8 `Frame`s. They should all be 192
  or just after; random numbers mean `Frame` comes back early.
- **#12 now:** the bank NextReg #12 reads back as (16 or 19).
- **#1E byte:** NextReg #1E's whole byte. Only bit 0 should ever be set.

In my emulator: 192 every time, #12 swapping 16 / 19, #1E 0, and a red/blue flicker.

## Files
- `Main.bas`, `Nx.cls`, `L2.cls`; `build/L2TEST.NEX` (and `.asm`).
