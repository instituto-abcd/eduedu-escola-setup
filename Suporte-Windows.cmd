@echo off
rem Gera o log de suporte do EduEdu+ em logs\log_<data>.txt
rem Roda como administrador, igual ao instalador, para ter o mesmo acesso ao Docker
powershell -Command "Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0installation-scripts\support-windows.ps1\"' -Verb RunAs"
exit /b 0
