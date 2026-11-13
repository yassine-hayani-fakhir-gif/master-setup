# One representation for both the local account and its one-time automatic logon.
# Base64 is reversible encoding, not encryption.
function New-AccountPasswordXml {
    param([AllowEmptyString()][string]$Password = '')
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Password+'Password'))
    return "<Password><Value>$encoded</Value><PlainText>false</PlainText></Password>"
}
