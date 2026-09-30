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
   sul tuo Drive. L'app prepara un comando così:

   ```bash
   docker run -d --name kagami-server --restart unless-stopped \
     -p 8080:8080 -v kagami-data:/data \
     -e KAGAMI_SETUP=eyJ2IjoxLC… ghcr.io/gabryxnlab/kagami-server:latest
   ```

3. Copialo e incollalo nel terminale del computer. Scarica l'immagine, la
   avvia e la fa ripartire da sola dopo un riavvio.
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
docker rm -f kagami-server
docker run … # il comando nuovo
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
docker pull ghcr.io/gabryxnlab/kagami-server:latest # aggiornare: poi rm -f e lo stesso comando
```

Spegnendolo, i lavori in corso si fermano e restano in coda; alla
riaccensione ripartono da dove erano, senza riscaricare ciò che è già su
Drive.

## Serie in corso

Le serie che il sito dà per `ongoing`, scaricate dal server, le segue lui,
per ogni account: ogni giorno alle 4:00 (ora del server: `-e TZ=Europe/Rome`
nel comando per la tua; `check.minutes` in `config.json` nel volume, `null`
per spegnerlo) mette in coda solo i capitoli nuovi.

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
