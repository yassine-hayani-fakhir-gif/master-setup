#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\InstallHelpers.ps1"
. "$PSScriptRoot\OfficeCompletion.ps1"
$logDir = Join-Path $env:ProgramData 'YHF-Setup'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
if (!$state) { Start-Transcript -Path (Join-Path $logDir ('setup-{0}.txt' -f (Get-Date -Format yyyyMMdd-HHmmss))) }
$profileRoot=if($state -and $state.ProfileRoot){$state.ProfileRoot}else{$PSScriptRoot}
$results=New-Object 'System.Collections.Generic.List[object]'
$options=@{AppMethod='WinGet';Apps=@('Brave.Brave','Google.Chrome','RARLab.WinRAR','VideoLAN.VLC');Office=$true}
$optionsPath=Join-Path $profileRoot 'options.json'
if(Test-Path -LiteralPath $optionsPath){$options=Get-Content -LiteralPath $optionsPath -Raw | ConvertFrom-Json}
function Set-StepResult([string]$Status,[string]$Detail){$script:stepStatus=$Status;$script:stepDetail=$Detail}
function Step($title, [scriptblock]$action) {
    Write-Host "--- $title ---"
    $stepClock=[Diagnostics.Stopwatch]::StartNew()
    $script:stepStatus='Completed';$script:stepDetail=''
    try { & $action } catch {$script:stepStatus=if($_.Exception.Message -like 'PENDING:*'){'Pending'}else{'NeedsAttention'};$script:stepDetail=$_.Exception.Message;Write-Warning "$title - $script:stepDetail"}
    finally {
        Write-Host ("Stage duration: $title | "+$stepClock.Elapsed.ToString())
        $record=@{Time=(Get-Date -Format o);Step=$title;Status=$script:stepStatus;Detail=$script:stepDetail;Seconds=$stepClock.Elapsed.TotalSeconds}
        $results.Add([pscustomobject]$record)
        Write-Host ('RESULT: '+$title+' | '+$script:stepStatus+' | '+$script:stepDetail)
        if($state -and $script:stepStatus -in 'Pending','NeedsAttention'){$state.Warnings=$true}
        try {Add-Content -LiteralPath (Join-Path $logDir 'results.jsonl') -Value ($record|ConvertTo-Json -Compress) -Encoding UTF8} catch {Write-Warning 'Could not save JSON results; see the main log.'}
    }
}
try {
    if ((Test-Path (Join-Path $profileRoot 'auto-source-relative.txt')) -or (Test-Path (Join-Path $profileRoot 'local-source-relative.txt'))) {
        $wl='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
        Set-ItemProperty $wl AutoAdminLogon '0'
        Set-ItemProperty $wl AutoLogonCount 0 -Type DWord
        Remove-ItemProperty $wl DefaultPassword -ErrorAction SilentlyContinue
    }
    Step 'Restore other disks after installation' {
        $restoreFile=Join-Path $profileRoot 'restore-disks.json'
        if(Test-Path $restoreFile){
            $decoded=Get-Content $restoreFile -Raw | ConvertFrom-Json
            $records=@($decoded | Where-Object {$null -ne $_})
            if(!$records.Count){Set-StepResult 'Skipped' 'No other disks to restore';return}
            foreach($record in $records){
                if(!$record.Size -or $record.Style -notin 'GPT','MBR' -or ($record.Style -eq 'GPT' -and (!$record.Guid -or [guid]$record.Guid -eq [guid]::Empty)) -or ($record.Style -eq 'MBR' -and !$record.Signature)){throw 'Incomplete disk identity: no changes made.'}
                $foundDisks=@(Get-Disk | Where-Object {
                    $_.BusType -ne 'USB' -and [string]$_.Size -eq [string]$record.Size -and
                    [string]$_.PartitionStyle -eq $record.Style -and
                    (($record.Style -eq 'GPT' -and [string]$_.Guid -eq $record.Guid) -or
                     ($record.Style -eq 'MBR' -and $_.Signature -eq $record.Signature))
                })
                if($foundDisks.Count -eq 1 -and $foundDisks[0].IsOffline){
                    Set-Disk -Number $foundDisks[0].Number -IsOffline $false
                    Write-Host "Disk brought online: $($foundDisks[0].FriendlyName)"
                } elseif($foundDisks.Count -ne 1){Set-StepResult 'NeedsAttention' 'Disk not identified';Write-Warning 'Disk to restore is not uniquely identified: no action taken.'}
            }
        }
    }
    $kits = @(Get-PSDrive -PSProvider FileSystem | ForEach-Object {
        $sourceId = Join-Path $profileRoot 'source.id'
        if (Test-Path -LiteralPath $sourceId) {
            $k = Join-Path $_.Root 'AtelierSource\Kit'
            $id = Join-Path $k 'source.id'
            if (!(Test-Path -LiteralPath $id) -or (Get-Content -LiteralPath $id -Raw) -ne (Get-Content -LiteralPath $sourceId -Raw)) { return }
        } else { $k = Join-Path $_.Root 'Kit' }
        if (Test-Path (Join-Path $k 'YHF-KIT.tag')) { $k }
    })
    $kit = if ($kits.Count -eq 1) { $kits[0] }
    $autoRef=Join-Path $profileRoot 'auto-source-relative.txt'
    if (Test-Path $autoRef) {
        $rel=(Get-Content -LiteralPath $autoRef -Raw).Trim()
        $autoKits=@(Get-PSDrive -PSProvider FileSystem | ForEach-Object {
            $candidate=Join-Path $_.Root $rel
            if (Test-Path (Join-Path $candidate 'ventoy-profile.tag')) { $candidate }
        })
        if ($autoKits.Count -eq 1) { $kit=$autoKits[0] }
    }
    $ventoy = Test-Path -LiteralPath (Join-Path $profileRoot 'ventoy-profile.tag')
    if ($ventoy) { $kit=$profileRoot }
    if ($kit -and (Test-Path (Join-Path $kit 'ventoy-profile.tag'))) { $ventoy=$true }
    $localRef=Join-Path $profileRoot 'local-source-relative.txt'
    if(Test-Path -LiteralPath $localRef){
        $relative=(Get-Content -LiteralPath $localRef -Raw).Trim()
        if($relative -notmatch '^MasterStage-[a-f0-9]{32}\\Kit$'){throw 'Invalid local deployment reference.'}
        $kit=Join-Path ($env:SystemDrive+'\') $relative
        if(!(Test-Path (Join-Path $kit 'ventoy-profile.tag'))){throw 'Local deployment source missing. Do not use another machine profile.'}
        $ventoy=$true
    }
    if (!$kit) { Write-Warning 'Reconnect exactly one prepared USB for offline drivers and Office. Rerun Finish.cmd afterwards.' }
    Step 'Secure Boot' { Confirm-SecureBootUEFI }
    Step 'Offline INF drivers' {
        if ($kit -and (Get-ChildItem "$kit\Drivers\Essential" -Filter *.inf -Recurse -ErrorAction SilentlyContinue)) {
            pnputil /add-driver "$kit\Drivers\Essential\*.inf" /subdirs /install
            if ($LASTEXITCODE -notin 0,3010) { throw "PnPUtil exit $LASTEXITCODE" }
        }
    }
    Step 'Office ISO' {
        if($state -and $state.SkipOffice){Set-StepResult 'Skipped' 'Office skipped for this resume';return}
        if(!$options.Office){Set-StepResult 'Skipped' 'Office not selected';return}
        if((Get-MasterInternetState) -eq 'Offline'){Write-Host 'Office: offline mode, using local media.'}
        if (!$kit) { throw 'PENDING: Office USB source not found.' }
        $folder = Join-Path $kit 'Office'
        $parts = Join-Path $folder 'Parts'
        $marker = Join-Path $logDir 'office-completed.txt'
        $tempFolder = $null
        $mountedHere = $false
        try {
            if (Test-Path -LiteralPath $parts) {
                $info = Get-Content -LiteralPath (Join-Path $parts 'manifest.json') -Raw | ConvertFrom-Json
                $total = [long]$info.bytes
                $count = [int]$info.count
                $hash = [string]$info.sha256
                if ($total -lt 4GB -or $count -ne [Math]::Ceiling($total / 2GB) -or $hash -notmatch '^[0-9a-f]{64}$') { throw 'Invalid Office manifest.' }
                if ((Test-Path $marker) -and (Get-Content $marker -Raw).Trim() -eq $hash) { Set-StepResult 'Skipped' 'Office installer already completed for this image'; return }
                if ((Get-Volume -DriveLetter ($env:SystemDrive.TrimEnd(':'))).SizeRemaining -le $total) { throw 'Not enough free space to reassemble Office.' }
                $tempFolder = New-Item -ItemType Directory -Path (Join-Path $logDir ([guid]::NewGuid().ToString()))
                $path = Join-Path $tempFolder.FullName 'Office.iso'
                $outFile = [IO.File]::Open($path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write)
                try {
                    for ($i=1; $i -le $count; $i++) {
                        $chunk = [IO.File]::OpenRead((Join-Path $parts ('office-{0:D4}.bin' -f $i)))
                        try { $chunk.CopyTo($outFile) } finally { $chunk.Dispose() }
                    }
                } finally { $outFile.Dispose() }
                if ((Get-Item -LiteralPath $path).Length -ne $total -or (Get-FileHash -LiteralPath $path).Hash -ne $hash) { throw 'Office image verification failed.' }
            } elseif ($ventoy) {
                $ref=Join-Path $kit 'office-relative.txt'
                if (!(Test-Path $ref)) { Set-StepResult 'Skipped' 'No Office image supplied'; return }
                $path=Join-Path ([IO.Path]::GetPathRoot($kit)) ([IO.File]::ReadAllText($ref).Trim())
                $hash=(Get-FileHash -LiteralPath $path).Hash
                if ((Test-Path $marker) -and (Get-Content $marker -Raw).Trim() -eq $hash) { Set-StepResult 'Skipped' 'Office installer already completed for this image'; return }
            } else {
                $isos = @(Get-ChildItem -LiteralPath $folder -Filter *.iso -File)
                if (!$isos.Count) { Set-StepResult 'Skipped' 'No Office image supplied'; return }
                if ($isos.Count -ne 1) { throw 'Keep exactly one prepared Office image.' }
                $path = $isos[0].FullName
                $hash = (Get-FileHash -LiteralPath $path).Hash
                if ((Test-Path $marker) -and (Get-Content $marker -Raw).Trim() -eq $hash) { Set-StepResult 'Skipped' 'Office installer already completed for this image'; return }
            }
            $img = Get-DiskImage -ImagePath $path
            if (!$img.Attached) {
                $img = Mount-DiskImage -ImagePath $path -StorageType ISO -PassThru
                $mountedHere = $true
            }
            $volumes=@($img | Get-Volume | Where-Object {$_.DriveLetter})
            if($volumes.Count -ne 1){throw 'Office volume is not uniquely identified.'}
            $officeRoot="$($volumes[0].DriveLetter):\"
            $exe=Join-Path $officeRoot 'setup.exe'
            if(!(Test-Path -LiteralPath $exe -PathType Leaf)){throw "Office : setup.exe missing in $officeRoot"}
            Write-Host "Office : source $path ; program $exe ; working directory $officeRoot"
            $sig = Get-AuthenticodeSignature $exe
            if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch '(?:^|, )O=Microsoft Corporation(?:,|$)') { throw 'Office setup signature could not be verified.' }
            Write-Host 'Office: complete the Microsoft setup window (Alt+Tab). Waiting for exit; percentage unavailable.'
            if($state){$state.Attention='Office: Microsoft setup may require attention (Alt+Tab)'}
            try {
                $officeStarted=Get-Date
                $officeWorker=[PowerShell]::Create()
                try {
                    [void]$officeWorker.AddScript({param($file,$directory)
                        $ErrorActionPreference='Stop'
                        $process=Start-Process -FilePath $file -WorkingDirectory $directory -Wait -PassThru
                        return $process.ExitCode
                    }.ToString()).AddArgument($exe).AddArgument($officeRoot)
                    $officeJob=$officeWorker.BeginInvoke()
                    while(!$officeJob.IsCompleted){
                        [void](Close-MasterOfficeSuccess -Started $officeStarted)
                        Start-Sleep -Seconds 2
                    }
                    $officeOutput=@($officeWorker.EndInvoke($officeJob))
                    if($officeWorker.HadErrors -or !$officeOutput.Count){throw 'Office installer monitoring failed; inspect the Microsoft window.'}
                    $r=[pscustomobject]@{ExitCode=[int]$officeOutput[-1]}
                } finally {$officeWorker.Dispose()}
                if($r.ExitCode -in 0,3010){
                    for($attempt=0;$attempt -lt 5;$attempt++){
                        if(Close-MasterOfficeSuccess -Started $officeStarted){break}
                        Start-Sleep -Seconds 1
                    }
                }
            } finally {if($state){$state.Attention=$null}}
            Write-Host ('Office: exit code '+$r.ExitCode)
            if ($r.ExitCode -notin 0,3010) { throw "Office exit $($r.ExitCode)" }
            Set-Content $marker $hash
            Set-StepResult 'InstallerExited' 'Office returned success; verify installation in Word.'
            Write-Host 'Office: installer exited. Open Word to verify. No activation command executed.'
        } finally {
            if ($mountedHere) { Dismount-DiskImage -ImagePath $path | Out-Null }
            if ($tempFolder) { Remove-Item -LiteralPath $tempFolder.FullName -Recurse -Force }
        }
    }
    Step 'Applications' {
        $method=if($options.AppMethod){[string]$options.AppMethod}else{'WinGet'}
        if($method -eq 'None'){Set-StepResult 'Skipped' 'Apps not selected';return}
        if($method -eq 'WinGet' -and !@($options.Apps).Count){Set-StepResult 'Skipped' 'No apps selected';return}
        if($method -eq 'Local'){
            if(!$kit){throw 'PENDING: reconnect the USB containing your installers.'}
            . "$PSScriptRoot\LocalApps.ps1"
            if(!@($options.LocalApps).Count){Set-StepResult 'Skipped' 'No local installers';return}
            $localSuccess=Invoke-LocalApps -Apps @($options.LocalApps) -BaseRoot $kit -LogDir $logDir
            if(!$localSuccess){throw 'Local apps: review individual results; run again to resume.'}
            Set-StepResult 'InstallerExited' 'Local installers exited or were previously run. Verify apps.'
            return
        }
        if((Get-MasterInternetState) -eq 'Offline'){throw 'PENDING: Windows reports no Internet. Reconnect and resume apps.'}
        if($method -eq 'Ninite'){
            if(!$kit){throw 'PENDING: reconnect the USB containing Ninite.'}
            $installer=Join-Path $kit 'Apps\Ninite.exe'
            Test-MasterInstaller -Path $installer -ExpectedHash $options.NiniteHash -ExpectedSigner $options.NiniteSigner
            Write-Host '--- Apps through your Ninite installer ---'
            $run=Start-Process -FilePath $installer -Wait -PassThru
            if($run.ExitCode -ne 0){throw "Ninite returned $($run.ExitCode). Check its results."}
            Set-StepResult 'InstallerExited' 'Review the per-app results in Ninite.'
            Write-Host 'Ninite exited. Check its per-app results. WinGet was not run.'
            return
        }
        if($method -ne 'WinGet'){throw 'Unknown apps method.'}
        if(!@($options.Apps).Count){Set-StepResult 'Skipped' 'No apps selected';return}
        $wingetPath=Resolve-MasterWinGet
        $failedApps=@()
        foreach ($app in @($options.Apps)) {
            if($app -notin 'Brave.Brave','Google.Chrome','RARLab.WinRAR','VideoLAN.VLC'){Write-Warning 'Unknown application in profile: skipped.';continue}
            Write-Host "--- Installation : $app ---"
            & $wingetPath install --id $app --exact --source winget --silent --accept-source-agreements --accept-package-agreements --disable-interactivity
            if($LASTEXITCODE -ne 0){$failedApps+=$app;Write-Warning "$app : code $LASTEXITCODE ; check the WinGet log."} else {Write-Host "$app installed."}
        }
        if($failedApps.Count){throw ('Apps needing attention: '+($failedApps -join ', '))}
    }
    Step 'Devices requiring attention' {
        Get-CimInstance Win32_PnPEntity -Filter 'ConfigManagerErrorCode <> 0' | Select-Object Name,PNPDeviceID,ConfigManagerErrorCode | Format-Table -Wrap
    }
    Write-Host 'RESULT: Activation | Not run | No Windows or Office activation commands.'
    Write-Host ('FINAL RESULT: '+@($results | Where-Object {$_.Status -in 'Pending','NeedsAttention'}).Count+' stage(s) to resume or verify.')

} finally { if (!$state) { Stop-Transcript } }
