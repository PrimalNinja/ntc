' Net: a ternary GRU run on the Z80 - GEN's model (tools/gen: trained on a PC, the weights -1 / 0 /
' 1 packed 4 a byte, the activations int8 in Tiny's units) - the same integer arithmetic as the
' PC's reference (tools/gen/qgru.py IntModel), so the two give the same bytes. The model file
' (GEN.MDL) is loaded by the program into memory; this class reads it in place.
'   Net.Load(addr, len)             the model at addr: True when its header is right
'   Net.Vocab() / Hidden() / Layers()
'   Net.Char(i) / Net.Index(ch)     the character of class i / the class of a character (0: unknown)
'   Net.Reset                       the state cleared (a new text)
'   n = Net.Feed(i)                 one character in; the class the model expects next (the biggest
'                                   logit); Net.Logit(i) each one (16 bits)
'   Net.FeedNoise(i, amp)           the same with +/- amp of noise on the logits (some variety)
' Needs Trit.cls and Tiny.cls. Up to 128 hidden, 128 classes, 2 layers. Weights are K balanced
' trits each (GEN.MDL v2: K planes, Horner-combined in DotK - still add / sub only, no multiply);
' K=1 is plain ternary and reads a v1 file too.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Option Explicit

Const MAXH = 128
Const MAXV = 128

Dim m_V As Integer, m_E As Integer, m_H As Integer, m_L As Integer, m_K As Integer
Dim m_cs As Integer, m_emb As Integer                   ' the charset, the embedding
Dim m_kih(1) As Integer, m_khh(1) As Integer, m_kout As Integer
Dim m_wih(1) As Integer, m_bih(1) As Integer, m_whh(1) As Integer, m_bhh(1) As Integer
Dim m_wout As Integer, m_bout As Integer
Dim m_x(MAXH - 1) As Byte                               ' the layer's input (the embedding, then h)
Dim m_h0(MAXH - 1) As Byte, m_h1(MAXH - 1) As Byte      ' the hidden states
Dim m_gi(3 * MAXH - 1) As Integer, m_gh(3 * MAXH - 1) As Integer
Dim m_lg(MAXV - 1) As Integer
Dim m_seed As Integer

Public Function Load(ByVal addr As Integer, ByVal n As Integer) As Integer
  Dim p As Integer, l As Integer, i As Integer, wi As Integer
  Dim ver As Integer
  Load = False
  If n < 12 Then Exit Function
  If Peek(addr) <> 71 Or Peek(addr + 1) <> 69 Or Peek(addr + 2) <> 78 Or Peek(addr + 3) <> 77 Then Exit Function
  ver = Peek(addr + 4)
  If ver <> 1 And ver <> 2 Then Exit Function
  m_V = Peek(addr + 5) : m_E = Peek(addr + 6) : m_H = Peek(addr + 7) : m_L = Peek(addr + 8)
  If m_V > MAXV Or m_H > MAXH Or m_L > 2 Or m_E > MAXH Then Exit Function
  p = addr + 9
  m_K = 1                                          ' v1: one trit a weight (plain ternary)
  If ver = 2 Then                                  ' v2: K balanced trits a weight, K planes
    m_K = Peek(p)
    p = p + 1
  End If
  If m_K < 1 Or m_K > 8 Then Exit Function
  m_cs = p : p = p + m_V
  m_emb = p : p = p + m_V * m_E
  For l = 0 To m_L - 1
    If l = 0 Then wi = m_E Else wi = m_H
    m_kih(l) = Peek(p) : m_khh(l) = Peek(p + 1) : p = p + 2
    m_wih(l) = p : p = p + m_K * 3 * m_H * (wi \ 4)
    m_bih(l) = p : p = p + 6 * m_H
    m_whh(l) = p : p = p + m_K * 3 * m_H * (m_H \ 4)
    m_bhh(l) = p : p = p + 6 * m_H
  Next
  m_kout = Peek(p) : p = p + 1
  m_wout = p : p = p + m_K * m_V * (m_H \ 4)
  m_bout = p : p = p + 2 * m_V
  If p - addr > n Then Exit Function
  Reset
  Load = True
End Function

Public Function Vocab() As Integer
  Vocab = m_V
End Function

Public Function Hidden() As Integer
  Hidden = m_H
End Function

Public Function Layers() As Integer
  Layers = m_L
End Function

Public Function Char(ByVal i As Integer) As String
  If i < 0 Or i >= m_V Then Char = "" Else Char = Chr$(Peek(m_cs + i))
End Function

Public Function Index(ByVal ch As String) As Integer
  Dim i As Integer, c As Integer
  Index = 0
  If Len(ch) = 0 Then Exit Function
  c = Asc(ch)
  For i = 0 To m_V - 1
    If Peek(m_cs + i) = c Then Index = i : Exit Function
  Next
End Function

Public Sub Reset()
  Dim i As Integer
  For i = 0 To MAXH - 1
    m_h0(i) = 0 : m_h1(i) = 0
  Next
End Sub

Public Function Logit(ByVal i As Integer) As Integer
  Logit = m_lg(i)
End Function

' v >> k, an arithmetic shift (floor), k 0-15
Private Function Sar(ByVal v As Integer, ByVal k As Integer) As Integer
#asm
            ld hl, ({v})
            ld a, ({k})
            or a
            jr z, sar_done
            ld b, a
sar_loop:   sra h
            rr l
            djnz sar_loop
sar_done:   ld ({result}), hl
#endasm
End Function

' the dot of a K-plane weight row at pw (its planes at pw, pw + wb, pw + 2*wb, ... each n/4 bytes)
' with the n values at xaddr: Horner over the balanced-trit planes, acc = acc*3 + plane_j . x with
' the high plane first. Each plane's dot is Trit.Dot - add / sub only, no multiply; the only
' arithmetic is the *3 on the running sum. K=1 is plain ternary (one Trit.Dot). The sum is 16-bit:
' fine for K up to a few while the dots stay small (they do here); a large K would want a Long.
Private Function DotK(ByVal pw As Integer, ByVal xaddr As Integer, ByVal n As Integer, ByVal wb As Integer, ByVal sh As Integer) As Integer
  Dim acc As Long, j As Integer
  If m_K = 1 Then
    DotK = Sar(Trit.Dot(pw, xaddr, n), sh)           ' plain ternary: 16-bit is enough
    Exit Function
  End If
  acc = 0                                            ' Long: the Horner *3 grows past 16 bits at K >= 4
  For j = 0 To m_K - 1                               ' plane K-1 down to 0 (high trit first)
    acc = acc * 3 + CLng(Trit.Dot(pw + (m_K - 1 - j) * wb, xaddr, n))
  Next
  DotK = LSar(acc, sh)                               ' floor(acc / 2^sh), down to 16 bits
End Function

' floor(v / 2^sh) for a Long v (an arithmetic shift right, matching the PC reference's >>); the
' result is a gate pre-activation and fits 16 bits
Private Function LSar(ByVal v As Long, ByVal sh As Integer) As Integer
  Dim p As Long, i As Integer
  p = 1
  For i = 1 To sh
    p = p * 2
  Next
  If v < 0 Then
    LSar = -(((0 - v) + (p - 1)) \ p)                ' floor for negatives (\ truncates toward zero)
  Else
    LSar = v \ p
  End If
End Function

' one GRU layer: m_x (wi wide) and h in, h out (in place)
Private Sub Layer(ByVal l As Integer, ByVal wi As Integer, ByVal haddr As Integer)
  Dim g As Integer, r As Integer, z As Integer, n As Integer, h As Integer
  Dim xaddr As Integer, wb As Integer, hb As Integer, kih As Integer, khh As Integer
  Dim pw As Integer, pb As Integer, ph As Integer, pbh As Integer
  xaddr = VarPtr(m_x(0))
  wb = wi \ 4 : hb = m_H \ 4
  kih = m_kih(l) : khh = m_khh(l)
  pw = m_wih(l) : pb = m_bih(l) : ph = m_whh(l) : pbh = m_bhh(l)
  For g = 0 To 3 * m_H - 1
    m_gi(g) = DotK(pw, xaddr, wi, wb, kih) + Deek(pb)
    m_gh(g) = DotK(ph, haddr, m_H, hb, khh) + Deek(pbh)
    pw = pw + m_K * wb : pb = pb + 2 : ph = ph + m_K * hb : pbh = pbh + 2
  Next
  For g = 0 To m_H - 1
    r = Tiny.Sigm(Tiny.Sat(m_gi(g) + m_gh(g)))
    z = Tiny.Sigm(Tiny.Sat(m_gi(m_H + g) + m_gh(m_H + g)))
    n = Tiny.Tanh(Tiny.Sat(m_gi(2 * m_H + g) + Tiny.Mul(r, Tiny.Sat(m_gh(2 * m_H + g)))))
    h = Tiny.FromByte(Peek(haddr + g))
    h = Tiny.Sat(Tiny.Mul(64 - z, n) + Tiny.Mul(z, h))
    Poke haddr + g, Tiny.ToByte(h)
  Next
End Sub

' one character in (its class); the class with the biggest logit back
Public Function Feed(ByVal c As Integer) As Integer
  Feed = FeedNoise(c, 0)
End Function

Public Function FeedNoise(ByVal c As Integer, ByVal amp As Integer) As Integer
  Dim i As Integer, best As Integer, bi As Integer, p As Integer, v As Integer
  If c < 0 Or c >= m_V Then c = 0
  p = m_emb + c * m_E
  For i = 0 To m_E - 1
    m_x(i) = Peek(p + i)
  Next
  Layer 0, m_E, VarPtr(m_h0(0))
  For i = 0 To m_H - 1
    m_x(i) = m_h0(i)
  Next
  If m_L > 1 Then
    Layer 1, m_H, VarPtr(m_h1(0))
    For i = 0 To m_H - 1
      m_x(i) = m_h1(i)
    Next
  End If
  p = m_wout
  bi = 0 : best = -32768
  For i = 0 To m_V - 1
    v = DotK(p, VarPtr(m_x(0)), m_H, m_H \ 4, m_kout) + Deek(m_bout + 2 * i)
    If amp > 0 Then
      m_seed = m_seed * 75 + 74                   ' (a small generator: the low bits are poor, the
      v = v + ((m_seed \ 64) Mod (2 * amp + 1)) - amp     ' middle ones fine for this)
    End If
    m_lg(i) = v
    If v > best Then best = v : bi = i
    p = p + m_K * (m_H \ 4)
  Next
  FeedNoise = bi
End Function

Public Sub Seed(ByVal s As Integer)
  m_seed = s
End Sub
