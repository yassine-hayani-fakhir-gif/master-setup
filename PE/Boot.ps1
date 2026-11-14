#Requires -RunAsAdministrator
$ErrorActionPreference='Stop'
try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    [Windows.Forms.Application]::EnableVisualStyles()
    $kit=Join-Path $PSScriptRoot 'Kit'
    . "$kit\Language.ps1"
    . "$kit\Welcome.ps1"
    if(!(Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Control\MiniNT')){throw 'This entry point requires WinPE.'}
    $route=Show-MasterWelcome -IsWinPE $true
    if($route -eq 'DeployPE'){& "$kit\Suivi.ps1" -Task DeployPE}
} catch {
    Write-Error $_ -ErrorAction Continue
    [void][Windows.Forms.MessageBox]::Show($_.Exception.Message,'Master Setup - Boot error')
    exit 1
}
