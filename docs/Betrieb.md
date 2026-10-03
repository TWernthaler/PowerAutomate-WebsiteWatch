# Betrieb

## Voraussetzungen

```powershell
Install-Module PnP.PowerShell -Scope CurrentUser
```

- Einmalige Entra App Registrierung für PnP (ClientId)
- Berechtigter Zugriff auf die Ziel-SharePoint-Site

## SharePoint-Liste automatisiert bereitstellen

```powershell
pwsh ./scripts/Create-WebMonitoringList.ps1 -SiteUrl "https://tenant.sharepoint.com/sites/Automation" -ClientId "<app-client-id>"
```

Das Skript erstellt:

- Liste `WebMonitoring` (falls nicht vorhanden)
- Alle erforderlichen Felder
- Einen Standarddatensatz für "Windows 11 Release History"

## Neue Überwachungsziele hinzufügen

```powershell
pwsh ./scripts/Add-MonitoringTarget.ps1 `
  -SiteUrl "https://tenant.sharepoint.com/sites/Automation" `
  -ClientId "<app-client-id>" `
  -Title "VMware Security Advisory" `
  -Url "https://..." `
  -MatchStart "Updated:" `
  -MatchEnd "<"
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
