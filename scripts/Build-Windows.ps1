$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
& "$PSScriptRoot\Test-Project.ps1"
$compiler=Get-Command clang-cl.exe -ErrorAction Stop
$build=Join-Path $env:TEMP ('MasterSetupBuild-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $build | Out-Null
Push-Location $build
try {
    & $compiler.Source /nologo /O1 /GS- /Zl /W3 "$root\src\Launcher.c" "/Fe:$root\MasterSetup.exe" /link /nodefaultlib /entry:entry /subsystem:windows /dynamicbase /nxcompat kernel32.lib user32.lib
    if($LASTEXITCODE -ne 0){throw 'Launcher compilation failed.'}
    & $compiler.Source /nologo /O1 /GS- /Zl /W3 "$root\Kit\native\DiskGuard.c" "/Fe:$root\Kit\DiskGuard.exe" /link /nodefaultlib /entry:entry /subsystem:console /dynamicbase /nxcompat kernel32.lib
    if($LASTEXITCODE -ne 0){throw 'DiskGuard compilation failed.'}
} finally {Pop-Location;Remove-Item $build -Recurse -Force}
Write-Host 'Unsigned build complete. Review and Authenticode-sign before a public release.'
