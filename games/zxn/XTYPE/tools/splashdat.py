#!/usr/bin/env python3
"""Makes Splash.cls (the game's) and build/SPLASH.DAT from the stock Cyborg Unicorn Splash.cls.
The stock class keeps its three packed screens in main RAM (about 4K each). This game has no room,
so the screens go in 16K bank 20 (NEX file) and the class reads them through slot 7:
  8K bank 40: the unicorn screen at +0, the NTC BASIC screen at +3838;  8K bank 41: the plain screen.
Run from the game's folder:  python3 tools/splashdat.py
"""
import re, sys, os
here = os.path.dirname(os.path.abspath(__file__)); root = os.path.dirname(here)
src = open(os.path.join(here, 'Splash.stock.cls')).read()
lines = src.split('\n')

def data_after(label):
    i = next(k for k, l in enumerate(lines) if l.startswith('@' + label + ':'))
    out = []
    for l in lines[i + 1:]:
        if l.strip().startswith('#endasm'): break
        m = re.match(r'\s*db\s+(.*)', l)
        out += [int(x.strip().lstrip('#'), 16) for x in m.group(1).split(',')]
    return bytes(out)

logo, plain, ntc = data_after('spl_logo'), data_after('spl_plain'), data_after('spl_ntc')
assert len(logo) + len(ntc) <= 8192 and len(plain) <= 8192
b40 = (logo + ntc).ljust(8192, b'\0'); b41 = plain.ljust(8192, b'\0')
os.makedirs(os.path.join(root, 'build'), exist_ok=True)
open(os.path.join(root, 'build', 'SPLASH.DAT'), 'wb').write(b40 + b41)
OFF = {'logo': 0, 'plain': 0, 'ntc': len(logo)}

# 1. drop the data blocks: from "@spl_x:" to the line before "#endasm" of its function
def drop(label):
    i = next(k for k, l in enumerate(lines) if l.startswith('@' + label + ':'))
    j = i
    while not lines[j].strip().startswith('#endasm'): j += 1
    del lines[i:j]
for l in ('spl_logo', 'spl_plain', 'spl_ntc'): drop(l)
s = '\n'.join(lines)
# 2. the three *At functions return a slot-7 address and set the bank
for lab, fn, bank, off in (('spl_logo', 'LogoAt', 40, OFF['logo']), ('spl_plain', 'PlainAt', 41, 0), ('spl_ntc', 'NtcAt', 40, OFF['ntc'])):
    s = s.replace('            ld de, %s\n' % lab, '            ld a, %d\n            ld (spl_bank), a\n            ld de, #%04X\n' % (bank, 0xE000 + off), 1)
# 3. Begin: slot 7 in for the unpack, put back after
s = s.replace('            SPR #56\n            ld (spl_r56), a\n', '            SPR #56\n            ld (spl_r56), a\n            SPR #57\n            ld (spl_r57), a\n', 1)
s = s.replace('            ld hl, (spl_src)\n', '            ld a, (spl_bank)        ; the packed screen is in bank 20, in slot 7\n            SPW #57\n            ld hl, (spl_src)\n', 1)
s = s.replace('            cp #DB\n            jr c, spu_lp\n            ret\n', '            cp #DB\n            jr c, spu_lp\n            ld a, (spl_r57)         ; slot 7 put back\n            SPW #57\n            ret\n', 1)
s = s.replace('@spl_src:   dw 0\n', '@spl_src:   dw 0\n@spl_bank:  db 0\n@spl_r57:   db 0\n', 1)
# 4. the bank in the NEX file (jumped over, like Pics.cls's)
s = s.replace('\n\' the palette at brightness k', '''
' the screens in the NEX file (bank 20: tools/splashdat.py makes build/SPLASH.DAT); it only jumps over them
Private Sub Banks()
#asm
            jp spz_end
spz_end:
            MMU 6 7, 40
            ORG #C000
            INCBIN "SPLASH.DAT", 0, 16384
            MMU 6 7, 10
            ORG spz_end
#endasm
End Sub

\' the palette at brightness k''', 1)
s = s.replace('Public Sub Show(ByVal n As Integer)\n  Dim a As Integer\n  a = 0\n', 'Public Sub Show(ByVal n As Integer)\n  Dim a As Integer\n  a = 0\n  If n = 99 Then Banks\n', 1)
open(os.path.join(root, 'Splash.cls'), 'w').write(s)
print('Splash.cls written; build/SPLASH.DAT', len(b40 + b41), 'bytes; logo', len(logo), 'plain', len(plain), 'ntc', len(ntc))
