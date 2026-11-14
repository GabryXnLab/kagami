# API di Kagami Server — v2

Il contratto fra l'app e un server che scarica al posto del telefono. È
l'originale: l'implementazione di riferimento è `server/` in questo repo, e
qualunque altro server che risponda così funziona con Kagami. Una modifica
che cambia il significato di un campo è una versione nuova; aggiungere campi
no, e un client ignora quelli che non conosce.

La v1 riconosceva chi chiamava con una chiave API creata dal terminale del
server. La v2 lo riconosce con l'account Google con cui si è fatto l'accesso
all'app: il server ha un proprietario, un elenco di account ammessi, e per
ognuno un Drive, una cartella, una coda e le serie che segue.

## Trasporto

JSON UTF-8 su HTTP. Il server non fa TLS: l'HTTPS lo mette chi lo espone
(Tailscale Funnel, un reverse proxy). In chiaro va bene solo in una rete
privata o dentro una VPN (vedi [server.md](server.md)).

## Chi chiama

Ogni richiesta sotto `/v2/` dice chi chiama in `Authorization`, in uno di due
modi.

### Biglietto (`tickets`)

`Authorization: Kagami-Ticket <biglietto>`. Il biglietto lo rilascia il
backend dell'app all'account che ha fatto l'accesso, per **questo** server a
**questo indirizzo**: l'app chiama `kagami_ticket(audience, origin)` con l'`id`
che il server dichiara in `GET /` e con l'indirizzo a cui l'app gli sta
parlando (`origin`: quello del collegamento, nella forma di
`normalizeServerUrl`, cioè `schema://host[:porta][/percorso]` senza `/`
finale), e manda al server solo ciò che ne esce. Il server non riceve mai il
token della sessione, che varrebbe sul backend: un biglietto vale dieci
minuti, solo per quell'`id` e quell'indirizzo, e sul backend non apre niente.

L'`id` da solo non basta, perché è pubblico: un server M che, a un primo
collegamento, dichiara l'`id` del server B riceverebbe un biglietto per B e lo
ripeterebbe su B. Per questo l'indirizzo lo sceglie l'app e lo **garantisce il
proprietario**: la sua app, per il server che ha creato (il collegamento lo
ricorda, `owner`), prima di chiedere biglietti chiama
`kagami_server_origin(audience, origin)` («a questo indirizzo risponde il mio
server con questo `id`»). Il server lo verifica chiedendo al backend, con la
sola chiave `anon`, `POST <url>/rest/v1/rpc/kagami_ticket_who` con
`{"ticket": …, "audience": <il suo id>, "owner": <l'email del suo
proprietario, da KAGAMI_SETUP>}`: la risposta è una riga `{email,
expires_at}` se impronta, `audience` e termine combaciano **e** l'indirizzo
del biglietto è stato garantito per quell'`audience` da `owner`; nessuna riga
altrimenti (`401 unauthorized`). Il biglietto chiesto attraverso M porta
l'indirizzo di M, che il proprietario di B non ha garantito: su B non vale.
Tiene l'esito fino al termine del biglietto: una richiesta al backend per
biglietto, non per chiamata. Il backend che non risponde è `503
identity_unavailable`; un backend senza la funzione rifiuta i biglietti
(`401`).

Conseguenze:

- un amico usa l'indirizzo dell'invito, che è quello del collegamento del
  proprietario e quindi garantito; un amico che lo cambia a mano (un altro
  nome dello stesso server) non entra finché il proprietario non collega
  anche quello;
- i biglietti valgono solo dopo che il proprietario ha aperto il server con
  un'app che garantisce l'indirizzo: fino ad allora gli amici ricevono `401`;
- i biglietti senza indirizzo (`kagami_ticket(audience)`, l'app di prima) non
  valgono su un server che chiede con `owner`, e la forma di prima di
  `kagami_ticket_who(ticket, audience)`, quella dei server di prima, non
  risponde per i biglietti con indirizzo: un server di prima rifiuta i
  biglietti dell'app nuova finché non si aggiorna (`kagami-updater`, entro
  un'ora);
- un indirizzo garantito vale 90 giorni dall'ultima dichiarazione (migrazione
  0015): `kagami_server_origin` ripetuta rinnova, e l'app la ripete a ogni
  apertura del server se l'ultima ha più di 7 giorni. Un proprietario che non
  apre il server per tre mesi deve riaprirlo prima che gli amici rientrino
  (`401` fino ad allora). Se perde un dominio e qualcun altro lo prende, i
  biglietti verso quel dominio smettono di valere entro 90 giorni; fino ad
  allora il rischio resta.

L'`id` è casuale (128 bit, 32 cifre esadecimali), nasce al primo avvio nella
cartella dei dati (`id`) e non cambia finché c'è il volume. Un server lo
dichiara in `GET /` e in `GET /v2/server`, ed elenca `tickets` fra le
`features` di tutt'e due solo se conosce il backend.

Che cosa fa l'app (residui in `handoff/raccolte-social-sorgenti/FASE-8.md`, F8.6):

- chiede `GET /` prima di ogni altra richiesta; con `tickets` manda un
  biglietto per l'`id` dichiarato e l'indirizzo del collegamento, e mai il
  token; per il proprio server garantisce prima l'indirizzo (una volta per
  avvio dell'app);
- ricorda l'`id` col collegamento, e **rifiuta un server che dichiara l'`id`
  del server collegato da un altro indirizzo** (chi si spaccia per lui per
  riusarne i biglietti), o un `id` diverso da quello ricordato per lo stesso
  collegamento (volume ricreato: si ricollega);
- a un server senza `tickets`, o col backend senza `kagami_ticket`, manda il
  token della sessione (`Bearer`, sotto) **solo se è il proprio**: quello che
  l'app ha creato con «Crea il tuo server», che il collegamento ricorda
  (`owner`). Ciò che dichiara il server non basta, perché un server modificato
  può dichiarare chiunque. A un server altrui senza biglietti non manda
  niente, e dice di aggiornarlo.

### Token della sessione (`Bearer`)

`Authorization: Bearer <token>`, il modo di prima: resta per l'app che non
ha biglietti e per il server del proprietario quando il backend non li
rilascia. Il server ne accetta due, e li riconosce dall'emittente (`iss`,
letto senza fidarsi e poi verificato da chi lo conosce):

1. **Backend** (`iss` = `<KAGAMI_BACKEND_URL>/auth/v1`): l'`access_token`
   (JWT) della sessione del backend compatibile Supabase di chi compila
   (`BACKEND_URL` dell'app; il manutentore usa Hestia). Il server lo accetta se:
   - `exp` non è passato e `iat`, se c'è, non è nel futuro (un minuto di
     tolleranza), `aud` è `authenticated`;
   - la firma RS256 torna con una delle chiavi di
     `<url>/auth/v1/.well-known/jwks.json`, se il backend le pubblica.
     Altrimenti (JWKS assente, `kid` sconosciuto, ES256 o HS256) chiede al
     backend `GET <url>/auth/v1/user` col token stesso e l'header `apikey`
     (la chiave `anon`), e tiene la risposta fino all'`exp` del token: una
     richiesta al backend per token, non per chiamata. Il server non ha mai
     il segreto del backend;
   - l'accesso è solo con Google: `app_metadata.providers` è esattamente
     `["google"]`, `is_anonymous` non è vero, `email` c'è e, nella risposta
     di `/user`, `email_confirmed_at` anche. È lo stesso criterio di
     `kagami_me()` sul backend (`backend/migrations/0008_hardening.sql`): un
     account con un altro accesso accanto (email e password, un secondo
     provider) non entra, perché il suo indirizzo potrebbe non averlo
     verificato Google. Il JWT non porta `email_confirmed_at`: lì basta
     Google come unico accesso, che l'indirizzo lo verifica da sé.
     `user_metadata` non decide niente: lo scrive l'utente.
2. **Firebase** (`iss` = `https://securetoken.google.com/<progetto>`), per il
   passaggio e le app di prima: l'ID token di Firebase, accettato solo se il
   server conosce il progetto (`KAGAMI_FIREBASE_PROJECT`, o il `project` di
   una configurazione senza `backend`). Il server lo accetta se:
   - la firma RS256 torna con una delle chiavi pubbliche di
     `securetoken@system.gserviceaccount.com`
     (`https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com`);
   - `aud` è il progetto e `iss` è `https://securetoken.google.com/<progetto>`;
   - `exp` non è passato e `iat` non è nel futuro (un minuto di tolleranza);
   - l'accesso è con Google (`firebase.sign_in_provider` = `google.com`),
     `email` c'è ed `email_verified` è vero.

L'utente è l'indirizzo `email`, in minuscolo. Token mancante o non valido
(firma, scadenza, emittente sconosciuto, il backend risponde `401`/`403`):
`401 unauthorized` con `WWW-Authenticate: Bearer realm="kagami-server"`, e
l'app deve rifare l'accesso. Chi rilascia i token non risponde (rete, `5xx`):
`503 identity_unavailable`, da riprovare, perché il token potrebbe valere.
Token valido di un account che non è nell'elenco: `403 not_allowed`.

Il server non tiene sessioni: ogni richiesta porta il suo token, quindi
togliere un account dall'elenco vale dalla richiesta seguente.

## Configurazione: `KAGAMI_SETUP`

Il server non ha schermate né accessi da fare sul terminale. Tutto ciò che
gli serve lo porta un blob che l'app genera per il proprietario e mette nel
comando di avvio, come variabile d'ambiente `KAGAMI_SETUP` (o
`kagami-server serve --setup <blob>`). È un JSON codificato in base64url,
senza `=` finali:

```json
{
  "v": 1,
  "name": "Il server di Gabry",
  "project": "mio-progetto-firebase",
  "backend": {"url": "https://backend.example.com", "anonKey": "eyJ…"},
  "client": {"id": "1234-abc.apps.googleusercontent.com", "secret": "…"},
  "owner": {
    "email": "proprietario@gmail.com",
    "refreshToken": "1//0g…",
    "folderId": "1AbC…",
    "folderName": "MangaArchive"
  }
}
```

| Campo | |
| --- | --- |
| `project` | facoltativo se c'è `backend` (l'app non lo scrive più): il progetto Firebase dell'app. Vale per i token solo in una configurazione senza `backend` (quelle di prima del backend); con `backend`, Firebase lo accende `KAGAMI_FIREBASE_PROJECT` |
| `backend` | facoltativo, il backend compatibile Supabase dell'app: `url` è la radice del progetto (emittente `<url>/auth/v1`), `anonKey` la sua chiave pubblica `anon`. Le variabili `KAGAMI_BACKEND_URL` e `KAGAMI_BACKEND_ANON_KEY` del server, se ci sono, valgono al suo posto |
| `client` | il client OAuth «Web» dello stesso progetto, quello per cui l'app chiede il codice per il server (`serverClientId`): con lui il server rinnova i permessi di Drive degli utenti |
| `owner` | il proprietario: il suo permesso di Drive (refresh token, scope `drive`) e la cartella della sua libreria |
| `name` | facoltativo, il nome che l'app mostra |

Il server lo applica al primo avvio e ogni volta che cambia (ne ricorda
l'impronta): riavviare il contenitore con lo stesso comando non rimette un
permesso vecchio sopra uno rinnovato. Il blob contiene segreti: chi lo ha
può scrivere sul Drive del proprietario.

Senza configurazione ogni richiesta sotto `/v2/` risponde
`503 not_configured`.

## Errori

Ogni errore ha lo stesso corpo, con un `code` stabile per il programma e un
`message` da mostrare all'utente:

```json
{"error": {"code": "drive_not_ready", "message": "Il server non ha ancora il tuo Drive: …"}}
```

| Stato | `code` | Quando |
| --- | --- | --- |
| 400 | `bad_request` | corpo non JSON, campo mancante o del tipo sbagliato |
| 400 | `unsupported_url` | il link non è di un sito che il server conosce |
| 400 | `bad_folder` | la cartella di Drive non c'è o il server non la vede |
| 400 | `bad_grant` | Google non accetta il permesso di Drive mandato |
| 401 | `unauthorized` | token o biglietto mancante, scaduto o non valido |
| 403 | `not_allowed` | l'account non è fra quelli ammessi |
| 403 | `owner_only` | l'operazione è del proprietario |
| 403 | `not_owner` | spostare nel cestino di Drive in una cartella che non è dell'account, o di cui il server non ha potuto leggere il proprietario (`owner`) |
| 404 | `not_found` | indirizzo, lavoro, serie o utente sconosciuti |
| 409 | `drive_not_ready` | il server non ha il permesso di Drive di chi chiama, o la sua cartella |
| 413 | `too_large` | corpo oltre 16 MB |
| 429 | `queue_full` | la coda di chi chiama ha già 1000 lavori |
| 503 | `not_configured` | il server è partito senza `KAGAMI_SETUP`, o senza né backend né progetto Firebase |
| 503 | `identity_unavailable` | il backend (o Google) non risponde: non si può verificare il token adesso |
| 503 | `drive_offline` | Google non risponde adesso |
| 500 | `internal` | guasto del server |

## Indirizzi

### `GET /` — senza token

```json
{"service": "kagami-server", "api": 2, "id": "3f2a…(32 cifre esadecimali)", "features": ["tickets"]}
```

È l'unica risposta senza token: dice che lì c'è un Kagami Server, quale API
parla e chi è (`id`, vedi «Biglietto»). `features` qui elenca solo `tickets`,
quando il server li accetta; un server di prima non ha né `id` né `features`.
La usano l'app, per dire «indirizzo giusto, server da aggiornare» e per
sapere per chi chiedere il biglietto, e il controllo di salute di Docker.

### `GET /v2/server`

```json
{
  "service": "kagami-server", "version": "0.2.0", "api": 2,
  "id": "3f2a…",
  "name": "Il server di Gabry",
  "owner": "proprietario@gmail.com",
  "providers": [{"id": "mangak", "name": "MangaK"}, {"id": "manhwaread", "name": "ManhwaRead"},
                {"id": "asurascans", "name": "Asura Scans"},
                {"id": "coffeemanga", "name": "Coffee Manga"},
                {"id": "examplescans", "name": "Example Scans", "builtIn": false, "version": 2}],
  "images": true,
  "features": ["ahead", "unfollowed", "verify", "sites", "browser", "owner"],
  "check": {"minutes": 240, "time": 240, "enabled": true, "library": true,
            "unfollowed": ["mangak:A1"],
            "checkedAt": "…", "checked": 12, "queued": 2, "failed": 1,
            "gated": [{"key": "manhwaread:disfarming", "title": "Disfarming",
                       "url": "https://manhwaread.com/manhwa/disfarming/"}],
            "sites": {"coffeemanga": {"broken": true, "message": "Serie Coffee Manga non trovata.",
                                      "since": "…", "checkedAt": "…"}}},
  "me": {
    "email": "amico@gmail.com", "owner": false,
    "drive": {"authorized": true, "folderId": "1XyZ…", "folderName": "Manga", "owned": true}
  }
}
```

- `me` è chi chiama. `me.drive.authorized`: il server ha il suo permesso di
  scrivere su Drive; `folderId` è la cartella della sua libreria, dove
  finisce tutto ciò che mette in coda.
- `images`: il server fa miniature e tessere (MALF, «Tessere delle tavole
  alte»). Se è `false` la libreria resta valida, solo senza tessere.
- `features`: ciò che il server sa fare oltre alla v2 di partenza. Un
  client offre una funzione solo a un server che la elenca; un server di
  prima non ha il campo. `ahead`: scarica «man mano» (`ahead` e
  `automatic` in `POST /v2/jobs`, `PUT /v2/ongoing/{key}`). `unfollowed`:
  il controllo salta le serie escluse (`PUT /v2/check`). `browser`: il
  server ha un Chromium e il controllo legge anche i siti dietro la
  verifica del browser, quando la verifica si risolve da sola; senza, li
  salta. `verify`: dice quali serie sono ferme alla verifica (`gated` in
  `check`) e ne accetta le pagine (`POST /v2/check/pages`). `repair`:
  ripara la libreria (`POST /v2/repair`). `elsewhere`: cerca ogni giorno le
  serie della libreria sugli altri siti (`GET /v2/elsewhere`) e accetta
  `elsewhere` in `PUT /v2/check`. `userProviders`: usa i siti degli utenti
  (`providers/` della cartella di Drive, `docs/siti.md`) per l'account che li
  ha, e li rilegge con `POST /v2/providers`. `expiry`: gli accessi degli
  utenti possono scadere (`expiresAt` in «Utenti», `me.expiresAt`).
  `shares`: ritira alla scadenza i permessi di Drive della libreria
  condivisa che l'app gli affida (`PUT /v2/me/shares`).
  `owner`: il server sposta nel cestino di Drive solo nella cartella di chi
  chiama che è sua (`me.drive.owned`, vedi «Proprietà della cartella»).
  `tickets`: accetta `Authorization: Kagami-Ticket` (vedi «Biglietto»).
- `id`: lo stesso di `GET /`.
- `me.expiresAt` (ISO 8601 UTC) c'è solo se l'accesso di chi chiama scade.
  Un accesso scaduto non risponde più: l'account è già stato tolto (vedi
  «Scadenza» in «Utenti») e riceve `403 not_allowed`.
- `providers`: i siti che il server usa **per chi chiama**: quelli inclusi e,
  con `userProviders`, i suoi dalla cartella della libreria, con `builtIn:
  false` e la `version` del file (uno con l'id di un sito incluso ne prende il
  posto). `sitesErrors`, se c'è, elenca i file di `providers/` che il server non
  ha potuto usare: `[{"file": "x.json", "message": "…"}]`.
- `check` è il controllo quotidiano di chi chiama (`PUT /v2/check`):
  `time` l'ora, in minuti dalla mezzanotte del server; `minutes` la stessa
  ora, `null` se è spento (`enabled`), come per i client di prima;
  `library` se guarda tutta la libreria su Drive; `unfollowed` le chiavi
  delle serie che l'utente ha smesso di seguire; `checkedAt`, `checked`,
  `queued`, `failed` com'è andato l'ultimo: serie controllate, con capitoli
  nuovi, con errori. `gated` sono le serie che il controllo non ha letto
  perché il sito voleva una verifica che nessun browser senza persone
  passa (la casella «Verify you are human»): restano lì finché un
  controllo non le legge. `sites` è la salute dei siti per id del provider
  (`broken`, `message`, `since`, `checkedAt`): un sito è rotto quando la sua
  pagina non ha più la forma attesa (`ProviderChanged`, in coda, nel
  controllo o nel man mano) o quando nello stesso controllo tutte le sue
  serie (almeno due) falliscono con un errore del sito; torna sano al primo
  successo. I lavori automatici di un sito rotto restano in coda senza
  essere tentati e quelli chiesti a mano partono; il client non rimette in
  coda le serie di un sito rotto. Un provider senza voce è sano.

#### Proprietà della cartella (`owner`)

Kagami cancella solo dove l'utente possiede. Quando la cartella cambia
(`PUT /v2/me/drive`, `PUT /v2/me/folder`, `KAGAMI_SETUP`) il server chiede a
Drive se è dell'account (`ownedByMe`) e lo tiene con la cartella:
`me.drive.owned` è `true`, `false` o `null` (non ancora letto: Drive non ha
risposto, o la cartella viene da `KAGAMI_SETUP`, che si applica senza rete).
Una proprietà non letta si richiede prima di ogni giro. Archiviare in una
cartella non propria resta com'è: lo decide il ruolo che Drive ha dato.
Ogni operazione che sposta qualcosa nel cestino di Drive (togliere una serie
o un file della libreria) con `owned` diverso da `true` si rifiuta con
`403 not_owner`, prima di toccare Drive; dentro un lavoro è l'esito in
`history`. Oggi nessun indirizzo toglie serie: il rifiuto è la guardia per
quelli che verranno.

Il server non legge e non scrive `reading/` della cartella: le posizioni di
lettura sono dell'app.

### `PUT /v2/me/drive` — dà al server il permesso sul proprio Drive

```json
{"refreshToken": "1//0g…", "folderId": "https://drive.google.com/drive/folders/1XyZ…"}
```

Il refresh token è quello che l'app ottiene da Google per il client di
`client.id` (lo scope `drive`). Il server lo prova subito chiedendo un token
d'accesso, poi controlla di vedere la cartella; se uno dei due non va,
non salva niente (`bad_grant`, `bad_folder`). `folderId` accetta l'id o il
link. Risponde con lo stesso `drive` di `me`.

### `DELETE /v2/me/drive` → `204`

Il server dimentica il permesso e la cartella di chi chiama, e ferma la sua
coda. È ciò che fa l'app scollegando il server.

### `PUT /v2/me/folder` — cambia la cartella della libreria

```json
{"folderId": "https://drive.google.com/drive/folders/1XyZ…"}
```

Come sopra, senza toccare il permesso.

### `PUT /v2/me/shares` — le condivisioni da ritirare alla scadenza (`shares`)

```json
{"shares": [{"folderId": "1XyZ…", "permissionId": "0123456789",
             "expiresAt": "2026-12-14T12:00:00.000Z"}]}
```

La libreria condivisa (`docs/drive.md`, «La libreria condivisa (contratto)»):
il termine vero di una condivisione è `expires_at` della sua riga sul
backend, e il server di chi condivide, acceso anche a telefono spento, lo fa
valere col permesso di Drive che ha già. Il server non parla col backend
dell'app: sa solo ciò che l'app gli manda qui.

- L'app manda l'elenco **intero** delle sue condivisioni con un termine, che
  sostituisce quello di prima; `[]` vuol dire nessuna. Lo rimanda quando ne
  crea, rinnova o ritira una, e quando `GET /v2/me/shares` non dice ciò che
  sanno le sue righe.
- Al più 200 voci; `folderId` e `permissionId` testi non vuoti sotto i 128
  caratteri, `expiresAt` una data ISO 8601 (anche già passata: si ritira al
  primo giro); la stessa coppia `folderId` + `permissionId` una volta sola.
  Altrimenti `400 bad_request` e l'elenco di prima resta.
- L'elenco sta nello spazio dell'utente (`shares.json`). Ogni ora, con la
  passata delle scadenze degli accessi, per ogni voce scaduta il server
  ritira il permesso su Drive (`DELETE` del permesso). La voce esce
  dall'elenco **solo se Drive ha risposto**: tolto, o `404` (già tolto). Senza
  rete, con un altro errore o senza il permesso di Drive dell'utente (mai
  dato, ritirato con `DELETE /v2/me/drive`, revocato su Google) la voce resta
  e si riprova all'ora dopo; un errore su una voce non ferma le altre né gli
  altri utenti. Una voce cambiata dall'app mentre il server la ritira (stessa
  coppia, altro `expiresAt`) resta.
- La riga sul backend il server non la tocca: la toglie l'app di chi
  condivide alla sua passata, quando il suo `unshare` riceve `404`.
- Accesso scaduto (`expiry`): lo spazio si cancella subito e l'elenco con
  lui. Le condivisioni non passano a nessun altro: restano a Drive, se ha
  accettato `expirationTime`, e all'app di chi condivide. Una voce scaduta
  nello stesso momento non si ritira più dal server.

Risponde `200` con l'elenco in carico, le date in UTC:

```json
{"shares": [{"folderId": "1XyZ…", "permissionId": "0123456789",
             "expiresAt": "2026-12-14T12:00:00.000Z"}]}
```

### `GET /v2/me/shares` — le condivisioni che il server ha in carico (`shares`)

La stessa risposta di `PUT`: le voci non ancora ritirate. L'app la confronta
con le sue righe per accorgersi che l'elenco del server è indietro (una
condivisione nuova o rinnovata mentre il server non rispondeva) e lo rimanda.

### `POST /v2/jobs` — mette in coda una serie

```json
{"url": "https://mangak.io/dungeon-odyssey", "title": "Dungeon Odyssey", "start": "16"}
```

| Campo | Tipo | |
| --- | --- | --- |
| `url` | stringa, obbligatorio | link della serie su un sito di `providers` |
| `title` | stringa | da mostrare finché il server non ha letto la serie |
| `start` | stringa o numero | dal capitolo con questo numero o id in poi |
| `ids` | elenco di stringhe | solo questi capitoli, per id; non insieme a `start` |
| `delayMs` | intero 0–5000 | distanza fra l'inizio di una richiesta al sito e il seguente, che salgono su più corsie (default 200) |
| `snapshot` | stringa | la pagina HTML della serie, solo per i siti dietro la verifica del browser (ManhwaRead) |
| `ahead` | intero 1–50 | scarica «man mano»: la serie resta seguita, anche conclusa, e i capitoli seguenti li chiede l'app (sotto); non per i siti dietro la verifica del browser |
| `automatic` | booleano | il lavoro non lo chiede una persona ma l'app: se la stessa serie è già in coda con `ids`, gli aggiunge i suoi invece di sostituirlo |

Va nella coda di chi chiama e sul suo Drive, nella sua cartella: senza
permesso o cartella, `409 drive_not_ready`. Una coda tiene al più 1000
lavori (ognuno può portare una pagina fino al limite del corpo, salvata sul
disco del server): oltre, `429 queue_full` finché il giro non ne smaltisce. Senza `start` né `ids` si
scarica tutta la serie. In ogni caso `series.json` ha l'elenco completo dei
capitoli (MALF). Lo stesso link già in coda viene sostituito, se non è
quello in corso e se il lavoro nuovo non è `automatic`. Risponde
`201`:

```json
{"job": {"id": "srv-…", "url": "…", "title": "Dungeon Odyssey", "start": "16", "delayMs": 200}}
```

`snapshot` serve perché il server non ha un browser per la verifica di
Cloudflare: la supera l'utente nella WebView del telefono, e il server legge
l'elenco dei capitoli da quella pagina. Le tavole le trova poi sul CDN del
sito. Se anche quello chiede la verifica, il lavoro finisce con un errore
che lo dice.

### `GET /v2/jobs` — a che punto è la propria coda

```json
{
  "status": {"state": "running", "jobId": "srv-…", "title": "Dungeon Odyssey",
             "total": 150, "done": 12, "failed": 0, "pagesDownloaded": 420,
             "pagesSkipped": 0, "bytes": 81234567, "message": "Chapter 13 (13/150)",
             "updatedAt": "2026-09-27T18:00:00.000"},
  "queue": [{"id": "srv-…", "url": "…", "title": "…"}],
  "history": [{"title": "…", "ok": true, "message": "Serie archiviata completamente.",
               "finishedAt": "…", "key": "mangak:KY55w5Y9"}]
}
```

`state` è `idle`, `running` o `waiting` (rete o Drive: `message` dice
perché). Il primo della coda è quello in corso. `history` tiene gli ultimi
sessanta esiti, dal più recente, ciascuno col suo `url`. Sono gli stessi campi della coda del telefono.
Un lavoro appena finito esce dalla coda un attimo prima che il suo esito
entri in `history`: un client che guarda la coda non ne deduce che è stato
annullato. Ogni utente vede solo la sua coda.

### `DELETE /v2/jobs/{id}` → `204`

Toglie il lavoro dalla coda; se è quello in corso lo ferma prima. Ciò che è
già su Drive resta, e rifare lo stesso download porta solo ciò che manca.

### `DELETE /v2/history` → `204`

Dimentica gli esiti.

### `GET /v2/ongoing` — le serie in corso che il server segue

```json
{"series": [{"key": "mangak:KY55w5Y9", "title": "…", "url": "…", "chapters": 169,
             "addedAt": "…", "checkedAt": "…", "problem": null},
            {"key": "mangak:A1", "title": "…", "url": "…", "chapters": 40,
             "addedAt": "…", "checkedAt": "…", "ahead": 5, "wanted": 0}]}
```

Una serie scaricata dal server entra qui da sola, se il sito non la dà per
conclusa o cancellata; il controllo quotidiano mette in coda solo i
capitoli nuovi, e una serie conclusa esce da sola dopo aver messo in coda
gli ultimi. Se il controllo non arriva al sito o a Drive si riprova dopo
mezz'ora. Sono quelle di chi chiama.

Con `ahead` la serie si scarica man mano e resta anche conclusa: il
controllo mette in coda solo i capitoli nuovi che l'app ha chiesto
(`wanted`). I capitoli che l'indice della serie già elenca li chiede l'app
con `POST /v2/jobs` (`ids`, `ahead`, `automatic`), perché è lei a sapere
cosa si legge.

### `PUT /v2/ongoing/{key}` — quanti capitoli nuovi servono

```json
{"wanted": 2}
```

Solo per le serie con `ahead` (altrimenti `409 not_ahead`); `wanted` va da 0
a 50. Il controllo seguente metterà in coda al più quel numero di capitoli
nuovi del sito. Se il sito non è stato guardato da sei ore, lo si guarda
subito, per quella serie sola. Risponde `200`:

```json
{"key": "mangak:A1", "wanted": 2, "checking": true}
```

### `DELETE /v2/ongoing/{key}` → `204`

Smette di seguire la serie. I capitoli già archiviati restano.

### `PUT /v2/check` — regola il proprio controllo quotidiano

```json
{"enabled": true, "minutes": 270, "library": true, "unfollowed": ["mangak:A1"], "elsewhere": true}
```

Ogni campo è facoltativo: cambia solo ciò che c'è. `minutes` da 0 a 1439.
`unfollowed` sostituisce l'elenco intero (al più 5000 chiavi): il
controllo non guarda quelle serie, né fra quelle di `GET /v2/ongoing` né
nella libreria. L'elenco è dell'app, che lo tiene fra i dati dell'utente e
lo rimanda quando cambia. `elsewhere` (solo con `elsewhere` fra le
`features`, acceso se non lo si è mai spento) accende la passata «Su altri
siti» dopo il controllo (`GET /v2/elsewhere`); `check` lo riporta.
Risponde con lo stesso `check` di `GET /v2/server`.

Con `library` il controllo guarda, oltre alle serie di `GET /v2/ongoing`,
ogni serie del `library.json` della propria cartella: mette in coda (lavori
`automatic`) i capitoli del sito che l'`index.json` della serie non elenca,
e quelli che l'indice dà a metà, che il giro salta se su Drive sono interi
riscrivendo l'indice. Salta le serie concluse (senza chiederle al sito),
quelle già in coda, quelle escluse e, senza `browser` fra le `features`,
quelle dei siti con la verifica del browser. Una serie letta col browser
porta nel lavoro la pagina letta, come lo `snapshot` del telefono.

### `POST /v2/check` → `202`

Il controllo quotidiano di chi chiama, subito, anche se è spento. Risponde prima di
finire: i capitoli nuovi compaiono in `GET /v2/jobs`.

### `POST /v2/check/pages` — le pagine delle serie ferme alla verifica

```json
{"pages": [{"url": "https://manhwaread.com/manhwa/disfarming/", "html": "<!DOCTYPE html>…"}]}
```

Da 1 a 50 pagine, nel limite del corpo. La verifica la passa una persona
sul telefono, che poi apre le serie di `gated` e manda qui le loro pagine:
il server controlla subito quelle serie, e solo quelle, come farebbe il
controllo quotidiano, leggendo la pagina da qui al posto del sito. Una
pagina di una serie che non è in `gated` si ignora. Risponde a controllo
finito:

```json
{"checked": 1, "queued": 1, "failed": 0, "gated": []}
```

`gated` sono le serie mandate che restano ferme (una pagina che non era
quella della serie).

### `POST /v2/repair` → `202` — ripara la libreria

```json
{"site": "coffeemanga"}
```

Rilegge dal sito le serie della libreria nella propria cartella di Drive e
ne corregge i dati (MALF, «Cambi d'identità e riparazione»): titolo,
metadati, copertina, capitoli, e la chiave nuova se il sito ha cambiato
identità alla serie. Senza campi tutta la libreria; con `site` (id di
`providers`) solo le serie di quel sito; con `keys` (da 1 a 5000 chiavi) solo
quelle. Non tutti e due. Solo con la `repair` fra le `features`; senza
permesso o cartella, `409 drive_not_ready`.

Risponde prima di finire, `{"repair": {"queued": true}}`. Una riparazione
alla volta per utente: se ce n'è già una, la nuova si somma a quella che
aspetta (tutta la libreria vince sul resto). La richiesta in attesa sta in
`repair.json` nella cartella dell'utente e sopravvive a un riavvio del server;
si cancella solo quando la riparazione finisce (se si ferma per rete o Drive
resta), e `kagami-server repair --user …` la scrive dal terminale. Non gira mentre il giro scarica:
il lavoro in corso si ferma fra un capitolo e l'altro e riprende dopo.
Mentre ripara, `GET /v2/jobs` ha `status.state` `running` con `jobId`
`repair` e `message` la serie a cui è. Le serie seguite (`GET /v2/ongoing`)
prendono la chiave adottata e perdono il `problem`; i capitoli archiviati a
metà tornano in coda come lavori `automatic`; un sito che risponde torna
sano in `check.sites`.

Ogni serie letta lascia un esito in `history`, con `repair` (assente negli
altri esiti):

```json
{"title": "Fog Land", "ok": true, "message": "…", "finishedAt": "…", "key": "coffeemanga:fog-land",
 "repair": {"key": "coffeemanga:fog-land", "title": "Fog Land", "adoptedFrom": "coffeemanga:7743",
            "renamed": {"88812": "chapter-1"}, "added": ["chapter-40"], "written": true}}
```

Campi di `repair`: `key`, `title`, `adoptedFrom`, `titleChanged`,
`coverChanged`, `seriesChanged`, `added`, `unlisted` (archiviati che il sito
non elenca più: restano), `renamed` (id vecchio → nuovo), `incomplete`
(rimessi in coda), `problems`, `error`, `written`. `ok` è `false` se c'è
`error`. Una serie senza cambiamenti lascia un esito senza `written`.

### `POST /v2/providers` → `200` — rilegge i siti degli utenti

Solo con `userProviders` fra le `features`. Il server rilegge subito
`providers/` dalla cartella di Drive di chi chiama (lo fa comunque prima di ogni
giro, controllo, riparazione e passata «Su altri siti») e risponde con
`{"providers": […], "sitesErrors": […]}` nella forma di `GET /v2/server`. Un
file che non si legge o non è valido non toglie il sito che il server aveva già:
resta quello di prima finché il file non torna valido o sparisce. Senza permesso
o cartella, `409`. L'app lo chiama dopo aver installato, aggiornato o tolto un sito.

### `GET /v2/elsewhere` — la stessa serie sugli altri siti

Solo con `elsewhere` fra le `features`. `?keys=a,b` (al più 200 chiavi) limita
la risposta a quelle serie; senza, tutte quelle viste.

```json
{"series": {"coffeemanga:fog-land": {
   "checkedAt": "…",
   "sites": {
     "mangak": {"state": "found", "checkedAt": "…", "key": "mangak:Q7", "url": "https://…",
                "title": "Fog Land", "chapters": 42, "latest": "41", "latestAt": "2026-10-27",
                "releaseStatus": "ongoing"},
     "asurascans": {"state": "missing", "checkedAt": "…"},
     "manhwaread": {"state": "gated", "checkedAt": "…"},
     "other": {"state": "error", "checkedAt": "…", "message": "…", "key": "…", "chapters": 30}}}},
 "pass": {"running": false, "startedAt": "…", "finishedAt": "…", "checked": 37, "pending": 12}}
```

Per ogni serie della libreria, i siti diversi dal suo (il suo lo dice
l'indice). `state`: `found` la serie c'è e la sua pagina si è letta;
`missing` la ricerca non la trova con nessuno dei suoi titoli (il titolo di
`library.json`, quello di `series.json` e gli alternativi, al più quattro);
`error` il sito ha risposto male questa volta; `broken` il sito è rotto
(`check.sites`), e non gli si è chiesto niente; `gated` il sito vuole la
verifica del browser e non è passata. Con uno stato diverso da `found`
restano i campi dell'ultima volta che c'era. `latest` è il numero
dell'ultimo capitolo (non il conteggio: un sito conta anche prologhi e
avvisi), e chi è avanti si decide da quello; `latestAt` è la data dell'ultimo
capitolo come la scrive il sito, se la scrive. `chapters` quanti capitoli elenca.
È un dato ricavato, non MALF: sta in `elsewhere.json` nella cartella
dell'utente, e il formato del pacchetto è `packages/kagami_archive/lib/elsewhere.dart`.

La passata parte dopo ogni controllo quotidiano, se `check.elsewhere`, e legge
`library.json` della propria cartella. Limiti, perché moltiplica le richieste
ai siti: al più 100 serie per passata, da quella vista meno di recente (una
libreria grande si completa in più giorni); una serie si riguarda dopo 20 ore,
una `completed` o `cancelled` sul suo sito dopo sette giorni; un sito alla
volta e due secondi fra una richiesta e l'altra; per sito, una serie già
trovata si rilegge dal suo link senza cercarla, una non trovata si ricerca solo
dopo sette giorni, e un sito rotto o dietro la verifica (senza `browser`) non si
chiede. Salta le serie di `unfollowed`, le schede senza link e quelle di un sito
che il server non conosce. Non gira mentre il giro scarica: si ferma fra una
serie e l'altra quando entra un lavoro e riprende a coda vuota. Un sito che
cambia forma durante la passata si dichiara rotto (`check.sites`). `pass`:
`running`, inizio e fine dell'ultima, serie lette e serie ancora da guardare.

### `POST /v2/elsewhere` → `202` — guarda subito alcune serie

```json
{"keys": ["coffeemanga:fog-land"]}
```

Da 1 a 50 chiavi, guardate prima della passata e anche se non sono da
riguardare, con gli stessi limiti per sito. L'app la chiede aprendo «Su altri
siti» di una serie mai vista o vista da più di 20 ore. Risponde `{"queued": 1}`;
il risultato arriva in `GET /v2/elsewhere`. Senza permesso o cartella, `409
drive_not_ready`.

## Utenti — solo il proprietario

Gli altri ricevono `403 owner_only`.

### `GET /v2/users`

```json
{"users": [
  {"email": "proprietario@gmail.com", "owner": true, "addedAt": "…", "connected": true},
  {"email": "amico@gmail.com", "owner": false, "addedAt": "…", "connected": false,
   "expiresAt": "2026-12-13T00:00:00.000Z"}
]}
```

`connected`: il server ha il permesso di Drive di quell'utente, cioè
l'utente ha già collegato il server dall'app. `expiresAt` c'è solo per un
accesso che scade (`expiry` fra le `features`); il proprietario non scade.

**Scadenza.** Alla scadenza il server toglie l'utente e cancella subito il
suo spazio, come con `DELETE /v2/users/{email}`: niente sospensione né
periodo di grazia. Un rinnovo (`PUT /v2/users/{email}`) vale quindi solo
prima della scadenza. Fino ad allora l'utente può sempre ritirare il suo
permesso di Drive (`DELETE /v2/me/drive`); dopo, lo spazio non esiste più e il
permesso resta nell'account Google dell'utente, che può revocarlo da lì. Il
server controlla le scadenze ogni ora e a ogni richiesta.

### `POST /v2/users` → `201`

```json
{"email": "amico@gmail.com", "expiresAt": "2026-12-13T00:00:00.000Z"}
```

Ammette l'account. Risponde con la riga dell'utente; un account già ammesso
risponde uguale. `expiresAt` è facoltativo (`expiry`): assente o `null`,
senza scadenza; una data passata o illeggibile è `400 bad_request`. Su un
account già ammesso, un `expiresAt` nel corpo (anche `null`) ne cambia la
scadenza. Avvisare l'utente è compito dell'app (vedi
[design.md](design.md), «Server e utenti»).

### `PUT /v2/users/{email}` → `200` — rinnova la scadenza (`expiry`)

```json
{"expiresAt": "2027-01-13T00:00:00.000Z"}
```

Cambia la scadenza, `null` la toglie; un accesso scaduto riparte. Risponde
con la riga dell'utente. `404 not_found` se l'account non è ammesso, `400
bad_request` sul proprietario o con una data passata o illeggibile.

### `DELETE /v2/users/{email}` → `204`

Toglie l'account: da subito le sue richieste ricevono `403`, il suo lavoro
in corso si ferma, e il server cancella il suo permesso di Drive, la sua coda
e le serie che seguiva. Ciò che è già sul suo Drive resta. Il proprietario
non si può togliere.
