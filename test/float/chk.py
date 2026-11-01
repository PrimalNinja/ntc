import struct, random, subprocess, sys, os
# where NTC's test folder (ntcrun.py) and Float.cls are
NTC_TEST = os.environ.get('NTC_TEST', os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
FLOAT_CLS = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'src', 'lib', 'z80', 'Float.cls')
os.makedirs('/tmp/fp', exist_ok=True)
def f2l(x): return struct.unpack('<I',struct.pack('<f',x))[0]
def l2f(n): return struct.unpack('<f',struct.pack('<I',n&0xFFFFFFFF))[0]
def f32(x):
    try: return struct.unpack('<f',struct.pack('<f',x))[0]
    except OverflowError: return float('inf') if x>0 else float('-inf')
def run(lines):
    open('/tmp/fp/c.bas','w').write("Dim lngA As Long, lngB As Long\n"+'\n'.join(lines)+'\n')
    out=subprocess.run(['python3','ntcrun.py','/tmp/fp/c.bas','',FLOAT_CLS,'--platform=test'],cwd=NTC_TEST,capture_output=True,text=True,timeout=250,env={'NTC_LIMIT':'200000','PATH':os.environ.get('PATH','')+':/usr/local/bin:/usr/bin:/bin'}).stdout
    return [l.rstrip() for l in out.split('\n') if l.strip() and not l.startswith('---') and 'Pass' not in l]
def ulps(a,b):
    if a==b: return 0
    return abs((a if a<0x80000000 else -(a&0x7FFFFFFF)) - (b if b<0x80000000 else -(b&0x7FFFFFFF)))
random.seed(int(sys.argv[1]) if len(sys.argv)>1 else 7)
def rnd():
    m=random.uniform(1,10)*(10**random.randint(-8,8)); return f32(m*random.choice([1,-1]))
cases=[(rnd(),rnd()) for i in range(40)]+[(1.0,1.0),(1.0,-1.0),(0.0,5.0),(5.0,0.0),(1e30,1e30),(16777216.0,1.0),(0.1,0.2),(1.5,-1.25),(123456.0,0.001),(-3.0,-3.0)]
bad=0; worst=0; n=0
for i in range(0,len(cases),20):
    ch=cases[i:i+20]; L=[]
    for a,b in ch:
        L.append("lngA = &H%08X : lngB = &H%08X"%(f2l(a),f2l(b)))
        L.append('Print Hex$(Float.Add(lngA, lngB)); " "; Hex$(Float.Subtract(lngA, lngB)); " "; Hex$(Float.Multiply(lngA, lngB)); " "; Hex$(Float.Divide(lngA, lngB))')
    out=run(L)[-len(ch):]
    for (a,b),ln in zip(ch,out):
        got=[int(x,16) for x in ln.split()]
        exp=[f32(a+b),f32(a-b),f32(a*b),f32(a/b) if b!=0 else (float('inf') if a>=0 else float('-inf'))]
        for g,e,op in zip(got,exp,'+-*/'):
            n+=1
            el=f2l(e) if e==e else 0
            if abs(e)<1.18e-38: el=0 if e>=0 else 0x80000000
            u=ulps(g,el) if not (g in (0,0x80000000) and el in (0,0x80000000)) else 0
            worst=max(worst,u)
            if u>1: bad+=1; print("BAD %g %s %g: got %08X want %08X (%d ulp)"%(a,op,b,g,el,u))
print("checked",n,"results; off by more than 1 ulp:",bad,"; worst",worst,"ulp")
if n!=len(cases)*4: print("FAIL: %d results for %d cases - the program did not run (sjasmplus on the PATH?)"%(n,len(cases)*4))
# exact ties (2026-11-01): a sum exactly halfway between two singles, at several scales and both
# signs, must round as the engine's rule says - halves away from zero (half up in magnitude) -
# bit for bit (not within 1 ulp): a change to the engine's rounding (to even, say) shows here
import math
def halfup(x):
    if x==0: return 0.0
    lo=f32(x)
    if lo==x: return lo
    s=1 if x>0 else -1; m=abs(x)
    a=abs(lo); b=struct.unpack('<f',struct.pack('<I',f2l(a)+1 if a<m else f2l(a)-1))[0]
    lo2,hi2=min(a,b),max(a,b)
    d1=m-lo2; d2=hi2-m
    return s*(hi2 if d2<=d1 else lo2)
ties=[]
for k in (-20,-3,0,5,40):
    for lsb in (0,1):
        a=math.ldexp(1.0+lsb*2.0**-23,k); b=math.ldexp(2.0**-24,k)
        ties.append((a,b)); ties.append((-a,-b))
L=[]
for a,b in ties:
    L.append("lngA = &H%08X : lngB = &H%08X"%(f2l(a),f2l(b)))
    L.append('Print Hex$(Float.Add(lngA, lngB))')
out=run(L)[-len(ties):]
tb=0
for (a,b),ln in zip(ties,out):
    g=int(ln.split()[0],16); e=f2l(halfup(a+b))
    if g!=e: tb+=1; print("TIE %r + %r: got %08X want %08X"%(a,b,g,e))
print("ties checked",len(out),"of",len(ties),"; wrong:",tb)
if len(out)!=len(ties): print("FAIL: the tie program did not run")
