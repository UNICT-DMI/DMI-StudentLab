# Correzioni StudentLab · Ripasso, domande e social

Applicare questo ZIP **dopo** `studentlab_aggiornamento_pubblicazione.zip` e `studentlab_avvisi_dmi.zip` senza cancellare altri file. I file sono completi e si sovrappongono ai percorsi indicati. Nessuna SQLite locale viene azzerata.

## Installazione

1. Estrarre lo ZIP dalla radice del progetto (`unzip -o studentlab_correzioni_ripasso_social.zip -d .`).
2. **Prima** del deploy backend, eseguire nel PostgreSQL di produzione `BE/migrations/manual/20260928_institutional_tutors.sql` (ad esempio `psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f BE/migrations/manual/20260928_institutional_tutors.sql`). Questo aggiunge una colonna con valore iniziale `none` e un indice, senza riscrivere gli account.
3. Eseguire `vercel --prod` dalla directory `BE` collegata al progetto backend. Ricompilare Flutter dalla directory `fe` e pubblicare il client quando il backend è attivo.

## Comportamento

- Home: **Esercitazioni**. Nella scelta della materia, **Esercitazione → Avvia quiz**. La flashcard non compare in quel flusso.
- Ripasso: il Quiz usa gli ID delle domande sbagliate presenti nello storico, fino a dieci. Se una domanda è stata rimossa o nascosta dal catalogo, non viene inserita nel nuovo quiz. Le Flashcard del Ripasso leggono testo, risposta corretta e spiegazione dallo storico locale: non richiedono che la materia abbia esercizi di tipo flashcard. Queste schede dello storico si sfogliano manualmente; la programmazione dilazionata della banca esercizi è separata.
- Editor domande: admin e creator possono modificare una domanda già presente nell'archivio quiz anche se la materia storica manca nel catalogo PostgreSQL. La validazione docente continua a richiedere la materia assegnata e verificata. Un ateneo mancante viene ricavato dal percorso DMI L31 quando applicabile.
- Contatti: il form invia l'oggetto come motivo dell'email StudentLab e nel testo inserisce nome del mittente, motivo e descrizione; al destinatario arriva anche una notifica nell'app. È attesa di cinque minuti tra due contatti alla stessa persona.
- Blocco: è personale, non invia segnalazioni all'admin, nasconde i profili in entrambe le direzioni per gli utenti autenticati e interrompe i contatti diretti; le news pubbliche e di gruppo degli utenti bloccati non compaiono nel feed personalizzato.
- Tutor: **Lezioni private** rimane disponibilità dichiarata senza verifica. **Tutoraggio UNICT** richiede una domanda dal proprio profilo, un percorso UNICT attivo e una decisione esplicita dal nuovo modulo *Tutor UNICT* nell'Admin Panel. Il pannello mostra ateneo, dipartimento, corso e stato di verifica del percorso per la valutazione dell'admin; l'approvazione del tutor non verifica automaticamente il percorso accademico. Lo stato del tutor viene fornito dal backend e abilita una voce distinta nel form Contatta. Il tutoraggio su una materia richiede che il tutor offra aiuto su quella materia.
- Durante una verifica accademica in sospeso (percorso, voto, ruolo docente o Tutor UNICT) il backend impedisce modifica di nome, cognome, password ed email; il client mostra un avviso giallo nella pagina di modifica del profilo o nella sicurezza account.

## Verifiche disponibili

I file Python compilano e gli schemi Pydantic delle nuove richieste sono stati validati. È stato verificato che il filtro del quiz selezioni solo gli ID richiesti ed escluda domande nascoste. In questo ambiente non è disponibile Flutter/Dart e non sono state eseguite build o prove con il PostgreSQL di produzione: eseguire il build Flutter locale prima di pubblicare.
