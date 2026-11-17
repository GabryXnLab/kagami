# Kagami Server

Un programma da tenere acceso su un computer qualsiasi (un mini PC, un NAS,
un Raspberry Pi, una VPS) che scarica le serie al posto del telefono e le
carica nella cartella di Drive della libreria di chi le chiede. Il telefono
sceglie cosa scaricare e poi può spegnersi. È lo stesso motore dell'app
(`packages/kagami_archive/`), quindi scrive la stessa libreria MALF e convive
con i download fatti dal telefono.

Chi lo usa lo dice l'account Google con cui si è fatto l'accesso all'app: il
server ha un proprietario, che può ammettere altri account, e ognuno scarica
sul proprio Drive con la propria coda.

Protocollo: [server-api.md](server-api.md).

## Cosa serve

- un computer sempre acceso con **Docker** (Linux x64 o arm64; su Windows e
  macOS Docker Desktop);
- l'app, con l'accesso a Google fatto.

Sul server non c'è niente da configurare né accessi da fare: tutto arriva
dal comando che genera l'app.

## 1. Crearlo dall'app

Nell'app: *Impostazioni → Scarica un manga → Server → Crea il tuo server*.

1. Se non l'hai già fatto, l'app ti chiede di accedere con Google e di
   scegliere la cartella dei manga su Drive.
2. *Genera il comando*: Google ti chiede di permettere al server di scrivere
   sul tuo Drive. L'app prepara due comandi così:

   ```bash
   docker network create --internal kagami-browser
   docker run -d --name kagami-browser --init --restart unless-stopped --no-healthcheck \
     --network kagami-browser -v kagami-browser:/data \
     ghcr.io/gabryxnlab/kagami-server:latest browser
   docker run -d --name kagami-server --init --restart unless-stopped \
     -p 8080:8080 -v kagami-data:/data -e KAGAMI_BROWSER=kagami-browser \
     -e KAGAMI_SETUP=eyJ2IjoxLC… ghcr.io/gabryxnlab/kagami-server:latest
   docker network connect kagami-browser kagami-server
   docker run -d --name kagami-updater --init --restart unless-stopped --no-healthcheck \
     -u 0 -v /var/run/docker.sock:/var/run/docker.sock \
     ghcr.io/gabryxnlab/kagami-server:latest update
   ```

3. Copiali e incollali nel terminale del computer. I primi due preparano la
   rete interna e il contenitore del Chromium (vedi [Il Chromium in un
   contenitore suo](#il-chromium-in-un-contenitore-suo)); il terzo scarica
   l'immagine, avvia il server e lo fa ripartire da solo dopo un riavvio, il
   quarto lo collega alla rete del Chromium; l'ultimo lo tiene aggiornato
   (vedi [Aggiornamenti](#aggiornamenti)).
   `--restart` serve anche a un'altra cosa: se un download resta un'ora senza
   avanzare, o il controllo dei capitoli nuovi quattro ore senza finire, il
   server esce (codice 75) e Docker lo riaccende; il lavoro riprende dalle
   tavole già scaricate.
4. Torna all'app e scrivi l'indirizzo del computer (vedi sotto): l'app
   verifica che il server ti riconosca come proprietario, e il server compare
   come destinazione, con la sua coda sotto quella del telefono.

`KAGAMI_SETUP` contiene il permesso di scrivere sul tuo Drive: **non mandare
il comando a nessuno**. Chi lo ha può scrivere sul tuo Drive, finché non
togli il permesso da <https://myaccount.google.com/connections>.

Il server applica la configurazione al primo avvio e ogni volta che cambia.
Per cambiare cartella o rinnovare il permesso generi un comando nuovo, e
ricrei il contenitore:

```bash
docker rm -f kagami-server kagami-updater kagami-browser
# poi i comandi nuovi, tutti
```

Il volume `kagami-data` resta: code, utenti e serie seguite non si perdono
(e `kagami-browser` i cookie delle verifiche già passate).

## 2. Farlo raggiungere dal telefono

All'app serve un indirizzo. Scegli il caso che fa per te, dal più semplice:

| Situazione | Come | Indirizzo nell'app |
| --- | --- | --- |
| Server e telefono sulla stessa rete di casa | niente da fare | `http://192.168.1.20:8080` |
| Da fuori casa, **senza dominio** (consigliato) | [Tailscale](https://tailscale.com) sul server e sul telefono: gratis, nessuna porta aperta sul router, il traffico è cifrato | `http://nome-server:8080` |
| Da fuori casa, senza VPN sul telefono | **Tailscale Funnel** (`tailscale funnel 8080`): un indirizzo HTTPS pubblico, sempre senza dominio e senza porte aperte | `https://nome-server.tailXXXX.ts.net` |
| Hai già un dominio | un reverse proxy con HTTPS davanti alla porta 8080 (Caddy, nginx) | `https://kagami.tuodominio.it` |

In chiaro (`http://`) il token del tuo account viaggia leggibile: va bene in
casa o dentro Tailscale, che cifra da sé, non su internet. Il server ascolta
in chiaro proprio per questo: l'HTTPS lo mette chi lo espone, e lo sa
rinnovare da sé.

Se ammetti altri account, anche loro devono poterlo raggiungere: dentro la
tua Tailscale (condividendo la macchina) o con un indirizzo HTTPS.

## 3. Chi può usarlo

Dall'app, sul server collegato: *Chi può usarlo*. Scrivi l'indirizzo Google
di chi vuoi:

- il server lo ammette subito;
- la sua app di Kagami riceve l'invito e lo avvisa con una notifica;
- collegando il server, dà il permesso di scrivere sul **suo** Drive, nella
  cartella della sua libreria. I suoi download vanno lì, con la sua coda e
  le sue serie in corso; nessuno vede la coda degli altri. Se la cartella
  non è sua (gliel'ha condivisa un altro) il server ci scarica ma non vi
  sposta mai niente nel cestino di Drive.

Chi ammetti entra con l'indirizzo dell'invito, che è quello con cui hai
collegato il server tu: la tua app lo garantisce al backend come indirizzo
del tuo server, e un biglietto chiesto per un altro indirizzo lì non vale
(`docs/server-api.md`, «Biglietto»). Se un amico deve usare un altro nome
dello stesso server, collegalo anche tu con quel nome una volta. Dopo
l'aggiornamento che ha introdotto questa regola, gli amici entrano solo dopo
che hai aperto il server almeno una volta dalla tua app.

Con un server che lo sa (`expiry`) accanto all'indirizzo si sceglie per
quanto ammetterlo: una settimana, un mese (proposto), tre mesi, un anno o
senza scadenza. Ogni riga dice «Scade il …», e *Rinnova* sceglie
una nuova durata, da adesso. Alla scadenza il server toglie l'utente e cancella
subito il suo spazio (niente sospensione); prima, l'utente può sempre
scollegare il suo Drive (protocollo in `docs/server-api.md`). Chi è ammesso con una
scadenza vede «Il tuo accesso scade il …» e, quando l'app legge il server a
meno di tre giorni dalla scadenza, riceve una notifica una volta sola.

Un server che lo sa (`shares`) fa valere anche il termine della libreria
condivisa (`docs/drive.md`): l'app gli affida le sue condivisioni con un
termine, e lui ne ritira il permesso su Drive entro un'ora dalla scadenza,
anche a telefono spento.

Togliendo un account, da subito il server non lo accetta più, il suo lavoro
in corso si ferma e il server cancella il suo permesso e la sua coda. Ciò
che è già sul suo Drive resta.

Chi si fa aggiungere al server di qualcun altro gli affida il permesso di
scrivere sul proprio Drive: l'app lo dice prima di chiederlo. Quel permesso
(un refresh token con l'accesso completo a Drive) sta in `drive.json` sul
volume del server, leggibile solo dall'utente del server (`0600`, come
`users.json`, `shares.json` e `setup.json`): chi ha il volume, o è root
sulla macchina, lo può usare. Non c'è modo di evitarlo, perché il server
carica sul Drive di ognuno anche a telefono spento.

**Rischio residuo.** Lo scope è `…/auth/drive` (tutto il Drive), non `drive.file`:
chi gestisce un server non proprio, una volta ammesso, ha un refresh token che
legge, scrive e cancella ovunque nel Drive di chi lo ha dato, non solo nella
cartella della libreria. L'app lo dice e chiede conferma prima di mandarlo a un
server che non è il proprio. La via vera è `drive.file` (solo i file creati
dall'app e dal server), un cambio di prodotto non ancora fatto.

**In chiaro.** Su `http://` verso un indirizzo non privato l'app rifiuta di mandare il
permesso di Drive (`PUT me/drive`): il refresh token viaggerebbe leggibile. Il resto
dell'`http://` resta consentito con l'avviso, come rischio dichiarato: il biglietto
col quale ci si identifica dura 10 minuti.

Ogni coda tiene al più 1000 lavori, e il server non apre indirizzi della
rete interna: le richieste ai siti (anche a ogni reindirizzamento) e il
Chromium dei controlli rifiutano gli host che risolvono in un indirizzo
privato, così un sito non porta il server sui metadati della macchina o sul
router. Chromium chiede al server il permesso per ogni richiesta, prima che
parta (`Fetch` di DevTools sul browser intero: pagina, reindirizzamenti con
302 o JavaScript, script, worker e service worker), e ne apre solo in `https`
verso host che non risolvono in un indirizzo privato; la pagina torna al motore
solo se è finita su un host del sito. I WebSocket, che `Fetch` non vede, li
ferma un proxy del server da cui passa ogni connessione di Chromium (loopback
compreso): risolve il nome una volta e si collega all'indirizzo controllato,
così per Chromium non c'è nemmeno la finestra del DNS rebinding. Per le
richieste del motore quella finestra resta, fra la risoluzione del nome e la
connessione.

**Rischi dichiarati del Chromium.** Dal proxy non passa l'UDP di WebRTC
(STUN e TURN), che una pagina può mandare verso la rete interna. E Chromium
gira con `--no-sandbox`: la sandbox chiede namespace utente o un binario
setuid, che il contenitore di un utente normale, col profilo seccomp di
Docker, non concede (misurato: anche l'helper setuid di `chromium-sandbox`
fallisce), e darglieli vorrebbe dire `--cap-add SYS_ADMIN` o un profilo
seccomp nel comando. Per questo Chromium sta in un contenitore suo (sotto):
un difetto del motore di rendering sfruttato da una pagina ostile non arriva
ai permessi di Drive. Chromium si accende solo nei controlli delle serie
dietro la verifica del browser.

### Il Chromium in un contenitore suo

Il contenitore `kagami-browser` è la stessa immagine col comando `browser`:
tiene acceso Chromium senza schermo e lo lascia guidare al server col
protocollo DevTools (porta 9222, mai pubblicata sull'host). Non ha il volume
`kagami-data` né `KAGAMI_SETUP`: ha solo il proprio profilo, nel volume
`kagami-browser`. Sta sulla rete `kagami-browser`, creata `--internal` e
quindi senza uscita verso internet; il server è collegato a quella e alla
rete di sempre. Chromium esce solo dal proxy del server
(`kagami-server:9223`), che accetta connessioni solo dall'indirizzo del
contenitore del browser e applica la guardia sugli indirizzi privati di
sopra. Il server lo trova con `KAGAMI_BROWSER=kagami-browser`.

Catalogo dei siti (facoltativo, `docs/catalogo.md`): `KAGAMI_CATALOG_URLS` e `KAGAMI_CATALOG_KEYS`
(vuoti o assenti: nessun catalogo; vincono sulle `CATALOG_*` dell'immagine, anche vuoti). La cache sta
in `catalog/` del volume. Chi compila l'immagine ne fissa il catalogo con
`docker build --build-arg CATALOG_URLS=… --build-arg CATALOG_KEYS=…`; senza, è vuoto.

Se il contenitore del browser manca o non risponde, il server non ripiega
sul Chromium locale: il log dice che il contenitore del browser non risponde
e le serie dietro la verifica restano col loro errore, come quando la
verifica non passa. Il resto del server funziona.

Un server creato prima di questa separazione (senza `KAGAMI_BROWSER`) usa
ancora il Chromium del proprio contenitore, insieme ai permessi di Drive, e
all'avvio lo dice. Per passare ai contenitori separati: genera il comando
nuovo nell'app e ricrea i contenitori come in [Crearlo dall'app](#1-crearlo-dallapp);
i volumi restano.

## Dal terminale del server

```bash
docker logs kagami-server                          # avvio, proprietario, errori
docker exec kagami-server kagami-server users      # account ammessi e chi ha collegato il Drive
docker exec kagami-server kagami-server status     # per ogni account: lavoro, coda, esiti
docker exec kagami-server kagami-server repair --user <email> [--site <id> | --keys k1,k2]
                                                   # mette in attesa la riparazione della libreria (repair.json)
docker logs kagami-updater                         # controlli e aggiornamenti
```

Spegnendolo, i lavori in corso si fermano e restano in coda; alla
riaccensione ripartono da dove erano, senza riscaricare ciò che è già su
Drive.

## La sentinella dei siti

```bash
kagami-server probe [--json] [--canaries catalog/canaries.json] [--site <id>]
```

Per ogni sito del registro (i provider inclusi, e quelli del catalogo se
`CATALOG_URLS`/`CATALOG_KEYS` sono configurati: usa la cache del volume e la
aggiorna) prova ricerca, serie, tavole del primo capitolo e i primi byte della
prima immagine, con il canarino del sito in `catalog/canaries.json` (una
`query` e/o l'`url` di una serie pubblica). Un sito senza canarino è `skipped`.
Esito per sito: `ok`, `changed` (`ProviderChanged`, risultati vuoti, struttura o
immagine inattesa, 4xx), `offline` (rete, timeout, 429/5xx), `gated` (verifica
di Cloudflare o 403), con la fase (`search`, `series`, `pages`, `image`).
Uscita: 0 se tutti ok, 1 se qualcuno no, 2 per un uso sbagliato. Senza `--json`
una riga per sito; con `--json` un solo oggetto
`{checkedAt, engine, serial, sites: [{site, status, phase, message, durationMs, version, origin}]}`
(`version` è la versione della definizione, `null` per i siti inclusi).

### Guasto, degradato, più canarini

Voci R1.3 e R2.2 di `handoff/siti-robusti/`, fatte; `kagami-server probe
--definition`, `--capture` e `--layers all` (R5.1) sono in
`server/lib/src/probe_run.dart`. I campi nuovi si aggiungono a quelli di ora, che restano,
così chi legge il JSON di prima continua a capirlo.

Per sito, nel JSON:

- `fault`: `{phase, field, detail}`, il guasto del `ProviderChanged`
  (`docs/siti.md` § «Diagnosi»), presente quando lo stato non è `ok`. `phase`
  aggiunge `chapters` a quelle di prima; per un 4xx la sonda lo scrive da sé,
  con la fase e `detail: "HTTP 404"`. `url` non c'è: la sonda conosce già il
  canarino, e l'indirizzo esatto sta nella cassetta di `--capture`.
- `degraded`: lista, vuota se niente è degradato. Con `ok` dice quali
  alternative di `first`/`try` hanno vinto senza essere le prime
  (`["series.title#2"]`): il sito va, ma la ridondanza si sta consumando.

Canarini multipli: in `catalog/canaries.json` un sito può avere fino a 3
canarini, una lista al posto dell'oggetto singolo, che resta valido. Ognuno
può dire `minChapters`: meno capitoli di così è `changed`, perché un elenco
tagliato dall'API passa altrimenti per buono.

```json
"mangak": [
  {"query": "solo leveling", "url": "https://mangak.io/solo-leveling", "minChapters": 200},
  {"url": "https://mangak.io/omniscient-reader", "minChapters": 150}
]
```

Lo stato del sito è il migliore fra i suoi canarini: un canarino che fallisce
da solo è più spesso una serie tolta che un sito cambiato. I canarini falliti
finiscono in `degraded` come `canary#<n>` (contati da 1), con il loro `fault`
in `canaries: [{n, status, fault}]`, così l'avviso li mostra senza spegnere il
sito. L'immagine contiene `catalog/canaries.json`, e il default di
`--canaries` funziona anche dentro il contenitore.

Opzioni nuove:

| Opzione | Cosa |
|---|---|
| `--definition <file>` | prova una definizione dal file, al posto di quella del registro con lo stesso id: una correzione si prova dal vivo prima di firmarla. Esclude `--layers` |
| `--capture <dir>` | per ogni sito non `ok` registra il giro in una cassetta in `<dir>/<id>/<data>-guasto/` (formato in `docs/manutenzione-siti.md` § «Cassette»): la pagina del guasto com'era in quel momento |
| `--layers all` | prova ogni strato del sito separatamente (catalogo e incluso), una voce per strato con il suo `origin`, invece del solo strato che vince nel registro. Serve a sapere se l'auto-ripiego ha ancora un incluso che funziona (`docs/catalogo.md` § «Il registro: chi vince») |

## Aggiornamenti

Il contenitore `kagami-updater` (il secondo comando) è la stessa immagine
in un altro ruolo: ogni ora scarica `kagami-server:latest` e, se la CI del
repo pubblico ne ha pubblicata una nuova, ricrea il server con la stessa
configurazione — porta, volume, `KAGAMI_SETUP`, `TZ` — e l'immagine nuova,
poi fa lo stesso con `kagami-browser`, se c'è, e con sé stesso. Il
contenitore ricreato torna su tutte le reti del vecchio, compresa quella
del browser. Se il server sta scaricando aspetta che
finisca, al più sei ore: un lavoro interrotto riprende comunque da dove era.

Ha bisogno del socket di Docker e gira come root, per questo è un
contenitore a parte: il server, che parla con internet, resta senza. Si
aggiorna solo un'immagine presa da un registro (`ghcr.io/…`), non una
costruita dal sorgente né una fissata con `@sha256:`. Con Docker *rootless*
il socket sta altrove: nel comando va il suo percorso
(`-v $XDG_RUNTIME_DIR/docker.sock:/var/run/docker.sock`).

Il rischio: chi ha il socket di Docker comanda la macchina, e
l'aggiornatore installa ciò che il registro gli dà sotto `latest`, senza
un'impronta fissata. Chi controllasse quell'immagine nel registro
controllerebbe la macchina. Nessuna rotta dell'API lo raggiunge (il server
non ha il socket). Chi non vuole correre il rischio non lancia il secondo
comando, o lo spegne, e aggiorna a mano con `docker pull` e ricreando il
server con lo stesso comando.

Un server creato prima che l'aggiornatore esistesse lo riceve lanciando
solo il secondo comando. Per spegnerlo: `docker rm -f kagami-updater`.
`--every <minuti>` dopo `update` cambia l'intervallo dei controlli.

## Controllo giornaliero dei capitoli nuovi

Ogni account ha il suo, e lo regola dall'app (*Impostazioni → Scarica un manga →
Server*): acceso o spento, a che ora (ora del server: `-e TZ=Europe/Rome`
nel comando per la tua) e su cosa.

- **Serie in corso del server**: quelle che il sito dà `ongoing` e che ha
  scaricato il server. Mette in coda solo i capitoli nuovi; una serie
  conclusa esce da sola.
- **Tutta la libreria su Drive** (acceso di partenza): anche ogni serie di
  `library.json`, chiunque l'abbia scaricata — il telefono, il server o un
  altro archiviatore. Sono nuovi i capitoli del sito che l'`index.json`
  della serie non elenca: chi ha scaricato dal capitolo 16 in poi non si
  ritrova in coda i precedenti. Le serie concluse non si chiedono al sito,
  e quelle di ManhwaRead, dietro la verifica del browser, si leggono con
  Chromium (sotto) o, se la verifica non passa, finiscono fra gli errori. Un
  capitolo che l'indice dà a metà si rimette in coda: se su Drive è intero
  il giro lo salta e ripara l'indice. Si saltano le serie per cui nell'app si è
  toccato «Smetti di seguire». Se nell'app si è scelto che controlli il
  server, il telefono non controlla niente; se si è scelto il telefono, il
  controllo del server si spegne.

`check.minutes` in `config.json` nel volume è l'ora di partenza per gli
account che non l'hanno ancora scelta (`null`: spento di partenza).

## ManhwaRead e Cloudflare

Per scaricare una serie nuova la verifica di Cloudflare la supera chi usa il
telefono, nella schermata dell'app come sempre, e il telefono manda al server
la pagina della serie. Per i controlli quotidiani il server apre la pagina con
il Chromium del contenitore `kagami-browser` (fuori da Docker quello della
macchina, `KAGAMI_CHROMIUM` per indicarne un altro), senza
schermo: passa la verifica che si risolve da sola, non quella che chiede di
spuntare «Verify you are human», che capita soprattutto dagli indirizzi dei
data center. Allora quella serie resta in attesa (`check.gated`): il telefono
lo avvisa con una notifica, la verifica la passa chi lo usa, e il telefono
manda al server le pagine di quelle serie (`POST /v2/check/pages`), che le
controlla subito. Lo stesso vale per «Ripara la serie»: la pagina la apre il
telefono e il server ripara quella serie subito (`POST /v2/repair/pages`);
la riparazione di un sito intero o della libreria non passa dal telefono, e queste serie possono fermarsi alla verifica.
Le tavole il server le prende dal CDN
del sito. Se il sito blocca anche quello dall'indirizzo del server, il lavoro
finisce con un errore che lo dice, e quella serie va scaricata dal telefono.

## Senza Docker, o dal sorgente

L'immagine si costruisce dalla radice del repo, perché il server usa il
motore di `packages/kagami_archive`:

```bash
docker build -f server/Dockerfile -t kagami-server .
cd server && KAGAMI_SETUP=<dall'app> docker compose up -d
```

Oppure un eseguibile unico, con Dart 3.13 (Linux, macOS, Windows) e, per
miniature e tessere, `libvips` (`apt install libvips-tools`; senza, la
libreria è valida lo stesso, solo senza tessere delle tavole alte):

```bash
cd server
dart pub get
dart compile exe bin/kagami_server.dart -o kagami-server
./kagami-server serve --setup <dall'app>    # 0.0.0.0:8080; --port per un'altra porta
```

I dati stanno in `~/.local/share/kagami-server`, oppure dove indicano
`--data` o `KAGAMI_DATA`. Dopo il primo avvio `--setup` non serve più.

## Il backend degli account

Il server riconosce chi chiama da un **biglietto** a tempo, legato al suo `id`
(nasce al primo avvio nel volume), che il backend rilascia all'app: il token
della sessione non gli arriva più, tranne che al proprio server di chi l'ha
creato se non ci sono biglietti. Un server di prima va aggiornato rifacendo il
comando di avvio; un collegamento di prima dei biglietti si adotta da solo al
primo contatto riuscito. Dettagli in [server-api.md](server-api.md), «Chi
chiama». Il backend è quello compatibile Supabase di chi compila (il
manutentore usa Hestia) e, nel passaggio, vale ancora l'ID token di Firebase. Di solito arriva tutto da `KAGAMI_SETUP`;
queste variabili valgono al suo posto:

| Variabile | |
| --- | --- |
| `KAGAMI_BACKEND_URL` | la radice del backend, es. `https://backend.example.com`: accetta i token con emittente `<url>/auth/v1` |
| `KAGAMI_BACKEND_ANON_KEY` | la chiave pubblica `anon` del backend: il gateway la vuole (`apikey`) anche per `GET /auth/v1/user`. Va data insieme all'indirizzo |
| `KAGAMI_FIREBASE_PROJECT` | il progetto Firebase di cui accettare ancora gli ID token, per le app di prima del backend |

Il server non ha il segreto del backend: verifica la firma con le chiavi
pubbliche (`/auth/v1/.well-known/jwks.json`, solo RS256) se il backend le
pubblica, altrimenti chiede al backend chi è il token (`/auth/v1/user`) e se
lo ricorda fino alla sua scadenza. Un backend che non risponde fa rispondere
`503 identity_unavailable`, non «token non valido».

**Il server si fida del backend per l'indirizzo**: ammette chi ha fatto
l'accesso con Google (`app_metadata.providers` contiene `google`) e lo
riconosce dall'`email` che il backend dichiara. Il backend deve quindi
confermare gli indirizzi: accesso solo con Google, o conferma dell'email
obbligatoria per gli altri metodi.

Un server creato prima del backend (configurazione senza `backend`)
continua ad accettare i token di Firebase del suo `project` anche dopo
l'aggiornamento. Con una configurazione che ha il backend, Firebase si
accetta solo con `KAGAMI_FIREBASE_PROJECT`. Senza backend e senza progetto
Firebase il server lo dice all'avvio e ogni richiesta risponde
`503 not_configured`.

## Chi compila la propria app

Il comando e l'accesso degli account funzionano con il backend e il progetto
Google dell'app che si usa. Chi compila la sua app (vedi il README) ha bisogno,
oltre a `google-services.json`:

- del **segreto del client «Web»** del progetto Google (*Google Cloud
  Console → API e servizi → Credenziali → Web client (auto created by
  Google Service)*), passato con
  `--dart-define=GOOGLE_SERVER_CLIENT_SECRET=…` (secret
  `GOOGLE_SERVER_CLIENT_SECRET` nella CI). Senza, l'app dice che non può
  collegare server;
- dello scope `…/auth/drive` nella schermata di consenso del progetto, con
  l'app OAuth **in produzione**: in «Testing» Google fa scadere i permessi
  dopo sette giorni, e il server smetterebbe di scrivere;
- dello schema di `backend/` applicato al proprio backend, per gli inviti (`backend/README.md`).

Un'immagine sua la indica con `--dart-define=KAGAMI_SERVER_IMAGE=…`; di serie
il comando usa quella del progetto, che non contiene niente di personale.
