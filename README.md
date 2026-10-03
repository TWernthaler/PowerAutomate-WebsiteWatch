# PowerAutomate-WebsiteWatch

Monitoring beliebiger Webseiten auf Änderungen mit SharePoint + Power Automate.

## Empfohlene Repository-Struktur

```text
/docs
    Architektur.md
    Betrieb.md
/scripts
    DotEnv.ps1
    Create-WebMonitoringList.ps1
    Add-MonitoringTarget.ps1
    Create-TeamsChannel.ps1
    Invoke-WebMonitoringCheck.ps1
    Deploy-WebsiteMonitoringFlow.ps1
    Uninstall-WebMonitoringResources.ps1
/powerplatform
    WebsiteMonitoring.zip (nach Export per PAC CLI)
.env.example
```

## Deployment-Ansatz

- SharePoint-Liste wird vollständig per PowerShell bereitgestellt.
- Cloud-Flow wird als Power-Platform-Solution verwaltet.
- Austausch zwischen Kollegen erfolgt über PAC CLI Export/Import.
- Lokale Konfiguration läuft optional über `.env` (aus `.env.example` ableiten), `.env` wird nicht versioniert.

## Betriebsmodi

- **Flow-zentriert**: Betrieb hauptsächlich über den Cloud-Flow.
- **Script-zentriert**: Betrieb hauptsächlich über `Invoke-WebMonitoringCheck.ps1` mit erweiterten Resilienzfunktionen.

Für Enterprise-Betrieb einen primären Modus festlegen (kein paralleler Dauerbetrieb beider Modi).

## Go-Live Check (Kurz)

- Installation der benötigten Module/Tools abgeschlossen (PnP, Graph, PAC CLI)
- `Create-WebMonitoringList.ps1` erfolgreich ausgeführt
- Ziele mit `Add-MonitoringTarget.ps1` angelegt
- Teams-Kanal/IDs konfiguriert (inkl. Testbenachrichtigung)
- `powerplatform/WebsiteMonitoring.zip` versioniert und importierbar
- Monitoring-Run (`Invoke-WebMonitoringCheck.ps1`) erfolgreich
- Deinstallation (`Uninstall-WebMonitoringResources.ps1`) im Testtenant verifiziert

Siehe:

- `/docs/Architektur.md`
- `/docs/Betrieb.md`
