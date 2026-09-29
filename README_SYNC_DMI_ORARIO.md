# Sincronizzazione oraria degli avvisi DMI

Questo ZIP aggiunge `.github/workflows/sync-dmi-notices-hourly.yml` al repository StudentLab. Richiede il backend degli avvisi DMI già pubblicato. Non contiene credenziali e non modifica i file dell'app.

## Installazione dalla radice del repository

```bash
unzip -o "$HOME/Downloads/studentlab_sync_dmi_orario.zip" -d .

# Copia il token già presente sul PC nei Secrets del repository, senza stampare il valore.
# Occorre essere autenticati su GitHub CLI: gh auth status
tr -d '\r\n' < "$HOME/.studentlab_dmi_sync_token" | gh secret set STUDENTLAB_NOTICE_SYNC_TOKEN -R FranzAmoroso/DMI-StudentLab

git add -- .github/workflows/sync-dmi-notices-hourly.yml README_SYNC_DMI_ORARIO.md
git diff --cached --name-only
git commit -m "Pianifica ogni ora la sincronizzazione degli avvisi DMI"
git push origin main

# Per repository fork, assicurati che il workflow non sia disabilitato.
gh workflow enable sync-dmi-notices-hourly.yml -R FranzAmoroso/DMI-StudentLab
gh workflow run sync-dmi-notices-hourly.yml -R FranzAmoroso/DMI-StudentLab --ref main
gh run list --workflow sync-dmi-notices-hourly.yml -R FranzAmoroso/DMI-StudentLab --limit 3
```

Se `gh` non è installato, aggiungi il token da GitHub → StudentLab → Settings → Secrets and variables → Actions → New repository secret; incollane il contenuto senza caratteri di fine riga. Dopo il push, avvia il workflow da Actions → Sincronizza avvisi DMI → Run workflow.

La pianificazione è `17 * * * *`: minuto 17 di ogni ora UTC (in Italia minuto 17 di ogni ora, inclusa l'ora legale). Il primo avvio manuale conferma token, accesso ai siti DMI e risposta del backend. I run programmati da GitHub possono subire ritardi. I workflow programmati dei fork possono essere inizialmente disabilitati e quelli dei repository pubblici inattivi per 60 giorni vengono disabilitati; controlla la scheda Actions se non vedi i run.

Lo scraper non elimina gli avvisi pubblicati quando una fonte non restituisce risultati; il backend aggiorna tramite ID stabile. L'avviso è visibile al client soltanto dopo la sincronizzazione e dopo la pubblicazione dell'app aggiornata.
