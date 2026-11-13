$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$out=Join-Path $root 'dist'
if(Test-Path $out){throw 'dist already exists. Use a clean checkout for packaging.'}
$stage=Join-Path $out 'MasterSetup'
New-Item -ItemType Directory $stage -Force | Out-Null
Push-Location $root
try {
    $files=@(& git ls-files)
    if($LASTEXITCODE -ne 0){throw 'Cannot enumerate tracked source files.'}
    foreach($file in $files) {
        if($file -match '^\.github/'){continue}
        $destination=Join-Path $stage $file
        New-Item -ItemType Directory (Split-Path $destination -Parent) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $root $file) -Destination $destination
    }
    foreach($binary in @('MasterSetup.exe','Kit/DiskGuard.exe')) {
        Copy-Item -LiteralPath (Join-Path $root $binary) -Destination (Join-Path $stage $binary)
    }
    $commit=(& git rev-parse HEAD).Trim()
    if($LASTEXITCODE -ne 0){throw 'Cannot resolve source commit.'}
    @{
        version='0.18.1.0'; signingStatus='UNSIGNED'; sourceCommit=$commit
        repository='https://github.com/yassine-hayani-fakhir-gif/master-setup'
        workflowRun=$env:GITHUB_RUN_ID; builtUtc=[DateTime]::UtcNow.ToString('o')
    } | ConvertTo-Json | Set-Content (Join-Path $stage 'BUILD.json') -Encoding UTF8
    $hashes=Get-ChildItem $stage -File -Recurse | Sort-Object FullName | ForEach-Object {
        $relative=$_.FullName.Substring($stage.Length+1).Replace('\','/')
        '{0}  {1}' -f (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant(),$relative
    }
    $hashes | Set-Content (Join-Path $stage 'SHA256SUMS.txt') -Encoding ASCII
    $zip=Join-Path $out 'MasterSetup_0.18.1_preview_UNSIGNED_x64.zip'
    Compress-Archive -Path $stage -DestinationPath $zip
    '{0}  {1}' -f (Get-FileHash $zip -Algorithm SHA256).Hash.ToLowerInvariant(),(Split-Path $zip -Leaf) |
        Set-Content (Join-Path $out 'SHA256SUMS.txt') -Encoding ASCII
} finally {Pop-Location}
