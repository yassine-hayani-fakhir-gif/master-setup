#Requires -RunAsAdministrator
$ErrorActionPreference='Stop'
. "$PSScriptRoot\PEHelpers.ps1"
. "$PSScriptRoot\LiveCopy.ps1"
. "$PSScriptRoot\LocalApps.ps1"
Assert-PEEnvironment
if([IO.Path]::GetPathRoot($PSScriptRoot) -ine 'X:\'){throw 'Boot the Master Setup WinPE ISO. Runtime must reside on the X: RAM drive.'}
$copiesVerified=$false;$imageApplied=$false;$bootConfigured=$false
$state.UsbReady=$false
$state.Firmware='UEFI'
Write-Warning 'BOOT PREVIEW: clean installation only. Back up data first. The selected disk is erased before local staging. This does not recover passwords or repair the old Windows installation.'
if($state.Options.AppMethod -notin 'Local','None'){throw 'Boot mode accepts Local installers or No applications. Full offline packages are required.'}
$source=Get-AtelierImage 'Windows: select install.wim or install.esd prepared from your ISO' 'Windows image|*.wim;*.esd'
if(!$source){$state.Cancelled=$true;return}
$sources=New-Object 'System.Collections.Generic.List[int]'
$sources.Add((Get-PESourceDisk $source))
$images=@(Get-WindowsImage -ImagePath $source -ErrorAction Stop)
foreach($image in $images){Write-Host ("$($image.ImageIndex) : $($image.ImageName)")}
do {
    $choice=(Read-Host 'Windows edition number (n = cancel)').Trim()
    if($choice -ieq 'n'){$state.Cancelled=$true;return}
    $chosen=@($images | Where-Object {[string]$_.ImageIndex -eq $choice})
} until($chosen.Count -eq 1)
$details=Get-WindowsImage -ImagePath $source -Index $chosen[0].ImageIndex
if([string]$details.Architecture -notin '9','amd64','x64'){throw 'Windows x64 image required.'}
$keyboardChoices=@('040c:0000040c','0409:00000409','0809:00000809','1801:00020401','0401:00000401','080c:0000080c','0407:00000407')
$keyboardNames=@('Francais France AZERTY','English US QWERTY','English UK QWERTY','Arabe Maroc 102 AZERTY','Arabe 101','Francais Belgique AZERTY','Deutsch QWERTZ')
for($i=0;$i -lt 7;$i++){Write-Host (([string]($i+1))+' : '+$keyboardNames[$i])}
do {$key=Read-Host 'Keyboard: choose 1 to 7'} until($key -match '^[1-7]$')
$keyboard=$keyboardChoices[[int]$key-1]
$office=$null
if($state.Options.Office){$office=Get-AtelierImage 'Office ISO / IMG (Cancel = skip)' 'Office|*.iso;*.img';if($office){$sources.Add((Get-PESourceDisk $office))}}
$bytes=(Get-Item -LiteralPath $source).Length
if($office){$bytes+=(Get-Item -LiteralPath $office).Length}
$apps=@()
if($state.Options.AppMethod -eq 'Local'){
    $apps=@($state.Options.LocalApps)
    foreach($app in $apps){$sources.Add((Get-PESourceDisk $app.Path));Test-LocalAppFile $app $app.Path;$bytes+=(Get-Item -LiteralPath $app.Path).Length}
}
$disks=@(Get-Disk | Sort-Object Number)
foreach($disk in $disks){Write-Host ("{0} : {1} | {2:N1} GiB | {3} | serie {4} | {5}" -f $disk.Number,$disk.FriendlyName,($disk.Size/1GB),$disk.BusType,$disk.SerialNumber,$disk.HealthStatus)}
while($true){
    $choice=Read-Host 'INTERNAL disk number to ERASE (n = cancel)'
    if($choice -ieq 'n'){$state.Cancelled=$true;return}
    $diskMatches=@($disks|Where-Object {[string]$_.Number -eq $choice})
    if($diskMatches.Count -ne 1){Write-Host 'Unknown number.';continue}
    $target=$diskMatches[0]
    try {$identity=Get-PEDiskIdentity $target;$target=Assert-PETarget $identity $target.Number $sources.ToArray()} catch {Write-Warning $_.Exception.Message;continue}
    if($target.Size -lt [math]::Max(64GB,([long]$details.ImageSize+$bytes+20GB))){Write-Warning 'Not enough space for Windows, local packages and a 20 GiB reserve.';continue}
    $state.TargetDisk="Disk $($target.Number) | $($target.FriendlyName) | $([math]::Round($target.Size/1GB,1)) GiB | serial $($target.SerialNumber)"
    break
}
$bindings=@(@($source)+@($office)+@($apps | ForEach-Object {$_.Path}) | Where-Object {$_} | ForEach-Object {
    $number=Get-PESourceDisk $_
    [pscustomobject]@{Path=$_;Number=$number;Identity=(Get-PEDiskIdentity (Get-Disk -Number $number))}
})
$token=[guid]::NewGuid().ToString('N')
$work=Join-Path $env:TEMP ('MasterPE-'+$token)
[void][IO.Directory]::CreateDirectory($work)
& "$PSScriptRoot\Prepare.ps1" -MediaRoot $work -AutoLogon
[xml]$answer=Get-Content -LiteralPath (Join-Path $work 'Autounattend.xml') -Raw
$ns=New-Object Xml.XmlNamespaceManager($answer.NameTable);$ns.AddNamespace('u','urn:schemas-microsoft-com:unattend')
$state.PlannedName=$answer.SelectSingleNode('//u:ComputerName',$ns).InnerText
$language=if($details.DefaultLanguage){[string]$details.DefaultLanguage}else{'en-US'}
$intl=$answer.CreateElement('component','urn:schemas-microsoft-com:unattend')
$intl.SetAttribute('name','Microsoft-Windows-International-Core');$intl.SetAttribute('processorArchitecture','amd64');$intl.SetAttribute('publicKeyToken','31bf3856ad364e35');$intl.SetAttribute('language','neutral');$intl.SetAttribute('versionScope','nonSxS')
foreach($pair in @(@('InputLocale',$keyboard),@('SystemLocale',$language),@('UILanguage',$language),@('UserLocale',$language))){$node=$answer.CreateElement($pair[0],'urn:schemas-microsoft-com:unattend');$node.InnerText=$pair[1];[void]$intl.AppendChild($node)}
[void]$answer.SelectSingleNode('//u:settings[@pass="oobeSystem"]',$ns).AppendChild($intl)
$answer.Save((Join-Path $work 'Autounattend.xml'))
$review=@(
    'BOOT PREVIEW - CLEAN INSTALLATION',
    ('Computer: '+$state.Computer),
    ('TARGET TO ERASE: '+$state.TargetDisk),
    ('Windows image: '+$source),
    ('Edition: '+$details.ImageName+' | Index: '+$chosen[0].ImageIndex),
    ('Keyboard: '+$keyboardNames[[int]$key-1]),
    ('New computer name: '+$state.PlannedName),
    ('Account: '+$state.AccountReview.Name+' | '+$state.AccountReview.Password),
    ('Office: '+$(if($office){$office}else{'Not selected'})),
    ('Applications: '+$(if($apps.Count){($apps.Name -join ', ')}else{'None'})),
    'ALL partitions on the selected disk will be erased. Existing files and accounts will be lost.',
    'Confirm only with authorization, a completed backup and an appropriate Windows license.',
    'Keep USB connected until the green release notice after local boot preparation.'
) -join [Environment]::NewLine
if(!(Get-AtelierConfirmation 'Erase selected disk and install Windows?' $review)){$state.Cancelled=$true;return}
# Re-identify every source as well as the target immediately before erasure.
Assert-PESourceBindings $bindings
$target=Assert-PETarget $identity $target.Number $sources.ToArray()
$free=@(68..87 | ForEach-Object {[char]$_} | Where-Object {!(Test-Path ([string]$_+':\')) -and !@(Get-Volume -DriveLetter $_ -ErrorAction SilentlyContinue).Count})
if($free.Count -lt 2){throw 'Two unused drive letters required.'}
$osLetter=[string]$free[0];$efiLetter=[string]$free[1]
$osRoot=$osLetter+':\';$efiRoot=$efiLetter+':\'
Write-Host '--- Preparing confirmed target disk ---'
if($target.PartitionStyle -ne 'RAW'){Clear-Disk -Number $target.Number -RemoveData -RemoveOEM -Confirm:$false -ErrorAction Stop}
Initialize-Disk -Number $target.Number -PartitionStyle GPT -ErrorAction Stop | Out-Null
$efi=New-Partition -DiskNumber $target.Number -Size 260MB -GptType '{C12A7328-F81F-11D2-BA4B-00A0C93EC93B}' -DriveLetter $efiLetter
$efi|Format-Volume -FileSystem FAT32 -NewFileSystemLabel 'System' -Confirm:$false -ErrorAction Stop | Out-Null
New-Partition -DiskNumber $target.Number -Size 16MB -GptType '{E3C9E316-0B5C-4DB8-817D-F92DF00215AE}' | Out-Null
$os=New-Partition -DiskNumber $target.Number -UseMaximumSize -DriveLetter $osLetter
$os|Format-Volume -FileSystem NTFS -NewFileSystemLabel 'Windows' -Confirm:$false -ErrorAction Stop | Out-Null
$stageName='MasterStage-'+$token
$stage=Join-Path $osRoot $stageName
[void][IO.Directory]::CreateDirectory($stage)
Write-Host '--- Copying and verifying local installation files ---'
$state.LocalLog=Join-Path $stage 'deployment.log'
$imageCopy=Join-Path $stage ('install'+[IO.Path]::GetExtension($source))
Copy-PEVerified $source $imageCopy
$kit=Join-Path $stage 'Kit'
[void][IO.Directory]::CreateDirectory($kit)
$settings=@{AppMethod=$state.Options.AppMethod;Apps=@();LocalApps=@();Office=[bool]$office}
if($office){
    $officeDest=Join-Path $kit ('Office\Office'+[IO.Path]::GetExtension($office))
    Copy-PEVerified $office $officeDest
    Set-Content -LiteralPath (Join-Path $kit 'office-relative.txt') -Value ($stageName+'\Kit\Office\'+[IO.Path]::GetFileName($officeDest))
}
$prepared=New-Object 'System.Collections.Generic.List[object]';$i=0
foreach($app in $apps){
    $i++;$relative='Apps\'+$i+'\'+[IO.Path]::GetFileName($app.Path)
    Copy-PEVerified $app.Path (Join-Path $kit $relative)
    Test-LocalAppFile $app (Join-Path $kit $relative)
    $prepared.Add([pscustomobject]@{Name=$app.Name;Path=$relative;Hash=$app.Hash;Signer=$app.Signer;Unsigned=$app.Unsigned;Mode=$app.Mode;Arguments=[string]$app.Arguments;ManualApproved=[bool]$app.ManualApproved})
}
$settings.LocalApps=$prepared.ToArray()
Set-Content -LiteralPath (Join-Path $kit 'ventoy-profile.tag') -Value $token
$installedKit=Join-Path $osRoot 'SetupKit'
# Finalization runtime is copied after the image is applied, to prevent image collisions.
Copy-PEVerified (Join-Path $work 'Autounattend.xml') (Join-Path $stage 'unattend.xml')
$copiesVerified=$true
$state.Stage='Applying Windows locally - keep USB connected until boot is ready'
$state.Progress=$null
Write-Host '--- Applying Windows from local storage ---'
& dism.exe /Apply-Image "/ImageFile:$imageCopy" "/Index:$($chosen[0].ImageIndex)" "/ApplyDir:$osRoot" /CheckIntegrity /Verify "/LogPath:$(Join-Path $stage 'dism.log')"
if($LASTEXITCODE -ne 0){throw "DISM : echec $LASTEXITCODE. Ne pas redemarrer. Voir le journal local."}
$imageApplied=$true
if(Test-Path -LiteralPath $installedKit){throw 'Unexpected SetupKit in Windows image. Boot preparation stopped.'}
Copy-PETreeVerified (Join-Path $work 'sources\$OEM$\$1\SetupKit') $installedKit
Set-Content -LiteralPath (Join-Path $installedKit 'options.json') -Value ($settings|ConvertTo-Json -Depth 5) -Encoding UTF8
Set-Content -LiteralPath (Join-Path $installedKit 'local-source-relative.txt') -Value ($stageName+'\Kit')
Set-Content -LiteralPath (Join-Path $installedKit 'profile-version.txt') -Value '0.17'
$panther=Join-Path $osRoot 'Windows\Panther'
[void][IO.Directory]::CreateDirectory($panther)
Copy-Item -LiteralPath (Join-Path $stage 'unattend.xml') -Destination (Join-Path $panther 'unattend.xml') -Force
Write-Host '--- Preparing internal UEFI boot ---'
& bcdboot.exe (Join-Path $osRoot 'Windows') /s $efiRoot /f UEFI
if($LASTEXITCODE -ne 0){throw 'BCDBoot a echoue : ne pas redemarrer ; consulter le journal.'}
if(!(Test-Path (Join-Path $efiRoot 'EFI\Boot\bootx64.efi'))){throw 'Chargeur UEFI de secours absent.'}
& bcdedit.exe /store (Join-Path $efiRoot 'EFI\Microsoft\Boot\BCD') /enum '{default}' | Out-Host
if($LASTEXITCODE -ne 0){throw 'Internal BCD store validation failed. Do not reboot.'}
$bootConfigured=$true
Assert-PEReleaseReady $copiesVerified $imageApplied $bootConfigured $osRoot $efiRoot $installedKit
@{Stage='ReadyForInternalBoot';Time=(Get-Date -Format o);Target=$state.TargetDisk;Profile=$token} |
    ConvertTo-Json | Set-Content (Join-Path $stage 'deployment-state.json') -Encoding UTF8
$state.UsbReady=$true
$state.Stage='USB can be removed - internal boot and local packages prepared'
$state.Progress=$null
Write-Host 'RESULT: USB CAN BE REMOVED. Windows is applied; Office and apps will use local files after first logon.'
Write-Host 'RESULT: If firmware does not select this disk automatically, select its UEFI boot entry in Boot Menu.'
# Operator acknowledgment prevents a reboot back into the still-connected USB.
do {$confirmation=Read-Host 'Remove USB, then enter Y to restart this PC. You can use the USB on the next computer.'}
until($confirmation.Trim() -imatch '^(y|yes|o|oui)$')
& wpeutil.exe reboot
if($LASTEXITCODE -ne 0){throw 'WinPE restart failed. Restart manually into the prepared internal disk.'}
