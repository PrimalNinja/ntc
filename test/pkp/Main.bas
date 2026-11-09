' regress.sh: a page-to-page far keyword call - Caller (page PA) calls Art's keywords (page PK): the
' caller's thread is in the window while Art's page is switched in, so kwin runs the call from
' a main-RAM copy of its words (ntc_ovl_kwin n). pkf/Art.cls copied beside.
Option Explicit
Option Page Pk = Art
Option Page Pa = Caller
Option Memory Reserved &H4000, &H4000
Dim r As Integer
r = Art.Val()
Print "VAL"; r
r = Caller.Go(1)
Print "MEM"; Peek(&HA000)
Print "PAGE"; r
End
