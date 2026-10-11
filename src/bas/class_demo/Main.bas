Dim c As New Counter
Dim r As Integer
c.Reset
c.Add 5
c.Add 7
Print "count "; c.Count; " total "; c.Total
c.Limit = 3
Print "limit "; c.Limit
r = Counter.Total
Print "direct "; r
Print c.Describe("x")
Print "Press a key";
Do : Frame : Loop Until Inkey <> 0
Print
