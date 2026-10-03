param(
    [string]$SiteUrl,

    [string]$ClientId,

    [string]$ListName = "WebMonitoring",

    [Parameter(Mandatory)]
    [string]$Title,

    [Parameter(Mandatory)]
    [string]$Url,

    [Parameter(Mandatory)]
    [string]$MatchStart,

    [Parameter(Mandatory)]
    [string]$MatchEnd,

    [switch]$Inactive
)

function Get-DotEnvConfig {
    param(
        [string]$Path
    )

    $config = @{}
    if (-not (Test-Path -Path $Path))
    {
        return $config
    }

    foreach ($line in Get-Content -Path $Path)
    {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith("#"))
        {
            continue
        }

        $parts = $trimmed.Split("=", 2)
        if ($parts.Count -ne 2)
        {
            continue
        }

        $key = $parts[0].Trim()
        $value = $parts[1].Trim()

        if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'")))
        {
            $value = $value.Substring(1, $value.Length - 2)
        }

        $config[$key] = $value
    }

    return $config
}

$envConfig = Get-DotEnvConfig -Path (Join-Path -Path $PSScriptRoot -ChildPath "..\.env")
if (-not $SiteUrl) { $SiteUrl = $envConfig["SITE_URL"] }
if (-not $ClientId) { $ClientId = $envConfig["CLIENT_ID"] }
if ($envConfig["LIST_NAME"]) { $ListName = $envConfig["LIST_NAME"] }

if (-not $SiteUrl) { throw "Missing SiteUrl. Provide -SiteUrl or set SITE_URL in .env." }
if (-not $ClientId) { throw "Missing ClientId. Provide -ClientId or set CLIENT_ID in .env." }

Connect-PnPOnline `
    -Url $SiteUrl `
    -Interactive `
    -ClientId $ClientId

$escapedUrl = $Url.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;").Replace("'", "&apos;").Replace('"', "&quot;")
$existingItem = Get-PnPListItem `
    -List $ListName `
    -Query "<View><Query><Where><Eq><FieldRef Name='Url'/><Value Type='Note'>$escapedUrl</Value></Eq></Where></Query><RowLimit>1</RowLimit></View>"

if (-not $existingItem)
{
    $activeValue = -not $Inactive.IsPresent
    Add-PnPListItem `
        -List $ListName `
        -Values @{
            Title      = $Title
            Url        = $Url
            MatchStart = $MatchStart
            MatchEnd   = $MatchEnd
            Active     = $activeValue
        }
}
