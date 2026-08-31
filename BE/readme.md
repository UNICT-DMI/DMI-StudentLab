# StudentLab – Architettura Storage con Raspberry Pi

## Obiettivo

L'obiettivo è evitare di utilizzare Vercel Blob come storage principale per grandi quantità di materiale didattico.

StudentLab può invece utilizzare:

- **Vercel** per ospitare il backend FastAPI.
- **Neon PostgreSQL** per utenti, gruppi, materie e metadati dei materiali.
- **Raspberry Pi + disco da 5 TB** come storage principale dei file.
- **Flutter** come client per upload e download.

In questo modo i file pesanti non vengono salvati direttamente su Vercel e non devono attraversare le Vercel Functions.

---

## Architettura generale

```text
                    Neon PostgreSQL
                         ↑
                    metadati file
                         │
                         │
Flutter ───────► FastAPI / Vercel
   │                   │
   │                   │ autorizzazione
   │                   │
   │                   ▼
   └──────────────► Raspberry Pi
                        │
                        │
                    Disco 5 TB
                        │
                 PDF / ZIP / DOCX
                 PPTX / altri file
```

---

## Ruolo di ogni componente

### Flutter

Flutter gestisce:

- selezione del file;
- richiesta di autorizzazione al backend;
- upload diretto verso il Raspberry Pi;
- download diretto dal Raspberry Pi;
- visualizzazione dei materiali presenti nei gruppi;
- salvataggio locale/offline sul dispositivo.

Il file non deve necessariamente attraversare FastAPI.

---

### FastAPI su Vercel

FastAPI rimane il punto centrale per:

- autenticazione;
- autorizzazione;
- controllo appartenenza ai gruppi;
- gestione dei permessi;
- creazione dei materiali;
- registrazione dei metadati;
- eliminazione dei materiali;
- coordinamento tra Flutter e Raspberry Pi.

FastAPI non deve essere utilizzato come proxy per file da 100 MB o superiori.

Esempio:

```text
Flutter
   ↓
FastAPI

"Posso caricare questo file nel gruppo 12?"

FastAPI
   ↓
controlla utente e permessi
   ↓
autorizza il caricamento

Flutter
   ↓
Raspberry Pi
```

---

### Neon PostgreSQL

Neon conserva esclusivamente i dati strutturati.

Per esempio:

```text
group_materials

id
group_id
uploaded_by
original_name
stored_name
file_path
mime_type
size
created_at
```

Neon non deve contenere direttamente i file binari.

Un record potrebbe rappresentare:

```text
id: 42
group_id: 12
uploaded_by: 7
original_name: reti_appunti.pdf
stored_name: 8f14e45f.pdf
file_path: groups/12/8f14e45f.pdf
mime_type: application/pdf
size: 104857600
```

---

### Raspberry Pi

Il Raspberry Pi diventa il file server di StudentLab.

Struttura possibile:

```text
Raspberry Pi
│
├── studentlab-storage/
│   ├── groups/
│   │   ├── group_1/
│   │   ├── group_2/
│   │   └── group_12/
│   │
│   └── materials/
│
└── file-service/
    ├── upload
    ├── download
    ├── delete
    └── health
```

Il Raspberry deve esporre un piccolo servizio API dedicato.

Possibili endpoint:

```text
POST   /storage/upload
GET    /storage/file/{storage_key}
DELETE /storage/file/{storage_key}
GET    /storage/health
```

---

# Upload di un materiale

Esempio: uno studente vuole caricare un file da 150 MB.

## Fase 1 – Autorizzazione

Flutter comunica con FastAPI:

```text
POST /materials/request-upload
```

con informazioni come:

```json
{
  "group_id": 12,
  "filename": "reti_appunti.pdf",
  "mime_type": "application/pdf",
  "size": 157286400
}
```

FastAPI controlla:

- utente autenticato;
- esistenza del gruppo;
- appartenenza al gruppo;
- permessi;
- tipo di file;
- dimensione consentita.

---

## Fase 2 – Upload

Se autorizzato:

```text
Flutter
   │
   │ file da 150 MB
   ▼
Raspberry Pi
```

Il file non passa attraverso Vercel.

Il Raspberry salva il file, per esempio:

```text
/studentlab-storage/groups/group_12/a81f0924.pdf
```

---

## Fase 3 – Registrazione

Al termine dell'upload viene registrato il materiale su Neon.

```text
FastAPI
   ↓
Neon
```

Neon salva soltanto:

- ID materiale;
- gruppo;
- proprietario;
- nome originale;
- storage key;
- MIME type;
- dimensione;
- data di creazione.

---

# Download di un materiale

Quando uno studente vede:

```text
reti_appunti.pdf
```

e preme **Scarica**:

```text
Flutter
   ↓
FastAPI
```

FastAPI verifica che l'utente possa accedere al materiale.

Dopo l'autorizzazione:

```text
Raspberry Pi
    │
    │ file
    ▼
Flutter
```

Il file viene quindi trasferito direttamente dal Raspberry al dispositivo.

---

# Eliminazione di un materiale

Quando un materiale viene eliminato definitivamente:

```text
Flutter
   ↓
FastAPI
```

FastAPI controlla se l'utente è autorizzato.

Successivamente:

```text
FastAPI
   ├──► Raspberry Pi
   │       elimina file fisico
   │
   └──► Neon
           elimina record
```

In questo modo non rimangono file orfani sul disco.

---

# Copie offline sui dispositivi

Il sistema locale Flutter rimane separato dallo storage centrale.

Sul dispositivo:

```text
Android / Linux / Windows
│
├── SQLite
│   └── metadati copia locale
│
└── filesystem
    └── file scaricato
```

SQLite non contiene necessariamente il file.

Può conservare:

```text
material_id
user_id
local_path
original_name
mime_type
size
downloaded_at
```

Il file reale rimane nel filesystem del dispositivo.

Se un materiale viene eliminato dal gruppo, una copia già scaricata offline sul dispositivo dell'utente non viene necessariamente eliminata automaticamente.

---

# Capacità prevista

Scenario iniziale:

```text
27 materie
× 20 file per materia
× 100 MB
≈ 54 GB
```

Con un disco da 5 TB:

```text
5 TB ≈ 5000 GB
```

54 GB rappresentano circa l'1% della capacità totale.

Questo lascia molto margine per:

- nuovi corsi;
- nuove materie;
- più anni accademici;
- materiali più grandi;
- backup;
- versioni multiple.

---

# Vantaggi

## Costi di storage ridotti

Lo storage principale viene gestito con hardware già posseduto.

Non è necessario pagare decine o centinaia di GB di object storage cloud.

---

## File molto grandi

Il file non attraversa Vercel.

Questo permette di gestire materiali da:

```text
100 MB
250 MB
500 MB
1 GB
```

a condizione che il Raspberry e la connessione Internet possano sostenere il trasferimento.

---

## Separazione delle responsabilità

```text
Vercel
→ applicazione / API

Neon
→ database

Raspberry
→ file

Flutter
→ client
```

Ogni componente svolge un ruolo preciso.

---

## Scalabilità futura

In futuro è possibile aggiungere:

```text
Raspberry principale
        +
Vercel Blob / S3 / R2
```

come:

- cache;
- backup;
- fallback;
- storage per materiali molto richiesti.

---

# Limiti e rischi

## Connessione Internet

La velocità di download disponibile agli studenti dipenderà soprattutto dall'upload della connessione dove si trova il Raspberry.

Esempio:

```text
20 Mbps upload
≈ 2,5 MB/s complessivi
```

Con più utenti contemporanei la banda viene condivisa.

Una connessione FTTH con upload elevato è quindi preferibile.

---

## Disponibilità

Il Raspberry dovrebbe essere:

- acceso 24/7;
- collegato stabilmente a Internet;
- protetto da interruzioni;
- monitorato;
- aggiornato.

Se il Raspberry è offline:

```text
StudentLab API        ✅
Neon                  ✅
gruppi e metadati     ✅
download file         ❌
```

---

## Disco

Un singolo disco non deve essere considerato un backup.

Per materiali importanti è consigliabile in futuro avere almeno:

```text
Disco principale
        +
Backup secondario
```

oppure una copia cloud selettiva.

---

## Sicurezza

Il Raspberry non deve esporre liberamente tutti i file tramite URL pubblici.

Non utilizzare semplicemente:

```text
http://IP-RASPBERRY/file.pdf
```

senza protezione.

Il file-service deve prevedere:

- HTTPS;
- autenticazione;
- token temporanei;
- validazione dei percorsi;
- controllo MIME type;
- limite dimensione;
- protezione da path traversal;
- rate limiting;
- logging.

FastAPI deve rimanere il componente che decide chi è autorizzato a caricare, scaricare o eliminare un materiale.

---

# Evoluzione futura: P2P

In futuro StudentLab potrebbe anche introdurre trasferimenti peer-to-peer.

Esempio:

```text
Studente A
    │
    │ WebRTC
    ▼
Studente B
```

FastAPI servirebbe soltanto per il signaling e l'autorizzazione.

In questo scenario gli studenti che hanno già scaricato un materiale potrebbero diventare fonti aggiuntive.

Esempio:

```text
             Studente A
             /        \
            ▼          ▼
      Studente B    Studente C
            │
            ▼
      Studente D
```

Questa funzionalità è però considerata una possibile evoluzione futura e non è necessaria per la prima versione dello storage Raspberry.

---

# Architettura consigliata per la prima versione

```text
                       ┌────────────────────┐
                       │ Neon PostgreSQL    │
                       │                    │
                       │ utenti             │
                       │ gruppi             │
                       │ materie            │
                       │ metadata materiali │
                       └─────────▲──────────┘
                                 │
                                 │
                       ┌─────────┴──────────┐
                       │ FastAPI / Vercel   │
                       │                    │
                       │ autenticazione     │
                       │ autorizzazione     │
                       │ API                │
                       └─────────▲──────────┘
                                 │
                                 │
                    ┌────────────┴────────────┐
                    │                         │
                    │                         │
                 Flutter               Raspberry Pi
                    │                  + disco 5 TB
                    │                         ▲
                    └─────────────────────────┘
                       upload / download file
```

---

# Strategia

## Prima fase

Utilizzare:

```text
Vercel + FastAPI
Neon PostgreSQL
Raspberry Pi + 5 TB
Flutter
```

con upload/download diretto tra Flutter e Raspberry.

## Seconda fase

Aggiungere:

- autenticazione completa;
- token temporanei per download;
- monitoraggio storage;
- backup automatici;
- limiti per utente;
- quote per gruppo;
- cache.

## Terza fase

Valutare:

- object storage di fallback;
- replica geografica;
- P2P/WebRTC;
- più Raspberry/storage node;
- CDN per file molto richiesti.

---

# Principio fondamentale

StudentLab deve separare:

```text
DATI
→ Neon PostgreSQL

FILE
→ Raspberry Pi / storage

LOGICA E AUTORIZZAZIONE
→ FastAPI

INTERFACCIA E STORAGE OFFLINE
→ Flutter
```

Questo permette di mantenere il backend leggero, evitare i limiti delle Vercel Functions sui file grandi e utilizzare il Raspberry Pi come archivio centrale dei materiali.