# s3dtools

Analysis scripts for S3D data (AUCKLAND.DAT, `tools/s3dmake`) and the AUCKLAND demo (`src/bas/auckland`).

- `datinfo.py AUCKLAND.DAT`: the header, the views, the landmark tiles, what the tiles hold
- `dat2png.py AUCKLAND.DAT out.png [buildings|trees|all]`: the data drawn from above
- `prof.py PROF.json`: a harness profile (`NTC_PROF=PROF.json python3 test/ntcrun.py ...`) summed by
  routine and by kind of work (vertex transform, projection, drawing, multiplies ...); loading left out

Needs python3 (and Pillow for `dat2png.py`). The profile and the notes for speeding AUCKLAND up:
`src/bas/auckland/README.TXT` and `ANALYSIS.TXT`.
