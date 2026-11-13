#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidatePattern('^[A-Fa-f0-9]{40}$')][string]$Thumbprint,
    [Parameter(Mandatory=$true)][uri]$TimestampServer,
    [ValidateSet('CurrentUser','LocalMachine')][string]$Store='CurrentUser',
    [Parameter(Mandatory=$true)][string]$OutputDirectory
)
$ErrorActionPreference='Stop'
if($env:OS -ne 'Windows_NT'){throw 'Signing requires Windows, the Windows SDK and your signing certificate.'}
if($TimestampServer.Scheme -notin 'http','https'){throw 'Use the timestamp URL supplied by your certificate provider.'}
$root=Split-Path $PSScriptRoot -Parent
$output=[IO.Path]::GetFullPath($OutputDirectory)
$rootFull=[IO.Path]::GetFullPath($root).TrimEnd('\')
if($output.TrimEnd('\') -eq $rootFull -or $output.StartsWith($rootFull+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Choose a NEW output directory outside the source tree.'}
if(Test-Path -LiteralPath $output){throw 'Output directory already exists. Choose a new directory.'}
$tool=(Get-Command signtool.exe -CommandType Application -ErrorAction Stop).Source
$cert=Get-Item -LiteralPath ("Cert:\$Store\My\$Thumbprint")
if(!$cert.HasPrivateKey){throw 'The certificate has no accessible private key. Configure your provider/token on this PC.'}
if($cert.Subject -eq $cert.Issuer){throw 'Self-signed publisher certificates are not accepted by this release workflow.'}
if((Get-Date) -lt $cert.NotBefore -or (Get-Date) -gt $cert.NotAfter){throw 'Certificate is not currently valid.'}
$usages=@($cert.Extensions | Where-Object {$_ -is [Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension]} | ForEach-Object {$_.EnhancedKeyUsages} | ForEach-Object {$_.Value})
if('1.3.6.1.5.5.7.3.3' -notin $usages){throw 'Certificate is not authorized for code signing.'}
$chain=New-Object Security.Cryptography.X509Certificates.X509Chain
try {
    $chain.ChainPolicy.RevocationMode='Online'
    if(!$chain.Build($cert)){throw ('Certificate chain could not be validated: '+(($chain.ChainStatus | ForEach-Object {$_.StatusInformation}) -join '; '))}
} finally {$chain.Dispose()}
& "$PSScriptRoot\Test-Project.ps1"
if(!(Test-Path "$root\MasterSetup.exe") -or !(Test-Path "$root\Kit\DiskGuard.exe")){throw 'Build the native binaries before signing.'}
# Refuse deployment payloads and secrets before copying source to the release area.
$files=@(Get-ChildItem -LiteralPath $root -Recurse -File -Force)
foreach($file in $files){
    if($file.Extension -in '.pfx','.p12','.key','.iso','.img','.wim','.esd','.log' -or $file.Name -match '^(Autounattend\.xml|answer-\d+\.xml|options\.json|target\.ini|ui-language\.txt|\.env)$'){
        throw "Private/deployment material must be removed from the release tree: $($file.Name)"
    }
}
[void][IO.Directory]::CreateDirectory($output)
$stage=Join-Path $output 'MasterSetup'
[void][IO.Directory]::CreateDirectory($stage)
try {
    foreach($file in $files){
        $relative=$file.FullName.Substring($rootFull.Length+1)
        if($relative -match '(^|[\\/])\.git([\\/]|$)' -or $file.Extension -in '.o','.obj','.a','.pdb','.pyc'){continue}
        $destination=Join-Path $stage $relative
        [void][IO.Directory]::CreateDirectory((Split-Path $destination -Parent))
        Copy-Item -LiteralPath $file.FullName -Destination $destination
    }
    $targets=@(Get-ChildItem -LiteralPath $stage -Recurse -File | Where-Object {$_.Extension -in '.ps1','.psm1','.psd1','.exe','.dll'})
    foreach($file in $targets){
        $arguments=@('sign','/s','My','/sha1',$Thumbprint,'/fd','SHA256','/tr',$TimestampServer.AbsoluteUri,'/td','SHA256','/d','Master Setup')
        if($Store -eq 'LocalMachine'){$arguments+='/sm'}
        $arguments+=$file.FullName
        & $tool @arguments
        if($LASTEXITCODE -ne 0){throw "Signing/timestamping failed: $($file.Name)"}
        & $tool verify /pa /all /tw $file.FullName
        if($LASTEXITCODE -ne 0){throw "Signature verification failed: $($file.Name)"}
        $signature=Get-AuthenticodeSignature -LiteralPath $file.FullName
        if($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Thumbprint -ne $Thumbprint -or !$signature.TimeStamperCertificate){throw "Missing valid publisher signature or timestamp: $($file.Name)"}
    }
    # Verify signed source still parses and passes non-destructive checks.
    & "$stage\scripts\Test-Project.ps1"
    $manifest=Join-Path $stage 'SHA256SUMS.txt'
    $lines=@(Get-ChildItem -LiteralPath $stage -Recurse -File -Force | Where-Object {$_.FullName -ne $manifest} | Sort-Object FullName | ForEach-Object {
        (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()+'  '+$_.FullName.Substring($stage.Length+1).Replace('\','/')
    })
    [IO.File]::WriteAllLines($manifest,$lines,[Text.UTF8Encoding]::new($false))
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive=Join-Path $output 'MasterSetup_0.18.1_signed_preview_x64.zip'
    [IO.Compression.ZipFile]::CreateFromDirectory($stage,$archive,[IO.Compression.CompressionLevel]::Optimal,$true)
    $archiveHash=(Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText(($archive+'.sha256'),$archiveHash+'  '+[IO.Path]::GetFileName($archive),[Text.UTF8Encoding]::new($false))
    Write-Host "Signed and verified release: $archive"
    Write-Host 'A valid signature does not guarantee immediate SmartScreen reputation.'
} catch {
    [IO.File]::WriteAllText((Join-Path $output 'SIGNING-FAILED.txt'),'DO NOT DISTRIBUTE: signing or validation did not complete. Review the console error.')
    throw
}
