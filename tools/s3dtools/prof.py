# prof.py PROF.json [SYM-PREFIX]: where the time goes in an NTC harness profile (ntcrun.py with
# NTC_PROF=PROF.json: a sample at a random point of each 1/300 s - PC, bank, SP - and the symbols).
# Each sample is put on the label at or below its PC; the labels are then grouped into kinds of
# work (the AUCKLAND engine's S3d.cls names: fn_s3d_render_...). Loading (the file read, the
# Memory class) is counted apart and left out of the shares.
import json, sys, bisect, collections, re
d = json.load(open(sys.argv[1]))
syms = sorted((v, k) for k, v in d['syms'].items() if 0 <= v < 0x10000 and not k.startswith('.'))
addrs = [a for a, _ in syms]
lab = collections.Counter()
for s in d['pc']:
    i = bisect.bisect_right(addrs, s[0]) - 1
    lab[syms[i][1] if i >= 0 else '?'] += 1

def kind(n):
    if n.startswith('gfx_'):
        return 'draw: lines (gfx_line, the library)'
    m = re.match(r'fn_s3d_render_(\w+)', n)
    if not m:
        if n.startswith(('mem_', 'fs_', 'fn_s3d_load')):
            return 'loading (left out)'
        return 'other: ' + n.split('_')[0]
    s = m.group(1)
    if s.startswith(('cl_lp', 'cl_blk')) and not s.startswith('cl_lp2'):
        return 'draw: clearing the screen'
    if s.startswith(('pj_', 'pd_', 'dv_')):
        return 'calc: projection (the divide per point)'
    if s.startswith(('vx', 'vp_', 'hneg', 'vh_')):
        return 'calc: vertex transform (table additions)'
    if s.startswith(('oc', 've_oc', 'cl_lp2', 'cp_', 'clip', 'ed_', 'ucap', 't_in')):
        return 'calc: clipping, outcodes, edges'
    if s.startswith(('tr_', 'tb_', 't3_', 'mu_', 'ms', 'to_', 'mulfix', 'd3_', 'div3')):
        return 'calc: multiplies (tile positions, frame tables, trees /3)'
    if s.startswith(('cmps', 'cm_')):
        return 'calc: compares'
    return 'walk: tiles, buildings, lines, trees'

kinds = collections.Counter()
for n, v in lab.items():
    kinds[kind(n)] += v
tot = sum(v for k, v in kinds.items() if not k.startswith('loading'))
print('%d samples (%d while flying)\n' % (sum(lab.values()), tot))
for k, v in kinds.most_common():
    if not k.startswith('loading'):
        print('%5.1f%%  %s' % (100.0 * v / tot, k))
print('\nthe labels (top 40):')
for n, v in lab.most_common(40):
    print('%5.1f%%  %s' % (100.0 * v / tot, n))
