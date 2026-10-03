# Betrieb

## Voraussetzungen

```powershell
Install-Module PnP.PowerShell -Scope CurrentUser
```

- Einmalige Entra App Registrierung für PnP (ClientId)
- Berechtigter Zugriff auf die Ziel-SharePoint-Site
- Für Teams-Automation: Microsoft Graph PowerShell Modul(e)
- Für Flow-Deployment: PAC CLI

## Betriebsentscheidung (wichtig)

Lege einen primären Betriebsmodus fest:

- **Flow-zentriert** (Power Automate)
- **Script-zentriert** (`Invoke-WebMonitoringCheck.ps1`)

Paralleler Dauerbetrieb beider Modi ist nicht empfohlen (Doppelverarbeitung).

## Optionale lokale `.env`-Konfiguration

1. Vorlage kopieren:

```powershell
Copy-Item .env.example .env
```

2. Werte in `.env` lokal pflegen (`SITE_URL`, `CLIENT_ID`, optional `LIST_NAME`, `TEAMS_TEAM_ID`, `TEAMS_CHANNEL_ID`, `TEAMS_TEAM_NAME`, `TEAMS_CHANNEL_NAME`, `FLOW_SOLUTION_PATH`, `FLOW_SOLUTION_NAME`, `REQUEST_TIMEOUT_SECONDS`, `REQUEST_RETRY_COUNT`, `REQUEST_USER_AGENT`, `NOTIFY_COOLDOWN_MINUTES`, `REQUEST_HEADERS_JSON`, `AUTH_TYPE`, `AUTH_SECRET_REF`).

> `.env` bleibt lokal auf dem Entwicklerhost und darf nicht ins Repository.

## SharePoint-Liste automatisiert bereitstellen

```powershell
pwsh ./scripts/Create-WebMonitoringList.ps1
```

Ohne `.env` können die Werte weiterhin explizit übergeben werden:

```powershell
pwsh ./scripts/Create-WebMonitoringList.ps1 -SiteUrl "https://tenant.sharepoint.com/sites/Automation" -ClientId "<app-client-id>" -ListName "WebMonitoring"
```

Das Skript erstellt:

- Liste `WebMonitoring` (falls nicht vorhanden)
- Alle erforderlichen Felder
- Einen Standarddatensatz für "Windows 11 Release History"

> Hinweis: Für Teams-Benachrichtigungen müssen pro Eintrag `TeamsTeamId` und `TeamsChannelId` gesetzt sein.

Optional kann der Standarddatensatz unterdrückt werden:

```powershell
pwsh ./scripts/Create-WebMonitoringList.ps1 -SkipDefaultItem
```

## Neue Überwachungsziele hinzufügen

```powershell
pwsh ./scripts/Add-MonitoringTarget.ps1 `
  -Title "VMware Security Advisory" `
  -Url "https://..." `
  -MatchStart "Updated:" `
  -MatchEnd "<"
```

Beispiel für die Windows-11-26H2-Historie:

```powershell
pwsh ./scripts/Add-MonitoringTarget.ps1 `
  -Title "Windows 11 Version 26H2 Update History" `
  -Url "https://support.microsoft.com/de-de/servicing/os/windows-11/2026/09/windows-11-version-26h2-update-history" `
  -MatchStart '<meta name="git_commit_id" content="' `
  -MatchEnd '"'
```

Bei Bedarf können `SiteUrl`, `ClientId`, `TeamsTeamId` und `TeamsChannelId` auch explizit gesetzt werden (ansonsten aus `.env`).

Optional kann ein Ziel initial inaktiv angelegt werden:

```powershell
pwsh ./scripts/Add-MonitoringTarget.ps1 ... -Inactive
```

Weitere optionale Parameter pro Ziel:

- `-RequestTimeoutSeconds`
- `-RetryCount`
- `-RequestUserAgent`
- `-NotifyCooldownMinutes`
- `-RequestHeadersJson` (JSON-Objekt als String)
- `-AuthType` (`None`, `BearerEnvVar`, `BasicEnvVar`)
- `-AuthSecretRef` (Name einer lokalen Umgebungsvariable mit Secret)

### Teams-Kanal für Benachrichtigungen festlegen

Der Zielkanal wird pro Listeneintrag über die Felder `TeamsTeamId` und `TeamsChannelId` gesteuert:

- automatisch über `.env` (`TEAMS_TEAM_ID`, `TEAMS_CHANNEL_ID`) beim Ausführen von `Add-MonitoringTarget.ps1`
- oder manuell direkt im SharePoint-Listeneintrag

### Teams-Kanal erstellen (falls noch nicht vorhanden)

1. In Microsoft Teams das gewünschte Team öffnen.
2. `...` neben dem Teamnamen → **Kanal hinzufügen**.
3. Kanalname vergeben (z. B. `website-monitoring`) und erstellen.
4. Kanal öffnen → `...` → **Link zum Kanal abrufen**.
5. Aus dem Link `groupId` als `TeamsTeamId` und `channelId` als `TeamsChannelId` übernehmen.

Alternativ per PowerShell (Microsoft Graph):

```powershell
Install-Module Microsoft.Graph.Teams -Scope CurrentUser
pwsh ./scripts/Create-TeamsChannel.ps1 -TeamDisplayName "IT Automation" -ChannelDisplayName "website-monitoring"
```

Das Skript erstellt den Kanal, falls er nicht existiert, oder gibt den vorhandenen zurück und schreibt:

- `TEAMS_TEAM_ID=...`
- `TEAMS_CHANNEL_ID=...`

Diese Werte in `.env` übernehmen (oder direkt als Parameter an `Add-MonitoringTarget.ps1` übergeben).

Optional kann `.env` direkt aktualisiert werden:

```powershell
pwsh ./scripts/Create-TeamsChannel.ps1 -TeamDisplayName "IT Automation" -ChannelDisplayName "website-monitoring" -WriteToEnv
```

## Reproduzierbares Flow-Deployment per PAC CLI

Installation:

```powershell
winget install Microsoft.PowerPlatformCLI
```

Login:

```powershell
pac auth create
```

Export:

```powershell
pac solution export --name WebsiteMonitoring --path .\powerplatform\WebsiteMonitoring.zip
```

Import:

```powershell
pac solution import --path .\powerplatform\WebsiteMonitoring.zip
```

Automatisiert per Skript (erstellt den Flow, wenn er noch nicht vorhanden ist):

```powershell
pwsh ./scripts/Deploy-WebsiteMonitoringFlow.ps1
```

Optional mit Pfad:

```powershell
pwsh ./scripts/Deploy-WebsiteMonitoringFlow.ps1 -SolutionZipPath ".\powerplatform\WebsiteMonitoring.zip"
```

## Robuster Monitoring-Lauf per Skript

Für robustes Monitoring beliebiger Webseiten inklusive Fehlerbehandlung:

```powershell
pwsh ./scripts/Invoke-WebMonitoringCheck.ps1
```

Das Skript bietet:

- Fehlerbehandlung pro Ziel (`LastStatus`, `LastError`, `ConsecutiveFailures`)
- Retry/Timeout/User-Agent pro Ziel oder global per `.env`
- Marker-Validierung (`MatchStart`/`MatchEnd`) mit sauberem Fehlerstatus
- Cooldown-basierte Benachrichtigung (`NotifyCooldownMinutes`, `LastNotifiedAt`)
- Optionale Header/Auth-Metadaten (`RequestHeadersJson`, `AuthType`, `AuthSecretRef`)

Optional ohne Teams-Nachrichten:

```powershell
pwsh ./scripts/Invoke-WebMonitoringCheck.ps1 -SkipTeamsNotification
```

Hinweis: `-SkipTeamsNotification` hat Vorrang vor Cooldown-Logik, unterdrückt die Nachricht und schreibt den neuen Wert trotzdem als verarbeitet (`LastValue` wird aktualisiert, `LastNotifiedAt` wird gesetzt).

## Reproduzierbares Artefakt sicherstellen

Die Datei `powerplatform/WebsiteMonitoring.zip` muss versioniert bereitliegen, damit ein reproduzierbarer Import jederzeit möglich bleibt.

## Release-/Abnahme-Checkliste

- Installationstools/Module verifiziert
- `.env` lokal gepflegt, keine Secrets committed
- SharePoint-Liste inkl. Felder erstellt
- Mindestens ein Ziel inkl. Team/Channel-ID angelegt
- Monitoring-Lauf erfolgreich mit Statusupdates (`LastStatus`, `LastError`)
- Teams-Testbenachrichtigung erfolgreich
- Flow-Solution importierbar
- Deinstallation im Testtenant erfolgreich getestet

## Saubere Deinstallation aller erzeugten Ressourcen

Das folgende Skript entfernt die erzeugten Ressourcen kontrolliert:

```powershell
pwsh ./scripts/Uninstall-WebMonitoringResources.ps1 `
  -RemoveSharePointList `
  -RemoveTeamsChannel `
  -RemoveFlowSolution
```

Optional auch das gesamte Team entfernen:

```powershell
pwsh ./scripts/Uninstall-WebMonitoringResources.ps1 -RemoveTeam
```

Für non-interactive Ausführung (ohne Rückfragen):

```powershell
pwsh ./scripts/Uninstall-WebMonitoringResources.ps1 -RemoveSharePointList -RemoveTeamsChannel -RemoveFlowSolution -Force
```
