# StudentLab Developer Architecture Backend — V1

Questa prima versione trasforma la Developer UI da prototipo mock a backend indicizzabile.

## File

```text
BE/
├── core/
│   └── developer_security.py
├── routes/
│   └── developer_architecture.py
├── schemas/
│   └── developer_architecture.py
├── services/
│   ├── developer_repository.py
│   ├── developer_indexer.py
│   ├── developer_search.py
│   └── developer_graph.py
└── tests/
    └── test_developer_indexer.py
```

## Sicurezza

Gli endpoint accettano esclusivamente:

- `creator`
- `devsyst`

La dependency `get_developer_system_user()` riusa `get_current_user()`, quindi JWT, account attivo e autenticazione continuano a essere gestiti dalla sicurezza esistente.

## Repository root

Per lo sviluppo locale:

```bash
export STUDENTLAB_REPOSITORY_ROOT="$HOME/FranzAmoroso1/projects/DMI-StudentLab"
```

Se non impostata, la root viene dedotta automaticamente dalla posizione `BE/services/...`.

## Include router

In `BE/main.py` aggiungere:

```python
from routes.developer_architecture import (
    router as developer_architecture_router,
)
```

e vicino agli altri `include_router`:

```python
app.include_router(
    developer_architecture_router,
)
```

## Endpoint

```text
GET /developer/access
GET /developer/status
GET /developer/tree
GET /developer/files
GET /developer/file?path=BE/services/auth.py
GET /developer/search?q=login
GET /developer/graph
```

## Badge reali

`DOCUMENTED`
: viene rilevata una documentazione associata.

`OUTDATED`
: il sorgente è più recente del file di documentazione.

`CHANGED`
: Git segnala il file come modificato/untracked.

`SECURITY CRITICAL`
: percorso o simboli contengono indicatori di sicurezza.

`NOT ANALYZED`
: lato UI equivale a `documented == false`.

## Cosa non fa questa V1

- non legge secret `.env`;
- non legge binari;
- non modifica il repository;
- non esegue codice del repository;
- non esegue commit/push;
- non espone il contenuto sorgente completo;
- non usa ancora embeddings/LLM per la ricerca;
- l'analisi Dart è volutamente euristica;
- i flow applicativi espliciti saranno aggiunti nella V2.

## Nota importante

`/developer/status` restituisce il path locale del repository. Se non vuoi esporlo al client, sostituisci `repository_root=str(root)` con un alias come `"local-repository"`.
