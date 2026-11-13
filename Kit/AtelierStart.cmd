@echo off
setlocal EnableExtensions DisableDelayedExpansion
title Atelier Windows - Installation automatique - Developed by Yassine
color 0B
echo Initialisation WinPE et des pilotes...
wpeinit
set "PROFILE=__PROFILE__"
set /a RETRY=0
:find
set "SOURCE="
set /a COUNT=0
for %%D in (C D E F G H I J K L M N O P Q R S T U V W Y Z) do if exist "%%D:\%PROFILE%\armed.tag" call :candidate "%%D:\%PROFILE%"
if %COUNT% GTR 1 goto ambiguous
if %COUNT% EQU 1 goto verify
set /a RETRY+=1
if %RETRY% GEQ 12 goto missing
echo Attente de la cle USB... tentative %RETRY% / 12
ping -n 6 127.0.0.1 >nul
goto find
:candidate
set /a COUNT+=1
set "SOURCE=%~1"
exit /b
:verify
echo Verification de l identite du disque autorise avant effacement...
"%SOURCE%\DiskGuard.exe" --plan
set "RESULT=%ERRORLEVEL%"
if %RESULT% LSS 10 goto guardfail
if %RESULT% GTR 41 goto guardfail
set /a DISK=%RESULT%-10
if not exist "%SOURCE%\answer-%DISK%.xml" goto missing
if not exist "%SOURCE%\Media\setup.exe" goto missing
echo Mise hors ligne temporaire des autres disques internes...
set "ISOLATING=1"
diskpart /s "%SOURCE%\isolate.txt"
rem DiskPart may return success with partial errors; independently verify offline flags.
"%SOURCE%\DiskGuard.exe" --verify
if not "%ERRORLEVEL%"=="%RESULT%" goto guardfail
rem Consume authorisation BEFORE Setup: this profile cannot silently wipe twice.
del "%SOURCE%\armed.tag"
if exist "%SOURCE%\armed.tag" goto guardfail
echo Disque confirme : %DISK%. Lancement de Windows Setup...
echo Les journaux Windows Setup seront dans Windows\Panther.
"%SOURCE%\Media\setup.exe" /unattend:"%SOURCE%\answer-%DISK%.xml"
echo Windows Setup a rendu le code %ERRORLEVEL%.
echo Si l installation est terminee, elle doit redemarrer automatiquement.
echo Sinon photographier ce message et consulter les journaux Setup.
goto stop
:ambiguous
echo ARRET : plusieurs sources correspondent au profil.
goto stop
:guardfail
echo ARRET AVANT EFFACEMENT : identite, taille, firmware ou isolation des autres disques non validee.
echo Aucun fallback vers disk 0. Photographier ce message.
goto stop
:missing
echo ARRET : USB/profil introuvable ou incomplet. Reconnecter la cle a la VM.
:stop
if defined ISOLATING if exist "%SOURCE%\restore.txt" diskpart /s "%SOURCE%\restore.txt"
echo Aucun autre effacement ne sera lance automatiquement.
echo Fermer cette fenetre pour terminer WinPE, ou Ctrl+C pour le diagnostic.
pause
exit /b
