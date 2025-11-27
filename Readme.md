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

# Architettura del progetto 

    StudentLab/
    │
    ├── app/
    │   ├── main.py              
    │   │
    │   ├── core/      
    │   │
    │   ├── auth/      
    │   │
    │   ├── questionnaires/    
    │   │
    │   ├── dictionary/          
    │   │
    │   ├── files/               
    │   │
    │   ├── shared/ 
    │   │             
    │   ├── profilies/    
    │               
    ├── test/ 
    ├── requirements.txt
    ├── docker-compose.yml
    └── README.md

## Moduli

### **`core/`**
Il modulo core rappresenta le fondamenta dell'intera applicazione. Qui vengono gestite tutte le configurazioni di base e i componenti essenziali che gli altri moduli utilizzeranno. 


### **`auth/`**
Questo modulo è dedicato interamente alla gestione dell'identità degli utenti e al controllo degli accessi.

### **`profiles/`**
Una volta che l'utente è autenticato, questo modulo gestisce tutte le informazioni che lo caratterizzano.

### **`questionnaires/`**
Il cuore didattico dell'applicazione, dedicato alla creazione e somministrazione di test e quiz.

### **`dictionary/`**
Una raccolta dinamica di termini e concetti accademici.

### **`files/`**
Il modulo dedicato all'elaborazione e gestione di tutti i tipi di documenti e file

### **`services/`**
Contiene la logica applicativa riutilizzabile, non endpoint. per mantenere il codice pulito, separano la logica api, riutilizzabili in altri moduli e facilita i test.

### **`main.py`**
Contiene i punti di ingresso dell'applicazione, dove verranno avviati l'app fastAPI, rotte API, il middleware e la connessione del database.

### **`test/`**
Contiene test automatici (Pytest), Serve per verificare che API e servizi funzionino.

### `Readme.md`
Spiega l'obbiettivo del progetto, la struttura del progetto e come avviare l'applicazione.


