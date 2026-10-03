# Betrieb

## Voraussetzungen

```powershell
Install-Module PnP.PowerShell -Scope CurrentUser
```

- Einmalige Entra App Registrierung für PnP (ClientId)
- Berechtigter Zugriff auf die Ziel-SharePoint-Site

## Optionale lokale `.env`-Konfiguration

1. Vorlage kopieren:

```powershell
Copy-Item .env.example .env
```

2. Werte in `.env` lokal pflegen (`SITE_URL`, `CLIENT_ID`, optional `LIST_NAME`, `TEAMS_TEAM_ID`, `TEAMS_CHANNEL_ID`, `TEAMS_TEAM_NAME`, `TEAMS_CHANNEL_NAME`, `FLOW_SOLUTION_PATH`).

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

Neue Ziele benötigen keine Flow-Anpassung, solange sie als zusätzliche Listeneinträge gepflegt werden.
