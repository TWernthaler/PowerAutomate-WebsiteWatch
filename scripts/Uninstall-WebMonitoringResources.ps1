<#
.SYNOPSIS
Entfernt erzeugte WebMonitoring-Ressourcen kontrolliert.

.DESCRIPTION
Optionales Entfernen von SharePoint-Liste, Teams-Kanal/Team und Power-Platform-Solution.
Standardmäßig mit Bestätigungsabfragen; mit -Force ohne Rückfragen.
#>
param(
    [string]$SiteUrl,
    [string]$ClientId,
    [string]$ListName = "WebMonitoring",
    [string]$TeamId,
    [string]$ChannelId,
    [string]$TeamDisplayName,
    [string]$ChannelDisplayName,
    [string]$SolutionName = "WebsiteMonitoring",
    [switch]$RemoveSharePointList,
    [switch]$RemoveTeamsChannel,
    [switch]$RemoveFlowSolution,
    [switch]$RemoveTeam,
    [switch]$Force
)

. "$PSScriptRoot\DotEnv.ps1"

function Confirm-Step {
    param([string]$Message, [switch]$Force)
    if ($Force.IsPresent) { return $true }
    $answer = Read-Host "$Message (yes/no)"
    return $answer -eq "yes"
}

$envConfig = Get-DotEnvConfig
if (-not $SiteUrl) { $SiteUrl = $envConfig["SITE_URL"] }
if (-not $ClientId) { $ClientId = $envConfig["CLIENT_ID"] }
if (-not $PSBoundParameters.ContainsKey("ListName") -and $envConfig["LIST_NAME"]) { $ListName = $envConfig["LIST_NAME"] }
if (-not $TeamId) { $TeamId = $envConfig["TEAMS_TEAM_ID"] }
if (-not $ChannelId) { $ChannelId = $envConfig["TEAMS_CHANNEL_ID"] }
if (-not $TeamDisplayName) { $TeamDisplayName = $envConfig["TEAMS_TEAM_NAME"] }
if (-not $ChannelDisplayName) { $ChannelDisplayName = $envConfig["TEAMS_CHANNEL_NAME"] }
if (-not $PSBoundParameters.ContainsKey("SolutionName") -and $envConfig["FLOW_SOLUTION_NAME"]) { $SolutionName = $envConfig["FLOW_SOLUTION_NAME"] }

if (-not $RemoveSharePointList.IsPresent -and -not $RemoveTeamsChannel.IsPresent -and -not $RemoveFlowSolution.IsPresent -and -not $RemoveTeam.IsPresent)
{
    throw "No removal target selected. Use one or more switches: -RemoveSharePointList -RemoveTeamsChannel -RemoveFlowSolution -RemoveTeam"
}

if ($RemoveSharePointList.IsPresent)
{
    if (-not $SiteUrl) { throw "Missing SiteUrl for SharePoint removal." }
    if (-not $ClientId) { throw "Missing ClientId for SharePoint removal." }
    Connect-PnPOnline -Url $SiteUrl -Interactive -ClientId $ClientId
    $list = Get-PnPList -Identity $ListName -ErrorAction SilentlyContinue
    if ($list -and (Confirm-Step -Message "Remove SharePoint list '$ListName'?" -Force:$Force))
    {
        Remove-PnPList -Identity $ListName -Recycle -Force
        Write-Host "Removed SharePoint list '$ListName' (recycle bin)."
    }
}

if ($RemoveTeamsChannel.IsPresent -or $RemoveTeam.IsPresent)
{
    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Teams))
    {
        throw "Module Microsoft.Graph.Teams not found. Install with: Install-Module Microsoft.Graph.Teams -Scope CurrentUser"
    }

    Import-Module Microsoft.Graph.Teams -ErrorAction Stop
    Import-Module Microsoft.Graph.Groups -ErrorAction Stop
    if (-not (Get-MgContext))
    {
        Connect-MgGraph -Scopes "Group.ReadWrite.All","Channel.Delete.All"
    }

    if (-not $TeamId -and $TeamDisplayName)
    {
        $groupCount = 0
        $groups = Get-MgGroup -Filter "resourceProvisioningOptions/Any(x:x eq 'Team')" -ConsistencyLevel eventual -Count groupCount -All
        $teamMatches = @($groups | Where-Object { $_.DisplayName -eq $TeamDisplayName })
        if ($teamMatches.Count -eq 1) { $TeamId = $teamMatches[0].Id }
        elseif ($teamMatches.Count -gt 1) { throw "Multiple teams found with display name '$TeamDisplayName'. Set TEAMS_TEAM_ID or -TeamId." }
    }

    if ($RemoveTeamsChannel.IsPresent)
    {
        if (-not $TeamId) { throw "Missing TeamId (or TeamDisplayName resolving to one team) for channel removal." }
        if (-not $ChannelId -and $ChannelDisplayName)
        {
            $channel = @(Get-MgTeamChannel -TeamId $TeamId | Where-Object { $_.DisplayName -eq $ChannelDisplayName }) | Select-Object -First 1
            if ($channel) { $ChannelId = $channel.Id }
        }
        if (-not $ChannelId)
        {
            throw "ChannelId not found. Provide -ChannelId or -ChannelDisplayName (or set TEAMS_CHANNEL_ID / TEAMS_CHANNEL_NAME in .env)."
        }
        if ($ChannelId -and (Confirm-Step -Message "Remove Teams channel '$ChannelId' from team '$TeamId'?" -Force:$Force))
        {
            Remove-MgTeamChannel -TeamId $TeamId -ChannelId $ChannelId
            Write-Host "Removed Teams channel '$ChannelId'."
        }
    }

    if ($RemoveTeam.IsPresent)
    {
        if (-not $TeamId) { throw "Missing TeamId (or TeamDisplayName resolving to one team) for team removal." }
        if (Confirm-Step -Message "Remove entire Team '$TeamId'?" -Force:$Force)
        {
            Remove-MgGroup -GroupId $TeamId
            Write-Host "Removed Team '$TeamId'."
        }
    }
}

if ($RemoveFlowSolution.IsPresent)
{
    if (-not (Get-Command pac -ErrorAction SilentlyContinue))
    {
        throw "PAC CLI not found. Install with: winget install Microsoft.PowerPlatformCLI"
    }

    if (Confirm-Step -Message "Remove Flow Solution '$SolutionName'?" -Force:$Force)
    {
        pac solution delete --name "$SolutionName"
        if ($LASTEXITCODE -ne 0) { throw "pac solution delete failed with exit code $LASTEXITCODE." }
        Write-Host "Removed Flow Solution '$SolutionName'."
    }
}
