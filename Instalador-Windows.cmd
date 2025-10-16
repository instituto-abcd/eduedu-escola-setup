@echo off
powershell -Command "Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoExit -NoProfile -ExecutionPolicy Bypass -File \"%~dp0installation-scripts\startup-windows.ps1\"' -Verb RunAs"
exit /b 0