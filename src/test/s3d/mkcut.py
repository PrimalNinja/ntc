# mkcut.py out.txt.gz: a small made-up OSM Cut file (tools/osmcut's text) for the AUCKLAND test -
# a 2 km town: a grid of buildings, roads, a railway, a coast, a volcano, a tower, trees, a wood
import gzip, sys, random
random.seed(7)
L = ["# STATE3D OSM cut 2 - a made-up test town", "O\t-36.85\t174.76", "X\t-\t-\t-\t-"]
def way(c, i, tags, pts):
    s = ["%d,%d" % pts[0]] + ["%d,%d" % (b[0] - a[0], b[1] - a[1]) for a, b in zip(pts, pts[1:])]
    L.append("%s\t%d\t%s\t%s" % (c, i, tags, " ".join(s)))
n = 1000
for gx in range(-12, 13):
    for gy in range(-12, 13):
        if gx == 0 or gy == 0: continue
        x, y = gx * 70, gy * 70; w, d = random.randint(10, 30), random.randint(10, 30)
        t = "building=yes" + ("|building:levels=%d" % random.randint(1, 20) if random.random() < 0.5 else "")
        way("W", n, t, [(x, y), (x + w, y), (x + w, y + d), (x, y + d), (x, y)]); n += 1
way("W", n, "highway=motorway", [(-900, 0), (900, 0)]); n += 1
way("W", n, "highway=residential|name=Test Street", [(0, -900), (0, 900)]); n += 1
way("W", n, "railway=rail", [(-900, -950), (900, -950)]); n += 1
way("W", n, "natural=coastline", [(900, 1000), (0, 1000), (-900, 1000)]); n += 1
way("W", n, "man_made=pier", [(100, 1000), (100, 1100)]); n += 1
way("W", n, "building=yes|height=328|man_made=tower|name=Sky Tower", [(300, 300), (310, 300), (310, 310), (300, 310), (300, 300)]); n += 1
way("W", n, "natural=wood", [(-800, -800), (-500, -800), (-500, -500), (-800, -500), (-800, -800)]); n += 1
L.append("N\t%d\tele=120|name=Test Hill|natural=volcano\t%d,%d" % (n, -600, 600)); n += 1
for k in range(40):
    L.append("N\t%d\tnatural=tree\t%d,%d" % (n, random.randint(-900, 900), random.randint(-900, 900))); n += 1
gzip.open(sys.argv[1], "wt").write("\n".join(L) + "\n")
