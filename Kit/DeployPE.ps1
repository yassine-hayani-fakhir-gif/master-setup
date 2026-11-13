#Requires -RunAsAdministrator
$ErrorActionPreference='Stop'
. "$PSScriptRoot\PEHelpers.ps1"
. "$PSScriptRoot\LiveCopy.ps1"
. "$PSScriptRoot\LocalApps.ps1"
Assert-PEEnvironment
$state.UsbReady=$false
$state.Firmware='UEFI'
Write-Warning 'WinPE experimental UEFI : sauvegarder les donnees avant de confirmer. Le disque choisi sera efface AVANT la copie locale.'
if($state.Options.AppMethod -notin 'Local','None'){throw 'Ce mode accepte Mes installateurs USB ou No applications. Pas de telechargement WinGet/Ninite.'}
$source=Get-AtelierImage 'Windows : choisir install.wim ou install.esd prepare sur USB' 'Image Windows|*.wim;*.esd'
if(!$source){$state.Cancelled=$true;return}
$sources=New-Object 'System.Collections.Generic.List[int]'
$sources.Add((Get-PESourceDisk $source))
$images=@(Get-WindowsImage -ImagePath $source -ErrorAction Stop)
foreach($image in $images){Write-Host ("$($image.ImageIndex) : $($image.ImageName)")}
do {
    $choice=(Read-Host 'Numero de l edition Windows (n = annuler)').Trim()
    if($choice -ieq 'n'){$state.Cancelled=$true;return}
    $chosen=@($images | Where-Object {[string]$_.ImageIndex -eq $choice})
} until($chosen.Count -eq 1)
$details=Get-WindowsImage -ImagePath $source -Index $chosen[0].ImageIndex
if([string]$details.Architecture -notin '9','amd64','x64'){throw 'Image Windows x64 requise.'}
$keyboardChoices=@('040c:0000040c','0409:00000409','0809:00000809','1801:00020401','0401:00000401','080c:0000080c','0407:00000407')
$keyboardNames=@('Francais France AZERTY','English US QWERTY','English UK QWERTY','Arabe Maroc 102 AZERTY','Arabe 101','Francais Belgique AZERTY','Deutsch QWERTZ')
for($i=0;$i -lt 7;$i++){Write-Host (([string]($i+1))+' : '+$keyboardNames[$i])}
do {$key=Read-Host 'Clavier : numero de 1 a 7'} until($key -match '^[1-7]$')
$keyboard=$keyboardChoices[[int]$key-1]
$office=$null
if($state.Options.Office){$office=Get-AtelierImage 'Office ISO / IMG (Annuler = ignorer)' 'Office|*.iso;*.img';if($office){$sources.Add((Get-PESourceDisk $office))}}
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
    $choice=Read-Host 'Numero du disque INTERNE a effacer (n = annuler)'
    if($choice -ieq 'n'){$state.Cancelled=$true;return}
    $diskMatches=@($disks|Where-Object {[string]$_.Number -eq $choice})
    if($diskMatches.Count -ne 1){Write-Host 'Numero inconnu.';continue}
    $target=$diskMatches[0]
    try {$identity=Get-PEDiskIdentity $target;$target=Assert-PETarget $identity $target.Number $sources.ToArray()} catch {Write-Warning $_.Exception.Message;continue}
    if($target.Size -lt [math]::Max(64GB,([long]$details.ImageSize+$bytes+20GB))){Write-Warning 'Espace insuffisant pour Windows, les sources et une marge de 20 GiB.';continue}
    $state.TargetDisk="Disk $($target.Number) | $($target.FriendlyName) | $([math]::Round($target.Size/1GB,1)) GiB | serial $($target.SerialNumber)"
    break
}
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
Write-Host ('CIBLE A EFFACER : '+$state.TargetDisk)
Write-Host ('Edition : '+$details.ImageName+' | Nouveau nom : '+$state.PlannedName)
$confirm=Read-Host ("Sauvegarde faite et licence Windows acceptee ? Pour EFFACER toutes les partitions, taper EFFACER $($target.Number)")
if($confirm.Trim() -ine "EFFACER $($target.Number)"){$state.Cancelled=$true;return}
# Re-identify source and target immediately before the first destructive command.
$null=Get-PESourceDisk $source
if($office){$null=Get-PESourceDisk $office}
foreach($app in $apps){$null=Get-PESourceDisk $app.Path}
$target=Assert-PETarget $identity $target.Number $sources.ToArray()
$free=@(68..87 | ForEach-Object {[char]$_} | Where-Object {!(Test-Path ([string]$_+':\')) -and !@(Get-Volume -DriveLetter $_ -ErrorAction SilentlyContinue).Count})
if($free.Count -lt 2){throw 'Deux lettres libres requises.'}
$osLetter=[string]$free[0];$efiLetter=[string]$free[1]
$osRoot=$osLetter+':\';$efiRoot=$efiLetter+':\'
Write-Host '--- Preparation du disque confirme ---'
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
Write-Host '--- Copie locale et verification avant liberation USB ---'
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
Copy-Item -LiteralPath (Join-Path $work 'sources\$OEM$\$1\SetupKit') -Destination $installedKit -Recurse
Set-Content -LiteralPath (Join-Path $installedKit 'options.json') -Value ($settings|ConvertTo-Json -Depth 5) -Encoding UTF8
Set-Content -LiteralPath (Join-Path $installedKit 'local-source-relative.txt') -Value ($stageName+'\Kit')
Set-Content -LiteralPath (Join-Path $installedKit 'profile-version.txt') -Value '0.15'
Copy-Item -LiteralPath (Join-Path $work 'Autounattend.xml') -Destination (Join-Path $stage 'unattend.xml')
# No USB files are referenced after this point. Running scripts live in X: RAM.
$state.LocalLog=Join-Path $stage 'deployment.log'
$state.UsbReady=$true
Write-Host 'BILAN USB : COPIES VERIFIEES - USB LIBERABLE. Retirer la cle pour preparer le prochain PC.'
$confirmation=Read-Host 'Retirer la cle USB, puis taper o pour continuer depuis le disque local'
while($confirmation -inotmatch '^(o|oui|y|yes)$'){$confirmation=Read-Host 'Taper o quand la cle est retiree'}
Write-Host '--- Application locale de Windows ---'
& dism.exe /Apply-Image "/ImageFile:$imageCopy" "/Index:$($chosen[0].ImageIndex)" "/ApplyDir:$osRoot" /CheckIntegrity /Verify "/LogPath:$(Join-Path $stage 'dism.log')"
if($LASTEXITCODE -ne 0){throw "DISM : echec $LASTEXITCODE. Ne pas redemarrer. Voir le journal local."}
$panther=Join-Path $osRoot 'Windows\Panther'
[void][IO.Directory]::CreateDirectory($panther)
Copy-Item -LiteralPath (Join-Path $stage 'unattend.xml') -Destination (Join-Path $panther 'unattend.xml') -Force
Write-Host '--- Creation du demarrage Windows UEFI ---'
& bcdboot.exe (Join-Path $osRoot 'Windows') /s $efiRoot /f UEFI
if($LASTEXITCODE -ne 0){throw 'BCDBoot a echoue : ne pas redemarrer ; consulter le journal.'}
if(!(Test-Path (Join-Path $efiRoot 'EFI\Boot\bootx64.efi'))){throw 'Chargeur UEFI de secours absent.'}
Write-Host 'RESULT: Windows applique. Redemarrage vers Windows ; Office et apps utilisent le disque local.'
Write-Host 'RESULT: Selon le firmware, selectionner Windows Boot Manager si le PC ne demarre pas automatiquement.'
Start-Sleep -Seconds 5
& wpeutil.exe reboot
if($LASTEXITCODE -ne 0){throw 'Redemarrage WinPE refuse.'}
