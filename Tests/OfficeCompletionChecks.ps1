. "$PSScriptRoot\..\Kit\OfficeCompletion.ps1"
if(!(Test-MasterOfficeSuccessText @('Tout est prêt !','Les applications Microsoft 365 et Office sont installés sur votre ordinateur.'))){throw 'French success not recognized'}
if(!(Test-MasterOfficeSuccessText @("You're all set!",'Microsoft 365 and Office are installed on your computer.'))){throw 'English success not recognized'}
if(Test-MasterOfficeSuccessText @('Installing Office','Close')){throw 'Installing is not success'}
if(Test-MasterOfficeSuccessText @('Something went wrong','Close')){throw 'Error is not success'}
if(Test-MasterOfficeSuccessText @('Tout est prêt !','An unrelated app')){throw 'Office confirmation required'}
Write-Host 'PASS: recognized Office success text only; no active installation or error closure.'
