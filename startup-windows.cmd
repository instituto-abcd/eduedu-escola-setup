@echo off
powershell -Command "Start-Process -FilePath 'powershell.exe' -ArgumentList ' -NoProfile -ExecutionPolicy Bypass -File \"%~dp0startup-windows.ps1\"' -Verb RunAs"
exit /b 0