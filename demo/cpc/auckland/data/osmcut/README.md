# OSM Cut

`osmcut.html`: open it in a browser (Chrome, Edge, Firefox), pick an OpenStreetMap `.osm.pbf`
(e.g. BBBike's Auckland.osm.pbf), set the box (the default is Auckland: CBD to Albany, Rangitoto,
Devonport, Birkdale), press Cut, download `NAME-cut.txt.gz`. Nothing leaves the page.

What it keeps (for STATE3D): buildings and building parts (height, min_height, levels, roof,
name), roads (type, bridge, tunnel, layer, name, lanes), railways, coastline, water and
waterways, woods, parks and other land uses, piers, bridges as areas, runways, islands; nodes:
trees, peaks, volcanoes, towers, masts, lighthouses, named places, attractions. Multipolygons'
member ways come out with the relation's tags plus role= and way=.

The output (gzipped text, a record a line, tab separated): `O lat0 lon0` (the origin), `X minx
miny maxx maxy` (the box), then `W id tags x,y x,y ...`, `R id tags x,y ...`, `N id tags x,y`;
tags as `k=v|k=v`; x east, y north in whole metres from the origin. Ways are kept when any of
their nodes is in the box (whole, so they may reach out of it).

Tested (node, the same script) on pyrosm's Helsinki extract and Valhalla's Utrecht one (11.8 MB:
1.16 million nodes, 142,630 buildings in the box, 3.5 s, 5.3 MB gzipped).
