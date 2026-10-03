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

    [int]$NotifyCooldownMinutes,

    [int]$RequestTimeoutSeconds,

    [int]$RetryCount,

    [string]$RequestUserAgent,

    [string]$RequestHeadersJson,

    [ValidateSet("None", "BearerEnvVar", "BasicEnvVar")]
    [string]$AuthType = "None",

    [string]$AuthSecretRef,

    [string]$TeamsTeamId,

    [string]$TeamsChannelId,

    [switch]$Inactive
)

. "$PSScriptRoot\DotEnv.ps1"

$envConfig = Get-DotEnvConfig
if (-not $SiteUrl) { $SiteUrl = $envConfig["SITE_URL"] }
if (-not $ClientId) { $ClientId = $envConfig["CLIENT_ID"] }
if (-not $PSBoundParameters.ContainsKey("ListName") -and $envConfig["LIST_NAME"]) { $ListName = $envConfig["LIST_NAME"] }
if (-not $PSBoundParameters.ContainsKey("NotifyCooldownMinutes") -and $envConfig["NOTIFY_COOLDOWN_MINUTES"]) { $NotifyCooldownMinutes = [int]$envConfig["NOTIFY_COOLDOWN_MINUTES"] }
if (-not $PSBoundParameters.ContainsKey("RequestTimeoutSeconds") -and $envConfig["REQUEST_TIMEOUT_SECONDS"]) { $RequestTimeoutSeconds = [int]$envConfig["REQUEST_TIMEOUT_SECONDS"] }
if (-not $PSBoundParameters.ContainsKey("RetryCount") -and $envConfig["REQUEST_RETRY_COUNT"]) { $RetryCount = [int]$envConfig["REQUEST_RETRY_COUNT"] }
if (-not $RequestUserAgent) { $RequestUserAgent = $envConfig["REQUEST_USER_AGENT"] }
if (-not $RequestHeadersJson) { $RequestHeadersJson = $envConfig["REQUEST_HEADERS_JSON"] }
if (-not $PSBoundParameters.ContainsKey("AuthType") -and $envConfig["AUTH_TYPE"]) { $AuthType = $envConfig["AUTH_TYPE"] }
if (-not $AuthSecretRef) { $AuthSecretRef = $envConfig["AUTH_SECRET_REF"] }
if (-not $TeamsTeamId) { $TeamsTeamId = $envConfig["TEAMS_TEAM_ID"] }
if (-not $TeamsChannelId) { $TeamsChannelId = $envConfig["TEAMS_CHANNEL_ID"] }

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
    $values = @{
        Title      = $Title
        Url        = $Url
        MatchStart = $MatchStart
        MatchEnd   = $MatchEnd
        Active     = $activeValue
    }
    if ($TeamsTeamId) { $values["TeamsTeamId"] = $TeamsTeamId }
    if ($TeamsChannelId) { $values["TeamsChannelId"] = $TeamsChannelId }
    if ($PSBoundParameters.ContainsKey("NotifyCooldownMinutes")) { $values["NotifyCooldownMinutes"] = $NotifyCooldownMinutes }
    if ($PSBoundParameters.ContainsKey("RequestTimeoutSeconds")) { $values["RequestTimeoutSeconds"] = $RequestTimeoutSeconds }
    if ($PSBoundParameters.ContainsKey("RetryCount")) { $values["RetryCount"] = $RetryCount }
    if ($RequestUserAgent) { $values["RequestUserAgent"] = $RequestUserAgent }
    if ($RequestHeadersJson) { $values["RequestHeadersJson"] = $RequestHeadersJson }
    if ($AuthType) { $values["AuthType"] = $AuthType }
    if ($AuthSecretRef) { $values["AuthSecretRef"] = $AuthSecretRef }
    $values["LastStatus"] = "NeverChecked"
    $values["ConsecutiveFailures"] = 0

    Add-PnPListItem `
        -List $ListName `
        -Values $values
}
else
{
    Write-Warning "Item with URL '$Url' already exists in list '$ListName'. Skipping."
}
