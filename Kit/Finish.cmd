@echo off
powershell.exe -STA -NoProfile -WindowStyle Hidden -ExecutionPolicy RemoteSigned -File "%~dp0Suivi.ps1" -Task Finish
