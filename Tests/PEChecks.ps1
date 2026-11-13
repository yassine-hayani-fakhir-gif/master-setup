$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\Kit\PEHelpers.ps1"
$script:mockDisk=[pscustomobject]@{Number=2;UniqueId='ID-A';SerialNumber='SERIAL';Size=128GB;BusType='NVMe';Path='DEVICE';IsOffline=$false;IsReadOnly=$false;IsBoot=$false;IsSystem=$false;HealthStatus='Healthy'}
function Get-Disk {param($Number,$ErrorAction) $script:mockDisk}
try {
    $expected=Get-PEDiskIdentity $script:mockDisk
    $null=Assert-PETarget $expected 2 @(3)
    $blocked=$false;try {$null=Assert-PETarget $expected 2 @(2)} catch {$blocked=$true}
    if(!$blocked){throw 'Source disk was accepted as target'}
    $script:mockDisk.UniqueId='CHANGED'
    $blocked=$false;try {$null=Assert-PETarget $expected 2 @(3)} catch {$blocked=$true}
    if(!$blocked){throw 'Changed target identity accepted'}
    $script:mockDisk.UniqueId='ID-A';$script:mockDisk.BusType='USB'
    $expected=Get-PEDiskIdentity $script:mockDisk
    $blocked=$false;try {$null=Assert-PETarget $expected 2 @(3)} catch {$blocked=$true}
    if(!$blocked){throw 'USB target accepted'}
    $script:mockDisk.BusType='NVMe';$script:mockDisk.HealthStatus='Warning'
    $expected=Get-PEDiskIdentity $script:mockDisk
    $blocked=$false;try {$null=Assert-PETarget $expected 2 @(3)} catch {$blocked=$true}
    if(!$blocked){throw 'Unhealthy target accepted'}
    Write-Host 'PASS: PE target/source separation, identity change, USB target and unhealthy disk refusal. No disk changes executed.'
} finally {Remove-Item Function:\Get-Disk}

# Non-destructive release gate: partial work must never advertise USB removal.
$fixture=Join-Path $env:TEMP ('master-pe-gate-'+[guid]::NewGuid().ToString('N'))
$os=Join-Path $fixture 'OS';$efi=Join-Path $fixture 'EFI';$kit=Join-Path $os 'SetupKit'
try {
    $required=@((Join-Path $os 'Windows\System32\winload.efi'),
        (Join-Path $os 'Windows\Panther\unattend.xml'),
        (Join-Path $efi 'EFI\Boot\bootx64.efi'),(Join-Path $efi 'EFI\Microsoft\Boot\BCD'))
    $required+=@('Finish.cmd','Finish.ps1','Suivi.ps1','options.json','local-source-relative.txt' | ForEach-Object {Join-Path $kit $_})
    foreach($path in $required){New-Item -ItemType Directory (Split-Path $path -Parent) -Force | Out-Null;Set-Content $path 'fixture'}
    foreach($flags in @(@($false,$true,$true),@($true,$false,$true),@($true,$true,$false))) {
        $blocked=$false
        try {Assert-PEReleaseReady $flags[0] $flags[1] $flags[2] $os $efi $kit} catch {$blocked=$true}
        if(!$blocked){throw 'Incomplete deployment accepted for USB removal.'}
    }
    Assert-PEReleaseReady $true $true $true $os $efi $kit
    foreach($path in $required){
        Remove-Item $path
        $blocked=$false
        try {Assert-PEReleaseReady $true $true $true $os $efi $kit} catch {$blocked=$true}
        if(!$blocked){throw "Missing boot/payload file accepted: $path"}
        Set-Content $path 'fixture'
    }
    Write-Host 'PASS: USB release requires completed copies, applied image, configured boot and all critical files.'
} finally {Remove-Item $fixture -Recurse -Force -ErrorAction SilentlyContinue}
# Source remapping must abort before target erasure.
function Get-PESourceDisk {param($Path) 3}
function Get-Disk {param($Number,$ErrorAction) $script:mockDisk}
try {
    $script:mockDisk.BusType='USB';$script:mockDisk.HealthStatus='Healthy'
    $binding=[pscustomobject]@{Path='Z:\install.wim';Number=3;Identity=(Get-PEDiskIdentity $script:mockDisk)}
    Assert-PESourceBindings @($binding)
    $binding.Number=4
    $blocked=$false;try {Assert-PESourceBindings @($binding)} catch {$blocked=$true}
    if(!$blocked){throw 'Changed source disk number accepted.'}
    $binding.Number=3;$script:mockDisk.UniqueId='REPLACED'
    $blocked=$false;try {Assert-PESourceBindings @($binding)} catch {$blocked=$true}
    if(!$blocked){throw 'Replaced source device accepted.'}
    Write-Host 'PASS: source remapping and replacement abort before disk changes.'
} finally {Remove-Item Function:\Get-Disk;Remove-Item Function:\Get-PESourceDisk}
