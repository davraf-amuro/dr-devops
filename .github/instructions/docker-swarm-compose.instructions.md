---
applyTo: "docker-compose_swarm.yaml"
---

# Docker Swarm Compose — Regole e Convenzioni (AI Agent)

Regole per creare o correggere `docker-compose_swarm.yaml`.
Stack: worker service / Minimal API .NET 10, deploy su Docker Swarm via Portainer.
Il file **non contiene mai valori sensibili**: solo placeholder `${VAR}`; i valori
reali si iniettano da Portainer a deploy time. Segui `sensitive-data.instructions.md`.
Esempi genericizzati — sostituisci i placeholder con i valori reali del progetto.

Le procedure operative in Portainer (creazione stack, update, rollback) stanno in
`portainer-swarm-stack.instructions.md`. Qui si descrive **solo il file**.

---

## 1. Image reference

```yaml
image: registry.example.com/myorg/<progetto>-main:${IMAGE_TAG:-latest}
```

- Formato: `<registry>/<org>/<image-name>-<branch-slug>:<tag>`.
- Il **tag** va sempre parametrizzato con `${IMAGE_TAG:-latest}` — **mai `:latest` hardcoded**.
  Motivo: Swarm confronta il **tag**, non il digest. Con `:latest` fisso il redeploy
  spesso non rileva la nuova immagine e non ridistribuisce, non è tracciabile quale
  versione gira e il rollback non è pulito. In produzione si imposta `IMAGE_TAG=vX.Y.Z`
  (= git tag della release) in Portainer; il default `latest` serve solo per dev.
- Ogni segmento parametrizzato **deve avere un default** (`${VAR:-default}`), altrimenti
  Portainer dà `invalid reference format`.
- Il path deve corrispondere **esattamente** a quello prodotto dalla CI
  (`gitlab-ci-cd.instructions.md`), e il nome immagine essere **tutto minuscolo**.

---

## 2. Env var derivate da `appsettings.json`

ASP.NET Core mappa le variabili d'ambiente su chiavi di config usando `__` (doppio
underscore) al posto della gerarchia JSON.

```
JSON:  Section.SubSection.Key
Env:   SECTION__SUBSECTION__KEY
```

Array JSON → indice numerico come segmento:
`WriteTo[1].Args.path` → `SERILOG__WRITETO__1__ARGS__PATH`.

Le env nel container **sovrascrivono** `appsettings.json` — è così che si
differenziano gli ambienti (dev/staging/prod).

### Default

- Chiavi **non sensibili** → default = valore di `appsettings.json`:
  ```yaml
  - SERILOG__MINIMUMLEVEL__DEFAULT=${SERILOG__MINIMUMLEVEL__DEFAULT:-Information}
  ```
- Chiavi **sensibili** (credenziali, connection string, URL/IP interni) → **senza
  default**, così l'assenza è evidente al primo avvio:
  ```yaml
  - CONNECTIONSTRINGS__MIODB=${CONNECTIONSTRINGS__MIODB}
  - APIESTERNO__PASSWORD=${APIESTERNO__PASSWORD}
  ```
  Mai scrivere il valore reale nel file. Mai IP/URL interni hardcodati.

---

## 3. ⚠️ Trappola: env no-op (deve stare nel compose *e* in Portainer)

In Swarm il container riceve **solo** le variabili elencate nel blocco
`environment:` del compose. Una chiave impostata in Portainer ma **assente** dal
compose **non arriva mai** al container: è un no-op silenzioso.

Regola: ogni chiave di configurazione che deve essere sovrascrivibile va
dichiarata nel blocco `environment:` (come `${CHIAVE:-default}` o `${CHIAVE}`).
Se una chiave non serve, rimuoverla **sia** dal compose **sia** da Portainer —
non lasciarla solo in Portainer illudendosi che abbia effetto.
Esempio tipico dell'errore: `APIESTERNO__TIMEOUTSECONDS` impostata in Portainer
ma mai aggiunta al blocco `environment:` → il valore non raggiunge il container.

---

## 4. Sezione `deploy`

```yaml
deploy:
  replicas: 1
  update_config:
    parallelism: 1
    delay: 60s
    order: stop-first
```

### `replicas`
Worker che scrivono su DB o inviano dati a sistemi esterni: **sempre `1`**. Due
repliche = doppia elaborazione (stesso record processato due volte). Repliche
multiple solo per servizi HTTP stateless.

### `update_config`
`order: stop-first` → ferma la replica attiva, poi avvia la nuova. Garantisce che
non girino mai due versioni insieme (breve downtime accettabile per worker senza
SLA). `start-first` è pericoloso per worker con stato — non usarlo qui.

### `placement` — ⚠️ verificare prima di aggiungere constraint
Un placement constraint (es. `node.role == worker`) può bloccare il servizio se i
nodi selezionati **non raggiungono il registry**: la task va `rejected`/`new`.
Lezione appresa: nodi worker che non raggiungevano il registry privato →
constraint **rimosso**, servizio libero su qualsiasi nodo.
Non aggiungere un constraint senza aver verificato il `docker pull` dai nodi target.

---

## 5. Sezione `logging` (GELF) — facoltativa

Omessa → driver default `json-file`, log visibili in Portainer. Includerla solo
per inviare i log a un collector esterno (Graylog/GELF):

```yaml
logging:
  driver: "gelf"
  options:
    gelf-address: "${GELF_ADDRESS}"   # IP parametrizzato, MAI hostname, MAI hardcoded
    tag: "<nome-servizio>"
    mode: "non-blocking"
    max-buffer-size: "4m"
```

Regole e lezioni apprese:
- **`gelf-address` via IP parametrizzato** `${GELF_ADDRESS}`, non un hostname. Un
  hostname non risolvibile dai nodi (DNS) causa **task rejected in init**, prima
  che il processo .NET parta. L'IP interno è un **dato sensibile**: non hardcodarlo
  nel repo → impostarlo in Portainer (`GELF_ADDRESS=udp://<ip-collector>:12201`).
- `mode: non-blocking` + `max-buffer-size: 4m` → l'app non si blocca se il
  collector è lento/irraggiungibile.
- **Rischio deploy:** se l'host GELF è irraggiungibile la task va `rejected`.
  Rollback = rimuovere la sezione `logging`. La pipeline verde **non** verifica la
  raggiungibilità del collector.
- **Conseguenza:** con driver GELF i log **non** sono più visibili in Portainer né
  via MCP (`get_service_logs` vuoto) — solo sul collector.

---

## 6. Chiavi Data Protection (servizi con autenticazione)

Vale per ogni servizio .NET con autenticazione a cookie o bearer. Le sessioni sono cifrate con le chiavi Data Protection: se restano dentro il container, **ricrearlo invalida tutte le sessioni** e con `replicas > 1` ogni replica ha il proprio portachiavi, quindi il login su una replica non vale sull'altra (401 a intermittenza).

Due modi per persistere il portachiavi, da scegliere nello stack:

| Modo | Cosa serve nel compose | Quando |
|------|------------------------|--------|
| Database | Nessun volume: le chiavi stanno in una tabella del DB già usato dal servizio | Default, se il servizio ha già un database |
| Volume | Un volume dedicato montato sul path delle chiavi | Se il DB non è disponibile all'avvio |

```yaml
services:
  api:
    volumes:
      - dataprotection-keys:/keys      # solo nel modo "volume"

volumes:
  dataprotection-keys:
```

**Il lato codice non si configura da qui.** Controlla `.ai/dr-guidelines-packages.json`: se elenca `dr-minimalapi`, la fonte unica è `minimal-api-architecture.instructions.md`, sezione "Autenticazione" — seguila, non duplicarla, e dichiara nell'output che l'hai usata.

Se non lo elenca, questo file non contiene la configurazione: dichiaralo nell'output e fermati a due requisiti, che valgono qualunque sia lo stack dietro il servizio.

- **Le repliche devono condividere il portachiavi.** Ogni replica che ne genera uno proprio invalida quello che hanno emesso le altre.
- **La fiducia va limitata al proxy noto.** Un servizio dietro proxy deve accettare gli header inoltrati solo da quel proxy, mai da chiunque.

Come si ottengano, nel linguaggio del servizio, è fuori dal perimetro di questo pacchetto: chiedi, o installa quello che porta la regola. Se il core `dr-guidelines` è installato, la convenzione che regola questi rimandi è in `cross-package-references.instructions.md`.

> ⚠️ `replicas > 1` senza portachiavi condiviso rompe l'autenticazione in modo intermittente, non con un errore. Verificare **prima** di alzare le repliche.

---

## 7. Adattare per un nuovo progetto

1. Cambiare la chiave del servizio sotto `services:` e il path immagine.
2. Una riga `environment:` per ogni config key (rispettando §2 e §3).
3. Lasciare `replicas: 1` e `order: stop-first` per i worker.
4. Aggiungere `placement`/`logging` solo dopo aver verificato registry e collector.
5. Verificare che `docker-compose_swarm.yaml` sia nella **root** (CI e Portainer lo cercano lì).

---

## ✅ Checklist post-modifica

- [ ] `image` usa `${IMAGE_TAG:-latest}`, path minuscolo coerente con la CI
- [ ] Nessun valore sensibile / IP / URL interno hardcodato
- [ ] Ogni chiave sovrascrivibile è nel blocco `environment:` (no env no-op)
- [ ] `replicas: 1` e `order: stop-first` per worker stateful
- [ ] `placement` presente solo se i nodi target raggiungono il registry
- [ ] `logging` GELF (se presente): `gelf-address=${GELF_ADDRESS}`, non-blocking, buffer 4m
- [ ] Servizio con autenticazione: portachiavi Data Protection persistito fuori dal container (DB o volume) — obbligatorio prima di alzare `replicas`

*Istruzione v2.2 — Docker Swarm Compose — 2026-09-24 — claude-opus-5 — rimando a dr-minimalapi reso condizionale al manifest, ripiego limitato ai requisiti (dr-guidelines#5)*
