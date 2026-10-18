# a web server for the network tests (NTC_M4: the M4 stand-in's sockets reach it) - scratch test
# tool, not delivered.  python3 websrv.py PORT DIR
#   /NAME          DIR/NAME as it is (an 8BML page), the query ignored
#   /echo?a=1&b=2  an 8BML page listing the request's parameters (t"a=1" ...), decoded
#   /moved         a 302 to /echo?moved=1
#   /big?n=N       an 8BML page of N bytes or so (lines of text)
#   ...&raw=W      any of them as a raw page for a screen W wide (tools/rawpage/8bml2raw.py:
#                  RAWYING, RAWYANG)
# HTTP/1.0 or 1.1 (keep-alive when asked for, Content-Length always); each request logged to
# DIR/requests.log (its first line)
import sys, os, socket, threading, urllib.parse
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'tools', 'rawpage'))
import importlib; rawpage = importlib.import_module('8bml2raw')

def page(title, lines):
    q = lambda t: t.replace('\\', '\\\\').replace('"', '\\"')
    return ('-"1","%s":p"%s":n:' % (q(title), q(title)) + ''.join('t"%s":n:' % q(x) for x in lines) + '.').encode('latin-1')

def answer(path, d):
    u = urllib.parse.urlsplit(path)
    if u.path == '/echo':
        ps = urllib.parse.parse_qsl(u.query, keep_blank_values=True)
        return 200, {}, page('Echo', ['%s=%s' % (k, v) for k, v in ps] or ['(no parameters)'])
    if u.path == '/moved':
        return 302, {'Location': '/echo?moved=1'}, b''
    if u.path == '/big':
        n = int(dict(urllib.parse.parse_qsl(u.query)).get('n', '4000'))
        ls = []; k = 0
        while sum(len(x) + 5 for x in ls) < n: ls.append('line %d of the big page, some words to fill it out' % k); k += 1
        return 200, {}, page('Big', ls)
    f = os.path.join(d, u.path.lstrip('/'))
    if u.path != '/' and os.path.isfile(f): return 200, {}, open(f, 'rb').read()
    return 404, {}, page('Not found', [u.path])

def serve(c, d):
    f = c.makefile('rb')
    try:
        while True:
            l = f.readline()
            if not l: break
            h = {}
            while True:
                x = f.readline()
                if not x or x in (b'\r\n', b'\n'): break
                k, _, v = x.decode('latin-1').partition(':'); h[k.strip().lower()] = v.strip()
            meth, path, ver = (l.decode('latin-1').split() + ['', '', ''])[:3]
            with open(os.path.join(d, 'requests.log'), 'a') as lg: lg.write(l.decode('latin-1').strip() + '\n')
            code, hd, body = answer(path, d)
            q = dict(urllib.parse.parse_qsl(urllib.parse.urlsplit(path).query, keep_blank_values=True))
            if code != 302 and q.get('raw', '').isdigit():
                body = rawpage.raw(body, int(q['raw']))
            keep = ver == 'HTTP/1.1' and h.get('connection', '').lower() != 'close'
            r = 'HTTP/1.1 %d %s\r\nContent-Length: %d\r\nContent-Type: text/plain\r\nConnection: %s\r\n' % (
                code, {200: 'OK', 302: 'Found', 404: 'Not Found'}[code], len(body), 'keep-alive' if keep else 'close')
            for k, v in hd.items(): r += '%s: %s\r\n' % (k, v)
            c.sendall(r.encode() + b'\r\n' + body)
            if not keep: break
    finally:
        c.close()

def main():
    port, d = int(sys.argv[1]), sys.argv[2]
    s = socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(('127.0.0.1', port)); s.listen(8)
    while True:
        c, _ = s.accept()
        threading.Thread(target=serve, args=(c, d), daemon=True).start()

if __name__ == '__main__':
    main()
