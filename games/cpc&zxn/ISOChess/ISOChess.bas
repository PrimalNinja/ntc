' ============================================================================
' ISOMETRIC CHESS for NTC BASIC (Amstrad CPC - cpc / cpcmin / cpcfw, ZX Spectrum Next - zxn)
' (zxn: also add Nx.cls to the project)
' ============================================================================
Option Explicit
Option Turbo Off
Option PressAnyKeyOnEnd "Game Over - Press any key"

' Piece Constants (Positive = White/Player, Negative = Black/CPU)
Const EMPTY_SQ = 0
Const PAWN = 1
Const KNIGHT = 2
Const BISHOP = 3
Const ROOK = 4
Const QUEEN = 5
Const KING = 6

' Game States
Const STATE_SELECT = 0
Const STATE_MOVE = 1
Const STATE_CPU = 2
Const STATE_OVER = 3

' Pens. CPC: pens 1-3 of Mode 1. Next: Layer 2 palette entries; the pens use separate bits so
' where XOR lines cross the mixed entries (3, 5, 6, 9, 10, 12) can be given a sensible colour
#If NTC_ZXN Then
Const PEN_GRID = 1
Const PEN_WHITE = 2
Const PEN_BLACK = 4
Const PEN_MARK = 8
#Else
Const PEN_GRID = 1
Const PEN_WHITE = 2
Const PEN_BLACK = 3
Const PEN_MARK = 3
#End If

' Isometric Projection Constants (Mode 1: 320x200)
Const ORIGIN_X = 160
Const ORIGIN_Y = 44
Const TILE_W = 16
Const TILE_H = 8

' Timer Constants (300 ticks/sec * 60 seconds = 18000 ticks)
Const TURN_LIMIT_TICKS = 18000&
Const TICKS_PER_SEC = 300&

' Board & Move State Arrays
Dim Board(7, 7) As Integer
Dim ValidMap(7, 7) As Byte
Dim ValidCount As Integer

' Cursor & Selection Globals
Dim CurX As Integer
Dim CurY As Integer
Dim SelX As Integer
Dim SelY As Integer
Dim CursorDrawn As Boolean
Dim MarkersDrawn As Boolean

' Game Flow & Clock Globals
Dim GameState As Integer
Dim Winner As Integer
Dim WinReason As String Max 36
Dim TurnStartTicks As Long
Dim LastSecShown As Integer

' Input Edge-Detection State
Dim PrevW As Boolean
Dim PrevA As Boolean
Dim PrevS As Boolean
Dim PrevD As Boolean
Dim PrevSpace As Boolean

' ============================================================================
' MAIN ENTRY POINT
' ============================================================================
Sub Main()
  Mode 1
  Cls
#If NTC_ZXN Then
  SetNextPalette
#End If
  Graphics.Clip 1
  Randomize

  InitGame
  DrawStaticBoard
  DrawAllPieces
  UpdateHUD True

  CurX = 4 : CurY = 6
  CursorDrawn = False
  MarkersDrawn = False
  DrawCursor CurX, CurY, PEN_MARK
  CursorDrawn = True

  WaitKeyRelease

  Do While GameState <> STATE_OVER
    CheckTurnTimer
    If GameState = STATE_OVER Then Exit Do

    If GameState = STATE_CPU Then
      MakeCPUMove
    Else
      HandlePlayerInput
    End If

    Frame
  Loop

  ShowGameOver
End Sub

#If NTC_ZXN Then
' Layer 2 palette (RRRGGGBB): 0 black, 1 board lines, 2 white pieces, 4 black (CPU) pieces,
' 8 cursor and move markers; the mixed entries are where two XOR lines cross
Sub SetNextPalette()
  Nx.PalEntry Nx.PalLayer2, 0, &H00
  Nx.PalEntry Nx.PalLayer2, 1, &H1F    ' cyan
  Nx.PalEntry Nx.PalLayer2, 2, &HFF    ' white
  Nx.PalEntry Nx.PalLayer2, 3, &HFF    ' grid x white
  Nx.PalEntry Nx.PalLayer2, 4, &HE0    ' red
  Nx.PalEntry Nx.PalLayer2, 5, &HE0    ' grid x red
  Nx.PalEntry Nx.PalLayer2, 6, &HFF    ' white x red
  Nx.PalEntry Nx.PalLayer2, 8, &HFC    ' yellow
  Nx.PalEntry Nx.PalLayer2, 9, &HFC    ' grid x marker
  Nx.PalEntry Nx.PalLayer2, 10, &HFC   ' white x marker
  Nx.PalEntry Nx.PalLayer2, 12, &HFC   ' red x marker
End Sub
#End If

' ============================================================================
' INITIALIZATION
' ============================================================================
Sub InitGame()
  Dim x As Integer, y As Integer

  For y = 0 To 7
    For x = 0 To 7
      Board(x, y) = EMPTY_SQ
      ValidMap(x, y) = 0
    Next x
  Next y

  ' Black Pieces (CPU - Top of board, rows 0 and 1)
  Board(0, 0) = -ROOK   : Board(1, 0) = -KNIGHT : Board(2, 0) = -BISHOP : Board(3, 0) = -QUEEN
  Board(4, 0) = -KING   : Board(5, 0) = -BISHOP : Board(6, 0) = -KNIGHT : Board(7, 0) = -ROOK
  For x = 0 To 7
    Board(x, 1) = -PAWN
    Board(x, 6) = PAWN
  Next x

  ' White Pieces (Player - Bottom of board, rows 6 and 7)
  Board(0, 7) = ROOK    : Board(1, 7) = KNIGHT  : Board(2, 7) = BISHOP  : Board(3, 7) = QUEEN
  Board(4, 7) = KING    : Board(5, 7) = BISHOP  : Board(6, 7) = KNIGHT  : Board(7, 7) = ROOK

  GameState = STATE_SELECT
  Winner = 0
  WinReason = ""
  ResetTurnTimer
End Sub

Sub ResetTurnTimer()
  TurnStartTicks = Ticks
  LastSecShown = -1
End Sub

' ============================================================================
' ISOMETRIC GRAPHICS & RENDERING (XOR MODE)
' ============================================================================
Function IsoX(ByVal c As Integer, ByVal r As Integer) As Integer
  IsoX = ORIGIN_X + (c - r) * TILE_W
End Function

Function IsoY(ByVal c As Integer, ByVal r As Integer) As Integer
  IsoY = ORIGIN_Y + (c + r) * TILE_H
End Function

Sub DrawStaticBoard()
  Dim i As Integer
  Dim x0 As Integer, y0 As Integer, x1 As Integer, y1 As Integer
  Dim bx0 As Integer, by0 As Integer, bx1 As Integer, by1 As Integer, bx2 As Integer, by2 As Integer

  Graphics.Pen PEN_GRID

  ' Draw Isometric Grid Lines
  For i = 0 To 8
    x0 = IsoX(0, i) : y0 = IsoY(0, i)
    x1 = IsoX(8, i) : y1 = IsoY(8, i)
    Graphics.Line x0, y0, x1, y1

    x0 = IsoX(i, 0) : y0 = IsoY(i, 0)
    x1 = IsoX(i, 8) : y1 = IsoY(i, 8)
    Graphics.Line x0, y0, x1, y1
  Next i

  ' Draw 3D Board Rim / Base Thickness
  bx0 = IsoX(0, 8) : by0 = IsoY(0, 8)
  bx1 = IsoX(8, 8) : by1 = IsoY(8, 8)
  bx2 = IsoX(8, 0) : by2 = IsoY(8, 0)

  Graphics.Line bx0, by0 + 1, bx0, by0 + 5
  Graphics.Line bx1, by1 + 1, bx1, by1 + 5
  Graphics.Line bx2, by2 + 1, bx2, by2 + 5
  Graphics.Line bx0, by0 + 5, bx1, by1 + 5
  Graphics.Line bx1, by1 + 5, bx2, by2 + 5
End Sub

Sub DrawAllPieces()
  Dim x As Integer, y As Integer
  For y = 0 To 7
    For x = 0 To 7
      If Board(x, y) <> EMPTY_SQ Then
        DrawPieceAt x, y, Board(x, y)
      End If
    Next x
  Next y
End Sub

' Draws or erases a piece at (c, r) using XOR lines
Sub DrawPieceAt(ByVal c As Integer, ByVal r As Integer, ByVal p As Integer)
  Dim cx As Integer, cy As Integer
  Dim pt As Integer, penCol As Integer

  If p = EMPTY_SQ Then Exit Sub

  pt = Abs(p)
  If p > 0 Then
    penCol = PEN_WHITE ' White (Player)
  Else
    penCol = PEN_BLACK ' Black (CPU)
  End If

  Graphics.Pen penCol

  ' Center of isometric tile (c, r) is at IsoX(c, r) + (1 - 1)*16 = IsoX(c, r), IsoY(c, r) + 8
  cx = IsoX(c, r)
  cy = IsoY(c, r) + TILE_H

  ' Base Pedestal (Isometric diamond base)
  Graphics.Line cx - 6, cy, cx, cy - 3
  Graphics.Line cx, cy - 3, cx + 6, cy
  Graphics.Line cx + 6, cy, cx, cy + 3
  Graphics.Line cx, cy + 3, cx - 6, cy

  ' For CPU pieces, add an inner base line to distinguish visually alongside colour
  If p < 0 Then
    Graphics.Line cx - 3, cy, cx + 3, cy
  End If

  Select Case pt
    Case PAWN
      Graphics.Line cx - 3, cy - 1, cx, cy - 9
      Graphics.Line cx + 3, cy - 1, cx, cy - 9
      Graphics.Line cx - 2, cy - 9, cx + 2, cy - 9

    Case ROOK
      Graphics.Line cx - 4, cy - 1, cx - 4, cy - 11
      Graphics.Line cx + 4, cy - 1, cx + 4, cy - 11
      Graphics.Line cx - 4, cy - 11, cx + 4, cy - 11
      Graphics.Line cx - 2, cy - 11, cx - 2, cy - 13
      Graphics.Line cx + 2, cy - 11, cx + 2, cy - 13

    Case KNIGHT
      Graphics.Line cx - 3, cy - 1, cx - 2, cy - 11
      Graphics.Line cx - 2, cy - 11, cx + 4, cy - 9
      Graphics.Line cx + 4, cy - 9, cx + 1, cy - 6
      Graphics.Line cx + 1, cy - 6, cx + 3, cy - 1

    Case BISHOP
      Graphics.Line cx - 4, cy - 1, cx, cy - 13
      Graphics.Line cx + 4, cy - 1, cx, cy - 13
      Graphics.Line cx - 2, cy - 7, cx + 2, cy - 7

    Case QUEEN
      Graphics.Line cx - 4, cy - 1, cx - 5, cy - 12
      Graphics.Line cx + 4, cy - 1, cx + 5, cy - 12
      Graphics.Line cx - 5, cy - 12, cx - 2, cy - 7
      Graphics.Line cx - 2, cy - 7, cx, cy - 13
      Graphics.Line cx, cy - 13, cx + 2, cy - 7
      Graphics.Line cx + 2, cy - 7, cx + 5, cy - 12

    Case KING
      Graphics.Line cx - 4, cy - 1, cx - 3, cy - 11
      Graphics.Line cx + 4, cy - 1, cx + 3, cy - 11
      Graphics.Line cx - 3, cy - 11, cx + 3, cy - 11
      Graphics.Line cx, cy - 11, cx, cy - 16
      Graphics.Line cx - 3, cy - 14, cx + 3, cy - 14
  End Select
End Sub

' Draws or erases the inset isometric cursor diamond
Sub DrawCursor(ByVal c As Integer, ByVal r As Integer, ByVal penCol As Integer)
  Dim cx As Integer, cy As Integer
  cx = IsoX(c, r)
  cy = IsoY(c, r) + TILE_H

  Graphics.Pen penCol
  Graphics.Line cx, cy - 6, cx + 12, cy
  Graphics.Line cx + 12, cy, cx, cy + 6
  Graphics.Line cx, cy + 6, cx - 12, cy
  Graphics.Line cx - 12, cy, cx, cy - 6
End Sub

' Draws or erases small markers on all valid destination tiles
Sub ToggleValidMarkers()
  Dim x As Integer, y As Integer
  Dim cx As Integer, cy As Integer

  Graphics.Pen PEN_MARK
  For y = 0 To 7
    For x = 0 To 7
      If ValidMap(x, y) = 1 Then
        cx = IsoX(x, y)
        cy = IsoY(x, y) + TILE_H
        Graphics.Line cx - 3, cy, cx, cy - 2
        Graphics.Line cx, cy - 2, cx + 3, cy
        Graphics.Line cx + 3, cy, cx, cy + 2
        Graphics.Line cx, cy + 2, cx - 3, cy
      End If
    Next x
  Next y
End Sub

' ============================================================================
' HUD & TIMERS
' ============================================================================
Sub UpdateHUD(ByVal fullRedraw As Boolean)
  Dim elapsed As Long, remTicks As Long
  Dim secsLeft As Integer

  elapsed = Ticks - TurnStartTicks
  If elapsed < 0 Then elapsed = 0
  remTicks = TURN_LIMIT_TICKS - elapsed
  If remTicks < 0 Then remTicks = 0
  secsLeft = CInt(remTicks \ TICKS_PER_SEC)

  If fullRedraw Then
    Locate 1, 1
    Print "ISOMETRIC CHESS   WASD:Move SPACE:Select";
    Locate 1, 2
    If GameState = STATE_SELECT Then
      Print "TURN: PLAYER (Select Piece)             ";
    ElseIf GameState = STATE_MOVE Then
      Print "TURN: PLAYER (Select Target / Origin)   ";
    ElseIf GameState = STATE_CPU Then
      Print "TURN: CPU THINKING...                   ";
    End If
    Locate 1, 24
    Print "Sq: "; Chr$(65 + CurX); CStr(8 - CurY); " "; PieceName(Board(CurX, CurY)); "       ";
  End If

  If secsLeft <> LastSecShown Or fullRedraw Then
    LastSecShown = secsLeft
    Locate 28, 24
    Print "TIME: "; Format$(secsLeft, "00"); "s ";
  End If
End Sub

Function PieceName(ByVal p As Integer) As String
  Dim s As String
  If p = EMPTY_SQ Then
    PieceName = "Empty     "
    Exit Function
  End If

  If p > 0 Then s = "W-" Else s = "B-"
  Select Case Abs(p)
    Case PAWN:   s = s & "Pawn  "
    Case KNIGHT: s = s & "Knight"
    Case BISHOP: s = s & "Bishop"
    Case ROOK:   s = s & "Rook  "
    Case QUEEN:  s = s & "Queen "
    Case KING:   s = s & "King  "
  End Select
  PieceName = s
End Function

Sub CheckTurnTimer()
  Dim elapsed As Long
  elapsed = Ticks - TurnStartTicks

  If elapsed >= TURN_LIMIT_TICKS Then
    If GameState = STATE_CPU Then
      Winner = 1
      WinReason = "CPU forfeited on 1-minute time limit!"
    Else
      Winner = -1
      WinReason = "Player forfeited on 1-min time limit!"
    End If
    GameState = STATE_OVER
  Else
    UpdateHUD False
  End If
End Sub

' ============================================================================
' PLAYER INPUT & CONSTRAINED CURSOR LOGIC
' ============================================================================
Sub WaitKeyRelease()
  Do While Keys.Down(Keys.KeyW) Or Keys.Down(Keys.KeyA) Or Keys.Down(Keys.KeyS) Or Keys.Down(Keys.KeyD) Or Keys.Down(Keys.KeySpace)
    Frame
  Loop
  PrevW = False : PrevA = False : PrevS = False : PrevD = False : PrevSpace = False
End Sub

Sub HandlePlayerInput()
  Dim kW As Boolean, kA As Boolean, kS As Boolean, kD As Boolean, kSp As Boolean
  Dim dx As Integer, dy As Integer
  Dim nx As Integer, ny As Integer

  kW = Keys.Down(Keys.KeyW)
  kA = Keys.Down(Keys.KeyA)
  kS = Keys.Down(Keys.KeyS)
  kD = Keys.Down(Keys.KeyD)
  kSp = Keys.Down(Keys.KeySpace)

  dx = 0 : dy = 0
  If kW And Not PrevW Then dy = -1
  If kS And Not PrevS Then dy = 1
  If kA And Not PrevA Then dx = -1
  If kD And Not PrevD Then dx = 1

  PrevW = kW : PrevA = kA : PrevS = kS : PrevD = kD

  ' Handle Directional Cursor Movement
  If dx <> 0 Or dy <> 0 Then
    If GameState = STATE_SELECT Then
      nx = CurX + dx
      ny = CurY + dy
      If nx >= 0 And nx <= 7 And ny >= 0 And ny <= 7 Then
        MoveCursorTo nx, ny
      End If
    ElseIf GameState = STATE_MOVE Then
      ' In STATE_MOVE, limit cursor positions strictly to valid moves for the selected piece
      ' (plus the piece's own origin square so the player can cancel selection)
      FindNextValidSquare CurX, CurY, dx, dy, nx, ny
      If nx <> CurX Or ny <> CurY Then
        MoveCursorTo nx, ny
      End If
    End If
  End If

  ' Handle Space Bar Selection / Placement
  If kSp And Not PrevSpace Then
    PrevSpace = True
    If GameState = STATE_SELECT Then
      ' Must select a White piece that has at least 1 valid move
      If Board(CurX, CurY) > 0 Then
        ComputeValidMoves CurX, CurY
        If ValidCount > 0 Then
          SelX = CurX
          SelY = CurY
          ToggleValidMarkers
          MarkersDrawn = True
          GameState = STATE_MOVE
          UpdateHUD True
        End If
      End If
    ElseIf GameState = STATE_MOVE Then
      If CurX = SelX And CurY = SelY Then
        ' Cancel selection and return to piece selection state
        If MarkersDrawn Then
          ToggleValidMarkers
          MarkersDrawn = False
        End If
        GameState = STATE_SELECT
        UpdateHUD True
      ElseIf ValidMap(CurX, CurY) = 1 Then
        ' Execute valid move
        If MarkersDrawn Then
          ToggleValidMarkers
          MarkersDrawn = False
        End If
        If CursorDrawn Then
          DrawCursor CurX, CurY, PEN_MARK
          CursorDrawn = False
        End If

        ExecuteMove SelX, SelY, CurX, CurY

        If GameState <> STATE_OVER Then
          GameState = STATE_CPU
          ResetTurnTimer
          UpdateHUD True
        End If
      End If
    End If
  ElseIf Not kSp Then
    PrevSpace = False
  End If
End Sub

Sub MoveCursorTo(ByVal nx As Integer, ByVal ny As Integer)
  If CursorDrawn Then
    DrawCursor CurX, CurY, PEN_MARK
  End If
  CurX = nx
  CurY = ny
  DrawCursor CurX, CurY, PEN_MARK
  CursorDrawn = True
  UpdateHUD True
End Sub

' Finds the nearest valid move square (or origin SelX, SelY) in the direction (dx, dy)
Sub FindNextValidSquare(ByVal cx As Integer, ByVal cy As Integer, ByVal dx As Integer, ByVal dy As Integer, ByRef bestX As Integer, ByRef bestY As Integer)
  Dim x As Integer, y As Integer
  Dim vx As Integer, vy As Integer
  Dim dot As Integer, cross As Integer, dist As Integer
  Dim bestScore As Integer, score As Integer

  bestX = cx
  bestY = cy
  bestScore = 30000

  For y = 0 To 7
    For x = 0 To 7
      If ValidMap(x, y) = 1 Or (x = SelX And y = SelY) Then
        If x <> cx Or y <> cy Then
          vx = x - cx
          vy = y - cy
          dot = vx * dx + vy * dy
          ' Must lie strictly in the requested half-plane
          If dot > 0 Then
            cross = Abs(vx * dy - vy * dx)
            dist = Abs(vx) + Abs(vy)
            score = dist * 4 + cross * 6
            If score < bestScore Then
              bestScore = score
              bestX = x
              bestY = y
            End If
          End If
        End If
      End If
    Next x
  Next y
End Sub

' ============================================================================
' CHESS RULES & VALID MOVE GENERATION
' ============================================================================
Sub ComputeValidMoves(ByVal sx As Integer, ByVal sy As Integer)
  Dim tx As Integer, ty As Integer
  ValidCount = 0

  For ty = 0 To 7
    For tx = 0 To 7
      If IsValidChessMove(sx, sy, tx, ty) Then
        ValidMap(tx, ty) = 1
        ValidCount = ValidCount + 1
      Else
        ValidMap(tx, ty) = 0
      End If
    Next tx
  Next ty
End Sub

Function IsValidChessMove(ByVal sx As Integer, ByVal sy As Integer, ByVal tx As Integer, ByVal ty As Integer) As Boolean
  Dim p As Integer, target As Integer
  Dim pt As Integer, side As Integer
  Dim dx As Integer, dy As Integer, adx As Integer, ady As Integer

  IsValidChessMove = False
  If sx = tx And sy = ty Then Exit Function
  If tx < 0 Or tx > 7 Or ty < 0 Or ty > 7 Then Exit Function

  p = Board(sx, sy)
  If p = EMPTY_SQ Then Exit Function

   side = Sgn(p)
  target = Board(tx, ty)

  ' Cannot capture own piece
  If target <> EMPTY_SQ Then
    If Sgn(target) = side Then Exit Function
  End If

  pt = Abs(p)
  dx = tx - sx
  dy = ty - sy
  adx = Abs(dx)
  ady = Abs(dy)

  Select Case pt
    Case PAWN
      If side > 0 Then
        ' White Pawn moves UP (dy < 0)
        If dx = 0 And dy = -1 And target = EMPTY_SQ Then
          IsValidChessMove = True
        ElseIf dx = 0 And dy = -2 And sy = 6 And target = EMPTY_SQ And Board(sx, 5) = EMPTY_SQ Then
          IsValidChessMove = True
        ElseIf adx = 1 And dy = -1 And target < 0 Then
          IsValidChessMove = True
        End If
      Else
        ' Black Pawn moves DOWN (dy > 0)
        If dx = 0 And dy = 1 And target = EMPTY_SQ Then
          IsValidChessMove = True
        ElseIf dx = 0 And dy = 2 And sy = 1 And target = EMPTY_SQ And Board(sx, 2) = EMPTY_SQ Then
          IsValidChessMove = True
        ElseIf adx = 1 And dy = 1 And target > 0 Then
          IsValidChessMove = True
        End If
      End If

    Case KNIGHT
      If (adx = 1 And ady = 2) Or (adx = 2 And ady = 1) Then
        IsValidChessMove = True
      End If

    Case BISHOP
      If adx = ady Then
        If IsPathClear(sx, sy, tx, ty) Then IsValidChessMove = True
      End If

    Case ROOK
      If dx = 0 Or dy = 0 Then
        If IsPathClear(sx, sy, tx, ty) Then IsValidChessMove = True
      End If

    Case QUEEN
      If dx = 0 Or dy = 0 Or adx = ady Then
        If IsPathClear(sx, sy, tx, ty) Then IsValidChessMove = True
      End If

    Case KING
      If adx <= 1 And ady <= 1 Then
        IsValidChessMove = True
      End If
  End Select
End Function

Function IsPathClear(ByVal sx As Integer, ByVal sy As Integer, ByVal tx As Integer, ByVal ty As Integer) As Boolean
  Dim stepX As Integer, stepY As Integer
  Dim cx As Integer, cy As Integer

  IsPathClear = False
  stepX = Sgn(tx - sx)
  stepY = Sgn(ty - sy)

  cx = sx + stepX
  cy = sy + stepY

  Do While cx <> tx Or cy <> ty
    If Board(cx, cy) <> EMPTY_SQ Then Exit Function
    cx = cx + stepX
    cy = cy + stepY
  Loop

  IsPathClear = True
End Function

' ============================================================================
' MOVE EXECUTION & CPU AI
' ============================================================================
Sub ExecuteMove(ByVal sx As Integer, ByVal sy As Integer, ByVal tx As Integer, ByVal ty As Integer)
  Dim movingPiece As Integer, capturedPiece As Integer

  movingPiece = Board(sx, sy)
  capturedPiece = Board(tx, ty)

  ' Erase moving piece from origin
  DrawPieceAt sx, sy, movingPiece

  ' Erase captured piece at destination if present
  If capturedPiece <> EMPTY_SQ Then
    DrawPieceAt tx, ty, capturedPiece
  End If

  ' Pawn Promotion to Queen at back ranks
  If movingPiece = PAWN And ty = 0 Then movingPiece = QUEEN
  If movingPiece = -PAWN And ty = 7 Then movingPiece = -QUEEN

  ' Update Board State
  Board(sx, sy) = EMPTY_SQ
  Board(tx, ty) = movingPiece

  ' Draw piece at new position
  DrawPieceAt tx, ty, movingPiece

  ' Check if a King was captured
  If Abs(capturedPiece) = KING Then
    If capturedPiece < 0 Then
      Winner = 1
      WinReason = "Player captured the CPU's King!"
    Else
      Winner = -1
      WinReason = "CPU captured the Player's King!"
    End If
    GameState = STATE_OVER
  End If
End Sub

Function PieceValue(ByVal pt As Integer) As Integer
  Select Case Abs(pt)
    Case PAWN:   PieceValue = 10
    Case KNIGHT: PieceValue = 30
    Case BISHOP: PieceValue = 30
    Case ROOK:   PieceValue = 50
    Case QUEEN:  PieceValue = 90
    Case KING:   PieceValue = 1000
    Case Else:   PieceValue = 0
  End Select
End Function

Sub MakeCPUMove()
  Dim sx As Integer, sy As Integer, tx As Integer, ty As Integer
  Dim bestSX As Integer, bestSY As Integer, bestTX As Integer, bestTY As Integer
  Dim bestScore As Integer, score As Integer
  Dim foundMove As Boolean

  foundMove = False
  bestScore = -30000

  For sy = 0 To 7
    For sx = 0 To 7
      ' Check all Black (CPU) pieces
      If Board(sx, sy) < 0 Then
        For ty = 0 To 7
          For tx = 0 To 7
            If IsValidChessMove(sx, sy, tx, ty) Then
              CheckTurnTimer
              If GameState = STATE_OVER Then Exit Sub

              ' Score move: prioritize captures, advancement, and slight randomness
              score = PieceValue(Board(tx, ty)) * 10 + ty * 2 + Rnd(6)

              ' Bonus for Pawn promotion
              If Board(sx, sy) = -PAWN And ty = 7 Then
                score = score + 800
              End If

              If score > bestScore Or Not foundMove Then
                bestScore = score
                bestSX = sx : bestSY = sy
                bestTX = tx : bestTY = ty
                foundMove = True
              End If
            End If
          Next tx
        Next ty
      End If
    Next sx
  Next sy

  If Not foundMove Then
    Winner = 1
    WinReason = "CPU has no legal moves remaining!"
    GameState = STATE_OVER
    Exit Sub
  End If

  ExecuteMove bestSX, bestSY, bestTX, bestTY

  If GameState <> STATE_OVER Then
    GameState = STATE_SELECT
    ResetTurnTimer
    DrawCursor CurX, CurY, PEN_MARK
    CursorDrawn = True
    UpdateHUD True
  End If
End Sub

' ============================================================================
' GAME OVER SCREEN
' ============================================================================
Sub ShowGameOver()
  Locate 1, 2
  If Winner = 1 Then
    Print "GAME OVER - PLAYER (WHITE) WINS!        ";
  ElseIf Winner = -1 Then
    Print "GAME OVER - CPU (BLACK) WINS!           ";
  Else
    Print "GAME OVER - DRAW!                       ";
  End If

  Locate 1, 25
  Print WinReason;
End Sub