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
