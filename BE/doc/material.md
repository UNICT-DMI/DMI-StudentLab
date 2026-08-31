SQLite v6: struttura nuova completata con material_files, materials, material_downloads, material_sync_state, pending_uploads.
Modelli locali v6: completati MaterialFileLocal, MaterialLocal, MaterialDownloadLocal, MaterialSyncStateLocal, MaterialOfflineEntry.
Repository/servizi locali: completati MaterialRepository, LocalFileService, MaterialDownloadService, LocalMaterialImportService, PendingUploadService, LocalStorageService.
Download unificato: completato per public, teacher, group, con deduplicazione SHA-256, file temporaneo, verifica hash, riuso del file fisico e garbage collection solo quando nessun materiale lo usa più.
Sync manifest backend: completato con visible_keys, sync incrementale tramite since, revoche accesso e isolamento per utente.
Backend download materiali: completato per public / teacher / group.
ApiService Flutter: integrato getMaterialSyncManifest(), downloadMaterial(), wrapper compatibili e adesso anche getGroups().
StudentMaterialPage: migrata alla v6; analyzer sostanzialmente pulito, rimane solo il nome file StudentMaterialPage.dart, che avevi scelto di lasciare così.
MaterialDownloadService e MaterialOfflineEntry: analyzer puliti.
StudyGroupDetailPage: migrata al nuovo sistema materiali; restano solo alcuni info relativi al fatto che un tipo privato _GroupMaterial viene esposto da GroupMaterialSection.
CreateGroupPage: la stiamo ripulendo ora; abbiamo già corretto FilePicker, withOpacity, dropdown deprecato e campo _currentUser inutilizzato.
PublicGroupsPage: integrato getGroups() e corretti i break inutili.
StudentGroupsPage: aggiornato, ma rimangono due segnalazioni minori dell’analyzer.
groups_material_page.dart: è ancora uno dei file principali da migrare/ripulire; contiene diversi withOpacity() e due use_build_context_synchronously.
widgets/study_group_card.dart: resta da ripulire dai withOpacity() deprecati.