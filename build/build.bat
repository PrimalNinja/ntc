@echo off
rem ============================================================
rem NTC BASIC test builds - assemble every program for every platform
rem (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
rem ============================================================
rem   build.bat                          sjasmplus.exe in this folder, or on the PATH
rem   build.bat C:\tools\sjasmplus.exe   or give its path (relative paths work too)
rem
rem   cpc\    Amstrad CPC, hardware     NAME.BIN  AMSDOS file, loads and runs at #0040
rem   cpcmin\ Amstrad CPC, minimal fw   NAME.BIN  AMSDOS file, loads and runs at #0040
rem   cpcfw\  Amstrad CPC, firmware     NAME.BIN  AMSDOS file, loads and runs at #0040
rem   cpcrom\ cpcminrom\ cpcfwrom\     NAME.BIN  as cpc / cpcmin / cpcfw, Library: ROM
rem                                     (the keywords in NTCCPC / NTCMIN / NTCFW.ROM)
rem   rom\    the keyword library ROMs  NTCCPC.ROM NTCMIN.ROM NTCFW.ROM: 16K + AMSDOS
rem                                     header, for ROM slots
rem   cpm\    CP/M 2.2 / 3              NAME.COM  at #0100
rem   test\   test harness platform     NAME.BIN  raw, at #4000 (for test\ntcrun.py)
rem   zxn\    ZX Spectrum Next, hardware NAME.NEX  NEX file (NextZXOS: run it from the browser)
rem
rem On the CPC: put the .BIN files on a disk image (or an M4 / SD card) and
rem RUN"NAME. On CP/M: copy the .COM files to the CP/M disk and type NAME.
rem The .ASM files are made by test\genbuild.js from bas\ - do not edit them.
rem cpm\SIEVEC.ASM is the sieve in Small C, copied from compare\smallc\.
rem ============================================================
setlocal
set SJ=sjasmplus
if exist "%~dp0sjasmplus.exe" set SJ=%~dp0sjasmplus.exe
if not "%~1"=="" set SJ=%~1
if exist "%~1" set SJ=%~f1
set FAIL=0
pushd "%~dp0"

for %%P in (cpc cpcmin cpcfw cpcrom cpcminrom cpcfwrom rom) do (
	pushd %%P
	for %%F in (*.ASM) do (
		echo %%P\%%F
		"%SJ%" --nologo --msg=err %%F || set FAIL=1
	)
	popd
)

pushd cpm
for %%F in (*.ASM) do (
	echo cpm\%%F
	"%SJ%" --nologo --msg=err --raw=%%~nF.COM %%F || set FAIL=1
)
popd

pushd zxn
for %%F in (*.ASM) do (
	echo zxn\%%F
	"%SJ%" --nologo --msg=err %%F || set FAIL=1
)
popd

pushd test
for %%F in (*.ASM) do (
	echo test\%%F
	"%SJ%" --nologo --msg=err --raw=%%~nF.BIN %%F || set FAIL=1
)
popd

popd
echo.
if "%FAIL%"=="1" (echo SOME FAILED) else (echo ALL BUILT)
endlocal
