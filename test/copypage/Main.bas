' Bug fix: a class copied into two pages, with a procedure nothing calls (Stars.Unused). The copy
' table must not name a body that was never emitted (was "Label not found" at assembly).
Option Memory Paged &H4000, &H4000
Option Page Level1 = Level1, Stars
Option Page Level2 = Level2, Stars
Print Level1.Go(1) + Level2.Go(2) + Stars.Used(3)
