$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\Kit\LocalApps.ps1"
$folder=Join-Path ([IO.Path]::GetTempPath()) ('master-local-tests-'+[guid]::NewGuid())
[void][IO.Directory]::CreateDirectory($folder)
$script:launches=0;$script:lastLaunch=$null;$script:mockExit=0
try {
    function Get-AuthenticodeSignature {param($LiteralPath) [pscustomobject]@{Status='Valid';SignerCertificate=[pscustomobject]@{Thumbprint='TEST';Subject='CN=Example'}}}
    function Start-Process {param($FilePath,$WorkingDirectory,$ArgumentList,[switch]$Wait,[switch]$PassThru)
        $script:launches++;$script:lastLaunch=@{File=$FilePath;Directory=$WorkingDirectory;Arguments=$ArgumentList}
        [pscustomobject]@{ExitCode=$script:mockExit}
    }
    function Wait-LocalInstaller {param($Process) return 'Exited'}
    $file=Join-Path $folder 'example with spaces.exe'
    [IO.File]::WriteAllText($file,'not executable test fixture')
    $app=New-LocalAppRecord $file;$app.ManualApproved=$true
    if(!(Invoke-LocalApps -Apps @($app) -LogDir (Join-Path $folder 'logs'))){throw 'Mock success failed'}
    if($script:launches -ne 1 -or $script:lastLaunch.Directory -ne $folder){throw 'Wrong working directory or launch count'}
    if(!(Invoke-LocalApps -Apps @($app) -LogDir (Join-Path $folder 'logs')) -or $script:launches -ne 1){throw 'Completed installer reran'}
    [IO.File]::WriteAllText($file,'changed')
    if(Invoke-LocalApps -Apps @($app) -LogDir (Join-Path $folder 'logs')){throw 'Tampered file accepted'}
    if($script:launches -ne 1){throw 'Tampered file launched'}
    $escape=$false
    try {Get-LocalAppPath ([pscustomobject]@{Path='..\escape.exe'}) $folder} catch {$escape=$true}
    if(!$escape){throw 'Relative escape accepted'}
    $msi=Join-Path $folder 'test package.msi'
    [IO.File]::WriteAllText($msi,'fake MSI')
    $msiApp=New-LocalAppRecord $msi;$msiApp.Mode='PassiveMSI';$script:mockExit=1603
    if(Invoke-LocalApps -Apps @($msiApp) -LogDir (Join-Path $folder 'logs')){throw 'Failed MSI reported success'}
    if($script:lastLaunch.Arguments -notlike '*/norestart*' -or $script:lastLaunch.Arguments -notlike '*/passive*'){throw 'MSI options missing'}
    $script:mockExit=0
    if(!(Invoke-LocalApps -Apps @($msiApp) -LogDir (Join-Path $folder 'logs'))){throw 'Retry failed'}
    $script:mockExit=3010
    $count=$script:launches
    if(Invoke-LocalApps -Apps @($msiApp,$msiApp) -LogDir (Join-Path $folder 'logs') -RetryCompleted){throw 'Reboot queue should stop'}
    if($script:launches -ne $count+1){throw 'Queue continued after reboot required'}
    $script:mockExit=0
    $custom=New-LocalAppRecord $file
    $count=$script:launches
    if(Invoke-LocalApps -Apps @($custom) -LogDir (Join-Path $folder 'custom')){throw 'Unconfigured EXE accepted'}
    if($script:launches -ne $count){throw 'Unconfigured EXE launched'}
    $custom.Mode='CustomSilent';$custom.Arguments='/quiet /norestart'
    if(!(Invoke-LocalApps -Apps @($custom) -LogDir (Join-Path $folder 'custom'))){throw 'Custom profile failed'}
    if($script:lastLaunch.Arguments -cne '/quiet /norestart'){throw 'Custom arguments changed'}
    $count=$script:launches
    $custom.Arguments='/silent'
    if(!(Invoke-LocalApps -Apps @($custom) -LogDir (Join-Path $folder 'custom'))){throw 'Changed custom profile failed'}
    if($script:launches -ne $count+1){throw 'Changed arguments reused old success marker'}
    $custom.Arguments="/silent`nanything"
    $count=$script:launches
    if(Invoke-LocalApps -Apps @($custom) -LogDir (Join-Path $folder 'custom')){throw 'Multiline arguments accepted'}
    if($script:launches -ne $count){throw 'Invalid custom profile launched'}
    Write-Host 'PASS: EXE working directory, success skip, tamper block, path confinement, MSI arguments, failed retry, reboot stop.'
} finally {
    Remove-Item Function:\Get-AuthenticodeSignature,Function:\Start-Process,Function:\Wait-LocalInstaller -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $folder -Recurse -Force
}
