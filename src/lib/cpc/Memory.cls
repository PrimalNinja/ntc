' Memory - RAM. NTC platform class: Amstrad CPC (direct hardware)
'
' Option Memory picks how the RAM is reached; the methods are the same either way, so a
' program builds with either. Decided when compiling: only that scheme's code is in the
' program.
'
' Option Memory CPCExpansion [maxpages]   (the default on cpc, cpcmin, cpcfw)
'   16K RAM pages switched into #4000-#7FFF (the window) by the gate array, up to a 4MB
'   expansion: page 1 = main RAM #4000-#7FFF, pages 2+ = 4 for each 64K bank found (6128:
'   pages 2-5), the standard 512K (port #7F) first, then the 512K blocks on #7E .. #78.
'   The first call probes what is fitted:
'     Small  (64K)          1 page         Pages() = 1
'     Medium (128K)         5 pages        Pages() = 5
'     Large  (up to 576K)   9 - 33 pages
'     Huge   (up to 4160K)  37 - 257 pages
'   maxpages (1 - 257) caps it - and shrinks the class's fixed data to suit.
'   Every page is on one list: free, C, D, I or U. Free pages come from two lists: main RAM
'   and the standard 512K for C / I / U, the blocks above it for D (the heap) - each falls
'   back to the other, so on 576K or less it is all one list.
'   The class keeps its page tables from the program's end up (3 bytes a page: 6128 15
'   bytes, 4MB 771), made by the first call - TableEnd() is the first byte after them.
'   With no room below #4000 it keeps fewer pages. The program, and its stack, must be out
'   of the window (Option Reserve &H4000, &H4000), else Pages() = 0. Anything the program
'   reads or writes in the window (Poke, FileSystem.Load ...) goes to the page in it then.
'
' Option Memory Small   (the default on cpm and test; any platform)
'   No paging: Alloc / Free over the free main RAM, from the program's end up to the
'   platform's top (CPC #A600, CP/M the BDOS), the stack, or an Option Reserve range -
'   HeapStart() / HeapEnd(). Far pointers are plain addresses (page 0). Pages() = 0; the
'   page methods give 0 or BadPage. The least code.
'
' A program asks for what it wants (AllocPage, Alloc); 0 back = not there, it carries on.
' Far pointer = a Long: low word the address, high word the page (0 = plain memory, no
' switching). Alloc gives them; Address, ReadByte, WriteByte ... use them.
' Only SelectPage and Address change the page in the window; the rest put it back.

' ---- status
Public Const OK = 0
Public Const BadPage = -2         ' not a page this machine has, not allocated, not a block

' ---- page types (the character Map shows)
Public Const TypeFree = 45        ' "-"
Public Const TypeCode = 67        ' "C" code (pageable classes, compiled sprites)
Public Const TypeData = 68        ' "D" the heap: Alloc / Free
Public Const TypeIrq = 73         ' "I" interrupt handler
Public Const TypeUser = 85        ' "U" the program's own (music, level data ...)
Public Const TypeBank = 66        ' "B" a whole 64K bank (AllocBank)
Public Const BankStubSize = 16    ' the bytes CallBank puts in a bank at BankStub()

' ---- the window (CPCExpansion), worked out when compiling - use these, not &H4000
#If NTC_MEM_CPCEXPANSION Then
Public Const WindowStart = &H4000
Public Const WindowSize = &H4000
#Else
Public Const WindowStart = 0      ' Small: no window
Public Const WindowSize = 0
#End If

' ---- models
Public Const ModelNone = 0        ' no paging (Small, or the program in the window)
Public Const ModelSmall = 1       ' 64K: 1 page
Public Const ModelMedium = 2      ' 128K: 5 pages
Public Const ModelLarge = 3       ' up to a 512K expansion: 33 pages
Public Const ModelHuge = 4        ' more: up to 257 pages (4MB)

' ---- what is there

' Pages(): pages this machine has (0, 1, 5, 9, 17, 33 ... 257)
Public Function Pages() As Integer
#asm
            pop hl
            ld (mem_res), hl
            ld hl, mem_pages
            jp mem_go
#endasm
End Function

' FreePages(): of those, still free
Public Function FreePages() As Integer
#asm
            pop hl
            ld (mem_res), hl
            ld hl, mem_freepages
            jp mem_go
#endasm
End Function

' RamSize(): K of RAM found (64, 128 ... 4160), 0 = no paging so not probed
Public Function RamSize() As Integer
#asm
            pop hl
            ld (mem_res), hl
            ld hl, mem_ramsize
            jp mem_go
#endasm
End Function

' Model(): ModelNone, ModelSmall, ModelMedium, ModelLarge, ModelHuge
Public Function Model() As Integer
#asm
            pop hl
            ld (mem_res), hl
            ld hl, mem_model
            jp mem_go
#endasm
End Function

' PageType(page): its type character (TypeFree ...), or BadPage
Public Function PageType(ByVal page As Integer) As Integer
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (mem_a1), de
            pop hl
            ld (mem_res), hl
            ld hl, mem_pagetype
            jp mem_go
#endasm
End Function

' HeapStart(), HeapEnd(): Small: the heap's main RAM (HeapEnd is the first byte past it);
' CPCExpansion: the window (the heap is in D pages there)
Public Function HeapStart() As Integer
#asm
            pop hl
            ld (mem_res), hl
            ld hl, mem_heapstart
            jp mem_go
#endasm
End Function

Public Function HeapEnd() As Integer
#asm
            pop hl
            ld (mem_res), hl
            ld hl, mem_heapend
            jp mem_go
#endasm
End Function

' TableEnd(): the first byte after the class's page tables (they start at the program's end;
' Small: no tables, the program's end)
Public Function TableEnd() As Integer
#asm
            pop hl
            ld (mem_res), hl
            ld hl, mem_tableend
            jp mem_go
#endasm
End Function

' ProgramStart(), ProgramEnd(): where the program is (ProgramEnd: the first byte after it
' and its arrays). Top(): the platform's top of free RAM (CPC #A600 - the firmware above;
' CP/M the BDOS; test #C000). StackTop(): the real stack (it grows down from here).
Public Function ProgramStart() As Integer
#asm
            pop hl
            ld (mem_res), hl
            ld hl, mem_progstart
            jp mem_go
#endasm
End Function

Public Function ProgramEnd() As Integer
#asm
            pop hl
            ld (mem_res), hl
            ld hl, mem_progend
            jp mem_go
#endasm
End Function

Public Function Top() As Integer
#asm
            pop hl
            ld (mem_res), hl
            ld hl, mem_top
            jp mem_go
#endasm
End Function

Public Function StackTop() As Integer
#asm
            pop hl
            ld (mem_res), hl
            ld hl, mem_stacktop
            jp mem_go
#endasm
End Function

' Map(first, count): one character per page from page first: "UCUDD--" (as many as the
' string holds; pages past the last are left out)
Public Function Map(ByVal first As Integer, ByVal count As Integer) As String
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (mem_a1), de
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (mem_a2), de
            pop hl
            ld (mem_res), hl
            ld hl, mem_map
            jp mem_go0
#endasm
End Function

' ---- whole pages

' AllocPage(kind): a free page, now of that kind (TypeCode, TypeData, TypeIrq, TypeUser);
' 0 = none left (or not one of those kinds)
Public Function AllocPage(ByVal kind As Integer) As Integer
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (mem_a1), de
            pop hl
            ld (mem_res), hl
            ld hl, mem_allocpage
            jp mem_go
#endasm
End Function

' FreePage(page): back to free (a heap page's blocks go with it). OK, or BadPage (not a
' page, or free already)
Public Function FreePage(ByVal page As Integer) As Integer
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (mem_a1), de
            pop hl
            ld (mem_res), hl
            ld hl, mem_freepage
            jp mem_go
#endasm
End Function

' SelectPage(page): into the window. WindowStart, or BadPage
Public Function SelectPage(ByVal page As Integer) As Integer
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (mem_a1), de
            pop hl
            ld (mem_res), hl
            ld hl, mem_selpage
            jp mem_go
#endasm
End Function

' CurrentPage(): the page in the window (0 = no paging)
Public Function CurrentPage() As Integer
#asm
            pop hl
            ld (mem_res), hl
            ld hl, mem_curpage
            jp mem_go
#endasm
End Function

' ---- the heap (in D pages)

' Alloc(size): a far pointer to size bytes (up to 16382), 0 = no room (Small: page 0)
Public Function Alloc(ByVal size As Integer) As Long
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (mem_a1), de
            pop hl
            ld (mem_res), hl
            ld hl, mem_alloc
            jp mem_go4
#endasm
End Function

' Free(ptr): a block from Alloc. A page left with nothing in it goes back to free.
' OK or BadPage
Public Function Free(ByVal ptr As Long) As Integer
#asm
            pop hl
            ld (mem_a1), hl
            pop hl
            ld (mem_res), hl
            ld hl, mem_free
            jp mem_go
#endasm
End Function

' Largest(): the biggest block Alloc could give now
Public Function Largest() As Integer
#asm
            pop hl
            ld (mem_res), hl
            ld hl, mem_largest
            jp mem_go
#endasm
End Function

' PageOf(ptr): a far pointer's page
Public Function PageOf(ByVal ptr As Long) As Integer
#asm
            pop hl
            ld (mem_a1), hl
            pop hl
            ld (mem_res), hl
            ld hl, mem_pageof
            jp mem_go
#endasm
End Function

' Address(ptr): its page into the window (page 0: nothing switched); the address
Public Function Address(ByVal ptr As Long) As Integer
#asm
            pop hl
            ld (mem_a1), hl
            pop hl
            ld (mem_res), hl
            ld hl, mem_address
            jp mem_go
#endasm
End Function

' ---- data through far pointers (the window is put back)

Public Function ReadByte(ByVal ptr As Long) As Integer
#asm
            pop hl
            ld (mem_a1), hl
            pop hl
            ld (mem_res), hl
            ld hl, mem_readbyte
            jp mem_go
#endasm
End Function

Public Function ReadWord(ByVal ptr As Long) As Integer
#asm
            pop hl
            ld (mem_a1), hl
            pop hl
            ld (mem_res), hl
            ld hl, mem_readword
            jp mem_go
#endasm
End Function

Public Sub WriteByte(ByVal ptr As Long, ByVal value As Integer)
#asm
            pop hl
            ld (mem_a1), hl
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (mem_a2), de
            ld hl, mem_writebyte
            jp mem_go0
#endasm
End Sub

Public Sub WriteWord(ByVal ptr As Long, ByVal value As Integer)
#asm
            pop hl
            ld (mem_a1), hl
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (mem_a2), de
            ld hl, mem_writeword
            jp mem_go0
#endasm
End Sub

' Copy(src, dst, length): far pointer to far pointer, 2K at a time through the buffer
' FileSystem uses too. Past #7FFF of a page it carries on at #4000 of the next page.
' OK or BadPage
Public Function Copy(ByVal src As Long, ByVal dst As Long, ByVal length As Integer) As Integer
#asm
            pop hl
            ld (mem_a1), hl
            pop hl
            ld (mem_a2), hl
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (mem_a3), de
            pop hl
            ld (mem_res), hl
            ld hl, mem_copy
            jp mem_go
#endasm
End Function

' ---- whole 64K banks (an expansion's 64K blocks: bank 1 = pages 2-5, bank 2 = pages 6-9 ...)

' Banks(): whole banks there are (0 = none: a 64K machine, or no paging)
Public Function Banks() As Integer
#asm
            pop hl
            ld (mem_res), hl
            ld hl, mem_bankcount
            jp mem_go
#endasm
End Function

' AllocBank(): a bank whose 4 pages are all free, now TypeBank; 0 = none left
Public Function AllocBank() As Integer
#asm
            pop hl
            ld (mem_res), hl
            ld hl, mem_allocbank
            jp mem_go
#endasm
End Function

' FreeBank(bank): its 4 pages back to free. OK, or BadPage (not a bank, or not taken
' with AllocBank)
Public Function FreeBank(ByVal bank As Integer) As Integer
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (mem_a1), de
            pop hl
            ld (mem_res), hl
            ld hl, mem_freebank
            jp mem_go
#endasm
End Function

' BankPage(bank, n): the page number of the bank's 16K part n (0 = its #0000-#3FFF ...
' 3 = #C000-#FFFF), for SelectPage, ReadByte, WriteByte and Copy (a far pointer is
' address #4000-#7FFF plus page * 65536)
Public Function BankPage(ByVal bank As Integer, ByVal n As Integer) As Integer
    BankPage = 4 * bank - 2 + n
End Function

' CallBank(bank, address, value): runs the bank's code at address with the whole 64K
' being that bank; it gets value in HL and its HL comes back. The bank must be taken
' (AllocBank). The switch code (about 20 bytes, at BankStub()) is copied into the bank
' at the same address first, so keep the bank's code and data away from it. While the
' bank's code runs: interrupts off, both ROMs off, nothing of the program or the screen
' in sight, the stack starts at the bank's top (#FFFF down). It ends with ret and must
' keep the alternate registers (BC', DE', HL'). BadPage = not a bank, or not taken.
Public Function CallBank(ByVal bank As Integer, ByVal address As Integer, ByVal value As Integer) As Integer
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (mem_a1), de
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (mem_a2), de
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (mem_a3), de
            pop hl
            ld (mem_res), hl
            ld hl, mem_callbank
            jp mem_go
#endasm
End Function

' BankStub(): where the switch code goes in a bank CallBank runs (it is BankStubSize
' bytes long; 0 = no banks)
Public Function BankStub() As Integer
#asm
            pop hl
            ld (mem_res), hl
            ld hl, mem_bkstub
            jp mem_go
#endasm
End Function
