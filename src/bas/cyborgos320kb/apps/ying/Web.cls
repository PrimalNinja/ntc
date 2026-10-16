' Web - the web side YING and YANG (apps/ying, apps/yang: the two CyborgOS 8BML web browsers)
' share: addresses and fetching. http only (no https). A page is asked for as 8BML: the request
' gets an empty 8bml parameter (?8bml= - &8bml= when the address has parameters already); that is
' never shown, the address keeps it out (Request makes it, for the fetch alone).
'
' Fetch is a stub for now: no network - it makes up a test page (its links: a relative one, one
' with parameters, up a folder, another host and port, an https one, back) into the buffer, as
' a real fetch will put the server's 8BML there.
'
' Addresses: http://host[:port][/path][?parameters][#place]. One without a scheme is taken as
' http://; one with no path gets "/". A file is a page too - read from the disc (local pages,
' linked to each other like AmigaGuide's): one with a drive (A:NAME.8BM), one named .8BM
' (NAME.8BM: this drive), or file:NAME.EXT. Its links: from its drive.
Option Explicit
Private sn As Integer, sb As Integer, smx As Integer   ' the page being made: length, buffer, room
Private stt As Integer                                 ' the last fetch's status (Fetch)

' Fetch(u, buf, max): page u (an address, as shown) fetched as 8BML into buf (max bytes at most):
' its length. Always a page - a status page when it couldn't be fetched. Status(): how it went
Public Function Fetch(ByVal u As String, ByVal buf As Integer, ByVal max As Integer) As Integer
  Dim q As String Max 90
  sb = buf : smx = max : sn = 0
  u = Clean(u)
  stt = 0
  If IsFile(u) Then
    LoadFile u
  ElseIf UCase$(Left$(u, 8)) = "HTTPS://" Then
    stt = 2
    Head "Not supported"
    PutT "https isn't supported - http only:"
    PutT u
  ElseIf UCase$(Left$(u, 7)) <> "HTTP://" Or Host(u) = "" Then
    stt = 1
    Head "Bad address"
    PutT "Not an http address: " + u
  Else
    q = Request(u)
    Stub u, q
  End If
  If IsFile(u) And stt = 0 Then PutW "." Else PutW "<:."   ' (a file: its own end; else a back link)
  Fetch = sn
End Function

' Status(): the last Fetch - 0 a page, 1 not an http address, 2 https, 3 no such file (or too big)
Public Function Status() As Integer
  Status = stt
End Function

' Clean(u): u as an address - spaces off its ends, http:// before one with no scheme, "/" after a
' host with no path
Public Function Clean(ByVal u As String) As String
  Dim j As Integer
  u = Trim$(u)
  If UCase$(Left$(u, 5)) = "FILE:" Then u = Mid$(u, 6)
  If IsFile(u) Then Clean = UCase$(u) : Exit Function
  If u <> "" And InStr(u, "://") = 0 Then u = "http://" + u
  j = InStr(u, "://")
  If j > 0 Then
    If InStr(Mid$(u, j + 3), "/") = 0 Then
      If InStr(Mid$(u, j + 3), "?") = 0 And InStr(Mid$(u, j + 3), "#") = 0 Then u = u + "/"
    End If
  End If
  Clean = u
End Function

' Request(u): the address the fetch asks for - the place (#...) off, the empty 8bml parameter on
Public Function Request(ByVal u As String) As String
  Dim j As Integer
  j = InStr(u, "#")
  If j > 0 Then u = Left$(u, j - 1)
  If InStr(u, "?") > 0 Then
    If Right$(u, 1) = "?" Or Right$(u, 1) = "&" Then u = u + "8bml=" Else u = u + "&8bml="
  Else
    u = u + "?8bml="
  End If
  Request = u
End Function

' Origin(u): "http://host[:port]" - u up to its path
Public Function Origin(ByVal u As String) As String
  Dim j As Integer, k As Integer
  j = InStr(u, "://")
  If j = 0 Then Origin = "" : Exit Function
  k = Edge(u, j + 3)
  Origin = Left$(u, k - 1)
End Function

' Host(u): its host name (no port)
Public Function Host(ByVal u As String) As String
  Dim h As String Max 80, j As Integer
  j = InStr(u, "://")
  If j = 0 Then Host = "" : Exit Function
  h = Mid$(Origin(u), j + 3)
  j = InStr(h, ":")
  If j > 0 Then h = Left$(h, j - 1)
  Host = h
End Function

' Port(u): its port (80 when it names none)
Public Function Port(ByVal u As String) As Integer
  Dim h As String Max 80, j As Integer
  Port = 80
  j = InStr(u, "://")
  If j = 0 Then Exit Function
  h = Mid$(Origin(u), j + 3)
  j = InStr(h, ":")
  If j > 0 Then Port = Val(Mid$(h, j + 1))
End Function

' Path(u): its path and parameters (what an HTTP GET names), "/" at least; the place left out
Public Function Path(ByVal u As String) As String
  Dim p As String Max 80, j As Integer
  p = Mid$(u, Len(Origin(u)) + 1)
  j = InStr(p, "#")
  If j > 0 Then p = Left$(p, j - 1)
  If Left$(p, 1) <> "/" Then p = "/" + p
  Path = p
End Function

' Resolve(base, h): link h as an address, from page base: a whole address as it is; //host...
' with http:; /path from base's host; ?parameters and #place on base's path; else from base's
' folder (./ and ../ followed)
Public Function Resolve(ByVal b As String, ByVal h As String) As String
  Dim d As String Max 80, j As Integer
  h = Trim$(h)
  If h = "" Then Resolve = b : Exit Function
  If InStr(h, "://") > 0 Then Resolve = h : Exit Function
  If UCase$(Left$(h, 5)) = "FILE:" Then Resolve = Mid$(h, 6) : Exit Function
  If IsFile(b) Then                              ' (from a file: its drive)
    j = InStr(h, "#")
    If j > 0 Then h = Left$(h, j - 1)
    If Mid$(h, 2, 1) = ":" Or Mid$(b, 2, 1) <> ":" Then Resolve = h Else Resolve = Left$(b, 2) + h
    Exit Function
  End If
  If Left$(h, 2) = "//" Then Resolve = "http:" + h : Exit Function
  If Left$(h, 1) = "/" Then Resolve = Origin(b) + h : Exit Function
  j = InStr(b, "#")
  If j > 0 Then b = Left$(b, j - 1)
  If Left$(h, 1) = "#" Then Resolve = b + h : Exit Function
  j = InStr(b, "?")
  If j > 0 Then b = Left$(b, j - 1)
  If Left$(h, 1) = "?" Then Resolve = b + h : Exit Function
  d = Mid$(b, Len(Origin(b)) + 1)                ' base's folder: its path to the last /
  j = Len(d)
  Do While j > 0
    If Mid$(d, j, 1) = "/" Then Exit Do
    j = j - 1
  Loop
  d = Left$(d, j)
  If d = "" Then d = "/"
  Do
    If Left$(h, 2) = "./" Then
      h = Mid$(h, 3)
    ElseIf Left$(h, 3) = "../" Then
      h = Mid$(h, 4)
      If Len(d) > 1 Then                         ' up a folder (not above /)
        j = Len(d) - 1
        Do While j > 0
          If Mid$(d, j, 1) = "/" Then Exit Do
          j = j - 1
        Loop
        d = Left$(d, j)
      End If
    Else
      Exit Do
    End If
  Loop
  Resolve = Origin(b) + d + h
End Function

' IsFile(u): u names a file - a drive (A:...), or NAME.8BM (no "/" - host/x.8bm is the web's)
Public Function IsFile(ByVal u As String) As Integer
  Dim c As String Max 1
  IsFile = False
  If InStr(u, "://") > 0 Then Exit Function
  c = UCase$(Left$(u, 1))
  If Mid$(u, 2, 1) = ":" And c >= "A" And c <= "P" Then IsFile = True : Exit Function
  If UCase$(Right$(u, 4)) = ".8BM" And InStr(u, "/") = 0 Then IsFile = True
End Function

' Home(): the home page - HOME.8BM on this drive, else A:'s, else Z:'s (else this drive's, not
' there: its page says so)
Public Function Home() As String
  Home = "HOME.8BM"
  If FileSystem.Exists("HOME.8BM") Then Exit Function
  If FileSystem.Exists("A:HOME.8BM") Then Home = "A:HOME.8BM" : Exit Function
  If FileSystem.Exists("Z:HOME.8BM") Then Home = "Z:HOME.8BM"
End Function

' where u's host part (from j) ends: its first /, ? or # (else past the end)
Private Function Edge(ByVal u As String, ByVal j As Integer) As Integer
  Dim c As String Max 1
  Do While j <= Len(u)
    c = Mid$(u, j, 1)
    If c = "/" Or c = "?" Or c = "#" Then Exit Do
    j = j + 1
  Loop
  Edge = j
End Function

' ---- a file: read whole (to its first ^Z: CP/M's records); none, or too big: a page says so
Private Sub LoadFile(ByVal u As String)
  Dim n As Integer, j As Integer
  n = FileSystem.Load(u, sb, smx)
  If n < 0 Then
    stt = 3
    Head "No such page"
    PutT "No such file (or too big for 8K): " + u
    Exit Sub
  End If
  For j = 0 To n - 1
    If Peek(sb + j) = 26 Then n = j : Exit For
  Next
  sn = n
End Sub

' ---- the stub: a made-up page for u (asked for as q)
Private Sub Stub(ByVal u As String, ByVal q As String)
  Head "Test page " + Path(u)
  PutT "No network yet: Web.cls made this page up."
  PutT "Address: " + u
  PutT "Asked for as: " + q
  PutT "Host " + Host(u) + ", port" + Str$(Port(u)) + ", GET " + Path(q)
  PutW "n:"
  PutW "s" : PutQ "Links" : PutW ":n:"
  PutL "/", "The host's home (/)"
  PutL "page2.8bml", "A page in this folder (page2.8bml)"
  PutL "find?q=cpc&n=2", "A page with parameters (find?q=cpc&n=2)"
  PutL "../up.8bml", "Up a folder (../up.8bml)"
  PutL "http://example.com:8080/x/y.8bml", "Another host and port (example.com:8080)"
  PutL "https://example.com/", "An https page (not supported)"
End Sub

' the page's start ("-", its title) and its heading
Private Sub Head(ByVal t As String)
  PutW "-" : PutQ "1" : PutW "," : PutQ t : PutW ":"
  PutW "p" : PutQ t : PutW ":n:"
End Sub

' a line of text; a link (then a new line)
Private Sub PutT(ByVal s As String)
  PutW "t" : PutQ s : PutW ":n:"
End Sub
Private Sub PutL(ByVal h As String, ByVal s As String)
  PutW "l" : PutQ h : PutW "," : PutQ s : PutW ":n:"
End Sub

' s into the page as it is; quoted (" \ as \" \\)
Private Sub PutW(ByVal s As String)
  Dim j As Integer
  For j = 1 To Len(s)
    If sn < smx Then Poke sb + sn, Asc(Mid$(s, j, 1)) : sn = sn + 1
  Next
End Sub
Private Sub PutQ(ByVal s As String)
  Dim j As Integer, c As String Max 1
  PutW Chr$(34)
  For j = 1 To Len(s)
    c = Mid$(s, j, 1)
    If c = Chr$(34) Or c = "\" Then PutW "\"
    PutW c
  Next
  PutW Chr$(34)
End Sub
