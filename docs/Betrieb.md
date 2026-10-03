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

2. Werte in `.env` lokal pflegen (`SITE_URL`, `CLIENT_ID`, optional `LIST_NAME`).

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

Bei Bedarf können `SiteUrl` und `ClientId` auch hier explizit gesetzt werden (ansonsten aus `.env`).

Optional kann ein Ziel initial inaktiv angelegt werden:

```powershell
pwsh ./scripts/Add-MonitoringTarget.ps1 ... -Inactive
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

Neue Ziele benötigen keine Flow-Anpassung, solange sie als zusätzliche Listeneinträge gepflegt werden.
