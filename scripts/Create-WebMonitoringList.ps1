param(
    [Parameter(Mandatory)]
    [string]$SiteUrl,

    [Parameter(Mandatory)]
    [string]$ClientId
)

Connect-PnPOnline `
    -Url $SiteUrl `
    -Interactive `
    -ClientId $ClientId

$listName = "WebMonitoring"

$list = Get-PnPList `
    -Identity $listName `
    -ErrorAction SilentlyContinue

if (-not $list)
{
    New-PnPList `
        -Title $listName `
        -Template GenericList `
        -OnQuickLaunch
}

$fields = @(
    @{ Name = "Url"; Type = "Note" },
    @{ Name = "MatchStart"; Type = "Note" },
    @{ Name = "MatchEnd"; Type = "Note" },
    @{ Name = "LastValue"; Type = "Note" },
    @{ Name = "TeamsTeamId"; Type = "Text" },
    @{ Name = "TeamsChannelId"; Type = "Text" },
    @{ Name = "Active"; Type = "Boolean" },
    @{ Name = "LastCheck"; Type = "DateTime" }
)

foreach ($field in $fields)
{
    try
    {
        Get-PnPField `
            -List $listName `
            -Identity $field.Name `
            -ErrorAction Stop
    }
    catch
    {
        Add-PnPField `
            -List $listName `
            -DisplayName $field.Name `
            -InternalName $field.Name `
            -Type $field.Type
    }
}

$existingDefault = Get-PnPListItem -List $listName -PageSize 200 | Where-Object { $_["Title"] -eq "Windows 11 Release History" }
if (-not $existingDefault)
{
    Add-PnPListItem `
        -List $listName `
        -Values @{
            Title      = "Windows 11 Release History"
            Url        = "https://learn.microsoft.com/de-de/windows/release-health/windows11-release-information"
            MatchStart = '<meta name="git_commit_id" content="'
            MatchEnd   = '"'
            Active     = $true
        }
}
