function Read-Yes($prompt, [string]$Summary = '') {
    if ($Summary) {
        Write-Host $Summary
        if (Get-Command Get-AtelierConfirmation -ErrorAction SilentlyContinue) {
            $accepted=Get-AtelierConfirmation $prompt $Summary
            if (!$accepted -and $state) {$state.Cancelled=$true}
            return [bool]$accepted
        }
    }
    do {
        $reply = (Read-Host "$prompt [y/n]").Trim()
        if ($reply -imatch '^(o|oui|y|yes)$') { return $true }
        if ($reply -imatch '^(n|non|no)$') { if ($state) { $state.Cancelled=$true }; return $false }
        Write-Host 'Enter y or n (o is also accepted).'
    } while ($true)
}
