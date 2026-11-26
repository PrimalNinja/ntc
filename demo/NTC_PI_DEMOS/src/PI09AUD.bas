' PI09AUD - NTC PI DEMOS 9: music played by the Pi. A short tone is made here (6000 8-bit
' samples, half a second at 12324 a second), put in the store as MUSIC/8BIT/PIDEMO and played:
' YOU SHOULD HEAR A HALF SECOND BEEP FROM THE PI. Then STATUS, the ENDED event, STOP, VOL and a
' tag that is not there. The Pi needs aplay (it is in the OS); without it PLAY says so.
' (c) 2026 Cyborg Unicorn Pty Ltd
Option Explicit
Dim b(5999) As Byte
Dim st As Integer, ch As Integer, i As Integer, k As Integer, t As Integer, ok As Integer, ended As Integer, v As Integer, bad As Integer

Mode 2
Link.Title "PI09 AUDIO - music played by the Pi"
If Not Link.Hello("PIDEMO") Then Print Link.Reply : Link.Summary : End
st = Link.Open("store")
ch = Link.Open("audio pos=1")
Link.Check "OPEN store and OPEN audio (two channels at once)", st > 0 And ch > 0 And st <> ch
If st = 0 Or ch = 0 Then Link.Summary : End
Link.Check "STATUS says idle", Link.Ask(ch, "STATUS") And Link.Reply = "OK idle"

' a 440 Hz triangle wave: 28 samples a cycle
v = 0
For i = 0 To 5999
  k = i Mod 28
  If k < 14 Then v = 68 + k * 8 Else v = 68 + (27 - k) * 8
  b(i) = v
Next
Link.Check "the tone put in the store (MUSIC/8BIT/PIDEMO, 6000 bytes)", Link.AskWith(st, "PUT MUSIC/8BIT/PIDEMO", VarPtr(b), 6000)
Link.LastEvent = ""
ok = Link.Ask(ch, "PLAY MUSIC/8BIT/PIDEMO")
Link.Check "PLAY MUSIC/8BIT/PIDEMO", ok
If Not ok Then Print "    the Pi could not play it: "; Link.Reply
ok = Link.Ask(ch, "STATUS")
Print "    "; Link.Reply
Link.Check "STATUS says playing (or the half second is over already)", Left$(Link.Reply, 10) = "OK playing" Or Link.Reply = "OK idle"
' the ENDED event: it may have come while STATUS was being answered (then it is in LastEvent)
ended = (Left$(Link.LastEvent, 5) = "ENDED") : bad = (Left$(Link.LastEvent, 3) = "ERR") : t = Ticks
If Link.LastEvent <> "" Then Print "    event: "; Link.LastEvent
Do While Not (ended Or bad Or Link.Lost Or (Ticks - t > 1800))
  k = Link.Poll(VarPtr(b), 256)
  If k = 5 Then
    Print "    event: "; Link.Reply
    If Left$(Link.Reply, 5) = "ENDED" Then ended = True
    If Left$(Link.Reply, 3) = "ERR" Then bad = True
  End If
Loop
If bad Then Print "    THE PI'S PLAYER DID NOT START (the event above): is aplay installed on the Pi?"
Link.Check "the ENDED event came", ended
Link.Check "STATUS is idle again", Link.Ask(ch, "STATUS") And Link.Reply = "OK idle"
ok = Link.Ask(ch, "PLAY MUSIC/8BIT/NOTTHERE")
Link.Check "a tag that is not there is refused (ERR nofile)", (Not ok) And Left$(Link.Reply, 10) = "ERR nofile"
Link.Check "VOL 80", Link.Ask(ch, "VOL 80")
Link.Check "STOP", Link.Ask(ch, "STOP")
ok = Link.Ask(ch, "NEXT")
Link.Check "NEXT with no list is refused (ERR nolist)", (Not ok) And Left$(Link.Reply, 10) = "ERR nolist"
Link.Check "the tone taken out of the store again", Link.Ask(st, "DEL MUSIC/8BIT/PIDEMO")
Link.Shut ch : Link.Shut st
Link.Summary
