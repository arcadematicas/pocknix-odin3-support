@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0flash-openabl.ps1" %*
pause
