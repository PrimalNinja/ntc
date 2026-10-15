#!/usr/bin/env python3
# packz.py - the CYBORGOS.Z* packer (run by gendsk). Boots CyborgOS once the slow way (RAMDISC Z
# SYSTEM copies the commands CYBORGOS.Z names from the boot drive to Z), then writes Z's pages as
# ready-made files for COSLOAD.BIN to load: the driver page first, then the data pages in D_POOL slot
# order, 32K (two pages) a file - CYBORGOS.Z1 (the driver page and the first data page),
# CYBORGOS.Z2 ... (the last may be 16K), each with an AMSDOS header (CAS IN DIRECT needs one).
# Z's pages go where the slow way puts them (and where CyborgOS's ProbeDiscs finds them): the
# driver page in C6, the data pages in C7 and then the bank after the slots' banks - which
# depends on the RAM, so COSLOAD.BIN works the pages out (it probes the banks as the Memory class
# does) and writes them into D_POOL, and the signature's checksum, as it loads. Nothing in
# CyborgOS itself changes (its main RAM stays as it is).
# Also writes COSZ.INC (the files, the pages Z keeps) and, with --sym=CYBORGOS.SYM (the
# CYBORGOS.BIN COSLOAD starts), COSCYB.INC: COSLOAD.ASM includes both.
#   packz.py <boot_dir> <out_dir> <Main.bas> <cls...> [--ram=576] [--sym=file] [--pages=2]
# Prints: PACKZ files=<n> pages=<n> commands=<n> (<k>K)
import sys, os, subprocess, shutil, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

PAGE = 0x4000
args = sys.argv[1:]
plat = 'cpcfw'; ram = '576'; sym = None; per = 2
for a in list(args):
    if a.startswith('--platform='): plat = a[11:]; args.remove(a)
    if a.startswith('--ram='): ram = a[6:]; args.remove(a)
    if a.startswith('--sym='): sym = a[6:]; args.remove(a)
    if a.startswith('--pages='): per = int(a[8:]); args.remove(a)
boot_dir, out_dir, bas = args[0], args[1], args[2]
extra = args[3:]
os.environ['NTC_RAM'] = ram
# the harness reads drive A from NTC_FILES/A: a scratch copy of boot_dir (CYBORGOS.Z, the .CYB files)
tmp = tempfile.mkdtemp(prefix='packz')
shutil.copytree(boot_dir, os.path.join(tmp, 'A'))
os.environ['NTC_FILES'] = tmp
import ntcrun, cpcrun

asm = os.path.join(tmp, 'Main.asm')
r = subprocess.run(['node', os.path.join(HERE, 'cli.js'), bas] + extra + ['--platform=' + plat], capture_output=True, text=True)
open(asm, 'w').write(r.stdout)
b, syms = cpcrun.assemble(asm); org = syms['ntc_start']
h = ntcrun.Host(plat, b, org, '')
cpcrun.endkey_set(h.m, syms)
h.run(int(os.environ.get('NTC_LIMIT', '60000')))
e = bytes(h.ram.ext)
shutil.rmtree(tmp, ignore_errors=True)

def page_ext(p):                     # Memory page p -> its 16K image (page 2 = the first expansion page)
    o = (p - 2) * PAGE
    return bytearray(e[o:o + PAGE])

i = e.find(b'CYBD\x5a\xcb')
if i < 0 or i % PAGE != 0x3F00:
    print('PACKZ FAIL: no driver page (CYBD) - the boot did not make Z'); sys.exit(1)
drv = page_ext(i // PAGE + 2)
# D_POOL at #5400: 256 x 6 (owner - 0 free -, -, page, RAM setting): the data pages in slot order
# (COSLOAD writes each slot's page and RAM setting, and the checksum, for the machine it is on)
DPOOL = 0x1400
used = [k for k in range(256) if drv[DPOOL + k * 6] != 0]
if used != list(range(len(used))):
    print('PACKZ FAIL: D_POOL slots not 0 .. n-1: %s' % used); sys.exit(1)
data = [page_ext(drv[DPOOL + k * 6 + 2] | (drv[DPOOL + k * 6 + 3] << 8)) for k in used]
claim = 1 + len(used)                # the pages Z keeps: the driver page and every D_POOL slot
# D_DIR at #6C00: 256 x 20 (RAM disc + 1, 0 free); D_VOL at #6A00: 8 x 16 (letter, -, blocks, free)
cmds = sum(1 for k in range(256) if drv[0x2C00 + k * 20] != 0 and bytes(drv[0x2C00 + k * 20 + 9:0x2C00 + k * 20 + 12]) == b'CYB')
kb = 0
for k in range(8):
    a = 0x2A00 + k * 16
    if drv[a] == ord('Z'): kb = (drv[a + 2] | (drv[a + 3] << 8)) * 2

# D_FAT at #5A00: 2048 x 2 (0 free): block g in D_POOL slot g \\ 8. Data pages at the end with no
# block in use aren't written (their RAM is Z's still - D_POOL keeps them - but what is in it
# doesn't matter): COSLOAD loads only the pages up to the last one in use
def inuse(k): return any(drv[0x1A00 + g * 2] | drv[0x1A01 + g * 2] for g in range(k * 8, k * 8 + 8) if g)
while data and not inuse(len(data) - 1): data.pop()
pages = [bytes(drv)] + [bytes(d) for d in data]
os.makedirs(out_dir, exist_ok=True)
for f in os.listdir(out_dir):
    if f.upper().startswith('CYBORGOS.Z') and f[10:].isdigit(): os.remove(os.path.join(out_dir, f))
files = []
for n, k in enumerate(range(0, len(pages), per)):
    d = b''.join(pages[k:k + per]); nm = 'CYBORGOS.Z%d' % (n + 1)
    open(os.path.join(out_dir, nm), 'wb').write(ntcrun.amsdos_header(d, 0x1000) + d)
    files.append((nm, len(pages[k:k + per])))
inc = ['; COSZ.INC - made by packz.py: the system drive Z ready-made (%d commands, %dK)' % (cmds, kb),
       'COSZ_FILES  equ %d' % len(files), 'COSZ_PAGES  equ %d                  ; the pages in the files' % len(pages),
       'COSZ_CLAIM  equ %d                  ; the pages Z keeps (D_POOL\'s slots + the driver page)' % claim,
       'COSZ_ENT    equ 16                  ; an entry: its first page (0 the driver page), its pages, the name\'s length, the name (0s after it)',
       'cosz_files:']
fp = 0
for nm, np in files:
    inc.append('            db %d, %d, %d, "%s"\n            ds %d' % (fp, np, len(nm), nm, 13 - len(nm))); fp += np
inc.append('cosz_last   equ cosz_files + (COSZ_FILES - 1) * COSZ_ENT')
open(os.path.join(out_dir, 'COSZ.INC'), 'w').write('\n'.join(inc) + '\n')
if sym:
    s = {}
    for line in open(sym):
        p = line.replace(':', ' ').split()
        if len(p) >= 3 and p[1].upper() == 'EQU': s[p[0]] = int(p[2].replace('0x', '').replace('#', ''), 16)
    out = ['; COSCYB.INC - made by packz.py from %s: the CYBORGOS.BIN COSLOAD.BIN starts' % os.path.basename(sym)]
    s['ntc_end'] = max(s.get('ntc_end', 0), s.get('ntc_fileend', 0))   # (the window data: in the file)
    for k, n in (('CYB_END', 'ntc_end'), ('CYB_FREE', 'ntc_free'), ('CYB_FWBLK', 'ntc_fwblk'), ('CYB_FWTOP', 'ntc_fwtop')):
        if n not in s: print('PACKZ FAIL: %s not in %s' % (n, sym)); sys.exit(1)
        out.append('%-11s equ #%04X' % (k, s[n]))
    if s['ntc_start'] != 0x40: print('PACKZ FAIL: CYBORGOS.BIN not at #0040'); sys.exit(1)
    open(os.path.join(out_dir, 'COSCYB.INC'), 'w').write('\n'.join(out) + '\n')
print('PACKZ files=%d pages=%d claim=%d commands=%d (%dK)' % (len(files), len(pages), claim, cmds, kb))
