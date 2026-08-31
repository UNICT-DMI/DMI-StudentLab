Sì: **possiamo fare esattamente quello che descrivi**, e la distinzione fondamentale è questa:

**il file salvato da StudentLab nel proprio spazio offline dell’app può essere aggiornato o eliminato.** Quello che non possiamo controllare è un’eventuale copia che l’utente ha esportato manualmente fuori da StudentLab, ad esempio in `Download/` del telefono. Ma a te interessa la libreria interna dell’app, quindi non è un problema.

Nel tuo caso costruirei il sistema così.

### La card rappresenta la materia, non il singolo file

Se uno studente ha:

```text
Programmazione 1
```

deve esserci **una sola card**:

```text
Programmazione 1
3 materiali
```

e dentro:

```text
Programmazione 1
│
├── Dispensa strutture dati.pdf
├── Esercizi alberi.pdf
└── Appunti puntatori.pdf
```

Quindi due PDF diversi della stessa materia **non sono duplicati**. Semplicemente appartengono alla stessa card.

Il duplicato va determinato sul **materiale**, non sulla materia.

Per esempio:

```text
Materia uguale + file diverso         → nuovo materiale nella stessa card ✅
Materia uguale + stesso SHA-256       → duplicato ❌
Stesso materiale remoto, nuova versione → aggiornamento ✅
```

Questo è molto importante perché altrimenti rischieremmo di impedire a una materia di avere più dispense.

---

### Anche SQLite può essere aggiornato e cancellato

Nel tuo `MaterialDownloadService` già oggi fai entrambe le cose.

Quando elimini:

```dart
await _fileService.delete(
  material.localPath,
);

await _repository.delete(
  userId:
      resolvedUserId,
  materialId:
      material.materialId,
);
```

quindi viene eliminato:

1. il file dalla cartella interna di StudentLab;
2. il record SQLite.

Questo significa che possiamo tranquillamente fare:

```text
Admin rimuove materiale
        ↓
utente torna online
        ↓
sync StudentLab
        ↓
materiale risulta revocato
        ↓
elimina file interno
        ↓
elimina record SQLite
        ↓
non compare più offline
```

Ed è esattamente quello che vuoi.

L'eventuale copia fatta manualmente dall'utente fuori dall'app rimane, ma StudentLab non la considera più.

---

## Per gli aggiornamenti farei ancora meglio

Non cancellerei il record remoto e ne creerei uno nuovo ogni volta.

Ogni materiale remoto deve mantenere **un'identità stabile**.

Esempio:

```text
TeacherMaterial id = 48

versione 1
appunti_programmazione.pdf
hash = ABC
```

Il docente aggiorna il documento:

```text
TeacherMaterial id = 48

versione 2
appunti_programmazione.pdf
hash = XYZ
```

Quindi rimane:

```text
material_id = 48
```

ma cambiano:

```text
version
stored_name
file_hash
size
updated_at
```

Sul telefono possiamo avere:

```text
materialId = 48
remoteVersion = 1
fileHash = ABC
```

Durante la sincronizzazione:

```text
SERVER
id 48
version 2
hash XYZ

        ↓ confronto

SQLITE
id 48
version 1
hash ABC

        ↓

AGGIORNAMENTO DISPONIBILE
```

A quel punto StudentLab può scaricare il nuovo file e sostituire quello vecchio.

---

# E possiamo anche farlo automaticamente

Per i materiali assegnati direttamente da:

* teacher;
* admin/StudentLab;
* eventualmente materiale obbligatorio di un gruppo;

possiamo impostare:

```text
nuova versione
      ↓
sync
      ↓
scarica nuovo file
      ↓
verifica hash
      ↓
salva nuovo file
      ↓
aggiorna SQLite
      ↓
elimina vecchio file
```

L'utente continuerà a vedere semplicemente:

```text
Appunti Programmazione
```

senza avere:

```text
Appunti Programmazione
Appunti Programmazione (2)
Appunti Programmazione nuovo
```

Quindi **niente duplicati**.

Meglio ancora, farei la sostituzione in modo sicuro:

```text
1. scarica versione nuova in temporaneo
2. verifica dimensione/hash
3. se tutto corretto:
       sostituisce il vecchio
       aggiorna SQLite
4. se fallisce:
       mantiene il vecchio
```

Così non rischiamo di perdere una dispensa funzionante per un download interrotto.

---

# Dobbiamo distinguere origine e identità

Questo diventa molto importante.

Nel record SQLite aggiungerei concettualmente:

```dart
sourceType
remoteMaterialId
remoteVersion
fileHash
```

Ad esempio:

```text
source_type        = teacher
remote_material_id = 48
remote_version     = 3
file_hash          = XYZ...
```

oppure:

```text
source_type        = public
remote_material_id = 17
remote_version     = 2
```

oppure:

```text
source_type        = group
remote_material_id = 82
remote_version     = 1
```

Per un file personale:

```text
source_type        = local
remote_material_id = null
remote_version     = null
```

Questo risolve tantissime cose.

---

# File personale dell'utente

Qui farei la distinzione che stavi proponendo.

Supponiamo che Franz abbia offline:

```text
Programmazione 1
└── miei_appunti.pdf
```

È:

```text
source = local
```

e non esiste ancora sul server.

Premendo:

```text
Proponi a StudentLab
```

inviamo la richiesta.

Una volta che esiste nel database una richiesta, il file locale può conservare:

```text
publicationRequestId = 31
```

A quel punto, se Franz prova nuovamente a proporre **quel materiale**, non dobbiamo creare:

```text
richiesta 31
richiesta 32
richiesta 33
```

Possiamo mostrargli:

```text
Questo materiale è già stato proposto.

[Aggiorna proposta]
[Visualizza stato]
```

Ed è molto più pulito.

---

# Se il materiale è già pubblicato

Caso successivo.

La richiesta `31` viene approvata e genera:

```text
PublicMaterial id = 12
```

Il locale può diventare associato a:

```text
source = public
remoteMaterialId = 12
```

oppure possiamo mantenere anche:

```text
origin = user_local
publicMaterialId = 12
```

Se l'utente modifica successivamente il proprio file e vuole riproporlo, non crea un altro materiale completamente indipendente.

Può fare:

```text
Proponi aggiornamento
```

che crea qualcosa come:

```text
MaterialPublicationRequest

target_public_material_id = 12
request_type = update
```

L'admin vede:

```text
Aggiornamento proposto

Materiale attuale:
Appunti strutture dati

Nuova versione:
Appunti strutture dati

[Confronta]
[Approva aggiornamento]
[Rifiuta]
```

Se approva:

```text
PublicMaterial id = 12
version 1 → version 2
hash ABC → XYZ
```

Non nasce un `PublicMaterial id = 73`.

Questo è il comportamento che adotterei.

---

# Anche teacher e admin funzionerebbero nello stesso modo

Teacher:

```text
TeacherMaterial id = 41
version = 1
```

il docente modifica:

```text
TeacherMaterial id = 41
version = 2
```

Agli studenti:

```text
SQLite
version 1

↓ sincronizzazione

server
version 2

↓
aggiornamento automatico
```

Admin/StudentLab:

```text
PublicMaterial id = 20
v1 → v2
```

stessa identica logica.

---

# E se l'admin elimina il materiale?

Qui invece:

```text
id = 41
status = removed
```

non facciamo necessariamente `DELETE FROM teacher_materials`.

Durante la sincronizzazione:

```text
SQLite:
teacher / 41

Server:
teacher / 41 / removed

        ↓

StudentLab:
elimina file locale
elimina/segna rimosso record SQLite
```

E scompare dalle dispense.

Questo è molto meglio di cancellare fisicamente subito il record server perché manteniamo audit:

```text
chi lo ha rimosso
quando
perché
```

---

## Quindi avremo tre concetti distinti

È questa la parte chiave:

```text
MATERIA
Programmazione 1
        ↓
una sola card

MATERIALI
        ↓
molti file diversi nella card

VERSIONI
        ↓
lo stesso materiale può essere aggiornato
senza generare duplicati
```

E il controllo duplicati diventa:

```text
stessa materia                  ≠ duplicato
stesso nome                     ≠ necessariamente duplicato
stesso SHA-256                  = duplicato contenuto
stesso source + remote id       = stesso materiale
stesso remote id + hash diverso = nuova versione
```

### Io modificherei leggermente il piano prima di continuare

Prima di aggiungere molti endpoint singoli, conviene introdurre ora il concetto di:

```text
material source
material version
material status
```

sia lato server sia SQLite.

Altrimenti rischiamo oggi di costruire:

```text
downloadPublicMaterial
downloadTeacherMaterial
downloadGroupMaterial
```

e tra poco doverli modificare tutti di nuovo per aggiornamento, revoca e sincronizzazione.

La struttura definitiva che suggerisco è:

```text
Dispense StudentLab

Programmazione 1
│
├── Materiale A
│   source: public
│   remote_id: 12
│   version: 3
│
├── Materiale B
│   source: teacher
│   remote_id: 48
│   version: 2
│
├── Materiale C
│   source: group
│   remote_id: 91
│   version: 1
│
└── I miei appunti
    source: local
```

Con questa struttura possiamo fare bene **download, aggiornamento automatico, rimozione remota, deduplicazione, proposta di aggiornamento e sincronizzazione offline** senza creare card duplicate.


un'altro requisito e quando lo studente a un file come programmazione 1 offline e non lo haancora proposto a studentlab, studentlab carica il file programmazione 1, allora nell'admi panel a me spunta il file che ha l'utente con il mio, se i file parlano della stessa cosa ma il mio  più aggiornato allora propongo aggiornamento se il suo è più aggiornato allora mi prendo il suo e agli altri gli verrà dato il materiale preso, se invece i due file parlano di una cosa diversa allora gli cambierò il nome del file con l'argomento più trattato o se si avvicina agli argomenti trattati semplicemente gli aggiungo qualche fisso dopo il nome

Mostrerei:

È disponibile una versione più recente
su StudentLab.


[Aggiorna]
[Mantieni la mia copia]

Se sceglie Aggiorna, sostituiamo la copia interna di StudentLab.

Questo evita che un aggiornamento remoto distrugga accidentalmente appunti personali che, inizialmente, erano soltanto coincidenti con il materiale pubblico.



Sì. Prima di scrivere il codice SQLite conviene fissare bene il modello, perché qui dobbiamo far convivere **materiali locali personali** e **materiali sincronizzati dal server** senza rischiare sovrascritture.

Per StudentLab imposterei SQLite come una cache/libreria locale, non come copia 1:1 di PostgreSQL.

## Struttura che userei

La tabella principale sarebbe:

```text
materials
```

Ogni record rappresenta **un file presente o conosciuto localmente**.

Campi principali:

```text
id                      INTEGER PRIMARY KEY AUTOINCREMENT

source                  TEXT NOT NULL
remote_key              TEXT UNIQUE
remote_id               INTEGER

subject_id              INTEGER
group_id                INTEGER

original_name           TEXT NOT NULL
local_path              TEXT

mime_type               TEXT
size                    INTEGER
file_hash               TEXT

remote_version          INTEGER
local_version           INTEGER

remote_status           TEXT
download_status         TEXT NOT NULL
sync_status             TEXT NOT NULL

is_available_remote     INTEGER NOT NULL
is_downloaded           INTEGER NOT NULL
is_personal             INTEGER NOT NULL

created_at              TEXT NOT NULL
updated_at              TEXT NOT NULL
last_synced_at          TEXT
```

### `source`

Valori:

```text
local
public
teacher
group
```

Esempi:

```text
local
public:12
teacher:48
group:31
```

Ma io terrei separati:

```text
source = teacher
remote_id = 48
remote_key = teacher:48
```

È molto più comodo per query e filtri.

---

## Il punto fondamentale: `local`

Un materiale:

```text
source = local
```

è proprietà locale dell'utente.

Quindi:

```text
remote_key = NULL
remote_id = NULL
is_personal = 1
```

e **il sync non deve mai cancellarlo o sostituirlo**.

Questo è il vincolo più importante dell'architettura.

Se l'utente possiede:

```text
Appunti Programmazione 1.pdf
```

e il server pubblica un file con lo stesso nome, non succede nulla.

Il nome non determina l'identità.

Usiamo:

```text
file_hash SHA-256
```

---

# Caso interessante: file locale identico a quello remoto

Supponiamo che l'utente abbia già:

```text
local/appunti.pdf
hash = ABC123
```

e arrivi dal manifest:

```text
teacher:48
hash = ABC123
```

Non dobbiamo scaricare di nuovo il file.

Possiamo associare la risorsa remota al file già presente.

Per farlo eviterei di mettere tutto direttamente in `materials`.

Aggiungerei una seconda tabella:

```text
material_files
```

che rappresenta il **file fisico** sul dispositivo.

### `material_files`

```text
id
local_path
file_hash UNIQUE
size
mime_type
created_at
updated_at
```

Poi `materials` contiene:

```text
file_id
```

come FK.

Quindi possiamo avere:

```text
materials
--------------------------------
id  source      remote_key    file_id
1   local       NULL          7
2   teacher     teacher:48    7
```

Entrambi puntano allo stesso file fisico:

```text
material_files
--------------------------------
id  file_hash    local_path
7   ABC123       /.../file.pdf
```

Questo evita copie duplicate.

Ed è esattamente il comportamento che avevamo progettato lato server/hash.

---

# Quindi dividerei `material` e `file`

La struttura definitiva sarebbe:

## 1. `material_files`

Rappresenta ciò che esiste realmente sul filesystem.

```sql
material_files
```

Campi:

```text
id
local_path
file_hash
size
mime_type
exists_locally
created_at
updated_at
```

---

## 2. `materials`

Rappresenta la risorsa logica.

```text
id
source
remote_key
remote_id

subject_id
group_id

original_name

file_id

remote_version
remote_status

is_available_remote
is_personal

created_at
updated_at
last_synced_at
```

Relazione:

```text
materials.file_id
        ↓
material_files.id
```

---

# 3. `material_sync_state`

Non salverei l'ultima sincronizzazione dentro ogni file.

Userei una tabella dedicata:

```text
material_sync_state
```

con:

```text
id
user_id
last_manifest_at
last_successful_sync_at
updated_at
```

Normalmente avremo una riga per account.

Esempio:

```text
user_id = 25
last_manifest_at = 2026-08-20T00:30:00Z
```

La successiva chiamata:

```http
GET /materials/sync-manifest?since=2026-08-20T00:30:00Z
```

---

# 4. `material_downloads`

Io separerei anche lo stato temporaneo dei download.

```text
material_downloads
```

con:

```text
id
material_id
status
temp_path
expected_hash
expected_size
downloaded_bytes
started_at
completed_at
error_message
```

Stati:

```text
pending
downloading
verifying
completed
failed
```

Questo diventa molto utile sui file da 100-250 MB.

Se l'app viene chiusa durante un download possiamo sapere cosa è successo.

---

# Flusso di sincronizzazione

Quando Flutter chiama:

```http
GET /materials/sync-manifest
```

riceve per esempio:

```json
{
  "generated_at": "...",
  "visible_keys": [
    "public:12",
    "teacher:48",
    "group:31"
  ],
  "items": [...]
}
```

SQLite fa:

```text
SERVER
  ↓
manifest
  ↓
remote_key
  ↓
materials
  ↓
controllo version/hash
  ↓
material_files
```

### Nuovo materiale

Server:

```text
teacher:48
version=1
hash=AAA
```

SQLite non lo conosce.

Inserisce:

```text
materials
source=teacher
remote_key=teacher:48
remote_version=1
file_id=NULL
```

Il file può essere mostrato come:

```text
Disponibile online
```

senza essere ancora scaricato.

---

# Quando l'utente preme Download

Chiamiamo:

```http
GET /materials/teacher/48/download
```

Scarichiamo inizialmente in:

```text
temp/
```

Poi:

```text
download
   ↓
SHA-256
   ↓
hash == manifest.file_hash ?
```

Se NO:

```text
cancella temp
download fallito
```

Se SÌ:

```text
atomic rename
```

e inseriamo:

```text
material_files
```

Infine:

```text
materials.file_id = material_files.id
```

---

# Aggiornamento remoto

Abbiamo:

```text
teacher:48
remote_version = 1
hash = AAA
```

Il manifest successivo dice:

```text
teacher:48
version = 2
hash = BBB
```

Per una risorsa server-managed:

```text
public
teacher
group
```

possiamo fare:

```text
scarica v2 in temp
        ↓
verifica hash BBB
        ↓
sostituzione atomica
        ↓
remote_version = 2
```

Non tocchiamo mai:

```text
source=local
```

---

# Tombstone

Se riceviamo:

```json
{
  "key": "teacher:48",
  "is_tombstone": true
}
```

oppure la chiave non compare più in:

```text
visible_keys
```

facciamo:

```text
materials.is_available_remote = 0
```

Non cancellerei immediatamente il record.

Questo permette di sapere che:

```text
teacher:48
```

esisteva ma non è più disponibile.

Poi possiamo decidere cosa fare al file fisico.

### Se il file è usato solo da quel materiale

Può essere eliminato.

### Se lo stesso `file_id` è usato anche da:

```text
local
```

non dobbiamo cancellarlo.

Ecco perché la separazione:

```text
materials
material_files
```

è molto utile.

---

# Protezione dei file personali

Questa query determina se possiamo eliminare fisicamente un file:

```sql
SELECT COUNT(*)
FROM materials
WHERE file_id = ?
```

Se il file è ancora referenziato da:

```text
source = local
```

rimane sul dispositivo.

Quindi una rimozione server non può mai accidentalmente eliminare gli appunti personali.

---

# Struttura finale

Io imposterei SQLite v1 della nuova architettura con **4 tabelle**:

```text
material_files
materials
material_downloads
material_sync_state
```

Più avanti possiamo aggiungere:

```text
subjects_cache
groups_cache
```

ma non sono necessarie per far funzionare la libreria materiali.

La relazione principale diventa:

```text
                  ┌──────────────────┐
                  │ material_files   │
                  │                  │
                  │ file_hash        │
                  │ local_path       │
                  │ size             │
                  └────────▲─────────┘
                           │
                           │ file_id
                           │
                  ┌────────┴─────────┐
                  │ materials        │
                  │                  │
                  │ source           │
                  │ remote_key       │
                  │ remote_version   │
                  │ subject_id       │
                  │ group_id         │
                  └──────────────────┘

       ┌────────────────────┐
       │ material_downloads │
       └────────────────────┘

       ┌────────────────────┐
       │ material_sync_state│
       └────────────────────┘
```

Questa struttura ci permette di avere **offline, deduplicazione SHA-256, versioning, assegnazioni teacher, gruppi, materiali pubblici e file personali** senza mischiare identità logica e file fisico.

Il prossimo passo lo farei già concreto: creare il **primo file Dart completo del database SQLite**, con `onCreate`, versione database e tutte e quattro le tabelle, prima ancora di scrivere repository e sync service.


Autenticazione e account
registrazione/login
JWT
verifica email
controllo età
accettazione policy/privacy/termini
ruoli student, teacher, admin, creator
teacher con verifica manuale
persistenza/sessione FE da fare dopo
Profilo e percorso accademico
percorsi multipli
percorso current/primary
stato enrolled / graduated
verifica manuale dei percorsi conclusi
profilo pubblico con visibilità controllata
segnalazione profilo / errore personale / eliminazione account
Materie e voti
associazione materie all’utente
voto con stato pending
verifica/rifiuto admin
voto pubblico solo se verificato
disponibilità per aiuto / lezioni private
Docenti
registrazione come teacher
verifica teacher
teacher assignments
materiali docente
assegnazione materiali a singoli studenti o gruppi
controllo accesso al materiale assegnato
Gruppi
creazione gruppo
pubblico/privato
join diretto o richiesta
owner/admin/member
gestione membri
cambio ruoli
eliminazione gruppo
trasferimento ownership
segnalazione gruppo/contenuti
Materiali
materiali gruppo
materiali docente
upload privato
hash anti-duplicato
metadata su PostgreSQL
file su storage esterno
pubblicazione/moderazione materiali
sync/versioning e logica offline da completare soprattutto lato client
Notifiche
backend notifiche
badge/lista lato FE ancora da collegare
Group News
Era l’ultimo blocco backend importante prima del FE:
news di gruppo
news private tra membri
reply tramite parent_news_id
scadenza dopo 7 giorni
cancellazione autore
moderazione owner/admin solo dove consentito
moderazione globale admin/creator
segnalazione news/autore
blocco utente
blocco dei messaggi privati quando esiste un block
contenuti del bloccato nascosti nel feed
privacy delle news private rispetto a owner/admin


Sì. Il blocco che stiamo implementando adesso è il **sottosistema Materiali + persistenza locale + sincronizzazione offline/online**, con aggancio progressivo a profilo, gruppi e materiali docente.

Hai appena raggiunto un punto importante: `flutter analyze lib/local_storage` → **No issues found**, quindi la base locale v6 è coerente e compilabile.

## Blocco attuale: Materiali / Local Storage / Sync

L’architettura che abbiamo impostato è questa:

```text
PostgreSQL / FastAPI
        │
        │ REST + manifest sync
        ▼
Flutter
        │
        ├── materials
        ├── material_files
        ├── material_downloads
        ├── material_sync_state
        └── pending_uploads
                │
                ▼
        filesystem locale
```

Il principio fondamentale è separare:

```text
Materiale logico
≠
File fisico
```

Per esempio lo stesso PDF può essere:

```text
material_files
└── file_id = 8
    hash = ABC...

materials
├── materiale personale → file_id 8
└── materiale docente   → file_id 8
```

Se il docente revoca il materiale remoto, **non dobbiamo cancellare il PDF** se esiste ancora un materiale personale che lo utilizza.

Questo requisito è già incorporato nel ref-count che abbiamo costruito.

---

# Requisiti funzionali del blocco Materiali

## 1. Materiali personali

Lo studente deve poter:

* importare file dal dispositivo;
* organizzarli per università;
* dipartimento;
* corso;
* materia;
* eventualmente argomento in futuro;
* consultare i materiali offline;
* mantenerli anche se il backend non è raggiungibile.

Un materiale personale ha:

```text
source = local
is_personal = true
remote_id = null
remote_key = null
```

e **non viene mai eliminato da una sincronizzazione server**.

---

## 2. Materiali pubblici

Materiali gestiti dal backend e disponibili agli studenti.

Devono:

* comparire nella materia corretta;
* poter essere scaricati;
* essere disponibili offline dopo il download;
* essere aggiornati quando cambia la versione server;
* sparire dalla disponibilità se vengono rimossi dal backend.

---

## 3. Materiali docente

Il teacher verificato può:

* caricare materiale;
* associarlo a una materia;
* decidere la visibilità;
* renderlo disponibile agli studenti;
* assegnarlo direttamente a studenti;
* assegnarlo a gruppi;
* revocare un’assegnazione.

Abbiamo anche appena completato la parte backend delle:

```text
TeacherMaterialAssignment
```

con assegnazione:

```text
teacher → student
teacher → group
```

e visibilità generale:

```text
visibility = students
```

oltre alle assegnazioni specifiche.

---

## 4. Materiali gruppo

I membri autorizzati devono poter caricare materiali nel gruppo secondo i permessi.

I file sono remoti ma possono essere scaricati localmente.

Devono essere separati per:

```text
user
group
material
```

e non devono diventare automaticamente materiali personali.

---

## 5. Upload offline

Abbiamo mantenuto:

```text
pending_uploads
```

perché un upload può essere preparato localmente anche quando la rete non è disponibile.

Gli stati sono:

```text
pending
uploading
failed
uploaded
```

e abbiamo appena sistemato:

```text
retry_count
last_attempt_at
uploaded_at
server_material_id
```

Se l’app viene chiusa mentre:

```text
status = uploading
```

alla riapertura:

```text
uploading → pending
```

e può essere ritentato.

---

# Download e deduplicazione

Il flusso concordato è:

```text
download
   ↓
file temporaneo
   ↓
SHA-256
   ↓
verifica hash
   ↓
material_files
   ↓
materials.file_id
```

Se il file con lo stesso SHA-256 esiste già:

```text
NON duplichiamo il file fisico
```

ma riutilizziamo:

```text
file_id
```

Questo riduce spazio occupato e permette la condivisione fisica sicura tra materiali logici.

---

# Sincronizzazione

Il backend deve esporre il manifest:

```http
GET /materials/sync-manifest
```

e successivamente:

```http
GET /materials/sync-manifest?since=...
```

Ogni materiale remoto usa una chiave qualificata:

```text
public:12
teacher:48
group:31
```

non solamente:

```text
48
```

perché gli ID potrebbero coincidere tra tabelle diverse.

Il server restituisce anche:

```text
visible_keys
```

che rappresenta **l’insieme completo dei materiali che quell’utente può ancora vedere**.

Se localmente abbiamo:

```text
teacher:48
```

ma non compare più in:

```text
visible_keys
```

allora:

```text
is_available_remote = false
```

e il download remoto può essere eliminato.

Ma il file fisico viene eliminato soltanto se:

```sql
SELECT COUNT(*)
FROM materials
WHERE file_id = ?
```

restituisce `0`.

---

# Account e privacy locale

Ogni dato remoto locale è associato a:

```text
user_id
```

Quindi due account sullo stesso dispositivo non devono vedere reciprocamente:

* download;
* cache;
* materiali;
* sync state;
* pending upload.

Il logout **non deve automaticamente cancellare tutto**.

Deve semplicemente impedire che un altro account possa vedere quei dati.

L’utente potrà avere una funzione esplicita:

```text
Cancella dati offline
```

che invece elimina realmente i dati del suo profilo locale.

Per il guest abbiamo previsto che potrà esistere uno scope locale dedicato, molto probabilmente:

```text
user_id = 0
```

ma questo va formalizzato quando completeremo definitivamente Guest Mode.

---

# Requisiti non funzionali

Questi sono altrettanto importanti.

### Sicurezza

* HTTPS per tutte le comunicazioni.
* JWT/sessione non hardcoded.
* autorizzazione verificata dal backend, mai solo dalla UI;
* teacher verificati;
* owner/admin group controllati server-side;
* accesso ai file verificato prima del download;
* nessuna fiducia nel `user_id` inviato arbitrariamente dal client.

Google richiede esplicitamente che i dati personali/sensibili siano gestiti in sicurezza e trasmessi con crittografia moderna, come HTTPS. ([Google Help][1])

### Integrità

Per i materiali:

```text
SHA-256
```

è la fonte per verificare che il file ricevuto sia quello atteso.

### Offline first

Se la rete cade:

* materiali personali funzionano;
* materiali già scaricati funzionano;
* upload possono restare pending;
* metadata precedentemente sincronizzati possono essere mostrati.

### Error handling

Nella UI non dobbiamo mostrare:

```text
SocketException
HTTP 500
Null check operator...
```

ma messaggi come:

```text
Impossibile caricare il materiale.
Controlla la connessione e riprova.
```

I dettagli tecnici possono eventualmente andare nei log.

### Performance

Non dobbiamo:

* riscaricare file con hash già presente;
* caricare continuamente l’intero catalogo;
* duplicare file fisici;
* fare query non indicizzate sulle tabelle principali.

Per questo abbiamo:

```text
remote_key
file_hash
user_id
subject_id
group_id
source
```

indicizzati.

---

# Requisiti StudentLab più ampi collegati a questo blocco

Il sistema materiali non è isolato.

Dovrà collegarsi a:

### Profilo

* percorsi accademici multipli;
* materia;
* teacher assignments;
* materiali associati.

### Utenti

Studenti e teacher possono avere:

```text
Può aiutarti in
Lezioni private in
```

ma questo resta distinto dall’identità `teacher` verificata.

### Gruppi

Abbiamo stabilito:

* gruppi pubblici/privati;
* owner;
* admin;
* membri;
* richieste ingresso;
* materiali;
* feed news.

Per ora **chat disattivata**.

Il gruppo usa invece un feed di news.

---

# News/UGC e requisiti Store

Questo è particolarmente importante per Google Play e App Store.

StudentLab contiene UGC perché gli utenti possono creare:

* news;
* contenuti nei gruppi;
* materiali;
* profili;
* potenzialmente altri contenuti social.

Google considera UGC qualsiasi contenuto creato dagli utenti visibile anche solo a un sottoinsieme degli altri utenti. ([Google Help][2])

Quindi dobbiamo avere obbligatoriamente:

* segnalazione contenuto;
* segnalazione utente;
* blocco utente;
* moderazione;
* Terms of Use;
* accettazione dei termini prima di usare le funzionalità UGC;
* azioni tempestive sui contenuti segnalati. ([Google Help][2])

Questo conferma che le specifiche che abbiamo già deciso per:

```text
Segnala news
Segnala profilo
Owner modera news
Admin modera
Rimuovi contenuto
Sospendi autore
```

non sono soltanto funzionalità utili: aiutano direttamente la conformità Play Store.

Una cosa che dovremo aggiungere chiaramente è anche:

```text
Blocca utente
```

perché Google richiede sia reporting sia blocking nelle app UGC. ([Google Help][2])

---

# Registrazione e policy

Avevamo già deciso:

```text
Registrazione
    ↓
accettazione policy obbligatoria
    ↓
creazione account
    ↓
verifica email
```

e una pagina:

```text
Privacy / Policy / Termini
```

consultabile anche dal form.

Google richiede una privacy policy valida sia nello store sia all’interno dell’app e la dichiarazione delle pratiche nella sezione Data Safety. ([Google Help][1])

Apple richiede anch’essa una privacy policy accessibile nell’app e nei metadata App Store; deve descrivere dati raccolti, utilizzi, condivisioni, retention ed eliminazione. ([Apple Developer][3])

---

# Eliminazione account

Questa è una funzionalità che dobbiamo necessariamente implementare.

StudentLab consentirà la creazione account, quindi Google richiede:

```text
eliminazione account dentro l'app
+
risorsa web per richiedere eliminazione
```

e l’eliminazione deve comprendere i dati associati salvo obblighi legittimi di conservazione. ([Google Help][4])

Apple richiede che un’app che crea account permetta di **avviare l’eliminazione dall’app**, e la semplice disattivazione dell’account non basta. ([Apple Developer][5])

Per StudentLab quindi il menu profilo dovrà avere:

```text
Profilo
├── Modifica profilo
├── Policy e privacy
├── Segnala un problema
├── Logout
└── Elimina account
```

Questo era già nella nostra roadmap, quindi siamo sulla strada corretta.

---

# Apple Privacy Nutrition Label

Quando pubblicheremo StudentLab, dovremo dichiarare in App Store Connect i dati effettivamente raccolti.

Ad esempio probabilmente:

```text
Nome
Email
User ID
Contenuti utente
Dati accademici/profilo
Diagnostica
```

a seconda dell'implementazione finale.

Apple richiede di dichiarare anche i dati raccolti da SDK di terze parti integrati nell’app. ([Apple Developer][6])

Una cosa positiva della nostra architettura è che i dati mantenuti **soltanto sul dispositivo** e mai trasmessi al server generalmente non rientrano nella definizione Apple di dati “collected”. ([Apple Developer][6])

Questo è utile proprio per il Guest Mode e SQLite locale.

---

# Controllo età

Avevamo già previsto un controllo dell’età durante la registrazione.

Dovremo farlo bene perché StudentLab contiene componenti social/UGC.

Per ora non significa necessariamente impedire l’utilizzo a tutti i minorenni: significa definire:

```text
target audience
età minima
privacy
UGC
moderazione
```

prima della pubblicazione.

Questo lo affrontiamo più avanti insieme alla policy definitiva.

---

# Stato del lavoro oggi

Possiamo considerare:

```text
LOCAL STORAGE V6
████████████████████  compilabile
```

Abbiamo:

```text
✓ database v6
✓ migrations
✓ material_files
✓ materials
✓ material_downloads
✓ material_sync_state
✓ pending_uploads
✓ MaterialLocal
✓ MaterialFileLocal
✓ MaterialDownloadLocal
✓ MaterialSyncStateLocal
✓ MaterialRepository
✓ LocalFileService
✓ LocalMaterialImportService
✓ MaterialDownloadService
✓ MaterialCacheService compatibility
✓ MaterialSyncService
✓ PendingUploadService
✓ PendingUploadRepository
✓ LocalStorageService
✓ flutter analyze lib/local_storage → OK
```

Abbiamo inoltre iniziato il backend teacher materials:

```text
✓ teacher material
✓ teacher assignments service
✓ teacher assignment route
```

---

# Come proseguirei adesso

Io **non continuerei ad aggiungere tabelle SQLite**.

La base è sufficiente.

Passerei al collegamento reale.

Ordine consigliato:

```text
1. Backend sync manifest
       ↓
2. ApiService Flutter
       ↓
3. MaterialSyncService reale
       ↓
4. StudentMaterialPage
       ↓
5. OnlineSubjectMaterialPage
       ↓
6. StudyGroupDetailPage
       ↓
7. eliminazione adapter legacy
```

Il prossimo blocco tecnico quindi dovrebbe essere:

## `GET /materials/sync-manifest`

Perché è il pezzo che rende realmente utile tutta la struttura v6 appena costruita.

Dobbiamo verificare/costruire backend:

```text
BE/routes/material_sync.py
BE/services/material_sync.py
BE/schemas/material_sync.py
```

con risposta del tipo:

```json
{
  "generated_at": "...",
  "incremental": false,
  "visible_keys": [
    "public:12",
    "teacher:48",
    "group:31"
  ],
  "items": []
}
```

e soprattutto dobbiamo correggere i punti che avevamo già individuato:

```text
teacher privacy/access
group membership/access
tombstone
updated_at
UTC
created_at fallback
incremental since
```

Dopo questo, aggiungiamo a `ApiService`:

```dart
getMaterialSyncManifest()
```

e possiamo eliminare la chiamata HTTP manuale attualmente dentro `MaterialSyncService`.

**Questo è il passo che farei adesso.**

Mandami quindi per primo:

```text
BE/services/material_sync.py
```

se esiste già.

Se non esiste, lo costruiamo direttamente da zero sulle specifiche che abbiamo definito.

[1]: https://support.google.com/googleplay/android-developer/answer/10144311 "User Data - Play Console Help"
[2]: https://support.google.com/googleplay/android-developer/answer/12923286?hl=en&ref_topic=12798386 "Understanding moderation requirements and incidental sexual content in UGC apps - Play Console Help"
[3]: https://developer.apple.com/app-store/review/guidelines/?utm_source=chatgpt.com "App Review Guidelines - Apple Developer"
[4]: https://support.google.com/googleplay/android-developer/answer/13327111 "Understanding Google Play’s app account deletion requirements - Play Console Help"
[5]: https://developer.apple.com/support/offering-account-deletion-in-your-app?utm_source=chatgpt.com "Offering account deletion in your app - Support - Apple Developer"
[6]: https://developer.apple.com/app-store/app-privacy-details/?utm_source=chatgpt.com "App Privacy Details - App Store - Apple Developer"


stato dei flussi doc allegati 
Flutter
   │
   │ metadata + SHA-256
   ▼
POST /question-attachments/upload-request
   │
   │ autorizzazioni teacher/admin
   │ MIME / estensione / size / hash
   │ pathname sicuro
   ▼
POST /api/blob-upload
   │
   │ signed HTTPS upload
   ▼
Vercel Blob privato
   │
   │ upload diretto
   ▼
POST /question-attachments/complete
   │
   │ verifica pathname + metadata
   ▼
AttachmentRef
   │
   ▼
Question JSON