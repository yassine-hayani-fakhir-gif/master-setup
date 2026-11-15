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
