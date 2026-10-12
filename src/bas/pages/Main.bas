' Pages: where each class goes, in one place. A page is a 16K file (PAGES.001 ...) loaded into
' a RAM page (cpcmin, cpcfw: a 6128 or more RAM) or, with one overlay area (cpm, Option Memory
' Small), into #4000-#7FFF in turn. Keep the page files (PAGES.001 to PAGES.004, numbered in
' the order of the Option Page lines) on the disc with the program.
'   - a class in no page is in main RAM (Score here: the levels and the credits all use it)
'   - a class in several pages is copied into each (Maths: no page switch when a level uses
'     it); its paged variables are separate in each copy (Stars counts per level) - with
'     one overlay area paged variables are ordinary variables, so the copies share them
'   - calls between classes of the same page switch nothing
' The compiler lists what is in each page, and how big (the GUI's messages; cli.js --layout).
Option Explicit
Option Page Intro  = Title
Option Page Stage1 = Level1, Maths, Stars
Option Page Stage2 = Level2, Maths, Stars
Option Page Ending = Credits
#If NTC_CPCMIN Then
Option RomEnable 7                ' RUN" drops AMSDOS: start it again, the pages load from disc
#End If
#If NTC_CPCFW Then
Option RomEnable 7
#End If
Option Reserve &H4000, &H4000     ' the program stays out of the window the pages run in

Title.Show
Level1.Play
Level2.Play
Level1.Play
Print "Maths from main: 7 squared is "; Maths.Square(7)
Print "Stars from main (Stage1's copy): "; Stars.Count()
Credits.Show
Print "Press a key";
Do While Inkey <> 0 : Loop
Do : Frame : Loop Until Inkey <> 0
Print
End
