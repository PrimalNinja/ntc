# shots.py - drives INTRO.NEX in NTC's Next emulator and saves screenshots into screenshots/
#   python3 tools/shots.py main            the menu and every paged section (and Have a Play)
#   python3 tools/shots.py demo MD PRO     one Demo run: MD 0 see it, 1 work it out; PRO 0-5 ZOSCII UNSIGNAL BRICS microZ microU microB
#   env NTC_EMU = the emu folder, NEX = INTRO or INTRON
import os, sys, shutil
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.environ.get('NTC_EMU', '/home/claude/ntc2/NTC/src/ntc3d/tools/emu'))
sys.path.insert(0, os.environ.get('ESXDIR', '/home/claude/game/ZOSCIITOOL_ZXN/tools'))
from esx import ESX
LG = os.environ.get('ZLANG', '').upper(); B = os.path.join(HERE, '..', 'build', LG); S = os.path.join(HERE, '..', 'screenshots', LG)
os.makedirs(S, exist_ok=True)
part = sys.argv[1] if len(sys.argv) > 1 else 'main'
md = int(sys.argv[2]) if part == 'demo' else 0
pro = int(sys.argv[3]) if part == 'demo' else 0
name = os.environ.get('NEX', 'INTRO')
SD = os.path.join('/tmp', 'shots_sd_%s_%d_%d' % (part, md, pro)); shutil.rmtree(SD, ignore_errors=True); os.makedirs(SD)
K = {'Q': 16, 'A': 8, 'O': 41, 'P': 40, 'SP': 56, 'Z': 1, 'W': 17, 'S': 9, 'EN': 48, '0': 32, 'E': 18, 'V': 4, 'R': 19}
z = ESX(os.path.join(B, name + '.NEX'), os.path.join(B, name + '.sym'), SD)
held = set(); z.keysheld = lambda f: set(held)
cur = 0
def press(k, wait=40):
    held.add(K[k]); z.run_frames(4); held.discard(K[k]); z.run_frames(wait)
def shot(n):
    z.shot(os.path.join(S, n + '.png'), 2); print('shot', n, flush=True)
def goto(i):
    global cur
    while cur < i: press('A', 20); cur += 1
    while cur > i: press('Q', 20); cur -= 1
def start():
    z.run_frames(60); press('SP', 150); press('SP', 150); z.run_frames(60); press('SP', 60)

def atk(tag):
    press('P', 60); shot(tag + '_type')
    for c in 'SEVERE': press(c, 6)
    press('EN', 1500); shot(tag)

def demo():
    start(); goto(11 + md)
    t = ('see', 'work')[md] + '_' + ('zoscii', 'unsignal', 'brics', 'microzoscii', 'microunsignal', 'microbrics')[pro]
    press('SP', 60)
    for i in range(pro + 1): press('A', 20)
    shot('d%d_%s_00_intro' % (md, t.split('_')[1]))
    press('SP', int(os.environ.get('GENW', '6000')))
    tag = 'd%d_%s' % (md, t.split('_')[1])
    np_ = z.var('var_demo_np')
    p = 0
    while True:
        shot('%s_p%02d' % (tag, p + 1))
        pa = z.var('var_demo_pa')
        if p == 3:
            press('SP', 120); shot('%s_p%02d_saved' % (tag, p + 1))
        if p == pa:
            atk('%s_p%02d_attacker' % (tag, p + 1))
        np_ = z.var('var_demo_np')
        if p + 1 >= np_: break
        press('P', 80); p += 1
    print('files', sorted(os.listdir(SD)))

def main():
    global cur
    z.run_frames(30); shot('00_splash_fadein'); z.run_frames(100); shot('00_splash1_cyborg_unicorn'); press('SP', 20); z.run_frames(150); shot('00_splash2_ntc'); press('SP', 20)
    z.run_frames(120); shot('01_title')
    press('SP', 60); shot('02_menu')
    goto(0); press('SP'); shot('03_story1')
    for i in range(4): press('P'); shot('03_story%d' % (i + 2))
    press('P')
    goto(1); press('SP'); shot('04_ntc1'); press('P'); shot('04_ntc2'); press('SP'); shot('04_ntc3'); press('Z')
    goto(2); press('SP'); shot('04b_rom1'); press('P'); shot('04b_rom2'); press('P')
    goto(3); press('SP', 200); shot('05_letter'); press('SP', 100); press('Z')
    goto(4); press('SP', 300); shot('06_plausibility'); press('Z')
    goto(5); press('SP', 100); shot('07_anatomy'); press('Z')
    goto(6); press('SP'); shot('08_family1'); press('P'); shot('08_family2'); press('P'); shot('08_family3_hash')
    press('SP'); shot('08_family3_hash_changed'); press('SP'); press('P'); shot('08_family4_zwt'); press('P'); shot('08_family5_micro'); press('P')
    goto(7); press('SP'); shot('09_random1'); press('P'); shot('09_random2'); press('P', 600); shot('09_random3'); press('P'); shot('09_random4'); press('P')
    goto(8); press('SP'); shot('09b_shannon1'); press('P'); shot('09b_shannon2'); press('P'); shot('09b_shannon3'); press('P'); shot('09b_shannon4'); press('P'); shot('09b_shannon5'); press('P')
    goto(9); press('SP'); shot('10_keys1'); press('P'); shot('10_keys2'); press('P')
    goto(10)
    press('SP'); shot('11_play_setup')
    press('SP', 400); shot('12_play_result')
    press('W', 200); shot('12_play_decode')
    press('S', 20); shot('12_play_tamper'); press('W', 200); shot('12_play_decode_tampered')
    press('SP', 40); shot('13_atk_yours_start')
    press('SP', 300); shot('13_atk_yours_readings')
    press('A'); press('SP', 600); shot('13_atk_yours_crib')
    press('A'); press('SP', 300); shot('13_atk_yours_roms')
    press('Z'); press('Z')
    press('A'); press('P'); press('P'); press('A'); press('A'); press('P'); press('A'); press('A'); press('P')
    shot('14_play_setup_layers')
    press('SP', 3000); shot('15_play_result_layers')
    press('W', 800); shot('15_play_decode_layers')
    press('S', 20); press('W', 800); shot('15_play_decode_layers_tampered')
    press('SP', 40); press('SP', 800); shot('15_atk_layers_readings')
    press('A'); press('SP', 1500); shot('15_atk_layers_crib')
    press('Z'); press('Z'); press('Z')
    goto(13); press('SP')
    for i in range(4): shot('20_primitive_protocols_p%d' % (i + 1)); press('P')
    goto(14); press('SP')
    for i in range(4): shot('19_fast%d' % (i + 1)); press('P')
    goto(15); press('SP')
    for i in range(3): shot('16_fine%d' % (i + 1)); press('P')

if part == 'main': main()
else: demo()
