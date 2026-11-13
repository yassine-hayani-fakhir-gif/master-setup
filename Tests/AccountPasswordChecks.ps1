. "$PSScriptRoot\..\Kit\AccountPassword.ps1"
foreach($password in @('', 'AbC', 'a&<>"')) {
    [xml]$xml=New-AccountPasswordXml -Password $password
    $decoded=[Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($xml.Password.Value))
    if($decoded -cne ($password+'Password')){throw 'Password encoding changed the value.'}
    if($xml.Password.PlainText -ne 'false'){throw 'Unexpected password representation.'}
}
[xml]$blank=New-AccountPasswordXml -Password ''
if($blank.Password.Value -ne 'UABhAHMAcwB3AG8AcgBkAA=='){throw 'Blank password missing.'}
Write-Host 'PASS: blank, mixed-case and XML-special-character password encoding.'
