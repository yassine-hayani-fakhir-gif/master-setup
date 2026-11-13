$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$temporary=Join-Path $env:TEMP ('Master Setup smoke '+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $temporary | Out-Null
$process=$null
try {
    Copy-Item (Join-Path $root 'MasterSetup.exe') $temporary
    # Exercise the compiled launcher without starting the deployment application.
    '[IO.File]::WriteAllText((Join-Path $PSScriptRoot "smoke-ok.txt"),"ok"); exit 0' |
        Set-Content (Join-Path $temporary 'App.ps1') -Encoding UTF8
    $process=Start-Process (Join-Path $temporary 'MasterSetup.exe') -PassThru
    if(!$process.WaitForExit(30000)){throw 'Compiled launcher smoke test timed out.'}
    $process.Refresh()
    if($process.ExitCode -ne 0){throw 'Compiled launcher returned a nonzero exit code.'}
    if(!(Test-Path (Join-Path $temporary 'smoke-ok.txt'))){throw 'Launcher did not run the test PowerShell script.'}
    Write-Host 'PASS: compiled x64 launcher executes a benign local script from a path with spaces.'
} finally {
    if($process -and !$process.HasExited){Stop-Process -Id $process.Id -Force}
    Remove-Item $temporary -Recurse -Force
}
