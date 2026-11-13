$script:MasterLanguageTable=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'languages.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if($env:MASTERSETUP_LANG -notin 'en','fr','ar','es') {
    $saved=Join-Path $PSScriptRoot 'ui-language.txt'
    $env:MASTERSETUP_LANG=if(Test-Path $saved){(Get-Content $saved -Raw).Trim()}else{'en'}
    if($env:MASTERSETUP_LANG -notin 'en','fr','ar','es'){$env:MASTERSETUP_LANG='en'}
}
function M([string]$Text) {
    if(!$Text){return $Text}
    $canonical=$Text
    foreach($prop in $script:MasterLanguageTable.PSObject.Properties){
        if($prop.Name -eq $Text -or $Text -in @($prop.Value.fr,$prop.Value.ar,$prop.Value.es)){$canonical=$prop.Name;break}
    }
    $entry=$script:MasterLanguageTable.PSObject.Properties[$canonical]
    if($env:MASTERSETUP_LANG -eq 'en' -or !$entry){return $canonical}
    return [string]$entry.Value.($env:MASTERSETUP_LANG)
}
function Convert-MasterReview([string]$Text){
    $lines=foreach($line in ($Text -split "`r?`n")){
        $translated=M $line
        if($translated -eq $line){
            foreach($prop in $script:MasterLanguageTable.PSObject.Properties){
                if($prop.Name.EndsWith(':') -and $line.StartsWith($prop.Name)){
                    $translated=(M $prop.Name)+' '+(M ($line.Substring($prop.Name.Length).Trim()));break
                }
            }
        }
        $translated
    }
    return ($lines -join "`r`n")
}
function Set-MasterControlLanguage($Control){
    if(!$Control -or $Control.IsDisposed){return}
    # RTL can recreate native handles. Snapshot children BEFORE changing properties.
    $children=@($Control.Controls | ForEach-Object {$_})
    if($Control -is [Windows.Forms.Label] -or $Control -is [Windows.Forms.Button] -or $Control -is [Windows.Forms.CheckBox] -or $Control -is [Windows.Forms.Form]){
        $translated=M $Control.Text
        if($Control.Text -cne $translated){$Control.Text=$translated}
        # Keep form/container geometry stable. Apply RTL only to leaf text controls.
        if($Control -isnot [Windows.Forms.Form]){
            $direction=if($env:MASTERSETUP_LANG -eq 'ar'){[Windows.Forms.RightToLeft]::Yes}else{[Windows.Forms.RightToLeft]::No}
            if($Control.RightToLeft -ne $direction){$Control.RightToLeft=$direction}
        }
    }
    if($Control -is [Windows.Forms.ComboBox] -and $Control.Name -ne 'MasterLanguageSelector'){
        $items=@($Control.Items | ForEach-Object {[string]$_})
        for($i=0;$i -lt $items.Count;$i++){
            $translated=M $items[$i]
            if($items[$i] -cne $translated){$Control.Items[$i]=$translated}
        }
    }
    foreach($child in $children){Set-MasterControlLanguage $child}
}
function Enable-MasterLanguage($Form){
    Set-MasterControlLanguage $Form
    $languageTimer=New-Object Windows.Forms.Timer
    $languageTimer.Interval=1000
    $languageState=@{Busy=$false;Failed=$false}
    $handler={
        if($languageState.Busy -or $languageState.Failed -or $Form.IsDisposed){return}
        $languageState.Busy=$true
        try {Set-MasterControlLanguage $Form}
        catch {
            $languageState.Failed=$true;$languageTimer.Stop()
            [void][Windows.Forms.MessageBox]::Show($Form,('Language refresh failed: '+$_.Exception.Message),'Master Setup')
        } finally {$languageState.Busy=$false}
    }.GetNewClosure()
    $languageTimer.Add_Tick($handler);$languageTimer.Start()
    $cleanup={$languageTimer.Stop();$languageTimer.Dispose()}.GetNewClosure()
    $Form.Add_FormClosed($cleanup)
}
