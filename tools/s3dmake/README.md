# S3D Make

`s3dmake.html`: open it in a browser (Chrome, Edge, Firefox), pick the OSM Cut output
(`NAME-cut.txt.gz` from `tools/osmcut`, or its parts `.1of2` `.2of2` ... together), press Make,
download `AUCKLAND.DAT` (the name box: 8 characters). Nothing leaves the page. Auckland (BBBike's
extract, 409 km²) takes about 6 seconds.

The `.DAT` is the data for the STATE3D demo `AUCKLAND.BIN` (`bas/auckland`, cpcfw): put both on
the same drive (the `.DAT` is 3.8 MB: a UniDOS / M4 drive, not a floppy) and `RUN"AUCKLAND` on a
CPC with 4 MB of expansion RAM. It reads the whole file into the expansion RAM at the start.

What goes in, until "At most" (3968K: a 4 MB CPC less what the program needs) is full - over
that, minor roads are thinned first, then the small buildings, then the trees - the woods' fill
first, the mapped trees last (Auckland fits whole: 3808K; a 1MB Next's 528K keeps 466 trees):

- buildings: outlines cut to 12 points or fewer; height from `height`, else `building:levels`
  (3.2 m a level, plus 1 m), else a guess from the kind and size (houses 6-8 m, sheds 3 m,
  apartments 12-20 m, offices 8-30 m - the tall ones near the CBD ...)
- roads: motorways and major roads as two lines (each side), minor ones as one; bridges on their
  deck height as 3D lines; railways, the coast, water, streams, piers
- trees: the mapped ones, and woods and scrub filled with one every 35 m
- landmarks, drawn from further away: the Sky Tower (a model, 328 m), the Harbour Bridge (its deck
  rising to 43 m and the truss over the main span), the volcanoes and peaks over 25 m (cones from their height:
  Rangitoto on its island's outline, Mount Victoria, Mount Eden, One Tree Hill ...)
- the views (keys 1-9 in the demo): the start - 200 m up out in the gulf, flying in at Auckland
  with Rangitoto 4 km off a little right of ahead (with no Rangitoto: south of the CBD) -, south
  of the CBD, the Sky Tower, the Harbour Bridge (low, 230 m off the main span), Devonport, the
  highest volcanoes
- a start of your own: "Start at" a street's name - the first view (key 1) looks at its far end from
  250 m off, 60 m up (the data has no house numbers: a short street or a cul-de-sac is best); the
  usual start becomes key 2. For node: `src/test/s3d/make.js s3dmake.html cut.txt.gz OUT.DAT NAME kb
  "street"`
- an area of its own: "Only the area round" a place's name (a suburb, a street, a building, a hill)
  and the square's side in km - only that, with all its detail: every street, house and tree (no
  thinning, where a whole city would need it). The first view looks at the place (or at the "Start
  at" street). Auckland: the Sky Tower 6 km, Devonport 8 km, Gemini Place 8 km - about 450K each,
  a 1MB Next's room (node: `make.js ... NAME kb "street" "place" km`)
- far landmarks: Rangitoto, the Sky Tower and the Harbour Bridge are drawn to 11 km (the other
  volcanoes to 3.5 km); a world can be 127 tiles (48 km) across at most
- the city's centre (the Sky Tower): the demo's compass points there
- limits (the engine's tables, kept small to stay under the ROMs' RAM): heights to 382 m, 256
  landmark tiles (the far ones kept first), 12 points a building

Another city works too (cut it with `osmcut.html` and its box): the Sky Tower, Harbour Bridge and
Rangitoto models are just left out when they are not found; any `natural=volcano` or `peak` with
`ele` of 25 m or more gets a cone.

The format (block 0 the header, directory and views; then 16K blocks of 384 m tiles; 0.5 m world
units, 2 m steps in a tile) is written out at the top of the script. The converter's `make(text,
opts, log)` is also exported for node: `src/test/s3d/make.js` runs it (the regression test makes
a small town with `src/test/s3d/mkcut.py` and flies through it).

Map data (c) OpenStreetMap contributors, ODbL: the demo shows it at the start.
