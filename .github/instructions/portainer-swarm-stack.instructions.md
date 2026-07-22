# Portainer Swarm Stack — Creazione e Manutenzione (AI Agent)

Procedure operative per creare, aggiornare e mantenere uno stack Docker Swarm
tramite Portainer. Complementare a `docker-swarm-compose.instructions.md` (il file
compose) e `gitlab-ci-cd.instructions.md` (la pipeline che produce l'immagine).
Esempi genericizzati — sostituisci i placeholder con i valori reali del progetto.

**Portainer aziendale:** un'unica istanza `https://portainer.example.com` (CE LTS).
**Endpoint (environment):** identificato da un id numerico (es. `<swarm-prod-endpoint>`).

Le azioni in Portainer sono **manuali** (UI) o via MCP con i limiti in §6. Nessuna
va eseguita senza richiesta esplicita dell'utente su un ambiente di produzione.

---

## 1. Concetti

- **Service**: astrazione sopra i container — Swarm sceglie il nodo, riavvia in
  caso di crash, aggiorna a rotazione.
- **Stack**: insieme di servizi da un compose, gestito come unità atomica.
- **Endpoint**: l'ambiente Swarm su cui gira lo stack.

---

## 2. Metodo di deploy dello stack — scelta strutturale

| Metodo | Sincronizzato col repo? | Quando |
|--------|-------------------------|--------|
| **Repository** | Sì — Portainer legge il compose dal Git ad ogni deploy | Standard con CI: preferibile |
| **Web editor** | **No** — il compose vive dentro Portainer | Test rapidi, o vincoli d'ambiente |
| Upload | No | Raro |

⚠️ **Regola di consapevolezza:** documentare **quale metodo** usa lo stack, perché
cambia radicalmente la manutenzione.

- Con **Repository**: modifiche al compose nel repo → si applicano al prossimo
  deploy. Richiede un deploy token GitLab (scope `read_repository`, senza scadenza).
- Con **Web editor**: il compose del repo **non si propaga** allo stack. Ogni
  modifica al compose va **incollata a mano** nell'editor prima dell'Update. Il repo
  resta la fonte di verità versionata; il Web editor ne è una copia da tenere
  allineata manualmente.

---

## 3. Variabili d'ambiente in Portainer

Sezione **Environment variables** → **Advanced mode**, una riga `CHIAVE=valore`.
I valori sensibili (password, connection string, IP interni, `GELF_ADDRESS`) si
inseriscono **qui** con i valori reali — **mai** nel repo.

⚠️ Una chiave impostata qui ma **assente** dal blocco `environment:` del compose
è un **no-op** (Swarm non la passa al container). Vedi
`docker-swarm-compose.instructions.md` §3.

---

## 4. Prima installazione (Web editor)

Prerequisiti: immagine `:vX.Y.Z` presente sul registry (pipeline verde), compose
nella root del repo, accesso a Portainer.

1. Portainer → seleziona l'**endpoint** Swarm target.
2. **Stacks** → **+ Add stack**. Name: minuscolo con trattini (es. `mio-servizio`).
3. Build method: **Web editor** → incolla il contenuto di `docker-compose_swarm.yaml`.
4. **Environment variables** → **Advanced mode** → incolla tutte le chiavi con i
   valori reali (incl. `IMAGE_TAG=vX.Y.Z` e, se GELF attivo, `GELF_ADDRESS`).
5. **Access control** → **Restricted** → team corretto (non "Administrators only").
6. **Deploy the stack**.

**Verifica:** tab Services → `1/1 Running`; tab Logs → avvio senza errori di
connettività (DB, API esterne). Con GELF attivo i log **non** appaiono qui (§7).

---

## 5. Aggiornamento a nuova versione

Prerequisito: `git tag vX.Y.Z && git push origin vX.Y.Z` → pipeline verde →
immagine `:vX.Y.Z` sul registry.

1. Portainer → **Stacks** → `<stack>`.
2. Se il compose è cambiato (Web editor): incolla la nuova versione del file.
3. **Environment variables** → imposta `IMAGE_TAG=vX.Y.Z`.
4. **Update the stack**.

Swarm esegue `stop-first`: ferma la replica attiva → pull `:vX.Y.Z` → avvia.
**Verifica:** task torna `Running` sulla nuova versione.

### Modifica solo di configurazione (senza nuova immagine)
Cambia il valore della env → **Update the stack**. L'immagine non cambia.

---

## 6. Monitoraggio via MCP (Claude Code) — e suoi limiti

Con `mcp-portainer` configurato (token in `.mcp.json`, in `.gitignore`) si possono
leggere log e stato senza aprire il browser: "mostra i log di `<stack>`", "stato
dei servizi", "riavvia il servizio `<servizio>`".

⚠️ **Limiti noti (lezione appresa):**
- Gli stack **Web editor** possono risultare **invisibili** al token MCP
  (`list_stacks` vuoto) → **non** gestibili via `update_stack` MCP. Le modifiche al
  compose vanno fatte a mano nell'editor. Il monitoraggio (log/servizi) funziona.
- Con driver **GELF** attivo, `get_service_logs` restituisce vuoto: i log sono solo
  sul collector.

---

## 7. Rollback

**Automatico:** se il container crasha subito dopo l'avvio, Swarm mantiene la task
precedente attiva — nessuna azione manuale.

**Manuale a versione nota:** imposta `IMAGE_TAG=<versione-stabile-precedente>` →
**Update the stack**. Nessun commit, nessuna build: solo un cambio di variabile.
Prerequisito: **non cancellare i tag vecchi dal registry** finché la nuova release
non è confermata stabile.

**GELF che manda in `rejected`:** rimuovi la sezione `logging` dal compose (Web
editor) → Update → il servizio riparte con log su stdout.

---

## 8. Diagnosi task bloccata (`new` / `has not been scheduled` / `rejected`)

Ordine di verifica:
1. **Placement constraint**: presente e nessun nodo lo soddisfa? Rimuovilo (§ compose).
2. **Pull immagine**: i nodi raggiungono il registry? (`docker pull ...` da un nodo,
   se hai accesso CLI). Task ferma in `preparing` → pull lento/bloccato.
3. **GELF**: host irraggiungibile → `rejected` in init. Rimuovi `logging`.
4. **Risorse nodo**: nessun nodo con risorse/label adatte.

⚠️ Limite reale: senza accesso CLI ai manager (solo UI Portainer) la causa esatta
può non essere catturabile. Rimedio empirico che ha sbloccato un servizio fermo in
`new`: **eliminare e ricreare lo stack**. Usarlo come ultima risorsa e annotarlo.

### Errori comuni
| Sintomo | Causa probabile | Azione |
|---------|-----------------|--------|
| `0/1` task `rejected` | GELF o registry irraggiungibile dal nodo | §7 / §8 |
| `non-zero exit (1)` | crash all'avvio | leggi i log: env errata o migration mancante |
| `Login failed for user` | credenziali SQL errate | correggi la connection string nelle env |
| `Connection refused` | servizio esterno non raggiungibile | verifica URL e connettività dal cluster |
| task in `preparing` | pull immagine lento/bloccato | verifica nodo → registry |

---

## ✅ Checklist deploy

- [ ] Immagine `:vX.Y.Z` sul registry (pipeline verde)
- [ ] Metodo dello stack documentato (Web editor vs Repository)
- [ ] Compose nel Web editor allineato al repo (se Web editor)
- [ ] Env in Advanced mode con valori reali; `IMAGE_TAG` = git tag
- [ ] Nessun dato sensibile nel repo (solo in Portainer)
- [ ] Access control **Restricted** → team corretto
- [ ] Servizio `1/1 Running`, log di avvio verificati
- [ ] Rollback plan noto (tag precedente ancora sul registry)

*Istruzione v1.0 — Portainer Swarm Stack — 2026-07-21 — claude-opus-4-8 — esempi genericizzati (nessun dato interno)*
