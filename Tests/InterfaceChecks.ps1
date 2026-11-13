# Non-destructive tests. No GUI, disk preparation or external installers are run.
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. "$root\Kit\Questions.ps1"
$script:testInputs=New-Object 'System.Collections.Generic.Queue[string]'
function Read-Host([string]$Prompt){$script:testInputs.Dequeue()}
$state=@{Testing=$true}
foreach($answer in @('o','O','oui','OuI','YES','y',' O ')){
    $script:testInputs.Enqueue($answer)
    if(!(Read-Yes 'Test')){throw "Case-insensitive confirmation failed: $answer"}
}
foreach($answer in @('n','N','non','NO',' n ')){
    $script:testInputs.Enqueue($answer)
    if(Read-Yes 'Test'){throw "Negative confirmation failed: $answer"}
}
$script:testInputs.Enqueue('wrong');$script:testInputs.Enqueue('O')
if(!(Read-Yes 'Retry')){throw 'Retry failed'}
Remove-Item Function:\Read-Host
. "$root\Kit\LiveCopy.ps1"
$testDir=Join-Path ([IO.Path]::GetTempPath()) ('master-test-'+[guid]::NewGuid())
[void][IO.Directory]::CreateDirectory($testDir)
try {
    $src=Join-Path $testDir 'source.bin';$dst=Join-Path $testDir 'copy.bin'
    $bytes=New-Object byte[] (3MB+17)
    $random=New-Object Random(42);$random.NextBytes($bytes)
    [IO.File]::WriteAllBytes($src,$bytes)
    Copy-AtelierFile $src $dst
    if((Get-FileHash $src).Hash -ne (Get-FileHash $dst).Hash){throw 'Copy mismatch'}
    if($state.Progress.Done -ne $bytes.Length -or $state.Progress.Total -ne $bytes.Length){throw 'Incorrect completed-byte progress'}
    if($state.Progress.Speed -lt 0){throw 'Invalid transfer speed'}
    $blocked=$false
    try {Copy-AtelierFile $src $dst} catch {$blocked=$true}
    if(!$blocked){throw 'Existing destination was overwritten'}
} finally {Remove-Item -LiteralPath $testDir -Recurse -Force}
Write-Host 'PASS: confirmation case, retry, copy integrity, byte progress and destination protection.'
