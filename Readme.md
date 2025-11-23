# Project Overview
Questo progetto mira ad aiutare studenti con difficoltà dovute a cause di forza maggiore. La piattaforma dispone di un catalogo di argomenti, spiegati in maniera formale e non, per ogni materia di ogni corso universitario. Inoltre è presente una sezione con questionari (contenenti domande di esami passati e nuove) adatti al ripasso delle materie scelte dallo studente. Quest’ultimo può scegliere se affrontare il questionario da solo o se avviare una “challenge” con un altro studente connesso alla piattaforma. Se i due studenti appartengono a corsi di laurea differenti, possono scegliere di affrontarsi  con quiz di cultura generale, o eventualmente con due questionari differenti. Durante i questionari sarà possibile, in qualsiasi momento, consultare il catalogo (che selezionerà automaticamente l’argomento della domanda) per colmare eventuali dubbi. Inoltre, qualora non si conoscesse il significato di eventuali termini, sarà possibile, selezionando la parola, consultare il significato che il termine assume in quel contesto attraverso un dizionario. Affrontando i questionari di materie non ancora conseguite si guadagneranno dei punti. Verrà dunque stilata una classifica tra i vari utenti in ordine decrescente di punteggio. I punti guadagnati saranno condizionati dalla difficoltà della materia e dallo status attuale dello studente (regolare o fuoricorso). Gli studenti che hanno già conseguito una materia otterranno la possibilità di creare nuove domande da inserire nei questionari che saranno verificate dagli sviluppatori. Inoltre, se è stata conseguita una materia propedeutica ad altre, verrà sbloccato l’accesso ai questionari di quest’ultime.  Sarà presente una dashboard dello studente, suddivisa in 6 sezioni: Profilo, Apprendimento, Percorso Universitario, Calendario, Amici e Colleghi.
La piattaforma mira ad essere flessibile per agevolare tutti gli studenti, sarà dunque disponibile una sezione per proporre eventuali migliorie o per segnalare problemi riscontrati durante l’utilizzo dell’app.

## Dashboard utente 
- ### Profilo
    nella sezione del profilo verranno inserite un’immagine profilo, il numero di matricola, nome e cognome dello studente (facoltativo per eventuali preferenze di privacy). Corso di studi e facoltà. Eventuali certificazioni e/o esperienze extracurriculari.

- ### Apprendimento
    nella sezione “apprendimento” lo studente può selezionare degli obbiettivi posti nel proprio corso di studio. Verranno inseriti automaticamente dalla piattaforma i progressi e gli obbiettivi già completati, i punteggi ottenuti e le nozioni apprese. 
- ### Percorso universitario 
    Dopo essere già stato inserito dallo studente nel profilo, la piattaforma mostra in questa sezione il percorso di studi scelto. Lo studente può selezionare quale materie ha già conseguito e con quale voto. L’applicazione calcolerà automaticamente i CFU ottenuti. Inoltre verrà data allo studente, per motivi di privacy, la possibilità di rendere pubblici o meno, i propri progressi nel percorso universitario.
- ### Calendario 
    In questa sezione la piattaforma mostra allo studente l’orario delle lezioni, eventuali attività extra e gli appelli degli esami del proprio corso di studi.
- ### Amici
     Cercando il numero di matricola o il nome sarà possibile aggiungere altri studenti alla propria lista di amici. Rendendo possibile messaggiare con essi, o affrontandoli in una challenge.
- ### Colleghi 
    La piattaforma aggiungerà automaticamente a questa lista, tutti gli studenti che frequentano lo stesso corso dell’utente. 

<!-- ## Catalogo 
## Questionari (singolo o challenge)
## Segnalazioni e Suggerimenti  -->

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
        |-- migrations/
        L-- seed/
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





