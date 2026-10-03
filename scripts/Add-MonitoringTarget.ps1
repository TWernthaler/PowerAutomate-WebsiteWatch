param(
    [Parameter(Mandatory)]
    [string]$SiteUrl,

    [Parameter(Mandatory)]
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
