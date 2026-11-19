' Keys - the keyboard as keys held down, and the game pads. NTC platform class: Fujitsu FM Towns
'
' Inkey / Inkey$ give characters typed; Keys tells whether a key is held down right now - for
' games: several at once, held keys, no auto repeat. The keyboard sends a key's press and its
' release; the platform follows them (Inkey and Keys read the same events, so they can be mixed).
' Key numbers are the FM Towns keyboard's own (0-127) - the constants below name them, with the
' same names as on NTC's other machines.
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
Public Const KeyDel = 75          
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
Public Const KeyUp = 77           
Public Const KeyLeft = 79         
Public Const KeyDown = 80         
Public Const KeyRight = 81        
Public Const KeyControl = 82      
Public Const KeyShift = 83        
Public Const KeyCaps = 83         ' Shift
Public Const KeySymbol = 82       ' Ctrl
Public Const KeyCopy = 82         ' (no Copy: Ctrl)

' ---- Joystick() bits (the same as NTC's other machines; JoyRun and JoySelect are the pad's own)
Public Const JoyUp = 1
Public Const JoyDown = 2
Public Const JoyLeft = 4
Public Const JoyRight = 8
Public Const JoyFire2 = 16        ' the pad's B
Public Const JoyFire1 = 32        ' the pad's A
Public Const JoyRun = 64          ' RUN (the pad sends it as left and right together)
Public Const JoySelect = 128      ' SELECT (up and down together)

' Down(key): True while the key is held
Public Function Down(ByVal key As Integer) As Integer
#asm
            pop esi
            movzx ebx, word [esi]
            and ebx, 127
            NTC_RS
            call ntc_tw_keypoll
            NTC_TS
            movzx eax, byte [ntc_tw_held + ebx]
            neg eax
            pop edi
            mov [edi], ax
#endasm
End Function

' Joystick(n): the pad in port n + 1 (0 or 1): the Joy bits held. A pad's port reads a bit low for
' each held: up, down, left, right, A, B.
Public Function Joystick(ByVal n As Integer) As Integer
#asm
            pop esi
            movzx ecx, word [esi]
            and ecx, 1
            mov dx, 0x4D6                       ; the pads' common lines and triggers given to the pads
            mov al, 0x0F
            out dx, al
            lea edx, [0x4D0 + ecx * 2]
            xor eax, eax
            in al, dx
            not eax
            and eax, 0x3F
            mov ecx, eax                        ; A and B: the other way round in the Joy bits
            and eax, 0x0F
            test ecx, 0x10
            jz kj_na
            or eax, 32
kj_na:
            test ecx, 0x20
            jz kj_nb
            or eax, 16
kj_nb:
            mov ecx, eax
            and ecx, 12
            cmp ecx, 12
            jne kj_nrun
            and eax, ~12
            or eax, 64
kj_nrun:
            mov ecx, eax
            and ecx, 3
            cmp ecx, 3
            jne kj_nsel
            and eax, ~3
            or eax, 128
kj_nsel:
            pop edi
            mov [edi], ax
#endasm
End Function
