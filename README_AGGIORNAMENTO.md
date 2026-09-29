# StudentLab · aggiornamento UI per la pubblicazione

Questo pacchetto contiene i file completi modificati, con percorsi relativi alla radice del repository. Prima di copiarli, conserva una copia del tuo progetto; quindi estrai l'archivio nella cartella `DMI-StudentLab` e sovrascrivi i file corrispondenti.

Modifiche incluse:

- Tema Kiwi predefinito su nuove installazioni; le scelte di tema già salvate restano valide.
- Home Allenati, Quiz e Flashcard nelle esercitazioni, catalogo Esercizi nascosto ma conservato nel sorgente; Flashcard per gli argomenti da rafforzare nel Ripasso.
- Istituzione e menu Gruppi visibili soltanto ai creator; Colleghi disponibile con filtri di corso, dipartimento e ateneo.
- Directory tutor con categorie visibili `Docenti verificati` e `Tutor privati`. Il riconoscimento specifico di tutor istituzionale richiede ancora un dato verificato nel backend e non viene attribuito automaticamente.
- Dispense: le azioni di richiesta aprono il form con materia, argomento facoltativo e descrizione; il controllo dei materiali esistenti usa argomento e descrizione. Pubblica apre il form già presente.
- Richieste: rimossa la card delle azioni in alto, pulsante in basso, stati filtrabili e colorati; materia e destinatario inclusi nelle risposte API.
- Calendario: riepilogo 2026/27 per Università di Catania, basato sulle date fornite, con estremi inclusi. Il riepilogo è informativo e non genera eventi o promemoria sul server.
- Modifica domanda: per creator/admin, ateneo ricavato dalla materia del catalogo quando manca nei metadati storici. La verifica delle assegnazioni dei docenti rimane nel backend.

Non sono state modificate tabelle, versioni o migrazioni SQLite: le dispense offline esistenti non vengono azzerate.

Verifica eseguita: compilazione sintattica dei moduli Python modificati e validazione Pydantic delle risposte delle richieste. Flutter e le dipendenze FastAPI/SQLAlchemy non sono disponibili nell'ambiente di produzione del pacchetto: prima del rilascio esegui nel tuo progetto `flutter pub get`, `flutter analyze`, `flutter test` e il build di destinazione; verifica inoltre le API dopo il deploy del backend.
