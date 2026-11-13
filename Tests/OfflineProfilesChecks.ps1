$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\Kit\LocalApps.ps1"
$script:publisher='CN=Brave Software, Inc.';$script:valid='Valid'
function Get-AuthenticodeSignature {param($LiteralPath) [pscustomobject]@{Status=$script:valid;SignerCertificate=[pscustomobject]@{Subject=$script:publisher}}}
try {
    if((Get-LocalAppMode 'C:\BraveBrowserStandaloneSetup.exe') -ne 'BraveOffline'){throw 'Brave profile'}
    if((Get-LocalAppMode 'C:\BraveBrowserStandaloneSilentSetup.exe') -ne 'BraveSilent'){throw 'Silent Brave profile'}
    if((Get-LocalAppMode 'C:\BraveBrowserSetup.exe') -ne 'Interactive'){throw 'Web launcher auto-enabled'}
    $script:publisher='CN=Other'
    if((Get-LocalAppMode 'C:\BraveBrowserStandaloneSetup.exe') -ne 'Interactive'){throw 'Spoofed name accepted'}
    $script:publisher='CN=win.rar GmbH'
    if((Get-LocalAppMode 'C:\winrar-x64-712fr.exe') -ne 'WinRAROffline'){throw 'WinRAR profile'}
    $script:publisher='CN=VideoLAN'
    if((Get-LocalAppMode 'C:\vlc-3.0.24-win64.exe') -ne 'VLCOffline'){throw 'VLC profile'}
    $script:publisher='CN=Other'
    if((Get-LocalAppMode 'C:\vlc-3.0.24-win64.exe') -ne 'Interactive'){throw 'VLC publisher mismatch accepted'}
    $script:valid='NotSigned'
    if((Get-LocalAppMode 'C:\winrar-x64-712fr.exe') -ne 'Interactive'){throw 'Unsigned auto-enabled'}
    if((Get-LocalAppMode 'C:\GoogleChromeStandaloneEnterprise64.msi') -ne 'SilentMSI'){throw 'MSI profile'}
    $state=@{SkipApp=$true}
    if((Wait-LocalInstaller ([pscustomobject]@{HasExited=$false})) -ne 'Skipped'){throw 'Skip ignored'}
    $state=@{SkipApp=$false}
    if((Wait-LocalInstaller ([pscustomobject]@{HasExited=$false}) -TimeoutSeconds 0) -ne 'Timeout'){throw 'Timeout ignored'}
    $proc=[pscustomobject]@{HasExited=$true}
    $proc|Add-Member ScriptMethod WaitForExit {}
    if((Wait-LocalInstaller $proc) -ne 'Exited'){throw 'Exit ignored'}
    Write-Host 'PASS: profiles, publisher mismatch, unsigned fallback, MSI, skip, timeout, exit.'
} finally {Remove-Item Function:\Get-AuthenticodeSignature -ErrorAction SilentlyContinue}
