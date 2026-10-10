import sys, re, subprocess, os
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
def assemble(path):
    b=path[:-4]+'.bin'; s=path[:-4]+'.sym'
    r=subprocess.run([SJ,'--nologo','--raw='+b,'--sym='+s,path],capture_output=True,text=True)
    if r.returncode: print(r.stdout,r.stderr); sys.exit(1)
    syms={}
    for line in open(s):
        m=re.match(r'^(\S+):\s+EQU\s+0x([0-9A-Fa-f]+)',line)
        if m: syms[m.group(1).lower()]=int(m.group(2),16)
    return open(b,'rb').read(),syms
class CPC:
    def __init__(s,binary,org,typed,syms):
        s.m=m=z80.Z80Machine(); m.set_memory_block(org,binary)
        m.set_memory_block(0xBFF0,b'\x76'); m.set_memory_block(0xBE00-2,bytes([0xF0,0xBF])); m.sp=0xBE00-2
        m.set_memory_block(0xBFE0,bytes([0xED,0x56,0xC3,org&255,org>>8])); m.pc=0xBFE0   # im 1 : jp org
        m.set_memory_block(0x38,bytes([0xFB,0xC9]))   # stand in for the firmware's handler
        s.ints=0
        s.line=0; s.scans=0; s.typed=list(typed); s.phase=0; s.cur=None; s.mode=None; s.vs=0; s.ga=[]
        m.set_output_callback(s.out); m.set_input_callback(s.inp); s.syms=syms
    def out(s,port,val):
        hi=(port>>8)&0xff
        if hi==0x7f: s.ga.append(val); s.mode=val&3 if (val&0xC0)==0x80 else s.mode
        elif hi==0xf6: s.line=val&15
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
            s.cur=KEYS[s.typed.pop(0)]; s.phase=1
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
    extra=[a for a in sys.argv[3:]]
    r=subprocess.run(['node',os.path.join(os.path.dirname(os.path.abspath(__file__)), 'cli.js'),bas]+extra,capture_output=True,text=True)
    if r.stderr: print(r.stderr)
    open(asm,'w').write(r.stdout)
    b,syms=assemble(asm)
    c=CPC(b,0x4000,typed,syms); c.run()
    print(c.screen(loadfont(syms,c.m.memory)))
    print('--- halted' if c.m.halted else '--- NOT halted', 'sp=%04x'%c.m.sp, 'ints=%d'%c.ints, 'T=%d'%c.T, 'gate array writes', ['%02X'%v for v in c.ga])
