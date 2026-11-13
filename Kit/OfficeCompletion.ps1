function Test-MasterOfficeSuccessText {
    param([string[]]$Names)
    $success=@($Names | Where-Object {$_ -match "^(Tout est prêt\s*!|You're all set!?|You’re all set!?|¡?Todo listo!?|تم الانتهاء.*)$"}).Count -gt 0
    $installed=@($Names | Where-Object {$_ -match '(Office|Microsoft 365).*(install[ée]e?s|installed|instaladas|instalados|تثبيت)'}).Count -gt 0
    return ($success -and $installed)
}
# Close only a recognized success page of this Office installation session.
function Close-MasterOfficeSuccess {
    param([datetime]$Started)
    try {
        Add-Type -AssemblyName UIAutomationClient
        Add-Type -AssemblyName UIAutomationTypes
        $desktop=[Windows.Automation.AutomationElement]::RootElement
        $windows=$desktop.FindAll([Windows.Automation.TreeScope]::Children,[Windows.Automation.Condition]::TrueCondition)
        foreach($window in $windows){
            $proc=Get-Process -Id $window.Current.ProcessId -ErrorAction SilentlyContinue
            if(!$proc -or $proc.StartTime -lt $Started.AddSeconds(-2)){continue}
            if($proc.ProcessName -notmatch '^(OfficeC2RClient|OfficeClickToRun|setup|IntegratedOffice)$'){continue}
            $sig=Get-AuthenticodeSignature -LiteralPath $proc.Path
            if($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch '(?:^|, )O=Microsoft Corporation(?:,|$)'){continue}
            $nodes=$window.FindAll([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.Condition]::TrueCondition)
            $names=@(foreach($node in $nodes){$node.Current.Name})
            if(!(Test-MasterOfficeSuccessText -Names $names)){continue}
            foreach($node in $nodes){
                if($node.Current.ControlType -eq [Windows.Automation.ControlType]::Button -and $node.Current.Name -match '^(Close|Fermer|Cerrar|إغلاق)$' -and $node.Current.IsEnabled){
                    $pattern=$null
                    if($node.TryGetCurrentPattern([Windows.Automation.InvokePattern]::Pattern,[ref]$pattern)){
                        ([Windows.Automation.InvokePattern]$pattern).Invoke()
                        Write-Host 'Office: recognized success page closed automatically.'
                        return $true
                    }
                }
            }
        }
    } catch {Write-Verbose ('Office completion inspection: '+$_.Exception.Message)}
    return $false
}
