$ErrorActionPreference='Stop'
. "$PSScriptRoot\..\Kit\Language.ps1"
. "$PSScriptRoot\..\Kit\Welcome.ps1"
$normal=@(Get-MasterStartupRoutes $false)
$boot=@(Get-MasterStartupRoutes $true)
if(($normal.Id -join ',') -ne 'Dashboard,Auto,Apps,BootGuide'){throw 'Unexpected Windows routes.'}
if($boot.Count -ne 1 -or $boot[0].Id -ne 'DeployPE'){throw 'WinPE must only offer the supported clean-install route.'}
foreach($language in 'fr','ar','es') {
    $env:MASTERSETUP_LANG=$language
    foreach($route in @($normal)+@($boot)) {
        if((M $route.Title) -eq $route.Title -or (M $route.Detail) -eq $route.Detail){throw "Missing startup route translation: $language"}
    }
}
$env:MASTERSETUP_LANG='en'
Write-Host 'PASS: startup routes are environment-specific and fully translated in French, Arabic and Spanish.'
