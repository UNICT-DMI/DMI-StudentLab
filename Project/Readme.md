# StudentLab

# Struttura del progetto

    Project/
    |
    |-- BE/
        |-- api/
        |-- core/
        |-- models/
        |-- services/
        L-- main.py
    |-- FE/
    |-- database/
    |-- docs/
    |-- Readme.md
    |-- requirements.txt



## `Project/`
È la cartella principale, contiene tutto il progetto: backend, frontend, documentazione, script, database.  

### `FE/`
Il Frontend è la parte che interaggisce con l'utente

### `BE/`
Il backend è il cuore dell'applicazione: gestisce logica dell'applicazione, database, autenticazione, API

#### `API/`
Contiene API per gestire il profilo utente, i questionari, catalogo, espansioni modulari e api per l'autenticazione.

#### `core/`
Contiene le funzioni fondamentali del sistema. come configurazioni globali, funzioni di sicurezza,  gestisce la connessione con il database PostgreSQL

#### `models/`
Contiene i modelli del database: user, tabelle di questionari, cataloghi, dizionari ed eveentuali espanzioni

#### `services/`
Contiene la logica applicativa riutilizzabile, non endpoint. per mantenere il codice pulito, separano la logica api, riutilizzabili in altri moduli e facilita i test.

#### `main.py`
Contiene i punti di ingresso dell'applicazione, dove verranno avviati l'app fastAPI, rotte API, il middleware e la connessione del database.

#### `test/`
Contiene test automatici (Pytest), Serve per verificare che API e servizi funzionino.

### `database/migrations/`
Contiene file di migrazione Alembic:
Modifica della struttura tabellare del database nel tempo

### `databse/seed/`
Dati da inserire inizialmente all'interno del database, 
(sono complementari non duplicati)

### `requirements.txt`
Contiene la lista dei pachetti python necessari per l'app

### `Readme.md`
Spiega l'obbiettivo del progetto, la struttura del progetto e come avviare l'applicazione.

### `Docs`
Documentazione del progetto (diagrammi, API docs, guide)





