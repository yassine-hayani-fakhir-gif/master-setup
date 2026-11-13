$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$failed=@()
foreach($file in Get-ChildItem $root -Filter *.ps1 -Recurse -File){
    $tokens=$null;$errors=$null
    [void][Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
    foreach($error in $errors){$failed+="$($file.FullName):$($error.Extent.StartLineNumber): $($error.Message)"}
}
if($failed.Count){throw ($failed -join [Environment]::NewLine)}
& "$root\Kit\Validate.ps1"
# These checks protect the release policy, not antivirus detection.
foreach($file in Get-ChildItem "$root\Kit" -Filter *.ps1 -File){
    $code=Get-Content $file.FullName -Raw
    if($code -match 'Invoke-Expression|\bIEX\b|Set-MpPreference|Add-MpPreference|ExecutionPolicy\s+Bypass|https://get\.activated\.win'){
        throw "Unexpected execution/security pattern in $($file.Name)"
    }
}
Write-Host 'Source parser and non-destructive regression checks passed.'

& "$root\Tests\InterfaceChecks.ps1"

& "$root\Tests\InstallerChecks.ps1"

& "$root\Tests\LocalAppsChecks.ps1"

& "$root\Tests\PEChecks.ps1"

& "$root\Tests\OfflineProfilesChecks.ps1"

& "$root\Tests\AccountPasswordChecks.ps1"

& "$root\Tests\OfficeCompletionChecks.ps1"

& "$root\Tests\LanguageChecks.ps1"
