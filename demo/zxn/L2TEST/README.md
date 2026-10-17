# L2TEST - are Layer 2's buffers swapped in step with the screen?

(c) 2026 Cyborg Unicorn Pty Ltd - MIT License

Run `build/L2TEST.NEX`. It draws the way NEON WAR does: each frame it takes off the lines it drew
on this buffer last time (`L2.Clear`), draws a spinning star and 4 bobbing boxes, waits for the
frame, then swaps the two Layer 2 buffers (`L2.Flip`, NextReg #12).

- **Solid shapes:** the swap is in step with the screen.
- **Shapes blinking or vanishing:** it isn't.

Keys:
- **W** swaps the way it waits for the frame:
  - **F** `Frame`, NTC's own: waits for raster line 192 (NextReg #1E / #1F), the end of the picture.
  - **R** raster wrap: waits until the line number goes back down, which is the start of a new
    frame whichever line the count starts from.
- **1-4** 3.5 / 7 / 14 / 28MHz.

If F blinks and R is solid, NTC's `Frame` is waiting for the wrong line on that machine (its line
numbers don't start at the top of the picture), and the fix is in `ntc_plat_frame`.

## Files
- `Main.bas`, `Nx.cls`, `L2.cls`; `build/L2TEST.NEX` (and `.asm`).
