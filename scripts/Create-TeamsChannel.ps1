param(
    [string]$TeamDisplayName,
    [string]$ChannelDisplayName,
    [ValidateSet("standard", "private", "shared")]
    [string]$MembershipType = "standard"
)

. "$PSScriptRoot\DotEnv.ps1"

$envConfig = Get-DotEnvConfig
if (-not $TeamDisplayName) { $TeamDisplayName = $envConfig["TEAMS_TEAM_NAME"] }
if (-not $ChannelDisplayName) { $ChannelDisplayName = $envConfig["TEAMS_CHANNEL_NAME"] }

if (-not $TeamDisplayName) { throw "Missing TeamDisplayName. Provide -TeamDisplayName or set TEAMS_TEAM_NAME in .env." }
if (-not $ChannelDisplayName) { throw "Missing ChannelDisplayName. Provide -ChannelDisplayName or set TEAMS_CHANNEL_NAME in .env." }

if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Teams))
{
    throw "Module Microsoft.Graph.Teams not found. Install with: Install-Module Microsoft.Graph.Teams -Scope CurrentUser"
}

Import-Module Microsoft.Graph.Teams -ErrorAction Stop

if (-not (Get-MgContext))
{
    Connect-MgGraph -Scopes "Group.ReadWrite.All","Channel.ReadWrite.All"
}

$groupCount = 0
$groups = Get-MgGroup -Filter "resourceProvisioningOptions/Any(x:x eq 'Team')" -ConsistencyLevel eventual -Count groupCount -All
$group = $groups | Where-Object { $_.DisplayName -eq $TeamDisplayName }
if (-not $group)
{
    throw "Team '$TeamDisplayName' not found. Create the team first or use the exact display name."
}
if ($group.Count -gt 1)
{
    throw "Multiple teams found with display name '$TeamDisplayName'. Use a unique team name."
}

$teamId = $group[0].Id

$existingChannel = Get-MgTeamChannel -TeamId $teamId | Where-Object { $_.DisplayName -eq $ChannelDisplayName } | Select-Object -First 1
if (-not $existingChannel)
{
    $created = New-MgTeamChannel -TeamId $teamId -DisplayName $ChannelDisplayName -MembershipType $MembershipType
    $channelId = $created.Id
}
else
{
    $channelId = $existingChannel.Id
}

Write-Host "TEAMS_TEAM_ID=$teamId"
Write-Host "TEAMS_CHANNEL_ID=$channelId"
