# Read-only parser validation and XML tests in a temporary directory.
$ErrorActionPreference='Stop'
$issues=@()
foreach ($file in Get-ChildItem $PSScriptRoot -Filter *.ps1 -File) {
    $tokens=$null;$errors=$null
    [void][Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
    foreach ($error in $errors) { $issues+="$($file.Name):$($error.Extent.StartLineNumber) $($error.Message)" }
}
if ($issues.Count) { throw ($issues -join [Environment]::NewLine) }
. "$PSScriptRoot\AutoAnswer.ps1"
$temp=Join-Path ([IO.Path]::GetTempPath()) ('AtelierCheck-'+[guid]::NewGuid().ToString('N'))
try {
    [void][IO.Directory]::CreateDirectory($temp)
    $base=Join-Path $temp 'base.xml'
    '<unattend xmlns="urn:schemas-microsoft-com:unattend"><settings pass="oobeSystem"><component name="Microsoft-Windows-Shell-Setup"><OOBE/></component></settings></unattend>' | Set-Content $base
    foreach ($firmware in 1,2) {
        New-AutoAnswers -BaseAnswer $base -Destination $temp -Firmware $firmware -Index 3 -Language 'en-US' -Keyboard '040c:0000040c' -SetupKey 'AAAAA-BBBBB-CCCCC-DDDDD-EEEEE'
        for ($i=0;$i -lt 32;$i++) {
            [xml]$doc=Get-Content (Join-Path $temp "answer-$i.xml") -Raw
            $ns=New-Object Xml.XmlNamespaceManager($doc.NameTable);$ns.AddNamespace('u','urn:schemas-microsoft-com:unattend')
            $ids=@($doc.SelectNodes('//u:DiskID',$ns))
            if ($ids.Count -ne 2 -or @($ids|Where-Object InnerText -ne ([string]$i)).Count) { throw 'DiskID XML incoherent.' }
            if ($doc.SelectSingleNode('//u:UserData/u:ProductKey/u:Key',$ns).InnerText -ne 'AAAAA-BBBBB-CCCCC-DDDDD-EEEEE') { throw 'Regression ProductKey : cle de SETUP absente.' }
            $partition=$doc.SelectSingleNode('//u:InstallTo/u:PartitionID',$ns).InnerText
            $expected=if ($firmware -eq 2) {'3'} else {'2'}
            if ($partition -ne $expected) { throw 'Partition Windows incoherente.' }
            if ($doc.SelectSingleNode('//u:MetaData/u:Value',$ns).InnerText -ne '3') { throw 'Edition XML incoherente.' }
        }
    }
    . "$PSScriptRoot\InstallKey.ps1"
    $sources=Join-Path $temp 'sources'
    [void][IO.Directory]::CreateDirectory($sources)
    $product=Join-Path $sources 'product.ini'
    @('[cmi]','Professional=AAAAA-BBBBB-CCCCC-DDDDD-EEEEE') | Set-Content $product
    if((Get-MediaInstallKey $temp 'Professional') -ne 'AAAAA-BBBBB-CCCCC-DDDDD-EEEEE'){throw 'Lecture cle de SETUP incorrecte.'}
    foreach($fixture in @(
        @('[cmi]','Core=AAAAA-BBBBB-CCCCC-DDDDD-EEEEE'),
        @('[other]','Professional=AAAAA-BBBBB-CCCCC-DDDDD-EEEEE'),
        @('[cmi]','Professional='),
        @('[cmi]','Professional=AAAAA-BBBBB-CCCCC-DDDDD-EEEEE','Professional=FFFFF-GGGGG-HHHHH-IIIII-JJJJJ')
    )) {
        $fixture | Set-Content $product
        $blocked=$false
        try { $null=Get-MediaInstallKey $temp 'Professional' } catch { $blocked=$true }
        if(!$blocked){throw 'Cle de SETUP absente/ambigue acceptee a tort.'}
    }
    # Regression from user ISO: product.ini is genuinely absent.
    Remove-Item -LiteralPath $product
    $expectedDefaults=@{
        Core='YTMG3-N6DKC-DKB77-7M9GH-8HVX7';CoreN='4CPRK-NM3K3-X6XXQ-RXX86-WXCHW'
        CoreSingleLanguage='BT79Q-G7N6G-PGBYW-4YWX6-6F4BT';Professional='VK7JG-NPHTM-C97JM-9MPGT-3V66T'
        ProfessionalN='2B87N-8KFHP-DKV6R-Y2C8J-PKCKT';Education='YNMGQ-8RYV3-4PGQ3-C8XTP-7CFBY'
        EducationN='84NGF-MHBT6-FXBX8-QWJK7-DRR8H';ProfessionalEducation='8PTT6-RNW4C-6V7J2-C2D3X-MHBPB'
        ProfessionalEducationN='GJTYN-HDMQY-FRR76-HVGC7-QPF8P';ProfessionalWorkstation='DXG7C-N36C4-C4HTG-X4T3X-2YV77'
        ProfessionalWorkstationN='WYPNQ-8C467-V2W6J-TX4WX-WT2RQ'
    }
    foreach($edition in $expectedDefaults.Keys){
        $key=Get-MediaInstallKey $temp $edition 6>$null
        if($key -cne $expectedDefaults[$edition]){throw "Mauvais profil de SETUP pour $edition."}
        New-AutoAnswers -BaseAnswer $base -Destination $temp -Firmware 2 -Index 3 -Language 'en-US' -Keyboard '0809:00000809' -SetupKey $key
        [xml]$answer=Get-Content (Join-Path $temp 'answer-0.xml') -Raw
        $nm=New-Object Xml.XmlNamespaceManager($answer.NameTable);$nm.AddNamespace('u','urn:schemas-microsoft-com:unattend')
        if($answer.SelectSingleNode('//u:UserData/u:ProductKey/u:Key',$nm).InnerText -ne $key){throw 'Cle absente du XML final.'}
    }
    $blocked=$false
    try{$null=Get-MediaInstallKey $temp 'UnknownEdition'}catch{$blocked=$true}
    if(!$blocked){throw 'Une edition inconnue a recu une cle par defaut.'}
    Write-Host 'Validation locale : XML, fichier product.ini present/absent, 11 editions et rejet des editions inconnues OK.'


} finally { if(Test-Path $temp){Remove-Item -LiteralPath $temp -Recurse -Force} }
