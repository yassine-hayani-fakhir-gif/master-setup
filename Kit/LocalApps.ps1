# Profiles use a signed publisher AND a specific installer filename, never name alone.
function Get-LocalAppMode([string]$Path) {
    if([IO.Path]::GetExtension($Path) -eq '.msi'){return 'SilentMSI'}
    $sig=Get-AuthenticodeSignature -LiteralPath $Path
    if($sig.Status -ne 'Valid'){return 'Interactive'}
    $publisher=$sig.SignerCertificate.Subject
    $name=[IO.Path]::GetFileName($Path)
    if($publisher -match 'Brave Software' -and $name -match '^BraveBrowserStandaloneSetup(32|Arm64)?\.exe$'){return 'BraveOffline'}
    if($publisher -match 'Brave Software' -and $name -match '^BraveBrowserStandaloneSilentSetup(32|Arm64)?\.exe$'){return 'BraveSilent'}
    if($publisher -match '(win\.rar GmbH|RARLAB)' -and $name -match '^winrar(-x64)?-\d+[a-z]*\.exe$'){return 'WinRAROffline'}
    if($publisher -match 'VideoLAN' -and $name -match '^vlc-[0-9.]+-win(32|64|arm64)\.exe$'){return 'VLCOffline'}
    return 'Interactive'
}
function Test-ProfileInstalled([string]$Mode) {
    $relative=if($Mode -like 'Brave*'){'BraveSoftware\Brave-Browser\Application\brave.exe'}elseif($Mode -eq 'WinRAROffline'){'WinRAR\WinRAR.exe'}elseif($Mode -eq 'VLCOffline'){'VideoLAN\VLC\vlc.exe'}else{return $true}
    $publisher=if($Mode -like 'Brave*'){'Brave Software'}elseif($Mode -eq 'VLCOffline'){'VideoLAN'}else{'(win\.rar GmbH|RARLAB)'}
    foreach($root in @($env:ProgramFiles,${env:ProgramFiles(x86)},$env:LOCALAPPDATA)){
        if(!$root){continue}
        $candidate=Join-Path $root $relative
        if(Test-Path -LiteralPath $candidate){
            $sig=Get-AuthenticodeSignature -LiteralPath $candidate
            if($sig.Status -eq 'Valid' -and $sig.SignerCertificate.Subject -match $publisher){return $true}
        }
    }
    return $false
}
# Poll only the launched installer; browser windows are not installation progress.
# Timeout stops the queue without killing a possibly active installer.
function Wait-LocalInstaller($Process,[int]$TimeoutSeconds=900) {
    $watch=[Diagnostics.Stopwatch]::StartNew()
    while(!$Process.HasExited){
        if($state){
            $state.AppSeconds=[int]$watch.Elapsed.TotalSeconds
            if($state.SkipApp){return 'Skipped'}
        }
        if($watch.Elapsed.TotalSeconds -ge $TimeoutSeconds){return 'Timeout'}
        Start-Sleep -Milliseconds 250
        $Process.Refresh()
    }
    $Process.WaitForExit()
    return 'Exited'
}
# Local installers are explicitly selected by the operator; no shell command evaluation.
function New-LocalAppRecord([string]$Path) {
    $file=Get-Item -LiteralPath $Path -ErrorAction Stop
    if($file.PSIsContainer -or $file.Extension -notin '.exe','.msi'){throw 'Choose an EXE or MSI file.'}
    $signature=Get-AuthenticodeSignature -LiteralPath $file.FullName
    if($signature.Status -notin 'Valid','NotSigned'){throw ('Invalid signature: '+$signature.Status)}
    return [pscustomobject]@{Name=$file.BaseName;Path=$file.FullName;Hash=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash;Signer=if($signature.Status -eq 'Valid'){$signature.SignerCertificate.Thumbprint}else{''};Unsigned=($signature.Status -eq 'NotSigned');Mode=(Get-LocalAppMode $file.FullName);Arguments='';ManualApproved=$false}
}
function Test-LocalAppFile($App,[string]$Path) {
    if([IO.Path]::GetExtension($Path) -notin '.exe','.msi'){throw 'Installer extension is not allowed.'}
    if($App.Hash -notmatch '^[a-fA-F0-9]{64}$'){throw 'Installer hash is missing.'}
    if(!(Test-Path -LiteralPath $Path -PathType Leaf)){throw 'Installer missing. Reconnect its source.'}
    if((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -ne $App.Hash){throw 'File changed since selection: execution cancelled.'}
    $signature=Get-AuthenticodeSignature -LiteralPath $Path
    if($App.Unsigned -eq $true -and !$App.Signer){
        if($signature.Status -ne 'NotSigned'){throw 'Signature state changed.'}
    } elseif($signature.Status -ne 'Valid' -or !$App.Signer -or $signature.SignerCertificate.Thumbprint -ne $App.Signer){throw 'Signature missing, invalid or different.'}
}
function Get-LocalAppPath($App,[string]$BaseRoot) {
    if(!$BaseRoot){return [IO.Path]::GetFullPath([string]$App.Path)}
    $relative=[string]$App.Path
    if([IO.Path]::IsPathRooted($relative)){throw 'Unexpected absolute path in the USB profile.'}
    $root=[IO.Path]::GetFullPath($BaseRoot).TrimEnd('\')+'\'
    $path=[IO.Path]::GetFullPath((Join-Path $root $relative))
    if(!$path.StartsWith($root,[StringComparison]::OrdinalIgnoreCase)){throw 'Installer path is outside the kit.'}
    return $path
}
function Invoke-LocalApps {
    param([object[]]$Apps,[string]$BaseRoot,[string]$LogDir,[switch]$RetryCompleted)
    [void][IO.Directory]::CreateDirectory($LogDir)
    $markers=Join-Path $LogDir 'local-apps-completed'
    [void][IO.Directory]::CreateDirectory($markers)
    $issues=0;$index=0
    foreach($app in $Apps){
        $index++;$clock=[Diagnostics.Stopwatch]::StartNew();$code=$null;$status='NeedsAttention';$detail='';$stopQueue=$false
        Write-Host "--- Application $index/$($Apps.Count) : $($app.Name) ---"
        try {
            if($app.Mode -eq 'Interactive' -and !$app.ManualApproved){throw 'No automatic profile. Select a supported installer or configure its documented silent arguments in the app picker.'}
            $path=Get-LocalAppPath $app $BaseRoot
            Test-LocalAppFile $app $path
            if($app.Mode -notin 'Interactive','CustomSilent','PassiveMSI','SilentMSI','BraveOffline','BraveSilent','WinRAROffline','VLCOffline'){throw 'Unknown installation mode.'}
            if($app.Mode -in 'PassiveMSI','SilentMSI' -and [IO.Path]::GetExtension($path) -ne '.msi'){throw 'MSI mode cannot be used for an EXE.'}
            if($app.Mode -in 'BraveOffline','BraveSilent','WinRAROffline','VLCOffline' -and (Get-LocalAppMode $path) -ne $app.Mode){throw 'Automatic profile does not match this signed file.'}
            if($app.Mode -eq 'CustomSilent' -and ([string]::IsNullOrWhiteSpace([string]$app.Arguments) -or [string]$app.Arguments -match '[\r\n\x00]')){throw 'Custom silent arguments are missing or invalid.'}
            $argsText=if($app.Mode -eq 'CustomSilent'){[string]$app.Arguments}else{''}
            $sha=[Security.Cryptography.SHA256]::Create()
            try {$argsHash=([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($argsText)))).Replace('-','')} finally {$sha.Dispose()}
            $marker=Join-Path $markers ($app.Hash+'-'+$app.Mode+'-'+$argsHash+'.txt')
            if((Test-Path -LiteralPath $marker) -and !$RetryCompleted){$status='Skipped';$detail='A successful exit was previously recorded for this file and mode. Verify the app.'}
            else {
                Write-Host ('Installer: '+$path+' | mode '+$app.Mode)
                if($state){$state.Attention="Application $index/$($Apps.Count) : $($app.Name) (Alt+Tab if needed)"}
                $launch=@{FilePath=$path;WorkingDirectory=([IO.Path]::GetDirectoryName($path));PassThru=$true}
                if([IO.Path]::GetExtension($path) -eq '.msi'){
                    $launch.FilePath=Join-Path $env:SystemRoot 'System32\msiexec.exe'
                    $msilog=Join-Path $LogDir ('msi-'+(Get-Date -Format yyyyMMdd-HHmmss)+'-'+$index+'.log')
                    $launch.ArgumentList='/i "'+$path+'" /norestart /L*v "'+$msilog+'"'
                    if($app.Mode -eq 'PassiveMSI'){$launch.ArgumentList+=' /passive'}
                }
                if($app.Mode -eq 'SilentMSI'){$launch.ArgumentList+=' /qn REBOOT=ReallySuppress'}
                if($app.Mode -eq 'BraveOffline'){$launch.ArgumentList='/silent /install'}
                if($app.Mode -eq 'WinRAROffline'){$launch.ArgumentList='-s1'}
                if($app.Mode -eq 'VLCOffline'){$launch.ArgumentList='/S /L=1033'}
                if($app.Mode -eq 'CustomSilent'){$launch.ArgumentList=[string]$app.Arguments}
                if($state){$state.AppWaiting=$true;$state.SkipApp=$false;$state.AppSeconds=0;$state.AppCount=$Apps.Count;$state.AppIndex=$index}
                $process=Start-Process @launch
                if($state){$state.Attention="Installing $($app.Name) | $($app.Mode)"}
                $waitResult=Wait-LocalInstaller $process
                if($waitResult -eq 'Timeout'){$stopQueue=$true;throw '15-minute timeout. Queue stopped; installer left running. Check its window before retrying.'}
                if($waitResult -eq 'Skipped'){throw 'Skipped by operator. Installation NOT verified; process left running.'}
                if($state){$state.AppWaiting=$false}
                $code=$process.ExitCode
                if($code -in 0,3010,1641){
                    $status='InstallerExited';$detail='Successful installer exit; verify the application.'
                    if($code -in 3010,1641){$detail='Restart required. Resume apps after restarting.';$stopQueue=$true;if($state){$state.Warnings=$true}}
                    if($app.Mode -in 'BraveOffline','BraveSilent','WinRAROffline','VLCOffline'){
                        $found=Test-ProfileInstalled $app.Mode
                        for($attempt=0;!$found -and $attempt -lt 30;$attempt++){Start-Sleep -Seconds 2;$found=Test-ProfileInstalled $app.Mode}
                        if(!$found){throw 'Installer exited, but the signed application was not found. Manual verification required.'}
                        $status='Installed';$detail='Successful exit and signed installed executable detected.'
                    }
                    Set-Content -LiteralPath $marker -Value (Get-Date -Format o)
                } else {throw "Installer returned $code. Run this app again to retry."}
            }
        } catch {$status='NeedsAttention';$detail=$_.Exception.Message;$issues++;Write-Warning ($app.Name+' : '+$detail);if($state){$state.Warnings=$true}}
        finally {
            if($state){$state.Attention=$null;$state.AppWaiting=$false;$state.SkipApp=$false;$state.AppDone=$index}
            $entry=@{Time=(Get-Date -Format o);App=$app.Name;Hash=$app.Hash;Status=$status;ExitCode=$code;Detail=$detail;Seconds=$clock.Elapsed.TotalSeconds}
            Add-Content -LiteralPath (Join-Path $LogDir 'local-apps-results.jsonl') -Value ($entry|ConvertTo-Json -Compress) -Encoding UTF8
            Write-Host ("APP RESULT: $($app.Name) | $status | $detail | $($clock.Elapsed.ToString())")
        }
        if($stopQueue){Write-Warning 'Queue stopped. Review results before resuming remaining apps.';return $false}
    }
    return ($issues -eq 0)
}
