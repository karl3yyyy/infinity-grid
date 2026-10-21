@echo off
rem Startet den WLAN-Host. Mit "neu" als Argument wird die Web-Version neu exportiert.
title Infinity Grid - WLAN-Spiel
if /I "%~1"=="neu" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\start_lan_game.ps1" -Rebuild
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\start_lan_game.ps1"
)
pause
