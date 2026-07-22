---
applyTo: ".gitlab-ci.yml"
---

# GitLab CI/CD — Pipeline .NET Worker/API (AI Agent)

Regole per creare o modificare `.gitlab-ci.yml` per un progetto .NET 10 il cui
artefatto è un'immagine Docker deployata su Docker Swarm via Portainer.
Testo ottimizzato per token. Segui sempre; non assumere in silenzio.
Esempi genericizzati — sostituisci i placeholder con i valori reali del progetto.

---

## 1. Modello di pipeline

```
lint → build → docker → package → release
              (docker/package/release: SOLO su tag v*.*.*)
```

| Stage | Trigger | Produce |
|-------|---------|---------|
| `lint` | MR, push su `main`, tag `v*.*.*` | nulla (verifica formattazione) |
| `build` | MR, push su `main`, tag `v*.*.*` | nulla (verifica compilazione) |
| `docker` | **solo tag `v*.*.*`** | immagine sul registry |
| `package` | **solo tag `v*.*.*`** | zip win-x64 (facoltativo) |
| `release` | **solo tag `v*.*.*`** | GitLab Release |

**Principio non negoziabile:** un push su branch esegue **solo lint + build**.
Non deve produrre né immagini né artefatti. Solo un **tag `v*.*.*`** genera una
release. Motivo: le immagini in produzione devono corrispondere 1:1 a una
versione immutabile e tracciabile; un rebuild da branch renderebbe non
deterministico cosa gira in prod.

Pattern tag obbligatorio (SemVer): `/^v\d+\.\d+\.\d+$/`. Applicarlo in **tutte**
le `rules` dei job di rilascio — non usare `only: tags` generico (accetterebbe
tag non-SemVer).

---

## 2. Fail-fast obbligatorio (regola critica)

⛔ Ogni snippet shell multi-comando **deve** iniziare con:

```bash
set -euo pipefail
```

⛔ **Mai** mascherare il fallimento di un comando di rilascio con `|| echo "..."`.
Un `docker push` che fallisce **deve** far diventare il job rosso.

```yaml
# ❌ SBAGLIATO — verde bugiardo: la pipeline passa senza immagine in produzione
- tag_and_push "$IMG" "$EXTERNAL_PREFIX" "$TAG" || echo "External registry push failed"

# ✅ CORRETTO — un push fallito fa fallire il job
- tag_and_push "$IMG" "$EXTERNAL_PREFIX" "$TAG"
```

Motivo (lezione appresa): un push esterno che falliva silenziosamente lasciava
la pipeline verde e la produzione senza la nuova immagine. Un verde deve
significare "immagine presente su tutti i registry", sempre.

Le funzioni shell (es. `tag_and_push`) devono propagare l'exit code: con
`set -e` un comando fallito interrompe subito la funzione e il job.

---

## 3. Registry — doppio push, entrambi bloccanti

| Registry | Host | Auth | Uso |
|----------|------|------|-----|
| Interno GitLab | `$CI_REGISTRY` | `$CI_JOB_TOKEN` (auto) | build cache, tracciabilità |
| Esterno aziendale | `registry.example.com/<gruppo>` | rete interna | **usato da Portainer** |

Entrambi i push devono avere successo (vedi §2). Portainer pull dall'esterno:
se manca lì, il deploy fallisce anche con pipeline verde.

Login interno nel `before_script`:
```bash
docker login -u "$CI_REGISTRY_USER" -p "$CI_JOB_TOKEN" "$CI_REGISTRY"
```

> Il nome host del registry esterno è un dato d'ambiente: tenerlo nelle
> `variables` del `.gitlab-ci.yml` o in una CI variable, non genericizzato qui.

---

## 4. Tag immagine prodotti

Per il git tag `vX.Y.Z` la funzione `tag_and_push` produce due tag Docker:

```
<prefix>/<progetto>-main:vX.Y.Z    # immutabile — usato in produzione
<prefix>/<progetto>-main:latest    # mobile — solo comodità/dev
```

- Nome immagine **tutto minuscolo** (Docker rifiuta le maiuscole nel reference).
- Il path deve corrispondere **esattamente** a quello atteso da
  `docker-compose_swarm.yaml` (vedi `docker-swarm-compose.instructions.md`).
- In produzione si pinna `IMAGE_TAG=vX.Y.Z`, **mai** `:latest`. Non rimuovere il
  push di `:vX.Y.Z`: è ciò che rende possibile il rollback deterministico.

---

## 5. Job `docker-build` — Docker-in-Docker

```yaml
docker-build:
  stage: docker
  image: docker:latest
  services:
    - name: docker:dind
      command: ["--tls=false"]
      entrypoint: ["dockerd-entrypoint.sh"]
  cache: []                       # dind non ha .NET: la cache NuGet non serve
```

- `DOCKER_TLS_CERTDIR: ""` nelle `variables` (disabilita TLS tra job e dind).
- `docker build --pull` per prendere sempre l'immagine base aggiornata.
- Il `Dockerfile` deve stare nella **root** del repo (`docker build .`).

---

## 6. Cache NuGet

```yaml
cache:
  key: "$CI_COMMIT_REF_SLUG"       # per-branch
  paths:
    - .nuget/packages/
    - src/<progetto>/obj/
variables:
  NUGET_PACKAGES: "$CI_PROJECT_DIR/.nuget/packages"
```

Il job `docker-build` disabilita la cache (`cache: []`): gira su `docker:latest`,
senza .NET, e la cache andrebbe in conflitto.

---

## 7. `needs:` — pipeline a DAG

Usare `needs:` per far partire un job appena la sua dipendenza è verde, senza
attendere l'intero stage precedente (es. `build` needs `lint`). Riduce il tempo
totale e mantiene comunque l'ordine logico.

---

## 8. Package + Release (facoltativi)

`package` (`dotnet publish --runtime win-x64 --self-contained false`) serve
**solo** se esiste anche un target di deploy Windows bare-metal (IIS/Windows
Service). Per un worker che gira solo su Swarm/Linux è ridondante: valutarne la
rimozione. `--self-contained false` richiede il runtime .NET sul server target.

`release` (immagine `release-cli`) crea la GitLab Release col link allo zip.
Artefatti `expire_in: never` per mantenere lo storico scaricabile.

---

## 9. Gate lint pre-push (coerenza con copilot-instructions)

Il job `lint` usa `dotnet format --verify-no-changes` — **non modifica** i file,
fallisce se la formattazione diverge. Prima di ogni push, in locale:

```bash
dotnet format src/<progetto>/<progetto>.csproj --verify-no-changes
```

Exit `0` → push consentita. Non-zero → **blocca** e correggi prima di pushare.

---

## 10. Adattare per un nuovo progetto

1. Aggiornare `PROJECT_PATH`, `PROJECT_NAME`, `EXTERNAL_REGISTRY_PATH` nelle `variables`.
2. Verificare che il `Dockerfile` sia nella root.
3. **Non** toccare la logica "solo su tag" delle `rules`.
4. Mantenere `set -euo pipefail` e i push bloccanti.
5. Rimuovere `package`/`release` se non serve un artefatto Windows.

---

## ✅ Checklist post-modifica

- [ ] `docker`/`package`/`release` girano solo su tag `/^v\d+\.\d+\.\d+$/`
- [ ] Push su branch = solo `lint` + `build`
- [ ] Ogni snippet shell inizia con `set -euo pipefail`
- [ ] Nessun `|| echo` che maschera un push fallito
- [ ] Push su registry interno **ed** esterno, entrambi bloccanti
- [ ] Nome immagine minuscolo, path coerente col compose
- [ ] Nessuna credenziale nel file (solo variabili CI predefinite / secret)

*Istruzione v1.0 — GitLab CI/CD — 2026-07-21 — claude-opus-4-8 — esempi genericizzati (nessun dato interno)*
