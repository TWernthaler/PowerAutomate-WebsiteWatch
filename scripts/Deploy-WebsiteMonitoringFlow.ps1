param(
    [string]$SolutionZipPath
)

. "$PSScriptRoot\DotEnv.ps1"

$envConfig = Get-DotEnvConfig
if (-not $SolutionZipPath) { $SolutionZipPath = $envConfig["FLOW_SOLUTION_PATH"] }
if (-not $SolutionZipPath) { $SolutionZipPath = "./powerplatform/WebsiteMonitoring.zip" }

if (-not (Get-Command pac -ErrorAction SilentlyContinue))
{
    throw "PAC CLI not found. Install with: winget install Microsoft.PowerPlatformCLI"
}

if (-not (Test-Path -Path $SolutionZipPath))
{
    throw "Solution zip not found at '$SolutionZipPath'. Export or place WebsiteMonitoring.zip first."
}

Write-Host "Importing flow solution from '$SolutionZipPath'..."
Write-Host "If the flow does not exist yet, it will be created during import."

pac solution import --path $SolutionZipPath
