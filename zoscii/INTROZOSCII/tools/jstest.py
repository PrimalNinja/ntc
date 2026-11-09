# jstest.py - drives the PotentJS version of INTRODUCTION TO ZOSCII in headless Chromium and takes screenshots of its screens.
#   python3 tools/jstest.py <game folder> <screenshot folder>
# (c) 2026 Cyborg Unicorn Pty Ltd
import sys, os, time
from playwright.sync_api import sync_playwright

game, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
errs = []

with sync_playwright() as pw:
    b = pw.chromium.launch()
    pg = b.new_page(viewport={'width': 960, 'height': 768})
    pg.on('console', lambda m: errs.append(m.type + ': ' + m.text) if m.type in ('error', 'warning') else None)
    pg.on('pageerror', lambda e: errs.append('PAGEERROR: ' + str(e)))
    pg.goto('file://' + os.path.abspath(game) + '/game.htm' + os.environ.get('JSQ', ''))
    time.sleep(0.5)

    def key(k, n=1, wait=0.12):
        for _ in range(n):
            pg.keyboard.down(k); time.sleep(0.06); pg.keyboard.up(k); time.sleep(wait)

    def shot(name):
        time.sleep(0.1)
        pg.locator('#canOutput').screenshot(path=os.path.join(out, name + '.png'))

    shot('00_splash1_start')
    time.sleep(2.0); shot('01_splash1_hold')
    key('Space')            # cuts the splash short
    time.sleep(1.0); shot('02_splash2')
    key('Space')
    time.sleep(1.0); shot('03_title')
    key('Space'); time.sleep(0.3); shot('04_menu')

    def section(i, pages, name, extra=None):
        # menu to item i
        key('q', 15, 0.03)
        key('a', i, 0.03)
        key('Space', wait=0.3)
        for p in range(pages):
            shot('%s_p%d' % (name, p + 1))
            if extra: extra(p)
            key('p', wait=0.3)
        time.sleep(0.2)

    section(0, 5, '10_story')
    section(1, 2, '11_where', extra=lambda p: key('Space', wait=0.3) if p == 1 else None)
    section(2, 2, '12_rom')
    section(3, 1, '13_letter'); key('Space'); shot('13_letter_again'); key('o'); shot('13_letter_prev'); key('z')
    section(4, 1, '14_plaus'); key('z')
    section(5, 1, '15_anatomy'); key('z')
    section(6, 5, '16_family', extra=lambda p: key('Space', wait=0.3) if p == 2 else None)
    section(7, 4, '17_random')
    section(8, 4, '18_shannon')
    section(9, 2, '19_key')
    section(13, 4, '1a_tiny')
    section(14, 3, '1b_fine')

    # have a play
    key('q', 15, 0.03); key('a', 10, 0.03); key('Space', wait=0.3); shot('20_play_setup')
    key('Space', wait=0.5); shot('21_play_result')
    key('w', wait=0.3); shot('22_play_decode')
    key('s', wait=0.3); shot('23_play_tamper'); key('w', wait=0.3); shot('24_play_tamper_decode')
    key('Space', wait=0.3)
    for i, f in enumerate(['a', 'b', 'c']):
        pass
    shot('25_attack_head')
    key('Space', wait=0.5); shot('26_attack_readings')
    key('a', wait=0.2); key('Space', wait=0.5); shot('27_attack_crib')
    key('a', wait=0.2); key('Space', wait=0.5); shot('28_attack_baseline')
    key('z'); time.sleep(0.2); shot('29_play_back_result'); key('z'); key('z'); time.sleep(0.2); shot('2a_menu_after')

    # demo (see it): protocol 0..5
    for mode, item in ((0, 11), (1, 12)):
        key('q', 15, 0.03); key('a', item, 0.03); key('Space', wait=0.3); shot('3%d_demo_intro' % mode)
        key('Space', wait=0.1); time.sleep(0.6); shot('3%d_demo_making' % mode); time.sleep(1.5)
        for p in range(12 if mode == 0 else 13):
            shot('3%d_demo_p%02d' % (mode, p + 1))
            if p == 8:
                for c in 'HELLO':
                    key(c.lower(), wait=0.05)
                key('Enter', wait=0.5); shot('3%d_demo_probe' % mode)
            if mode == 1 and p == 9:
                for i in range(10): key('Space', wait=0.1)
                time.sleep(0.2)
            else:
                key('p', wait=0.3)
        key('z'); time.sleep(0.3)
    print('ERRORS:', errs if errs else 'none')
    b.close()
