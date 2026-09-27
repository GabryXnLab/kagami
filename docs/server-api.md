# API di Kagami Server — v1

Il contratto fra l'app e un server che scarica al posto del telefono. È
l'originale: l'implementazione di riferimento è `server/` in questo repo, e
qualunque altro server che risponda così funziona con Kagami. Una modifica
che cambia il significato di un campo è una `v2`; aggiungere campi no, e un
client ignora quelli che non conosce.

## Trasporto e chiave

- JSON UTF-8 su HTTP. Il server non fa TLS: l'HTTPS lo mette chi lo espone
  (Tailscale Funnel, un reverse proxy). In chiaro va bene solo in una rete
  privata o dentro una VPN (vedi [server.md](server.md)).
- Ogni richiesta sotto `/v1/` porta la chiave:
  `Authorization: Bearer kagami_…`. Senza chiave, o con una non valida: `401`
  con `WWW-Authenticate: Bearer realm="kagami-server"`.
- La chiave la crea il server (`kagami-server key create <nome>`), che ne
  tiene solo l'impronta SHA-256. Una per dispositivo, revocabile da sola.
- Il link di abbinamento `kagami://server?url=<indirizzo>&key=<chiave>` porta
  indirizzo e chiave insieme: l'app lo accetta incollato.

## Errori

Ogni errore ha lo stesso corpo, con un `code` stabile per il programma e un
`message` da mostrare all'utente:

```json
{"error": {"code": "drive_not_ready", "message": "Il server non ha ancora Drive: …"}}
```

| Stato | `code` | Quando |
| --- | --- | --- |
| 400 | `bad_request` | corpo non JSON, campo mancante o del tipo sbagliato |
| 400 | `unsupported_url` | il link non è di un sito che il server conosce |
| 400 | `bad_folder` | la cartella di Drive non c'è o il server non la vede |
| 401 | `unauthorized` | chiave mancante o non valida |
| 404 | `not_found` | indirizzo, lavoro o serie sconosciuti |
| 409 | `drive_not_ready` | il server non ha ancora il permesso di Drive o la cartella |
| 413 | `too_large` | corpo oltre 16 MB |
| 503 | `drive_offline` | Drive non risponde adesso |
| 500 | `internal` | guasto del server |

## Indirizzi

### `GET /` — senza chiave

```json
{"service": "kagami-server", "api": 1}
```

È l'unica risposta senza chiave: dice che lì c'è un Kagami Server e quale
API parla. La usano l'app, per dire «indirizzo giusto, chiave sbagliata», e
il controllo di salute di Docker.

### `GET /v1/server`

```json
{
  "service": "kagami-server", "version": "0.1.0", "api": 1,
  "name": "Kagami Server",
  "providers": [{"id": "mangak", "name": "MangaK"}, {"id": "manhwaread", "name": "ManhwaRead"}],
  "drive": {"authorized": true, "folderId": "1AbC…", "folderName": "MangaArchive"},
  "images": true,
  "check": {"minutes": 240}
}
```

- `drive.authorized`: il server ha il permesso di scrivere su Drive.
  `folderId` è la cartella della libreria dove finisce tutto: deve essere la
  stessa che legge l'app.
- `images`: il server fa miniature e tessere (MALF, «Tessere delle tavole
  alte»). Se è `false` la libreria resta valida, solo senza tessere.
- `check.minutes`: l'ora del controllo quotidiano delle serie in corso, in
  minuti dalla mezzanotte del server; `null` se è spento.

### `POST /v1/jobs` — mette in coda una serie

```json
{"url": "https://mangak.io/dungeon-odyssey", "title": "Dungeon Odyssey", "start": "16"}
```

| Campo | Tipo | |
| --- | --- | --- |
| `url` | stringa, obbligatorio | link della serie su un sito di `providers` |
| `title` | stringa | da mostrare finché il server non ha letto la serie |
| `start` | stringa o numero | dal capitolo con questo numero o id in poi |
| `ids` | elenco di stringhe | solo questi capitoli, per id; non insieme a `start` |
| `delayMs` | intero 0–5000 | pausa fra le richieste al sito (default 200) |
| `snapshot` | stringa | la pagina HTML della serie, solo per i siti dietro la verifica del browser (ManhwaRead) |

Senza `start` né `ids` si scarica tutta la serie. In ogni caso `series.json`
ha l'elenco completo dei capitoli (MALF). Lo stesso link già in coda viene
sostituito. Risponde `201`:

```json
{"job": {"id": "srv-…", "url": "…", "title": "Dungeon Odyssey", "start": "16", "delayMs": 200}}
```

`snapshot` serve perché il server non ha un browser per la verifica di
Cloudflare: la supera l'utente nella WebView del telefono, e il server legge
l'elenco dei capitoli da quella pagina. Le tavole le trova poi sul CDN del
sito. Se anche quello chiede la verifica, il lavoro finisce con un errore
che lo dice.

### `GET /v1/jobs` — a che punto è

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
annullato.

### `DELETE /v1/jobs/{id}` → `204`

Toglie il lavoro dalla coda; se è quello in corso lo ferma prima. Ciò che è
già su Drive resta, e rifare lo stesso download porta solo ciò che manca.

### `DELETE /v1/history` → `204`

Dimentica gli esiti.

### `GET /v1/ongoing` — le serie in corso che il server segue

```json
{"series": [{"key": "mangak:KY55w5Y9", "title": "…", "url": "…", "chapters": 169,
             "addedAt": "…", "checkedAt": "…", "problem": null}]}
```

Una serie che il sito dà `ongoing`, scaricata dal server, entra qui da sola;
il controllo quotidiano mette in coda solo i capitoli nuovi, e una serie
conclusa esce da sola.

### `DELETE /v1/ongoing/{key}` → `204`

Smette di seguire la serie. I capitoli già archiviati restano.

### `POST /v1/check` → `202`

Il controllo delle serie in corso, subito. Risponde prima di finire: i
capitoli nuovi compaiono in `GET /v1/jobs`.

### `PUT /v1/drive/folder` — sceglie la cartella della libreria

```json
{"folderId": "https://drive.google.com/drive/folders/1AbC…"}
```

Accetta l'id o il link. Il server controlla di vederla e di poterci entrare
col suo permesso, poi risponde con lo stesso `drive` di `GET /v1/server`.
Serve all'app per dire al server «usa la cartella che leggo io».
