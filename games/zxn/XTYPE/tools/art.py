# art.py - X-TYPE's graphics, all drawn here:
#   GfxData.cls + build/XTYPE.DAT (banks 28-29): the sprites (4 bit, 16 x 16 patterns, palette rows) and the
#     tiles (the font, the terrain of each stage, the stars) with the tilemap palette
#   Pals.cls: the tilemap's palette of each stage (the stage swaps it; the font keeps colours 1-4)
#   gfx/*.png: what they look like
#   python3 tools/art.py
# (c) 2026 Cyborg Unicorn Pty Ltd
import os, sys, math, random
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.join(HERE, '..')
sys.path.insert(0, HERE)
import numpy as np
from PIL import Image, ImageDraw
import nxkit

BANK = 28
GFX = os.path.join(ROOT, 'gfx'); os.makedirs(GFX, exist_ok=True)
random.seed(2026)

def rgba(w, h): return Image.new('RGBA', (w, h), (0, 0, 0, 0))
def A(c): return tuple(c) + (255,)

g = nxkit.Gfx()

# ---------------------------------------------------------------- the palette rows (15 colours each)
# a row is a list of colours, picked by name in the drawings below
def mk(names):
    return {n: A(c) for n, c in names}, [c for _, c in names]

ROWS = {}
def row(name, cols):
    d, lst = mk(cols); ROWS[name] = (d, g.row(None, fixed=lst)); return d
SHIP = row('SHIP', [('W', (255, 255, 255)), ('L', (196, 214, 244)), ('M', (92, 132, 226)), ('D', (34, 54, 126)), ('C', (0, 236, 255)),
                    ('O', (255, 150, 30)), ('Y', (255, 232, 80)), ('R', (232, 44, 44)), ('r', (120, 14, 24)), ('G', (96, 232, 110)),
                    ('g', (24, 120, 56)), ('K', (255, 150, 190)), ('P', (160, 90, 230)), ('S', (140, 150, 170)), ('B', (22, 24, 44))])
RED = row('RED', [('W', (255, 255, 255)), ('L', (255, 200, 170)), ('M', (240, 90, 60)), ('D', (140, 30, 30)), ('C', (255, 240, 120)),
                  ('O', (255, 150, 30)), ('Y', (255, 232, 80)), ('R', (232, 44, 44)), ('r', (90, 10, 20)), ('S', (150, 130, 140)),
                  ('s', (80, 70, 90)), ('B', (22, 20, 36)), ('K', (255, 120, 150)), ('P', (200, 70, 200)), ('G', (90, 240, 120))])
GRN = row('GRN', [('W', (255, 255, 255)), ('L', (200, 255, 200)), ('M', (70, 200, 90)), ('D', (20, 100, 50)), ('C', (180, 255, 120)),
                  ('O', (255, 170, 40)), ('Y', (255, 240, 100)), ('R', (232, 60, 60)), ('r', (90, 20, 30)), ('S', (130, 160, 150)),
                  ('s', (60, 90, 90)), ('B', (14, 30, 30)), ('T', (0, 200, 200)), ('P', (200, 90, 220)), ('K', (255, 140, 180))])
PUR = row('PUR', [('W', (255, 255, 255)), ('L', (232, 200, 255)), ('M', (170, 90, 230)), ('D', (80, 30, 130)), ('C', (255, 150, 230)),
                  ('O', (255, 170, 40)), ('Y', (255, 240, 100)), ('R', (240, 50, 120)), ('r', (100, 10, 60)), ('S', (150, 140, 170)),
                  ('s', (70, 60, 100)), ('B', (24, 14, 40)), ('T', (0, 220, 230)), ('G', (110, 240, 130)), ('K', (255, 190, 220))])
FX = row('FX', [('W', (255, 255, 255)), ('Y', (255, 240, 130)), ('O', (255, 160, 40)), ('R', (240, 60, 30)), ('r', (130, 20, 20)),
                ('S', (200, 200, 210)), ('s', (110, 110, 130)), ('C', (110, 240, 255)), ('B', (40, 120, 255)), ('G', (120, 255, 130)),
                ('K', (255, 140, 200)), ('P', (200, 120, 255)), ('D', (60, 60, 90)), ('T', (255, 255, 200)), ('Q', (255, 100, 100))])
BOSS1 = row('BOSS1', [('W', (255, 255, 255)), ('L', (210, 220, 240)), ('M', (140, 160, 200)), ('D', (60, 70, 110)), ('d', (28, 32, 60)),
                      ('O', (255, 150, 30)), ('Y', (255, 232, 80)), ('R', (232, 44, 44)), ('r', (120, 14, 24)), ('C', (0, 236, 255)),
                      ('G', (110, 240, 120)), ('K', (255, 150, 190)), ('P', (170, 100, 230)), ('S', (170, 150, 120)), ('B', (14, 16, 30))])
BOSS2 = row('BOSS2', [('W', (255, 255, 255)), ('L', (255, 220, 170)), ('M', (230, 150, 70)), ('D', (130, 70, 30)), ('d', (50, 28, 20)),
                      ('O', (255, 120, 20)), ('Y', (255, 232, 80)), ('R', (232, 44, 44)), ('r', (120, 14, 24)), ('C', (255, 250, 200)),
                      ('G', (150, 200, 90)), ('K', (255, 150, 150)), ('S', (170, 160, 150)), ('s', (100, 90, 90)), ('B', (22, 14, 12))])
HUDR = row('HUD', [('W', (255, 255, 255)), ('Y', (255, 232, 80)), ('O', (255, 150, 30)), ('R', (232, 44, 44)), ('G', (96, 232, 110)),
                   ('C', (0, 236, 255)), ('M', (92, 132, 226)), ('D', (34, 54, 126)), ('S', (150, 160, 180)), ('s', (70, 76, 100)),
                   ('B', (14, 16, 30)), ('P', (200, 110, 240)), ('K', (255, 150, 190)), ('L', (200, 220, 255)), ('T', (80, 90, 120))])
ROWN = {n: ROWS[n][1] for n in ROWS}

def draw(w, h, rows_, pal):
    """ASCII picture: '.' see-through, a letter = pal[letter]"""
    im = rgba(w, h)
    for y, line in enumerate(rows_):
        for x, ch in enumerate(line[:w]):
            if ch != '.' and ch in pal: im.putpixel((x, y), pal[ch])
    return im

def spr(name, frames, rowname):
    g.sprite(name, frames, row=ROWN[rowname])

# ---------------------------------------------------------------- the ship (32 x 16), three frames: level, up, down
def ship(tilt):
    s = [
        "................................",
        "...........LLL..................",
        "..........LWWWLL................",
        ".....DD...MLLLLLMM..............",
        "....DMMD.MMMMLLMMMML............",
        "...DMMMMMMMMMMMLLLLLLLL.........",
        "..DMMMMMMMMMMMMMMMMMLLLLLL......",
        ".DCCMMMMMMMMDDWWCCCCMMLLLLLLWW..",
        ".DCCMMMMMMMMDDWWCCCCMMLLLLLLWW..",
        "..DMMMMMMMMMMMMMMMMMDDDDDD......",
        "...DMMMMMMMMMMMDDDDDDDD.........",
        "....DMMD.MMMMDDMMMMD............",
        ".....DD...MDDDDDMM..............",
        "..........DDDDDD................",
        "................................",
        "................................"]
    if tilt == 1:   # up: nose a pixel up, the body shifted
        s = [r for r in s[1:]] + [s[0]]
    if tilt == 2:
        s = [s[-1]] + s[:-1]
    return draw(32, 16, s, SHIP)
spr('SHIP', [ship(0), ship(1), ship(2)], 'SHIP')

def flame(k):
    s = ["................",
         "................",
         "................",
         "................",
         "................",
         "......YYYY......" if k == 0 else "......YYY.......",
         "....OOYYWW......" if k == 0 else "...OOYYWW.......",
         "..RROOYYWW......" if k == 0 else "..ROOYYWW.......",
         "..RROOYYWW......" if k == 0 else "..ROOYYWW.......",
         "....OOYYWW......" if k == 0 else "...OOYYWW.......",
         "......YYYY......" if k == 0 else "......YYY.......",
         "................", "................", "................", "................", "................"]
    return draw(16, 16, [r[:16].ljust(16, '.') for r in s], SHIP)
# the flame sits just behind the ship: drawn mirrored (the ship is level at x, the flame at x - 12)
fl = [flame(0), flame(1)]
spr('FLAME', fl, 'SHIP')

# ---------------------------------------------------------------- the orb (4 frames of its glow)
def orb(k):
    im = rgba(16, 16); d = ImageDraw.Draw(im)
    d.ellipse([1, 1, 14, 14], fill=SHIP['O'], outline=SHIP['R'])
    d.ellipse([3, 3, 12, 12], fill=SHIP['Y'])
    d.ellipse([5, 5, 10, 10], fill=SHIP['W'])
    # four spokes of light going round
    ang = k * math.pi / 8
    for q in range(4):
        a = ang + q * math.pi / 2
        x = 8 + math.cos(a) * 6.5; y = 8 + math.sin(a) * 6.5
        d.point((int(round(x)), int(round(y))), fill=SHIP['W'])
        d.point((int(round(8 + math.cos(a) * 5)), int(round(8 + math.sin(a) * 5))), fill=SHIP['R'])
    return im
spr('ORB', [orb(k) for k in range(4)], 'SHIP')

# ---------------------------------------------------------------- the ship's shots
def shot_normal():
    s = ["................"] * 7 + ["....CCWWWWWWCC..", "....CCWWWWWWCC.."] + ["................"] * 7
    return draw(16, 16, s, SHIP)
def shot_diag():
    s = ["................"] * 16
    s = [list(r) for r in s]
    for i in range(7):
        s[3 + i][3 + i] = 'W'; s[3 + i][4 + i] = 'C'
        s[3 + i + 1][3 + i] = 'C'
    return draw(16, 16, [''.join(r) for r in s], SHIP)
def shot_orb():
    s = ["................"] * 7 + ["......YYWWYY....", "......YYWWYY...."] + ["................"] * 7
    return draw(16, 16, s, SHIP)
spr('SHOT', [shot_normal()], 'SHIP'); spr('SHOTD', [shot_diag()], 'SHIP'); spr('SHOTO', [shot_orb()], 'SHIP')
# the charged wave: a head and a body, drawn tall; they are scaled across (sizes 1..5)
def wave_head(pw):
    im = rgba(16, 16); d = ImageDraw.Draw(im)
    d.ellipse([2, 0, 15, 15], fill=SHIP['C'], outline=SHIP['W'])
    d.ellipse([5, 3, 15, 12], fill=SHIP['W'])
    return im
def wave_body():
    im = rgba(16, 16); d = ImageDraw.Draw(im)
    d.rectangle([0, 2, 15, 13], fill=SHIP['C'])
    d.rectangle([0, 5, 15, 10], fill=SHIP['W'])
    d.line([0, 0, 15, 0], fill=SHIP['M']); d.line([0, 15, 15, 15], fill=SHIP['M'])
    return im
spr('WAVEH', [wave_head(0)], 'SHIP'); spr('WAVEB', [wave_body()], 'SHIP')
def charge_glow(k):
    im = rgba(16, 16); d = ImageDraw.Draw(im)
    r = 2 + k * 2
    d.ellipse([8 - r, 8 - r, 8 + r, 8 + r], outline=SHIP['C'], fill=None if k > 1 else SHIP['W'])
    if k > 0: d.ellipse([8 - r + 2, 8 - r + 2, 8 + r - 2, 8 + r - 2], outline=SHIP['W'])
    return im
spr('GLOW', [charge_glow(k) for k in range(4)], 'SHIP')

# ---------------------------------------------------------------- the enemies' bullets and the explosions
def ebullet(k):
    im = rgba(16, 16); d = ImageDraw.Draw(im)
    d.ellipse([5, 5, 10, 10], fill=FX['R'], outline=FX['Y'])
    d.rectangle([7, 7, 8, 8], fill=FX['W'])
    if k: d.point([(4, 8), (11, 8), (8, 4), (8, 11)], fill=FX['O'])
    return im
spr('EBUL', [ebullet(0), ebullet(1)], 'FX')
def boom(t):
    im = rgba(16, 16); d = ImageDraw.Draw(im)
    r = [2, 4, 6, 7][t]
    cols = [FX['W'], FX['Y'], FX['O'], FX['R']]
    d.ellipse([8 - r, 8 - r, 8 + r, 8 + r], fill=cols[min(3, t)], outline=cols[min(3, t + 1)])
    if t < 3: d.ellipse([8 - r + 2, 8 - r + 2, 8 + r - 2, 8 + r - 2], fill=cols[max(0, t - 1)])
    for i in range(8):
        a = i * math.pi / 4 + t
        d.point((int(8 + math.cos(a) * (r + 1)), int(8 + math.sin(a) * (r + 1))), fill=FX['Y'])
    return im
spr('BOOM', [boom(t) for t in range(4)], 'FX')
def bit(k):
    im = rgba(16, 16)
    for i in range(10):
        a = random.random() * 6.28; r = random.random() * 6
        im.putpixel((int(8 + math.cos(a) * r), int(8 + math.sin(a) * r)), FX['Y'] if k else FX['O'])
    return im
spr('SPARK', [bit(0), bit(1)], 'FX')

# ---------------------------------------------------------------- the pickups: S (speed), P (power), O (orb)
def pickup(ch, col):
    def f(k):
        im = rgba(16, 16); d = ImageDraw.Draw(im)
        d.ellipse([1, 1, 14, 14], fill=FX['D'], outline=col if k == 0 else FX['W'])
        d.ellipse([3, 3, 12, 12], outline=FX['s'])
        # the letter, 5 x 7
        L = {'S': ["01110", "10001", "10000", "01110", "00001", "10001", "01110"],
             'P': ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
             'O': ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
             'B': ["11110", "10001", "10001", "11110", "10001", "10001", "11110"]}[ch]
        for y, r_ in enumerate(L):
            for x, c in enumerate(r_):
                if c == '1': im.putpixel((5 + x, 4 + y), FX['W'] if k == 0 else col)
        return im
    return [f(0), f(1)]
spr('PUS', pickup('S', FX['C']), 'FX'); spr('PUP', pickup('P', FX['O']), 'FX'); spr('PUO', pickup('O', FX['G']), 'FX')

# ---------------------------------------------------------------- the enemies (one drawing each, recoloured by palette row)
def e_drone(k):
    s = ["................",
         "......DDDD......",
         "....DDMMMMDD....",
         "...DMMLLLLMMD...",
         "..DMMLWWWWLMMD..",
         "..DMLWCCCCWLMD..",
         ".DMMLWCRRCWLMMD.",
         ".DMMLWCRRCWLMMD.",
         "..DMLWCCCCWLMD..",
         "..DMMLWWWWLMMD..",
         "...DMMLLLLMMD...",
         "....DDMMMMDD....",
         ("..RR..DDDD..RR." if k else "...RR.DDDD.RR.."),
         ("..R...........R" if k else "................"),
         "................",
         "................"]
    return draw(16, 16, [r[:16].ljust(16, '.') for r in s], RED)
def e_dart():
    s = ["................",
         "................",
         "................",
         "......DD........",
         "....DDMMDD......",
         "..DDMMMMLLDD....",
         ".DMMMMLLLWWLD...",
         "DMMLLWWWCCWWLD..",
         "DMMLLWWWCCWWLD..",
         ".DMMMMLLLWWLD...",
         "..DDMMMMLLDD....",
         "....DDMMDD......",
         "......DD........",
         "................",
         "................",
         "................"]
    return draw(16, 16, [r[:16].ljust(16, '.') for r in s], GRN)
def e_swoop(k):
    s = ["................",
         "..S..........S..",
         "..SS........SS..",
         "..SMS..DD..SMS..",
         "..SMMSDMMDSMMS..",
         "...SMMDLLDMMS...",
         "....SDLWWLDS....",
         ".....DLCCLD.....",
         ("....SDLCCLDS...." if k else ".....DLCCLD....."),
         ("...SM.DLLD.MS..." if k else "....S.DLLD.S...."),
         ("...S...DD...S..." if k else "................"),
         "................", "................", "................", "................", "................"]
    return draw(16, 16, [r[:16].ljust(16, '.') for r in s], PUR)
def e_crawler(k):
    s = ["................",
         "................",
         "................",
         "................",
         "......DDDD......",
         "....DDMMMMDD....",
         "...DMMLLLLMMD...",
         "..DMLWWLLWWLMD..",
         "..DMLRRLLRRLMD..",
         ".DDMMLLLLLLMMDD.",
         ".SD.DDMMMMDD.DS.",
         ("SS..S......S..SS" if k else ".S.S........S.S."),
         ("S...S......S...S" if k else "S............... "[:16]),
         "................", "................", "................"]
    return draw(16, 16, [r[:16].ljust(16, '.') for r in s], GRN)
def e_turret(a):
    # base + a barrel at one of five aims: 0 left, 1 left-down... (the barrel's tip as a dx, dy from the middle)
    im = rgba(16, 16); d = ImageDraw.Draw(im)
    d.pieslice([1, 4, 14, 20], 180, 360, fill=RED['M'], outline=RED['D'])
    d.rectangle([1, 12, 14, 15], fill=RED['D'])
    d.rectangle([4, 9, 11, 11], fill=RED['L'])
    d.ellipse([5, 5, 10, 10], fill=RED['s'], outline=RED['S'])
    tip = [(1, 6), (2, 3), (8, 1), (13, 3), (14, 6)][a]
    d.line([8, 8, tip[0], tip[1]], fill=RED['W'], width=2)
    d.point([(8, 8)], fill=RED['R'])
    return im
def e_head(k):
    s = ["................",
         "................",
         "....DDDDDDD.....",
         "..DDMMMMMMMD....",
         ".DMMLLLLLLMMD...",
         "DMLLWWWWWLLMMD..",
         "DMLWCCRRCWLMMD..",
         "DMLWCCRRCWLMMD..",
         "DMLLWWWWWLLMMD..",
         ".DMMLLLLLLMMD...",
         "..DDMMMMMMMD....",
         "....DDDDDDD.....",
         "................", "................", "................", "................"]
    return draw(16, 16, [r[:16].ljust(16, '.') for r in s], GRN)
def e_seg(k):
    im = rgba(16, 16); d = ImageDraw.Draw(im)
    d.ellipse([2, 2, 13, 13], fill=GRN['M'], outline=GRN['D'])
    d.ellipse([4, 4, 10, 10], fill=GRN['L'])
    d.rectangle([6, 6, 8, 8], fill=GRN['C'] if k == 0 else GRN['Y'])
    return im
def e_carrier(k):
    s = ["................................",
         "................................",
         "......DDDDDDDDDDDDDDDD..........",
         "....DDMMMMMMMMMMMMMMMMDD........",
         "...DMMLLLLLLLLLLLLLLLLMMD.......",
         "..DMLLWWWWWWWWWWWWWWWWLLMD......",
         ".DMLWWWSSSSSSSSSSSSSSSSWWLMD....",
         "DMLWSSSsssssYYYYYYssssSSSWLMD...",
         "DMLWSSSsssssYYYYYYssssSSSWLMD...",
         ".DMLWWWSSSSSSSSSSSSSSSSWWLMD....",
         "..DMLLWWWWWWWWWWWWWWWWLLMD......",
         "...DMMLLLLLLLLLLLLLLLLMMD.......",
         ("....DDMMMMMMMMMMMMMMMMDD........" if k == 0 else ".....DMMMMMMMMMMMMMMMMD........."),
         ("......DDDDDDDDDDDDDDDD.........." if k == 0 else "......DD.DDDDDDDDDD.DD........"),
         "................................",
         "................................"]
    return draw(32, 16, [r[:32].ljust(32, '.') for r in s], RED)
def e_mine(k):
    im = rgba(16, 16); d = ImageDraw.Draw(im)
    d.ellipse([3, 3, 12, 12], fill=PUR['D'], outline=PUR['M'])
    d.ellipse([5, 5, 10, 10], fill=PUR['M'])
    spikes = [(8, 0), (8, 15), (0, 8), (15, 8)] if k == 0 else [(2, 2), (13, 2), (2, 13), (13, 13)]
    for sx, sy in spikes: d.line([8, 8, sx, sy], fill=PUR['L'])
    d.rectangle([7, 7, 8, 8], fill=PUR['R'] if k else PUR['C'])
    return im
def e_orbiter(k):
    im = rgba(16, 16); d = ImageDraw.Draw(im)
    d.ellipse([2, 4, 13, 11], fill=GRN['D'], outline=GRN['M'])
    d.ellipse([5, 5, 10, 10], fill=GRN['C'] if k == 0 else GRN['Y'])
    d.line([0, 8, 3, 8], fill=GRN['S']); d.line([12, 8, 15, 8], fill=GRN['S'])
    return im
spr('DRONE', [e_drone(0), e_drone(1)], 'RED'); spr('DART', [e_dart()], 'GRN'); spr('SWOOP', [e_swoop(0), e_swoop(1)], 'PUR')
spr('CRAWL', [e_crawler(0), e_crawler(1)], 'GRN'); spr('TURRET', [e_turret(a) for a in range(5)], 'RED')
spr('HEAD', [e_head(0)], 'GRN'); spr('SEG', [e_seg(0), e_seg(1)], 'GRN')
spr('CARRIER', [e_carrier(0), e_carrier(1)], 'RED'); spr('MINE', [e_mine(0), e_mine(1)], 'PUR'); spr('ORBIT', [e_orbiter(0), e_orbiter(1)], 'GRN')

# ---------------------------------------------------------------- the bosses (a grid of patterns each)
def boss1():
    """the Colossus: 64 x 48, a big armoured head with a red core, plates and cannons"""
    im = rgba(64, 48); d = ImageDraw.Draw(im); P = BOSS1
    d.polygon([(10, 2), (54, 2), (62, 14), (62, 34), (54, 46), (10, 46), (2, 34), (2, 14)], fill=P['D'], outline=P['d'])
    d.polygon([(14, 6), (50, 6), (58, 16), (58, 32), (50, 42), (14, 42), (6, 32), (6, 16)], fill=P['M'], outline=P['L'])
    d.rectangle([4, 20, 14, 28], fill=P['d']); d.rectangle([0, 22, 8, 26], fill=P['S'])           # the front cannon (left)
    d.rectangle([20, 0, 44, 5], fill=P['S']); d.rectangle([20, 42, 44, 47], fill=P['S'])        # the top and bottom plates
    for x in (18, 28, 38):
        d.rectangle([x, 8, x + 4, 12], fill=P['d']); d.rectangle([x, 36, x + 4, 40], fill=P['d'])
    d.ellipse([20, 14, 44, 34], fill=P['d'], outline=P['S'])
    d.ellipse([24, 17, 40, 31], fill=P['R'], outline=P['O'])
    d.ellipse([28, 20, 36, 28], fill=P['Y']); d.rectangle([30, 22, 33, 25], fill=P['W'])
    d.line([48, 10, 56, 18], fill=P['L']); d.line([48, 38, 56, 30], fill=P['L'])
    return im
spr('BOSS1', [boss1()], 'BOSS1')
def guardian():
    """the mid boss: a 32 x 32 spiked orb with an eye"""
    im = rgba(32, 32); d = ImageDraw.Draw(im); P = BOSS1
    for a in range(0, 360, 45):
        x = 16 + math.cos(math.radians(a)) * 15; y = 16 + math.sin(math.radians(a)) * 15
        d.line([16, 16, x, y], fill=P['S'], width=3)
    d.ellipse([3, 3, 28, 28], fill=P['D'], outline=P['d'])
    d.ellipse([6, 6, 25, 25], fill=P['M'], outline=P['L'])
    d.ellipse([9, 9, 22, 22], fill=P['d'])
    d.ellipse([11, 11, 20, 20], fill=P['R'], outline=P['O'])
    d.rectangle([14, 14, 17, 17], fill=P['Y'])
    return im
spr('GUARD', [guardian()], 'BOSS1')
def boss2():
    """the Engine: 64 x 48 furnace block, pistons and a glowing vent"""
    im = rgba(64, 48); d = ImageDraw.Draw(im); P = BOSS2
    d.rectangle([4, 2, 60, 46], fill=P['D'], outline=P['d'])
    d.rectangle([8, 6, 56, 42], fill=P['M'], outline=P['L'])
    for y in (8, 16, 36):
        d.rectangle([10, y, 54, y + 4], fill=P['S'], outline=P['s'])
    d.rectangle([0, 14, 8, 34], fill=P['s'], outline=P['d']); d.rectangle([56, 14, 63, 34], fill=P['s'], outline=P['d'])
    d.rectangle([14, 20, 50, 32], fill=P['d'], outline=P['S'])
    for x in range(16, 49, 8):
        d.rectangle([x, 22, x + 5, 30], fill=P['O'] if (x // 8) % 2 else P['R'])
    d.ellipse([26, 21, 38, 31], fill=P['Y'], outline=P['W'])
    for x in (12, 24, 40, 52):
        d.ellipse([x - 2, 2, x + 2, 6], fill=P['S'])
    return im
spr('BOSS2', [boss2()], 'BOSS2')

# ---------------------------------------------------------------- the HUD: the digits, a life, the beam gauge
def glyph(ch, col):
    L = {'0': ["01110", "10001", "10011", "10101", "11001", "10001", "01110"], '1': ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
         '2': ["01110", "10001", "00001", "00110", "01000", "10000", "11111"], '3': ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
         '4': ["00010", "00110", "01010", "10010", "11111", "00010", "00010"], '5': ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
         '6': ["00110", "01000", "10000", "11110", "10001", "10001", "01110"], '7': ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
         '8': ["01110", "10001", "10001", "01110", "10001", "10001", "01110"], '9': ["01110", "10001", "10001", "01111", "00001", "00010", "01100"]}[ch]
    im = rgba(16, 16)
    for y, r_ in enumerate(L):
        for x, c in enumerate(r_):
            if c == '1':
                im.putpixel((x * 1 + 1, y + 1), HUDR['B']); im.putpixel((x + 0, y), col)
    return im
spr('DIGIT', [glyph(str(n), HUDR['W']) for n in range(10)], 'HUD')
def life():
    im = rgba(16, 16); d = ImageDraw.Draw(im)
    d.polygon([(1, 11), (3, 6), (12, 5), (14, 8), (12, 11)], fill=HUDR['M'], outline=HUDR['L'])
    d.rectangle([8, 7, 11, 8], fill=HUDR['C'])
    return im
spr('LIFE', [life()], 'HUD')
def seg(k):
    im = rgba(16, 16); d = ImageDraw.Draw(im)
    d.rectangle([1, 5, 14, 10], fill=HUDR['B'], outline=HUDR['s'])
    if k == 1: d.rectangle([3, 7, 12, 8], fill=HUDR['C'])
    if k == 2: d.rectangle([2, 6, 13, 9], fill=HUDR['W'])
    return im
spr('GAUGE', [seg(0), seg(1), seg(2)], 'HUD')
def lab(txt):
    im = rgba(16, 16); d = ImageDraw.Draw(im)
    return im
# the little words: BEAM, 1UP's ship icon and the stage letters are on the tilemap's font (title and text pages)

# a few stars
def star(k):
    im = rgba(16, 16)
    c = [HUDR['W'], HUDR['L'], HUDR['S']][k]
    im.putpixel((8, 8), c)
    if k == 0:
        im.putpixel((7, 8), HUDR['T']); im.putpixel((9, 8), HUDR['T']); im.putpixel((8, 7), HUDR['T']); im.putpixel((8, 9), HUDR['T'])
    return im
spr('STAR', [star(0), star(1), star(2)], 'HUD')

# the title's big letters X - T Y P E (16 x 16 chunky glyphs, drawn 2x on the title)
def bigglyph(ch):
    G = {'X': ["1100000011", "1110000111", "0111001110", "0011111100", "0001111000", "0001111000", "0011111100", "0111001110", "1110000111", "1100000011"],
         '-': ["0000000000", "0000000000", "0000000000", "0000000000", "0111111110", "0111111110", "0000000000", "0000000000", "0000000000", "0000000000"],
         'T': ["1111111111", "1111111111", "0001111000", "0001111000", "0001111000", "0001111000", "0001111000", "0001111000", "0001111000", "0001111000"],
         'Y': ["1100000011", "1110000111", "0111001110", "0011111100", "0001111000", "0001111000", "0001111000", "0001111000", "0001111000", "0001111000"],
         'P': ["1111111100", "1111111110", "1110000111", "1110000111", "1111111110", "1111111100", "1110000000", "1110000000", "1110000000", "1110000000"],
         'E': ["1111111111", "1111111111", "1110000000", "1110000000", "1111111100", "1111111100", "1110000000", "1110000000", "1111111111", "1111111111"]}[ch]
    im = rgba(16, 16)
    for y, r_ in enumerate(G):
        for x, c in enumerate(r_):
            if c == '1':
                t = y / 9.0
                col = HUDR['W'] if t < 0.25 else (HUDR['C'] if t < 0.6 else HUDR['M'])
                im.putpixel((x + 3, y + 3), col)
                if y == 9 or x == 9 or (x < 9 and r_[x + 1:x + 2] != '1' ): pass
    # a dark edge under and right
    for y in range(15, 0, -1):
        for x in range(15, 0, -1):
            if im.getpixel((x, y))[3] == 0 and (im.getpixel((x - 1, y))[3] or im.getpixel((x, y - 1))[3]):
                im.putpixel((x, y), HUDR['D'])
    return im
spr('LOGO', [bigglyph(c) for c in 'X-TYPE'], 'HUD')

# ---------------------------------------------------------------- the tiles: colours 1-4 are the font's; the stage's colours 5-14
# semantic colour numbers (each stage's palette gives them their colours): 5 rock dark, 6 rock mid, 7 rock light, 8 rock cracks,
# 9 accent a, 10 accent b, 11 edge dark, 12 edge light, 13 glow, 14 star
TROW0 = True
g.font()
def tile(n, rows_, name=None):
    ix = [[(15 if ch == '.' else (int(ch, 16))) for ch in r_] for r_ in rows_]
    g.tile_ix(n, ix, name)
# terrain 1: the rock fills, two variants of 3 shades (tiles 1, 2), the ceiling's lower edge (3), the floor's upper edge (4)
R = random.Random(7)
def rock(var):
    t = []
    for y in range(8):
        r_ = ''
        for x in range(8):
            v = R.random()
            r_ += '5' if v < 0.55 else ('6' if v < 0.85 else ('7' if v < 0.95 else '8'))
        t.append(r_)
    return t
tile(1, rock(0), 'ROCKA'); tile(2, rock(1), 'ROCKB')
# proper edge tiles drawn directly (colour numbers in hex digits): 3 ceiling's lower lip, 4 floor's upper lip
tile(3, ['55555555', '55655565', '56665666', '5BCBBCBB', 'BCCCCCCC', 'CCCCCCCC', '........', '........'], 'EDGEC')
tile(4, ['........', '........', 'CCCCCCCC', 'BCCCCCCB', 'BBCBBCBB', '56665666', '55655565', '55555555'], 'EDGEF')
tile(5, ['5555555B', '555555BC', '55555BCC', '5555BCCC', '555BCCC.', '55BCCC..', '5BCCC...', 'BCCC....'], 'SLOPEA')   # spare
tile(6, ['........', '........', '........', '...EE...', '..EEEE..', '...EE...', '........', '........'], 'GLOWA')    # a glow crystal
tile(7, ['........', '........', '........', '........', '........', '........', '........', '........'], 'EMPTY')
tile(8, ['........', '........', '........', '....E...', '........', '........', '........', '........'], 'STARA')
tile(9, ['........', '..E.....', '........', '........', '........', '.....E..', '........', '........'], 'STARB')
tile(10, ['........', '........', '........', '........', '....E...', '........', '........', '........'], 'STARC')
# rock with a hanging/rising spike (decor) 11, 12 and plates for the foundry (13-19)
tile(11, ['55555555', '56555655', '55575555', '5B555B55', '.BC55CB.', '..BCCB..', '...BB...', '........'], 'STALAC')
tile(12, ['........', '...BB...', '..BCCB..', '.BC55CB.', '5B555B55', '55575555', '56555655', '55555555'], 'STALAG')
def plate(a, b, c):
    return ['7777777B', '7%s%s%s%s%s%sB' % (a, a, a, a, a, a), '7%s%s%s%s%s%sB' % (a, b, b, b, b, a), '7%s%s%s%s%s%sB' % (a, b, c, c, b, a),
            '7%s%s%s%s%s%sB' % (a, b, c, c, b, a), '7%s%s%s%s%s%sB' % (a, b, b, b, b, a), '7%s%s%s%s%s%sB' % (a, a, a, a, a, a), 'BBBBBBBB']
tile(13, plate('6', '5', '9'), 'PLATEA'); tile(14, plate('6', '5', '5'), 'PLATEB')
tile(15, ['7777777B', '7666666B', '7699996B', '7699996B', '7666666B', '7666666B', '7666666B', 'BBBBBBBB'], 'PLATEC')   # a vent with colour 9
tile(16, ['CCCCCCCC', 'CBBBBBBC', '56666665', '55555555', '55555555', '55555555', '55555555', '55555555'], 'FLIPC')    # foundry ceiling lip
tile(17, ['55555555', '55555555', '55555555', '55555555', '55555555', '56666665', 'CBBBBBBC', 'CCCCCCCC'], 'FLIPF')    # foundry floor lip

# ---------------------------------------------------------------- the tilemap palettes, a stage each (colours 1-4 stay the font's)
STAGEPAL = [
    # 1 the debris belt: cold blue-grey rock under a violet haze
    {5: (34, 38, 64), 6: (52, 58, 96), 7: (84, 92, 136), 8: (20, 22, 40), 9: (150, 70, 220), 10: (90, 40, 150), 11: (14, 16, 30), 12: (170, 190, 240), 13: (120, 220, 255), 14: (200, 210, 255)},
    # 2 the foundry: hot orange iron
    {5: (60, 30, 26), 6: (96, 52, 36), 7: (150, 90, 52), 8: (34, 16, 16), 9: (255, 120, 20), 10: (200, 60, 20), 11: (20, 10, 10), 12: (255, 200, 120), 13: (255, 240, 160), 14: (255, 220, 160)},
    # 3 the reef: deep green and teal
    {5: (16, 52, 56), 6: (24, 84, 84), 7: (40, 130, 120), 8: (10, 30, 34), 9: (255, 100, 160), 10: (200, 60, 120), 11: (8, 20, 24), 12: (140, 255, 220), 13: (180, 255, 240), 14: (190, 255, 240)},
]
def hexc(c): return c
def tilepal(sp):
    cols = [None] * 16
    base = [(255, 255, 255), (210, 210, 240), (150, 150, 200), (60, 60, 80)]
    cols[0] = (0, 0, 0)
    for i in range(4): cols[1 + i] = base[i] if i < 3 else (40, 40, 70)
    for k in range(5, 15): cols[k] = sp[k]
    cols[15] = (255, 0, 255)
    return cols
# the font uses 1 (top) 2 (middle) 3 (bottom) 4 (shadow) - already in tile row 0's first four; the terrain uses 5-14 by the stage

# ---------------------------------------------------------------- write it all
g.trow(0, [c for c in tilepal(STAGEPAL[0])[0:15]])
gb = g.build()
nxkit.write_dat(os.path.join(ROOT, 'build', 'XTYPE.DAT'), gb)
g.write_cls(os.path.join(ROOT, 'GfxData.cls'), 'XTYPE.DAT', BANK, 'X-TYPE')
nxkit.set_banks(os.path.join(ROOT, 'game.json'), 'art', range(BANK, BANK + len(gb)))

# Pals.cls: the stage palettes in 9 bit (2 bytes a colour) and a Sub that puts one into the tilemap's palette 0
L = ["' Pals - the tilemap's palette for each stage (made by tools/art.py: don't edit). Set n puts stage n's colours in", "' the tilemap's first palette (colours 1-4 are the font's, 5-14 the terrain, 15 see-through).",
     "' (c) 2026 Cyborg Unicorn Pty Ltd", "Option Explicit", "", "Public Sub Set(n As Integer)", "#asm", "            pop hl", "            ld a, (hl)", "            ld l, a",
     "            ld h, 0", "            add hl, hl", "            add hl, hl", "            add hl, hl", "            add hl, hl", "            add hl, hl",
     "            ld de, pl_tab", "            add hl, de", "            ld bc, #243B", "            ld a, #43", "            out (c), a", "            inc b", "            ld a, #30",
     "            out (c), a", "            dec b", "            ld a, #40", "            out (c), a", "            inc b", "            xor a", "            out (c), a", "            dec b",
     "            ld a, #44", "            out (c), a", "            inc b", "            ld e, 16", "pl_lp:", "            ld a, (hl)", "            out (c), a", "            inc hl",
     "            ld a, (hl)", "            out (c), a", "            inc hl", "            dec e", "            jr nz, pl_lp", "            dec b", "            ld a, #43", "            out (c), a", "            inc b", "            xor a", "            out (c), a",
     "            jp pl_end", "pl_tab:"]
for sp in STAGEPAL:
    cols = tilepal(sp)
    cols[1:4] = [(255, 255, 255), (210, 210, 240), (150, 150, 200)]
    cols[4] = (40, 40, 70)
    bs = nxkit.pal_bytes(cols, 16)
    L.append("            db " + ",".join('#%02X' % b for b in bs))
L += ["pl_end:", "#endasm", "End Sub"]
open(os.path.join(ROOT, 'Pals.cls'), 'w').write('\n'.join(L) + '\n')
g.sheet(os.path.join(GFX, 'sprites.png'), 4)
# the tiles, stage 1 colours, as a sheet
sp = STAGEPAL[0]; cols = tilepal(sp)
ts = Image.new('RGB', (16 * 9, 8 * 9), (0, 0, 0))
for n in range(1, 18):
    t = g.tiles.get(n)
    if not t: continue
    for y in range(8):
        for x in range(8):
            v = t[y * 4 + x // 2]; c = (v >> 4) if x % 2 == 0 else (v & 15)
            if c != 15: ts.putpixel(((n - 1) % 16 * 9 + x, (n - 1) // 16 * 9 + y), cols[c] if cols[c] else (255, 0, 255))
ts.resize((ts.width * 5, ts.height * 5), Image.NEAREST).save(os.path.join(GFX, 'tiles.png'))
print('art: %d patterns, %d sprite rows, %d tiles; banks %d-%d' % (len(g.pats), len(g.rows), len(g.tiles), BANK, BANK + len(gb) - 1))
