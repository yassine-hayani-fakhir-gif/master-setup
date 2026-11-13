#Requires -RunAsAdministrator
param([ValidateSet('Finish','Auto','Apps','DeployPE')][string]$Task,[string]$ProfileRoot)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
. "$PSScriptRoot\Language.ps1"
$lock=New-Object Threading.Mutex($false,'Local\AtelierWin8Execution')
try { $acquired=$lock.WaitOne(0) } catch [Threading.AbandonedMutexException] { $acquired=$true }
if (!$acquired) { [void][Windows.Forms.MessageBox]::Show('A Master Setup operation is already running.'); return }
$dir=Join-Path $env:LOCALAPPDATA 'AtelierWindows\Journaux'
[void][IO.Directory]::CreateDirectory($dir)
$logPath=Join-Path $dir ((Get-Date -Format yyyyMMdd-HHmmss)+'-'+$Task+'.log')
$queue=New-Object 'System.Collections.Concurrent.ConcurrentQueue[string]'
$wake=New-Object Threading.AutoResetEvent($false)
$state=[hashtable]::Synchronized(@{Prompt=$null; Answer=$null; Failed=$false; Warnings=$false; Cancelled=$false})
$state.ProfileRoot=$ProfileRoot
$f=New-Object Windows.Forms.Form
$f.Text="Master Setup 0.18.1-preview | Progress - $Task"
$f.StartPosition='CenterScreen'
$wa=[Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$f.Size=New-Object Drawing.Size([Math]::Min(960,$wa.Width-24),[Math]::Min(740,$wa.Height-24))
$f.MinimumSize=New-Object Drawing.Size(535,375)
$f.Font=New-Object Drawing.Font('Segoe UI',10)
$f.BackColor=[Drawing.ColorTranslator]::FromHtml('#101D34');$f.ForeColor=[Drawing.ColorTranslator]::FromHtml('#EAF0FF')
$top=New-Object Windows.Forms.Label
$top.Dock='Top'; $top.Height=52; $top.TextAlign='MiddleLeft'
$top.BackColor=[Drawing.Color]::FromArgb(20,40,62); $top.ForeColor=[Drawing.Color]::White
$box=New-Object Windows.Forms.RichTextBox
$box.BackColor=[Drawing.ColorTranslator]::FromHtml('#0A1120');$box.ForeColor=[Drawing.ColorTranslator]::FromHtml('#A7E8D8');$box.BorderStyle='None'
$box.Dock='Fill'; $box.ReadOnly=$true; $box.Font=New-Object Drawing.Font('Consolas',10)
$bottom=New-Object Windows.Forms.Panel
$bottom.Dock='Bottom'; $bottom.Height=130
$label=New-Object Windows.Forms.Label
$label.SetBounds(10,4,480,46); $label.Anchor='Top,Left,Right'
$field=New-Object Windows.Forms.TextBox
$field.SetBounds(10,55,450,28); $field.Anchor='Top,Left,Right'
$ok=New-Object Windows.Forms.Button
$ok.SetBounds(474,52,116,34); $ok.Anchor='Top,Right'; $ok.Text='Continue';$ok.FlatStyle='Flat';$ok.BackColor=[Drawing.ColorTranslator]::FromHtml('#53E4D0');$ok.ForeColor=[Drawing.ColorTranslator]::FromHtml('#0A1120')
# Give the panel its final width before anchor calculations.
$bottom.Width=$f.ClientSize.Width
$field.Width=$bottom.Width-154
$label.Width=$bottom.Width-22
$ok.Left=$bottom.Width-132
$bottom.Controls.AddRange(@($label,$field,$ok))
$statusPanel=New-Object Windows.Forms.Panel
$statusPanel.Dock='Top';$statusPanel.Height=130
$stageLabel=New-Object Windows.Forms.Label
$stageLabel.SetBounds(18,12,740,52);$stageLabel.Anchor='Top,Left,Right'
$stageLabel.Font=New-Object Drawing.Font('Segoe UI',13,[Drawing.FontStyle]::Bold)
$stageLabel.Text='Preparing your installation'
$progress=New-Object Windows.Forms.ProgressBar
$progress.SetBounds(18,71,740,12);$progress.Anchor='Top,Left,Right';$progress.Style='Marquee';$progress.MarqueeAnimationSpeed=30
$metrics=New-Object Windows.Forms.Label
$metrics.SetBounds(18,94,740,34);$metrics.Anchor='Top,Left,Right'
$metrics.ForeColor=[Drawing.ColorTranslator]::FromHtml('#53E4D0')
$statusPanel.Controls.AddRange(@($stageLabel,$progress,$metrics))
$journal=New-Object Windows.Forms.Button
$journal.Text='Open detailed log';$journal.SetBounds(10,95,180,28)
$journal.FlatStyle='Flat';$journal.ForeColor=[Drawing.ColorTranslator]::FromHtml('#A78BFA')
$journal.Add_Click({if(Test-Path -LiteralPath $logPath){Start-Process notepad.exe -ArgumentList ('"'+$logPath+'"')}})
$bottom.Controls.Add($journal)
$skipApp=New-Object Windows.Forms.Button
$skipApp.Text='Skip this app';$skipApp.SetBounds(205,95,235,28);$skipApp.Enabled=$false
$skipApp.Add_Click({
    if(!$state.AppWaiting){return}
    $waitingIndex=$state.AppIndex
    $answer=[Windows.Forms.MessageBox]::Show($f,'Confirm that this installer is no longer working. Its process will NOT be closed. This app will remain unverified and the next app will start. Continue?','Skip without recording success','YesNo','Warning','Button2')
    if($answer -eq 'Yes' -and $state.AppWaiting -and $state.AppIndex -eq $waitingIndex){$state.SkipApp=$true}
})
$bottom.Controls.Add($skipApp)
$box.Font=New-Object Drawing.Font('Segoe UI',11)
$identityPanel=New-Object Windows.Forms.Label
$identityPanel.Dock='Top';$identityPanel.Height=80;$identityPanel.Padding=New-Object Windows.Forms.Padding(14,6,14,6)
$identityPanel.BackColor=[Drawing.ColorTranslator]::FromHtml('#203451');$identityPanel.ForeColor=[Drawing.Color]::White
$identityPanel.Text='Target computer: reading device information...'
$usbStatus=New-Object Windows.Forms.Label
$usbStatus.Dock='Top';$usbStatus.Height=34;$usbStatus.TextAlign='MiddleLeft';$usbStatus.ForeColor=[Drawing.ColorTranslator]::FromHtml('#F5CA7A')
$usbStatus.Text=if($Task -eq 'DeployPE'){'   USB required: local copy incomplete'}else{'   KEEP USB CONNECTED  /  Installation packages are still required'}
$f.Controls.Add($box); $f.Controls.Add($statusPanel); $f.Controls.Add($bottom); $f.Controls.Add($usbStatus); $f.Controls.Add($identityPanel); $f.Controls.Add($top)
$field.Enabled=$false; $ok.Enabled=$false
$label.Text='Technical details are available in the log.'
$state.Stage='Preparing';$state.Progress=$null
$state.LastMessage=''
if($Task -in 'Auto','DeployPE') {
    . "$PSScriptRoot\SetupOptions.ps1"
    $state.Options=Show-SetupOptions -PEMode:($Task -eq 'DeployPE')
    if(!$state.Options){$lock.ReleaseMutex();$lock.Dispose();$f.Dispose();return}
}
if($Task -eq 'Finish' -and $ProfileRoot){
    $choice=[Windows.Forms.MessageBox]::Show($f,'Run Office setup again? Choose No if Office is already installed. Windows will not be reinstalled.','Resume installation',[Windows.Forms.MessageBoxButtons]::YesNoCancel,[Windows.Forms.MessageBoxIcon]::Question,[Windows.Forms.MessageBoxDefaultButton]::Button2)
    if($choice -eq [Windows.Forms.DialogResult]::Cancel){$lock.ReleaseMutex();$lock.Dispose();$f.Dispose();return}
    $state.SkipOffice=($choice -eq [Windows.Forms.DialogResult]::No)
}
if($Task -eq 'Apps'){
    . "$PSScriptRoot\LocalAppsUI.ps1"
    $selection=Show-LocalAppsPicker -RunNow
    if(!$selection){$lock.ReleaseMutex();$lock.Dispose();$f.Dispose();return}
    $state.LocalApps=$selection.Apps
}
$watch=[Diagnostics.Stopwatch]::StartNew()
$rs=[RunspaceFactory]::CreateRunspace()
$rs.ApartmentState='STA'; $rs.ThreadOptions='ReuseThread'; $rs.Open()
$ps=[PowerShell]::Create(); $ps.Runspace=$rs
$body={
    param($scriptFile,$state,$queue,$wake,$logPath)
    $ErrorActionPreference='Stop'
    function Record([string]$line) {
        if ([string]::IsNullOrWhiteSpace($line)) { return }
        $text=(Get-Date -Format 'HH:mm:ss')+'  '+$line.TrimEnd()
        $queue.Enqueue($text)
        $state.LastMessage=$line.TrimEnd()
        if($line -match '^--- (.+) ---$' -or $line -match '^\[\d+/\d+\]\s*(.+)') {
            $state.Stage=$Matches[1];$state.Progress=$null
        }
        if($line -match '^SHA256 verification'){$state.Stage=$line;$state.Progress=$null}
        if($line -match '\[[= ]*([0-9]+(?:[.,][0-9]+)?)%[= ]*\]') {
            $pct=[double]::Parse(($Matches[1] -replace ',','.'),[Globalization.CultureInfo]::InvariantCulture)
            $state.Progress=@{Done=$pct;Total=100;Unit='percent';Speed=0}
        }
        if($line -match '^Office\s*:'){$state.Stage=$line;$state.Progress=$null}
        [IO.File]::AppendAllText($logPath,$text+[Environment]::NewLine)
        if($state.LocalLog){[IO.File]::AppendAllText($state.LocalLog,$text+[Environment]::NewLine)}
    }
    function Ask($kind,$title,$filter) {
        Record "Waiting for input: $title"
        $state.Prompt=@{Kind=$kind;Title=$title;Filter=$filter}
        [void]$wake.WaitOne()
        if ($state.Abort) { throw 'Cancelled while waiting for input.' }
        $value=$state.Answer
        $state.Answer=$null
        return $value
    }
    function Read-Host([string]$Prompt,[switch]$AsSecureString) {
        $kind=if ($AsSecureString) {'secret'} else {'text'}
        $value=Ask $kind $Prompt ''
        Record 'Input received.'
        return $value
    }
    function Get-AtelierImage($title,$filter) { Ask 'file' $title $filter }
    function Get-AtelierConfirmation($title,$summary) { return ((Ask 'review' $title $summary) -eq 'yes') }
    try {
        try {
            $pc=Get-CimInstance Win32_ComputerSystem -OperationTimeoutSec 5
            $bios=Get-CimInstance Win32_BIOS -OperationTimeoutSec 5
            $product=Get-CimInstance Win32_ComputerSystemProduct -OperationTimeoutSec 5
            $state.Computer="$($pc.Manufacturer) $($pc.Model) | Serial: $($bios.SerialNumber) | RAM : $([math]::Round($pc.TotalPhysicalMemory/1GB,1)) GiB"
            $state.MachineId=$product.UUID
            $state.CurrentName=$env:COMPUTERNAME
            Record ('Target computer: '+$state.Computer+' | UUID : '+$state.MachineId)
        } catch {$state.Computer='Device information unavailable; see log';Record $_.Exception.Message}
        Record 'Starting.' 
        & $scriptFile *>&1 | ForEach-Object {
            if ($_ -is [Management.Automation.WarningRecord]) { $state.Warnings=$true;Record ('WARNING: '+[string]$_) } else {Record ([string]$_)}
        }
        if ($state.Cancelled) { Record 'Operation cancelled.' } else { Record 'Task finished. Open the log for detailed results.' }
    } catch { $state.Failed=$true; Record ("ERROR: "+$_.Exception.Message+"  "+$_.InvocationInfo.PositionMessage) }
}
[void]$ps.AddScript($body.ToString()).AddArgument((Join-Path $PSScriptRoot ($Task+'.ps1'))).AddArgument($state).AddArgument($queue).AddArgument($wake).AddArgument($logPath)
$job=$ps.BeginInvoke()
$ok.Add_Click({
    if (!$field.Enabled) { return }
    if ($field.UseSystemPasswordChar) {
        $secret=New-Object Security.SecureString
        foreach ($c in $field.Text.ToCharArray()) { $secret.AppendChar($c) }
        $secret.MakeReadOnly(); $state.Answer=$secret
    } else { $state.Answer=$field.Text }
    $field.Clear(); $field.Enabled=$false; $ok.Enabled=$false
    $label.Text='Working...'; [void]$wake.Set()
})
$f.AcceptButton=$ok
$timer=New-Object Windows.Forms.Timer
$timer.Interval=200
$timer.Add_Tick({
    $skipApp.Enabled=[bool]$state.AppWaiting
    $field.Visible=$field.Enabled;$ok.Visible=$field.Enabled
    $line=''
    while ($queue.TryDequeue([ref]$line)) {
        $plain=$line -replace '^\d{2}:\d{2}:\d{2}\s+',''
        # This panel displays decisions, validation feedback and final results only.
        if($plain -match '^\d+\s*:' -or $plain -match '^(TARGET TO ERASE|ALL partitions|Edition :|Selected disk|Unknown number|Choose |Invalid |Passwords |Enter |The USB|Disk not eligible|ERROR|Task finished|Operation cancelled|APP RESULT|RESULT:|FINAL RESULT|WARNING:)') {
            $box.SelectionColor=if($plain -match 'NeedsAttention|ERROR|WARNING'){[Drawing.ColorTranslator]::FromHtml('#F5CA7A')}else{[Drawing.ColorTranslator]::FromHtml('#A7E8D8')}
            $box.AppendText($plain+[Environment]::NewLine)
            $box.SelectionStart=$box.TextLength;$box.ScrollToCaret()
        }
    }
    $identityPanel.Text="Target computer: $($state.Computer)`r`nSession : $($state.CurrentName) | $($state.Firmware) | UUID : $($state.MachineId)`r`n$($state.TargetDisk) | Planned name: $($state.PlannedName)"
    if($state.UsbReady){$usbStatus.Text='   USB CAN BE REMOVED - local files verified';$usbStatus.ForeColor=[Drawing.ColorTranslator]::FromHtml('#53E4D0')}
    $stageLabel.Text=[string]$state.Stage
    $pr=$state.Progress
    if($pr -and $pr.Total -gt 0) {
        $progress.Style='Continuous';$progress.Value=[math]::Min(100,[math]::Max(0,[int](100*$pr.Done/$pr.Total)))
        if($pr.Unit -eq 'percent'){$metrics.Text=($progress.Value.ToString()+'% of this stage')} else {
        $metrics.Text=('{0:N0} / {1:N0} MB  |  {2:N1} MB/s  |  {3}% of this file' -f ($pr.Done/1MB),($pr.Total/1MB),$pr.Speed,$progress.Value)
        }
    } else {
        $progress.Style='Marquee'
        $metrics.Text='Working - this installer does not report a percentage'
    }
    if($state.AppWaiting){$metrics.Text="Application $($state.AppIndex)/$($state.AppCount) | $($state.AppSeconds) s | $($state.AppDone) processed | individual percentage unavailable"}
    $p=$state.Prompt
    if ($p) {
        $state.Prompt=$null
        if ($p.Kind -eq 'review') {
            $reviewForm=New-Object Windows.Forms.Form
            $reviewForm.Text='Review installation - Master Setup'
            $reviewForm.StartPosition='CenterParent'
            $reviewForm.Size=New-Object Drawing.Size([Math]::Min(780,$wa.Width-30),[Math]::Min(650,$wa.Height-30))
            $reviewForm.BackColor=$f.BackColor
            $reviewForm.Padding=New-Object Windows.Forms.Padding(18)
            $reviewForm.Font=New-Object Drawing.Font('Segoe UI',10)
            $reviewText=New-Object Windows.Forms.TextBox
            $reviewText.BorderStyle='None';$reviewText.Multiline=$true;$reviewText.ReadOnly=$true;$reviewText.ScrollBars='Vertical';$reviewText.Dock='Fill'
            $reviewText.Font=New-Object Drawing.Font('Segoe UI',10)
            $reviewText.BackColor=$f.BackColor;$reviewText.ForeColor=$f.ForeColor
            $reviewText.Text=Convert-MasterReview $p.Filter
            $reviewText.RightToLeft=if($env:MASTERSETUP_LANG -eq 'ar'){'Yes'}else{'No'}
            $reviewButtons=New-Object Windows.Forms.FlowLayoutPanel
            $reviewButtons.Dock='Bottom';$reviewButtons.Height=64;$reviewButtons.Padding=New-Object Windows.Forms.Padding(0,12,0,0);$reviewButtons.FlowDirection='RightToLeft'
            $yes=New-Object Windows.Forms.Button
            $yes.Text='Yes - erase and install';$yes.Width=200;$yes.Height=38;$yes.DialogResult='Yes'
            $yes.FlatStyle='Flat';$yes.FlatAppearance.BorderSize=0
            $yes.BackColor=[Drawing.ColorTranslator]::FromHtml('#53E4D0');$yes.ForeColor=[Drawing.ColorTranslator]::FromHtml('#101D34')
            $no=New-Object Windows.Forms.Button
            $no.Text='No - cancel';$no.Width=140;$no.Height=38;$no.DialogResult='No'
            $no.FlatStyle='Flat';$no.FlatAppearance.BorderSize=0
            $no.BackColor=[Drawing.ColorTranslator]::FromHtml('#203451');$no.ForeColor=[Drawing.Color]::White
            $reviewButtons.Controls.Add($no);$reviewButtons.Controls.Add($yes)
            $reviewForm.Controls.Add($reviewText);$reviewForm.Controls.Add($reviewButtons)
            $reviewForm.CancelButton=$no;$reviewForm.AcceptButton=$no
            Enable-MasterLanguage $reviewForm
            try {$state.Answer=if($reviewForm.ShowDialog($f) -eq 'Yes'){'yes'}else{'no'}}
            finally {$reviewForm.Dispose();[void]$wake.Set()}
        } elseif ($p.Kind -eq 'file') {
            $dialog=New-Object Windows.Forms.OpenFileDialog
            $dialog.Title=(M $p.Title); $dialog.Filter=$p.Filter
            try {
                if ($dialog.ShowDialog($f) -eq 'OK') { $state.Answer=$dialog.FileName } else { $state.Answer=$null }
            } finally { $dialog.Dispose(); [void]$wake.Set() }
        } else {
            $stageLabel.Text='Your input'; $label.Text=(M $p.Title); $field.UseSystemPasswordChar=($p.Kind -eq 'secret')
            $field.Enabled=$true; $ok.Enabled=$true; $field.Focus() | Out-Null
        }
    }
    if($field.Enabled){$stageLabel.Text='Your input';$progress.Style='Continuous';$progress.Value=0;$metrics.Text='Choices are case-insensitive. Password case is preserved.'}
    $phase=if($state.Attention){[string]$state.Attention} elseif ($field.Enabled) {'Waiting for your input'} else {'Running'}
    $top.Text="   MASTER SETUP    |    $(M $phase)    |    "+$watch.Elapsed.ToString('hh\:mm\:ss')
    if ($job.IsCompleted -and $queue.IsEmpty) {
        $timer.Stop();$skipApp.Enabled=$false
        try { [void]$ps.EndInvoke($job) } catch { $state.Failed=$true; $box.AppendText($_.Exception.Message) }
        $phase=if ($state.Failed) {'Failed'} elseif ($state.Cancelled) {'Cancelled'} elseif ($state.Warnings) {'Finished with warnings'} else {'Finished'}
        $watch.Stop(); $top.Text="   MASTER SETUP    |    $(M $phase)    |    "+$watch.Elapsed.ToString('hh\:mm\:ss')
        $progress.Style='Continuous'; $progress.Value=if($state.Failed -or $state.Cancelled){0}else{100}
        $stageLabel.Text=$phase
        $metrics.Text='Review individual results below; detailed output is in the log.'
        [IO.File]::AppendAllText($logPath, ("Total duration: "+$watch.Elapsed.ToString()+[Environment]::NewLine))
        $field.Visible=$false; $ok.Visible=$false; $label.Text='Technical details are available in the log.'
    }
})
$f.Add_FormClosing({param($sender,$e)
    if (!$job.IsCompleted -and $e.CloseReason -eq 'UserClosing') {
        $e.Cancel=$true
        if ($field.Enabled) {
            if ([Windows.Forms.MessageBox]::Show($f,'Cancel this task?','Confirmation','YesNo') -eq 'Yes') {
                $state.Abort=$true; $state.Cancelled=$true; $field.Clear(); $field.Enabled=$false; $ok.Enabled=$false; [void]$wake.Set()
            }
            return
        }
        [void][Windows.Forms.MessageBox]::Show($f,'This task is running. Use No at a confirmation prompt to cancel.')
    }
})
$f.Add_Shown({$f.Activate();$timer.Start()})
try { Enable-MasterLanguage $f
[void]$f.ShowDialog() } finally { $timer.Dispose(); $ps.Dispose(); $rs.Dispose(); $wake.Dispose(); $lock.ReleaseMutex(); $lock.Dispose() }
