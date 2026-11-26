' PI10VOX - NTC PI DEMOS 10: speech. The Pi emulates the Votrax SC-01 chip; phoneme bytes go as
' DATA. The chip's own ROM is not shipped: it must be in this machine's store as SYS/SC01A.BIN.
' STATUS says ready (it will speak), norom (no ROM in the store) or off (the Pi has no votrax
' program built). Only "ready" can be heard: YOU SHOULD HEAR "HELLO" FROM THE PI.
' (c) 2026 Cyborg Unicorn Pty Ltd
Option Explicit
Dim p(15) As Byte
Dim ch As Integer, ok As Integer

Mode 2
Link.Title "PI10 VOTRAX - speech from the Pi (the SC-01)"
If Not Link.Hello("PIDEMO") Then Print Link.Reply : Link.Summary : End
ch = Link.Open("votrax")
Link.Check "OPEN votrax", ch > 0
If ch = 0 Then Link.Summary : End
Link.Check "STATUS", Link.Ask(ch, "STATUS")
Print "    "; Link.Reply
If Link.Reply = "OK norom" Then Print "    no ROM: put the SC-01's 512 byte ROM in the store as PIDEMO's SYS/SC01A.BIN"
If Link.Reply = "OK off" Then Print "    off: the votrax program is not built on this Pi (cyborg-os/3p/votrax)"
' H EH1 L O1 U1 PA1 STOP
p(0) = &H1B : p(1) = &H02 : p(2) = &H18 : p(3) = &H35 : p(4) = &H37 : p(5) = &H3E : p(6) = &H3F
Link.Send ch, VarPtr(p), 7
Link.Check "7 phonemes sent (HELLO)", Not Link.Lost
If Link.Reply = "OK ready" Then Print "    LISTEN: the Pi should say HELLO"
Link.Check "the channel still answers", Link.Ask(ch, "STATUS")
Link.Check "STOP (the chip restarted)", Link.Ask(ch, "STOP")
ok = Link.Ask(ch, "SING")
Link.Check "an unknown request is refused", Not ok
Link.Shut ch
Link.Summary
