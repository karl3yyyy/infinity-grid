@echo off
rem Doppelklick: prueft, baut, veroeffentlicht (Cloudflare) und pusht (GitHub).
cd /d "%~dp0"
echo Infinity Grid wird veroeffentlicht ...
powershell -NoProfile -ExecutionPolicy Bypass -File "tools\publish_all.ps1" %*
echo.
pause
