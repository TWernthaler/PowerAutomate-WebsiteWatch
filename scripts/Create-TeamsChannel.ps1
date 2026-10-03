<#
.SYNOPSIS
Erstellt einen Teams-Kanal falls nicht vorhanden und liefert Team/Channel IDs zurück.
#>
param(
    [string]$TeamDisplayName,
    [string]$ChannelDisplayName,
    [ValidateSet("standard", "private", "shared")]
    [string]$MembershipType = "standard",
    [switch]$WriteToEnv
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
    Connect-MgGraph -Scopes "Group.Read.All","Channel.ReadWrite.All"
}

$groupCount = 0
$groups = Get-MgGroup -Filter "resourceProvisioningOptions/Any(x:x eq 'Team')" -ConsistencyLevel eventual -Count groupCount -All
$group = @($groups | Where-Object { $_.DisplayName -eq $TeamDisplayName })
if ($group.Count -gt 1)
{
    throw "Multiple teams found with display name '$TeamDisplayName'. Use a unique team name."
}
if (-not $group)
{
    throw "Team '$TeamDisplayName' not found. Create the team first or use the exact display name."
}

$teamId = $group[0].Id

$existingChannel = $null
$canUseServerFilter = $ChannelDisplayName -match "^[A-Za-z0-9 _\-\.\(\)]+$"
if ($canUseServerFilter)
{
    $escapedChannelName = $ChannelDisplayName.Replace("'", "''")
    $existingChannel = @(Get-MgTeamChannel -TeamId $teamId -Filter "displayName eq '$escapedChannelName'" | Where-Object { $_.DisplayName -eq $ChannelDisplayName }) | Select-Object -First 1
}

if (-not $existingChannel)
{
    # Fallback without server-side filter for names with broader character sets.
    $existingChannel = @(Get-MgTeamChannel -TeamId $teamId | Where-Object { $_.DisplayName -eq $ChannelDisplayName }) | Select-Object -First 1
}
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

if ($WriteToEnv.IsPresent)
{
    $envPath = Join-Path -Path $PSScriptRoot -ChildPath "..\.env"
    if (-not (Test-Path -Path $envPath))
    {
        throw ".env file not found at '$envPath'. Create it first (for example from .env.example)."
    }

    $lines = Get-Content -Path $envPath
    $updated = @()
    $hasTeamId = $false
    $hasChannelId = $false

    foreach ($line in $lines)
    {
        if ($line -match "^TEAMS_TEAM_ID=")
        {
            $updated += "TEAMS_TEAM_ID=$teamId"
            $hasTeamId = $true
            continue
        }
        if ($line -match "^TEAMS_CHANNEL_ID=")
        {
            $updated += "TEAMS_CHANNEL_ID=$channelId"
            $hasChannelId = $true
            continue
        }
        $updated += $line
    }

    if (-not $hasTeamId) { $updated += "TEAMS_TEAM_ID=$teamId" }
    if (-not $hasChannelId) { $updated += "TEAMS_CHANNEL_ID=$channelId" }

    Set-Content -Path $envPath -Value $updated
    Write-Host "Updated .env with TEAMS_TEAM_ID and TEAMS_CHANNEL_ID."
}
