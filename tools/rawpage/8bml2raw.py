#!/usr/bin/env python3
"""8bml2raw.py - an 8BML page laid out for a screen width, as a raw page: what RAWYING and
RAWYANG (CyborgOS's raw browsers) read with no 8BML of their own - the reference for a server's
raw renderer (it lays a page out exactly as YING's Bml.cls does).

    python3 8bml2raw.py [--local] PAGE.8BM WIDTH [OUT]      (OUT: else to stdout)
    import: raw(page_bytes, width, local=False) -> bytes
--local: a local page (HOME.8BM -> HOME.RAW): its links to NAME.8BM files go to NAME.RAW

THE RAW FORMAT (RAW.TXT has it in full)
A record a line, its first character its kind, CR LF (or LF) after it. Numbers are decimal,
one space between them; a text part (a name, a value, an address, a choice) goes from a TAB to
the next TAB or the record's end - it never holds a TAB, CR or LF. Nothing is escaped.
  T<title>                       the page's title
  L<text>                        the next row of the page (0, 1, 2 ...) as it is shown: WIDTH
                                 characters at most (spaces at its end may be left off)
  K<row> <col> <len><TAB><url>   a link: where it is on the page, its address ("<": back)
  F<kind> <row> <col> <width> <rows> <max> <flags> <form><TAB><name><TAB><value>
                                 a form field: kind 1 a text field, 2 a text area, 3 a select;
                                 at row, col: a text field |value___| (width characters between
                                 the bars, a password's value as *), an area that on each of its
                                 rows, a select [ choice v] (width: the longest choice); max: the
                                 most characters; flags 1 mandatory, 2 a password; form: which
                                 form (the fields a button sends: its form's)
  O<code><TAB><text>             a select's choice (after its F, in order): what is sent, what is
                                 shown
  B<row> <col> <len> <form><TAB><url><TAB><action>
                                 a form's button: [ action ] at row, col - len its action's
                                 length (the link is the action's characters, from col + 2);
                                 it sends its form to url: name=value& ... &action=action
  E                              the end (anything after it is left alone)
The rows come first, in order; the rest may follow in any order (here: as the page has them).
"""
import sys

def _params(s, i):
    """the command's parameters from s[i] (to its ':' outside quotes): [(text with \\ escapes
    taken off, raw length)], the index after the command"""
    out = []
    n = len(s)
    while i < n:
        c = s[i]
        if c == ':':
            break
        i += 1
        if c != '"':
            continue
        j = i
        t = []
        while j < n and s[j] != '"':
            if s[j] == '\\' and j + 1 < n:
                j += 1
            t.append(s[j])
            j += 1
        out.append(''.join(t))
        i = j + 1
    return out, i

class Page:
    def __init__(s, width, local=False):
        s.local = local
        s.w = width
        s.rows = []          # the page's rows (strings)
        s.recs = []          # the other records, in order
        s.title = ''
        s.form = 0
        s.after_button = False

    def emit(s, text, c=0):
        line = (' ' * c + text)[:s.w]
        s.rows.append(line.rstrip())

    def link(s, row, col, n, url):
        if s.local and '://' not in url and url.upper().endswith('.8BM'):
            url = url[:-4] + '.RAW'
        if n >= 1:
            s.recs.append('K%d %d %d\t%s' % (row, col, n, url))

    def flow(s, text, pre='', al=0, url=None, ul=None):
        """text word wrapped to the width after pre (its next lines indented as far): al 0 left,
        1 centred, 2 right; url: each line a link to it; ul: a character to underline it with"""
        ind = len(pre)
        if ind >= s.w:
            ind, pre = 0, ''
        av = s.w - ind
        words = [x for x in text.replace('\t', ' ').split(' ') if x]
        # (Bml splits at any character up to 32: the same for printable text)
        words = [y for x in words for y in x.split() if y]
        k = 0
        while k < len(words):
            ll, line = 0, []
            while k < len(words):
                wd = words[k]
                wl = len(wd) + (1 if ll > 0 else 0)
                if ll + wl > av:
                    if ll == 0:                  # longer than a line: as much as fits
                        line.append(wd[:av]); ll = av
                        words[k] = wd[av:]
                        if not words[k]:
                            k += 1
                    break
                line.append(wd); ll += wl; k += 1
            c = 0
            if al == 1:
                c = (s.w - ind - ll) // 2
            if al == 2:
                c = s.w - ind - ll
            if c < 0:
                c = 0
            if url is not None:
                s.link(len(s.rows), c + ind, ll, url)
            s.emit(pre + ' '.join(line), c)
            if ul:
                s.emit(ul * ll, c + ind)
            pre = ' ' * ind

    def field_form(s):
        if s.after_button:
            s.form += 1
            s.after_button = False
        return s.form

    def text_field(s, kind, name, mx, flags, value, rows):
        wd = max(1, min(mx, s.w - 2))
        rows = max(1, min(rows, 8))
        mxv = mx * rows if kind == 2 else mx
        if mxv > 126 or mxv < 1:
            mxv = 126
        value = value[:mxv]
        shown = '*' * len(value) if flags & 2 else value
        row = len(s.rows)
        s.recs.append('F%d %d %d %d %d %d %d %d\t%s\t%s' % (kind, row, 0, wd, rows, mxv, flags, s.field_form(), name, value))
        for r in range(rows):
            t = shown[r * wd:(r + 1) * wd]
            s.emit('|' + t + '_' * (wd - len(t)) + '|')

    def select(s, name, value, flags, opts):
        wd = max([len(t) for _, t in opts] + [1])
        wd = min(wd, s.w - 5)
        shown = opts[0][1] if opts else ''
        for code, t in opts:
            if code == value:
                shown = t
        row = len(s.rows)
        s.recs.append('F3 %d %d %d %d %d %d %d\t%s\t%s' % (row, 0, wd, 1, 126, flags, s.field_form(), name, value))
        for code, t in opts:
            s.recs.append('O%s\t%s' % (code, t))
        s.emit('[ ' + shown[:wd].ljust(wd) + ' v]')

    def out(s):
        r = ['T' + s.title] + ['L' + x for x in s.rows] + s.recs + ['E']
        return ('\r\n'.join(r) + '\r\n').encode('latin-1', 'replace')

def flags_of(t):
    return (1 if 'm' in t else 0) + (2 if 'p' in t else 0)

def raw(data, width, local=False):
    s = data.decode('latin-1')
    p = Page(width, local)
    i, n = 0, len(s)
    while i < n:
        c = s[i]
        i += 1
        if c == '.':
            break
        if c <= ' ' or c == ':':
            continue
        ps, i = _params(s, i)
        g = lambda k: ps[k] if k < len(ps) else None
        if c in 'tb' and g(0) is not None:
            p.flow(g(0))
        elif c == 'p' and g(0) is not None:
            p.flow(g(0), al=1, ul='=')
        elif c == 's' and g(0) is not None:
            p.flow(g(0), al=1, ul='-')
        elif c == 'n':
            p.emit('')
        elif c == 'h':
            p.emit('-' * width)
        elif c == 'r' and g(0) is not None:
            p.emit(g(0))
        elif c == '-' and g(1) is not None:
            p.title = g(1)[:80]
        elif c in 'ld' and g(1) is not None:
            al = 2 if (c == 'l' and g(2) and 'r' in g(2)) else 0
            p.flow(g(1), pre='^ ' if c == 'd' else '-> ', al=al, url=g(0))
        elif c == 'i' and len(ps) >= 3:
            p.flow(g(2), pre='[image] ', url=g(1))      # an image: a link to it (fetched apart)
        elif c == '<':
            p.link(len(p.rows), 3, 4, '<')
            p.emit('<- Back')
        elif c == '>':
            line = ''
            row0 = len(p.rows)
            pend = []
            for k in range(0, len(ps) - 1, 2):
                u, t = ps[k], ps[k + 1]
                if len(line) + len(t) + 3 > width and line:
                    p.emit(line); line = ''
                    for x in pend: p.recs.append(x)
                    pend = []
                if line:
                    line += ' '
                if p.local and '://' not in u and u.upper().endswith('.8BM'):
                    u = u[:-4] + '.RAW'
                pend.append('K%d %d %d\t%s' % (len(p.rows), len(line) + 1, len(t), u))
                line += '[' + t + ']'
            if line:
                p.emit(line)
                p.recs.extend(pend)
        elif c == 'v' and g(0) is not None:
            k = max(1, int(g(0)) if g(0).strip().isdigit() else 1)
            cw = width // k
            row = ''
            for j in range(k):
                t = g(2 + j * 2) or ''
                row = row.ljust(j * cw) + t[:cw - 1]
            p.emit(row)
            p.emit('-' * width)
            q = 1 + k * 2
            while q + 1 < len(ps) + 1:
                cells = ps[q:q + k * 2]
                if not cells:
                    break
                row = ''
                rn = len(p.rows)
                for j in range(0, len(cells) - 1, 2):
                    u, t = cells[j], cells[j + 1][:cw - 1]
                    row = row.ljust((j // 2) * cw) + t
                    if u:
                        p.link(rn, (j // 2) * cw, len(t), u)
                p.emit(row)
                q += k * 2
        elif c == 'x' and g(1) is not None:
            t = g(1)
            row = len(p.rows)
            p.recs.append('B%d %d %d %d\t%s\t%s' % (row, 0, len(t), p.form, g(0), t))
            p.after_button = True
            p.emit('[ ' + t + ' ]')
        elif c == 'y' and len(ps) >= 3:
            p.text_field(1, g(0), int(g(1) or 0) if (g(1) or '').isdigit() else 0, flags_of(g(2)), g(3) or '', 1)
        elif c == 'z' and len(ps) >= 4:
            cols = int(g(1)) if (g(1) or '').isdigit() else 0
            rows = int(g(2)) if (g(2) or '').isdigit() else 1
            p.text_field(2, g(0), cols, flags_of(g(3)), g(4) or '', rows)
        elif c == 'w' and len(ps) >= 3:
            opts = [(ps[k], ps[k + 1]) for k in range(3, len(ps) - 1, 2)]
            p.select(g(0), g(1), flags_of(g(2)), opts)
        # m (music): left out
    return p.out()

if __name__ == '__main__':
    a = sys.argv[1:]
    loc = '--local' in a
    a = [x for x in a if x != '--local']
    if len(a) < 2:
        print(__doc__); sys.exit(1)
    o = raw(open(a[0], 'rb').read(), int(a[1]), loc)
    if len(a) > 2:
        open(a[2], 'wb').write(o)
    else:
        sys.stdout.write(o.decode('latin-1'))
