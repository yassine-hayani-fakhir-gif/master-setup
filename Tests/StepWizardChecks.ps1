$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
. "$PSScriptRoot\..\Kit\Language.ps1"
. "$PSScriptRoot\..\Kit\StepWizard.ps1"
$env:MASTERSETUP_LANG='en'
function Get-StepControls($parent){foreach($child in $parent.Controls){$child;Get-StepControls $child}}
foreach($scenario in 'Text','Secret','Cancel','SkipOffice') {
    $test=@{Error=$null;Scenario=$scenario}
    $timer=New-Object Windows.Forms.Timer;$timer.Interval=250
    $timer.Add_Tick({
        $timer.Stop()
        $form=@([Windows.Forms.Application]::OpenForms | Where-Object {$_.Text -like 'Master Setup | Prepare*'})[0]
        try {
            $controls=@(Get-StepControls $form)
            if($test.Scenario -eq 'Cancel'){$form.Close();return}
            if($test.Scenario -eq 'SkipOffice'){
                ($controls | Where-Object {$_ -is [Windows.Forms.Button] -and $_.Text -eq 'Skip Office'}).PerformClick();return
            }
            $valueBox=@($controls | Where-Object {$_ -is [Windows.Forms.TextBox] -and !$_.ReadOnly})[0]
            $valueBox.Text='MiXeD test'
            $next=@($controls | Where-Object {$_ -is [Windows.Forms.Button] -and $_.Text -eq 'Next'})[0]
            $next.PerformClick()
            if($test.Scenario -eq 'Text'){
                ($controls | Where-Object {$_ -is [Windows.Forms.Button] -and $_.Text -eq 'Back'}).PerformClick()
                if($valueBox.Text -cne 'MiXeD test'){throw 'Back lost the entered value.'}
                $next.PerformClick();$next.PerformClick()
            }
        } catch {$test.Error=$_.Exception.Message;$form.Close()}
    })
    $kind=if($scenario -eq 'Secret'){'secret'}elseif($scenario -eq 'SkipOffice'){'file'}else{'text'}
    $prompt=[pscustomobject]@{Kind=$kind;Title=if($scenario -eq 'SkipOffice'){'Office image'}else{'Test value'};Filter='All files|*.*'}
    try {
        $timer.Start();$answer=Show-MasterStepDialog $null $prompt '1 : Example choice'
        if($test.Error){throw $test.Error}
        switch($scenario){
            'Text' {if($answer.Cancelled -or $answer.Value -cne 'MiXeD test'){throw 'Text review failed.'}}
            'Secret' {
                if($answer.Value -isnot [Security.SecureString]){throw 'Secret was not returned as SecureString.'}
                try {if([Net.NetworkCredential]::new('',$answer.Value).Password -cne 'MiXeD test'){throw 'Password case changed.'}}
                finally {$answer.Value.Dispose()}
            }
            'Cancel' {if(!$answer.Cancelled){throw 'Closing the dialog must cancel.'}}
            'SkipOffice' {if($answer.Cancelled -or $null -ne $answer.Value){throw 'Skip Office must remain distinct from cancellation.'}}
        }
    } finally {$timer.Stop();$timer.Dispose()}
}
Write-Host 'PASS: preparation dialog review/back, password case, cancellation and explicit Office skip.'
$test=@{Error=$null}
$timer=New-Object Windows.Forms.Timer;$timer.Interval=250
$timer.Add_Tick({
    $timer.Stop()
    $form=@([Windows.Forms.Application]::OpenForms | Where-Object {$_.Text -like 'Master Setup | Prepare*'})[0]
    try {
        $controls=@(Get-StepControls $form)
        $list=@($controls | Where-Object {$_ -is [Windows.Forms.ListView]})[0]
        $next=@($controls | Where-Object {$_ -is [Windows.Forms.Button] -and $_.Text -eq 'Next'})[0]
        if($next.Enabled){throw 'A disk must not be preselected.'}
        $list.Items[0].Selected=$true
        if($next.Enabled){throw 'Protected USB must not be selectable for installation.'}
        $list.Items[0].Selected=$false;$list.Items[1].Selected=$true
        if(!$next.Enabled){throw 'Eligible disk could not be selected.'}
        $next.PerformClick()
        ($controls | Where-Object {$_ -is [Windows.Forms.Button] -and $_.Text -eq 'Back'}).PerformClick()
        if(!$list.Visible -or !$list.Items[1].Selected){throw 'Back lost disk selection.'}
        $next.PerformClick();$next.PerformClick()
    } catch {$test.Error=$_.Exception.Message;$form.Close()}
})
$options=@(@{Value='0';Title='USB source';Detail='Protected';Enabled=$false},@{Value='7';Title='Internal SSD';Detail='256 GiB';Enabled=$true})
try {
    $timer.Start()
    $answer=Show-MasterStepDialog $null @{Kind='choice';Title='Select the disk for Windows';Filter=(ConvertTo-Json -InputObject $options)} ''
    if($test.Error){throw $test.Error}
    if($answer.Cancelled -or $answer.Value -ne '7'){throw 'Disk identity must be returned, not row position.'}
} finally {$timer.Stop();$timer.Dispose()}
. "$PSScriptRoot\..\Kit\DashboardLayout.ps1"
$f=New-Object Windows.Forms.Form;$f.AutoScroll=$true;$f.ClientSize=New-Object Drawing.Size(948,746)
$c=New-Object Windows.Forms.Panel;$c.Size=New-Object Drawing.Size(910,730);$f.Controls.Add($c)
$h=New-Object Windows.Forms.Panel;$h.SetBounds(0,0,910,128);$c.Controls.Add($h)
$b=New-Object Windows.Forms.Button;$b.SetBounds(22,673,864,38);$c.Controls.Add($b)
try {
    Initialize-MasterDashboardLayout $f $c $h
    $f.ClientSize=New-Object Drawing.Size(1800,900)
    if($c.Width -lt 1750 -or $h.Width -ne $c.Width -or $b.Right -gt $c.Width){throw 'Maximized dashboard did not fill available width.'}
    $f.ClientSize=New-Object Drawing.Size(600,400)
    if($f.AutoScrollMinSize.Height -lt $b.Bottom -or $f.AutoScrollMinSize.Width -lt 910){throw 'Small windows must keep all actions scrollable.'}
} finally {$f.Dispose()}
Write-Host 'PASS: disk click selection, USB protection, stable identity, review/back and dashboard resizing.'
