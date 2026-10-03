# PowerAutomate-WebsiteWatch

Monitoring beliebiger Webseiten auf Änderungen mit SharePoint + Power Automate.

## Empfohlene Repository-Struktur

```text
/docs
    Architektur.md
    Betrieb.md
/scripts
    Create-WebMonitoringList.ps1
    Add-MonitoringTarget.ps1
/powerplatform
    WebsiteMonitoring.zip (nach Export per PAC CLI)
```

## Deployment-Ansatz

- SharePoint-Liste wird vollständig per PowerShell bereitgestellt.
- Cloud-Flow wird als Power-Platform-Solution verwaltet.
- Austausch zwischen Kollegen erfolgt über PAC CLI Export/Import.

Siehe:

- `/docs/Architektur.md`
- `/docs/Betrieb.md`
