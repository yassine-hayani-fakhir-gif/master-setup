function New-AutoAnswers {
    param([string]$BaseAnswer,[string]$Destination,[int]$Firmware,[int]$Index,[string]$Language,[string]$Keyboard,[string]$SetupKey)
    if ($SetupKey -notmatch '^[A-Z0-9]{5}(-[A-Z0-9]{5}){4}$') { throw 'Setup key missing or invalid: stopped before restart.' }
    $ns='urn:schemas-microsoft-com:unattend'
    $base=[IO.File]::ReadAllText($BaseAnswer)
    if ($Firmware -eq 2) {
        $create='<CreatePartition wcm:action="add"><Order>1</Order><Type>EFI</Type><Size>260</Size></CreatePartition><CreatePartition wcm:action="add"><Order>2</Order><Type>MSR</Type><Size>16</Size></CreatePartition><CreatePartition wcm:action="add"><Order>3</Order><Type>Primary</Type><Extend>true</Extend></CreatePartition>'
        $modify='<ModifyPartition wcm:action="add"><Order>1</Order><PartitionID>1</PartitionID><Format>FAT32</Format><Label>System</Label></ModifyPartition><ModifyPartition wcm:action="add"><Order>2</Order><PartitionID>3</PartitionID><Format>NTFS</Format><Label>Windows</Label><Letter>C</Letter></ModifyPartition>'
        $part=3
    } else {
        $create='<CreatePartition wcm:action="add"><Order>1</Order><Type>Primary</Type><Size>550</Size></CreatePartition><CreatePartition wcm:action="add"><Order>2</Order><Type>Primary</Type><Extend>true</Extend></CreatePartition>'
        $modify='<ModifyPartition wcm:action="add"><Order>1</Order><PartitionID>1</PartitionID><Format>NTFS</Format><Label>System</Label><Active>true</Active></ModifyPartition><ModifyPartition wcm:action="add"><Order>2</Order><PartitionID>2</PartitionID><Format>NTFS</Format><Label>Windows</Label><Letter>C</Letter></ModifyPartition>'
        $part=2
    }
    $attrs='processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS"'
    $locale="<InputLocale>$Keyboard</InputLocale><SystemLocale>$Language</SystemLocale><UILanguage>$Language</UILanguage><UserLocale>$Language</UserLocale>"
    for ($disk=0;$disk -lt 32;$disk++) {
        [xml]$doc=$base
        $settings=$doc.CreateElement('settings',$ns);$settings.SetAttribute('pass','windowsPE')
        $settings.InnerXml=@"
<component xmlns="$ns" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" name="Microsoft-Windows-Setup" $attrs>
<DiskConfiguration><Disk wcm:action="add"><DiskID>$disk</DiskID><WillWipeDisk>true</WillWipeDisk><CreatePartitions>$create</CreatePartitions><ModifyPartitions>$modify</ModifyPartitions></Disk><WillShowUI>OnError</WillShowUI></DiskConfiguration>
<ImageInstall><OSImage><InstallFrom><MetaData wcm:action="add"><Key>/IMAGE/INDEX</Key><Value>$Index</Value></MetaData></InstallFrom><InstallTo><DiskID>$disk</DiskID><PartitionID>$part</PartitionID></InstallTo><WillShowUI>OnError</WillShowUI></OSImage></ImageInstall>
<UserData><AcceptEula>true</AcceptEula><ProductKey><Key>$SetupKey</Key><WillShowUI>OnError</WillShowUI></ProductKey></UserData>
</component>
<component xmlns="$ns" name="Microsoft-Windows-International-Core-WinPE" $attrs><SetupUILanguage><UILanguage>$Language</UILanguage></SetupUILanguage>$locale</component>
"@
        [void]$doc.DocumentElement.PrependChild($settings)
        $manager=New-Object Xml.XmlNamespaceManager($doc.NameTable);$manager.AddNamespace('u',$ns)
        $oobe=$doc.SelectSingleNode('//u:settings[@pass="oobeSystem"]',$manager)
        $intl=$doc.CreateElement('component',$ns)
        $fragment=[xml]"<component xmlns='$ns' name='Microsoft-Windows-International-Core' $attrs>$locale</component>"
        [void]$oobe.AppendChild($doc.ImportNode($fragment.DocumentElement,$true))
        $shellOobe=$doc.SelectSingleNode('//u:OOBE',$manager)
        $wireless=$doc.CreateElement('HideWirelessSetupInOOBE',$ns);$wireless.InnerText='true';[void]$shellOobe.AppendChild($wireless)
        $doc.Save((Join-Path $Destination ("answer-$disk.xml")))
    }
}
