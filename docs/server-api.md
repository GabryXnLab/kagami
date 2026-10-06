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

Ogni richiesta sotto `/v2/` porta il token d'identità di Firebase
dell'account con cui si è fatto l'accesso all'app:
`Authorization: Bearer <ID token>`. È un JWT firmato da Google che dura
un'ora; l'app ne chiede uno nuovo da sé (`getIdToken`), senza schermate.

Il server lo accetta se:

- la firma RS256 torna con una delle chiavi pubbliche di
  `securetoken@system.gserviceaccount.com`
  (`https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com`);
- `aud` è il progetto Firebase della configurazione e `iss` è
  `https://securetoken.google.com/<progetto>`;
- `exp` non è passato e `iat` non è nel futuro (un minuto di tolleranza);
- l'accesso è con Google (`firebase.sign_in_provider` = `google.com`),
  `email` c'è ed `email_verified` è vero.

L'utente è l'indirizzo `email`, in minuscolo. Token mancante o non valido:
`401` con `WWW-Authenticate: Bearer realm="kagami-server"`. Token valido di
un account che non è nell'elenco: `403 not_allowed`.

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
| `project` | il progetto Firebase dell'app: `aud` dei token accettati |
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
| 401 | `unauthorized` | token mancante, scaduto o non valido |
| 403 | `not_allowed` | l'account non è fra quelli ammessi |
| 403 | `owner_only` | l'operazione è del proprietario |
| 404 | `not_found` | indirizzo, lavoro, serie o utente sconosciuti |
| 409 | `drive_not_ready` | il server non ha il permesso di Drive di chi chiama, o la sua cartella |
| 413 | `too_large` | corpo oltre 16 MB |
| 503 | `not_configured` | il server è partito senza `KAGAMI_SETUP` |
| 503 | `drive_offline` | Google non risponde adesso |
| 500 | `internal` | guasto del server |

## Indirizzi

### `GET /` — senza token

```json
{"service": "kagami-server", "api": 2}
```

È l'unica risposta senza token: dice che lì c'è un Kagami Server e quale API
parla. La usano l'app, per dire «indirizzo giusto, server da aggiornare», e
il controllo di salute di Docker.

### `GET /v2/server`

```json
{
  "service": "kagami-server", "version": "0.2.0", "api": 2,
  "name": "Il server di Gabry",
  "owner": "proprietario@gmail.com",
  "providers": [{"id": "mangak", "name": "MangaK"}, {"id": "manhwaread", "name": "ManhwaRead"},
                {"id": "asurascans", "name": "Asura Scans"}],
  "images": true,
  "check": {"minutes": 240, "time": 240, "enabled": true, "library": true,
            "checkedAt": "…", "checked": 12, "queued": 2, "failed": 0},
  "me": {
    "email": "amico@gmail.com", "owner": false,
    "drive": {"authorized": true, "folderId": "1XyZ…", "folderName": "Manga"}
  }
}
```

- `me` è chi chiama. `me.drive.authorized`: il server ha il suo permesso di
  scrivere su Drive; `folderId` è la cartella della sua libreria, dove
  finisce tutto ciò che mette in coda.
- `images`: il server fa miniature e tessere (MALF, «Tessere delle tavole
  alte»). Se è `false` la libreria resta valida, solo senza tessere.
- `check` è il controllo quotidiano di chi chiama (`PUT /v2/check`):
  `time` l'ora, in minuti dalla mezzanotte del server; `minutes` la stessa
  ora, `null` se è spento (`enabled`), come per i client di prima;
  `library` se guarda tutta la libreria su Drive; `checkedAt`, `checked`,
  `queued`, `failed` com'è andato l'ultimo: serie controllate, con capitoli
  nuovi, con errori.

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

Va nella coda di chi chiama e sul suo Drive, nella sua cartella: senza
permesso o cartella, `409 drive_not_ready`. Senza `start` né `ids` si
scarica tutta la serie. In ogni caso `series.json` ha l'elenco completo dei
capitoli (MALF). Lo stesso link già in coda viene sostituito. Risponde
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
venti esiti, dal più recente. Sono gli stessi campi della coda del telefono.
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
             "addedAt": "…", "checkedAt": "…", "problem": null}]}
```

Una serie che il sito dà `ongoing`, scaricata dal server, entra qui da sola;
il controllo quotidiano mette in coda solo i capitoli nuovi, e una serie
conclusa esce da sola. Sono quelle di chi chiama.

### `DELETE /v2/ongoing/{key}` → `204`

Smette di seguire la serie. I capitoli già archiviati restano.

### `PUT /v2/check` — regola il proprio controllo quotidiano

```json
{"enabled": true, "minutes": 270, "library": true}
```

Ogni campo è facoltativo: cambia solo ciò che c'è. `minutes` da 0 a 1439.
Risponde con lo stesso `check` di `GET /v2/server`.

Con `library` il controllo guarda, oltre alle serie di `GET /v2/ongoing`,
ogni serie del `library.json` della propria cartella: mette in coda (lavori
`automatic`) i capitoli del sito che l'`index.json` della serie non elenca,
e quelli che l'indice dà a metà, che il giro salta se su Drive sono interi
riscrivendo l'indice. Salta le serie concluse (senza chiederle al sito),
quelle già in coda e quelle dei siti con la verifica del browser.

### `POST /v2/check` → `202`

Il controllo quotidiano di chi chiama, subito, anche se è spento. Risponde prima di
finire: i capitoli nuovi compaiono in `GET /v2/jobs`.

## Utenti — solo il proprietario

Gli altri ricevono `403 owner_only`.

### `GET /v2/users`

```json
{"users": [
  {"email": "proprietario@gmail.com", "owner": true, "addedAt": "…", "connected": true},
  {"email": "amico@gmail.com", "owner": false, "addedAt": "…", "connected": false}
]}
```

`connected`: il server ha il permesso di Drive di quell'utente, cioè
l'utente ha già collegato il server dall'app.

### `POST /v2/users` → `201`

```json
{"email": "amico@gmail.com"}
```

Ammette l'account. Risponde con la riga dell'utente; un account già ammesso
risponde uguale. Avvisare l'utente è compito dell'app (vedi
[design.md](design.md), «Server e utenti»).

### `DELETE /v2/users/{email}` → `204`

Toglie l'account: da subito le sue richieste ricevono `403`, il suo lavoro
in corso si ferma, e il server cancella il suo permesso di Drive, la sua coda
e le serie che seguiva. Ciò che è già sul suo Drive resta. Il proprietario
non si può togliere.
