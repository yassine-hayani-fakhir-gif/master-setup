function Copy-AtelierFile($source,$destination) {
    if($state){$state.Stage='Copy: '+[IO.Path]::GetFileName($source);$state.Progress=$null}
    $reader = [IO.File]::OpenRead($source)
    try {
        $writer = [IO.File]::Open($destination,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
        try {
            $buf = $script:copyBuffer
            if (!$buf) { $script:copyBuffer = New-Object byte[] (2MB); $buf = $script:copyBuffer }
            $timer = [Diagnostics.Stopwatch]::StartNew()
            $mark = 0
            while (($read = $reader.Read($buf,0,$buf.Length)) -gt 0) {
                $writer.Write($buf,0,$read)
                if($state){$state.Progress=@{Done=$reader.Position;Total=$reader.Length;Speed=($reader.Position/1MB/[math]::Max(0.001,$timer.Elapsed.TotalSeconds))}}
                if ($timer.ElapsedMilliseconds - $mark -ge 1500) {
                    $mark = $timer.ElapsedMilliseconds
                    Write-Host ('{0}   {1:P0}   {2:N0}/{3:N0} MiB   {4:N1} MiB/s' -f [IO.Path]::GetFileName($source),($reader.Position/[double]$reader.Length),($reader.Position/1MB),($reader.Length/1MB),($reader.Position/1MB/$timer.Elapsed.TotalSeconds))
                }
            }
            if($reader.Length -ge 1MB -or $timer.ElapsedMilliseconds -ge 1500){Write-Host ('Copy completed: {0} | {1:N0} MB | 100% | {2:N1} MB/s | {3:N1} s' -f [IO.Path]::GetFileName($source),($reader.Length/1MB),($reader.Length/1MB/[math]::Max(0.001,$timer.Elapsed.TotalSeconds)),$timer.Elapsed.TotalSeconds)}
        } finally { $writer.Dispose() }
    } finally { $reader.Dispose() }
}
function Copy-AtelierTree($files,$sourceRoot,$targetRoot) {
    $clock = [Diagnostics.Stopwatch]::StartNew()
    $mark = -3000
    foreach ($file in $files) {
        $relative = $file.FullName.Substring($sourceRoot.Length)
        $target = Join-Path $targetRoot $relative
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))
        if ($clock.ElapsedMilliseconds - $mark -ge 2500 -or $file.Length -ge 100MB) {
            Write-Host "Copy: $relative"
            $mark = $clock.ElapsedMilliseconds
        }
        Copy-AtelierFile $file.FullName $target
    }
}
