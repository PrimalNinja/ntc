' Keys - the keyboard as keys held down, and the joysticks. NTC platform class: Sharp X68000
'
' Inkey / Inkey$ give characters typed; Keys tells whether a key is held down right now - for
' games: several at once, held keys, no auto repeat. Through the ROM's calls (IOCS _BITSNS: the
' keys held, 8 to a group; _JOYGET: a joystick), which work from user mode. Key numbers are the
' X68000 keyboard's own (group * 8 + bit) - the constants below name them, with the same names as
' on NTC's other machines.
'   If Keys.Down(Keys.KeyLeft) Then x = x - 1
'   j = Keys.Joystick(0) : If j And Keys.JoyFire1 Then ...
Option Explicit

' ---- key numbers
Public Const KeyEsc = 1           
Public Const Key1 = 2             
Public Const Key2 = 3             
Public Const Key3 = 4             
Public Const Key4 = 5             
Public Const Key5 = 6             
Public Const Key6 = 7             
Public Const Key7 = 8             
Public Const Key8 = 9             
Public Const Key9 = 10            
Public Const Key0 = 11            
Public Const KeyDel = 55          
Public Const KeyTab = 16          
Public Const KeyQ = 17            
Public Const KeyW = 18            
Public Const KeyE = 19            
Public Const KeyR = 20            
Public Const KeyT = 21            
Public Const KeyY = 22            
Public Const KeyU = 23            
Public Const KeyI = 24            
Public Const KeyO = 25            
Public Const KeyP = 26            
Public Const KeyEnter = 29        ' Return
Public Const KeyReturn = 29       
Public Const KeyA = 30            
Public Const KeyS = 31            
Public Const KeyD = 32            
Public Const KeyF = 33            
Public Const KeyG = 34            
Public Const KeyH = 35            
Public Const KeyJ = 36            
Public Const KeyK = 37            
Public Const KeyL = 38            
Public Const KeyZ = 42            
Public Const KeyX = 43            
Public Const KeyC = 44            
Public Const KeyV = 45            
Public Const KeyB = 46            
Public Const KeyN = 47            
Public Const KeyM = 48            
Public Const KeySpace = 53        
Public Const KeyLeft = 59         
Public Const KeyUp = 60           
Public Const KeyRight = 61        
Public Const KeyDown = 62         
Public Const KeyShift = 112       
Public Const KeyControl = 113     
Public Const KeyCaps = 112        ' Shift
Public Const KeySymbol = 113      ' Ctrl
Public Const KeyCopy = 98         ' COPY

' ---- Joystick() bits (the same as NTC's other machines)
Public Const JoyUp = 1
Public Const JoyDown = 2
Public Const JoyLeft = 4
Public Const JoyRight = 8
Public Const JoyFire2 = 16        ' button B
Public Const JoyFire1 = 32        ' button A

' Group(g): the keys of group g held (a bit each: key number = g * 8 + bit)
Public Function Group(ByVal g As Integer) As Integer
#asm
            movea.l (sp)+, a0
            move.w (a0), d1
            moveq #$04, d0              ; IOCS _BITSNS
            trap #15
            andi.w #255, d0
            movea.l (sp)+, a0
            move.w d0, (a0)
#endasm
End Function

' Down(key): True while the key is held
Public Function Down(ByVal key As Integer) As Integer
#asm
            movea.l (sp)+, a0
            move.w (a0), d2
            move.w d2, d1
            lsr.w #3, d1
            andi.w #15, d1
            moveq #$04, d0              ; IOCS _BITSNS
            trap #15
            andi.w #7, d2
            btst d2, d0
            sne d0
            ext.w d0
            movea.l (sp)+, a0
            move.w d0, (a0)
#endasm
End Function

' Joystick(n): joystick n + 1 (0 or 1): the Joy bits held (IOCS _JOYGET: a bit low for each held:
' up, down, left, right, -, A, B)
Public Function Joystick(ByVal n As Integer) As Integer
#asm
            movea.l (sp)+, a0
            move.w (a0), d1
            andi.w #1, d1
            moveq #$3B, d0              ; IOCS _JOYGET
            trap #15
            not.w d0
            move.w d0, d1
            andi.w #15, d0
            btst #5, d1
            beq kj_na
            ori.w #32, d0
kj_na:
            btst #6, d1
            beq kj_nb
            ori.w #16, d0
kj_nb:
            movea.l (sp)+, a0
            move.w d0, (a0)
#endasm
End Function
