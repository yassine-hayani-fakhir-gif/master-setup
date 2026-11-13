function Assert-PEEnvironment {
    if(!(Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Control\MiniNT')){throw 'Ce mode fonctionne uniquement dans Master Setup WinPE.'}
    if(![Environment]::Is64BitProcess){throw 'WinPE x64 requis.'}
    & wpeutil.exe UpdateBootInfo
    if($LASTEXITCODE -ne 0){throw 'Lecture firmware WinPE impossible.'}
    if((Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control' -Name PEFirmwareType).PEFirmwareType -ne 2){throw 'Ce premier mode USB amovible exige UEFI. Mode BIOS non pris en charge.'}
}
function Get-PEDiskIdentity($Disk) {
    if([string]::IsNullOrWhiteSpace([string]$Disk.UniqueId)){throw 'Identite disque absente ; aucune selection automatique.'}
    return ([string]$Disk.UniqueId+'|'+[string]$Disk.SerialNumber+'|'+[string]$Disk.Size+'|'+[string]$Disk.BusType+'|'+[string]$Disk.Path)
}
function Assert-PETarget($Expected,[int]$Number,[int[]]$SourceDisks) {
    $disk=Get-Disk -Number $Number -ErrorAction Stop
    if((Get-PEDiskIdentity $disk) -cne $Expected){throw 'Identite du disque changee. Arret.'}
    if($disk.Number -in $SourceDisks -or $disk.BusType -notin 'SATA','SAS','NVMe','ATA','SCSI','RAID' -or $disk.IsOffline -or $disk.IsReadOnly -or $disk.IsBoot -or $disk.IsSystem){throw 'Disque cible non eligible ou contenant une source.'}
    if([string]$disk.HealthStatus -ne 'Healthy'){throw 'Disque cible signale non sain par Windows.'}
    return $disk
}
function Get-PESourceDisk([string]$Path) {
    $root=[IO.Path]::GetPathRoot([IO.Path]::GetFullPath($Path))
    if($root -notmatch '^[A-Za-z]:\\$' -or $root -ieq 'X:\'){throw 'Choisir les medias sur une cle USB NTFS/exFAT.'}
    $partition=@(Get-Partition -DriveLetter $root[0] -ErrorAction Stop)
    if($partition.Count -ne 1){throw 'Volume source ambigu.'}
    $disk=$partition[0]|Get-Disk
    $volume=Get-Volume -DriveLetter $root[0]
    if($disk.BusType -ne 'USB' -or $volume.FileSystem -notin 'NTFS','exFAT'){throw 'Source USB NTFS/exFAT requise pour ce mode.'}
    return [int]$disk.Number
}
function Copy-PEVerified([string]$Source,[string]$Destination) {
    $hash=(Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Destination))
    Copy-AtelierFile $Source $Destination
    Write-Host ('Verification SHA256 : '+[IO.Path]::GetFileName($Destination))
    if((Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash -ne $hash){throw ('Copie non conforme : '+$Destination)}
}
