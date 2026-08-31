Le regole già implementate nel blocco sono quelle che avevamo definito: news pubbliche di gruppo o private, risposte tramite parent_news_id, scadenza a 7 giorni, eliminazione dell'autore, moderazione owner/admin per le news del gruppo, privacy delle news private, moderazione globale admin/creator, segnalazioni, blocco utenti, impossibilità di inviare news private tra utenti bloccati e occultamento nel feed dei contenuti degli utenti bloccati.

Sì, adesso il quadro è molto più chiaro e correggo la specifica precedente.

Lo studente **non può pubblicare news pubbliche**. Può pubblicare soltanto:

* nel gruppo che ha creato;
* oppure in un gruppo di cui è membro **se ha il permesso di pubblicazione**;
* può ricevere news private;
* può rispondere alle news private se il flusso e i blocchi lo consentono.

Le news pubbliche della futura sezione `News` saranno invece comunicazioni istituzionali/accademiche pubblicate da teacher verificati, admin e creator secondo permessi e target accademico.

Per il frontend che mi hai mandato, io procederei così.

## 1. Problema dei gruppi duplicati

Ho trovato una causa molto probabile nel frontend attuale.

Dentro `_SocialGroupsPage`, il caricamento usa:

```dart
onlyUserGroups:
    false,
```

e quindi `_loadGroupsFromBackend()` chiama:

```dart
apiService.getGroups()
```

anziché:

```dart
apiService.getUserGroups(
    currentUserId,
)
```

La helper è infatti già predisposta per distinguere i due casi. 

Questo è sbagliato per la schermata **Gruppi personali**: lì dovremmo usare:

```dart
onlyUserGroups:
    true,
```

Il backend, invece, quando crea un gruppo crea una sola `StudyGroup` e successivamente una sola `GroupMember` con ruolo `owner`; non crea due gruppi. 

Quindi il sospetto principale è proprio la visualizzazione frontend / aggregazione, non una doppia `INSERT` backend.

---

# 2. Nuova struttura Social

Attualmente la navigazione autenticata contiene:

```text
Profilo
Utenti
Gruppi
```



La trasformerei in:

```text
Profilo
Utenti
Gruppi
News
```

La nuova voce `News` sarà la sezione pubblica generale, ma **non la implementerei ancora nel primo passaggio**. Prima chiudiamo completamente Gruppi + Group News.

Quindi il primo refactor UI resta:

```text
Profilo
Utenti
Gruppi
```

e successivamente:

```text
Profilo
Utenti
Gruppi
News
```

---

# 3. Il Profilo non deve più mostrare "I miei gruppi"

Hai ragione.

Attualmente `_SocialProfilePage` carica anche i gruppi dell'utente e li mostra nel profilo. Invece questa responsabilità deve andare interamente nella sezione `Gruppi`.

La pagina Profilo deve restare concentrata su:

```text
dati utente
percorso accademico
ruolo
disponibilità
materie
azioni profilo
```

Non:

```text
i miei gruppi
```

La sezione Gruppi diventa il vero hub.

---

# 4. Come costruirei la nuova sezione Gruppi

Non farei più semplicemente una lista di tutti i gruppi.

La pagina dovrebbe essere così:

```text
Gruppi

I tuoi gruppi di studio e le community
a cui partecipi.

[ + Crea gruppo ]   [ 🔎 Esplora ]

────────────────────────

I tuoi gruppi                     4

[ Tutti ] [ Creati da te ] [ Partecipi ]

┌────────────────────────────┐
│ Gruppo Programmazione 2    │
│ PUBBLICO          OWNER    │
│                            │
│ Creato da Franz Amoroso    │
│                            │
│ Università di Catania      │
│ DMI · Informatica          │
│ Programmazione 2           │
│                            │
│ 👥 12     📁 6             │
└────────────────────────────┘
```

La sezione `_SocialGroupsPage` che hai già è un'ottima base perché possiede già le azioni:

```dart
_createGroup()
_exploreGroups()
_openGroup()
```

e la UI ha già previsto "Crea gruppo" ed "Esplora gruppi". 

Quindi non la riscriverei da zero: la ripuliamo e la facciamo diventare l'hub definitivo.

---

# 5. Card gruppo

Il tuo `StudyGroupCard` attuale è già visivamente coerente con StudentLab, ma manca una parte importante delle informazioni. 

Aggiungerei al model:

```dart
final int createdBy;
final String creatorName;
```

e nella card mostrerei:

```text
Nome gruppo

PUBBLICO / PRIVATO
OWNER / ADMIN se applicabile

Creato da Mario Rossi

Ateneo
Dipartimento · Corso
Materia

Descrizione

12 partecipanti     5 materiali
```

### Badge pubblico / privato

Oggi mostri soltanto l'icona del lucchetto quando:

```dart
group.isPrivate
```

Per un gruppo pubblico non compare nulla. 

Io renderei sempre esplicito lo stato:

```text
🌐 Pubblico
```

oppure:

```text
🔒 Privato
```

Questo migliora molto la comprensione.

Quindi niente più:

```dart
if (group.isPrivate)
```

come unica rappresentazione.

Avremo sempre:

```dart
_GroupVisibilityBadge(
  isPrivate: group.isPrivate,
)
```

---

# 6. Ateneo, dipartimento e corso

Il model contiene già:

```dart
university
department
course
```

quindi possiamo mostrarli senza modifiche API se il backend li restituisce correttamente.

La card che usi in `PublicGroupsPage` oggi mostra solo:

```dart
group.subject
group.department • group.course
```



La farei invece:

```text
🏛 Università di Catania
🎓 DMI · Informatica
📘 Programmazione 2
```

senza appesantire troppo.

---

# 7. Chi ha creato il gruppo

Il backend contiene già:

```python
created_by
```

e quando crea il gruppo assegna quello stesso utente come owner. 

Ma nel model Flutter attuale interpreti `created_by` soltanto per calcolare:

```dart
isOwner
```

Non salvi il dato del creatore.

Quindi `StudyGroup` deve diventare almeno:

```dart
final int? createdBy;
final String creatorName;
```

Se il JSON del dettaglio gruppo espone già l'utente associato al `created_by`, useremo quello.

Altrimenti possiamo temporaneamente ottenere il creator attraverso:

```dart
getSocialUser(createdBy)
```

durante il merge del gruppo.

Meglio però, quando torneremo sul backend, far restituire direttamente:

```json
"creator": {
  "id": 1,
  "first_name": "...",
  "last_name": "..."
}
```

per evitare una query HTTP aggiuntiva per ogni card.

---

# 8. Esplora gruppi: privati e pubblici

Qui cambierei il comportamento attuale.

La pagina `PublicGroupsPage` oggi filtra esplicitamente:

```dart
if (!group.isPrivate) {
  groups.add(group);
}
```

e successivamente:

```dart
_groups.where(
  (group) => !group.isPrivate,
)
```



Quindi oggi **non può mostrare gruppi privati**.

Se la nuova specifica è che nella ricerca devono poter comparire anche quelli privati, allora rinominerei concettualmente:

```text
PublicGroupsPage
```

in:

```text
ExploreGroupsPage
```

e mostreremo:

```text
Pubblico
Privato
```

con comportamenti diversi.

### Gruppo pubblico

Card:

```text
PUBBLICO
```

azione:

```text
Partecipa
```

oppure apertura e ingresso diretto.

### Gruppo privato

Card:

```text
PRIVATO
```

azione:

```text
Richiedi accesso
```

e non deve esporre dati che il backend considera privati.

---

# 9. Filtri

Qui terrei quasi esattamente quello che hai già.

Hai già:

```text
Materia
Dipartimento
Corso
Ordina
Reset
```



Mi piace anch'io come base.

Aggiungerei solamente:

```text
Ateneo
Accesso
```

quindi:

```text
[Ateneo]
[Dipartimento]
[Corso]
[Materia]
[Accesso]
[Ordina]
```

Accesso:

```text
Tutti
Pubblici
Privati
```

Ricerca testuale:

```text
nome
descrizione
creator
ateneo
dipartimento
corso
materia
```

---

# 10. Default dei filtri

Per l'utente autenticato:

```text
Ateneo       = percorso principale
Dipartimento = percorso principale
Corso        = percorso principale
```

ma modificabili.

E aggiungerei:

```text
Ripristina il mio percorso
```

Questo stesso componente filtro lo possiamo successivamente riutilizzare nella futura pagina **News pubbliche**.

---

# 11. Chat di gruppo → News del gruppo

Questa è una modifica importante.

`StudyGroupDetailPage` oggi importa:

```dart
group_chat_layer.dart
```

e mostra:

```text
Chat del gruppo
Parla con i partecipanti del gruppo.
```



Quella card deve sparire.

Diventa:

```text
News del gruppo
```

con icona:

```dart
Icons.campaign_outlined
```

oppure:

```dart
Icons.newspaper_rounded
```

Io sceglierei `campaign_outlined`.

Descrizione:

```text
Leggi aggiornamenti e comunicazioni del gruppo.
```

Per chi può pubblicare:

```text
Leggi e pubblica aggiornamenti per il gruppo.
```

---

# 12. Come costruirei `GroupNewsPage`

Qui riutilizziamo il backend appena fatto.

UI:

```text
Programmazione 2
News del gruppo

────────────────────────────

Mario Rossi
Owner
20 ago · 14:30

Domani ci vediamo in aula studio
alle 15 per gli esercizi sugli alberi.

                         ⋮

────────────────────────────

Prof. Bianchi
Docente verificato
20 ago · 11:10

Ho aggiunto il materiale relativo
alla lezione di oggi.

                         ⋮
```

In fondo, se l'utente può pubblicare:

```text
[ Scrivi un aggiornamento... ]   [Pubblica]
```

Se non può:

```text
Puoi leggere le news del gruppo.
```

---

# 13. Permesso di pubblicazione

Qui introduciamo una distinzione importante.

Non basta:

```dart
isMember
```

Serve qualcosa tipo:

```dart
canPublishGroupNews
```

che deve arrivare dal backend o dai dati membership.

Ruoli predefiniti:

```text
Owner     → sì
Admin     → sì
Member    → no, salvo autorizzazione
```

Quindi lato membership suggerisco in futuro:

```text
can_publish_news
```

oppure una tabella permission.

Per la UI possiamo già predisporre:

```dart
bool get canPublishNews {
  return group.isOwner ||
      group.isAdmin ||
      currentMemberCanPublishNews;
}
```

---

# 14. News private dentro il gruppo

Nel feed Group News, quando una news è privata e l'utente è destinatario/autore, la card appare così:

```text
🔒 Privato

Prof. Bianchi
Docente verificato

Vorrei segnalarti un materiale utile...
```

Con azione:

```text
Rispondi
```

La risposta crea un'altra GroupNews privata con:

```text
parent_news_id
```

e il backend già applica le regole privacy/blocco.

---

# 15. Icona chat globale

Questo è un punto diverso dalla pagina Group News.

Attualmente `SocialPage` e la pagina Gruppi aprono:

```dart
MessagesPage()
```

tramite l'icona:

```dart
Icons.chat_bubble_outline_rounded
```



Quell'icona deve **rimanere visivamente una comunicazione personale**, ma non rappresentare più una chat generica.

La farei diventare:

```text
Comunicazioni private
```

e la pagina mostra esclusivamente:

```text
GroupNews.visibility == private
AND currentUser è autore o destinatario
```

Esempio:

```text
Comunicazioni

Prof. Rossi
Gruppo: Programmazione 2

Ti consiglio di ripassare...
2 ore fa

────────────────────────

Mario Bianchi
Gruppo: Analisi 1

Ti mando il riferimento...
ieri
```

Quindi:

```text
icona chat
    ↓
PrivateNewsInboxPage
```

non:

```text
GroupChatLayer
```

---

# 16. Guest

Oggi nei testi Guest compare ancora:

> “Per utilizzare la chat…”



Dobbiamo sostituirlo ovunque.

Ad esempio:

```text
Come Guest puoi consultare le informazioni pubbliche
del gruppo e i materiali disponibili.

Accedi per partecipare al gruppo e visualizzare
le comunicazioni riservate ai membri.
```

Niente più riferimento alla chat.

---

# 17. Segnalazione gruppo

Hai già gli endpoint backend, quindi va integrata nella UI.

Per utenti non owner:

nel menu `⋮` del dettaglio gruppo:

```text
Segnala gruppo
Esci dal gruppo
```

Per un utente esterno:

```text
Segnala gruppo
```

Per owner/admin:

```text
Gestisci gruppo
```

e owner avrà:

```text
Modifica
Privacy
Gestisci partecipanti
Gestisci segnalazioni
Elimina gruppo
```

La segnalazione deve aprire un bottom sheet:

```text
Segnala gruppo

Perché vuoi segnalarlo?

○ Spam
○ Contenuti offensivi
○ Impersonificazione
○ Contenuto illecito
○ Privacy
○ Altro

Dettagli opzionali

[Annulla] [Invia segnalazione]
```

Mai mostrare stack trace / exception raw.

---

# 18. Eliminazione gruppo

`GroupAdminLayer` contiene già una sezione:

```text
Elimina gruppo
```



Quindi non partiamo da zero.

La UI deve però rispettare la policy ownership che abbiamo già definito:

se il gruppo ha altri membri, non dovrebbe essere sempre:

```text
Elimina definitivamente
```

ma:

```text
Elimina gruppo
```

e poi backend può richiedere trasferimento owner.

Dialog:

```text
Vuoi eliminare il gruppo?

Prima dell'eliminazione potrebbe essere necessario
trasferire la proprietà a un altro partecipante.

[Annulla]
[Continua]
```

Messaggi backend trasformati in testo user-friendly.

---

# 19. Error handling App Store / Play Store

In alcuni file hai ancora:

```dart
_error = e.toString();
```

per esempio nel GroupAdminLayer. 

Questo va eliminato ovunque.

La `_cleanError()` che hai già in versioni più recenti è molto meglio: mappa `401`, `403`, `404`, timeout e rete in messaggi comprensibili. 

Standard globale:

```text
401
→ La sessione non è più valida. Accedi nuovamente.

403
→ Non hai i permessi necessari.

404
→ Il contenuto non è più disponibile.

rete
→ Non è stato possibile connettersi a StudentLab.

timeout
→ La richiesta sta impiegando troppo tempo.

altro
→ Non è stato possibile completare l'operazione. Riprova.
```

Mai:

```text
Exception:
DioException:
SocketException:
HTTP 500:
SQLAlchemy:
```

---

# 20. Nuova sezione News pubbliche

Correggo anche questo punto.

### Studente

Può:

```text
leggere
filtrare
aprire autore
segnalare
bloccare autore quando previsto
```

Non può:

```text
pubblicare PublicNews
```

### Teacher verificato

Può pubblicare PublicNews solo nel proprio contesto autorizzato:

```text
università
dipartimento
corso
materie assegnate/verificate
```

### Admin

Può:

```text
pubblicare news ufficiali
moderare
gestire segnalazioni
```

### Creator

Può:

```text
pubblicare globalmente
moderare globalmente
gestire admin
```

---

# 21. La futura tab bar Social

Alla fine la vedrei così:

```text
Profilo     Utenti      Gruppi      News
 👤          👥          👨‍👩‍👧         📰
```

e in alto:

```text
🔔 notifiche
💬 comunicazioni private
```

Quindi separiamo bene:

```text
News
→ comunicazioni pubbliche istituzionali/accademiche

Gruppi
→ community + GroupNews

💬
→ private GroupNews destinate all'utente

🔔
→ notifiche di sistema
```

---

## Ordine pratico che seguirei adesso

Per pubblicare prima possibile, farei questo ordine:

1. **`StudyGroup` model Flutter**

   * `createdBy`
   * `creatorName`
   * eventuale `canPublishNews`

2. **`SocialPage`**

   * rimuovere i gruppi dal Profilo
   * `_SocialGroupsPage` usa `onlyUserGroups: true`
   * rendere Gruppi l'hub unico

3. **Card gruppo**

   * creator
   * ateneo
   * dipartimento
   * corso
   * materia
   * badge `Pubblico/Privato`
   * ruolo owner/admin

4. **Explore Groups**

   * trasformare `PublicGroupsPage` in esplorazione di pubblici + privati
   * filtri esistenti + Ateneo + Accesso
   * join/request

5. **StudyGroupDetailPage**

   * rimuovere `GroupChatLayer`
   * sostituire con `GroupNewsPage`
   * segnalazione gruppo
   * uscita
   * gestione

6. **GroupNews UI**

   * feed
   * publish permission
   * delete
   * report
   * moderate
   * private label
   * reply

7. **icona chat globale**

   * nuova inbox delle sole Private Group News

8. **GroupAdminLayer**

   * eliminazione
   * segnalazioni
   * errori user-friendly

9. poi nuova sezione **News pubbliche**.

Il primo file che modificherei ora è proprio **`StudyGroup`**, perché tutte le card e le pagine dipendono da quello. Poi passerei immediatamente a `SocialPage`.

Se vuoi procedere file per file come abbiamo fatto col backend, il prossimo passo è: **ti restituisco `StudyGroup` completo e aggiornato, senza commenti**, aggiungendo creator e i campi necessari alla nuova UI.
