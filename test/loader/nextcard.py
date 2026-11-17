#!/usr/bin/env python3
# nextcard.py - a NextZXOS card for the Loader test: BASE.MMC (a NextZXOS card image) copied, NTC.NEX
# (this folder's Main.bas built for zxn, with Do / Loop added at its end so it stays up) and DATA.BIN put
# on it, AUTOEXEC.BAS running it.   python3 nextcard.py BASE.MMC OUT.MMC root|sub
#   root: /LDTEST.NEX and /DATA.BIN, run by .nexload /LDTEST.NEX
#   sub:  both in /LDT, run by .cd /LDT then .nexload LDTEST.NEX (the file must come from /LDT)
# Needs pip install pyfatfs (and setuptools below 81). (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
import struct, sys, shutil
from pyfatfs import PyFatFS
def bas(lines):
    prog=b''
    for n,cmd in lines:
        body=cmd.encode()+b'\r'
        prog+=struct.pack('>H',n)+struct.pack('<H',len(body))+body
    hdr=bytearray(128); hdr[0:8]=b'PLUS3DOS'; hdr[8]=0x1A; hdr[9]=1
    struct.pack_into('<I',hdr,11,128+len(prog)); struct.pack_into('<H',hdr,16,len(prog)); struct.pack_into('<H',hdr,18,10); struct.pack_into('<H',hdr,20,len(prog))
    hdr[127]=sum(hdr[:127])&255
    return bytes(hdr)+prog
base,out,mode=sys.argv[1:4]
shutil.copy(base,out)
d=open(out,'rb').read(512); start=int.from_bytes(d[0x1C6:0x1CA],'little')
fs=PyFatFS.PyFatFS(out,offset=start*512)
data=bytes([(i*7+3)&255 for i in range(200)])
nex=open('NTC.NEX','rb').read()
if mode=='root':
    fs.writebytes('/LDTEST.NEX',nex); fs.writebytes('/DATA.BIN',data)
    lines=[(10,'.nexload /LDTEST.NEX')]
else:
    if not fs.exists('/LDT'): fs.makedir('/LDT')
    fs.writebytes('/LDT/LDTEST.NEX',nex); fs.writebytes('/LDT/DATA.BIN',data)
    if fs.exists('/DATA.BIN'): fs.remove('/DATA.BIN')
    lines=[(10,'.cd /LDT'),(20,'.nexload LDTEST.NEX')]
fs.writebytes('/NEXTZXOS/AUTOEXEC.BAS',bas(lines))
print(fs.listdir('/')[:12]); fs.close()
