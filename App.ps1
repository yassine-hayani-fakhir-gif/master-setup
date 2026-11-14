$ErrorActionPreference = 'Stop'
try {
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
. "$PSScriptRoot\Kit\Language.ps1"
$parseIssues=@()
foreach ($scriptFile in Get-ChildItem (Join-Path $PSScriptRoot 'Kit') -Filter *.ps1 -File) {
    $t=$null;$e=$null
    [void][Management.Automation.Language.Parser]::ParseFile($scriptFile.FullName,[ref]$t,[ref]$e)
    foreach ($issue in $e) { $parseIssues+="$($scriptFile.Name):$($issue.Extent.StartLineNumber) $($issue.Message)" }
}
if ($parseIssues.Count) {
    [void][Windows.Forms.MessageBox]::Show(($parseIssues -join [Environment]::NewLine),'Source validation - execution stopped')
    return
}

. "$PSScriptRoot\Kit\Welcome.ps1"
$startupRoute=Show-MasterWelcome -IsWinPE $false
if(!$startupRoute){return}
if($startupRoute -eq 'BootGuide'){
    [void][Windows.Forms.MessageBox]::Show((M 'Copy MasterSetup-WinPE-x64.iso to Ventoy, restart this PC and select the ISO from Boot Menu. Back up files before clean installation.'),'Master Setup')
    return
}
if($startupRoute -in 'Auto','Apps'){
    Start-Process "$PSHOME\powershell.exe" -Verb RunAs -ArgumentList ('-STA -NoProfile -WindowStyle Hidden -ExecutionPolicy RemoteSigned -File "'+(Join-Path $PSScriptRoot 'Kit\Suivi.ps1')+'" -Task '+$startupRoute)
    return
}
$kit = Join-Path $PSScriptRoot 'Kit'
$navy = '#EAF0FF'
$teal = '#53E4D0'
$muted = '#9DAFCB'
function Color($hex) { [Drawing.ColorTranslator]::FromHtml($hex) }
function Panel($parent,$x,$y,$w,$h,$bg) {
    $p = New-Object Windows.Forms.Panel
    $p.SetBounds($x,$y,$w,$h)
    $p.BackColor = Color $bg
    $parent.Controls.Add($p)
    return $p
}
function Caption($parent,$x,$y,$w,$h,$value,$size,$ink,$bold=$false) {
    $l = New-Object Windows.Forms.Label
    $l.SetBounds($x,$y,$w,$h)
    $l.AutoEllipsis = $true
    $l.TextAlign = 'MiddleLeft'
    $style = if ($bold) { 'Bold' } else { 'Regular' }
    $l.Font = New-Object Drawing.Font('Segoe UI',[single]$size,[Drawing.FontStyle]$style)
    $l.ForeColor = Color $ink
    $l.Text = $value
    $parent.Controls.Add($l)
    return $l
}
function Action($parent,$x,$y,$w,$title,$bg,$ink,$handler) {
    $b = New-Object Windows.Forms.Button
    $b.SetBounds($x,$y,$w,38)
    $b.Text = $title
    $b.FlatStyle = 'Flat'
    $b.FlatAppearance.BorderSize = 0
    $b.FlatAppearance.MouseOverBackColor=Color '#33527A'
    $b.Font=New-Object Drawing.Font('Segoe UI',10,[Drawing.FontStyle]::Bold)
    $b.BackColor = Color $bg
    $b.ForeColor = Color $ink
    $b.Cursor = 'Hand'
    $b.Add_Click($handler)
    $parent.Controls.Add($b)
}
function Read-Class($name) {
    try { Get-CimInstance -ClassName $name -OperationTimeoutSec 5 -ErrorAction Stop } catch { }
}
function Display($value) {
    if ([string]::IsNullOrWhiteSpace([string]$value)) { return 'Unavailable' }
    return ([string]$value).Trim()
}
function Capacity($bytes) {
    if ($bytes -gt 0) { return ('{0:0.##} GiB' -f ($bytes / 1GB)) }
    return 'Unavailable'
}
function Launch-Step($file) {
    try {
        $path = Join-Path $kit $file
        if (!(Test-Path -LiteralPath $path)) { throw 'Extract the entire ZIP before running this action.' }
        $runner = Join-Path $kit 'Suivi.ps1'
        $task = [IO.Path]::GetFileNameWithoutExtension($file)
        Start-Process "$PSHOME\powershell.exe" -Verb RunAs -ArgumentList ('-STA -NoProfile -WindowStyle Hidden -ExecutionPolicy RemoteSigned -File "'+$runner+'" -Task '+$task)
    } catch { [void][Windows.Forms.MessageBox]::Show($form,$_.Exception.Message) }
}
$form=New-Object Windows.Forms.Form
$form.Text='Master Setup | Developed by Yassine'
$form.StartPosition='CenterScreen';$form.AutoScroll=$true
$wa=[Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$form.ClientSize=New-Object Drawing.Size([Math]::Min(948,$wa.Width-38),[Math]::Min(746,$wa.Height-72))
$form.BackColor=Color '#0A1120';$form.Font=New-Object Drawing.Font('Segoe UI',10)
$canvas=Panel $form 0 0 910 710 '#0A1120'
$header=Panel $canvas 0 0 910 128 '#101D34'
$null=Panel $header 0 0 6 128 '#53E4D0'
$null=Caption $header 26 14 440 24 'WINDOWS / OFFICE / APPLICATIONS' 9 '#53E4D0' $true
$null=Caption $header 24 39 530 53 'MASTER SETUP' 30 '#F3F6FF' $true
$null=Caption $header 27 96 520 22 'From your Windows image to your everyday apps.' 10 '#9DAFCB'
$badge=Panel $header 680 49 204 29 '#29234D'
$null=Caption $badge 12 1 184 26 '0.18.1 / PREVIEW' 9 '#C3ACFF' $true
$null=Caption $header 680 83 210 30 'Developed by Yassine' 10 '#9DAFCB'
$hostLabel=Caption $canvas 22 136 700 28 $env:COMPUTERNAME 12 '#EAF0FF' $true
$null=Caption $canvas 22 166 850 22 'DEVICE OVERVIEW  /  Check the target before deployment.' 9 $muted
$tiles=@{}
$names=@('PC','Windows','RAM','Serial','CPU','Firmware','Storage','Secure Boot','Network')
$accent=@('#53E4D0','#A78BFA','#73B8FF')
for ($i=0;$i -lt $names.Count;$i++) {
    $topic=$names[$i];$x=22+292*($i%3);$y=200+88*[Math]::Floor($i/3)
    $card=Panel $canvas $x $y 280 78 '#14223A'
    $stripe=Panel $card 0 0 3 78 $accent[$i%3]
    $title=Caption $card 16 7 220 22 ('{0:00}  /  {1}' -f ($i+1),$topic.ToUpperInvariant()) 9 $muted
    $val=Caption $card 16 32 249 37 'Reading...' 12 '#EAF0FF' $true
    $tiles[$topic]=$val
}
Action $canvas 22 480 864 'Offline apps / package guide' '#203451' '#B9CFFF' {Start-Process notepad.exe -ArgumentList ('"'+(Join-Path $PSScriptRoot 'APPS_OFFLINE.txt')+'"')}
$null=Caption $canvas 22 522 850 12 '01  Select  /  02  Confirm disk  /  03  Prepare  /  04  Install' 11 '#BBCBE5'
Action $canvas 22 538 350 'Resume an existing installation' '#203451' '#B9CFFF' {
    $installed=Join-Path $env:SystemDrive 'SetupKit'
    $version=Join-Path $installed 'profile-version.txt'
    if(!(Test-Path $version) -or (Get-Content $version -Raw).Trim() -notin '0.13','0.13.1','0.14','0.14.1','0.15','0.16','0.17'){
        [void][Windows.Forms.MessageBox]::Show($form,'Available after a Master Setup installation. Resuming does not reinstall Windows.');return
    }
    try {
        Start-Process "$PSHOME\powershell.exe" -Verb RunAs -ArgumentList ('-STA -NoProfile -WindowStyle Hidden -ExecutionPolicy RemoteSigned -File "'+(Join-Path $PSScriptRoot 'Kit\Suivi.ps1')+'" -Task Finish -ProfileRoot "'+$installed+'"')
    } catch {[void][Windows.Forms.MessageBox]::Show($form,$_.Exception.Message)}
}
Action $canvas 390 538 496 'Install apps on this PC' '#203451' '#B9CFFF' {Launch-Step 'Apps.ps1'}
$deploy=Panel $canvas 22 574 864 93 '#182842'
$null=Panel $deploy 0 0 4 93 '#A78BFA'
$null=Caption $deploy 18 9 820 25 'USB MEDIA  /  DISK SELECTION  /  AUTOMATIC RESTART' 10 '#BBCBE5'
Action $deploy 18 43 828 'Install automatically on this machine' '#53E4D0' '#0A192A' {Launch-Step 'Auto.ps1'}
$null=Caption $canvas 22 679 660 24 'Guided deployment  /  Detailed logs  /  Confirm target before erasing' 9 '#7E93B2'
Action $canvas 710 673 176 'Open logs' '#203451' '#B9CFFF' {
    $folder=Join-Path $env:LOCALAPPDATA 'AtelierWindows\Journaux'
    [void][IO.Directory]::CreateDirectory($folder)
    Start-Process explorer.exe -ArgumentList ('"'+$folder+'"')
}
$form.Add_Shown({
    $form.Refresh()
    $cs=Read-Class Win32_ComputerSystem
    $prod=Read-Class Win32_ComputerSystemProduct
    $model=$cs.Model
    $hostLabel.Text=$env:COMPUTERNAME+'  /  '+$cs.Manufacturer
    if ($cs.Manufacturer -match 'Lenovo') {
        if ($prod.Version -match '(Think|Idea|Yoga|Legion)') {$model='Lenovo '+$prod.Version}
        elseif ($model -like '20R3*') {$model='Lenovo ThinkPad L13'}
    }
    $tiles.PC.Text=Display $model
    $os=Read-Class Win32_OperatingSystem
    $tiles.Windows.Text=Display ($os.Caption -replace '^Microsoft ','')
    $ram=@(Read-Class Win32_PhysicalMemory)
    $bytes=if ($ram.Count) {($ram|Measure-Object Capacity -Sum).Sum} else {$cs.TotalPhysicalMemory}
    $tiles.RAM.Text=Capacity $bytes
    $tiles.Serial.Text=Display ((Read-Class Win32_BIOS).SerialNumber)
    $tiles.CPU.Text=Display (((Read-Class Win32_Processor).Name) -join ' / ')
    try {
        Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public static class MasterFirmware { [DllImport("kernel32.dll", SetLastError=true)] public static extern bool GetFirmwareType(out uint t); }'
        [uint32]$fw=0
        if(![MasterFirmware]::GetFirmwareType([ref]$fw)){throw 'Firmware unavailable'}
        $tiles.Firmware.Text=switch($fw){1{'BIOS'} 2{'UEFI'} default{'Unknown'}}
    } catch {$tiles.Firmware.Text='Unknown'}
    try {$tiles['Secure Boot'].Text=if(Confirm-SecureBootUEFI -ErrorAction Stop){'Enabled'}else{'Disabled'}} catch {$tiles['Secure Boot'].Text='Unavailable / access required'}
    $disks=@(Get-Disk -ErrorAction SilentlyContinue)
    $tiles.Storage.Text=if ($disks.Count) {"$($disks.Count) disk(s) · "+(Capacity (($disks|Measure-Object Size -Sum).Sum))} else {'Unavailable'}
    $links=@(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object Status -eq 'Up')
    $tiles.Network.Text=if ($links.Count) {$links.Name -join ' / '} else {'Offline'}
    $net=@(Get-NetConnectionProfile -ErrorAction SilentlyContinue | Where-Object { $_.IPv4Connectivity -eq 'Internet' -or $_.IPv6Connectivity -eq 'Internet' })
    if($net.Count){$tiles.Network.Text='Internet detected by Windows'}
})
$languagePicker=New-Object Windows.Forms.ComboBox
$languagePicker.Name='MasterLanguageSelector'
$languagePicker.SetBounds(680,12,204,28);$languagePicker.DropDownStyle='DropDownList'
[void]$languagePicker.Items.AddRange(@('English','Français','العربية','Español'))
$languagePicker.SelectedIndex=[array]::IndexOf(@('en','fr','ar','es'),$env:MASTERSETUP_LANG)
$languagePicker.Add_SelectedIndexChanged({
    $env:MASTERSETUP_LANG=@('en','fr','ar','es')[$languagePicker.SelectedIndex]
    try {Set-MasterControlLanguage $form}
    catch {[void][Windows.Forms.MessageBox]::Show($form,('Language change failed: '+$_.Exception.Message),'Master Setup')}
})
$header.Controls.Add($languagePicker);$languagePicker.BringToFront()
Enable-MasterLanguage $form
[void]$form.ShowDialog()

} catch {
    $startupError=$_.Exception.Message+[Environment]::NewLine+$_.InvocationInfo.PositionMessage
    Write-Error $startupError -ErrorAction Continue
    try {[void][Windows.Forms.MessageBox]::Show($startupError,'Master Setup - Startup error')} catch {}
    exit 1
}
