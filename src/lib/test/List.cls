' List - linked lists. NTC platform class: test harness (Option Memory Small)
'
' Linked lists in the Memory class's heap: D pages with Option Memory CPCExpansion, the free
' main RAM with Option Memory Small - so a list can be far bigger than the program's own
' memory. A list is a handle (a Long), so a program can have as many as it likes; each costs
' 4 bytes of main memory. Nodes are far pointers (Longs) too; each has a next and a previous
' node and size bytes of data, read and written with GetWord / SetWord / GetByte / SetByte
' (or Memory.ReadWord(List.Data(node) + offset) ...).
' A list takes its nodes from blocks of up to 16000 bytes at a time, cut into nodes on its own
' free chain: Append / Delete are a pointer swap, nothing fragments. Destroy gives the blocks
' back. Statuses: Memory's (BadPage -2: not a list or node).
'
'   h = List.Create(10)                 ' 10 data bytes a node
'   n = List.Append(h) : List.SetWord n, 0, 1234
'   n = List.First(h)
'   Do While n <> 0
'     Print List.GetWord(n, 0)
'     n = List.NextOf(n)
'   Loop

' Create(size): a new empty list, size data bytes a node (up to 15988); 0 = no room
Public Function Create(ByVal size As Integer) As Long
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (mem_a1), de
            pop hl
            ld (mem_res), hl
            ld hl, lst_create
            jp mem_go4
#endasm
End Function
' Append(h), Prepend(h): a new node (cleared) at the end / the start; 0 = no room
Public Function Append(ByVal h As Long) As Long
#asm
            pop hl
            ld (mem_a1), hl
            pop hl
            ld (mem_res), hl
            ld hl, lst_append
            jp mem_go4
#endasm
End Function
Public Function Prepend(ByVal h As Long) As Long
#asm
            pop hl
            ld (mem_a1), hl
            pop hl
            ld (mem_res), hl
            ld hl, lst_prepend
            jp mem_go4
#endasm
End Function
' InsertAfter(h, node): a new node after that one (node 0: at the start); 0 = no room
Public Function InsertAfter(ByVal h As Long, ByVal node As Long) As Long
#asm
            pop hl
            ld (mem_a1), hl
            pop hl
            ld (mem_a2), hl
            pop hl
            ld (mem_res), hl
            ld hl, lst_insert
            jp mem_go4
#endasm
End Function
' Delete(h, node): out of the list (its memory goes back to the list's free chain). OK
Public Function Delete(ByVal h As Long, ByVal node As Long) As Integer
#asm
            pop hl
            ld (mem_a1), hl
            pop hl
            ld (mem_a2), hl
            pop hl
            ld (mem_res), hl
            ld hl, lst_delete
            jp mem_go
#endasm
End Function
' First(h), Last(h), NextOf(node), PrevOf(node): a node, or 0
Public Function First(ByVal h As Long) As Long
#asm
            pop hl
            ld (mem_a1), hl
            pop hl
            ld (mem_res), hl
            ld hl, lst_first
            jp mem_go4
#endasm
End Function
Public Function Last(ByVal h As Long) As Long
#asm
            pop hl
            ld (mem_a1), hl
            pop hl
            ld (mem_res), hl
            ld hl, lst_last
            jp mem_go4
#endasm
End Function
Public Function NextOf(ByVal node As Long) As Long
#asm
            pop hl
            ld (mem_a1), hl
            pop hl
            ld (mem_res), hl
            ld hl, lst_nextof
            jp mem_go4
#endasm
End Function
Public Function PrevOf(ByVal node As Long) As Long
#asm
            pop hl
            ld (mem_a1), hl
            pop hl
            ld (mem_res), hl
            ld hl, lst_prevof
            jp mem_go4
#endasm
End Function
' Count(h): the nodes in it
Public Function Count(ByVal h As Long) As Integer
#asm
            pop hl
            ld (mem_a1), hl
            pop hl
            ld (mem_res), hl
            ld hl, lst_countof
            jp mem_go
#endasm
End Function
' GetWord(node, offset), GetByte(node, offset): from its data
Public Function GetWord(ByVal node As Long, ByVal offset As Integer) As Integer
#asm
            pop hl
            ld (mem_a1), hl
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (mem_a2), de
            pop hl
            ld (mem_res), hl
            ld hl, lst_getword
            jp mem_go
#endasm
End Function
Public Function GetByte(ByVal node As Long, ByVal offset As Integer) As Integer
#asm
            pop hl
            ld (mem_a1), hl
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (mem_a2), de
            pop hl
            ld (mem_res), hl
            ld hl, lst_getbyte
            jp mem_go
#endasm
End Function
' SetWord node, offset, value / SetByte node, offset, value: into its data
Public Sub SetWord(ByVal node As Long, ByVal offset As Integer, ByVal value As Integer)
#asm
            pop hl
            ld (mem_a1), hl
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
            ld hl, lst_setword
            jp mem_go0
#endasm
End Sub
Public Sub SetByte(ByVal node As Long, ByVal offset As Integer, ByVal value As Integer)
#asm
            pop hl
            ld (mem_a1), hl
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
            ld hl, lst_setbyte
            jp mem_go0
#endasm
End Sub
' Data(node): a far pointer to its data (for Memory.Copy, Memory.ReadWord ...)
Public Function Data(ByVal node As Long) As Long
#asm
            pop hl
            ld (mem_a1), hl
            pop hl
            ld (mem_res), hl
            ld hl, lst_dataof
            jp mem_go4
#endasm
End Function
' Search(h, offset, value): the first node whose data has that word at offset, or 0
Public Function Search(ByVal h As Long, ByVal offset As Integer, ByVal value As Integer) As Long
#asm
            pop hl
            ld (mem_a1), hl
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
            ld hl, lst_search
            jp mem_go4
#endasm
End Function
' Sort(h, offset): in order of the word at offset (signed; equal ones keep their order). OK
Public Function Sort(ByVal h As Long, ByVal offset As Integer) As Integer
#asm
            pop hl
            ld (mem_a1), hl
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (mem_a2), de
            pop hl
            ld (mem_res), hl
            ld hl, lst_sort
            jp mem_go
#endasm
End Function
' Destroy(h): the list's memory back to the heap; the handle and its nodes are gone. OK
Public Function Destroy(ByVal h As Long) As Integer
#asm
            pop hl
            ld (mem_a1), hl
            pop hl
            ld (mem_res), hl
            ld hl, lst_destroy
            jp mem_go
#endasm
End Function
