' INTRODUCTION TO ZOSCII - an illustrated tour of ZOSCII and UNSIGNAL for the ZX Spectrum Next, with an attacker to try. NTC BASIC.
' (c) 2026 Cyborg Unicorn Pty Ltd
#Const SplashNoPlain = 1
Option Explicit
Option Turbo
Option NexData "INTRO.DAT", 42
Option Next2MB                                  ' <--- NEW (the program already needs a 2MB Next: its data runs past bank 47)
Option Memory CPCExpansion
Option Page SCR Loaded 20 = Splash
Option Page DEMO Loaded 21 = Demo, Proto, Esx
Option Page PLAYP Loaded 22 = Play, Attack, Screens
Option Memory Reserved &H4000, &H4000
Rng.Start &H243F, &H6A88, &H85A3, &H08D3
Vid.Init
Rng.Reseed
Snd.Init
Vid.Sync : Vid.Sync : Vid.Sync
Splash.Show 1
Splash.Show 2
Intro.Run
