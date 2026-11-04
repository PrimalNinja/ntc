@echo off
rem Streamer - the UniDOS node ROM: sjasmplus (on the PATH, or ..\..\sjasmplus\sjasmplus.exe)
cd ..\src
sjasmplus streamer.asm
cd ..\build
dir streamer.rom
