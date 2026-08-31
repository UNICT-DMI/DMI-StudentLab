per i dati di dipartimaneti già ci abbiamo penssato, invece per i dati dei json dobbiamo implementare che una teahcer o un admin può creare quest, o caricare json dei quest, possono modificare quest già esistenti, possono eliminare quest già esistenti o naascondere quest , li possono pure modificare, pre scegliere un quest anche un guest lo può fare, il form per scegliere il quest darà scelta del dipartimento (in futuro prima la città) dopo il corso, dopo la materia dopo gli argomenti, tra cui uno, più o tutti gli argomenti della materia, in fine siscegliera il numero delle domande da fare verrà impostato un massimo e si potra cambiare il valore con piu o meno oppure maualmente, se abbiamo già i valori si pùò scegliere anche un tempo, alla fine verrà salvata una scheda dello studente con tutti i dettagli dei quiz svolti così può apparire nell'area docente, e il docente può eliminare la scheda o nasconderla, con la scheda si può monitorare le lacune dello studente quindi tutti le domande degli argomenti delle materie cui ha sbagliato o risposto giusto e metterli in un'altra sezione per farlo ripassare, nell'area docente il teacher potrà assegnare a gruppi, uno o più studenti dei quiz con le specifiche come numero di domande tempo e quali domande , questi risultati appariranno in una sezione dedicata nell'area studenti 


Sì. Per costruire bene tutto il sistema quiz che abbiamo definito, eviterei di mettere tutto in `main.py`: conviene separare **banca domande, tentativi, assegnazioni, statistiche e guest locale**.

Partirei dal **backend**, perché frontend e SQLite guest dipenderanno dai contratti API e dai modelli dati.

## Struttura prevista

Nel backend aggiungerei questi file:

```text
BE/
├── models/
│   ├── question.py
│   ├── quiz_attempt.py
│   └── quiz_assignment.py
│
├── schemas/
│   ├── question.py
│   ├── quiz.py
│   ├── quiz_attempt.py
│   └── quiz_assignment.py
│
├── services/
│   ├── question_service.py
│   ├── quiz_service.py
│   ├── quiz_attempt_service.py
│   ├── quiz_assignment_service.py
│   └── quiz_statistics_service.py
│
├── routers/
│   ├── questions.py
│   ├── quizzes.py
│   ├── quiz_attempts.py
│   └── quiz_assignments.py
│
└── data/
    └── dmi/
        └── l-31/
            └── question/
                ├── programmazione_1.json
                ├── architettura_degli_elaboratori.json
                └── ...
```

Non creerei necessariamente un model separato per ogni piccola tabella: possiamo raggruppare quelle strettamente collegate nello stesso file.

---

# 1. `models/question.py`

Questo sarà il cuore della **banca domande server**.

Conterrà indicativamente:

```text
Question
QuestionOption
QuestionTeacher   (se necessario)
QuestionImport
```

`Question` avrà campi come:

```python
id
university
department_code
course_code
subject
argument

text
estimated_time

formal_explanation
informal_explanation

is_active
is_hidden

created_by
created_at
updated_at
deleted_at
```

Le opzioni invece:

```python
QuestionOption

id
question_id
option_key       # a, b, c, d
text
is_correct
explanation
```

Questa scelta è importante.

Nel JSON abbiamo:

```json
"question_response_explanation": {
    "a": "...",
    "b": "...",
    "c": "...",
    "d": "..."
}
```

Nel database possiamo salvarla direttamente sull'opzione:

```text
QuestionOption.explanation
```

Quindi ogni risposta sa già:

```text
testo
se è corretta
perché è corretta/sbagliata
```

Molto più pulito.

---

# 2. `schemas/question.py`

Qui mettiamo i modelli Pydantic per:

```text
creazione domanda
modifica domanda
lettura domanda
nascondi/riattiva
import JSON
risposta import
```

Per esempio:

```python
QuestionCreate
QuestionUpdate
QuestionResponse

QuestionOptionCreate
QuestionOptionResponse

QuestionVisibilityUpdate

QuestionImportRequest
QuestionImportResult
```

Il teacher potrebbe quindi inviare:

```json
{
    "argument": "Puntatori",
    "text": "Cosa contiene un puntatore?",
    "estimated_time": 15,
    "options": [...],
    "formal_explanation": "...",
    "informal_explanation": "..."
}
```

---

# 3. `services/question_service.py`

Qui deve stare la logica vera.

Per esempio:

```python
create_question()
update_question()
hide_question()
restore_question()
delete_question()

import_questions_from_json()

validate_question()
validate_options()

get_available_questions()
count_available_questions()
```

Questo è anche il posto giusto per controllare:

```text
esattamente una risposta corretta
nessuna opzione vuota
argomento valido
materia valida
teacher autorizzato
duplicati
JSON valido
```

---

# 4. `routers/questions.py`

Endpoint amministrativi/teacher.

Ad esempio:

```http
POST   /questions
PATCH  /questions/{question_id}
DELETE /questions/{question_id}

PATCH  /questions/{question_id}/visibility

POST   /questions/import
GET    /questions/manage
GET    /questions/{question_id}
```

Con permessi:

```text
guest       ❌
student     ❌
teacher     ✅
admin       ✅
```

per creazione/modifica.

La lettura per svolgere quiz sarà invece accessibile anche ai guest tramite gli endpoint quiz.

---

# 5. `schemas/quiz.py`

Questo descrive la **configurazione del quiz**.

Per esempio:

```python
QuizAvailabilityRequest
QuizAvailabilityResponse

QuizGenerateRequest
QuizGenerateResponse
```

Richiesta:

```json
{
    "department": "dmi",
    "course": "l-31",
    "subject": "Programmazione 1",
    "arguments": [
        "Array",
        "Puntatori"
    ],
    "question_count": 20,
    "time_limit_seconds": 1200
}
```

Se:

```json
"arguments": []
```

possiamo decidere che significhi:

```text
tutti gli argomenti
```

oppure usare esplicitamente:

```json
"all_arguments": true
```

Io preferisco il secondo perché è meno ambiguo.

---

# 6. `services/quiz_service.py`

Qui avremo:

```python
get_departments()
get_courses()
get_subjects()
get_arguments()

get_available_question_count()

generate_quiz()
shuffle_questions()
shuffle_options()
```

È questa parte che servirà al form Flutter.

Flusso:

```text
department
 ↓
course
 ↓
subject
 ↓
arguments
 ↓
available_count
 ↓
question_count
 ↓
time
 ↓
generate quiz
```

Il backend risponde per esempio:

```json
{
    "available_questions": 73,
    "max_questions": 73,
    "estimated_total_time": 1095
}
```

---

# 7. `routers/quizzes.py`

Endpoint utilizzabili anche dal **guest**:

```http
GET  /quiz/departments
GET  /quiz/courses
GET  /quiz/subjects
GET  /quiz/arguments

POST /quiz/availability
POST /quiz/generate
POST /quiz/validate
```

---

# 8. `models/quiz_attempt.py`

Questo registra ciò che lo studente ha fatto.

Metterei nello stesso file:

```python
QuizAttempt
QuizAttemptAnswer
```

### `QuizAttempt`

```text
id
user_id

subject
started_at
completed_at

question_count
correct_count
wrong_count
unanswered_count

time_limit_seconds
elapsed_seconds

is_hidden_from_history
hidden_from_history_at
hidden_from_history_by

created_at
```

### `QuizAttemptAnswer`

```text
id
attempt_id
question_id

argument

selected_option_id
correct_option_id

is_correct
is_answered

response_time_seconds
```

---

# 9. `schemas/quiz_attempt.py`

Avremo:

```python
QuizAttemptStart
QuizAttemptSubmit

QuizAnswerSubmit

QuizAttemptResponse
QuizAttemptDetailResponse
QuizAttemptHistoryResponse
```

---

# 10. `services/quiz_attempt_service.py`

Funzioni:

```python
start_attempt()
submit_answer()
complete_attempt()

get_student_history()

hide_from_history()
restore_to_history()

delete_attempt()
```

E qui applichiamo la regola che hai appena stabilito:

```python
is_hidden_from_history == True
```

significa:

> il quiz resta memorizzato, ma **non contribuisce allo storico e alle statistiche**.

---

# 11. `services/quiz_statistics_service.py`

Questo secondo me deve essere separato.

Calcola:

```text
precisione generale
precisione per materia
precisione per argomento

domande più sbagliate
domande più corrette

argomenti deboli
argomenti forti

andamento nel tempo
```

Sempre filtrando:

```python
QuizAttempt.is_hidden_from_history == False
```

Da qui nasce la sezione:

```text
Ripasso
```

Non serve inizialmente una tabella `Weakness`.

La lacuna viene calcolata dai dati reali.

---

# 12. `models/quiz_assignment.py`

Qui avremo almeno:

```text
QuizAssignment
QuizAssignmentRecipient
QuizAssignmentQuestion
QuizAssignmentArgument
```

### `QuizAssignment`

```text
id
teacher_id

title
description

subject

question_count
time_limit_seconds

selection_mode
created_at
due_at

is_active
```

`selection_mode` potrebbe essere:

```text
random
selected_questions
arguments
```

---

## Recipient

Serve per poter assegnare:

```text
uno studente
più studenti
un gruppo
```

Possiamo modellarlo con:

```python
QuizAssignmentRecipient
```

che contiene:

```text
assignment_id

user_id nullable
group_id nullable
```

---

# 13. `schemas/quiz_assignment.py`

Per esempio:

```python
QuizAssignmentCreate
QuizAssignmentUpdate
QuizAssignmentResponse

QuizAssignmentRecipientCreate

StudentAssignedQuizResponse
TeacherAssignmentResultResponse
```

---

# 14. `services/quiz_assignment_service.py`

Gestisce:

```python
create_assignment()

assign_to_student()
assign_to_students()
assign_to_group()

get_student_assignments()
get_teacher_assignments()

start_assignment()
complete_assignment()

get_assignment_results()
```

---

# 15. `routers/quiz_assignments.py`

Teacher:

```http
POST /quiz-assignments

PATCH /quiz-assignments/{id}

DELETE /quiz-assignments/{id}

GET /quiz-assignments/teacher
GET /quiz-assignments/{id}/results
```

Student:

```http
GET /quiz-assignments/student
GET /quiz-assignments/{id}
POST /quiz-assignments/{id}/start
```

---

# Guest / SQLite Flutter

Sul frontend aggiungerei poi:

```text
fe/lib/
└── quiz/
    ├── models/
    │   ├── quiz_attempt.dart
    │   └── quiz_attempt_answer.dart
    │
    ├── services/
    │   ├── quiz_api_service.dart
    │   ├── quiz_local_service.dart
    │   └── quiz_history_service.dart
    │
    ├── repositories/
    │   └── quiz_repository.dart
    │
    └── database/
        ├── quiz_database.dart
        └── quiz_database_tables.dart
```

SQLite avrà:

```text
guest_quiz_attempts
guest_quiz_attempt_answers
```

Il `QuizRepository` decide:

```dart
if (authenticated) {
  // FastAPI/PostgreSQL
} else {
  // SQLite
}
```

In questo modo la UI non deve sapere dove vengono memorizzati i dati.

---

# Frontend UI prevista

Successivamente:

```text
quiz/
├── pages/
│   ├── quiz_setup_page.dart
│   ├── quiz_page.dart
│   ├── quiz_result_page.dart
│   ├── quiz_history_page.dart
│   ├── quiz_review_page.dart
│   └── assigned_quizzes_page.dart
│
└── teacher/
    ├── question_bank_page.dart
    ├── question_editor_page.dart
    ├── question_import_page.dart
    ├── quiz_assignment_create_page.dart
    ├── quiz_assignments_page.dart
    └── student_quiz_results_page.dart
```

---

# Ordine in cui inizierei

Non creerei 25 file contemporaneamente.

Procederei così:

```text
FASE 1 — Question Bank
1. models/question.py
2. schemas/question.py
3. services/question_service.py
4. routers/questions.py

FASE 2 — Generazione quiz
5. schemas/quiz.py
6. services/quiz_service.py
7. routers/quizzes.py

FASE 3 — Storico
8. models/quiz_attempt.py
9. schemas/quiz_attempt.py
10. services/quiz_attempt_service.py
11. routers/quiz_attempts.py

FASE 4 — Lacune
12. services/quiz_statistics_service.py

FASE 5 — Assegnazioni
13. models/quiz_assignment.py
14. schemas/quiz_assignment.py
15. services/quiz_assignment_service.py
16. routers/quiz_assignments.py

FASE 6 — Flutter + SQLite guest
```

## Partiamo adesso

Il **primo file che costruirei è**:

```text
BE/models/question.py
```

perché tutti gli altri dipendono dalla struttura definitiva della domanda.

Lo imposterei già per supportare:

```text
teacher/admin create
JSON import
edit
hide
restore
delete
spiegazione formale
spiegazione informale
spiegazione per ogni opzione
argomento/capitolo
più teacher
tracciamento autore
```

Dopo `question.py`, passiamo direttamente a `schemas/question.py` e costruiamo il primo blocco completo del backend.
I due file che ti ho appena generato **non vanno tenuti con quei nomi “canonical”**: erano nomi temporanei per distinguere gli artefatti scaricabili. Nel progetto devi usarli come sostituzione completa dei service esistenti.

Quindi:

```text
BE/services/material.py
```

va sostituito con il contenuto di:

```text
services_material_canonical.py
```

e:

```text
BE/services/teacher_material.py
```

va sostituito con il contenuto di:

```text
services_teacher_material_canonical.py
```

Non devi quindi creare:

```text
BE/services/services_material_canonical.py
BE/services/services_teacher_material_canonical.py
```

Quelli sono solo i nomi dei file che ti ho consegnato.

Lo stesso principio vale per gli altri file che abbiamo prodotto durante questo blocco. La situazione corretta del progetto, a questo punto, dovrebbe essere questa:

```text
BE/
├── api/
│   └── blob-upload.ts
│
├── schemas/
│   ├── material.py
│   ├── teacher_material.py
│   └── question_attachment.py
│
├── services/
│   ├── material.py
│   ├── teacher_material.py
│   ├── question_attachment.py
│   └── upload_authorization.py
│
├── routes/
│   └── question_attachment.py
│
└── main.py
```

Mentre nel frontend abbiamo preparato:

```text
fe/lib/services/blob_upload_service.dart
```

con:

```dart
uploadGroupMaterial(...)
uploadTeacherMaterial(...)
uploadQuestionAttachment(...)
```

## Dove siamo arrivati nello sviluppo

Siamo ormai oltre la sola parte quiz. Abbiamo costruito buona parte dell'infrastruttura backend necessaria per gestire quiz, assegnazioni e materiali in modo serio.

Sul blocco **quiz** abbiamo già:

```text
Domande
├── lettura JSON
├── creazione
├── modifica
├── eliminazione
├── hide / restore
├── activate / deactivate
├── import JSON
└── allegati
```

Abbiamo poi:

```text
Quiz Assignment
├── docente → utenti
├── docente → gruppi
├── utenti + gruppi contemporaneamente
├── random
├── argomenti
├── domande selezionate
├── deadline
├── limite tempo
├── attivazione/disattivazione
├── riattivazione
└── notifiche
```

Per i tentativi:

```text
Quiz Attempt
├── quiz normale
├── quiz assegnato
├── una sola esecuzione assegnata per utente
├── snapshot della domanda
├── snapshot risposte
├── spiegazioni
├── storico
├── hide / restore
├── delete logico
└── completamento notifiche
```

E per le statistiche:

```text
Statistiche personali
├── overall
├── materia
├── argomento
├── domanda
├── argomenti deboli
├── review
└── profilo statistico
```

con accesso controllato alle statistiche degli altri studenti.

Poi siamo entrati nel blocco **upload privato**.

Ora abbiamo una struttura comune:

```text
Flutter
    ↓
FastAPI upload-request
    ↓
autorizzazione + pathname + upload_token
    ↓
Vercel /api/blob-upload
    ↓
FastAPI verify-upload
    ↓
presigned PUT
    ↓
Vercel Blob privato
    ↓
FastAPI complete
```

Ed è già stata pensata per:

```text
1. GroupMaterial
2. TeacherMaterial
3. QuestionAttachment
```

La cosa importante è che abbiamo eliminato il problema precedente dove una seconda chiamata poteva generare un UUID/pathname diverso.

Ora il token lega:

```text
utente
tipo upload
pathname
hash SHA-256
MIME
dimensione
risorsa
scadenza
```

Quindi il client non può chiedere:

> “Autorizzami A”

e poi caricare:

> “B”.

Abbiamo anche deciso correttamente che nel database:

```text
stored_name = pathname Blob privato
file_path   = pathname Blob privato
```

e **non** una presigned URL temporanea.

---

# Come integrerei la UI

Qui farei una distinzione importante.

Non farei una gigantesca pagina nuova chiamata, ad esempio, “Gestione Quiz”.

La funzionalità dovrebbe entrare naturalmente nella parte docente di StudentLab.

La struttura che vedo bene è:

```text
Home docente
    ↓
Strumenti docente
    ↓
Materia
    ↓
┌─────────────────────────────┐
│ Materiali                   │
│ Quiz / Domande              │
│ Assegna quiz                │
│ Risultati studenti          │
└─────────────────────────────┘
```

In particolare, per questo blocco appena sviluppato, farei una pagina:

# `Gestione domande`

Con AppBar tipo:

```text
← Programmazione 1                         ⋮
```

e sotto una toolbar:

```text
[ + Nuova domanda ]   [ Importa JSON ]
```

Poi elenco delle domande:

```text
┌─────────────────────────────────────────────┐
│ #12                                         │
│ Qual è la complessità di una ricerca...?   │
│                                             │
│ Fondamenti algoritmi                        │
│                                             │
│ 📎 2 allegati       ● Attiva               │
│                                             │
│ [Modifica] [⋮]                              │
└─────────────────────────────────────────────┘
```

Il menu `⋮` può contenere:

```text
Nascondi
Disattiva
Elimina
```

oppure, in base allo stato:

```text
Ripristina
Attiva
Elimina
```

## Creazione domanda

Premendo:

```text
+ Nuova domanda
```

aprirei una pagina/form dedicato, non un dialog piccolo.

Indicativamente:

```text
Nuova domanda

Argomento
[ Fondamenti del linguaggio C        ▼ ]

Testo domanda
┌───────────────────────────────────────┐
│ Quale delle seguenti...?             │
└───────────────────────────────────────┘

Risposte

A
[ .................................... ]

B
[ .................................... ]

C
[ .................................... ]

D
[ .................................... ]

Risposta corretta
(●) A   ( ) B   ( ) C   ( ) D

Spiegazione formale
[ .................................... ]

Spiegazione semplice
[ .................................... ]
```

Poi arriviamo al blocco che stiamo sviluppando adesso:

# Allegati

Lo farei così:

```text
Allegati

Puoi aggiungere immagini o documenti
alla domanda.

[ + Aggiungi allegato ]
```

Dopo l'upload:

```text
┌────────────────────────────────────┐
│ 🖼 diagramma_memoria.png           │
│ Immagine · 1.8 MB                  │
│                             ✕      │
└────────────────────────────────────┘

┌────────────────────────────────────┐
│ 📄 specifica.pdf                   │
│ PDF · 620 KB                       │
│                             ✕      │
└────────────────────────────────────┘
```

Questi non sarebbero ancora “salvati nella domanda” al momento della selezione.

Il flusso UI sarebbe:

```text
utente seleziona file
        ↓
spinner "Caricamento..."
        ↓
uploadQuestionAttachment()
        ↓
ritorna:
{
    id,
    type,
    original_name,
    mime_type,
    stored_name
}
        ↓
aggiungiamo l'oggetto a:
_pendingAttachments
        ↓
la UI mostra la card allegato
```

E alla pressione di:

```text
[ Salva domanda ]
```

mandiamo:

```json
{
  "text": "...",
  "option": [...],
  "id_correct": "a",
  "attachments": [
    {
      "id": "...",
      "type": "image",
      "original_name": "schema.png",
      "mime_type": "image/png",
      "stored_name": "questions/..."
    }
  ]
}
```

Quindi il file viene caricato **prima**, ma viene collegato semanticamente alla domanda quando salviamo la domanda.

---

# Creazione vs modifica domanda

Per una domanda già esistente è ancora più semplice.

Entrando in:

```text
Modifica domanda
```

mostriamo gli allegati già presenti:

```text
Allegati

🖼 schema_heap.png
📄 esercizio.pdf

[ + Aggiungi allegato ]
```

Quando aggiunge un file, il nostro metodo:

```dart
uploadQuestionAttachment(
    department: ...,
    course: ...,
    subject: ...,
    questionId: question.id,
    filePath: ...,
)
```

può già usare il vero `question_id`.

Per una domanda nuova invece:

```dart
questionId: null
```

e il backend salva temporaneamente sotto:

```text
questions/tmp/{user_id}/...
```

Qui c'è però un punto architetturale che dobbiamo completare.

Attualmente abbiamo previsto il percorso temporaneo, ma non abbiamo ancora realizzato il **move/promote del Blob da `questions/tmp/...` al percorso definitivo della domanda dopo la creazione**.

Questa è una delle prossime cose che farei prima di considerare gli allegati completamente chiusi.

Abbiamo due possibilità.

La prima:

```text
upload temporaneo
↓
crea domanda
↓
backend sposta/rinomina Blob
↓
aggiorna attachments con pathname definitivo
```

È la soluzione che preferisco.

Oppure possiamo lasciare permanentemente:

```text
questions/tmp/{user_id}/...
```

anche dopo il salvataggio, ma concettualmente sarebbe meno pulito.

Io sceglierei quindi la prima.

---

# Gestione errori UI

Evitiamo assolutamente errori tipo:

```text
Exception: ClientException...
SocketException...
HTTP 422...
```

La UI mostra messaggi tipo:

```text
File troppo grande.
```

```text
Questo formato non è supportato.
```

```text
Questo allegato non può essere caricato.
```

```text
La sessione di caricamento è scaduta.
Riprova.
```

```text
Non sei autorizzato a modificare questa materia.
```

Questo è importante anche in ottica Play Store/App Store.

---

# Upload UX

Durante l'upload userei una card provvisoria:

```text
┌─────────────────────────────────┐
│ 📄 esercizio.pdf                │
│ Caricamento...                  │
│ ███████████░░░░░░░              │
└─────────────────────────────────┘
```

Il nostro servizio oggi supporta streaming, ma **non espone ancora progress percentuale**.

Quindi inizialmente possiamo avere:

```text
CircularProgressIndicator
Caricamento...
```

e successivamente aggiungere callback:

```dart
onProgress(double progress)
```

al servizio Blob.

Non lo considero necessario per completare la funzionalità, ma è una buona rifinitura UX per file grandi.

---

# Come collegherei la parte quiz assegnati

Dalla stessa pagina materia:

```text
Programmazione 1

[ Domande ]
[ Quiz assegnati ]
[ Materiali ]
[ Statistiche ]
```

Dentro:

```text
Quiz assegnati
```

avremmo:

```text
+ Assegna quiz
```

Form:

```text
Titolo
[ Quiz Puntatori                    ]

Modalità
(●) Casuale
( ) Argomenti
( ) Domande specifiche

Numero domande
[ 10 ]

Tempo
[ 30 minuti ]

Destinatari
[ + Utenti ]
[ + Gruppi ]

Scadenza
[ 30 agosto 2026 · 23:59 ]

[ Assegna quiz ]
```

Gli utenti/gruppi scelti diventano chip:

```text
[ Mario Rossi × ]
[ Gruppo Programmazione 1 × ]
[ Anna Verdi × ]
```

Poi una lista:

```text
Quiz assegnati

┌────────────────────────────────┐
│ Puntatori e memoria            │
│ 10 domande · 30 min            │
│                                │
│ 24 destinatari                 │
│ Scade 30 ago                   │
│                                │
│ Attivo                         │
│                        [⋮]     │
└────────────────────────────────┘
```

Menu:

```text
Disattiva
Riattiva
Modifica
```

secondo le policy già implementate.

---

# Per lo studente

Dall'altra parte l'esperienza è molto diversa.

Quando riceve un quiz:

```text
🔔 Nuovo quiz assegnato

Programmazione 1
Puntatori e memoria
10 domande · 30 minuti
Scadenza: 30 agosto

[ Inizia quiz ]
```

L'assegnazione compare sia nelle notifiche sia nella sezione quiz.

Dopo il completamento:

```text
Completato ✓

8 / 10
80%
```

e la notifica passa automaticamente a `completed`, cosa che il backend già gestisce.

---

## In sintesi

Direi che siamo grosso modo qui:

```text
BACKEND QUIZ
████████████████████  ~90%

UPLOAD INFRASTRUCTURE
██████████████████░░  ~85%

FRONTEND QUIZ ATTUALE
████████░░░░░░░░░░░░  ~40%

NUOVA UI DOCENTE QUIZ
██░░░░░░░░░░░░░░░░░░  da costruire

UI ALLEGATI DOMANDA
██░░░░░░░░░░░░░░░░░░  service pronto, UI da costruire
```

Non prenderei queste percentuali come metriche matematiche, ma rendono bene lo stato: **la parte difficile di modello dati, permessi, sicurezza e lifecycle backend è ormai molto avanti; adesso entriamo nella fase in cui dobbiamo trasformarla in esperienza utente Flutter.**

Prima però farei ancora una piccola chiusura backend: **promozione degli allegati temporanei `questions/tmp/...` al pathname definitivo quando una nuova domanda viene salvata**. Dopodiché possiamo costruire la UI senza lasciarci dietro un comportamento provvisorio.
