@echo off
powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy RemoteSigned -File "%~dp0App.ps1"
if errorlevel 1 (
 echo.
 echo Master Setup could not start. Read the error above and README.md.
 echo Do not disable Defender or add exclusions.
 pause
)
