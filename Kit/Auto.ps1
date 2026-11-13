#Requires -RunAsAdministrator
# Experimental deployment. Source media is never formatted.
$ErrorActionPreference='Stop'
. "$PSScriptRoot\Questions.ps1"
. "$PSScriptRoot\LiveCopy.ps1"
. "$PSScriptRoot\ReuseMedia.ps1"
& "$PSScriptRoot\Validate.ps1"
function Pick($title,$filter) { Get-AtelierImage $title $filter }
function Bcd([string[]]$Options) {
    $out=& "$env:SystemRoot\System32\bcdedit.exe" @Options 2>&1
    if ($LASTEXITCODE -ne 0) { throw ($out -join ' ') }
}
function Dism([string[]]$Options) {
    & "$env:SystemRoot\System32\dism.exe" @Options
    if ($LASTEXITCODE -ne 0) { throw "DISM failed: $LASTEXITCODE. See C:\Windows\Logs\DISM\dism.log" }
}
if (![Environment]::Is64BitProcess) { throw 'Run the x64 version.' }
$cs=Get-CimInstance Win32_ComputerSystem -OperationTimeoutSec 10
$isVM=($cs.Manufacturer -match 'VMware|Microsoft Corporation|innotek|QEMU' -and $cs.Model -match 'VMware|Virtual|KVM')
if($isVM){Write-Warning 'VM: host free space cannot be checked from this guest. Check the host disk containing VMDK files and snapshots before continuing.'}
else {Write-Warning 'Physical PC: preview release; an external backup is required. The confirmed disk will be completely erased.'}

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class AtelierFirmware {
 [DllImport("kernel32.dll", SetLastError=true)] public static extern bool GetFirmwareType(out uint type);
}
'@
[uint32]$fw=0
if (![AtelierFirmware]::GetFirmwareType([ref]$fw) -or $fw -notin 1,2) { throw 'Could not determine BIOS/UEFI mode.' }
$firmware=if ($fw -eq 2) {'UEFI'} else {'BIOS'}
$state.Firmware=$firmware
Write-Host "Machine : $($cs.Model) | Firmware: $firmware | RAM : $([math]::Round($cs.TotalPhysicalMemory/1GB,1)) GiB"
# Show every disk before selecting media or collecting account information.
$disks=@(Get-Disk | Sort-Object Number)
if (@($disks | Where-Object { $_.BusType -ne 'USB' -and $_.Number -ge 32 }).Count) { throw 'Disk numbering is outside the supported range.' }
Write-Host 'DETECTED DISKS (numbers assigned by Windows):'
foreach ($d in $disks) {
    $role=if($d.BusType -eq 'USB'){'USB SOURCE - PROTECTED'}elseif($d.IsBoot){'Current Windows'}else{'Internal disk'}
    Write-Host ("{0} : {1} | {2:N2} GiB | {3}/{4} | serial: {5} | {6}" -f $d.Number,$d.FriendlyName,($d.Size/1GB),$d.BusType,$d.PartitionStyle,$d.SerialNumber,$role)
}
while ($true) {
    $chosen=(Read-Host 'INTERNAL disk number to erase and use for Windows (n = cancel)').Trim()
    if($chosen -ieq 'n'){$state.Cancelled=$true;return}
    $match=@($disks | Where-Object { [string]$_.Number -eq $chosen })
    if($match.Count -ne 1){Write-Host 'Unknown number. Correct only this selection.';continue}
    $target=$match[0]
    if($target.BusType -eq 'USB'){Write-Host 'The USB is protected: select an internal disk.';continue}
    if($target.IsOffline -or $target.IsReadOnly -or $target.Size -lt 32GB -or $target.Number -ge 32){Write-Host 'Disk not eligible: must be online, writable, >=32 GiB, number <32.';continue}
    if(($fw -eq 2 -and $target.PartitionStyle -ne 'GPT') -or ($fw -eq 1 -and $target.PartitionStyle -ne 'MBR')){Write-Host "Disk not eligible for ${firmware}: choose an existing GPT disk for UEFI or MBR disk for BIOS. RAW disks are not initialized automatically.";continue}
    if($fw -eq 1 -and (!$target.IsBoot -or !$target.IsSystem)){Write-Host 'In BIOS mode, select the current Windows disk to restart without changing firmware settings.';continue}
    $state.TargetDisk="Disk $($target.Number) | $($target.FriendlyName) | serial $($target.SerialNumber)"
    break
}
if (@($disks | Where-Object { $_.BusType -ne 'USB' -and $_.Number -ne $target.Number -and $_.PartitionStyle -notin 'GPT','MBR' }).Count) { throw 'Another internal disk is RAW: disconnect it before this test so other disks can be restored reliably.' }
Write-Host "Selected disk: $($target.Number) - $($target.FriendlyName). Other internal disks will be taken offline in WinPE during installation."
$bitlocker=Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop
if ($bitlocker.VolumeStatus -ne 'FullyDecrypted') { throw 'Stopped: system drive is encrypted. Use an unencrypted test machine; protection is not suspended automatically.' }
$targetVolumes=@(Get-Partition -DiskNumber $target.Number | Where-Object DriveLetter | Get-Volume)
foreach($volume in $targetVolumes){
    $encryption=Get-BitLockerVolume -MountPoint ($volume.DriveLetter+':') -ErrorAction Stop
    if($encryption.VolumeStatus -ne 'FullyDecrypted'){throw 'Target contains an encrypted volume. Preparation stopped without changing protection.'}
}
if ($fw -eq 2) { Write-Host "Secure Boot : $(Confirm-SecureBootUEFI)" }
while ($true) {
    $win=Pick 'Choose Windows x64 ISO on USB (NTFS or exFAT)' 'Windows ISO|*.iso'
    if (!$win) { $state.Cancelled=$true;return }
    $root=[IO.Path]::GetPathRoot($win)
    $letter=$root.Substring(0,1)
    $usb=Get-Partition -DriveLetter $letter | Get-Disk
    $vol=Get-Volume -DriveLetter $letter
    if ($usb.BusType -ne 'USB' -or $usb.IsBoot -or $usb.IsSystem -or $vol.FileSystem -notin 'NTFS','exFAT') { Write-Warning 'Choose an ISO on the USB connected to this machine (NTFS/exFAT).';continue }
    break
}
while ($true) {
    if($state.Options -and !$state.Options.Office){$office=$null;break}
    $office=Pick 'Office on the same USB (Cancel = skip Office)' 'Office ISO or IMG|*.iso;*.img'
    if ($office -and ($office -eq $win -or [IO.Path]::GetPathRoot($office) -ne $root)) { Write-Warning 'Choose a separate Office image on the same USB.';continue };break
}
$token=[guid]::NewGuid().ToString('N')
$relative="AtelierAuto\$token"
$stage=Join-Path $root $relative
$media=Join-Path $stage 'Media'
$local=Join-Path ($env:SystemDrive+'\') ('AtelierPE-'+$token)
$mount=Join-Path $local 'Mount'
$attached=(Get-DiskImage -ImagePath $win).Attached
$entries=@();$armed=$false;$wimMounted=$false
try {
    Write-Host '[1/7] Reading the ISO and Windows editions...'
    $image=Mount-DiskImage -ImagePath $win -PassThru
    $src=($image | Get-Volume).DriveLetter+':\'
    foreach ($file in 'setup.exe','sources\boot.wim','boot\boot.sdi') { if (!(Test-Path ($src+$file))) { throw "Incomplete ISO: $file" } }
    if (Test-Path ($src+'Autounattend.xml')) { throw 'Use a standard Microsoft ISO without a bundled answer file.' }
    if (Test-Path -LiteralPath ($src+'sources\$OEM$')) { throw 'Custom Windows ISO is not supported.' }
    $install=if (Test-Path ($src+'sources\install.wim')) {$src+'sources\install.wim'} elseif (Test-Path ($src+'sources\install.esd')) {$src+'sources\install.esd'} else { throw 'install.wim/install.esd not found.' }
    $editions=@(Get-WindowsImage -ImagePath $install)
    foreach ($edition in $editions) { Write-Host "$($edition.ImageIndex) : $($edition.ImageName)" }
    do { $ix=Read-Host 'Edition number to install';$selected=@($editions | Where-Object { [string]$_.ImageIndex -eq $ix.Trim() });if($selected.Count -ne 1){Write-Host 'Choose a number from the displayed list.'} } until ($selected.Count -eq 1)
    $detail=Get-WindowsImage -ImagePath $install -Index $selected[0].ImageIndex
    if ([string]$detail.Architecture -notin '9','x64','amd64') { throw 'x64 image required.' }
    $language=[string]@($detail.Languages)[0]
    if ($language -notmatch '^[a-zA-Z]{2,3}-[a-zA-Z0-9-]+$') { throw 'Could not determine image language.' }
    if ($selected[0].ImageName -match 'Windows 11') {
        $missing=@()
        if($fw -ne 2){$missing+='UEFI boot required'}
        if($cs.TotalPhysicalMemory -lt 4GB){$missing+=('RAM : {0:N1} / 4 GiB required' -f ($cs.TotalPhysicalMemory/1GB))}
        if($target.Size -lt 64GB){$missing+=('Disk: {0:N1} / 64 GiB required' -f ($target.Size/1GB))}
        if($missing.Count){throw ('Windows 11 : '+($missing -join ' ; ')+'. Correct the settings and retry.')}
    }
    if ($selected[0].ImageName -match 'Windows 11') { $tpm=Get-Tpm;if(!$tpm.TpmPresent -or !$tpm.TpmReady){throw 'Windows 11: a present and ready TPM is required.'} }
    $keyboards=@(
        @{Name='French (France) - AZERTY';Code='040c:0000040c'},
        @{Name='English (United States) - QWERTY US';Code='0409:00000409'},
        @{Name='English (United Kingdom) - QWERTY UK';Code='0809:00000809'},
        @{Name='Arabic (Morocco) - Arabic 102 AZERTY';Code='1801:00020401'},
        @{Name='Arabic - Arabic 101';Code='0401:00000401'},
        @{Name='French (Belgium) - AZERTY';Code='080c:0000080c'},
        @{Name='German (Germany) - QWERTZ';Code='0407:00000407'}
    )
    for($k=0;$k -lt $keyboards.Count;$k++){Write-Host ("{0} : {1}" -f ($k+1),$keyboards[$k].Name)}
    do {$keyboardChoice=(Read-Host 'Keyboard: choose a number from 1 to 7').Trim()} until ($keyboardChoice -match '^[1-7]$')
    $layout=$keyboards[[int]$keyboardChoice-1].Code
    Write-Host "Selected keyboard: $($keyboards[[int]$keyboardChoice-1].Name)"
    . "$PSScriptRoot\InstallKey.ps1"
    $setupKey=Get-MediaInstallKey -MediaRoot $src -EditionId ([string]$detail.EditionId)
    Write-Host 'Setup key selected for this edition. No activation commands will be run.'
    $activation='Licence'
    Write-Host 'Windows and Office licensing is handled separately. No activation commands are run by Master Setup.'
    $files=@(Get-ChildItem -LiteralPath $src -File -Recurse -Force)
    $bytes=($files|Measure-Object Length -Sum).Sum
    $reuseCandidates=@()
    if($vol.FileSystem -eq 'NTFS') {
        $reuseCandidates=@(Get-ChildItem (Join-Path $root 'AtelierAuto') -Directory -ErrorAction SilentlyContinue | Where-Object { Test-Path (Join-Path $_.FullName 'Media\setup.exe') })
    }
    $localBytes=[long]0
    if($state.Options -and $state.Options.AppMethod -eq 'Local'){
        foreach($app in @($state.Options.LocalApps)){$localBytes+=(Get-Item -LiteralPath $app.Path -ErrorAction Stop).Length}
    }
    if($vol.SizeRemaining -lt ($localBytes+512MB)){throw 'USB: insufficient space for the selected installers.'}
    if ($vol.SizeRemaining -lt 512MB -or ($reuseCandidates.Count -eq 0 -and $vol.SizeRemaining -lt ($bytes+$localBytes+512MB))) { throw 'USB: insufficient space. Existing profiles may allow verified file reuse.' }
    if ((Get-PSDrive ($env:SystemDrive.TrimEnd(':'))).Free -lt ((Get-Item ($src+'sources\boot.wim')).Length*2+4GB)) { throw 'Windows disk: insufficient temporary space for WinPE.' }
    [void][IO.Directory]::CreateDirectory($media)
    [void][IO.Directory]::CreateDirectory($mount)
    & "$PSScriptRoot\Prepare.ps1" -MediaRoot $media -Activation $activation -AutoLogon
    $sizeGiB=[math]::Round($target.Size/1GB,2)
    Write-Host "TARGET TO ERASE: disk $($target.Number) | $($target.FriendlyName) | $sizeGiB GiB | serial $($target.SerialNumber)"
    Write-Host "ALL partitions and data on THIS disk will be deleted. USB source preserved: $root"
    Write-Host "Edition : $($selected[0].ImageName) | Firmware: $firmware | Account and password are stored in the USB profile (recoverable)."
    $appSummary='None'
    if($state.Options){
        switch($state.Options.AppMethod){
            'Local' {$appSummary=(@($state.Options.LocalApps)|ForEach-Object {$_.Name+' ['+$_.Mode+']'}) -join ', '}
            'Ninite' {$appSummary='Ninite: '+$state.Options.NinitePath}
            'WinGet' {$appSummary=@($state.Options.Apps) -join ', '}
        }
    }
    if(!$appSummary){$appSummary='None'}
    $officeSummary=if($office){$office}else{'Not selected'}
    $review=@"
REVIEW YOUR INSTALLATION

Computer: $($cs.Manufacturer) $($cs.Model)
Windows ISO: $win
Edition: $($selected[0].ImageName) (index $($selected[0].ImageIndex))
Image language: $language
Keyboard: $($keyboards[[int]$keyboardChoice-1].Name)
Firmware: $firmware

DISK TO ERASE: $($target.Number) | $($target.FriendlyName) | $sizeGiB GiB
Disk serial: $($target.SerialNumber)
USB source (preserved): $root

Office: $officeSummary
Applications: $appSummary
Administrator: $($state.AccountReview.Name)
Computer name: $($state.PlannedName)
Password: $($state.AccountReview.Password)

ALL partitions and data on the selected internal disk will be deleted.
Continue only after checking your backup and these selections.
"@
    if (!(Read-Yes 'Erase the selected disk and restart automatically?' -Summary $review)) { return }
    Write-Host '[2/7] Copying Windows files to USB (original ISO files unchanged)...'
    Copy-ReusableMedia -Files $files -SourceRoot $src -TargetRoot $media -UsbRoot $root -FileSystem $vol.FileSystem
    Write-Host '[3/7] Preparing the post-installation kit...'
    $kit=Join-Path $stage 'Kit'
    Copy-Item -LiteralPath $PSScriptRoot -Destination $kit -Recurse
    Set-Content (Join-Path $kit 'ventoy-profile.tag') $token
    Set-Content (Join-Path $kit 'activation.txt') $activation
    if ($office) { Set-Content (Join-Path $kit 'office-relative.txt') ($office.Substring($root.Length)) }
    $payload=Join-Path $media 'sources\$OEM$\$1\SetupKit'
    if($state.Options -and $state.Options.AppMethod -eq 'Ninite'){
        $niniteSource=$state.Options.NinitePath
        $sig=Get-AuthenticodeSignature -LiteralPath $niniteSource
        if($sig.Status -ne 'Valid'){throw 'Invalid Ninite signature. Preparation stopped.'}
        $niniteHash=(Get-FileHash -LiteralPath $niniteSource -Algorithm SHA256).Hash
        $appsFolder=Join-Path $kit 'Apps'
        [void][IO.Directory]::CreateDirectory($appsFolder)
        $niniteCopy=Join-Path $appsFolder 'Ninite.exe'
        Copy-AtelierFile $niniteSource $niniteCopy
        if((Get-FileHash -LiteralPath $niniteCopy -Algorithm SHA256).Hash -ne $niniteHash){throw 'Ninite copy verification failed.'}
        $state.Options.NiniteHash=$niniteHash
        $state.Options.NiniteSigner=$sig.SignerCertificate.Thumbprint
        $state.Options.NinitePath='Apps\Ninite.exe'
    }
    if($state.Options -and $state.Options.AppMethod -eq 'Local'){
        . "$PSScriptRoot\LocalApps.ps1"
        $prepared=New-Object 'System.Collections.Generic.List[object]'
        $localIndex=0
        foreach($app in @($state.Options.LocalApps)){
            Test-LocalAppFile $app $app.Path
            $localIndex++
            $relativeInstaller='Apps\Local\'+$localIndex.ToString('D3')+'\'+[IO.Path]::GetFileName($app.Path)
            $destination=Join-Path $kit $relativeInstaller
            [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))
            Copy-AtelierFile $app.Path $destination
            Test-LocalAppFile $app $destination
            $prepared.Add([pscustomobject]@{Name=$app.Name;Path=$relativeInstaller;Hash=$app.Hash;Signer=$app.Signer;Unsigned=$app.Unsigned;Mode=$app.Mode;Arguments=[string]$app.Arguments;ManualApproved=[bool]$app.ManualApproved})
        }
        $state.Options.LocalApps=$prepared.ToArray()
    }
    if($state.Options){
        $settings=$state.Options | ConvertTo-Json -Depth 4
        Set-Content -LiteralPath (Join-Path $kit 'options.json') -Value $settings -Encoding UTF8
        Set-Content -LiteralPath (Join-Path $payload 'options.json') -Value $settings -Encoding UTF8
    }
    Set-Content (Join-Path $payload 'profile-version.txt') '0.17'
    Set-Content (Join-Path $payload 'auto-source-relative.txt') ($relative+'\Kit')
    $restore=@(Get-Disk | Where-Object { $_.BusType -ne 'USB' -and $_.Number -ne $target.Number -and !$_.IsOffline } | ForEach-Object {
        if($_.PartitionStyle -notin 'GPT','MBR'){throw 'Another disk is RAW: disconnect it before this test.'}
        @{Style=[string]$_.PartitionStyle;Guid=[string]$_.Guid;Signature=[uint32]$_.Signature;Size=[string]$_.Size}
    })
    ConvertTo-Json -InputObject $restore | Set-Content (Join-Path $payload 'restore-disks.json') -Encoding UTF8
    Copy-Item "$PSScriptRoot\DiskGuard.exe" $stage
    $identity=if ($fw -eq 2) { ([guid]$target.Guid).ToByteArray() } else { [BitConverter]::GetBytes([uint32]$target.Signature) }
    $hex=([BitConverter]::ToString($identity)).Replace('-','')
    $style=if ($fw -eq 2) {1} else {0}
    @('[Target]',"Firmware=$fw","Style=$style","Size=$($target.Size)","Identity=$hex") | Set-Content (Join-Path $stage 'target.ini') -Encoding Unicode
    & (Join-Path $stage 'DiskGuard.exe')
    if ($LASTEXITCODE -ne (10+$target.Number)) { throw 'Independent disk guard rejected the target. No boot scheduled.' }
    . "$PSScriptRoot\AutoAnswer.ps1"
    New-AutoAnswers -BaseAnswer (Join-Path $media 'Autounattend.xml') -Destination $stage -Firmware $fw -Index $selected[0].ImageIndex -Language $language -Keyboard $layout -SetupKey $setupKey
    # Never expose an implicit destructive Autounattend.xml to another boot mode.
    Remove-Item (Join-Path $media 'Autounattend.xml')
    Write-Host '[4/7] Creating WinPE from this ISO...'
    Copy-AtelierFile ($src+'sources\boot.wim') (Join-Path $local 'boot.wim')
    Copy-AtelierFile ($src+'boot\boot.sdi') (Join-Path $local 'boot.sdi')
    $bootImages=@(Get-WindowsImage -ImagePath (Join-Path $local 'boot.wim'))
    if (!($bootImages | Where-Object ImageIndex -eq 2)) { throw 'A standard Windows ISO with boot.wim index 2 is required.' }
    Dism @('/Mount-Image',('/ImageFile:'+(Join-Path $local 'boot.wim')),'/Index:2',('/MountDir:'+$mount))
    $wimMounted=$true
    $shell=@('[LaunchApps]','%SYSTEMROOT%\System32\cmd.exe, /d /c X:\Windows\System32\AtelierStart.cmd')
    $shell | Set-Content (Join-Path $mount 'Windows\System32\winpeshl.ini') -Encoding ASCII
    $startup=(Get-Content "$PSScriptRoot\AtelierStart.cmd" -Raw).Replace('__PROFILE__',$relative)
    [IO.File]::WriteAllText((Join-Path $mount 'Windows\System32\AtelierStart.cmd'),$startup,[Text.Encoding]::ASCII)
    $peDrivers=Join-Path $PSScriptRoot 'Drivers\WinPE'
    if(Test-Path $peDrivers){
        $infs=@(Get-ChildItem -LiteralPath $peDrivers -Filter *.inf -Recurse -File)
        if($infs.Count){
            Write-Host 'Adding supplied Drivers/WinPE drivers (DISM requires valid signatures).'
            Dism @(('/Image:'+$mount),'/Add-Driver',('/Driver:'+$peDrivers),'/Recurse')
        }
    }
    Write-Host '[5/7] Saving WinPE (DISM may take several minutes)...'
    Dism @('/Unmount-Image',('/MountDir:'+$mount),'/Commit')
    $wimMounted=$false
    Write-Host '[6/7] Creating a temporary Windows Boot Manager entry...'
    $rd='{'+[guid]::NewGuid().ToString()+'}';$pe='{'+[guid]::NewGuid().ToString()+'}'
    $existingBoot=(& bcdedit.exe /enum '{bootmgr}' 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0) { throw 'Could not read BCD.' }
    if ($existingBoot -match '(?im)^bootsequence\s') { throw 'A one-time boot sequence already exists. Finish that operation before preparing Master Setup.' }
    Bcd @('/export',(Join-Path $stage 'BCD-backup'))
    Bcd @('/create',$rd,'/d','Atelier RAM disk','/device');$entries+=$rd
    Bcd @('/set',$rd,'ramdisksdidevice',('partition='+$env:SystemDrive))
    $localRelative='\'+[IO.Path]::GetFileName($local)
    Bcd @('/set',$rd,'ramdisksdipath',($localRelative+'\boot.sdi'))
    Bcd @('/create',$pe,'/d','Master Setup automatic installation','/application','osloader');$entries+=$pe
    $device="ramdisk=[$env:SystemDrive]$localRelative\boot.wim,$rd"
    foreach ($key in 'device','osdevice') { Bcd @('/set',$pe,$key,$device) }
    $loader=if($fw -eq 2){'\Windows\System32\Boot\winload.efi'}else{'\Windows\System32\Boot\winload.exe'}
    Bcd @('/set',$pe,'path',$loader)
    Bcd @('/set',$pe,'systemroot','\Windows')
    Bcd @('/set',$pe,'winpe','Yes');Bcd @('/set',$pe,'detecthal','Yes')
    @("bcdedit /delete $pe","bcdedit /delete $rd","Temporary folder: $local","USB profile: $stage") | Set-Content (Join-Path $stage 'Annulation.txt')
    # Repeat the read-only guard immediately before arming the one-time boot.
    & (Join-Path $stage 'DiskGuard.exe')
    if ($LASTEXITCODE -ne (10+$target.Number)) { throw 'Disk identity changed during preparation. Stopped.' }
    Set-Content (Join-Path $stage 'armed.tag') $token
    Bcd @('/bootsequence',$pe,'/addfirst')
    Write-Host '[7/7] Automatic restart in 15 seconds. Keep the USB connected TO THIS MACHINE.'
    Write-Host 'WinPE checks disk identity before installation. Ambiguous targets are blocked before erasure.'
    & shutdown.exe /r /t 15
    if ($LASTEXITCODE -ne 0) { throw 'Restart request failed.' }
    $armed=$true
} finally {
    if ($wimMounted) { & dism.exe /Unmount-Image "/MountDir:$mount" /Discard | Out-Host }
    if (!$armed) {
        [array]::Reverse($entries)
        foreach ($entry in $entries) { & bcdedit.exe /delete $entry | Out-Null }
        if (!(Test-Path (Join-Path $mount 'Windows'))) {
            if (Test-Path $local) { Remove-Item -LiteralPath $local -Recurse -Force -ErrorAction Continue }
        }
        if (Test-Path (Join-Path $stage 'armed.tag')) { Remove-Item (Join-Path $stage 'armed.tag') }
        if (Test-Path $stage) { Write-Warning "Incomplete profile retained for diagnosis: $stage. It contains account information. Delete after diagnosis." }
    }
    if (!$attached -and (Get-DiskImage -ImagePath $win).Attached) { Dismount-DiskImage -ImagePath $win | Out-Null }
}
