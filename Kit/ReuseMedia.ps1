function Copy-ReusableMedia {
    param($Files,[string]$SourceRoot,[string]$TargetRoot,[string]$UsbRoot,[string]$FileSystem)
    $candidates=@()
    if($FileSystem -eq 'NTFS') {
        $candidates=@(Get-ChildItem (Join-Path $UsbRoot 'AtelierAuto') -Directory -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | ForEach-Object { Join-Path $_.FullName 'Media' } |
            Where-Object { $_ -ne $TargetRoot -and (Test-Path (Join-Path $_ 'setup.exe')) } | Select-Object -First 3)
    }
    [long]$reused=0;[long]$copied=0;$counter=0
    $timer=[Diagnostics.Stopwatch]::StartNew();$last=-5000
    foreach($file in $Files) {
        $counter++
        $relative=$file.FullName.Substring($SourceRoot.Length)
        $targetFile=Join-Path $TargetRoot $relative
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($targetFile))
        $linked=$false;$sourceHash=$null
        if($file.Length -ge 1MB) {
            foreach($candidate in $candidates) {
                $old=Join-Path $candidate $relative
                if(!(Test-Path -LiteralPath $old -PathType Leaf)){continue}
                if((Get-Item -LiteralPath $old).Length -ne $file.Length){continue}
                Write-Host "SHA256 verification before reuse: $relative ($([math]::Round($file.Length/1MB)) MiB). Reading; identical verified files will be reused."
                if(!$sourceHash){$sourceHash=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash}
                if((Get-FileHash -LiteralPath $old -Algorithm SHA256).Hash -ne $sourceHash){continue}
                New-Item -ItemType HardLink -Path $targetFile -Target $old -ErrorAction Stop | Out-Null
                $reused+=$file.Length;$linked=$true
                Write-Host "Verified and reused: $relative"
                break
            }
        }
        if(!$linked){Copy-AtelierFile $file.FullName $targetFile;$copied+=$file.Length}
        if($timer.ElapsedMilliseconds-$last -ge 2500){
            $last=$timer.ElapsedMilliseconds
            Write-Host ("Media : {0}/{1} files | reused {2:N0} MiB | copied {3:N0} MiB" -f $counter,$Files.Count,($reused/1MB),($copied/1MB))
        }
    }
    Write-Host ("Media ready: reused {0:N0} MiB, copied {1:N0} MiB. Original ISO files unchanged." -f ($reused/1MB),($copied/1MB))
}
