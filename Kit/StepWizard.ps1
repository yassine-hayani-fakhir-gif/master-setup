# Shared preparation pages. Back edits this step; it never replays disk operations.
function Show-MasterStepDialog($Owner,$Prompt,[string]$Context) {
    $form=New-Object Windows.Forms.Form
    $form.Text='Master Setup | '+(M 'Prepare installation');$form.StartPosition='CenterParent'
    $form.Size=New-Object Drawing.Size(760,570);$form.MinimumSize=New-Object Drawing.Size(540,420)
    $form.Font=New-Object Drawing.Font('Segoe UI',11)
    $form.BackColor=[Drawing.ColorTranslator]::FromHtml('#101D34');$form.ForeColor=[Drawing.Color]::White
    $header=New-Object Windows.Forms.Label;$header.Dock='Top';$header.Height=100
    $header.Padding=New-Object Windows.Forms.Padding(24,14,24,0)
    $header.Font=New-Object Drawing.Font('Segoe UI',15,[Drawing.FontStyle]::Bold)
    $header.Text='MASTER SETUP'+"`r`n"+(M $Prompt.Title)
    $footer=New-Object Windows.Forms.FlowLayoutPanel;$footer.Dock='Bottom';$footer.Height=65
    $footer.FlowDirection='RightToLeft';$footer.Padding=New-Object Windows.Forms.Padding(12)
    $cancel=New-Object Windows.Forms.Button;$cancel.Text=M 'Cancel';$cancel.Size=New-Object Drawing.Size(110,36);$cancel.DialogResult='Cancel'
    $next=New-Object Windows.Forms.Button;$next.Text=M 'Next';$next.Size=New-Object Drawing.Size(110,36)
    $next.BackColor=[Drawing.ColorTranslator]::FromHtml('#53E4D0');$next.ForeColor=[Drawing.Color]::Black
    $back=New-Object Windows.Forms.Button;$back.Text=M 'Back';$back.Size=New-Object Drawing.Size(110,36);$back.Enabled=$false
    $footer.Controls.AddRange(@($cancel,$next,$back))
    $body=New-Object Windows.Forms.Panel;$body.Dock='Fill';$body.Padding=New-Object Windows.Forms.Padding(24,8,24,12)
    $entryRow=New-Object Windows.Forms.Panel;$entryRow.Dock='Top';$entryRow.Height=48
    $valueBox=New-Object Windows.Forms.TextBox;$valueBox.Dock='Fill';$valueBox.UseSystemPasswordChar=($Prompt.Kind -eq 'secret')
    $browse=New-Object Windows.Forms.Button;$browse.Dock='Right';$browse.Width=125;$browse.Text=M 'Browse...';$browse.Visible=($Prompt.Kind -eq 'file')
    $valueBox.ReadOnly=($Prompt.Kind -eq 'file');$entryRow.Controls.Add($valueBox);$entryRow.Controls.Add($browse)
    $details=New-Object Windows.Forms.TextBox;$details.Dock='Fill';$details.Multiline=$true;$details.ReadOnly=$true;$details.ScrollBars='Both'
    $details.BackColor=[Drawing.ColorTranslator]::FromHtml('#14223A');$details.ForeColor=[Drawing.ColorTranslator]::FromHtml('#B9CFFF');$details.BorderStyle='None'
    $details.Text=if($Prompt.Kind -eq 'file'){M 'Choose the file, then review your selection.'}elseif($Prompt.Kind -eq 'secret'){M 'Password is optional. Leave empty for no password. Letter case is preserved.'}else{$Context}
    $choices=New-Object Windows.Forms.ListView
    $choices.Dock='Fill';$choices.View='Details';$choices.FullRowSelect=$true;$choices.MultiSelect=$false;$choices.HideSelection=$false
    [void]$choices.Columns.Add('Disk',220);[void]$choices.Columns.Add('Capacity / connection / identity',650)
    if($Prompt.Kind -eq 'choice'){
        $entryRow.Visible=$false;$details.Visible=$false;$next.Enabled=$false
        $decodedOptions=$Prompt.Filter | ConvertFrom-Json
        foreach($option in $decodedOptions){
            $item=New-Object Windows.Forms.ListViewItem([string]$option.Title)
            [void]$item.SubItems.Add([string]$option.Detail);$item.Tag=$option
            if(!$option.Enabled){$item.ForeColor=[Drawing.Color]::Gray}
            [void]$choices.Items.Add($item)
        }
        $choices.Add_SelectedIndexChanged({
            $next.Enabled=($choices.SelectedItems.Count -eq 1 -and $choices.SelectedItems[0].Tag.Enabled)
        })
        $body.Controls.Add($choices)
    } else {$choices.Visible=$false}
    $body.Controls.Add($details);$body.Controls.Add($entryRow)
    $form.Controls.Add($body);$form.Controls.Add($footer);$form.Controls.Add($header)
    $form.CancelButton=$cancel;$form.AcceptButton=$next
    $page=@{Review=$false;Value=$null;Original=$details.Text;Skip=$false}
    if($Prompt.Kind -eq 'file' -and $Prompt.Title -match 'Office'){
        $skip=New-Object Windows.Forms.Button;$skip.Text=M 'Skip Office';$skip.Size=New-Object Drawing.Size(130,36)
        $skip.Add_Click({$page.Skip=$true;$form.DialogResult='OK';$form.Close()});$footer.Controls.Add($skip)
    }
    $browse.Add_Click({
        $picker=New-Object Windows.Forms.OpenFileDialog;$picker.Title=M $Prompt.Title;$picker.Filter=$Prompt.Filter
        if($valueBox.Text){$picker.FileName=$valueBox.Text}
        try {if($picker.ShowDialog($form) -eq 'OK'){$valueBox.Text=$picker.FileName}} finally {$picker.Dispose()}
    })
    $back.Add_Click({$page.Review=$false;$entryRow.Visible=($Prompt.Kind -ne 'choice');$choices.Visible=($Prompt.Kind -eq 'choice');$details.Visible=($Prompt.Kind -ne 'choice');$details.Text=$page.Original;$back.Enabled=$false;$next.Text=M 'Next';$valueBox.Focus()|Out-Null})
    $next.Add_Click({
        if($Prompt.Kind -eq 'secret'){$form.DialogResult='OK';$form.Close();return}
        if(!$page.Review){
            if($Prompt.Kind -eq 'choice'){
                if($choices.SelectedItems.Count -ne 1 -or !$choices.SelectedItems[0].Tag.Enabled){return}
                $option=$choices.SelectedItems[0].Tag
                $valueBox.Text=[string]$option.Value
                $page.Value=$option.Title+"`r`n"+$option.Detail
                $choices.Visible=$false;$details.Visible=$true
            }
            if($Prompt.Kind -eq 'file' -and ([string]::IsNullOrWhiteSpace($valueBox.Text) -or !(Test-Path -LiteralPath $valueBox.Text -PathType Leaf))){
                [void][Windows.Forms.MessageBox]::Show($form,(M 'Choose an existing file.'));return
            }
            $page.Review=$true;$entryRow.Visible=$false;$back.Enabled=$true;$next.Text=M 'Continue'
            $details.Text=(M 'Review this selection:')+"`r`n`r`n"+$(if($Prompt.Kind -eq 'choice'){$page.Value}else{$valueBox.Text})
        } else {$form.DialogResult='OK';$form.Close()}
    })
    $form.Add_Shown({$valueBox.Focus()|Out-Null;$details.SelectionStart=$details.TextLength;$details.ScrollToCaret()})
    if($env:MASTERSETUP_LANG -eq 'ar'){$header.RightToLeft='Yes';$details.RightToLeft='Yes'}
    try {
        if($form.ShowDialog($Owner) -ne 'OK'){return [pscustomobject]@{Cancelled=$true;Value=$null}}
        if($page.Skip){return [pscustomobject]@{Cancelled=$false;Value=$null}}
        if($Prompt.Kind -eq 'secret'){
            $secret=New-Object Security.SecureString
            foreach($character in $valueBox.Text.ToCharArray()){$secret.AppendChar($character)}
            $secret.MakeReadOnly();$valueBox.Clear()
            return [pscustomobject]@{Cancelled=$false;Value=$secret}
        }
        return [pscustomobject]@{Cancelled=$false;Value=$valueBox.Text}
    } finally {$valueBox.Clear();$form.Dispose()}
}
