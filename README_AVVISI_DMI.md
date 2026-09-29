# Avvisi ufficiali DMI in StudentLab

Questo aggiornamento si applica **sopra** `studentlab_aggiornamento_pubblicazione.zip` già installato. Estrarre lo ZIP nella radice del progetto, sostituendo i file indicati. Non modifica le news create dagli utenti.

## Backend

1. Installare le dipendenze aggiornate: `pip install -r BE/requirements.txt`.
2. Eseguire sul PostgreSQL usato dal backend **una sola volta** `BE/migrations/manual/20260928_dmi_external_notices.sql` (per esempio con `psql "$DATABASE_URL" -f BE/migrations/manual/20260928_dmi_external_notices.sql`). Verificare di usare l'URL del database corretto prima del comando.
3. Impostare nel backend `STUDENTLAB_NOTICE_SYNC_TOKEN` a una stringa casuale lunga e segreta; effettuare il deploy del backend.
4. Ricompilare/rilasciare l'app Flutter dopo aver applicato i file `fe/`.

## Prima sincronizzazione e aggiornamento orario

Su una macchina che resta accesa e può raggiungere il DMI e il backend, impostare gli stessi token del backend e l'endpoint, quindi eseguire:

```bash
export STUDENTLAB_NOTICE_API_URL='https://dmi-student-lab.vercel.app/institutional-notices/sync'
export STUDENTLAB_NOTICE_SYNC_TOKEN='INSERISCI_IL_TOKEN_SEGRETO'
python3 BE/scripts/sync_dmi_notices.py
```

Per eseguirlo ogni ora, usare un processo pianificato sul server o un runner CI con accesso ai due siti. Esempio crontab (ambiente/variabili già impostati in modo sicuro sul server):

```cron
0 * * * * cd /percorso/assoluto/DMI-StudentLab && /percorso/assoluto/venv/bin/python BE/scripts/sync_dmi_notices.py >> /percorso/assoluto/dmi-sync.log 2>&1
```

Il piano Hobby di Vercel limita i cron a una volta al giorno: per l'aggiornamento orario utilizzare un runner esterno o un piano che consenta cron orari. Lo script, se non estrae avvisi, non svuota quelli già pubblicati; i record sono aggiornati tramite un ID stabile.

## Interfaccia

Nel feed, ciascun avviso ufficiale mostra titolo, DMI e ateneo, docente (se disponibile), data e anteprima. La pagina di dettaglio mostra il testo completo e in fondo la fonte e il pulsante per aprire l'originale. Gli avvisi sono limitati al contesto DMI Informatica L-31, esclusi i filtri per materia. La visibilità della pagina Istituzione segue le regole esistenti nell'app installata.
