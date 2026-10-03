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

. "$PSScriptRoot\DotEnv.ps1"

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
else
{
    Write-Warning "Item with URL '$Url' already exists in list '$ListName'. Skipping."
}
