function Get-MasterInternetState {
    $manager=$null
    try {
        $manager=New-Object -ComObject NetworkListManager
        if($manager.IsConnectedToInternet){return 'Online'}
        return 'Offline'
    } catch {return 'Unknown'}
    finally {if($manager){[void][Runtime.InteropServices.Marshal]::ReleaseComObject($manager)}}
}
function Test-MasterInstaller {
    param([string]$Path,[string]$ExpectedHash,[string]$ExpectedSigner)
    if($ExpectedHash -notmatch '^[A-Fa-f0-9]{64}$' -or [string]::IsNullOrWhiteSpace($ExpectedSigner)){throw 'Installer identity is missing from the profile.'}
    if(!(Test-Path -LiteralPath $Path -PathType Leaf)){throw 'Installer not found on USB.'}
    if((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -ne $ExpectedHash){throw 'Installer changed since preparation.'}
    $sig=Get-AuthenticodeSignature -LiteralPath $Path
    if($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Thumbprint -ne $ExpectedSigner){throw 'Installer signature is invalid or different.'}
}

function Find-MasterWinGet {
    $command=Get-Command winget.exe -CommandType Application -ErrorAction SilentlyContinue
    if($command){return $command.Source}
    foreach($package in @(Get-AppxPackage -Name Microsoft.DesktopAppInstaller -ErrorAction SilentlyContinue)){
        if($package.InstallLocation){
            $candidate=Join-Path $package.InstallLocation 'winget.exe'
            if(Test-Path -LiteralPath $candidate -PathType Leaf){return $candidate}
        }
    }
    return $null
}
function Resolve-MasterWinGet {
    $candidate=Find-MasterWinGet
    if($candidate){return $candidate}
    Write-Host 'Apps: registering App Installer for this user...'
    try {Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe -ErrorAction Stop}
    catch {Write-Host ('App Installer : '+$_.Exception.Message)}
    for($attempt=0;$attempt -lt 10;$attempt++){
        $candidate=Find-MasterWinGet
        if($candidate){return $candidate}
        Start-Sleep -Seconds 2
    }
    throw 'PENDING: WinGet unavailable. Install or update App Installer from Microsoft Store, then resume. Alternatively use local full installers.'
}
