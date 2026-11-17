' X68000: the keyboard through the ROM's key calls, Locate, Ticks (x68regress.sh)
Dim nm As String, v As Integer, k As Integer, t As Integer
Input "Name"; nm
Input "Number"; v
Print "name "; nm; " n"; v * 3;
Do : k = Inkey : Frame : Loop Until k <> 0
Print " k"; k;
t = System.Ticks()
Frame : Frame : Frame
If System.Ticks() - t >= 3 And System.Ticks() - t <= 5 Then Print " at ok" Else Print " at bad"
Locate 20, 10 : Print "here";
