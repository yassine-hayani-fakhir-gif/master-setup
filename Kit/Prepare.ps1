# Yassine Hayani Fakhir | Windows PowerShell 5.1 x64
#Requires -RunAsAdministrator
param([string]$MediaRoot, [string]$Activation = 'Licence', [switch]$AutoLogon)
$ErrorActionPreference = 'Stop'
$root = if ($MediaRoot) { $MediaRoot } else { [IO.Path]::GetPathRoot($PSScriptRoot) }
if ((!$MediaRoot -and (!(Test-Path ($root+'sources\boot.wim')) -or !(Test-Path ($root+'setup.exe')))) -or $root -eq ($env:SystemDrive+'\')) {
    throw 'Extract Kit onto the writable Windows installer USB and run Prepare there.'
}
$answer = Join-Path $root 'Autounattend.xml'
$payload = Join-Path $root 'sources\$OEM$\$1\SetupKit'
if ((Test-Path $answer) -or (Test-Path $payload)) { throw 'Existing answer file or SetupKit found. Review and remove it before preparing again.' }
do {
    $name = Read-Host 'Administrator account name'
    $ok = $name.Length -in (1..20) -and $name -eq $name.Trim() -and $name -notmatch '["/\\\[\]:;|=,+*?<>\x00-\x1f]' -and $name -notmatch '^[. ]+$|[.]$|^(Administrator|Administrateur|Guest|Invité|DefaultAccount|WDAGUtilityAccount|defaultuser0|CON|PRN|NUL|AUX|COM[1-9]|LPT[1-9])$'
    if (!$ok) { Write-Host 'Invalid or reserved account name. Correct only the name.' }
} until ($ok)
do {
    $pc = Read-Host 'Computer name (Enter = automatic)'
    if (!$pc) { $pc = '*' }
    $ok = ($pc -eq '*' -or ($pc -match '^(?![0-9]+$)[A-Za-z0-9](?:[A-Za-z0-9-]{0,13}[A-Za-z0-9])?$' -and $pc -ne $name))
    if (!$ok) { Write-Host 'Choose a different computer name, 1 to 15 characters.' }
} until ($ok)
$name = [Security.SecurityElement]::Escape($name)
function Get-TextPassword($prompt) {
    $s = Read-Host $prompt -AsSecureString
    try { [Net.NetworkCredential]::new('', $s).Password } finally { $s.Dispose() }
}
do {
    $pass = Get-TextPassword 'Optional password (Enter = no password)'
    $ok = !$pass -or $pass -ceq (Get-TextPassword 'Confirm password')
    if (!$ok) { Write-Host 'Passwords do not match. Re-enter only the password.' }
} until ($ok)
. "$PSScriptRoot\AccountPassword.ps1"
$passwordXml = New-AccountPasswordXml -Password $pass
if ($state) {
    $state.AccountReview=[ordered]@{Name=[Net.WebUtility]::HtmlDecode($name);ComputerName=$pc;Password=if($pass){'Set (hidden)'}else{'No password'}}
    $state.PlannedName=if($pc -eq '*'){'Automatic'}else{$pc}
}
$autoXml = ''
if ($AutoLogon) {
    $autoPass = $passwordXml
    $autoXml = "<AutoLogon>$autoPass<Enabled>true</Enabled><LogonCount>1</LogonCount><Username>$name</Username></AutoLogon>"
}
$pass = $null
$xml = @"
<unattend xmlns="urn:schemas-microsoft-com:unattend" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
<settings pass="specialize"><component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS"><ComputerName>$pc</ComputerName></component></settings>
<settings pass="oobeSystem"><component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
$autoXml
<OOBE><HideEULAPage>true</HideEULAPage><HideOnlineAccountScreens>true</HideOnlineAccountScreens><ProtectYourPC>3</ProtectYourPC></OOBE>
<UserAccounts><LocalAccounts><LocalAccount wcm:action="add">$passwordXml<Group>Administrators</Group><Name>$name</Name></LocalAccount></LocalAccounts></UserAccounts>
<FirstLogonCommands><SynchronousCommand wcm:action="add"><Order>1</Order><Description>Yassine Setup Kit</Description><CommandLine>cmd.exe /c "%SystemDrive%\SetupKit\Finish.cmd"</CommandLine></SynchronousCommand></FirstLogonCommands>
</component></settings></unattend>
"@
try {
    New-Item -ItemType Directory -Path $payload -Force | Out-Null
    Write-Host 'Writing account and deployment files...'
    foreach ($file in 'Finish.cmd','Finish.ps1','Suivi.ps1','InstallHelpers.ps1','LocalApps.ps1','OfficeCompletion.ps1','Language.ps1','languages.json') { Copy-Item (Join-Path $PSScriptRoot $file) $payload }
    Set-Content -LiteralPath (Join-Path $payload 'ui-language.txt') -Value $(if($env:MASTERSETUP_LANG -in 'en','fr','ar','es'){$env:MASTERSETUP_LANG}else{'en'})
    Set-Content -LiteralPath (Join-Path $payload 'activation.txt') -Value $Activation
    [IO.File]::WriteAllText($answer, $xml, [Text.UTF8Encoding]::new($false))
} catch {
    Remove-Item -LiteralPath $payload -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $answer -Force -ErrorAction SilentlyContinue
    throw
}
if (!$MediaRoot) { Write-Host 'Ready. Back up the target, unplug other disks, boot this USB in UEFI mode. Read GUIDE.txt.' }
