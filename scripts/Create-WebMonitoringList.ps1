param(
    [string]$SiteUrl,

    [string]$ClientId,

    [string]$ListName = "WebMonitoring"
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

$list = Get-PnPList `
    -Identity $ListName `
    -ErrorAction SilentlyContinue

if (-not $list)
{
    New-PnPList `
        -Title $ListName `
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
            -List $ListName `
            -Identity $field.Name `
            -ErrorAction Stop
    }
    catch
    {
        Add-PnPField `
            -List $ListName `
            -DisplayName $field.Name `
            -InternalName $field.Name `
            -Type $field.Type
    }
}

$existingDefault = Get-PnPListItem `
    -List $ListName `
    -Query "<View><Query><Where><Eq><FieldRef Name='Title'/><Value Type='Text'>Windows 11 Release History</Value></Eq></Where></Query><RowLimit>1</RowLimit></View>"
if (-not $existingDefault)
{
    Add-PnPListItem `
        -List $ListName `
        -Values @{
            Title      = "Windows 11 Release History"
            Url        = "https://learn.microsoft.com/en-us/windows/release-health/windows11-release-information"
            MatchStart = '<meta name="git_commit_id" content="'
            MatchEnd   = '"'
            Active     = $true
        }
}
