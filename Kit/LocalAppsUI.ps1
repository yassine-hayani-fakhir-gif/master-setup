. "$PSScriptRoot\Language.ps1"
. "$PSScriptRoot\LocalApps.ps1"
function Show-LocalAppsPicker {
    param([object[]]$InitialApps=@(),[switch]$RunNow)
    $form=New-Object Windows.Forms.Form
    $form.Add_Shown({param($sender,$e) Enable-MasterLanguage $sender})
    $form.Text='Master Setup | Application library';$form.ClientSize=New-Object Drawing.Size(820,600)
    $form.StartPosition='CenterScreen';$form.BackColor=[Drawing.ColorTranslator]::FromHtml('#101D34');$form.ForeColor=[Drawing.Color]::White
    $form.Font=New-Object Drawing.Font('Segoe UI',10);$form.MaximizeBox=$false;$form.FormBorderStyle='FixedDialog';$form.AutoScroll=$true
    $wa=[Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $form.Height=[Math]::Min($form.Height,$wa.Height-30)
    $records=New-Object 'System.Collections.Generic.List[object]'
    foreach($app in $InitialApps){
        if(!$app.PSObject.Properties['Arguments']){$app|Add-Member NoteProperty Arguments ''}
        if(!$app.PSObject.Properties['ManualApproved']){$app|Add-Member NoteProperty ManualApproved $false}
        $records.Add($app)
    }
    $title=New-Object Windows.Forms.Label;$title.SetBounds(24,18,770,38)
    $title.Text='YOUR APPS. ONE INSTALLATION QUEUE.';$title.Font=New-Object Drawing.Font('Segoe UI',18,[Drawing.FontStyle]::Bold)
    $title.ForeColor=[Drawing.ColorTranslator]::FromHtml('#53E4D0')
    $intro=New-Object Windows.Forms.Label;$intro.SetBounds(24,66,770,52)
    $intro.Text='Add full EXE / MSI installers from your USB. Supported packages use silent defaults. Nothing installs until you start. Internet is still required for download launchers.'
    $list=New-Object Windows.Forms.ListView;$list.SetBounds(24,132,770,245)
    $list.View='Details';$list.FullRowSelect=$true;$list.MultiSelect=$false;$list.HideSelection=$false
    $list.BackColor=[Drawing.ColorTranslator]::FromHtml('#0A1120');$list.ForeColor=[Drawing.Color]::White;$list.BorderStyle='None'
    [void]$list.Columns.Add('APPLICATION',310);[void]$list.Columns.Add('INSTALLATION MODE',205);[void]$list.Columns.Add('PACKAGE',220)
    $form.Controls.AddRange(@($title,$intro,$list))
    $refresh={
        $list.Items.Clear()
        foreach($item in $records){
            $row=New-Object Windows.Forms.ListViewItem($item.Name)
            [void]$row.SubItems.Add([string]$item.Mode)
            $info=if($item.Mode -eq 'Interactive' -and !$item.ManualApproved){'Needs a silent profile'}elseif($item.Mode -eq 'CustomSilent'){'Custom: offline not verified'}elseif($item.Mode -eq 'SilentMSI'){'MSI: check dependencies'}else{'Full installer required'}
            [void]$row.SubItems.Add($info)
            if($item.Mode -eq 'Interactive'){$row.ForeColor=[Drawing.ColorTranslator]::FromHtml('#F5CA7A')}
            [void]$list.Items.Add($row)
        }
    }
    & $refresh
    function PickerButton($text,$x,$width){
        $b=New-Object Windows.Forms.Button;$b.Text=$text;$b.SetBounds($x,393,$width,36)
        $b.FlatStyle='Flat';$b.BackColor=[Drawing.ColorTranslator]::FromHtml('#203451');$b.ForeColor=[Drawing.Color]::White
        $form.Controls.Add($b);return $b
    }
    $add=PickerButton 'Add installers' 24 160
    $remove=PickerButton 'Remove' 194 100
    $up=PickerButton 'Up' 304 70
    $down=PickerButton 'Down' 384 80
    $mode=PickerButton 'Configure selected app' 474 320
    $add.Add_Click({
        $picker=New-Object Windows.Forms.OpenFileDialog;$picker.Filter='Installers (*.exe;*.msi)|*.exe;*.msi';$picker.Multiselect=$true
        try {if($picker.ShowDialog($form) -eq 'OK'){
            foreach($path in $picker.FileNames){
                try {
                    if(@($records|Where-Object {$_.Path -eq $path}).Count){continue}
                    $form.Cursor='WaitCursor';$app=New-LocalAppRecord $path
                    if([IO.Path]::GetFileName($path) -match '^(ChromeSetup|BraveBrowserSetup[^.]*)\.exe$'){
                        [void][Windows.Forms.MessageBox]::Show($form,'This is a download launcher. For unattended offline installation use Chrome Enterprise MSI or BraveBrowserStandaloneSetup.exe. For online installation, choose WinGet on the preparation page. This file was not added.','Full installer required');continue
                    }
                    if($app.Unsigned -and [Windows.Forms.MessageBox]::Show($form,"Unsigned installer: $path`r`nAdd only if you trust its source. Allow this exact file?",'Unverified publisher','YesNo','Warning','Button2') -ne 'Yes'){continue}
                    $records.Add($app)
                } catch {[void][Windows.Forms.MessageBox]::Show($form,$_.Exception.Message)} finally {$form.Cursor='Default'}
            }
            & $refresh
        }} finally {$picker.Dispose()}
    })
    $remove.Add_Click({if($list.SelectedIndices.Count){$records.RemoveAt($list.SelectedIndices[0]);& $refresh}})
    $up.Add_Click({if($list.SelectedIndices.Count){$i=$list.SelectedIndices[0];if($i -gt 0){$a=$records[$i];$records.RemoveAt($i);$records.Insert($i-1,$a);& $refresh;$list.Items[$i-1].Selected=$true}}})
    $down.Add_Click({if($list.SelectedIndices.Count){$i=$list.SelectedIndices[0];if($i -lt $records.Count-1){$a=$records[$i];$records.RemoveAt($i);$records.Insert($i+1,$a);& $refresh;$list.Items[$i+1].Selected=$true}}})
    $mode.Add_Click({
        if(!$list.SelectedIndices.Count){return}
        $i=$list.SelectedIndices[0];$app=$records[$i]
        $config=New-Object Windows.Forms.Form
        $config.Add_Shown({param($sender,$e) Enable-MasterLanguage $sender});$config.Text='Installation profile | '+$app.Name
        $config.ClientSize=New-Object Drawing.Size(610,265);$config.StartPosition='CenterParent';$config.BackColor=$form.BackColor;$config.ForeColor=$form.ForeColor;$config.Font=$form.Font
        $choice=New-Object Windows.Forms.ComboBox;$choice.SetBounds(20,20,570,30);$choice.DropDownStyle='DropDownList'
        [void]$choice.Items.Add('Automatic - recognized profile');[void]$choice.Items.Add('Custom silent arguments - advanced');[void]$choice.Items.Add('Manual - explicitly allow installer windows');$choice.SelectedIndex=0
        $help=New-Object Windows.Forms.Label;$help.SetBounds(20,62,570,66);$help.Text='Custom mode: enter only the publisher-documented installer arguments, not a command or script. You are responsible for silent operation, defaults and restart behavior. No silent flag works for every EXE.'
        $argsBox=New-Object Windows.Forms.TextBox;$argsBox.SetBounds(20,138,570,28);$argsBox.Text=[string]$app.Arguments;$argsBox.Enabled=$false
        $choice.Add_SelectedIndexChanged({$argsBox.Enabled=($choice.SelectedIndex -eq 1)})
        $save=New-Object Windows.Forms.Button;$save.SetBounds(390,208,200,36);$save.Text='Apply profile';$save.FlatStyle='Flat'
        $save.Add_Click({
            if($choice.SelectedIndex -eq 0){
                $detected=Get-LocalAppMode $app.Path
                if($detected -eq 'Interactive'){[void][Windows.Forms.MessageBox]::Show($config,'No recognized automatic profile. Obtain a supported package or provide documented silent arguments.');return}
                $app.Mode=$detected;$app.Arguments='';$app.ManualApproved=$false
            }elseif($choice.SelectedIndex -eq 1){
                if([IO.Path]::GetExtension($app.Path) -eq '.msi'){[void][Windows.Forms.MessageBox]::Show($config,'Use Automatic for MSI packages. Custom arguments are for EXE installers.');return}
                if([string]::IsNullOrWhiteSpace($argsBox.Text) -or $argsBox.Text -match '[\r\n\x00]'){return}
                $app.Mode='CustomSilent';$app.Arguments=$argsBox.Text.Trim();$app.ManualApproved=$false
            }else{$app.Mode='Interactive';$app.Arguments='';$app.ManualApproved=$true}
            $config.DialogResult='OK';$config.Close()
        })
        $config.Controls.AddRange(@($choice,$help,$argsBox,$save))
        try{[void]$config.ShowDialog($form)}finally{$config.Dispose()}
        & $refresh
    })
    $note=New-Object Windows.Forms.Label;$note.SetBounds(24,449,770,48)
    $note.Text='AUTOMATIC PROFILES  /  VLC, WinRAR, Brave standalone and MSI packages.`r`nUnknown EXE files need a profile before starting; they never silently fall back to Next / Finish.'.Replace('`r`n',"`r`n")
    $ok=New-Object Windows.Forms.Button;$ok.SetBounds(474,532,320,40);$ok.Text='Use this app selection';$ok.FlatStyle='Flat';$ok.BackColor=[Drawing.ColorTranslator]::FromHtml('#53E4D0');$ok.ForeColor=[Drawing.Color]::Black
    if($RunNow){$ok.Text='Install selected apps on this PC';$intro.Text='Test your app queue without reinstalling Windows or Office. Close running applications before starting. Use full installers for offline operation.'}
    $ok.Add_Click({
        if(!$records.Count){return}
        if(@($records|Where-Object {$_.Mode -eq 'Interactive' -and !$_.ManualApproved}).Count){[void][Windows.Forms.MessageBox]::Show($form,'Some apps need a silent profile. Select each highlighted app and configure it, or remove it before continuing.');return}
        $form.DialogResult='OK';$form.Close()
    })
    $form.Controls.AddRange(@($note,$ok))
    try {if($form.ShowDialog() -eq 'OK'){return @{Apps=$records.ToArray()}};return $null}finally{$form.Dispose()}
}
