#Requires -RunAsAdministrator
$ErrorActionPreference='Stop'
. "$PSScriptRoot\LocalApps.ps1"
if(!$state -or !$state.LocalApps){throw 'No apps selected.'}
$logDir=Join-Path $env:ProgramData 'YHF-Setup'
$success=Invoke-LocalApps -Apps @($state.LocalApps) -LogDir $logDir
if(!$success){Write-Warning 'Some apps need attention. Run Install apps on this PC to retry; successful packages are skipped.'}
