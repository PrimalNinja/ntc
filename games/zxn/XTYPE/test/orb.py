# orb.py - the orb, the power levels and the wave beam, up close
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.join(HERE, '..'); sys.path.insert(0, HERE)
import nextemu
SHOT = os.path.join(ROOT, 'screenshots')
e = nextemu.Emu(os.path.join(ROOT, 'build', 'XTYPE.NEX'), os.path.join(ROOT, 'build', 'XTYPE.sym'))
e.frame(60); e.press('space', 4, 4); e.frame(60); e.press('space', 4, 4); e.frame(100); e.press('space', 4, 4); e.frame(250)
e.pokew('g_intpow', 2); e.pokew('g_intorb', 1); e.pokew('g_intinv', 3000)
e.held = {'space'}; e.frame(3); e.held = set(); e.frame(6)
e.picture(os.path.join(SHOT, '06_orb_spread.png'), 2, False)
e.held = {'space'}; e.frame(50)
e.picture(os.path.join(SHOT, '07_charging.png'), 2, False)
e.held = set(); e.frame(8)
e.picture(os.path.join(SHOT, '08_wave.png'), 2, False)
e.press('z', 3, 20)
e.picture(os.path.join(SHOT, '09_orb_out.png'), 2, False)
