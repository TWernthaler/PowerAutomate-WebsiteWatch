# Architektur

## Zielarchitektur

- SharePoint Liste **WebMonitoring** als Konfigurationsquelle
- Power Automate Cloud Flow für wiederkehrende Prüfungen
- Teams Benachrichtigungen bei erkannten Änderungen

```text
M365
│
├── SharePoint Liste "WebMonitoring"
│
└── Power Automate Cloud Flow
    │
    ├── Lädt alle aktiven Einträge
    ├── Ruft Webseiten ab
    ├── Extrahiert git_commit_id
    ├── Vergleicht LastValue
    ├── Teams Notification
    └── Aktualisiert LastValue
```

## Flow-Definition

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
