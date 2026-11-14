#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [string]$WindowsIso,
    [Parameter(Mandatory=$true)][string]$OutputFolder,
    [string]$OfficeImage,
    [string]$AppsFolder,
    [string]$AdkRoot="${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit"
)
$ErrorActionPreference='Stop'
if(![Environment]::Is64BitProcess){throw 'PowerShell x64 requis.'}
if($WindowsIso){$WindowsIso=(Resolve-Path -LiteralPath $WindowsIso).Path}
$OutputFolder=[IO.Path]::GetFullPath($OutputFolder)
if($OfficeImage){
    $OfficeImage=(Resolve-Path -LiteralPath $OfficeImage).Path
    if([IO.Path]::GetExtension($OfficeImage) -notin '.iso','.img'){throw 'Office must be an ISO or IMG file.'}
}
if($AppsFolder){
    $AppsFolder=(Resolve-Path -LiteralPath $AppsFolder).Path
    if(!(Test-Path -LiteralPath $AppsFolder -PathType Container)){throw 'AppsFolder must be a directory.'}
}

if(Test-Path -LiteralPath $OutputFolder){throw 'Choisir un nouveau dossier de sortie vide (inexistant).'}
# Paths used by ADK batch scripts must not contain command-shell metacharacters.
foreach($path in @($OutputFolder,$AdkRoot)){if($path -match '["%!?&|<>^\r\n]'){throw 'Choisir un chemin sans caracteres speciaux pour les outils ADK.'}}
$peRoot=Join-Path $AdkRoot 'Windows Preinstallation Environment'
$deployRoot=Join-Path $AdkRoot 'Deployment Tools'
$copype=Join-Path $peRoot 'copype.cmd'
$make=Join-Path $peRoot 'MakeWinPEMedia.cmd'
$envCmd=Join-Path $deployRoot 'DandISetEnv.bat'
$oc=Join-Path $peRoot 'amd64\WinPE_OCs'
foreach($file in @($copype,$make,$envCmd,(Join-Path $oc 'WinPE-PowerShell.cab'))){if(!(Test-Path -LiteralPath $file)){throw 'Installer Windows ADK (Deployment Tools) et le module complementaire Windows PE avant de lancer ce script.'}}
$root=Split-Path $PSScriptRoot -Parent
$work=Join-Path $OutputFolder 'WinPE-build'
[void][IO.Directory]::CreateDirectory($OutputFolder)
$mounted=$false;$isoMounted=$false
function Invoke-AdkBatch([string]$Command) {
    $batch=Join-Path $OutputFolder 'adk-step.cmd'
    $lines=@('@echo off','setlocal DisableDelayedExpansion',('call "'+$envCmd+'"'),'if errorlevel 1 exit /b 1',$Command,'exit /b %errorlevel%')
    [IO.File]::WriteAllLines($batch,$lines,[Text.Encoding]::Default)
    & $env:ComSpec /d /c $batch
    if($LASTEXITCODE -ne 0){throw "ADK command failed: $LASTEXITCODE"}
}
function Run-Dism([string[]]$Arguments){& dism.exe @Arguments;if($LASTEXITCODE -ne 0){throw "DISM exit $LASTEXITCODE"}}
try {
    Invoke-AdkBatch ('call "'+$copype+'" amd64 "'+$work+'"')
    if($LASTEXITCODE -ne 0){throw 'Creation du dossier WinPE refusee par ADK.'}
    $mount=Join-Path $work 'mount';$wim=Join-Path $work 'media\sources\boot.wim'
    Run-Dism @('/Mount-Image',"/ImageFile:$wim",'/Index:1',"/MountDir:$mount")
    $mounted=$true
    foreach($package in @('WinPE-WMI','WinPE-SecureStartup','WinPE-NetFX','WinPE-Scripting','WinPE-PowerShell','WinPE-StorageWMI','WinPE-DismCmdlets')){
        Run-Dism @("/Image:$mount",'/Add-Package',('/PackagePath:'+(Join-Path $oc ($package+'.cab'))))
        $language=Join-Path $oc ('en-us\'+$package+'_en-us.cab')
        if(Test-Path -LiteralPath $language){Run-Dism @("/Image:$mount",'/Add-Package',"/PackagePath:$language")}
    }
    Run-Dism @("/Image:$mount",'/Set-ScratchSpace:512')
    $app=Join-Path $mount 'MasterSetup'
    [void][IO.Directory]::CreateDirectory($app)
    Copy-Item -LiteralPath (Join-Path $root 'Kit') -Destination (Join-Path $app 'Kit') -Recurse
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Boot.ps1') -Destination (Join-Path $app 'Boot.ps1')
    $drivers=Join-Path $root 'Kit\Drivers\WinPE'
    if(@(Get-ChildItem -LiteralPath $drivers -Filter *.inf -Recurse -ErrorAction SilentlyContinue).Count){Run-Dism @("/Image:$mount",'/Add-Driver',"/Driver:$drivers",'/Recurse')}
    $start=@('@echo off','wpeinit','powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy RemoteSigned -File X:\MasterSetup\Boot.ps1','echo Master Setup closed. Logs are on X: or in the local MasterStage folder.','cmd.exe')
    [IO.File]::WriteAllLines((Join-Path $mount 'Windows\System32\startnet.cmd'),$start,[Text.Encoding]::ASCII)
    Run-Dism @('/Unmount-Image',"/MountDir:$mount",'/Commit');$mounted=$false
    $bootIso=Join-Path $OutputFolder 'MasterSetup-WinPE-x64.iso'
    Invoke-AdkBatch ('call "'+$make+'" /ISO "'+$work+'" "'+$bootIso+'"')
    if($LASTEXITCODE -ne 0){throw 'Creation ISO WinPE echouee.'}
    . "$root\Kit\LiveCopy.ps1"
    . "$root\Kit\PEHelpers.ps1"
    [void][IO.Directory]::CreateDirectory((Join-Path $OutputFolder 'MasterSetupMedia\Windows'))
    if($WindowsIso){
    $image=Get-DiskImage -ImagePath $WindowsIso
    if(!$image.Attached){$image=Mount-DiskImage -ImagePath $WindowsIso -PassThru;$isoMounted=$true}
    $volume=@($image|Get-Volume|Where-Object DriveLetter)
    if($volume.Count -ne 1){throw 'ISO Windows : volume ambigu.'}
    $sourceRoot=[string]$volume[0].DriveLetter+':\sources'
    $candidates=@('install.wim','install.esd'|ForEach-Object {Join-Path $sourceRoot $_}|Where-Object {Test-Path -LiteralPath $_})
    if($candidates.Count -ne 1){throw 'ISO standard avec un install.wim ou install.esd requis. Images SWM non gerees.'}
    $media=Join-Path $OutputFolder 'MasterSetupMedia\Windows'
    [void][IO.Directory]::CreateDirectory($media)
    Copy-PEVerified $candidates[0] (Join-Path $media ([IO.Path]::GetFileName($candidates[0])))
    } else {
        Write-Host 'BOOT ISO ONLY: provide your own Windows install.wim/install.esd in MasterSetupMedia\Windows.'
    }
    foreach($folder in @('Office','Apps')){[void][IO.Directory]::CreateDirectory((Join-Path $OutputFolder ('MasterSetupMedia\'+$folder)))}
    if($OfficeImage){Copy-PEVerified $OfficeImage (Join-Path $OutputFolder ('MasterSetupMedia\Office\'+[IO.Path]::GetFileName($OfficeImage)))}
    if($AppsFolder){
        foreach($package in Get-ChildItem -LiteralPath $AppsFolder -File | Where-Object {$_.Extension -in '.exe','.msi'}) {
            Copy-PEVerified $package.FullName (Join-Path $OutputFolder ('MasterSetupMedia\Apps\'+$package.Name))
        }
    }
    $isoHash=(Get-FileHash -LiteralPath $bootIso -Algorithm SHA256).Hash.ToLowerInvariant()
    "$isoHash  MasterSetup-WinPE-x64.iso" | Set-Content (Join-Path $OutputFolder 'SHA256SUMS.txt') -Encoding ASCII
    Copy-Item (Join-Path $root 'docs\BOOT_MODE.md') (Join-Path $OutputFolder 'BOOT_MODE.md')
    @{
        Application='Master Setup Boot Preview';Version='0.19-experimental'
        SourceCommit=$env:GITHUB_SHA;WorkflowRun=$env:GITHUB_RUN_ID
        BuiltUtc=[DateTime]::UtcNow.ToString('o');IncludesWindowsInstallImage=[bool]$WindowsIso
        ApplicationSigning='Unsigned';BootTest='Not performed'
    } | ConvertTo-Json | Set-Content (Join-Path $OutputFolder 'BUILD.json') -Encoding UTF8
    Write-Host 'READY: copy MasterSetup-WinPE-x64.iso and MasterSetupMedia onto your existing Ventoy data partition.'
    Write-Host 'Add Office ISO/IMG and standalone app installers to their folders. Boot this ISO in UEFI mode.'
    Write-Host 'The WinPE-build folder is build workspace only; do not copy it to USB.'
} finally {
    if($mounted){& dism.exe /Unmount-Image "/MountDir:$mount" /Discard | Out-Host}
    if($isoMounted){Dismount-DiskImage -ImagePath $WindowsIso | Out-Null}
}
