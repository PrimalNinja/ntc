' TOP: the TOP table (each slot's state, program, and its turns, BDOS calls and characters in the
' last whole second), then the totals, printed once into this slot, in CyborgOS (build for cpm,
' with CybSys.cls). Control + ESC shows it live
Option Explicit
Dim r As Integer
r = CybSys.Ask(6, 0)
