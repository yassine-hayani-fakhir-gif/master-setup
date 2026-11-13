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

function Assert-PESourceBindings($Bindings) {
    foreach($binding in $Bindings) {
        $number=Get-PESourceDisk $binding.Path
        $identity=Get-PEDiskIdentity (Get-Disk -Number $number -ErrorAction Stop)
        if($number -ne $binding.Number -or $identity -cne $binding.Identity) {
            throw 'Source device changed since selection. No disk changes allowed.'
        }
    }
}
function Copy-PETreeVerified([string]$Source,[string]$Destination) {
    foreach($file in Get-ChildItem -LiteralPath $Source -File -Recurse) {
        $relative=$file.FullName.Substring($Source.TrimEnd('\').Length+1)
        Copy-PEVerified $file.FullName (Join-Path $Destination $relative)
    }
}
function Assert-PEReleaseReady([bool]$CopiesVerified,[bool]$ImageApplied,[bool]$BootConfigured,
                               [string]$OsRoot,[string]$EfiRoot,[string]$KitRoot) {
    if(!$CopiesVerified -or !$ImageApplied -or !$BootConfigured) {
        throw 'USB still required: local deployment is incomplete.'
    }
    foreach($file in @((Join-Path $OsRoot 'Windows\System32\winload.efi'),
        (Join-Path $OsRoot 'Windows\Panther\unattend.xml'),
        (Join-Path $EfiRoot 'EFI\Boot\bootx64.efi'),
        (Join-Path $EfiRoot 'EFI\Microsoft\Boot\BCD'),
        (Join-Path $KitRoot 'Finish.cmd'),(Join-Path $KitRoot 'Finish.ps1'),
        (Join-Path $KitRoot 'Suivi.ps1'),(Join-Path $KitRoot 'options.json'),
        (Join-Path $KitRoot 'local-source-relative.txt'))) {
        if(!(Test-Path -LiteralPath $file -PathType Leaf)){throw "USB release blocked: missing $file"}
    }
}
