' PI01LINK - NTC PI DEMOS 1: is the card there, does the Pi answer?
' The card's status byte, HELLO, PING (50 times, timed), TIME, INFO, the services.
' (c) 2026 Cyborg Unicorn Pty Ltd
Option Explicit
Dim buf(1023) As Byte
Dim i As Integer, t As Integer, n As Integer, st As Integer

Mode 2
Link.Title "PI01 LINK - the card and the Pi"
st = Link.Status()
Print "Status byte at &FD81: &"; Hex$(st); "  (bit 0 a byte waiting, bit 1 room, bits 2 / 3 new data in Pi ROM 1 / 2)"
If Link.IsCPLink2() Then Print "Card: CPLink2 (bits 4-7 read 0001: its version)" Else Print "Card: CPC-CPLink (or none: bits 4-7 are not 0001)"
If st = &HFF Then
  Print "&FF: nothing answers at &FD81 - no card, or not a CPLink at this address."
  Link.Check "a card at &FD81", False
  Link.Summary : End
End If
Link.Check "the card has room to write (bit 1)", (st And 2) <> 0

Link.Check "HELLO answered", Link.Hello("PIDEMO")
Print "    "; Link.Reply
If Link.Lost Then Link.Summary : End

Link.Check "PING", Link.Ask(0, "PING")
Link.Check "PING says OK PONG", Link.Reply = "OK PONG"
t = Ticks : n = 0
For i = 1 To 50
  If Link.Ask(0, "PING") Then n = n + 1
Next
t = Ticks - t
Link.Check "50 PINGs all answered", n = 50
Print "    50 PINGs in "; t; " ticks (300 a second)"

Link.Check "TIME", Link.Ask(0, "TIME")
Print "    "; Link.Reply
Link.Check "INFO", Link.AskTo(0, "INFO", VarPtr(buf), 1000)
Print "    "; Link.Reply
Link.Check "LIST (the services)", Link.AskTo(0, "LIST", VarPtr(buf), 1023)
Print "    "; Link.Reply; "  ("; Link.BodyLen; " bytes in "; Link.Parts; " frames; the first "; Link.Kept; " shown)"
For i = 0 To Link.Kept - 1
  Print Chr$(buf(i));
Next
Print
Link.Check "an unknown request is refused", Not Link.Ask(0, "NOSUCH")
Link.Summary
