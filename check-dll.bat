@echo off
setlocal
set "TARGET=%~dp0"
set "PROXY=%TARGET%\version.dll"
if not exist "%PROXY%" set "PROXY=%TARGET%\version.dll.disabled"
"%~dp0diagnostics\dll_probe.exe" "%PROXY%" proxy > "%~dp0dll-check.txt" 2>&1
set "PROXY_RESULT=%errorlevel%"
"%~dp0diagnostics\dll_probe.exe" "%TARGET%\chat_translator.dll" worker >> "%~dp0dll-check.txt" 2>&1
set "WORKER_RESULT=%errorlevel%"
type "%~dp0dll-check.txt"
echo Proxy exit=%PROXY_RESULT% Worker exit=%WORKER_RESULT%
echo Kiem tra DLL trong goi moi, khong sua game. Gui dll-check.txt va hai exit code.
pause
