# dr-devops

Pacchetto di linee guida per rilascio e CI/CD: compose Docker Swarm, stack Portainer e pipeline GitLab, installabile su qualsiasi repository.

## 🧩 Cosa contiene

| File | Tipo | A cosa serve |
|------|------|--------------|
| `.github/instructions/docker-swarm-compose.instructions.md` | Istruzione | Regole per `docker-compose_swarm.yaml` (è il suo `applyTo`): tag immagine `${IMAGE_TAG:-latest}`, variabili d'ambiente derivate da `appsettings.json`, nessun valore sensibile nel file, ogni chiave sovrascrivibile dichiarata in `environment:`. Impone `replicas: 1` e `order: stop-first` per i worker, GELF facoltativo e portachiavi Data Protection persistito per i servizi con autenticazione. |
| `.github/instructions/gitlab-ci-cd.instructions.md` | Istruzione | Regole per `.gitlab-ci.yml` (è il suo `applyTo`) di un progetto .NET 10: su ogni push solo `lint` e `build`, immagine, pacchetto e release solo su tag `v*.*.*`. Impone `set -euo pipefail` e push bloccanti su registry interno ed esterno, mai mascherati con `echo`. |
| `.github/instructions/portainer-swarm-stack.instructions.md` | Istruzione | Procedure Portainer per lo stack Swarm: metodo Repository o Web editor, variabili in Advanced mode, prima installazione, aggiornamento via `IMAGE_TAG`, rollback, diagnosi di task bloccate e limiti del monitoraggio via MCP `mcp-portainer`. Il file non ha frontmatter `applyTo`. |

## 🔗 Dipendenze e domini

- Dipende da: nessuna dipendenza.
- Richiesto da: nessuno. Nessun pacchetto del catalogo dichiara `dr-devops` tra le sue dipendenze.
- Applicabilità nel catalogo: `appliesTo: any`. Si installa su qualsiasi repository, senza uno stack richiesto.
- Contenuto delle regole: descrivono servizi .NET 10 (worker o Minimal API) deployati su Docker Swarm tramite Portainer, con immagini prodotte da GitLab CI/CD.
- Dominio del catalogo: `devops` (Deploy, container e CI/CD, kind `any`). È l'unico pacchetto del dominio.
- Tipologie di progetto che lo suggeriscono: nessuna. Il dominio ha `projectTypes` vuoto e nessuna tipologia lo cita in `suggestedPackages` o `optionalPackages`.
- Rimandi ad altri pacchetti: `docker-swarm-compose.instructions.md` cita `sensitive-data.instructions.md` del core. Per il codice Data Protection rimanda a `minimal-api-architecture.instructions.md` (sezione "Autenticazione") di `dr-minimalapi`, che **non** è una dipendenza dichiarata, ed è voluto: questo pacchetto è `appliesTo: any` e copre anche repository di sola infrastruttura, senza .NET. Il rimando è condizionale al manifest e, quando il pacchetto manca, si ferma a dichiarare i due requisiti — portachiavi condiviso fra le repliche, fiducia limitata al proxy noto — senza entrare nel codice. Vedi `cross-package-references.instructions.md` del core.

## 🚀 Come si installa

Di solito non serve farlo a mano. Per una soluzione nuova si segue la guida del core [Creare una soluzione da zero](https://github.com/davraf-amuro/dr-guidelines/blob/main/docs/guida-nuova-soluzione.md): `/dr-scaffold` installa i pacchetti giusti da solo. Il flusso completo non è ancora stato provato sul campo. Per il kind `any`, come `dr-devops`, `/dr-scaffold` delega a `/dr-scaffold-guidelines` sul repository esistente.

A mano. Conviene installare prima il core `dr-guidelines`, che porta `CLAUDE.md`, configurazione e skill; l'installer però non lo impone. Prerequisiti: PowerShell 7, git, `gh auth status` autenticato (i repo sono Private). Esegui dalla **root del repository host**: l'installer usa la cartella corrente come destinazione e non avvisa se sbagli cartella.

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

Nota: la forma breve `irm https://raw.githubusercontent.com/... | iex` funziona solo a repo Public. Oggi risponde 404.

## 📦 Cosa finisce nel progetto host

| Percorso nel progetto host | Contenuto |
|----------------------------|-----------|
| `.github/instructions/docker-swarm-compose.instructions.md` | Copia dell'istruzione sul compose Swarm |
| `.github/instructions/gitlab-ci-cd.instructions.md` | Copia dell'istruzione sulla pipeline GitLab |
| `.github/instructions/portainer-swarm-stack.instructions.md` | Copia dell'istruzione sulle procedure Portainer |
| `.ai/dr-guidelines-packages.json` | Voce `dr-devops` in `installed`: `package`, `installedAt` (data) e `commit` (commit di `main` installato). Il file si crea se manca. |

Nessuna modifica a `CLAUDE.md` né ai file di configurazione del core (`.editorconfig`, `.gitignore`, `.gitattributes`, `.claude/settings.json`, `.mcp.json`).

`LICENSE`, `.github/ISSUE_TEMPLATE/` e `dr-devops-install.ps1` restano in questo repo: non vengono copiati.

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

Dal progetto host usa `/dr-segnala-miglioria <descrizione>` (su Copilot il prompt `.github/prompts/dr-segnala-miglioria.prompt.md` del core). Apre la issue in questo repo.

| Modello | Quando |
|---------|--------|
| `.github/ISSUE_TEMPLATE/miglioria.md` | Richiesta evolutiva |
| `.github/ISSUE_TEMPLATE/problema.md` | Malfunzionamento |

---

*Documento aggiornato: Settembre 2026 — Revisione v1.1 — 2026-09-24 — claude-opus-5*
