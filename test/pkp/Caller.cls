' Caller: a page class whose code calls Art's keywords - a page-to-page far keyword call:
' this thread is in the window while Art's page has to be in it
Public Function Go(ByVal n As Integer) As Integer
  Dim r As Integer
  Art.Fill
  r = Art.Val()
  Go = r + n
End Function
