import sys
sys.path.insert(0,'/home/claude/work/emu')
import nextemu
S='/tmp/claude-0/-home-claude/763e589f-1b39-5ff1-8745-d6aace327178/scratchpad'
z=nextemu.NextX('build/DEFENDER.NEX','build/DEFENDER.sym')
Q,A,O,P,SP,B=16,8,41,40,56,60
held=set()
def v(n): return z.var(n)
def a(n,i): return z.arr(n,i)
def onframe(z):
    held.clear(); t=z.frame
    if v('var_game_over') or v('var_lives')<=0 or t<300:
        if t%80<3 and t>100: held.add(SP)
        return
    px,py=v('var_px'),v('var_py')
    best=None
    for i in range(10):
        if a('arr_estate',i)!=0:
            d=(a('arr_ex',i)-px)&1023
            if d>=512: d-=1024
            if best is None or abs(d)<abs(best[0]): best=(d,a('arr_ey',i))
    if best:
        d,ey=best
        if ey>py+2: held.add(Q)
        elif ey<py-2: held.add(A)
        if abs(d)>60: held.add(P if d>0 else O)
        elif d>0 and v('var_pdir')<0: held.add(P)
        elif d<0 and v('var_pdir')>0: held.add(O)
        if t%6<3: held.add(SP)
z.onframe=onframe
z.keysheld=lambda f: held
[z.shots.__setitem__(f,'%s/dn_%d.png'%(S,f)) for f in (150,600,1500,3000,4500)]
def per(z): print(z.frame,'fr',v('var_frames'),'wave',v('var_wave'),'score',z.deek(z.symtab['var_score']),'lives',v('var_lives'),'humans',v('var_humans_alive'),'enemies',v('var_enemies_alive'),v('var_enemies_to_spawn'),flush=True)
last=[0,0]
def rate(z):
    f=v('var_frames'); print('R', z.frame, f-last[0], 'ens', v('var_enemies_alive'), 'pvx', v('var_pvx'), 'psx', v('var_psx'), 'safe', v('var_safet')); last[0]=f
z.run_frames(int(sys.argv[1]),(25,rate))
