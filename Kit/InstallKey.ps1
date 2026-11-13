# Installation-only keys: prefer ISO metadata; use known edition defaults if product.ini is absent.
# This is not a licence, an activation request, or a downloaded key.
function Get-MediaInstallKey {
    param([string]$MediaRoot,[string]$EditionId)
    if ($EditionId -notmatch '^[A-Za-z0-9]+$') { throw 'EditionID unavailable: no setup key selected.' }
    $path=Join-Path $MediaRoot 'sources\product.ini'
    if (!(Test-Path -LiteralPath $path)) {
        # Exact EditionID matching; never substitute Pro for an unknown edition.
        # Public installation defaults, not activation licences or KMS servers.
        $defaults=@{
            Core='YTMG3-N6DKC-DKB77-7M9GH-8HVX7'
            CoreN='4CPRK-NM3K3-X6XXQ-RXX86-WXCHW'
            CoreSingleLanguage='BT79Q-G7N6G-PGBYW-4YWX6-6F4BT'
            Professional='VK7JG-NPHTM-C97JM-9MPGT-3V66T'
            ProfessionalN='2B87N-8KFHP-DKV6R-Y2C8J-PKCKT'
            Education='YNMGQ-8RYV3-4PGQ3-C8XTP-7CFBY'
            EducationN='84NGF-MHBT6-FXBX8-QWJK7-DRR8H'
            ProfessionalEducation='8PTT6-RNW4C-6V7J2-C2D3X-MHBPB'
            ProfessionalEducationN='GJTYN-HDMQY-FRR76-HVGC7-QPF8P'
            ProfessionalWorkstation='DXG7C-N36C4-C4HTG-X4T3X-2YV77'
            ProfessionalWorkstationN='WYPNQ-8C467-V2W6J-TX4WX-WT2RQ'
        }
        if(!$defaults.ContainsKey($EditionId)) {
            throw "Edition '$EditionId' has no known setup key. Stopped before copying; do not select a random edition."
        }
        Write-Host "product.ini missing: using setup profile $EditionId (licensing handled separately)."
        return $defaults[$EditionId]
    }
    $section='';$keys=@()
    foreach ($line in [IO.File]::ReadAllLines($path)) {
        $value=$line.Trim()
        if($value -match '^\[([^\]]+)\]$'){$section=$Matches[1];continue}
        if($section -ine 'cmi'){continue}
        if($value -match '^([^=]+)\s*=\s*([A-Z0-9]{5}(?:-[A-Z0-9]{5}){4})\s*$') {
            if($Matches[1].Trim() -ieq $EditionId){$keys+=$Matches[2].ToUpperInvariant()}
        }
    }
    if($keys.Count -ne 1){throw "No unique setup key found in this ISO for $EditionId. Stopped before copying and restart."}
    return $keys[0]
}
