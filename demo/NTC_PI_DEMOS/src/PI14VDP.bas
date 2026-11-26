' PI14VDP - NTC PI DEMOS 14: the Pi's HDMI as a video chip (the vdp service, profile v9990),
' through hwlib's Pi class (NTC's own: src/hwlib/lib/Pi.cls, copied here unchanged). Twelve
' balls are put on the Pi with movers and animation; the Pi moves them itself, the CPC only
' says "frame". LOOK AT THE PI'S SCREEN: twelve red balls bouncing in a box. After 150 frames
' the Pi is asked where ball 0 and ball 11 are, twice: they must be there and must have moved.
' Then it runs on (any key ends it).
' Pi.cls waits for the Pi with no time limit: run PI01LINK first if this one just sits there.
' (c) 2026 Cyborg Unicorn Pty Ltd
Option Explicit
Dim i As Integer, k As Integer, t As Integer
Dim s0 As String Max 80, s1 As String Max 80

Mode 2
Link.Title "PI14 VDP - sprites on the Pi's HDMI (hwlib's Pi class)"
If Not Link.Hello("HWLIB") Then Print Link.Reply : Link.Summary : End
Link.Check "HELLO (the link is alive before Pi.cls takes it)", True
Pi.Init
Pi.Palette 1, 56, 0, 0 : Pi.Palette 2, 96, 0, 16 : Pi.Palette 3, 144, 16, 24 : Pi.Palette 4, 192, 40, 40
Pi.Palette 5, 224, 80, 56 : Pi.Palette 6, 248, 128, 96 : Pi.Palette 7, 255, 255, 255
Pi.Palette 8, 160, 160, 0 : Pi.Palette 9, 216, 216, 0 : Pi.Palette 10, 255, 255, 120
For i = 0 To 3
  Pi.Pattern i, Art.Ball() + i * 128
Next
Pi.Bounds 0, 48, 239, 195
For i = 0 To 11
  Pi.Put i, 6 + i * 19, 56 + (i * 23) Mod 120, 0
  Pi.Move i, 1 + (i Mod 3), 1 + ((i + 1) Mod 2)
  Pi.Anim i, 0, 4, 4 + (i Mod 3) * 2
Next
t = Ticks
For i = 1 To 150
  Pi.Frame
Next
t = Ticks - t
Print "    150 frames in "; t; " ticks (300 a second)"
' the vdp channel is the first one opened on this link: 1
Link.Check "CHANS shows the vdp channel", Link.Ask(0, "CHANS")
Link.Check "STATE 0: ball 0 is on the Pi", Link.Ask(1, "STATE 0") And Left$(Link.Reply, 5) = "OK 0 "
s0 = Link.Reply
Print "    "; s0
Link.Check "STATE 11: ball 11 is on the Pi", Link.Ask(1, "STATE 11") And Left$(Link.Reply, 6) = "OK 11 "
Print "    "; Link.Reply
For i = 1 To 10
  Pi.Frame
Next
Link.Check "STATE 0 again", Link.Ask(1, "STATE 0")
s1 = Link.Reply
Print "    "; s1
Link.Check "  ball 0 has moved", s0 <> s1
Link.Summary
Print "Running on: any key ends it."
Do
  Pi.Frame
Loop While Inkey = 0
