# Architektur

## Zielarchitektur

- SharePoint Liste **WebMonitoring** als Konfigurationsquelle
- Power Automate Cloud Flow für reproduzierbaren M365-Deployment-Pfad
- PowerShell Monitoring Runner für robuste Laufzeitlogik
- Teams Benachrichtigungen bei erkannten Änderungen

```text
M365
│
├── SharePoint Liste "WebMonitoring"
│
├── Power Automate Cloud Flow (Solution-basiert)
│   └── Standard-Flow für organisationsweiten M365-Betrieb
│
└── PowerShell Runner (Invoke-WebMonitoringCheck.ps1)
    │
    ├── Lädt aktive Einträge
    ├── HTTP mit Retry/Timeout/User-Agent/Header/Auth-Metadaten
    ├── Extraktion über MatchStart/MatchEnd
    ├── Cooldown-gesteuerte Teams-Benachrichtigung
    └── Status-/Fehler-Update pro Ziel
```

## Laufzeitmodi

1. **Flow-zentriert**  
   Cloud-Flow übernimmt den zyklischen Betrieb.

2. **Script-zentriert (robust)**  
   `Invoke-WebMonitoringCheck.ps1` übernimmt den zyklischen Betrieb mit erweiterten Resilienzmechanismen.

Empfehlung für Enterprise-Betrieb: einen primären Laufzeitmodus festlegen, um Doppelverarbeitung zu vermeiden.

## Konfigurationsmodell

- Zentrale Zielkonfiguration in SharePoint (`WebMonitoring`)
- Lokale Umgebungsparameter in `.env` (nicht versioniert)
- Reproduzierbares Flow-Artefakt: `powerplatform/WebsiteMonitoring.zip`

## Resilienz- und Betriebsfelder pro Ziel

- `LastStatus`, `LastError`, `ConsecutiveFailures`, `LastCheck`
- `LastNotifiedAt`, `NotifyCooldownMinutes`
- `RequestTimeoutSeconds`, `RetryCount`, `RequestUserAgent`, `RequestHeadersJson`
- `AuthType`, `AuthSecretRef`
- `TeamsTeamId`, `TeamsChannelId`

## Flow-Referenzdefinition (Solution-Inhalt)

1. **Trigger**: Recurrence (alle 6 Stunden)
2. **Get items**: Liste `WebMonitoring`, Filter `Active eq 1`
3. **Apply to each** über alle aktiven Items
4. **HTTP GET** mit URL `@{items('Apply_to_each')['Url']}`
5. **Compose** mit Ausdruck:

```text
first(
 split(
   last(
      split(
         body('HTTP'),
         items('Apply_to_each')?['MatchStart']
      )
   ),
   items('Apply_to_each')?['MatchEnd']
 )
)
```

6. **Condition**: `outputs('Compose')` ist ungleich `items('Apply_to_each')?['LastValue']`
7. **Teams**: Nachricht in Kanal posten
8. **Update item**: `LastValue = Compose`, `LastCheck = utcNow()`

## Lifecycle / Deinstallation

Die Entfernung aller erzeugten Ressourcen erfolgt zentral über:

- `Uninstall-WebMonitoringResources.ps1`
  - SharePoint-Liste
  - Teams-Kanal oder gesamtes Team
  - Power-Platform-Solution
