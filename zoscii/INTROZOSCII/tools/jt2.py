# jt2.py - the JS demo: challenge page (press SPACE: downloads), the encoding pages, then the attacker / answer / proof pages
#   python3 tools/jt2.py <game folder> <out folder> <mode 0|1> <protocol presses>
import sys, os, time
from playwright.sync_api import sync_playwright
game, out, mode, pro = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
os.makedirs(out, exist_ok=True); errs = []; dl = []
with sync_playwright() as pw:
    b = pw.chromium.launch()
    ctx = b.new_context(viewport={'width': 960, 'height': 768}, accept_downloads=True)
    pg = ctx.new_page()
    pg.on('console', lambda m: errs.append(m.type + ': ' + m.text) if m.type in ('error', 'warning') else None)
    pg.on('pageerror', lambda e: errs.append('PAGEERROR: ' + str(e)))
    def got(d):
        path = os.path.join(out, 'dl_' + d.suggested_filename); d.save_as(path); dl.append(d.suggested_filename)
    pg.on('download', got)
    pg.goto('file://' + os.path.abspath(game) + '/game.htm'); time.sleep(0.5)
    def key(k, n=1, wait=0.12):
        for _ in range(n):
            pg.keyboard.down(k); time.sleep(0.06); pg.keyboard.up(k); time.sleep(wait)
    def shot(name):
        time.sleep(0.1); pg.locator('#canOutput').screenshot(path=os.path.join(out, name + '.png'))
    time.sleep(2.0); key('Space'); time.sleep(1.5); key('Space'); time.sleep(0.3)
    item = 11 + mode
    key('q', 15, 0.03); key('a', item, 0.03); key('Space', wait=0.3)
    key('a', pro, 0.05)
    key('Space', wait=0.1); time.sleep(8)
    shot('p01')
    for p in range(1, 4): key('p', wait=0.3)
    shot('p04'); key('Space'); time.sleep(6); shot('p04_saved')
    for p in range(5, int(os.environ.get('LAST', '30'))):
        key('p', wait=0.3); shot('p%02d' % p)
    print(dl); print(errs[:5])
    import zipfile
    z = zipfile.ZipFile(os.path.join(out, 'dl_' + dl[0])); print(z.testzip(), len(z.namelist()), z.namelist()[:3], z.read('message1.txt'))
    b.close()
