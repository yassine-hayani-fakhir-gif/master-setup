#Requires -RunAsAdministrator
$ErrorActionPreference='Stop'
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
# Official paired Microsoft links from the ADK download page, reviewed 2026-11-13.
$installers=@(
    @{Name='adksetup.exe';Url='https://go.microsoft.com/fwlink/?linkid=2289980';Feature='OptionId.DeploymentTools'},
    @{Name='adkwinpesetup.exe';Url='https://go.microsoft.com/fwlink/?linkid=2289981';Feature='OptionId.WindowsPreinstallationEnvironment'}
)
foreach($installer in $installers){
    $path=Join-Path $env:TEMP $installer.Name
    Invoke-WebRequest -Uri $installer.Url -OutFile $path -UseBasicParsing
    $signature=Get-AuthenticodeSignature -LiteralPath $path
    if($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch '(?:^|, )O=Microsoft Corporation(?:,|$)') {
        throw 'Microsoft ADK installer signature verification failed.'
    }
    Write-Host ('Installing Microsoft '+$installer.Name)
    $process=Start-Process -FilePath $path -ArgumentList @('/quiet','/norestart','/ceip','off','/features',$installer.Feature) -Wait -PassThru
    if($process.ExitCode -notin 0,3010){throw "ADK installer failed: $($process.ExitCode)"}
}
