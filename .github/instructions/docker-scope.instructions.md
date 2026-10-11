---
applyTo: "**/Dockerfile,**/*.Dockerfile,**/docker-compose*.yml,**/docker-compose*.yaml,**/compose.yml,**/compose.yaml"
---

# Perimetro di dr-devops per Docker (AI Agent)

`dr-devops` copre tre casi: lo stack Docker Swarm (`docker-compose_swarm.yaml`), il suo deploy da Portainer e le pipeline GitLab CI/CD. Non copre il container su host singolo.

| File | Coperto | Regole |
|---|---|---|
| `docker-compose_swarm.yaml` | Sì | `docker-swarm-compose.instructions.md` e, per il deploy, `portainer-swarm-stack.instructions.md` |
| `docker-compose.yml`, `compose.yaml` per host singolo (`docker compose up`) | **No** | nessuna regola del pacchetto |
| `Dockerfile` | **No** | nessuna regola del pacchetto |

## Cosa fare su un file non coperto

1. **Dichiaralo nell'output**, una riga: "`dr-devops` non copre `<file>`: procedo senza regole del pacchetto."
2. **Non applicare per analogia le regole Swarm.** `deploy:`, `replicas`, `order: stop-first` e le variabili gestite da Portainer non hanno senso con `docker compose up` su un host singolo.
3. **Valgono comunque le regole del core**: nessun valore sensibile nel file (`sensitive-data.instructions.md`), segreti in un `.env` non committato con un `.env.example` committato, nessun valore fisso con un significato (`no-hardcoded-values.instructions.md`).

---

*Istruzione v1.0 - Perimetro Docker di dr-devops - 2026-10-11 — claude-opus-5-5 (dr-devops#1)*
