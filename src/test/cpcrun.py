import sys, os, re, subprocess, os
import z80
SJ=os.environ.get('SJASMPLUS', 'sjasmplus')   # sjasmplus on the PATH, or set SJASMPLUS
KEYS={}  # char -> (line,bit,shift)
km=['0,0,0,9,6,3,\r,.','0,0,7,8,5,1,2,0','0,[,\r,],4,0,\\,0','^,-,@,p,;,:,/,.','0,9,o,i,l,k,m,,'.replace(',,,',',COMMA,'),'8,7,u,y,h,j,n,SP','6,5,r,t,g,f,b,v','4,3,e,w,s,d,c,x','1,2,0,q,0,a,0,z','0,0,0,0,0,0,0,DEL']
rows=[['0','0','0','9','6','3','\r','.'],['0','0','7','8','5','1','2','0'],['0','[','\r',']','4','0','\\','0'],['^','-','@','p',';',':','/','.'],['0','9','o','i','l','k','m',','],['8','7','u','y','h','j','n',' '],['6','5','r','t','g','f','b','v'],['4','3','e','w','s','d','c','x'],['1','2','0','q','0','a','0','z'],['0','0','0','0','0','0','0','\x7f']]
for L in (3,4,5,6,7,8):
    for b,c in enumerate(rows[L]):
        if c!='0' or L==4: KEYS.setdefault(c,(L,b,False))
KEYS['\r']=(2,2,False); KEYS['\x7f']=(9,7,False)
for c in 'abcdefghijklmnopqrstuvwxyz': KEYS[c.upper()]=(KEYS[c][0],KEYS[c][1],True)
KEYS['-']=(3,1,False); KEYS['0']=(4,0,False)
# stand in for the CPC lower ROM: only the character matrices (#3800, chars 32-126 from
# #3900) - the public domain font8x8_basic NTC used before, not Amstrad's ROM
LOWROM=bytearray(0x4000)
LOWROM[0x3900:0x3900+760]=bytes(int(x,16) for l in open(os.path.join(os.path.dirname(os.path.abspath(__file__)),'font_standin.txt')) if not l.startswith(';') for x in l.split(';')[0].split())
class RamBanks:
    # the gate array's RAM setting (port #78xx-#7Fxx, value #C0-#FF) on a machine with kb K of RAM.
    # The setting's low 3 bits pick what is in the four 16K slots (main RAM pages 0-3, a bank's
    # pages 4-7): C0 0,1,2,3  C1 0,1,2,7  C2 4,5,6,7 (the whole bank)  C3 0,3,2,7  C4-C7 0,n,2,3.
    # Bits 3-5 pick the 64K bank, the port's high byte the 512K block (#7F = the first ... #78 the
    # eighth: 4MB). Banks past the ones fitted wrap round (a 6128 has one), a 64K machine ignores
    # every setting. NTC_RAM sets kb (64, 128, 576 = a 512K expansion, 4160 = 4MB; default 128).
    MAP = {0: (0, 1, 2, 3), 1: (0, 1, 2, 7), 2: (4, 5, 6, 7), 3: (0, 3, 2, 7), 4: (0, 4, 2, 3), 5: (0, 5, 2, 3), 6: (0, 6, 2, 3), 7: (0, 7, 2, 3)}
    def __init__(s, m, kb=None):
        kb = int(kb or os.environ.get('NTC_RAM', '128'))
        s.m = m; s.nb = max(0, (kb - 64) // 64); s.ext = bytearray(s.nb * 0x10000)
        s.mainp = [None] * 4; s.view = [('m', 0), ('m', 1), ('m', 2), ('m', 3)]; s.writes = 0
    def set(s, val, hi=0x7F):
        s.writes += 1
        cfg = val & 7
        if s.nb == 0: cfg = 0
        bank = ((((0x7F - hi) & 7) * 8 + ((val >> 3) & 7)) % s.nb) if s.nb else 0
        new = [('m', p) if p < 4 else ('x', bank, p - 4) for p in RamBanks.MAP[cfg]]
        if new == s.view: return
        mem = s.m.memory
        for k in range(4):
            if s.view[k] != new[k]: s.store(s.view[k], bytes(mem[k * 0x4000:(k + 1) * 0x4000]))
        for k in range(4):
            if s.view[k] != new[k]: s.m.set_memory_block(k * 0x4000, s.load(new[k]))
        s.view = new
    def store(s, pid, data):
        if pid[0] == 'm': s.mainp[pid[1]] = data
        else: o = pid[1] * 0x10000 + pid[2] * 0x4000; s.ext[o:o + 0x4000] = data
    def load(s, pid):
        if pid[0] == 'm': return s.mainp[pid[1]]
        o = pid[1] * 0x10000 + pid[2] * 0x4000; return bytes(s.ext[o:o + 0x4000])
    def main_page(s, i):
        # main RAM's page i as it is now (the CRTC always shows main RAM: page 3 is the screen)
        for k in range(4):
            if s.view[k] == ('m', i): return bytes(s.m.memory[k * 0x4000:(k + 1) * 0x4000])
        return s.mainp[i]
def assemble(path):
    # sjasmplus runs in the .asm's folder, so files it writes itself (overlay classes'
    # .PAG files, OUTPUT) land there; they are copied to the harness's disc folders
    # (t/files/A and TAPE) for the program to load. The binary is cut at ntc_end: the
    # overlays follow it in --raw output.
    import glob, shutil
    d=os.path.dirname(os.path.abspath(path)); base=os.path.basename(path)
    b=base[:-4]+'.bin'; s=base[:-4]+'.sym'
    # the page files the assembly writes (OUTPUT "NAME.001" / SAVEAMSDOS "NAME.001", ...)
    pages=[]
    for line in open(path):
        m=re.match(r'^\s+(?:OUTPUT|SAVEAMSDOS)\s+"([^"]+)"\s*,?\s*(\S*)',line)
        if m and (line.lstrip().startswith('OUTPUT') or m.group(2).startswith('ovl_')): pages.append(m.group(1))
    for f in pages:
        if os.path.exists(os.path.join(d,f)): os.remove(os.path.join(d,f))
    r=subprocess.run([SJ,'--nologo','--raw='+b,'--sym='+s,base],capture_output=True,text=True,cwd=d)
    if r.returncode: print(r.stdout,r.stderr); sys.exit(1)
    syms={}
    for line in open(os.path.join(d,s)):
        m=re.match(r'^(\S+):\s+EQU\s+0x([0-9A-Fa-f]+)',line)
        if m: syms[m.group(1).lower()]=int(m.group(2),16)
    data=open(os.path.join(d,b),'rb').read()
    if 'ntc_end' in syms and 'ntc_start' in syms: data=data[:syms.get('ntc_fileend',syms['ntc_end'])-syms['ntc_start']]   # (ntc_fileend: the window data after the program, in the file)
    import ntcrun
    # NTC_KEEPPAGES=1: leave the disc folders' page files as they are (a test of a page file
    # from another build: the loader must refuse it)
    for f in ([] if os.environ.get('NTC_KEEPPAGES') else [os.path.join(d,p) for p in pages if os.path.exists(os.path.join(d,p))]):
        for dev in ('A','TAPE'):
            os.makedirs(os.path.join(ntcrun.FILES,dev),exist_ok=True); shutil.copy(f,os.path.join(ntcrun.FILES,dev,os.path.basename(f)))
    return data,syms
def endkey_set(m, syms):
    # Option PressAnyKeyOnEnd: a breakpoint on kw_waitkey (its key at the end); NTC_NOENDKEY=1: none
    if syms and 'kw_waitkey' in syms and not os.environ.get('NTC_NOENDKEY'): m.set_breakpoint(syms['kw_waitkey'])
def endkey_run(obj):
    # run on; at kw_waitkey, when the typed text is used up, a Return is typed (the test needn't)
    m = obj.m; ev = m.run()
    while ev & 1:
        if not obj.typed: obj.typed.append('\r')
        ev = m.step_over_breakpoint()
        if m.halted or m.ticks_to_stop <= 0: break
        ev = m.run()

class CPC:
    def __init__(s,binary,org,typed,syms):
        s.m=m=z80.Z80Machine(); m.set_memory_block(org,binary)
        m.set_memory_block(0xBFF0,b'\x76'); m.set_memory_block(0xBE00-2,bytes([0xF0,0xBF])); m.sp=0xBE00-2
        m.set_memory_block(0xBFE0,bytes([0xED,0x56,0xC3,org&255,org>>8])); m.pc=0xBFE0   # im 1 : jp org
        m.set_memory_block(0x38,bytes([0xFB,0xC9]))   # stand in for the firmware's handler
        s.ints=0; s.romon=False; s.ram=RamBanks(m)
        s.line=0; s.scans=0; s.typed=list(typed); s.phase=0; s.cur=None; s.mode=None; s.vs=0; s.ga=[]
        m.set_output_callback(s.out); m.set_input_callback(s.inp); s.syms=syms
        endkey_set(m, syms)
        # the firmware calls the cpc platform's FileSystem makes (AMSDOS through the firmware):
        # stand-ins on low ports #E0.. (the CPC decodes its I/O on the high byte), as in ntcrun
        import ntcrun
        s.fw = ntcrun.Host.__new__(ntcrun.Host); s.fw.m = m; s.fw.p = 'cpcfw'
        s.fw.cas_in = None; s.fw.cas_out = None; s.fw.amsdos = False; s.fw.cas_dev = 'TAPE'; s.fw.disk = 'A'; s.fw.cas_ascii = False; s.fw.cas_load = 0
        os.makedirs(ntcrun.FILES, exist_ok=True)
        s.fwport = {}; s.fwaddr = {0xDF: 0x18}
        for i, a in enumerate(sorted(ntcrun.FW)):
            if ntcrun.FW[a].startswith(('cas_', 'kl_')):
                m.set_memory_block(a, bytes([0xD3, 0xE0 + i, 0xC9])); s.fwport[0xE0 + i] = ntcrun.FW[a]; s.fwaddr[0xE0 + i] = a
        m.set_memory_block(0x18, bytes([0xD3, 0xDF, 0xC9]))     # RST 3: AMSDOS's far call CAS entries
        # Library: ROM - the keyword ROM's image (NTC_XROM) in upper ROM slot XSLOT: at #C000 while
        # the gate array has the upper ROM on and that slot is selected (writes go to the RAM below)
        s.uon = False; s.romsel = 0; s.umapped = None; s.uram = None
        s.xroms = ntcrun.load_xroms()          # (a set of more than one ROM: slots 6, 5, 4 ...)
        if s.xroms:
            m.set_write_callback(s.uwrite)
    def uwrite(s, a, v):
        s.uram[a - 0xC000] = v
    def umap(s):
        if not s.xroms: return
        want = None
        if s.uon: want = s.romsel if s.romsel in s.xroms else 'basic'
        if want == s.umapped: return
        m = s.m
        if s.umapped is not None:
            m.unmark_addrs(0xC000, 0x4000, m.WRITE_MARK); m.set_memory_block(0xC000, bytes(s.uram)); s.uram = None
        if want is not None:
            s.uram = bytearray(m.memory[0xC000:0x10000])
            m.set_memory_block(0xC000, s.xroms[want] if want != 'basic' else bytes([0x80]) + bytes(0x3FFF))   # another ROM: BASIC's type byte
            m.mark_addrs(0xC000, 0x4000, m.WRITE_MARK)
        s.umapped = want
    def ramset(s,val,hi):
        # a RAM setting: the ROM images come off the slots while the pages move, then back on
        lo=s.romon; was=s.umapped
        if lo: s.lowrom(False)
        if was is not None:
            m=s.m; m.unmark_addrs(0xC000,0x4000,m.WRITE_MARK); m.set_memory_block(0xC000,bytes(s.uram)); s.uram=None; s.umapped=None
        s.ram.set(val,hi)
        if lo: s.lowrom(True)
        s.umap()
    def lowrom(s,on):
        # the lower ROM over #0000-#3FFF: reads give the ROM, writes still go to the RAM below
        m=s.m
        if on and not s.romon:
            s.ramlo=bytearray(m.memory[0:0x4000]); m.set_memory_block(0,bytes(LOWROM)); s.romon=True
        elif not on and s.romon:
            cur=m.memory[0:0x4000]
            for i in range(0x4000):
                if cur[i]!=LOWROM[i]: s.ramlo[i]=cur[i]      # written while the ROM was on
            m.set_memory_block(0,bytes(s.ramlo)); s.romon=False
    def out(s,port,val):
        lo=port&0xff
        if (lo in s.fwport or lo==0xDF) and s.m.pc-2==s.fwaddr[lo]:
            s.fwcall(lo); return     # a stand-in's out (n),a - not a real port write with that low byte
        hi=(port>>8)&0xff
        if 0x78<=hi<=0x7e and (val&0xC0)==0xC0:
            s.ramset(val,hi); return       # a RAM setting for another 512K block (4MB)
        if hi==0x7f:
            s.ga.append(val); s.mode=val&3 if (val&0xC0)==0x80 else s.mode
            if (val&0xC0)==0x80: s.lowrom(not (val&4)); s.uon = not (val&8); s.umap()
            elif (val&0xC0)==0xC0: s.ga.pop(); s.ramset(val,hi)
        elif hi==0xf6: s.line=val&15
        elif hi==0xdf: s.romsel=val; s.umap()      # the upper ROM's slot (a keyword ROM set's far calls)
    def fwcall(s,lo):
        import ntcrun
        m=s.m; fw=s.fw
        if lo==0xDF:
            sp=m.sp; ret=m.memory[sp]|(m.memory[sp+1]<<8)
            ok=fw.cas(ntcrun.FW[ret-1]); m.f=(m.f|1) if ok else (m.f&0xFE); m.sp=sp+2; return
        f=s.fwport[lo]
        if f.startswith('cas_'):
            ok=fw.cas(f); m.f=(m.f|1) if ok else (m.f&0xFE)
        elif f=='kl_rom_walk' or (f=='kl_init_back' and m.c==7):
            fw.amsdos_on(); m.hl=0xA6FB
        elif f=='kl_find_command':
            a=m.hl; n=''
            while True:
                c=m.memory[a]; n+=chr(c&0x7F); a+=1
                if c&0x80: break
            if fw.amsdos and n in ntcrun.RSX: m.hl=0x4000+ntcrun.RSX.index(n); m.c=7; m.f=m.f|1
            else: m.f=m.f&0xFE
        elif f in ('kl_rom_select','kl_rom_deselect'):
            old=s.romsel; s.romsel=m.c; s.uon=(f=='kl_rom_select') or bool(s.uon); s.umap(); m.c=old; m.b=0
        elif f=='kl_far_pcall':
            n=ntcrun.RSX[m.hl-0x4000]
            if n=='TAPE': fw.cas_dev='TAPE'
            elif n=='DISC': fw.cas_dev=fw.disk
            else:
                fw.disk=n
                if fw.cas_dev!='TAPE': fw.cas_dev=n
    def inp(s,port):
        hi=(port>>8)&0xff
        if hi==0xf4:
            v=0xff
            if s.cur:
                L,bit,sh=s.cur
                if s.line==L: v&=~(1<<bit)
                if sh and s.line==2: v&=~(1<<5)
            if s.line==9:
                # a scan by the Keys class (Down / Joystick) moves on held keys ({n}) and pauses (~) only:
                # typed keys are for Inkey's scan, which a program's Keys calls mustn't hurry
                ks=s.syms.get('ntc_ksc_line') if s.syms else None
                typedkey=(s.phase==1 and getattr(s,'tkey',False)) or (s.phase==0 and s.typed and s.typed[0] not in '{~')
                if ks is None or not (ks<=s.m.pc<ks+16) or not typedkey:
                    s.tick()
            return v&0xff
        if hi==0xf5:
            s.vs+=1; return 1 if (s.vs//50)%2 else 0
        return 0xff
    def tick(s):
        s.scans+=1
        if s.phase==0 and s.typed and s.scans%3==0:
            c=s.typed.pop(0)
            if c=='{':                                      # {n} = key number n held (Keys class)
                n=''
                while s.typed and s.typed[0]!='}': n+=s.typed.pop(0)
                if s.typed: s.typed.pop(0)
                s.cur=(int(n)//8,int(n)%8,False); s.phase=1; s.tkey=False
            else:
                s.cur=None if c=='~' else KEYS[c]; s.phase=1; s.tkey=(c!='~')     # ~ = a pause: no key for one press
        elif s.phase==1 and s.scans%3==0: s.cur=None; s.phase=0; s.tkey=False
    def run(s,limit=30000):
        # CPC: an interrupt every 13333 T, held until the Z80 takes it
        n=0; s.T=0
        while not s.m.halted:
            s.m.ticks_to_stop=13333; endkey_run(s); n+=1; s.T+=13333-s.m.ticks_to_stop
            if s.m.halted: break
            steps=0
            while not s.m.halted and steps<2000:
                if s.m.iff1 and s.m.on_handle_active_int(): s.ints+=1; break
                s.m.ticks_to_stop=1; endkey_run(s); steps+=1; s.T+=1-s.m.ticks_to_stop
            if n>limit: print('TIMEOUT pc=%04x sp=%04x'%(s.m.pc,s.m.sp)); break
        s.chunks=n
    def screen(s,font):
        mem=bytearray(s.m.memory)
        if s.uram is not None and s.ram.view[3]==('m',3): mem[0xC000:0x10000]=s.uram     # the screen under the ROM
        else: mem[0xC000:0x10000]=s.ram.main_page(3)                                     # the CRTC shows main RAM
        mode=s.syms and s.m.memory[s.syms['ntc_smode']]
        bpc,cols={0:(4,20),1:(2,40),2:(1,80)}[mode]
        out=[]
        for r in range(25):
            line=''
            for c in range(cols):
                pat=[]
                for y in range(8):
                    a=0xC000+r*80+c*bpc+y*0x800; v=0
                    for k in range(bpc):
                        b=mem[a+k]
                        if bpc==1: v=b
                        elif bpc==2: v|=(b&0xF0)>>(4*k)
                        else: v|=(b&0xC0)>>(2*k)
                    pat.append(v)
                line+=font.get(tuple(pat),'#')
            out.append(line.rstrip())
        while out and not out[-1]: out.pop()
        return '\n'.join(out)
def loadfont(syms,mem):
    f={}
    base=syms['ntc_font']
    for c in range(32,127):
        f[tuple(mem[base+(c-32)*8+i] for i in range(8))]=chr(c)
    return f
if __name__=='__main__':
    bas=sys.argv[1]; typed=(sys.argv[2] if len(sys.argv)>2 else '').replace('\\n','\r').replace('\\x7f','\x7f')
    asm=bas[:-4]+'.asm'
    extra=[a for a in sys.argv[3:] if not a.startswith('--ram=')]
    for a in sys.argv[3:]:
        if a.startswith('--ram='): os.environ['NTC_RAM']=a[6:]
    r=subprocess.run(['node',os.path.join(os.path.dirname(os.path.abspath(__file__)), 'cli.js'),bas]+extra,capture_output=True,text=True)
    if r.stderr: print(r.stderr)
    open(asm,'w').write(r.stdout)
    b,syms=assemble(asm)
    c=CPC(b,syms.get('ntc_start',0x4000),typed,syms); c.run()   # loaded at the program's org (CPC: #0040)
    print(c.screen(loadfont(syms,c.m.memory)))
    print('--- halted' if c.m.halted else '--- NOT halted', 'sp=%04x'%c.m.sp, 'ints=%d'%c.ints, 'T=%d'%c.T, 'gate array writes', ['%02X'%v for v in c.ga])
