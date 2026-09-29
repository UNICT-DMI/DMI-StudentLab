# StudentLab · avvisi, ripasso e verifiche

Questo pacchetto si estrae nella radice del repository già aggiornato con gli avvisi DMI e il tutoraggio UNICT. Comprende file `BE/` e `fe/` e la pianificazione oraria degli avvisi DMI. Non modifica direttamente il database e non include segreti.

## Installazione

```bash
cd ~/FranzAmoroso1/projects/DMI-StudentLab
unzip -o "$HOME/Downloads/studentlab_avvisi_ripasso_verifiche.zip" -d .
```

Prima di fare la migrazione, controllare che `DATABASE_URL` punti davvero al PostgreSQL usato dal backend di produzione (il nome `neondb` da solo non basta). Verificare `alembic current` e le revisioni disponibili:

```bash
cd BE
alembic current
alembic heads
# Solo sul database di produzione verificato, dopo backup:
alembic upgrade head
```

La nuova revisione Alembic `b943student_verification` aggiunge lo stato della verifica studente. Presuppone che il database sia compatibile con le migrazioni precedenti; se `alembic current` non riflette le modifiche manuali già eseguite o esistono revisioni non applicate, non usare `stamp` alla cieca: risolvere lo storico della migrazione prima del deploy. Non inserire `DATABASE_URL` o token nei commit.

Per distribuire il backend tramite il collegamento GitHub → Vercel (senza `vercel --prod` dal PC):

```bash
cd ..
git add -- BE/main.py BE/models/user.py BE/routes/student_verifications.py \
  BE/schemas/user.py BE/services/user.py BE/services/verification_lock.py \
  BE/alembic/versions/b943student_verification.py \
  fe/lib/calendar/calendar_home_page.dart fe/lib/layers/homeLayer.dart \
  fe/lib/local_storage/database/app_database.dart \
  fe/lib/local_storage/database/database_migrations.dart \
  fe/lib/local_storage/repositories/study_plan_local_repository.dart \
  fe/lib/quiz/review/review_quiz_page.dart \
  fe/lib/quiz/review/student_quiz_review_page.dart fe/lib/quiz/subjectSelection.dart \
  fe/lib/services/api_service.dart fe/lib/social/admin/admin_panel_page.dart \
  fe/lib/social/admin/admin_student_verifications_page.dart \
  fe/lib/social/news/institutional_news_page.dart fe/lib/social/social_models.dart \
  fe/lib/social/social_page.dart fe/lib/social/widgets/social_user_profile_page.dart \
  fe/lib/social/widgets/student_help_card.dart \
  .github/workflows/sync-dmi-notices-hourly.yml \
  README_SYNC_DMI_ORARIO.md README_RILASCIO_AVVISI_RIPASSO_PROFILI.md
git diff --cached --stat
git commit -m "Corregge avvisi e ripasso, aggiunge verifiche studenti"
git push origin main
```

Ricompilare e pubblicare l'app Flutter a partire da `fe/`. La versione del database locale aumenta da 14 a 15 per conservare le alternative dei quiz di ripasso scaricati in seguito: le domande precedenti restano disponibili, ma per sessioni offline che non conservavano tutte le alternative il quiz può mostrare solo la risposta data e quella corretta. Il punteggio del quiz di ripasso non modifica automaticamente le statistiche dei tentativi originali.

Per l'aggiornamento orario DMI, aggiungere lo stesso `STUDENTLAB_NOTICE_SYNC_TOKEN` del backend ai Secrets del repository GitHub (Actions), quindi avviare manualmente il workflow `Sincronizza avvisi DMI` per verificare il primo avvio. Il workflow incluso è programmato ogni ora al minuto 17 UTC. Vedi anche `README_SYNC_DMI_ORARIO.md`.
