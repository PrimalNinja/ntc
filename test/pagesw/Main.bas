' regress.sh: Option Memory Paged - the window is not reserved: the procedures (page 0 code) fill
' through #4000-#7FFF, while what must stay in sight of the pages (the stubs, the library, the data, and
' Helper and Util.Hello, which a page calls) is in the safe memory (Option Memory Safe); on cpm
' (Option Memory Heap Main: a page is loaded in place) nothing goes under it. pages/*.cls + this main.
Option Page "TITLE"   = Title
Option Page "LEVEL1"  = Level1, Shared, Counter, OnlyOne
Option Page "LEVEL2"  = Level2, Shared, Counter
Option Page "CREDITS" = Credits
#If NTC_CPCMIN Then
Option ROM Enable 7
#End If
#If NTC_CPCFW Then
Option ROM Enable 7
#End If
Option Memory Paged 1, &H4000, &H4000     ' the window: code may sit under it, data never
Option Memory Safe &H0040, &H3FC0   ' what the pages must always see goes here (all the memory below the window); what it leaves is ordinary memory
Dim r As Integer
Title.Show
Print "L1 "; Level1.Play(3)
Print "L2 "; Level2.Play(4)
Print "L1 again "; Level1.Play(1)
Print "main sum "; Shared.Sum(10)
Print "main count "; Counter.Bump(); Counter.Bump(); " "; Counter.Marks()
Print "loaded "; Level1.Loaded(); Level2.Loaded(); Credits.Loaded()
Credits.Show
Print "fill "; Fill1(1); Fill2(1); Fill3(1); Fill4(1); Fill5(1)
Print "done"
End


Function Fill1(ByVal x As Integer) As Integer
  Dim t As Integer
  t = x
  t = t + x * 1 + 1 - x + 1 * x - 1 + x + 1
  t = t + x * 2 + 2 - x + 2 * x - 2 + x + 2
  t = t + x * 3 + 3 - x + 3 * x - 3 + x + 3
  t = t + x * 4 + 4 - x + 4 * x - 4 + x + 4
  t = t + x * 5 + 5 - x + 5 * x - 5 + x + 5
  t = t + x * 6 + 6 - x + 6 * x - 6 + x + 6
  t = t + x * 7 + 7 - x + 7 * x - 7 + x + 7
  t = t + x * 8 + 8 - x + 8 * x - 8 + x + 8
  t = t + x * 9 + 9 - x + 9 * x - 9 + x + 9
  t = t + x * 10 + 10 - x + 10 * x - 10 + x + 10
  t = t + x * 11 + 11 - x + 11 * x - 11 + x + 11
  t = t + x * 12 + 12 - x + 12 * x - 12 + x + 12
  t = t + x * 13 + 13 - x + 13 * x - 13 + x + 13
  t = t + x * 14 + 14 - x + 14 * x - 14 + x + 14
  t = t + x * 15 + 15 - x + 15 * x - 15 + x + 15
  t = t + x * 16 + 16 - x + 16 * x - 16 + x + 16
  t = t + x * 17 + 17 - x + 17 * x - 17 + x + 17
  t = t + x * 18 + 18 - x + 18 * x - 18 + x + 18
  t = t + x * 19 + 19 - x + 19 * x - 19 + x + 19
  t = t + x * 20 + 20 - x + 20 * x - 20 + x + 20
  t = t + x * 21 + 21 - x + 21 * x - 21 + x + 21
  t = t + x * 22 + 22 - x + 22 * x - 22 + x + 22
  t = t + x * 23 + 23 - x + 23 * x - 23 + x + 23
  t = t + x * 24 + 24 - x + 24 * x - 24 + x + 24
  t = t + x * 25 + 25 - x + 25 * x - 25 + x + 25
  t = t + x * 26 + 26 - x + 26 * x - 26 + x + 26
  t = t + x * 27 + 27 - x + 27 * x - 27 + x + 27
  t = t + x * 28 + 28 - x + 28 * x - 28 + x + 28
  t = t + x * 29 + 29 - x + 29 * x - 29 + x + 29
  t = t + x * 30 + 30 - x + 30 * x - 30 + x + 30
  t = t + x * 31 + 31 - x + 31 * x - 31 + x + 31
  t = t + x * 32 + 32 - x + 32 * x - 32 + x + 32
  t = t + x * 33 + 33 - x + 33 * x - 33 + x + 33
  t = t + x * 34 + 34 - x + 34 * x - 34 + x + 34
  t = t + x * 35 + 35 - x + 35 * x - 35 + x + 35
  t = t + x * 36 + 36 - x + 36 * x - 36 + x + 36
  t = t + x * 37 + 37 - x + 37 * x - 37 + x + 37
  t = t + x * 38 + 38 - x + 38 * x - 38 + x + 38
  t = t + x * 39 + 39 - x + 39 * x - 39 + x + 39
  t = t + x * 40 + 40 - x + 40 * x - 40 + x + 40
  t = t + x * 41 + 41 - x + 41 * x - 41 + x + 41
  t = t + x * 42 + 42 - x + 42 * x - 42 + x + 42
  t = t + x * 43 + 43 - x + 43 * x - 43 + x + 43
  t = t + x * 44 + 44 - x + 44 * x - 44 + x + 44
  t = t + x * 45 + 45 - x + 45 * x - 45 + x + 45
  t = t + x * 46 + 46 - x + 46 * x - 46 + x + 46
  t = t + x * 47 + 47 - x + 47 * x - 47 + x + 47
  t = t + x * 48 + 48 - x + 48 * x - 48 + x + 48
  Fill1 = t
End Function

Function Fill2(ByVal x As Integer) As Integer
  Dim t As Integer
  t = x
  t = t + x * 1 + 1 - x + 1 * x - 1 + x + 1
  t = t + x * 2 + 2 - x + 2 * x - 2 + x + 2
  t = t + x * 3 + 3 - x + 3 * x - 3 + x + 3
  t = t + x * 4 + 4 - x + 4 * x - 4 + x + 4
  t = t + x * 5 + 5 - x + 5 * x - 5 + x + 5
  t = t + x * 6 + 6 - x + 6 * x - 6 + x + 6
  t = t + x * 7 + 7 - x + 7 * x - 7 + x + 7
  t = t + x * 8 + 8 - x + 8 * x - 8 + x + 8
  t = t + x * 9 + 9 - x + 9 * x - 9 + x + 9
  t = t + x * 10 + 10 - x + 10 * x - 10 + x + 10
  t = t + x * 11 + 11 - x + 11 * x - 11 + x + 11
  t = t + x * 12 + 12 - x + 12 * x - 12 + x + 12
  t = t + x * 13 + 13 - x + 13 * x - 13 + x + 13
  t = t + x * 14 + 14 - x + 14 * x - 14 + x + 14
  t = t + x * 15 + 15 - x + 15 * x - 15 + x + 15
  t = t + x * 16 + 16 - x + 16 * x - 16 + x + 16
  t = t + x * 17 + 17 - x + 17 * x - 17 + x + 17
  t = t + x * 18 + 18 - x + 18 * x - 18 + x + 18
  t = t + x * 19 + 19 - x + 19 * x - 19 + x + 19
  t = t + x * 20 + 20 - x + 20 * x - 20 + x + 20
  t = t + x * 21 + 21 - x + 21 * x - 21 + x + 21
  t = t + x * 22 + 22 - x + 22 * x - 22 + x + 22
  t = t + x * 23 + 23 - x + 23 * x - 23 + x + 23
  t = t + x * 24 + 24 - x + 24 * x - 24 + x + 24
  t = t + x * 25 + 25 - x + 25 * x - 25 + x + 25
  t = t + x * 26 + 26 - x + 26 * x - 26 + x + 26
  t = t + x * 27 + 27 - x + 27 * x - 27 + x + 27
  t = t + x * 28 + 28 - x + 28 * x - 28 + x + 28
  t = t + x * 29 + 29 - x + 29 * x - 29 + x + 29
  t = t + x * 30 + 30 - x + 30 * x - 30 + x + 30
  t = t + x * 31 + 31 - x + 31 * x - 31 + x + 31
  t = t + x * 32 + 32 - x + 32 * x - 32 + x + 32
  t = t + x * 33 + 33 - x + 33 * x - 33 + x + 33
  t = t + x * 34 + 34 - x + 34 * x - 34 + x + 34
  t = t + x * 35 + 35 - x + 35 * x - 35 + x + 35
  t = t + x * 36 + 36 - x + 36 * x - 36 + x + 36
  t = t + x * 37 + 37 - x + 37 * x - 37 + x + 37
  t = t + x * 38 + 38 - x + 38 * x - 38 + x + 38
  t = t + x * 39 + 39 - x + 39 * x - 39 + x + 39
  t = t + x * 40 + 40 - x + 40 * x - 40 + x + 40
  t = t + x * 41 + 41 - x + 41 * x - 41 + x + 41
  t = t + x * 42 + 42 - x + 42 * x - 42 + x + 42
  t = t + x * 43 + 43 - x + 43 * x - 43 + x + 43
  t = t + x * 44 + 44 - x + 44 * x - 44 + x + 44
  t = t + x * 45 + 45 - x + 45 * x - 45 + x + 45
  t = t + x * 46 + 46 - x + 46 * x - 46 + x + 46
  t = t + x * 47 + 47 - x + 47 * x - 47 + x + 47
  t = t + x * 48 + 48 - x + 48 * x - 48 + x + 48
  Fill2 = t
End Function

Function Fill3(ByVal x As Integer) As Integer
  Dim t As Integer
  t = x
  t = t + x * 1 + 1 - x + 1 * x - 1 + x + 1
  t = t + x * 2 + 2 - x + 2 * x - 2 + x + 2
  t = t + x * 3 + 3 - x + 3 * x - 3 + x + 3
  t = t + x * 4 + 4 - x + 4 * x - 4 + x + 4
  t = t + x * 5 + 5 - x + 5 * x - 5 + x + 5
  t = t + x * 6 + 6 - x + 6 * x - 6 + x + 6
  t = t + x * 7 + 7 - x + 7 * x - 7 + x + 7
  t = t + x * 8 + 8 - x + 8 * x - 8 + x + 8
  t = t + x * 9 + 9 - x + 9 * x - 9 + x + 9
  t = t + x * 10 + 10 - x + 10 * x - 10 + x + 10
  t = t + x * 11 + 11 - x + 11 * x - 11 + x + 11
  t = t + x * 12 + 12 - x + 12 * x - 12 + x + 12
  t = t + x * 13 + 13 - x + 13 * x - 13 + x + 13
  t = t + x * 14 + 14 - x + 14 * x - 14 + x + 14
  t = t + x * 15 + 15 - x + 15 * x - 15 + x + 15
  t = t + x * 16 + 16 - x + 16 * x - 16 + x + 16
  t = t + x * 17 + 17 - x + 17 * x - 17 + x + 17
  t = t + x * 18 + 18 - x + 18 * x - 18 + x + 18
  t = t + x * 19 + 19 - x + 19 * x - 19 + x + 19
  t = t + x * 20 + 20 - x + 20 * x - 20 + x + 20
  t = t + x * 21 + 21 - x + 21 * x - 21 + x + 21
  t = t + x * 22 + 22 - x + 22 * x - 22 + x + 22
  t = t + x * 23 + 23 - x + 23 * x - 23 + x + 23
  t = t + x * 24 + 24 - x + 24 * x - 24 + x + 24
  t = t + x * 25 + 25 - x + 25 * x - 25 + x + 25
  t = t + x * 26 + 26 - x + 26 * x - 26 + x + 26
  t = t + x * 27 + 27 - x + 27 * x - 27 + x + 27
  t = t + x * 28 + 28 - x + 28 * x - 28 + x + 28
  t = t + x * 29 + 29 - x + 29 * x - 29 + x + 29
  t = t + x * 30 + 30 - x + 30 * x - 30 + x + 30
  t = t + x * 31 + 31 - x + 31 * x - 31 + x + 31
  t = t + x * 32 + 32 - x + 32 * x - 32 + x + 32
  t = t + x * 33 + 33 - x + 33 * x - 33 + x + 33
  t = t + x * 34 + 34 - x + 34 * x - 34 + x + 34
  t = t + x * 35 + 35 - x + 35 * x - 35 + x + 35
  t = t + x * 36 + 36 - x + 36 * x - 36 + x + 36
  t = t + x * 37 + 37 - x + 37 * x - 37 + x + 37
  t = t + x * 38 + 38 - x + 38 * x - 38 + x + 38
  t = t + x * 39 + 39 - x + 39 * x - 39 + x + 39
  t = t + x * 40 + 40 - x + 40 * x - 40 + x + 40
  t = t + x * 41 + 41 - x + 41 * x - 41 + x + 41
  t = t + x * 42 + 42 - x + 42 * x - 42 + x + 42
  t = t + x * 43 + 43 - x + 43 * x - 43 + x + 43
  t = t + x * 44 + 44 - x + 44 * x - 44 + x + 44
  t = t + x * 45 + 45 - x + 45 * x - 45 + x + 45
  t = t + x * 46 + 46 - x + 46 * x - 46 + x + 46
  t = t + x * 47 + 47 - x + 47 * x - 47 + x + 47
  t = t + x * 48 + 48 - x + 48 * x - 48 + x + 48
  Fill3 = t
End Function

' called from LEVEL2's code: Shared's copy in the window (LEVEL2) is used
Function Helper(ByVal n As Integer) As Integer
  Helper = Shared.Odd(n) + 1000
End Function

Function Fill4(ByVal x As Integer) As Integer
  Dim t As Integer
  t = x
  t = t + x * 1 + 1 - x + 1 * x - 1 + x + 1
  t = t + x * 2 + 2 - x + 2 * x - 2 + x + 2
  t = t + x * 3 + 3 - x + 3 * x - 3 + x + 3
  t = t + x * 4 + 4 - x + 4 * x - 4 + x + 4
  t = t + x * 5 + 5 - x + 5 * x - 5 + x + 5
  t = t + x * 6 + 6 - x + 6 * x - 6 + x + 6
  t = t + x * 7 + 7 - x + 7 * x - 7 + x + 7
  t = t + x * 8 + 8 - x + 8 * x - 8 + x + 8
  t = t + x * 9 + 9 - x + 9 * x - 9 + x + 9
  t = t + x * 10 + 10 - x + 10 * x - 10 + x + 10
  t = t + x * 11 + 11 - x + 11 * x - 11 + x + 11
  t = t + x * 12 + 12 - x + 12 * x - 12 + x + 12
  t = t + x * 13 + 13 - x + 13 * x - 13 + x + 13
  t = t + x * 14 + 14 - x + 14 * x - 14 + x + 14
  t = t + x * 15 + 15 - x + 15 * x - 15 + x + 15
  t = t + x * 16 + 16 - x + 16 * x - 16 + x + 16
  t = t + x * 17 + 17 - x + 17 * x - 17 + x + 17
  t = t + x * 18 + 18 - x + 18 * x - 18 + x + 18
  t = t + x * 19 + 19 - x + 19 * x - 19 + x + 19
  t = t + x * 20 + 20 - x + 20 * x - 20 + x + 20
  t = t + x * 21 + 21 - x + 21 * x - 21 + x + 21
  t = t + x * 22 + 22 - x + 22 * x - 22 + x + 22
  t = t + x * 23 + 23 - x + 23 * x - 23 + x + 23
  t = t + x * 24 + 24 - x + 24 * x - 24 + x + 24
  t = t + x * 25 + 25 - x + 25 * x - 25 + x + 25
  t = t + x * 26 + 26 - x + 26 * x - 26 + x + 26
  t = t + x * 27 + 27 - x + 27 * x - 27 + x + 27
  t = t + x * 28 + 28 - x + 28 * x - 28 + x + 28
  t = t + x * 29 + 29 - x + 29 * x - 29 + x + 29
  t = t + x * 30 + 30 - x + 30 * x - 30 + x + 30
  t = t + x * 31 + 31 - x + 31 * x - 31 + x + 31
  t = t + x * 32 + 32 - x + 32 * x - 32 + x + 32
  t = t + x * 33 + 33 - x + 33 * x - 33 + x + 33
  t = t + x * 34 + 34 - x + 34 * x - 34 + x + 34
  t = t + x * 35 + 35 - x + 35 * x - 35 + x + 35
  t = t + x * 36 + 36 - x + 36 * x - 36 + x + 36
  t = t + x * 37 + 37 - x + 37 * x - 37 + x + 37
  t = t + x * 38 + 38 - x + 38 * x - 38 + x + 38
  t = t + x * 39 + 39 - x + 39 * x - 39 + x + 39
  t = t + x * 40 + 40 - x + 40 * x - 40 + x + 40
  t = t + x * 41 + 41 - x + 41 * x - 41 + x + 41
  t = t + x * 42 + 42 - x + 42 * x - 42 + x + 42
  t = t + x * 43 + 43 - x + 43 * x - 43 + x + 43
  t = t + x * 44 + 44 - x + 44 * x - 44 + x + 44
  t = t + x * 45 + 45 - x + 45 * x - 45 + x + 45
  t = t + x * 46 + 46 - x + 46 * x - 46 + x + 46
  t = t + x * 47 + 47 - x + 47 * x - 47 + x + 47
  t = t + x * 48 + 48 - x + 48 * x - 48 + x + 48
  Fill4 = t
End Function

Function Fill5(ByVal x As Integer) As Integer
  Dim t As Integer
  t = x
  t = t + x * 1 + 1 - x + 1 * x - 1 + x + 1
  t = t + x * 2 + 2 - x + 2 * x - 2 + x + 2
  t = t + x * 3 + 3 - x + 3 * x - 3 + x + 3
  t = t + x * 4 + 4 - x + 4 * x - 4 + x + 4
  t = t + x * 5 + 5 - x + 5 * x - 5 + x + 5
  t = t + x * 6 + 6 - x + 6 * x - 6 + x + 6
  t = t + x * 7 + 7 - x + 7 * x - 7 + x + 7
  t = t + x * 8 + 8 - x + 8 * x - 8 + x + 8
  t = t + x * 9 + 9 - x + 9 * x - 9 + x + 9
  t = t + x * 10 + 10 - x + 10 * x - 10 + x + 10
  t = t + x * 11 + 11 - x + 11 * x - 11 + x + 11
  t = t + x * 12 + 12 - x + 12 * x - 12 + x + 12
  t = t + x * 13 + 13 - x + 13 * x - 13 + x + 13
  t = t + x * 14 + 14 - x + 14 * x - 14 + x + 14
  t = t + x * 15 + 15 - x + 15 * x - 15 + x + 15
  t = t + x * 16 + 16 - x + 16 * x - 16 + x + 16
  t = t + x * 17 + 17 - x + 17 * x - 17 + x + 17
  t = t + x * 18 + 18 - x + 18 * x - 18 + x + 18
  t = t + x * 19 + 19 - x + 19 * x - 19 + x + 19
  t = t + x * 20 + 20 - x + 20 * x - 20 + x + 20
  t = t + x * 21 + 21 - x + 21 * x - 21 + x + 21
  t = t + x * 22 + 22 - x + 22 * x - 22 + x + 22
  t = t + x * 23 + 23 - x + 23 * x - 23 + x + 23
  t = t + x * 24 + 24 - x + 24 * x - 24 + x + 24
  t = t + x * 25 + 25 - x + 25 * x - 25 + x + 25
  t = t + x * 26 + 26 - x + 26 * x - 26 + x + 26
  t = t + x * 27 + 27 - x + 27 * x - 27 + x + 27
  t = t + x * 28 + 28 - x + 28 * x - 28 + x + 28
  t = t + x * 29 + 29 - x + 29 * x - 29 + x + 29
  t = t + x * 30 + 30 - x + 30 * x - 30 + x + 30
  t = t + x * 31 + 31 - x + 31 * x - 31 + x + 31
  t = t + x * 32 + 32 - x + 32 * x - 32 + x + 32
  t = t + x * 33 + 33 - x + 33 * x - 33 + x + 33
  t = t + x * 34 + 34 - x + 34 * x - 34 + x + 34
  t = t + x * 35 + 35 - x + 35 * x - 35 + x + 35
  t = t + x * 36 + 36 - x + 36 * x - 36 + x + 36
  t = t + x * 37 + 37 - x + 37 * x - 37 + x + 37
  t = t + x * 38 + 38 - x + 38 * x - 38 + x + 38
  t = t + x * 39 + 39 - x + 39 * x - 39 + x + 39
  t = t + x * 40 + 40 - x + 40 * x - 40 + x + 40
  t = t + x * 41 + 41 - x + 41 * x - 41 + x + 41
  t = t + x * 42 + 42 - x + 42 * x - 42 + x + 42
  t = t + x * 43 + 43 - x + 43 * x - 43 + x + 43
  t = t + x * 44 + 44 - x + 44 * x - 44 + x + 44
  t = t + x * 45 + 45 - x + 45 * x - 45 + x + 45
  t = t + x * 46 + 46 - x + 46 * x - 46 + x + 46
  t = t + x * 47 + 47 - x + 47 * x - 47 + x + 47
  t = t + x * 48 + 48 - x + 48 * x - 48 + x + 48
  Fill5 = t
End Function
