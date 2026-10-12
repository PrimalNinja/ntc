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
    # the gate array's RAM setting (port #78xx-#7Fxx, value #C0-#FF) on a machine with kb K of RAM:
    # C0 = the plain 64K, C4-C7 (+ bank * 8) = page 0-3 of a 64K bank at #4000-#7FFF; the port's
    # high byte picks the 512K block (#7F = the first, #7E the second ... #78 the eighth: 4MB).
    # Banks past the ones fitted wrap round (a 6128 has one: every setting is bank 0; a 512K
    # expansion ignores the block), a 64K machine ignores C4-C7. C1-C3 are not emulated.
    # NTC_RAM sets kb (total RAM: 64, 128, 576 = a 512K expansion, 4160 = 4MB; default 128).
    def __init__(s, m, kb=None):
        kb = int(kb or os.environ.get('NTC_RAM', '128'))
        s.m = m; s.nb = max(0, (kb - 64) // 64); s.ext = bytearray(s.nb * 0x10000)
        s.main = None; s.cur = None; s.writes = 0
    def set(s, val, hi=0x7F):
        s.writes += 1
        want = None
        if (val & 7) in (1, 2, 3): print('RamBanks: setting %02X not emulated' % val)
        if s.nb and (val & 4): want = ((((0x7F - hi) & 7) * 8 + ((val >> 3) & 7)) % s.nb, val & 3)
        if want == s.cur: return
        win = bytes(s.m.memory[0x4000:0x8000])
        if s.cur is None: s.main = win
        else:
            o = s.cur[0] * 0x10000 + s.cur[1] * 0x4000; s.ext[o:o + 0x4000] = win
        if want is None: s.m.set_memory_block(0x4000, s.main)
        else:
            o = want[0] * 0x10000 + want[1] * 0x4000; s.m.set_memory_block(0x4000, bytes(s.ext[o:o + 0x4000]))
        s.cur = want
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
    if 'ntc_end' in syms and 'ntc_start' in syms: data=data[:syms['ntc_end']-syms['ntc_start']]
    import ntcrun
    # NTC_KEEPPAGES=1: leave the disc folders' page files as they are (a test of a page file
    # from another build: the loader must refuse it)
    for f in ([] if os.environ.get('NTC_KEEPPAGES') else [os.path.join(d,p) for p in pages if os.path.exists(os.path.join(d,p))]):
        for dev in ('A','TAPE'):
            os.makedirs(os.path.join(ntcrun.FILES,dev),exist_ok=True); shutil.copy(f,os.path.join(ntcrun.FILES,dev,os.path.basename(f)))
    return data,syms
class CPC:
    def __init__(s,binary,org,typed,syms):
        s.m=m=z80.Z80Machine(); m.set_memory_block(org,binary)
        m.set_memory_block(0xBFF0,b'\x76'); m.set_memory_block(0xBE00-2,bytes([0xF0,0xBF])); m.sp=0xBE00-2
        m.set_memory_block(0xBFE0,bytes([0xED,0x56,0xC3,org&255,org>>8])); m.pc=0xBFE0   # im 1 : jp org
        m.set_memory_block(0x38,bytes([0xFB,0xC9]))   # stand in for the firmware's handler
        s.ints=0; s.romon=False; s.ram=RamBanks(m)
        s.line=0; s.scans=0; s.typed=list(typed); s.phase=0; s.cur=None; s.mode=None; s.vs=0; s.ga=[]
        m.set_output_callback(s.out); m.set_input_callback(s.inp); s.syms=syms
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
            s.ram.set(val,hi); return       # a RAM setting for another 512K block (4MB)
        if hi==0x7f:
            s.ga.append(val); s.mode=val&3 if (val&0xC0)==0x80 else s.mode
            if (val&0xC0)==0x80: s.lowrom(not (val&4))
            elif (val&0xC0)==0xC0: s.ga.pop(); s.ram.set(val,hi)
        elif hi==0xf6: s.line=val&15
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
            if s.line==9: s.tick()
            return v&0xff
        if hi==0xf5:
            s.vs+=1; return 1 if (s.vs//50)%2 else 0
        return 0xff
    def tick(s):
        s.scans+=1
        if s.phase==0 and s.typed and s.scans%3==0:
            c=s.typed.pop(0)
            s.cur=None if c=='~' else KEYS[c]; s.phase=1     # ~ = a pause: no key for one press
        elif s.phase==1 and s.scans%3==0: s.cur=None; s.phase=0
    def run(s,limit=30000):
        # CPC: an interrupt every 13333 T, held until the Z80 takes it
        n=0; s.T=0
        while not s.m.halted:
            s.m.ticks_to_stop=13333; s.m.run(); n+=1; s.T+=13333-s.m.ticks_to_stop
            if s.m.halted: break
            steps=0
            while not s.m.halted and steps<2000:
                if s.m.iff1 and s.m.on_handle_active_int(): s.ints+=1; break
                s.m.ticks_to_stop=1; s.m.run(); steps+=1; s.T+=1-s.m.ticks_to_stop
            if n>limit: print('TIMEOUT pc=%04x sp=%04x'%(s.m.pc,s.m.sp)); break
        s.chunks=n
    def screen(s,font):
        mem=s.m.memory; mode=s.syms and s.m.memory[s.syms['ntc_smode']]
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
