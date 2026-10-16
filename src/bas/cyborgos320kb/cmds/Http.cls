' Http - the network for CyborgOS programs (build for cpm with this class; NET M4 turns the
' network on): HTTP GETs over the M4's sockets, which CyborgOS drives (BDOS 131 ops 20-27 - the
' hypervisor's service page: a socket is the slot's that opened it, closed when its program ends).
' http only. HTTP/1.0, the connection closed after each GET (Connection: close).
'   Present()             True when the network is on
'   Get(url, buf, max)    url fetched into buf (max bytes at most): the body's length (the
'                         headers taken off), -1 when it failed - Code() the HTTP status (200 ...;
'                         0: no answer), Message() why it failed. Up to 3 redirects followed
'                         (301, 302, 303, 307, 308: Location). Where it ended up: Url()
'   Time()                the clock: 300 a second (its low 16 bits)
' An address: http://host[:port]/path?parameters (the #place, if any, left out). A host is a
' name (looked up: the last one kept) or 1.2.3.4
Option Explicit
Private b(15) As Byte, e(15) As Byte, ip(3) As Byte, cip(3) As Byte
Private ch As String Max 64, msg As String Max 60, fin As String Max 255, org As String Max 80
Private nxt As String Max 255, rq As String Max 140   ' (rq: the request's pieces)
Private cd As Integer, sk As Integer, hsp As Integer, cl As Long, ca As Integer, la As Integer

Public Function Present() As Integer
  b(0) = 20 : b(1) = 0
  Present = (Bdos(131, VarPtr(b)) <> 255)
End Function

Public Function Time() As Integer
  b(0) = 20 : b(1) = 3 : b(6) = 0 : b(7) = 0
  If Bdos(131, VarPtr(b)) <> 0 Then Time = 0 : Exit Function
  Time = b(6) + b(7) * 256
End Function

Public Function Code() As Integer
  Code = cd
End Function
Public Function Message() As String Max 60
  Message = msg
End Function
Public Function Url() As String Max 255
  Url = fin
End Function

Public Function Get(ByVal u As String Max 255, ByVal buf As Integer, ByVal mx As Integer) As Integer
  Dim n As Integer, k As Integer
  cd = 0 : msg = "" : nxt = ""
  fin = u
  For k = 0 To 3
    n = Get1(buf, mx)
    If n < 0 Or cd < 300 Or cd > 308 Or nxt = "" Then Exit For
    fin = nxt                                      ' (a redirect: Get1 left its address in nxt)
  Next
  Get = n
End Function

' ---- one GET of fin: the body's length (-1 failed); nxt the address it redirects to ("" none)
Private Function Get1(ByVal buf As Integer, ByVal mx As Integer) As Integer
  Dim h As String Max 64, pj As Integer, pn As Integer, j As Integer, pt As Integer, n As Integer
  Dim t0 As Integer, he As Integer, c As Integer, k As Integer, r As Integer
  Get1 = -1 : cd = 0
  If UCase$(Left$(fin, 7)) <> "HTTP://" Then msg = "Not an http address" : Exit Function
  j = 8
  Do While j <= Len(fin)                           ' the host: up to the first / ? or #
    c = Asc(Mid$(fin, j, 1))
    If c = 47 Or c = 63 Or c = 35 Then Exit Do
    j = j + 1
  Loop
  h = Mid$(fin, 8, j - 8)
  pj = j : pn = 0                                  ' the path: from there to the # (if any)
  Do While j <= Len(fin)
    If Mid$(fin, j, 1) = "#" Then Exit Do
    j = j + 1 : pn = pn + 1
  Loop
  pt = 80
  j = InStr(h, ":")
  If j > 0 Then pt = Val(Mid$(h, j + 1)) : h = Left$(h, j - 1)
  If h = "" Then msg = "No host" : Exit Function
  org = "http://" + h
  If pt <> 80 Then org = org + ":" + Trim$(Str$(pt))
  If Not Present() Then msg = "No network (NET M4)" : Exit Function
  If Not Lookup(h) Then Exit Function
  b(0) = 23                                        ' a socket, connected (each call here is a far
  sk = Bdos(131, VarPtr(b))                        ' call into CyborgOS: as few as can be)
  If sk = 255 Then msg = "No socket free" : Exit Function
  b(0) = 24 : b(1) = sk
  For j = 0 To 3
    b(2 + j) = ip(j)
  Next
  Wd 6, pt
  If Bdos(131, VarPtr(b)) <> 0 Then msg = "Can't connect" : Shut : Exit Function
  t0 = Time()
  Do
    r = State()
    If r <> 1 Then Exit Do
    If Time() - t0 > 3000 Then Exit Do             ' (10 seconds)
  Loop
  If r <> 0 Then msg = "Can't connect to " + h + ":" + Trim$(Str$(pt)) : Shut : Exit Function
  n = 0                                            ' the request, in buf: GET, its path ("/" when
  rq = "GET "                                      ' it has none), the rest - sent in one go
  Move VarPtr(rq), buf, 4 : n = 4
  If pn = 0 Or Mid$(fin, pj, 1) <> "/" Then Poke buf + n, 47 : n = n + 1
  Move VarPtr(fin) + pj - 1, buf + n, pn : n = n + pn
  rq = " HTTP/1.0" + Chr$(13) + Chr$(10) + "Host: " + Mid$(org, 8) + Chr$(13) + Chr$(10)
  rq = rq + "User-Agent: CyborgOS" + Chr$(13) + Chr$(10) + "Connection: close" + Chr$(13) + Chr$(10) + Chr$(13) + Chr$(10)
  Move VarPtr(rq), buf + n, Len(rq) : n = n + Len(rq)
  SendA buf, n
  If msg <> "" Then Shut : Exit Function
  n = 0 : he = -1 : cl = -1 : t0 = 0               ' the answer: until it closes (or its length)
  Do
    k = mx - n
    If k > 2048 Then k = 2048
    If k <= 0 Then Exit Do
    b(0) = 26 : b(1) = sk
    Wd 2, buf + n : Wd 4, k : Wd 6, 0
    If Bdos(131, VarPtr(b)) <> 0 Then Exit Do
    k = b(6) + b(7) * 256
    If k > 0 Then
      n = n + k : t0 = 0
      If he < 0 Then he = Heads(buf, n)
      If he >= 0 And cl >= 0 Then
        If n - he >= cl Then Exit Do
      End If
    Else
      r = State()                                  ' none: closed (and nothing left), or waited too long
      If (r = 3 Or r > 5) And e(2) = 0 And e(3) = 0 Then Exit Do
      If t0 = 0 Then
        t0 = Time()
      ElseIf Time() - t0 > 3000 Then
        msg = "No answer (10 seconds)" : Exit Do
      End If
    End If
  Loop
  Shut
  If he < 0 Then
    If msg = "" Then msg = "Not an HTTP answer"
    Exit Function
  End If
  If n - he > 0 Then Move buf + he, buf, n - he
  Get1 = n - he
End Function

' a name's IP address into ip: a.b.c.d as it is, else looked up (the last kept): False, msg why
Private Function Lookup(ByVal h As String Max 64) As Integer
  Dim j As Integer, k As Integer, v As Integer, c As Integer, t0 As Integer, r As Integer
  Lookup = -1
  k = 0 : v = 0 : r = -1                           ' 1.2.3.4
  For j = 1 To Len(h)
    c = Asc(Mid$(h, j, 1))
    If c = 46 Then
      If k > 2 Then r = 0
      If k <= 3 Then ip(k) = v And 255
      k = k + 1 : v = 0
    ElseIf c >= 48 And c <= 57 Then
      v = v * 10 + c - 48
    Else
      r = 0 : Exit For
    End If
  Next
  If r And k = 3 Then ip(3) = v And 255 : Exit Function
  If h = ch Then
    For j = 0 To 3
      ip(j) = cip(j)
    Next
    Exit Function
  End If
  b(0) = 21 : Wd 2, VarPtr(h) : b(4) = Len(h)
  If Bdos(131, VarPtr(b)) <> 1 Then msg = "Can't look up " + h : Lookup = 0 : Exit Function
  t0 = Time()
  Do
    b(0) = 22 : b(1) = 255 : Wd 2, VarPtr(e)
    r = Bdos(131, VarPtr(b))
    If r <> 5 Then Exit Do
    If Time() - t0 > 3000 Then Exit Do
  Loop
  If r <> 0 Then msg = "No such host: " + h : Lookup = 0 : Exit Function
  For j = 0 To 3
    ip(j) = e(4 + j) : cip(j) = ip(j)
  Next
  ch = h
End Function

' the socket's state (its 16 bytes in e: +2 a word, the bytes waiting)
Private Function State() As Integer
  b(0) = 22 : b(1) = sk : Wd 2, VarPtr(e)
  State = Bdos(131, VarPtr(b))
End Function

' n bytes at a sent on the socket (240 a go: after the first, each waits for the one before);
' msg when they can't be
Private Sub SendA(ByVal a As Integer, ByVal n As Integer)
  Dim k As Integer, t0 As Integer, f As Integer
  If msg <> "" Then Exit Sub
  f = -1
  Do While n > 0
    k = n : If k > 240 Then k = 240
    If Not f Then
      t0 = Time()
      Do While State() = 2                         ' (the one before still going)
        If Time() - t0 > 3000 Then msg = "Can't send" : Exit Sub
      Loop
    End If
    f = 0
    b(0) = 25 : b(1) = sk
    Wd 2, a : Wd 4, k
    If Bdos(131, VarPtr(b)) <> 0 Then msg = "Can't send" : Exit Sub
    a = a + k : n = n - k
  Loop
End Sub

Private Sub Shut()
  Dim r As Integer
  b(0) = 27 : b(1) = sk
  r = Bdos(131, VarPtr(b))
End Sub

' the headers in buf (n bytes so far): where the body starts (-1: not all there yet) - cd the
' status, cl the body's length (Content-Length; -1 none), nxt a redirect's address ("" none).
' Scan (Z80) finds their end and those two lines: a character at a time in BASIC took 0.15 s
Private Function Heads(ByVal buf As Integer, ByVal n As Integer) As Integer
  Dim c As Integer, a As Integer
  Heads = Scan(buf, n)
  If Heads < 0 Then Exit Function
  cd = (Peek(buf + 9) - 48) * 100 + (Peek(buf + 10) - 48) * 10 + Peek(buf + 11) - 48
  cl = -1 : nxt = ""
  If ca <> 0 Then
    cl = 0 : a = ca
    Do
      c = Peek(a)
      If c < 48 Or c > 57 Then Exit Do
      cl = cl * 10 + c - 48 : a = a + 1
    Loop
  End If
  If la <> 0 Then
    a = la
    Do
      c = Peek(a)
      If c < 33 Or Len(nxt) >= 255 Then Exit Do
      nxt = nxt + Chr$(c) : a = a + 1
    Loop
    If Left$(nxt, 1) = "/" Then nxt = org + nxt     ' (a redirect to /path: this host's)
  End If
End Function

' the n bytes at a: where the headers end (past their empty line; -1 not there yet) - ca, la
' where the Content-Length's and Location's values start (0: none), letters' case ignored
Private Function Scan(ByVal a As Integer, ByVal n As Integer) As Integer
#asm
            ld ({hsp}), sp          ; (a stack for its calls: SP is the threaded code's)
            ld sp, (ntc_csp)
            ld hl, 0
            ld ({ca}), hl
            ld ({la}), hl
            dec hl
            ld ({result}), hl
            ld hl, ({a})
            ld bc, ({n})
hs_line:                            ; HL a line's start, BC the bytes left
            push hl
            push bc
            ld de, hs_p1
            call hs_cmp
            jr nz, hs_l1
            ld ({ca}), hl
hs_l1:
            pop bc
            pop hl
            push hl
            push bc
            ld de, hs_p2
            call hs_cmp
            jr nz, hs_l2
            ld ({la}), hl
hs_l2:
            pop bc
            pop hl
hs_eol:                             ; to the line's end: past its LF
            ld a, b
            or c
            jr z, hs_done           ; (not all there yet)
            ld a, (hl)
            inc hl
            dec bc
            cp 10
            jr nz, hs_eol
            ld a, b                 ; the next line: CR LF - the headers' end?
            or a
            jr nz, hs_two
            ld a, c
            cp 2
            jr c, hs_done
hs_two:
            ld a, (hl)
            cp 13
            jr nz, hs_line
            inc hl
            ld a, (hl)
            dec hl
            cp 10
            jr nz, hs_line
            inc hl
            inc hl
            ld de, ({a})
            or a
            sbc hl, de
            ld ({result}), hl
            jr hs_done
; hs_cmp - Z when the text at HL starts with DE's word (its length first; the text's letters
; made small: OR #20), HL then past it and the spaces after it
hs_cmp:
            ld a, (de)
            ld b, a
            inc de
hs_c1:
            ld a, (hl)
            or #20
            ex de, hl
            cp (hl)
            ex de, hl
            ret nz
            inc hl
            inc de
            djnz hs_c1
hs_c2:
            ld a, (hl)
            cp 32
            jr nz, hs_c3
            inc hl
            jr hs_c2
hs_c3:
            xor a
            ret
hs_p1:      db 15, "content-length:"
hs_p2:      db 9, "location:"
hs_done:
            ld sp, ({hsp})
#endasm
End Function

' n bytes from a to d (d below a: forwards)
Private Sub Move(ByVal a As Integer, ByVal d As Integer, ByVal n As Integer)
#asm
            ld hl, ({a})
            ld de, ({d})
            ld bc, ({n})
            ld a, b
            or c
            jr z, nm_none
            ldir
nm_none:
#endasm
End Sub

' b(i), b(i + 1): v (low byte first - an address from #8000 is a negative Integer: And first)
Private Sub Wd(ByVal i As Integer, ByVal v As Integer)
  b(i) = v And 255 : b(i + 1) = ((v And &HFF00) \ 256) And 255
End Sub

' BDOS function f, DE = d: A
Private Function Bdos(ByVal f As Integer, ByVal d As Integer) As Integer
#asm
            ld ({hsp}), sp
            ld sp, (ntc_csp)
            ld a, ({f})
            ld c, a
            ld de, ({d})
            ei                      ; (CP/M's BDOS: interrupts on)
            call 5
            di                      ; (off before SP is the threaded code again: it comes back with them on)
            ld l, a
            ld h, 0
            ld ({result}), hl
            ld sp, ({hsp})
#endasm
End Function
