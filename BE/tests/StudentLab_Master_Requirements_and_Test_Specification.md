# StudentLab - Master Requirements & Test Specification

**Versione:** 2026-08-18

Questo documento è la sorgente di verità per requisiti funzionali, non funzionali, sicurezza, privacy, moderazione e store compliance di StudentLab. Ogni requisito deve essere collegato a uno o più test o a una verifica manuale di release.

## Regola Definition of Done

Un requisito è DONE solo quando: implementazione presente; test automatico passa se applicabile; test end-to-end passa; eventuale check manuale/store passa; documentazione e audit sono aggiornati.

## Matrice requisiti

### FR-AUTH-001 - Registrazione account
- Categoria: Auth
- Priorità: P1
- Requisito: L'utente può registrarsi come studente o docente con dati obbligatori validati lato server.
- Criterio di accettazione: Registrazione valida crea un account; input non valido restituisce errore user-friendly; nessun account parziale incoerente.
- Test: API integration + service unit

### FR-AUTH-002 - Login
- Categoria: Auth
- Priorità: P1
- Requisito: Login tramite email/password con password hash verificata e account attivo.
- Criterio di accettazione: Credenziali corrette restituiscono token; errate o account inattivo non autenticano.
- Test: API integration + security

### FR-AUTH-003 - Persistenza sessione
- Categoria: Auth
- Priorità: P1
- Requisito: La sessione autenticata deve sopravvivere alla navigazione e alla riapertura dell'app fino a scadenza/revoca.
- Criterio di accettazione: Riapertura app mantiene sessione valida; token scaduto/revocato forza nuovo login.
- Test: Flutter integration + API

### FR-AUTH-004 - Rimozione ID hardcoded
- Categoria: Auth
- Priorità: P1
- Requisito: Ogni operazione utente usa l'identità autenticata reale.
- Criterio di accettazione: Nessun `_currentUserId = 1` o equivalenti nel codice produttivo.
- Test: Static scan + integration

### FR-AUTH-005 - Logout
- Categoria: Auth
- Priorità: P1
- Requisito: Logout invalida la sessione locale e impedisce accessi successivi a contenuti protetti.
- Criterio di accettazione: Dopo logout le route protette richiedono nuova autenticazione.
- Test: Flutter integration + API

### FR-AUTH-006 - Recupero password
- Categoria: Auth
- Priorità: P1
- Requisito: L'utente può recuperare l'accesso senza supporto manuale.
- Criterio di accettazione: Token/codice di reset scade, è monouso e non rivela se email inesistente.
- Test: API integration + security

### FR-AUTH-007 - Verifica email
- Categoria: Auth
- Priorità: P1
- Requisito: Account nuovo resta non verificato finché il codice email non viene confermato.
- Criterio di accettazione: Codice corretto verifica; scaduto/errato/troppi tentativi falliscono; resend invalida il precedente.
- Test: API integration + Flutter

### FR-AUTH-008 - Controllo età
- Categoria: Auth
- Priorità: P1
- Requisito: La registrazione applica la policy d'età definita da StudentLab.
- Criterio di accettazione: Età non ammessa impedisce registrazione/social features secondo policy; stessa regola FE/BE.
- Test: API + Flutter + manual policy

### FR-POLICY-001 - Accettazione termini/privacy
- Categoria: Policy
- Priorità: P1
- Requisito: Prima della registrazione l'utente deve accettare la versione corrente di policy/termini.
- Criterio di accettazione: Consenso obbligatorio, versionato, timestampato e recuperabile per audit.
- Test: API + DB contract

### FR-PROFILE-001 - Profilo studente/docente
- Categoria: Profilo
- Priorità: P1
- Requisito: Il profilo mostra ruolo, descrizione, disponibilità, percorsi, titoli e dati social applicabili.
- Criterio di accettazione: Proprio profilo e profilo altrui rispettano visibilità e privacy.
- Test: Flutter widget + API

### FR-PROFILE-002 - Percorsi accademici multipli
- Categoria: Profilo
- Priorità: P1
- Requisito: Un utente può mantenere più percorsi accademici, con current/primary/status.
- Criterio di accettazione: CRUD corretto; nessuna perdita di dati; graduated resta distinguibile.
- Test: API + DB + Flutter

### FR-PROFILE-003 - Titoli accademici multipli
- Categoria: Profilo
- Priorità: P1
- Requisito: Titoli conseguiti sono entità distinte e verificabili.
- Criterio di accettazione: Titolo dichiarato può essere pending/verified/rejected; nessun duplicato visuale con percorso graduated equivalente.
- Test: API + DB + Flutter

### FR-GRADE-001 - Materia senza voto
- Categoria: Studente
- Priorità: P1
- Requisito: Associare una materia senza voto non richiede verifica.
- Criterio di accettazione: grade=NULL implica grade_status=none; materia può essere visibile senza badge di verifica.
- Test: Unit + API + Flutter

### FR-GRADE-002 - Voto dichiarato
- Categoria: Studente
- Priorità: P1
- Requisito: Un voto inserito richiede verifica manuale.
- Criterio di accettazione: Nuovo voto imposta pending; pubblico solo se verified.
- Test: Unit + API + Flutter

### FR-GRADE-003 - Modifica voto
- Categoria: Studente
- Priorità: P1
- Requisito: Modificare un voto verificato invalida la verifica precedente.
- Criterio di accettazione: Cambio valore resetta verifier/timestamp e torna pending.
- Test: Unit + API

### FR-GRADE-004 - Rimozione voto
- Categoria: Studente
- Priorità: P1
- Requisito: Rimuovere il voto elimina la necessità di verifica.
- Criterio di accettazione: grade=NULL e grade_status=none; verifier/timestamp null.
- Test: Unit + API

### FR-GRADE-005 - Visibilità voto
- Categoria: Studente
- Priorità: P1
- Requisito: Pending/rejected non sono pubblici; il proprietario vede lo stato.
- Criterio di accettazione: Card/profilo altrui mostra solo verified; proprio profilo mostra stato completo.
- Test: Flutter widget + API serialization

### FR-SOCIAL-001 - Ricerca utenti
- Categoria: Social
- Priorità: P1
- Requisito: Ricerca e filtri permettono di trovare studenti/docenti compatibili.
- Criterio di accettazione: Paginazione, filtri e privacy funzionano; sospesi/bloccati esclusi.
- Test: API + Flutter + performance

### FR-SOCIAL-002 - Aiuto e lezioni private
- Categoria: Social
- Priorità: P1
- Requisito: Utenti possono dichiarare materie per aiuto e/o lezioni private.
- Criterio di accettazione: Filtri e card riflettono i flag senza conferire qualifiche non verificate.
- Test: API + Flutter

### FR-SOCIAL-003 - Recensioni
- Categoria: Social
- Priorità: P1
- Requisito: Le recensioni devono essere associate a utenti reali e moderabili.
- Criterio di accettazione: Niente self-review se vietata; rate limit/anti-abuso; report disponibile.
- Test: API + moderation

### FR-SOCIAL-004 - Segnalazione profilo
- Categoria: Social
- Priorità: P1
- Requisito: Un utente può segnalare un altro profilo.
- Criterio di accettazione: Non può auto-segnalarsi; report registrato e visibile ad Admin.
- Test: API + Admin

### FR-SOCIAL-005 - Blocco utente
- Categoria: Social
- Priorità: P0
- Requisito: Gli utenti possono bloccare utenti abusivi.
- Criterio di accettazione: Blocco influenza profili, ricerca, chat/DM e interazioni applicabili.
- Test: API + Flutter integration

### FR-TEACHER-001 - Verifica docente
- Categoria: Docente
- Priorità: P1
- Requisito: Registrarsi come teacher non attribuisce automaticamente stato verificato.
- Criterio di accettazione: Teacher pending/rejected non usa strumenti riservati; Admin può approvare/rifiutare.
- Test: API authorization + Admin

### FR-TEACHER-002 - Teacher assignments
- Categoria: Docente
- Priorità: P1
- Requisito: Gli insegnamenti dichiarati/assegnati sono verificabili e legati a subject/offering.
- Criterio di accettazione: Solo assignment verificato abilita operazioni riservate su quella materia/offering.
- Test: API + DB + authorization

### FR-TEACHER-003 - Area docente
- Categoria: Docente
- Priorità: P1
- Requisito: Teacher verificato dispone di dashboard e strumenti dedicati.
- Criterio di accettazione: Accesso negato a non teacher/non verified; dati limitati ai suoi insegnamenti.
- Test: Flutter + API authorization

### FR-MAT-001 - Upload sicuro
- Categoria: Materiali
- Priorità: P1
- Requisito: Upload usa storage esterno, presign e autorizzazione backend.
- Criterio di accettazione: Dimensione/MIME/hash/path validati; file non memorizzato come blob PostgreSQL.
- Test: API integration + storage E2E

### FR-MAT-002 - Deduplicazione
- Categoria: Materiali
- Priorità: P1
- Requisito: Duplicati sono rilevati tramite SHA-256 lato backend.
- Criterio di accettazione: Stesso hash nel medesimo scope viene rifiutato/riusato secondo regola.
- Test: Unit + API

### FR-MAT-003 - Catalogo nel form materiali
- Categoria: Materiali
- Priorità: P1
- Requisito: Form usa catalogo comune università→dipartimento→corso→materia→offering.
- Criterio di accettazione: Nuovi dati importati nel DB appaiono senza liste hardcoded nel client.
- Test: API contract + Flutter integration

### FR-MAT-004 - Assegnazione docente→studente
- Categoria: Materiali
- Priorità: P1
- Requisito: Teacher autorizzato può assegnare materiale a destinatari ammessi.
- Criterio di accettazione: Backend verifica teacher, assignment e destinatari; crea notifica e audit.
- Test: API + authorization + notification

### FR-MAT-005 - Ricezione studente
- Categoria: Materiali
- Priorità: P1
- Requisito: Studente vede materiali assegnati e stato remoto/locale.
- Criterio di accettazione: Distinzione assigned/downloaded/synced/revoked; accesso solo autorizzato.
- Test: API + Flutter integration

### FR-MAT-006 - Offline materiali
- Categoria: Materiali
- Priorità: P1
- Requisito: Materiali scaricati restano disponibili offline secondo policy.
- Criterio di accettazione: Riapertura offline legge file locale e metadati SQLite; revoca gestita alla risincronizzazione.
- Test: Flutter integration/device

### FR-GROUP-001 - Lista/creazione gruppo
- Categoria: Gruppi
- Priorità: P1
- Requisito: Utente autenticato può visualizzare/creare gruppi secondo permessi.
- Criterio di accettazione: Public/private corretti; dati validati; owner creato correttamente.
- Test: API + Flutter

### FR-GROUP-002 - Join request
- Categoria: Gruppi
- Priorità: P1
- Requisito: Gruppi privati supportano richiesta, accettazione e rifiuto.
- Criterio di accettazione: Solo owner/admin decide; stati idempotenti e notificati.
- Test: API + notifications

### FR-GROUP-003 - Ruoli owner/admin/membro
- Categoria: Gruppi
- Priorità: P1
- Requisito: Permessi differenziati sulle operazioni sensibili.
- Criterio di accettazione: Membro non può compiere azioni owner/admin.
- Test: Authorization tests

### FR-GROUP-004 - Owner transfer
- Categoria: Gruppi
- Priorità: P1
- Requisito: Owner propone successore; candidato accetta/rifiuta; timeout definito.
- Criterio di accettazione: Trasferimento atomico; rifiuto/timeout gestiti; nessun gruppo senza owner salvo eliminazione prevista.
- Test: API + scheduled/integration

### FR-GROUP-005 - Chat
- Categoria: Gruppi
- Priorità: P1
- Requisito: Membri autorizzati possono chattare; messaggi sono moderabili.
- Criterio di accettazione: Non membro escluso; rate limit; report/delete secondo ruolo.
- Test: WebSocket integration + moderation

### FR-GROUP-006 - Materiali gruppo
- Categoria: Gruppi
- Priorità: P1
- Requisito: Materiali gruppo rispettano membership e permessi.
- Criterio di accettazione: Upload/download negati a utenti non autorizzati; hash duplicati gestiti.
- Test: API + storage

### FR-GROUP-007 - Segnalazioni gruppo/contenuto
- Categoria: Gruppi
- Priorità: P1
- Requisito: Utente può segnalare gruppo, messaggio/contenuto/materiale applicabile.
- Criterio di accettazione: Report arriva a coda Admin con reporter, target, motivo, timestamp.
- Test: API + Admin

### FR-NOTIF-001 - Badge unread
- Categoria: Notifiche
- Priorità: P1
- Requisito: Navbar autenticata mostra notifiche non lette.
- Criterio di accettazione: Unread count coerente con DB e si aggiorna dopo mark-read/read-all.
- Test: API + Flutter

### FR-NOTIF-002 - Eventi applicativi
- Categoria: Notifiche
- Priorità: P1
- Requisito: Verifiche, gruppi, materiali e moderation generano notifiche pertinenti.
- Criterio di accettazione: Ogni evento previsto crea una sola notifica idempotente.
- Test: Integration

### FR-ADMIN-001 - Accesso Admin
- Categoria: Admin
- Priorità: P0
- Requisito: Solo creator/admin o ruoli esplicitamente autorizzati accedono.
- Criterio di accettazione: Student/teacher normale riceve 403; admin entra.
- Test: Authorization tests

### FR-ADMIN-002 - Verifica voti
- Categoria: Admin
- Priorità: P1
- Requisito: Admin vede pending e approva/rifiuta.
- Criterio di accettazione: Decisione salva reviewer/timestamp/reason e notifica studente.
- Test: API + audit

### FR-ADMIN-003 - Verifica titoli/percorsi
- Categoria: Admin
- Priorità: P1
- Requisito: Admin verifica dichiarazioni accademiche.
- Criterio di accettazione: Stati coerenti, audit e visibilità pubblica solo se verified.
- Test: API + audit

### FR-ADMIN-004 - Verifica teacher/assignment
- Categoria: Admin
- Priorità: P1
- Requisito: Admin approva teacher e relativi insegnamenti.
- Criterio di accettazione: Permessi cambiano solo dopo verifica server-side.
- Test: API authorization

### FR-ADMIN-005 - Moderazione
- Categoria: Admin
- Priorità: P0
- Requisito: Admin gestisce segnalazioni di profili, gruppi, contenuti e materiali.
- Criterio di accettazione: Coda, decisione, motivo, reviewer, timestamp, sospensione/ban ove previsto.
- Test: API + UI + audit

### FR-ADMIN-006 - Gestione catalogo
- Categoria: Admin
- Priorità: P1
- Requisito: Admin può gestire/importare catalogo accademico.
- Criterio di accettazione: CRUD/import non produce duplicati e usa codici stabili.
- Test: API + DB + migration

### FR-ACCOUNT-001 - Cancellazione account in-app
- Categoria: Account
- Priorità: P0
- Requisito: Utente può iniziare la cancellazione dal prodotto.
- Criterio di accettazione: Conferma, eventuale re-auth, revoca sessioni, cleanup/anonymization coerenti.
- Test: API + Flutter + E2E

### FR-ACCOUNT-002 - Gestione dipendenze cancellazione
- Categoria: Account
- Priorità: P1
- Requisito: Cancellazione gestisce gruppi, ownership, contenuti e dati correlati.
- Criterio di accettazione: Nessun FK rotto; dati trattenuti solo se policy/legge lo richiede.
- Test: DB integration + manual privacy

### FR-CATALOG-001 - Catalogo dinamico
- Categoria: Catalogo
- Priorità: P1
- Requisito: Catalogo accademico è sorgente comune FE/BE.
- Criterio di accettazione: 7+ cataloghi importabili; nuovi JSON riconosciuti; question/ esclusa.
- Test: Importer integration

### FR-CATALOG-002 - Identità stabile materie
- Categoria: Catalogo
- Priorità: P1
- Requisito: Materia identificata tramite codici stabili, non solo nomi.
- Criterio di accettazione: Unique constraint e lookup allineati a university/department/course/subject code.
- Test: DB migration + duplicate test

### FR-QUIZ-001 - Esercitazione e simulazione
- Categoria: Quiz
- Priorità: P1
- Requisito: Quiz carica domande filtrate e restituisce risultato/spiegazioni.
- Criterio di accettazione: Nessuna risposta corretta esposta prima della validazione; risultati coerenti.
- Test: API + Flutter

### FR-QUIZ-002 - Argomenti multipli
- Categoria: Quiz
- Priorità: P1
- Requisito: Utente può selezionare più argomenti dove previsto.
- Criterio di accettazione: Filtro server/client produce solo domande coerenti.
- Test: API + Flutter

### NFR-SEC-001 - Autorizzazione server-side
- Categoria: Sicurezza
- Priorità: P0
- Requisito: Il client non è fonte di fiducia per ruoli, ownership o verifiche.
- Criterio di accettazione: Ogni endpoint sensibile controlla current user e permission.
- Test: Route contract + negative API tests

### NFR-SEC-002 - Password e token
- Categoria: Sicurezza
- Priorità: P1
- Requisito: Password mai in chiaro; token con scadenza e secret sicuro.
- Criterio di accettazione: Hash robusto, JWT verificato, secret non hardcoded nel repo.
- Test: Unit + secret scan

### NFR-SEC-003 - Rate limiting
- Categoria: Sicurezza
- Priorità: P1
- Requisito: Endpoint abusabili sono limitati.
- Criterio di accettazione: Login, email code, report, chat, upload e azioni sensibili resistono a burst.
- Test: Load/security test

### NFR-SEC-004 - Upload validation
- Categoria: Sicurezza
- Priorità: P1
- Requisito: Upload valida size, MIME/content, hash e pathname.
- Criterio di accettazione: Bypass MIME/estensione/path traversal falliscono.
- Test: Security integration

### NFR-SEC-005 - CORS
- Categoria: Sicurezza
- Priorità: P1
- Requisito: Configurazione CORS non espone credenziali a origini arbitrarie.
- Criterio di accettazione: Niente wildcard con credentials; origini prod esplicite.
- Test: Static/config test

### NFR-PRIV-001 - Data minimization
- Categoria: Privacy
- Priorità: P1
- Requisito: Si raccolgono solo dati necessari alle funzioni dichiarate.
- Criterio di accettazione: Inventario dati documentato; campi inutilizzati rimossi.
- Test: Manual audit + schema review

### NFR-PRIV-002 - Consenso versionato
- Categoria: Privacy
- Priorità: P1
- Requisito: Privacy/Terms acceptance è tracciabile e aggiornata.
- Criterio di accettazione: Versione, timestamp e consensi persistiti.
- Test: DB/API

### NFR-PRIV-003 - Retention e cancellazione
- Categoria: Privacy
- Priorità: P1
- Requisito: Ogni categoria dati ha retention/cancellazione definita.
- Criterio di accettazione: Delete account produce esito coerente con retention policy.
- Test: E2E + manual

### NFR-UX-001 - Errori user-friendly
- Categoria: UX
- Priorità: P1
- Requisito: Nessun traceback/HTTP/raw exception mostrato all'utente.
- Criterio di accettazione: Static scan + widget tests per error mapping.
- Test: Static + Flutter

### NFR-UX-002 - Responsive
- Categoria: UX
- Priorità: P1
- Requisito: UI non va in overflow su telefoni/tablet/desktop supportati.
- Criterio di accettazione: Golden/widget test su viewport e text scale.
- Test: Flutter widget/golden

### NFR-A11Y-001 - Semantics e screen reader
- Categoria: Accessibilità
- Priorità: P1
- Requisito: Controlli importanti hanno label/semantics.
- Criterio di accettazione: TalkBack/VoiceOver possono navigare le funzioni chiave.
- Test: Flutter semantics + manual device

### NFR-A11Y-002 - Text scaling e touch targets
- Categoria: Accessibilità
- Priorità: P1
- Requisito: UI regge font grandi e target interattivi adeguati.
- Criterio di accettazione: Nessun overflow a textScale elevato; touch target verificati.
- Test: Flutter widget + manual

### NFR-PERF-001 - Paginazione
- Categoria: Performance
- Priorità: P1
- Requisito: Liste social/gruppi/materiali non caricano dataset interi.
- Criterio di accettazione: Endpoint paginati; client lazy load.
- Test: API + load

### NFR-PERF-002 - Query efficienti
- Categoria: Performance
- Priorità: P1
- Requisito: Evitare N+1 e query superflue.
- Criterio di accettazione: Budget query/latency per endpoint chiave.
- Test: SQL instrumentation + load

### NFR-REL-001 - Timeout/retry
- Categoria: Affidabilità
- Priorità: P1
- Requisito: Rete lenta/fallita non blocca indefinitamente UI.
- Criterio di accettazione: Timeout configurati, retry solo dove sicuro/idempotente.
- Test: Integration chaos

### NFR-REL-002 - Idempotenza
- Categoria: Affidabilità
- Priorità: P1
- Requisito: Operazioni ripetute non duplicano dati sensibili.
- Criterio di accettazione: Retry upload/import/notification/assignment non duplica.
- Test: API integration

### NFR-DATA-001 - Migrazioni
- Categoria: Dati
- Priorità: P1
- Requisito: Schema modificato tramite migrazioni riproducibili.
- Criterio di accettazione: DB nuovo raggiunge stesso schema; rollback strategia documentata.
- Test: Migration CI

### NFR-DATA-002 - Backup/restore
- Categoria: Dati
- Priorità: P1
- Requisito: PostgreSQL e metadata critici hanno processo di backup/restore.
- Criterio di accettazione: Restore test periodico riuscito.
- Test: Operational manual/test

### NFR-OFFLINE-001 - Coerenza cache
- Categoria: Offline
- Priorità: P1
- Requisito: SQLite/cache distingue remoto, locale, stale e revoked.
- Criterio di accettazione: Sync deterministico e conflitti gestiti.
- Test: Flutter integration

### NFR-OBS-001 - Logging sicuro
- Categoria: Osservabilità
- Priorità: P1
- Requisito: Log tecnici utili senza password/token/dati eccessivi.
- Criterio di accettazione: Secret/PII redaction; livelli log prod corretti.
- Test: Static + runtime audit

### NFR-OBS-002 - Health/monitoring
- Categoria: Osservabilità
- Priorità: P1
- Requisito: Backend espone health e metriche minime.
- Criterio di accettazione: Alert su error rate/DB/storage definiti.
- Test: Integration + ops

### NFR-TEST-001 - CI requirements-driven
- Categoria: Qualità
- Priorità: P1
- Requisito: Ogni requisito automatizzabile è coperto e gira in CI.
- Criterio di accettazione: PR fallisce se un requisito critico regredisce.
- Test: CI

### NFR-TEST-002 - Test E2E release
- Categoria: Qualità
- Priorità: P1
- Requisito: Flussi chiave sono provati su Android/iOS reali.
- Criterio di accettazione: Registrazione→social→materiale→delete account completati senza crash.
- Test: Device E2E

### STORE-GP-001 - Account deletion
- Categoria: Google Play
- Priorità: P0
- Requisito: App con creazione account deve offrire percorso in-app e risorsa web per richiesta cancellazione account/dati.
- Criterio di accettazione: Entrambi i percorsi funzionano e Data Safety è coerente.
- Test: E2E + public URL check + Play checklist

### STORE-GP-002 - UGC moderation
- Categoria: Google Play
- Priorità: P0
- Requisito: UGC richiede termini/policy, moderazione, report in-app e block dove applicabile.
- Criterio di accettazione: Report utenti/contenuti e block funzionano; azioni moderation documentate.
- Test: E2E + Admin + policy checklist

### STORE-GP-003 - Child safety standards
- Categoria: Google Play
- Priorità: P0
- Requisito: App social deve avere standard pubblici contro CSAE, meccanismo report, processo CSAM/legal compliance e child-safety contact.
- Criterio di accettazione: Documenti pubblici e processi operativi verificati prima release.
- Test: Manual legal/ops + in-app tests

### STORE-GP-004 - Data Safety
- Categoria: Google Play
- Priorità: P0
- Requisito: Dichiarazioni Play devono riflettere dati raccolti/condivisi e pratiche reali.
- Criterio di accettazione: Inventario SDK/dati corrisponde al form pubblicato.
- Test: Manual release audit

### STORE-GP-005 - Target API
- Categoria: Google Play
- Priorità: P0
- Requisito: App rispetta il requisito target API applicabile alla release.
- Criterio di accettazione: Build release target conforme alla scadenza Play corrente.
- Test: Build/CI + release checklist

### STORE-GP-006 - Permessi sensibili
- Categoria: Google Play
- Priorità: P1
- Requisito: Permessi/API sensibili richiesti solo se necessari e per finalità dichiarate.
- Criterio di accettazione: Manifest e runtime permission audit senza permessi superflui.
- Test: Static manifest + manual

### STORE-APPLE-001 - Account deletion
- Categoria: App Store
- Priorità: P0
- Requisito: App che crea account permette di iniziare cancellazione direttamente nell'app.
- Criterio di accettazione: Flusso accessibile, comprensibile e cancella account/dati non legalmente trattenuti.
- Test: E2E + review checklist

### STORE-APPLE-002 - UGC guideline 1.2
- Categoria: App Store
- Priorità: P0
- Requisito: UGC/social richiede filtering, report, risposta tempestiva, block e contatto pubblico.
- Criterio di accettazione: Tutti i meccanismi disponibili e moderation operativa.
- Test: E2E + manual moderation

### STORE-APPLE-003 - App Privacy
- Categoria: App Store
- Priorità: P0
- Requisito: App Store Connect descrive accuratamente dati raccolti dall'app e terze parti.
- Criterio di accettazione: Privacy labels aggiornate a codice/SDK effettivi.
- Test: Manual release audit

### STORE-APPLE-004 - Social capabilities disclosure
- Categoria: App Store
- Priorità: P0
- Requisito: Dalle submission interessate, dichiarare correttamente le social capabilities.
- Criterio di accettazione: Metadati App Store Connect coerenti con profili/gruppi/chat/UGC.
- Test: Manual release checklist

### STORE-APPLE-005 - Age rating
- Categoria: App Store
- Priorità: P0
- Requisito: UGC/social e altre capability sono dichiarate nel questionario rating.
- Criterio di accettazione: Rating e declared age range coerenti con prodotto.
- Test: Manual release checklist

## Fonti ufficiali store

- Google Play - Account deletion: https://support.google.com/googleplay/android-developer/answer/13327111
- Google Play - User-generated content: https://support.google.com/googleplay/android-developer/answer/9876937
- Google Play - Child endangerment / child safety standards: https://support.google.com/googleplay/android-developer/answer/9878809
- Google Play - Data Safety: https://support.google.com/googleplay/android-developer/answer/10787469
- Google Play - July 15 2026 policy announcement / target API reminder: https://support.google.com/googleplay/android-developer/answer/17134731
- Apple - App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Apple - Offering account deletion in your app: https://developer.apple.com/support/offering-account-deletion-in-your-app/
- Apple - App Privacy Details: https://developer.apple.com/app-store/app-privacy-details/
- Apple - WWDC26 App Store guide: https://developer.apple.com/wwdc26/guides/app-store/