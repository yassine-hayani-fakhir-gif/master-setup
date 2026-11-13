. "$PSScriptRoot\Language.ps1"
 . "$PSScriptRoot\LocalAppsUI.ps1"
function Show-SetupOptions {
    param([switch]$PEMode)
    $localSelection=@{Apps=@()}
    $dialog=New-Object Windows.Forms.Form
    $dialog.Text='Master Setup | Prepare installation'
    $dialog.StartPosition='CenterScreen';$dialog.ClientSize=New-Object Drawing.Size(740,630)
    $dialog.FormBorderStyle='FixedDialog';$dialog.MaximizeBox=$false
    $dialog.BackColor=[Drawing.ColorTranslator]::FromHtml('#101D34')
    $dialog.ForeColor=[Drawing.ColorTranslator]::FromHtml('#EAF0FF')
    $dialog.Font=New-Object Drawing.Font('Segoe UI',10)
    $title=New-Object Windows.Forms.Label
    $title.SetBounds(24,16,690,44);$title.Text='01 / MEDIA AND APPLICATIONS'
    $title.Font=New-Object Drawing.Font('Segoe UI',18,[Drawing.FontStyle]::Bold)
    $dialog.Controls.Add($title)
    $hint=New-Object Windows.Forms.Label
    $hint.SetBounds(24,64,690,53)
    $hint.Text='Use a Ventoy or regular NTFS / exFAT USB. Keep your Windows ISO, Office image and app installers together. This page only collects your choices.'
    $dialog.Controls.Add($hint)
    $links=@(
        @('Windows','https://www.microsoft.com/software-download/'),
        @('Office','https://www.office.com/signin')
    )
    for($i=0;$i -lt $links.Count;$i++) {
        $button=New-Object Windows.Forms.Button
        $button.SetBounds((24+350*$i),122,330,38);$button.Text='Download '+$links[$i][0]
        $button.Tag=$links[$i][1];$button.FlatStyle='Flat';$button.Enabled=(!$PEMode)
        $button.Add_Click({param($sender,$e) Start-Process ([string]$sender.Tag)})
        $dialog.Controls.Add($button)
    }
    $apps=New-Object Windows.Forms.CheckedListBox
    $apps.SetBounds(24,186,330,102);$apps.CheckOnClick=$true
    $apps.BackColor=$dialog.BackColor;$apps.ForeColor=$dialog.ForeColor;$apps.BorderStyle='None'
    foreach($name in 'Brave','Google Chrome','WinRAR','VLC'){[void]$apps.Items.Add($name,$true)}
    $dialog.Controls.Add($apps)
    $localSummary=New-Object Windows.Forms.Label
    $localSummary.SetBounds(24,186,330,102);$localSummary.AutoEllipsis=$true
    $localSummary.Text='No packages selected. Choose your app installers below.'
    $dialog.Controls.Add($localSummary)
    $appHint=New-Object Windows.Forms.Label
    $appHint.SetBounds(380,186,330,90)
    $appHint.Text='Selected apps download and install after Windows through WinGet. Internet is required. Third-party installers are not bundled.'
    $dialog.Controls.Add($appHint)
    $office=New-Object Windows.Forms.CheckBox
    $office.SetBounds(24,299,680,30);$office.Text='Install Office after Windows (provide ISO / IMG)';$office.Checked=$true
    $method=New-Object Windows.Forms.ComboBox
    $method.SetBounds(24,340,330,30);$method.DropDownStyle='DropDownList'
    [void]$method.Items.Add('WinGet - online app selection')
    [void]$method.Items.Add('My Ninite installer')
    [void]$method.Items.Add('No applications')
    [void]$method.Items.Add('Local EXE / MSI installers (USB)')
    $method.SelectedIndex=0
    $ninite=New-Object Windows.Forms.Button
    $ninite.SetBounds(380,338,330,34);$ninite.Text='Choose Ninite.exe';$ninite.Enabled=$false
    $ninitePath=New-Object Windows.Forms.Label
    $ninitePath.SetBounds(24,381,686,48);$ninitePath.AutoEllipsis=$true
    $ninitePath.Text='WinGet downloads selected apps after Windows.'
    $ninite.Add_Click({
        if($method.SelectedIndex -eq 3){
            $chosen=Show-LocalAppsPicker -InitialApps @($localSelection.Apps)
            if($chosen){$localSelection.Apps=$chosen.Apps;$localSummary.Text=(@($chosen.Apps | ForEach-Object {$_.Name}) -join [Environment]::NewLine);$ninitePath.Text="$($chosen.Apps.Count) installer(s) selected, in queue order."}
            return
        }
        $picker=New-Object Windows.Forms.OpenFileDialog
        $picker.Filter='Ninite installer (*.exe)|*.exe';$picker.Title='Choose your Ninite installer'
        try {
            if($picker.ShowDialog($dialog) -eq 'OK'){
                $sig=Get-AuthenticodeSignature -LiteralPath $picker.FileName
                if($sig.Status -ne 'Valid'){
                    [void][Windows.Forms.MessageBox]::Show($dialog,'Invalid digital signature. Choose an official installer.');return
                }
                $ninitePath.Tag=$picker.FileName
                $ninitePath.Text=$picker.FileName+' | '+$sig.SignerCertificate.Subject
            }
        } finally {$picker.Dispose()}
    })
    $method.Add_SelectedIndexChanged({
        if($PEMode -and $method.SelectedIndex -in 0,1){$method.SelectedIndex=3;return}
        $apps.Enabled=($method.SelectedIndex -eq 0)
        $apps.Visible=($method.SelectedIndex -eq 0)
        $localSummary.Visible=($method.SelectedIndex -eq 3)
        $appHint.Text=switch($method.SelectedIndex){
            0 {'WinGet installs selected apps silently after Windows. Requires Internet and App Installer.'}
            1 {'Ninite installs the apps included in your Ninite file. Requires Internet. Check Ninite licensing for your usage.'}
            2 {'Windows and Office only. No additional apps.'}
            3 {'Choose local packages and their order. Recognized apps install silently after Windows. No WinGet required. Full packages work offline.'}
        }
        $ninite.Enabled=($method.SelectedIndex -in 1,3)
        $ninite.Text=if($method.SelectedIndex -eq 3){'Choose app installers'}else{'Choose Ninite.exe'}
        $ninitePath.Text=if($method.SelectedIndex -eq 3){"$($localSelection.Apps.Count) installer(s) selected. Staged on USB during preparation."}elseif($method.SelectedIndex -eq 1){[string]$ninitePath.Tag}else{'WinGet requires Internet; No applications skips the app stage.'}
    })
    $method.SelectedIndex=3
    $dialog.Controls.AddRange(@($office,$method,$ninite,$ninitePath))
    $hint2=New-Object Windows.Forms.Label
    $hint2.SetBounds(24,441,690,88)
    $hint2.Text='Start this workflow from a working Windows system. Keep the USB connected until all installations finish. Use complete installers for offline operation. FAT / FAT32 sources are not supported by this workflow.'
    if($PEMode){$hint.Text='Experimental WinPE: internal disk is erased after confirmation, then files are staged locally. Choose files on NTFS / exFAT USB.';$hint2.Text='After copy verification: USB can be removed. This experimental mode accepts local apps or no apps. Windows uses a WIM/ESD prepared with the WinPE builder.'}
    $dialog.Controls.Add($hint2)
    $go=New-Object Windows.Forms.Button
    $go.SetBounds(390,560,320,38);$go.Text='Continue to disks and Windows ISO'
    $go.BackColor=[Drawing.ColorTranslator]::FromHtml('#53E4D0');$go.ForeColor=[Drawing.Color]::Black
    $go.Add_Click({
        if($method.SelectedIndex -eq 1 -and !$ninitePath.Tag){
            [void][Windows.Forms.MessageBox]::Show($dialog,'Choose a Ninite file before continuing.');return
        }
        if($method.SelectedIndex -eq 3 -and !$localSelection.Apps.Count){
            [void][Windows.Forms.MessageBox]::Show($dialog,'Choose your installers before continuing.');return
        }
        $dialog.DialogResult='OK';$dialog.Close()
    })
    $dialog.Controls.Add($go);$dialog.AcceptButton=$go
    try {
        Enable-MasterLanguage $dialog
        if($dialog.ShowDialog() -ne 'OK'){return $null}
        $ids=@('Brave.Brave','Google.Chrome','RARLab.WinRAR','VideoLAN.VLC')
        $selected=@(foreach($index in $apps.CheckedIndices){$ids[$index]})
        $mode=@('WinGet','Ninite','None','Local')[$method.SelectedIndex]
        if($mode -ne 'WinGet'){$selected=@()}
        return @{Apps=$selected;AppMethod=$mode;NinitePath=[string]$ninitePath.Tag;Office=$office.Checked;LocalApps=@($localSelection.Apps)}
    } finally {$dialog.Dispose()}
}
