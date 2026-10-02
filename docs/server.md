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

Nell'app: *Altro → Scarica un manga → Server → Crea il tuo server*.

1. Se non l'hai già fatto, l'app ti chiede di accedere con Google e di
   scegliere la cartella dei manga su Drive.
2. *Genera il comando*: Google ti chiede di permettere al server di scrivere
   sul tuo Drive. L'app prepara due comandi così:

   ```bash
   docker run -d --name kagami-server --restart unless-stopped \
     -p 8080:8080 -v kagami-data:/data \
     -e KAGAMI_SETUP=eyJ2IjoxLC… ghcr.io/gabryxnlab/kagami-server:latest
   docker run -d --name kagami-updater --restart unless-stopped --no-healthcheck \
     -u 0 -v /var/run/docker.sock:/var/run/docker.sock \
     ghcr.io/gabryxnlab/kagami-server:latest update
   ```

3. Copiali e incollali nel terminale del computer. Il primo scarica
   l'immagine, avvia il server e lo fa ripartire da solo dopo un riavvio; il
   secondo lo tiene aggiornato (vedi [Aggiornamenti](#aggiornamenti)).
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
docker rm -f kagami-server kagami-updater
docker run … # i comandi nuovi
```

Il volume `kagami-data` resta: code, utenti e serie seguite non si perdono.

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
  le sue serie in corso; nessuno vede la coda degli altri.

Togliendo un account, da subito il server non lo accetta più, il suo lavoro
in corso si ferma e il server cancella il suo permesso e la sua coda. Ciò
che è già sul suo Drive resta.

Chi si fa aggiungere al server di qualcun altro gli affida il permesso di
scrivere sul proprio Drive: l'app lo dice prima di chiederlo.

## Dal terminale del server

```bash
docker logs kagami-server                          # avvio, proprietario, errori
docker exec kagami-server kagami-server users      # account ammessi e chi ha collegato il Drive
docker exec kagami-server kagami-server status     # per ogni account: lavoro, coda, esiti
docker logs kagami-updater                         # controlli e aggiornamenti
```

Spegnendolo, i lavori in corso si fermano e restano in coda; alla
riaccensione ripartono da dove erano, senza riscaricare ciò che è già su
Drive.

## Aggiornamenti

Il contenitore `kagami-updater` (il secondo comando) è la stessa immagine
in un altro ruolo: ogni ora scarica `kagami-server:latest` e, se la CI del
repo pubblico ne ha pubblicata una nuova, ricrea il server con la stessa
configurazione — porta, volume, `KAGAMI_SETUP`, `TZ` — e l'immagine nuova,
poi fa lo stesso con sé stesso. Se il server sta scaricando aspetta che
finisca, al più sei ore: un lavoro interrotto riprende comunque da dove era.

Ha bisogno del socket di Docker e gira come root, per questo è un
contenitore a parte: il server, che parla con internet, resta senza. Si
aggiorna solo un'immagine presa da un registro (`ghcr.io/…`), non una
costruita dal sorgente né una fissata con `@sha256:`. Con Docker *rootless*
il socket sta altrove: nel comando va il suo percorso
(`-v $XDG_RUNTIME_DIR/docker.sock:/var/run/docker.sock`).

Un server creato prima che l'aggiornatore esistesse lo riceve lanciando
solo il secondo comando. Per spegnerlo: `docker rm -f kagami-updater`.
`--every <minuti>` dopo `update` cambia l'intervallo dei controlli.

## Controllo giornaliero dei capitoli nuovi

Ogni account ha il suo, e lo regola dall'app (*Altro → Scarica un manga →
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
  e quelle di ManhwaRead, dietro la verifica del browser, si saltano. Un
  capitolo che l'indice dà a metà si rimette in coda: se su Drive è intero
  il giro lo salta e ripara l'indice. Il telefono, finché è collegato, lascia
  al server le serie che scendono in quella cartella, per non scaricarle due
  volte.

`check.minutes` in `config.json` nel volume è l'ora di partenza per gli
account che non l'hanno ancora scelta (`null`: spento di partenza).

## ManhwaRead e Cloudflare

Il server non ha un browser per superare la verifica di Cloudflare. La supera
chi usa il telefono, nella schermata dell'app come sempre, e il telefono
manda al server la pagina della serie. Le tavole il server le prende dal CDN
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

## Chi compila la propria app

Il comando e l'accesso degli account funzionano con il progetto Firebase
dell'app che si usa. Chi compila la sua app (vedi il README) ha bisogno,
oltre a `google-services.json`:

- del **segreto del client «Web»** creato da Firebase (*Google Cloud
  Console → API e servizi → Credenziali → Web client (auto created by
  Google Service)*), passato con
  `--dart-define=GOOGLE_SERVER_CLIENT_SECRET=…` (secret
  `GOOGLE_SERVER_CLIENT_SECRET` nella CI). Senza, l'app dice che non può
  collegare server;
- dello scope `…/auth/drive` nella schermata di consenso del progetto, con
  l'app OAuth **in produzione**: in «Testing» Google fa scadere i permessi
  dopo sette giorni, e il server smetterebbe di scrivere;
- delle regole di `firestore.rules` pubblicate, per gli inviti.

Un'immagine sua la indica con `--dart-define=KAGAMI_SERVER_IMAGE=…`; di serie
il comando usa quella del progetto, che non contiene niente di personale.
