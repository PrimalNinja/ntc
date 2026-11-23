' Keys - the game pads, with the same calls as the Keys class on NTC's machines that have a
' keyboard, so a game's control code needs no change. NTC platform class: SNK Neo Geo
'
' The Neo Geo has no keyboard: Keys.Down is always False (the key names are here so the same
' line compiles). Keys.Joystick(n) is pad n + 1 (the Pad class has every button by its own name).
'   j = Keys.Joystick(0) : If j And Keys.JoyFire1 Then ...
Option Explicit

' ---- key numbers (no keyboard: every one is 0)
Public Const KeyCaps = 0
Public Const KeyZ = 0
Public Const KeyX = 0
Public Const KeyC = 0
Public Const KeyV = 0
Public Const KeyA = 0
Public Const KeyS = 0
Public Const KeyD = 0
Public Const KeyF = 0
Public Const KeyG = 0
Public Const KeyQ = 0
Public Const KeyW = 0
Public Const KeyE = 0
Public Const KeyR = 0
Public Const KeyT = 0
Public Const Key1 = 0
Public Const Key2 = 0
Public Const Key3 = 0
Public Const Key4 = 0
Public Const Key5 = 0
Public Const Key0 = 0
Public Const Key9 = 0
Public Const Key8 = 0
Public Const Key7 = 0
Public Const Key6 = 0
Public Const KeyP = 0
Public Const KeyO = 0
Public Const KeyI = 0
Public Const KeyU = 0
Public Const KeyY = 0
Public Const KeyEnter = 0
Public Const KeyL = 0
Public Const KeyK = 0
Public Const KeyJ = 0
Public Const KeyH = 0
Public Const KeySpace = 0
Public Const KeySymbol = 0
Public Const KeyM = 0
Public Const KeyN = 0
Public Const KeyB = 0
Public Const KeyLeft = 0
Public Const KeyDown = 0
Public Const KeyUp = 0
Public Const KeyRight = 0
Public Const KeyReturn = 0
Public Const KeyShift = 0
Public Const KeyControl = 0
Public Const KeyCopy = 0
Public Const KeyEsc = 0
Public Const KeyDel = 0
Public Const KeyTab = 0

' ---- Joystick() bits (the first six as NTC's other machines)
Public Const JoyUp = 1
Public Const JoyDown = 2
Public Const JoyLeft = 4
Public Const JoyRight = 8
Public Const JoyFire2 = 16        ' button B
Public Const JoyFire1 = 32        ' button A
Public Const JoyFire3 = 64        ' button C
Public Const JoyStart = 128       ' Start
Public Const JoyFire4 = 256       ' button D
Public Const JoySelect = 512      ' Select (a home console's; an arcade board has none)

Public Function Down(ByVal key As Integer) As Integer
    Down = 0
End Function

Public Function Joystick(ByVal n As Integer) As Integer
    Dim intP As Integer, intR As Integer
    intP = Pad.Read(n + 1)
    intR = intP And 15
    If (intP And Pad.B) <> 0 Then intR = intR Or JoyFire2
    If (intP And Pad.A) <> 0 Then intR = intR Or JoyFire1
    If (intP And Pad.C) <> 0 Then intR = intR Or JoyFire3
    If (intP And Pad.Start) <> 0 Then intR = intR Or JoyStart
    If (intP And Pad.D) <> 0 Then intR = intR Or JoyFire4
    If (intP And Pad.SelectKey) <> 0 Then intR = intR Or JoySelect
    Joystick = intR
End Function
