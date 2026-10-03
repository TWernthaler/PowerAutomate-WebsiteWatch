param(
    [Parameter(Mandatory)]
    [string]$SiteUrl,

    [Parameter(Mandatory)]
    [string]$ClientId,

    [Parameter(Mandatory)]
    [string]$Title,

    [Parameter(Mandatory)]
    [string]$Url,

    [Parameter(Mandatory)]
    [string]$MatchStart,

    [Parameter(Mandatory)]
    [string]$MatchEnd,

    [bool]$Active = $true
)

Connect-PnPOnline `
    -Url $SiteUrl `
    -Interactive `
    -ClientId $ClientId

Add-PnPListItem `
    -List "WebMonitoring" `
    -Values @{
        Title      = $Title
        Url        = $Url
        MatchStart = $MatchStart
        MatchEnd   = $MatchEnd
        Active     = $Active
    }
