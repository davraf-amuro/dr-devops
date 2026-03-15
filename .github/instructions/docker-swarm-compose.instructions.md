---
applyTo: "docker-compose_swarm.yaml"
---

# Docker Swarm Compose — Regole e Convenzioni

Istruzioni per creare o correggere un file `docker-compose_swarm.yaml` per questo progetto.
Stack: .NET 10 Minimal API, deploy su Docker Swarm tramite Portainer.

---

## 1. Image Reference

- Il tag immagine **deve sempre avere un default** per evitare `invalid reference format` in Portainer:
  ```yaml
  image: registry.unidata.it/voisoft/foundrybridge-${ENVIRONMENT:-main}:latest
  ```
- Il path del registry deve corrispondere esattamente a quello prodotto dalla pipeline CI (`.gitlab-ci.yml`).
- Il nome immagine deve essere **tutto minuscolo** — Docker non accetta maiuscole nel reference.
- Formato: `<registry>/<org>/<image-name>-<branch-slug>:<tag>`

---

## 2. Derivare le variabili d'ambiente da `appsettings.json`

Le variabili d'ambiente nel compose **si ricavano direttamente dalla struttura di `appsettings.json`**.

### Regola di mapping

ASP.NET Core converte automaticamente le variabili d'ambiente in chiavi di configurazione usando il separatore `__` (double underscore) al posto di `:` o della gerarchia JSON.

**Schema:**
```
JSON path:   Section.SubSection.Key
Env var:     SECTION__SUBSECTION__KEY
```

### Esempio da `appsettings.json` di questo progetto

```json
{
  "Serilog": {
    "MinimumLevel": {
      "Default": "Verbose",
      "Override": {
        "Microsoft": "Warning",
        "System": "Error"
      }
    },
    "WriteTo": [
      { "Name": "Console" },
      {
        "Name": "File",
        "Args": {
          "path": "logs/FoundryBridge-.log",
          "formatter": "Serilog.Formatting.Compact.CompactJsonFormatter, Serilog.Formatting.Compact",
          "rollingInterval": "Day",
          "retainedFileCountLimit": 90
        }
      }
    ],
    "Enrich": [ "FromLogContext" ]
  },
  "FoundryAgent": {
    "ProjectEndpoint": "https://...",
    "AgentName": "fake-agent-name"
  }
}
```

Diventa nel compose:

```yaml
environment:
  # Serilog.MinimumLevel.Default → SERILOG__MINIMUMLEVEL__DEFAULT
  - SERILOG__MINIMUMLEVEL__DEFAULT=${SERILOG__MINIMUMLEVEL__DEFAULT:-Information}
  # Serilog.MinimumLevel.Override.Microsoft → SERILOG__MINIMUMLEVEL__OVERRIDE__MICROSOFT
  - SERILOG__MINIMUMLEVEL__OVERRIDE__MICROSOFT=${SERILOG__MINIMUMLEVEL__OVERRIDE__MICROSOFT:-Warning}
  - SERILOG__MINIMUMLEVEL__OVERRIDE__SYSTEM=${SERILOG__MINIMUMLEVEL__OVERRIDE__SYSTEM:-Error}
  # Array WriteTo: indice 0 = Console, indice 1 = File
  - SERILOG__WRITETO__0__NAME=${SERILOG__WRITETO__0__NAME:-Console}
  - SERILOG__WRITETO__1__NAME=${SERILOG__WRITETO__1__NAME:-File}
  - SERILOG__WRITETO__1__ARGS__PATH=${SERILOG__WRITETO__1__ARGS__PATH:-logs/FoundryBridge-.log}
  - SERILOG__WRITETO__1__ARGS__FORMATTER=${SERILOG__WRITETO__1__ARGS__FORMATTER}
  - SERILOG__WRITETO__1__ARGS__ROLLINGINTERVAL=${SERILOG__WRITETO__1__ARGS__ROLLINGINTERVAL:-Day}
  - SERILOG__WRITETO__1__ARGS__RETAINEDFILECOUNTLIMIT=${SERILOG__WRITETO__1__ARGS__RETAINEDFILECOUNTLIMIT:-90}
  # Array Enrich: indice 0
  - SERILOG__ENRICH__0=${SERILOG__ENRICH__0:-FromLogContext}
  # FoundryAgent.ProjectEndpoint → FOUNDRYAGENT__PROJECTENDPOINT
  - FOUNDRYAGENT__PROJECTENDPOINT=${FOUNDRYAGENT__PROJECTENDPOINT}
  - FOUNDRYAGENT__AGENTNAME=${FOUNDRYAGENT__AGENTNAME}
```

### Regole per gli array JSON

- Gli array in `appsettings.json` si mappano con l'**indice numerico** come segmento del path:
  - `WriteTo[0]` → `SERILOG__WRITETO__0__NAME`
  - `WriteTo[1].Args.path` → `SERILOG__WRITETO__1__ARGS__PATH`
  - `Enrich[0]` → `SERILOG__ENRICH__0`

### Regole per i default

- Le chiavi con valori **non sensibili** ricevono il default del corrispettivo in `appsettings.json`:
  ```yaml
  - SERILOG__MINIMUMLEVEL__DEFAULT=${SERILOG__MINIMUMLEVEL__DEFAULT:-Information}
  ```
- Le chiavi **sensibili** (credenziali, endpoint segreti) non devono avere default e vanno commentate:
  ```yaml
  # Secrets — inserire via Portainer UI, NON qui
  # - FOUNDRYAGENT__TENANTID=${FOUNDRYAGENT__TENANTID}
  # - FOUNDRYAGENT__CLIENTID=${FOUNDRYAGENT__CLIENTID}
  # - FOUNDRYAGENT__CLIENTSECRET=${FOUNDRYAGENT__CLIENTSECRET}
  ```

---

## 3. Variabili d'ambiente — Convenzioni generali

- Naming: `SECTION__SUBSECTION__KEY` — double underscore, tutto maiuscolo.
- Variabili critiche sempre con `${VAR:-default}`.
- Le variabili d'ambiente nel container **sovrascrivono** i valori di `appsettings.json` — usarle per differenziare ambienti (dev, staging, prod).
