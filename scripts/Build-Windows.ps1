$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
& "$PSScriptRoot\Test-Project.ps1"
$compiler=Get-Command clang-cl.exe -ErrorAction Stop
$build=Join-Path $env:TEMP ('MasterSetupBuild-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $build | Out-Null
Push-Location $build
try {
    $rc=Get-Command rc.exe -ErrorAction Stop
    foreach($name in @('Launcher','DiskGuard')) {
        & $rc.Source /nologo "/fo$name.res" "$root\src\$name.rc"
        if($LASTEXITCODE -ne 0){throw "Resource compilation failed: $name"}
    }
    & $compiler.Source /nologo /O1 /clang:-ffreestanding /clang:-fno-builtin /GS- /Zl /W3 "$root\src\Launcher.c" Launcher.res "/Fe:$root\MasterSetup.exe" /link /nodefaultlib /entry:entry /subsystem:windows /dynamicbase /nxcompat kernel32.lib user32.lib
    if($LASTEXITCODE -ne 0){throw 'Launcher compilation failed.'}
    & $compiler.Source /nologo /O1 /clang:-ffreestanding /clang:-fno-builtin /GS- /Zl /W3 "$root\Kit\native\DiskGuard.c" DiskGuard.res "/Fe:$root\Kit\DiskGuard.exe" /link /nodefaultlib /entry:entry /subsystem:console /dynamicbase /nxcompat kernel32.lib
    if($LASTEXITCODE -ne 0){throw 'DiskGuard compilation failed.'}
} finally {Pop-Location;Remove-Item $build -Recurse -Force}
Write-Host 'Unsigned build complete. Review and Authenticode-sign before a public release.'

foreach($binary in @("$root\MasterSetup.exe", "$root\Kit\DiskGuard.exe")) {
    $info=(Get-Item $binary).VersionInfo
    if($info.ProductName -ne 'Master Setup' -or $info.ProductVersion -ne '0.18.1.0') {
        throw "Unexpected product metadata: $binary"
    }
    if((Get-AuthenticodeSignature $binary).Status -ne 'NotSigned') {
        throw "Expected an unsigned CI build: $binary"
    }
}
