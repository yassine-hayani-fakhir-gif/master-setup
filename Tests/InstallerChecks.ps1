$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\Kit\InstallHelpers.ps1"
$folder=Join-Path ([IO.Path]::GetTempPath()) ('master-installer-test-'+[guid]::NewGuid())
[void][IO.Directory]::CreateDirectory($folder)
try {
    $file=Join-Path $folder 'fixture.exe'
    [IO.File]::WriteAllText($file,'fixture-not-executable')
    $hash=(Get-FileHash $file).Hash
    function Get-AuthenticodeSignature {param($LiteralPath) [pscustomobject]@{Status='Valid';SignerCertificate=[pscustomobject]@{Thumbprint='EXPECTED'}}}
    Test-MasterInstaller $file $hash 'EXPECTED'
    $blocked=$false;try {Test-MasterInstaller $file $hash 'OTHER'} catch {$blocked=$true}
    if(!$blocked){throw 'Changed signer accepted'}
    [IO.File]::WriteAllText($file,'tampered')
    $blocked=$false;try {Test-MasterInstaller $file $hash 'EXPECTED'} catch {$blocked=$true}
    if(!$blocked){throw 'Tampered installer accepted'}
    $blocked=$false;try {Test-MasterInstaller $file '' 'EXPECTED'} catch {$blocked=$true}
    if(!$blocked){throw 'Missing identity accepted'}
    Write-Host 'PASS: matching installer, changed signer, tampering, missing identity.'
} finally {Remove-Item Function:\Get-AuthenticodeSignature -ErrorAction SilentlyContinue;Remove-Item $folder -Recurse -Force}

try {
    $script:findCount=0;$script:registrationCount=0
    function Find-MasterWinGet {$script:findCount++;if($script:findCount -ge 3){return 'C:\mock\winget.exe'};return $null}
    function Add-AppxPackage {$script:registrationCount++}
    function Start-Sleep {param($Seconds)}
    $resolved=Resolve-MasterWinGet
    if($resolved -ne 'C:\mock\winget.exe' -or $script:registrationCount -ne 1){throw 'Delayed WinGet registration not handled'}
    function Find-MasterWinGet {return $null}
    $pending=$false
    try {Resolve-MasterWinGet} catch {$pending=$_.Exception.Message -like 'PENDING:*'}
    if(!$pending){throw 'Missing WinGet did not become Pending'}
    Write-Host 'PASS: delayed WinGet registration and missing package.'
} finally {
    Remove-Item Function:\Find-MasterWinGet,Function:\Add-AppxPackage,Function:\Start-Sleep -ErrorAction SilentlyContinue
}
