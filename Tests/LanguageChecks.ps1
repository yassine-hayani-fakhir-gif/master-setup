# Windows-only, non-destructive WinForms regression. No deployment is started.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
. "$PSScriptRoot\..\Kit\Language.ps1"
$form=New-Object Windows.Forms.Form
$panel=New-Object Windows.Forms.Panel
$label=New-Object Windows.Forms.Label
$label.Text='Continue'
$input=New-Object Windows.Forms.TextBox
$input.Text='AbC&123'
$picker=New-Object Windows.Forms.ComboBox
[void]$picker.Items.AddRange(@('No applications','Local EXE / MSI installers (USB)'))
$picker.SelectedIndex=1
$panel.Controls.AddRange(@($label,$input,$picker));$form.Controls.Add($panel)
try {
    [void]$form.Handle;[void]$label.Handle
    foreach($lang in @('en','fr','ar','es','ar','en')){
        $env:MASTERSETUP_LANG=$lang
        Set-MasterControlLanguage $form
        Set-MasterControlLanguage $form
        if($form.IsDisposed -or $panel.Controls.Count -ne 3){throw 'Language switch changed controls'}
        if($input.Text -cne 'AbC&123'){throw 'Language switch modified input'}
        if($picker.SelectedIndex -ne 1){throw 'Language switch modified selection'}
        if($label.Text -cne (M 'Continue')){throw 'Label was not translated'}
        if($form.RightToLeft -eq 'Yes'){throw 'Whole form RTL must remain unchanged'}
    }
} finally {$form.Dispose();$env:MASTERSETUP_LANG='en'}
Write-Host 'PASS: repeated language switches preserve controls, input and app mode.'
