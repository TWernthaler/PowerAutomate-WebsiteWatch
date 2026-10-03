<#
.SYNOPSIS
Führt robuste Monitoring-Prüfungen für alle aktiven WebMonitoring-Einträge aus.

.DESCRIPTION
Liest aktive Ziele aus SharePoint, ruft Webseiten mit Retry/Timeout ab, extrahiert Werte
zwischen MatchStart/MatchEnd, aktualisiert Statusfelder und versendet optional Teams-Nachrichten
unter Berücksichtigung eines Cooldowns.
#>
param(
    [string]$SiteUrl,
    [string]$ClientId,
    [string]$ListName = "WebMonitoring",
    [int]$DefaultTimeoutSeconds = 30,
    [int]$DefaultRetryCount = 2,
    [string]$DefaultUserAgent = "PowerAutomate-WebsiteWatch/1.0",
    [switch]$SkipTeamsNotification
)

. "$PSScriptRoot\DotEnv.ps1"

function Get-ItemTextValue {
    param($Item, [string]$Name)
    $value = $Item[$Name]
    if ($null -eq $value) { return $null }
    return [string]$value
}

function Get-ItemIntValue {
    param($Item, [string]$Name, [int]$Fallback)
    $value = $Item[$Name]
    if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) { return $Fallback }
    return [int]$value
}

function Resolve-AuthHeader {
    param(
        [string]$AuthType,
        [string]$AuthSecretRef
    )

    if (-not $AuthType -or $AuthType -eq "None" -or -not $AuthSecretRef) { return $null }
    $secretValue = [Environment]::GetEnvironmentVariable($AuthSecretRef)
    if (-not $secretValue) { throw "AuthSecretRef '$AuthSecretRef' is set but environment variable is missing." }

    if ($AuthType -eq "BearerEnvVar")
    {
        return ("Bearer " + $secretValue)
    }

    if ($AuthType -eq "BasicEnvVar")
    {
        return "Basic $secretValue"
    }

    throw "Unsupported AuthType '$AuthType'."
}

function Send-TeamsChannelMessage {
    param(
        [string]$TeamId,
        [string]$ChannelId,
        [string]$Message
    )

    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Teams))
    {
        throw "Module Microsoft.Graph.Teams not installed."
    }

    Import-Module Microsoft.Graph.Teams -ErrorAction Stop
    if (-not (Get-MgContext))
    {
        Connect-MgGraph -Scopes "ChannelMessage.Send"
    }

    $body = @{
        body = @{
            contentType = "text"
            content = $Message
        }
    } | ConvertTo-Json -Depth 4

    Invoke-MgGraphRequest -Method POST -Uri "/teams/$TeamId/channels/$ChannelId/messages" -Body $body -ContentType "application/json" | Out-Null
}

$envConfig = Get-DotEnvConfig
if (-not $SiteUrl) { $SiteUrl = $envConfig["SITE_URL"] }
if (-not $ClientId) { $ClientId = $envConfig["CLIENT_ID"] }
if (-not $PSBoundParameters.ContainsKey("ListName") -and $envConfig["LIST_NAME"]) { $ListName = $envConfig["LIST_NAME"] }
if (-not $PSBoundParameters.ContainsKey("DefaultTimeoutSeconds") -and $envConfig["REQUEST_TIMEOUT_SECONDS"]) { $DefaultTimeoutSeconds = [int]$envConfig["REQUEST_TIMEOUT_SECONDS"] }
if (-not $PSBoundParameters.ContainsKey("DefaultRetryCount") -and $envConfig["REQUEST_RETRY_COUNT"]) { $DefaultRetryCount = [int]$envConfig["REQUEST_RETRY_COUNT"] }
if (-not $PSBoundParameters.ContainsKey("DefaultUserAgent") -and $envConfig["REQUEST_USER_AGENT"]) { $DefaultUserAgent = $envConfig["REQUEST_USER_AGENT"] }

if (-not $SiteUrl) { throw "Missing SiteUrl. Provide -SiteUrl or set SITE_URL in .env." }
if (-not $ClientId) { throw "Missing ClientId. Provide -ClientId or set CLIENT_ID in .env." }

Connect-PnPOnline -Url $SiteUrl -Interactive -ClientId $ClientId

$items = Get-PnPListItem -List $ListName -Query "<View><Query><Where><Eq><FieldRef Name='Active'/><Value Type='Boolean'>1</Value></Eq></Where></Query></View>"
foreach ($item in $items)
{
    $itemId = $item["ID"]
    $title = Get-ItemTextValue -Item $item -Name "Title"
    $url = Get-ItemTextValue -Item $item -Name "Url"
    $matchStart = Get-ItemTextValue -Item $item -Name "MatchStart"
    $matchEnd = Get-ItemTextValue -Item $item -Name "MatchEnd"
    $lastValue = Get-ItemTextValue -Item $item -Name "LastValue"
    $teamId = Get-ItemTextValue -Item $item -Name "TeamsTeamId"
    $channelId = Get-ItemTextValue -Item $item -Name "TeamsChannelId"
    $cooldownMinutes = Get-ItemIntValue -Item $item -Name "NotifyCooldownMinutes" -Fallback 360
    if ($cooldownMinutes -lt 0) { $cooldownMinutes = 0 }
    $timeoutSeconds = Get-ItemIntValue -Item $item -Name "RequestTimeoutSeconds" -Fallback $DefaultTimeoutSeconds
    if ($timeoutSeconds -lt 1) { $timeoutSeconds = 1 }
    $userAgent = Get-ItemTextValue -Item $item -Name "RequestUserAgent"
    if (-not $userAgent) { $userAgent = $DefaultUserAgent }
    $retryCount = Get-ItemIntValue -Item $item -Name "RetryCount" -Fallback $DefaultRetryCount
    if ($retryCount -lt 0) { $retryCount = 0 }
    $headersJson = Get-ItemTextValue -Item $item -Name "RequestHeadersJson"
    $authType = Get-ItemTextValue -Item $item -Name "AuthType"
    $authSecretRef = Get-ItemTextValue -Item $item -Name "AuthSecretRef"
    $consecutiveFailures = Get-ItemIntValue -Item $item -Name "ConsecutiveFailures" -Fallback 0
    $headers = @{}

    try
    {
        if (-not [Uri]::IsWellFormedUriString($url, [System.UriKind]::Absolute))
        {
            throw "Invalid URL '$url'."
        }
        if ([string]::IsNullOrEmpty($matchStart) -or [string]::IsNullOrEmpty($matchEnd))
        {
            throw "MatchStart/MatchEnd missing for target '$title'."
        }

        if ($headersJson)
        {
            $parsedHeaders = ConvertFrom-Json -InputObject $headersJson
            foreach ($property in $parsedHeaders.PSObject.Properties)
            {
                $headers[$property.Name] = [string]$property.Value
            }
        }

        $authHeader = Resolve-AuthHeader -AuthType $authType -AuthSecretRef $authSecretRef
        if ($authHeader) { $headers["Authorization"] = $authHeader }

        $currentValue = $null
        $success = $false
        $lastException = $null
        for ($attempt = 0; $attempt -le $retryCount; $attempt++)
        {
            try
            {
                $response = Invoke-WebRequest -Uri $url -Method GET -TimeoutSec $timeoutSeconds -UserAgent $userAgent -Headers $headers -ErrorAction Stop
                $content = [string]$response.Content
                $startIndex = $content.IndexOf($matchStart)
                if ($startIndex -lt 0) { throw "MatchStart marker not found." }
                $startIndex += $matchStart.Length
                $endIndex = $content.IndexOf($matchEnd, $startIndex)
                if ($endIndex -lt 0) { throw "MatchEnd marker not found." }
                $currentValue = $content.Substring($startIndex, $endIndex - $startIndex)
                $success = $true
                break
            }
            catch
            {
                $lastException = $_
                if ($attempt -lt $retryCount) { Start-Sleep -Seconds 2 }
            }
        }

        if (-not $success)
        {
            if ($null -ne $lastException) { throw $lastException }
            throw "Request failed without detailed exception."
        }

        $nowUtc = (Get-Date).ToUniversalTime()
        $changed = $currentValue -ne $lastValue
        $updateValues = @{
            LastCheck = $nowUtc
            LastStatus = "OK"
            LastError = $null
            ConsecutiveFailures = 0
        }

        if ($changed)
        {
            $notifyAllowed = $true
            if ($item["LastNotifiedAt"])
            {
                $lastNotifiedAt = [datetime]$item["LastNotifiedAt"]
                if ((New-TimeSpan -Start $lastNotifiedAt -End $nowUtc).TotalMinutes -lt $cooldownMinutes)
                {
                    $notifyAllowed = $false
                }
            }

            if ($SkipTeamsNotification.IsPresent)
            {
                $updateValues["LastStatus"] = "ChangedSkipped"
                $updateValues["LastValue"] = $currentValue
            }
            elseif (-not $notifyAllowed)
            {
                $updateValues["LastStatus"] = "ChangedCooldown"
                $updateValues["LastValue"] = $currentValue
            }
            elseif (-not $teamId -or -not $channelId)
            {
                $updateValues["LastStatus"] = "ChangedNoChannel"
                $updateValues["LastValue"] = $currentValue
            }
            else
            {
                $safeCurrentValue = ($currentValue -replace "[\r\n\t]", " ")
                if ($safeCurrentValue.Length -gt 500) { $safeCurrentValue = $safeCurrentValue.Substring(0, 500) + "..." }
                # Message text kept in German for current team conventions.
                $message = "🔔 Webseitenänderung erkannt`n`nName: $title`nNeuer Wert: $safeCurrentValue`nURL: $url"
                try
                {
                    Send-TeamsChannelMessage -TeamId $teamId -ChannelId $channelId -Message $message
                    $updateValues["LastNotifiedAt"] = $nowUtc
                    $updateValues["LastStatus"] = "ChangedNotified"
                    $updateValues["LastValue"] = $currentValue
                }
                catch
                {
                    $updateValues["LastStatus"] = "ChangedNotifyError"
                    $updateValues["LastError"] = $_.Exception.Message
                }
            }
        }
        else
        {
            $updateValues["LastStatus"] = "NoChange"
        }

        Set-PnPListItem -List $ListName -Identity $itemId -Values $updateValues | Out-Null
    }
    catch
    {
        $errorText = $_.Exception.Message
        Set-PnPListItem -List $ListName -Identity $itemId -Values @{
            LastCheck = (Get-Date).ToUniversalTime()
            LastStatus = "Error"
            LastError = $errorText
            ConsecutiveFailures = ($consecutiveFailures + 1)
        } | Out-Null
    }
}
