# Shared startup wizard. No disk operations are performed here.
function Get-MasterStartupRoutes([bool]$IsWinPE) {
    if($IsWinPE){
        return @([pscustomobject]@{Id='DeployPE';Title='Windows unavailable / blank disk';Detail='Clean installation from boot media. The selected INTERNAL disk is erased after confirmation.'})
    }
    return @(
        [pscustomobject]@{Id='Dashboard';Title='Open Master Setup';Detail='View this computer and choose installation, applications or resume.'},
        [pscustomobject]@{Id='Auto';Title='Normal installation';Detail='Prepare Windows, Office and applications from a working Windows system.'},
        [pscustomobject]@{Id='Apps';Title='Install applications only';Detail='Install selected packages on this PC without reinstalling Windows.'},
        [pscustomobject]@{Id='BootGuide';Title='Windows unavailable / blank disk';Detail='Restart from the Master Setup Boot ISO on Ventoy. This option shows instructions only.'}
    )
}
function Show-MasterLanguageDialog {
    $form=New-Object Windows.Forms.Form
    $form.Text='Master Setup | Language';$form.StartPosition='CenterScreen'
    $form.ClientSize=New-Object Drawing.Size(520,210)
    $form.FormBorderStyle='FixedDialog';$form.MaximizeBox=$false;$form.MinimizeBox=$false
    $form.Font=New-Object Drawing.Font('Segoe UI',11)
    $form.BackColor=[Drawing.ColorTranslator]::FromHtml('#101D34');$form.ForeColor=[Drawing.Color]::White
    $label=New-Object Windows.Forms.Label
    $label.SetBounds(24,24,472,44);$label.Text='Choose your language / Choisir la langue'
    $combo=New-Object Windows.Forms.ComboBox
    $combo.Name='MasterLanguageSelector';$combo.DropDownStyle='DropDownList';$combo.SetBounds(24,78,472,32)
    [void]$combo.Items.AddRange(@('English','Français','العربية','Español'))
    $combo.SelectedIndex=[Math]::Max(0,[array]::IndexOf(@('en','fr','ar','es'),$env:MASTERSETUP_LANG))
    $ok=New-Object Windows.Forms.Button;$ok.SetBounds(272,150,108,36);$ok.Text=M 'Continue';$ok.DialogResult='OK'
    $ok.BackColor=[Drawing.ColorTranslator]::FromHtml('#53E4D0');$ok.ForeColor=[Drawing.Color]::Black
    $cancel=New-Object Windows.Forms.Button;$cancel.SetBounds(390,150,106,36);$cancel.Text=M 'Cancel';$cancel.DialogResult='Cancel'
    $form.Controls.AddRange(@($label,$combo,$ok,$cancel));$form.AcceptButton=$ok;$form.CancelButton=$cancel
    try {
        if($form.ShowDialog() -ne 'OK'){return $false}
        $env:MASTERSETUP_LANG=@('en','fr','ar','es')[$combo.SelectedIndex]
        return $true
    } finally {$form.Dispose()}
}
function Show-MasterWelcome([bool]$IsWinPE) {
    while($true){
        if(!(Show-MasterLanguageDialog)){return $null}
        $routes=@(Get-MasterStartupRoutes $IsWinPE)
        $form=New-Object Windows.Forms.Form
        $form.Text='Master Setup | '+(M 'Welcome');$form.StartPosition='CenterScreen'
        $area=[Windows.Forms.Screen]::PrimaryScreen.WorkingArea
        $form.ClientSize=New-Object Drawing.Size([Math]::Min(760,$area.Width-40),[Math]::Min(600,$area.Height-80))
        $form.MinimumSize=New-Object Drawing.Size(520,420)
        $form.BackColor=[Drawing.ColorTranslator]::FromHtml('#101D34');$form.ForeColor=[Drawing.Color]::White
        $form.Font=New-Object Drawing.Font('Segoe UI',11)
        $footer=New-Object Windows.Forms.FlowLayoutPanel;$footer.Dock='Bottom';$footer.Height=60
        $footer.FlowDirection='RightToLeft';$footer.Padding=New-Object Windows.Forms.Padding(10)
        $cancel=New-Object Windows.Forms.Button;$cancel.Size=New-Object Drawing.Size(110,36);$cancel.Text=M 'Cancel';$cancel.DialogResult='Cancel'
        $next=New-Object Windows.Forms.Button;$next.Size=New-Object Drawing.Size(110,36);$next.Text=M 'Continue';$next.DialogResult='OK'
        $next.BackColor=[Drawing.ColorTranslator]::FromHtml('#53E4D0');$next.ForeColor=[Drawing.Color]::Black
        $back=New-Object Windows.Forms.Button;$back.Size=New-Object Drawing.Size(110,36);$back.Text=M 'Back';$back.DialogResult='Retry'
        $footer.Controls.AddRange(@($cancel,$next,$back))
        $body=New-Object Windows.Forms.FlowLayoutPanel;$body.Dock='Fill';$body.AutoScroll=$true
        $body.FlowDirection='TopDown';$body.WrapContents=$false;$body.Padding=New-Object Windows.Forms.Padding(24)
        $title=New-Object Windows.Forms.Label;$title.AutoSize=$true;$title.Text='MASTER SETUP'
        $title.Font=New-Object Drawing.Font('Segoe UI',26,[Drawing.FontStyle]::Bold)
        $subtitle=New-Object Windows.Forms.Label;$subtitle.AutoSize=$true;$subtitle.MaximumSize=New-Object Drawing.Size(640,0)
        $subtitle.Text=M 'Choose how you want to work. Nothing is changed until you confirm.'
        $credit=New-Object Windows.Forms.Label;$credit.AutoSize=$true;$credit.Text='Developed by Yassine'
        $credit.ForeColor=[Drawing.ColorTranslator]::FromHtml('#53E4D0')
        $body.Controls.AddRange(@($title,$subtitle,$credit))
        $buttons=@()
        foreach($route in $routes){
            $radio=New-Object Windows.Forms.RadioButton;$radio.AutoSize=$true
            $radio.MaximumSize=New-Object Drawing.Size(640,0);$radio.Text=(M $route.Title)+"`r`n"+(M $route.Detail)
            $radio.Tag=$route.Id;$radio.Margin=New-Object Windows.Forms.Padding(0,18,0,0)
            if(!$buttons.Count){$radio.Checked=$true}
            $buttons+=,$radio;$body.Controls.Add($radio)
        }
        if($IsWinPE){
            $notice=New-Object Windows.Forms.Label;$notice.AutoSize=$true;$notice.MaximumSize=New-Object Drawing.Size(640,0)
            $notice.Margin=New-Object Windows.Forms.Padding(0,24,0,0)
            $notice.Text=M 'USB can be removed only after Windows and internal boot preparation. External USB target disks are not supported.'
            $body.Controls.Add($notice)
        }
        $form.Controls.Add($body);$form.Controls.Add($footer);$form.AcceptButton=$next;$form.CancelButton=$cancel
        Set-MasterControlLanguage $form
        try {
            $result=$form.ShowDialog()
            if($result -eq 'Retry'){continue}
            if($result -ne 'OK'){return $null}
            $selected=@($buttons | Where-Object Checked)
            if($selected.Count -ne 1){throw 'Select one workflow.'}
            return [string]$selected[0].Tag
        } finally {$form.Dispose()}
    }
}
