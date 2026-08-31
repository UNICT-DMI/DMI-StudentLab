
# StudentLab Requirements Test Suite

Questa suite trasforma i requisiti StudentLab in quality gate.

## Esecuzione

Dalla root del repository:

```bash
source BE/.venv/bin/activate
pip install pytest
pytest -q BE/tests/requirements
```

Oppure da `BE/`:

```bash
pytest -q tests/requirements
```

## Cosa verifica già

- route catalogo accademico;
- area Admin;
- area Teacher verificata;
- teacher materials;
- notifiche;
- report gruppi/contenuti;
- account deletion in-app;
- campi di verifica voto;
- regola materia senza voto => `none`;
- voto dichiarato => `pending`;
- modifica voto verificato => `pending`;
- rimozione voto => `none`;
- assenza di alcuni pattern di user ID hardcoded;
- assenza dei pattern più pericolosi di `error.toString()` mostrati direttamente;
- CORS wildcard + credentials.

## Cosa NON può essere certificato solo da pytest

Questi requisiti richiedono test aggiuntivi:

- accessibilità reale Android/iOS;
- comportamento offline e sync su dispositivo;
- performance e carico;
- upload reale verso Blob;
- push notification;
- WebSocket/chat realtime;
- backup/restore;
- privacy disclosures Play/App Store;
- URL pubblico di cancellazione account;
- moderazione operativa e tempi di risposta;
- review account e flusso Store;
- crash-free testing su device.

Il file `requirements_matrix.json` è la matrice di tracciabilità. Ogni requisito deve avere:
1. un ID;
2. una specifica;
3. uno o più test;
4. una prova manuale quando l'automazione non basta.

## Regola di progetto

Un requisito non è `DONE` solo perché esiste una classe o una schermata.
È `DONE` quando:
- il test automatico passa, se applicabile;
- il test end-to-end passa;
- il controllo manuale/store passa, se richiesto.
