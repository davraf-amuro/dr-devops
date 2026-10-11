# dr-devops

Pacchetto di linee guida per rilascio e CI/CD: compose Docker Swarm, stack Portainer e pipeline GitLab, installabile su qualsiasi repository.

> **Perimetro.** Il pacchetto non copre il container su host singolo: `Dockerfile` e `docker-compose.yml` per `docker compose up` non hanno regole proprie. Su quei file l'agente lo dichiara e non applica per analogia le regole Swarm (`docker-scope.instructions.md`).

## 🧩 Cosa contiene

| File | Tipo | A cosa serve |
|------|------|--------------|
| `.github/instructions/docker-swarm-compose.instructions.md` | Istruzione | Regole per `docker-compose_swarm.yaml` (è il suo `applyTo`): tag immagine `${IMAGE_TAG:-latest}`, variabili d'ambiente derivate da `appsettings.json`, nessun valore sensibile nel file, ogni chiave sovrascrivibile dichiarata in `environment:`. Impone `replicas: 1` e `order: stop-first` per i worker, GELF facoltativo e portachiavi Data Protection persistito per i servizi con autenticazione. |
| `.github/instructions/gitlab-ci-cd.instructions.md` | Istruzione | Regole per `.gitlab-ci.yml` (è il suo `applyTo`) di un progetto .NET 10: su ogni push solo `lint` e `build`, immagine, pacchetto e release solo su tag `v*.*.*`. Impone `set -euo pipefail` e push bloccanti su registry interno ed esterno, mai mascherati con `echo`. |
| `.github/instructions/docker-scope.instructions.md` | Istruzione | Perimetro del pacchetto su `Dockerfile` e compose (è il suo `applyTo`): solo `docker-compose_swarm.yaml` è coperto. Su un `Dockerfile` o un compose per host singolo l'agente dichiara che il pacchetto non lo copre, non applica le regole Swarm per analogia e segue comunque le regole del core su dati sensibili e valori fissi. |
| `.github/instructions/portainer-swarm-stack.instructions.md` | Istruzione | Procedure Portainer per lo stack Swarm: metodo Repository o Web editor, variabili in Advanced mode, prima installazione, aggiornamento via `IMAGE_TAG`, rollback, diagnosi di task bloccate e limiti del monitoraggio via MCP `mcp-portainer`. Il file non ha frontmatter `applyTo`. |

## 🔗 Dipendenze e domini

- Dipende da: nessuna dipendenza dichiarata. Il core `dr-guidelines` arriva comunque per primo se manca dal manifest: è una dipendenza implicita di ogni pacchetto.
- Richiesto da: nessuno. Nessun pacchetto del catalogo dichiara `dr-devops` tra le sue dipendenze.
- Applicabilità nel catalogo: `appliesTo: any`. Si installa su qualsiasi repository, senza uno stack richiesto.
- Contenuto delle regole: descrivono servizi .NET 10 (worker o Minimal API) deployati su Docker Swarm tramite Portainer, con immagini prodotte da GitLab CI/CD.
- Dominio del catalogo: `devops` ("Deploy Docker Swarm/Portainer e CI/CD GitLab", kind `any`). È l'unico pacchetto del dominio.
- Tipologie di progetto che lo propongono: `minimal-api` e `worker-service`, come pacchetto opzionale (`optionalPackages`). Il dominio `devops` non ha tipologie proprie (`projectTypes` vuoto).
- `dr-minimalapi` **non** è una dipendenza dichiarata, ed è voluto: questo pacchetto è `appliesTo: any` e copre anche repository di sola infrastruttura, senza .NET. Quando `dr-minimalapi` manca, il rimando si ferma a dichiarare i due requisiti (portachiavi condiviso fra le repliche, fiducia limitata al proxy noto) senza entrare nel codice.

File di altri pacchetti citati dalle istruzioni:

| File citato | Chi lo cita | Pacchetto che lo porta |
|-------------|-------------|------------------------|
| `sensitive-data.instructions.md` | `docker-swarm-compose`, `docker-scope` | `dr-guidelines` (core) |
| `no-hardcoded-values.instructions.md` | `docker-scope` | `dr-guidelines` (core) |
| `cross-package-references.instructions.md` | `docker-swarm-compose` | `dr-guidelines` (core) |
| `minimal-api-architecture.instructions.md` (sezione "Autenticazione") | `docker-swarm-compose`, rimando condizionale | `dr-minimalapi` |

Pacchetti suggeriti (`suggests` del catalogo): `dr-minimalapi`. L'installer non li installa e non chiede nulla: a fine installazione stampa una riga `[sugg]` con il motivo per ognuno che manca dal manifest.

## 🚀 Come si installa

Di solito non serve farlo a mano. Per una soluzione nuova si segue la guida del core [Creare una soluzione da zero](https://github.com/davraf-amuro/dr-guidelines/blob/main/docs/guida-nuova-soluzione.md): `/dr-scaffold` installa i pacchetti giusti da solo. Il flusso completo non è ancora stato provato sul campo. Per il kind `any`, come `dr-devops`, `/dr-scaffold` delega a `/dr-scaffold-guidelines` sul repository esistente.

A mano. Il core `dr-guidelines` porta `CLAUDE.md`, configurazione e skill: se manca dal manifest, l'installer lo installa per primo, con entrambe le forme qui sotto. Prerequisiti: PowerShell 7, git, `gh auth status` autenticato (l'installer si scarica con `gh api`; i repo sono Public dal 2026-09-21). Esegui dalla **root del repository host**: l'installer usa la cartella corrente come destinazione e non avvisa se sbagli cartella.

L'installer clona `main` da GitHub in una cartella temporanea, copia i file nel progetto host e poi cancella la cartella temporanea.

Via core, un solo installer:

```powershell
Set-Location <root-del-progetto-host>
& ([scriptblock]::Create((gh api repos/davraf-amuro/dr-guidelines/contents/dr-guidelines-install.ps1 -H "Accept: application/vnd.github.raw" | Out-String))) -Package dr-devops
```

Oppure con l'installer del pacchetto:

```powershell
& ([scriptblock]::Create((gh api repos/davraf-amuro/dr-devops/contents/dr-devops-install.ps1 -H "Accept: application/vnd.github.raw" | Out-String)))
```

Nota: la forma breve `irm https://raw.githubusercontent.com/... | iex` è un'alternativa valida, perché i repo sono Public. Su un repo Private risponderebbe 404: lì si usa `gh api`.

## 📦 Cosa finisce nel progetto host

| Percorso nel progetto host | Contenuto |
|----------------------------|-----------|
| `.github/instructions/docker-swarm-compose.instructions.md` | Copia dell'istruzione sul compose Swarm |
| `.github/instructions/gitlab-ci-cd.instructions.md` | Copia dell'istruzione sulla pipeline GitLab |
| `.github/instructions/docker-scope.instructions.md` | Copia dell'istruzione sul perimetro Docker del pacchetto |
| `.github/instructions/portainer-swarm-stack.instructions.md` | Copia dell'istruzione sulle procedure Portainer |
| `.ai/dr-guidelines-packages.json` | Voce `dr-devops` in `installed`: `package`, `installedAt` (data) e `commit` (commit di `main` installato). Il file si crea se manca. |

Il pacchetto non modifica `CLAUDE.md` né i file di configurazione (`.editorconfig`, `.gitignore`, `.gitattributes`, `.claude/settings.json`, `.mcp.json`). Li scrive il core, solo se viene installato insieme perché mancava dal manifest.

Non vengono copiati `README.md`, `LICENSE`, `.github/ISSUE_TEMPLATE/` e l'installer `dr-devops-install.ps1`.

Senza `-Update` un file già presente nel progetto host viene saltato (`[SKIP]`).

## 🔄 Aggiornare

Tutti i pacchetti del progetto: `/dr-get-latest`.

Solo questo pacchetto: stesso comando dell'installer del pacchetto, con `-Update` in coda:

```powershell
& ([scriptblock]::Create((gh api repos/davraf-amuro/dr-devops/contents/dr-devops-install.ps1 -H "Accept: application/vnd.github.raw" | Out-String))) -Update
```

Nota: `-Update` sovrascrive le copie locali. Si installa sempre l'ultimo `main` pushato: una modifica a questo repo non pushata su `main` non arriva nei progetti host.

Un file rimosso da questo repo resta nel progetto host: l'installer copia, non cancella.

## 🐞 Segnalare un problema o una miglioria

Non correggere la copia nel progetto host: si perde al primo `-Update`.

Dal progetto host usa `/dr-file-feedback <descrizione>` (su Copilot il prompt `.github/prompts/dr-file-feedback.prompt.md` del core). La issue si apre in questo repo, dopo la tua conferma esplicita di titolo e corpo.

| Modello del repo | Quando usarlo |
|------------------|---------------|
| `.github/ISSUE_TEMPLATE/miglioria.md` | Richiesta evolutiva: regola nuova, precisazione, estensione del pacchetto |
| `.github/ISSUE_TEMPLATE/problema.md` | Malfunzionamento: regola sbagliata, ambigua o che porta l'agente fuori strada |

---

*Revisione v1.6 — 2026-10-11 21:00 — claude-opus-5-5*