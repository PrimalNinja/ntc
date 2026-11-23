' Psg - the YM2610's SSG on the Neo Geo: an AY-3-8910 inside the chip (three square waves, a noise,
' envelopes), clocked at 2 MHz. The registers are written through NTC's sound driver on the Z80.
' NTC platform class: SNK Neo Geo (68000). (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'   Psg.Reg r, v         register r (0-13) = v (sent only when it changes: three bytes to the Z80)
'   Psg.Tone ch, p, v    channel ch (0-2): tone period p (1-4095: 125000 / p Hz), volume v (0-15)
'   Psg.Noise ch, p, v   channel ch: noise, period p (0-31: one noise for all three), volume v
'   Psg.Off ch           channel ch silent
'   Psg.Quiet            all three silent
' (A ZX Spectrum's or a Next's AY runs at 1.7734 MHz: the same note is its period and an eighth more.)
Option Explicit

Private regs(15) As Integer         ' the registers as last written
Private mix As Integer              ' register 7: 1 bits are off (tones 0-2, noises 3-5)
Private blnUp As Integer

Private Sub Fresh()
    Dim i As Integer
    If blnUp = 0 Then
        blnUp = 1
        For i = 0 To 15
            regs(i) = -1
        Next i
        mix = &H3F
    End If
End Sub

Public Sub Reg(ByVal r As Integer, ByVal v As Integer)
    Fresh
    r = r And 15
    If r < 14 Then
        If regs(r) <> v Then
            regs(r) = v
            Sound.Send &H10 : Sound.Send r : Sound.Send v
        End If
    End If
End Sub

Public Sub Tone(ByVal ch As Integer, ByVal p As Integer, ByVal v As Integer)
    Fresh
    Reg ch * 2, p And 255
    Reg ch * 2 + 1, (p \ 256) And 15
    mix = (mix And Not Bit(ch)) Or Bit(ch + 3)
    Reg 7, mix
    Reg 8 + ch, v And 15
End Sub

Public Sub Noise(ByVal ch As Integer, ByVal p As Integer, ByVal v As Integer)
    Fresh
    Reg 6, p And 31
    mix = (mix And Not Bit(ch + 3)) Or Bit(ch)
    Reg 7, mix
    Reg 8 + ch, v And 15
End Sub

Public Sub Off(ByVal ch As Integer)
    Fresh
    mix = mix Or Bit(ch) Or Bit(ch + 3)
    Reg 7, mix
    Reg 8 + ch, 0
End Sub

Public Sub Quiet()
    Off 0 : Off 1 : Off 2
End Sub

Private Function Bit(ByVal n As Integer) As Integer
    Select Case n
        Case 0: Bit = 1
        Case 1: Bit = 2
        Case 2: Bit = 4
        Case 3: Bit = 8
        Case 4: Bit = 16
        Case Else: Bit = 32
    End Select
End Function
