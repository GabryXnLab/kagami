# Kagami Server

Un programma da tenere acceso su un computer qualsiasi (un mini PC, un NAS,
un Raspberry Pi, una VPS) che scarica le serie al posto del telefono e le
carica nella cartella di Drive della libreria. Il telefono sceglie cosa
scaricare e poi può spegnersi. È lo stesso motore dell'app
(`packages/kagami_archive/`), quindi scrive la stessa libreria MALF e convive
con i download fatti dal telefono.

Protocollo: [server-api.md](server-api.md).

## Cosa serve

- Docker, oppure Dart 3.13 su Linux (x64 o arm64), macOS o Windows;
- senza Docker, `libvips` (`apt install libvips-tools`) per miniature e
  tessere. Senza, funziona lo stesso: la libreria è valida, solo senza
  tessere delle tavole alte. L'immagine Docker lo ha già;
- un account Google con la cartella della libreria su Drive.

## 1. Avviare

### Con Docker (consigliato)

```bash
git clone <repo> kagami && cd kagami/server
docker compose up -d
docker compose logs kagami-server      # la prima chiave API
```

I dati stanno nel volume `kagami-data`, e l'ora del controllo delle serie in
corso segue `TZ` in `docker-compose.yml`. I comandi di questa guida si danno
dentro al contenitore, con
`docker compose exec kagami-server kagami-server <comando>`: per esempio
`… drive login`. Il client OAuth del passo 2 si può scrivere anche in
`docker-compose.yml` (`KAGAMI_GOOGLE_CLIENT_ID`, `KAGAMI_GOOGLE_CLIENT_SECRET`)
invece di passarlo a `drive login`. Nel contenitore il browser non arriva
all'indirizzo di ritorno: alla fine dell'accesso si incolla sempre
l'indirizzo copiato dalla barra.

### Senza Docker

```bash
cd server
dart pub get
dart compile exe bin/kagami_server.dart -o kagami-server
./kagami-server serve            # 0.0.0.0:8080; --port per un'altra porta
```

Al primo avvio stampa una **chiave API**. Copiala subito: il server ne tiene
solo l'impronta e non potrà più mostrarla. I dati stanno in
`~/.local/share/kagami-server`, oppure dove indicano `--data` o
`KAGAMI_DATA`.

## 2. Dare al server il permesso di Drive

Il server scrive su Drive con un permesso suo, che non scade quando il
telefono si spegne. Per averlo serve un **client OAuth tuo**: Kagami non può
distribuirne uno per tutti, perché Google chiede una verifica a pagamento a
chi apre l'accesso completo a Drive a chiunque. Richiede cinque minuti e si
fa una volta sola:

1. Su <https://console.cloud.google.com> crea un progetto.
2. *API e servizi → Libreria*: abilita **Google Drive API**.
3. *Google Auth Platform* (schermata di consenso OAuth): tipo **Esterno**,
   un nome qualsiasi, la tua email. Poi, in *Pubblico*, **pubblica l'app**
   («In produzione»). È importante: con l'app «In test» Google fa scadere il
   permesso dopo sette giorni. Non serve farla verificare, perché la usi
   solo tu.
4. *Client → Crea client*: tipo **App desktop**. Copia ID client e segreto.

Poi, sul server:

```bash
./kagami-server drive login --client-id <ID> --client-secret <SEGRETO>
```

Stampa un indirizzo: aprilo in un browser qualsiasi, anche sul telefono, e
concedi l'accesso. Google avvisa che l'app non è verificata: è la tua, quindi
*Avanzate → Vai a …*. Se il browser non è sulla stessa macchina del server,
alla fine mostra una pagina che non si carica (`http://127.0.0.1:…`): copia
l'indirizzo intero dalla barra e incollalo nel terminale.

Infine scegli la cartella della libreria, la stessa che legge l'app:

```bash
./kagami-server drive folder https://drive.google.com/drive/folders/<id>
./kagami-server drive status
```

La cartella la può scegliere anche l'app, dalla sezione Server.

## 3. Farlo raggiungere dal telefono

All'app servono un indirizzo e la chiave. Scegli il caso che fa per te,
dal più semplice:

| Situazione | Come | Indirizzo nell'app |
| --- | --- | --- |
| Server e telefono sulla stessa rete di casa | niente da fare | `http://192.168.1.20:8080` |
| Da fuori casa, **senza dominio** (consigliato) | [Tailscale](https://tailscale.com) sul server e sul telefono: gratis, nessuna porta aperta sul router, il traffico è cifrato | `http://nome-server:8080` |
| Da fuori casa, senza VPN sul telefono | **Tailscale Funnel** (`tailscale funnel 8080`): un indirizzo HTTPS pubblico, sempre senza dominio e senza porte aperte | `https://nome-server.tailXXXX.ts.net` |
| Hai già un dominio | un reverse proxy con HTTPS davanti alla porta 8080 (Caddy, nginx) | `https://kagami.tuodominio.it` |

In chiaro (`http://`) la chiave viaggia leggibile: va bene in casa o dentro
Tailscale, che cifra da sé, non su internet. Il server ascolta in chiaro
proprio per questo: l'HTTPS lo mette chi lo espone, e lo sa rinnovare da sé.

Per un indirizzo e una chiave insieme, da incollare nell'app:

```bash
./kagami-server key create "Telefono" --url https://nome-server.tailXXXX.ts.net
```

## Chiavi

```bash
./kagami-server key create "Tablet"     # una per dispositivo
./kagami-server key list
./kagami-server key revoke Tablet       # vale subito, anche col server acceso
```

## Tenerlo acceso

Con systemd, in `~/.config/systemd/user/kagami-server.service`:

```ini
[Unit]
Description=Kagami Server

[Service]
ExecStart=%h/kagami-server/kagami-server serve
Restart=on-failure

[Install]
WantedBy=default.target
```

```bash
systemctl --user enable --now kagami-server
loginctl enable-linger "$USER"      # resta acceso anche senza una sessione aperta
```

`./kagami-server status` mostra lavoro in corso, coda e ultimi esiti.
Spegnendolo, il lavoro in corso si ferma e resta in coda; alla riaccensione
riparte da dove era, senza riscaricare ciò che è già su Drive.

## Serie in corso

Le serie che il sito dà per `ongoing`, scaricate dal server, le segue lui:
ogni giorno alle 4:00 (ora del server; `check.minutes` in `config.json`,
`null` per spegnerlo) mette in coda solo i capitoli nuovi.

## ManhwaRead e Cloudflare

Il server non ha un browser per superare la verifica di Cloudflare. La supera
chi usa il telefono, nella schermata dell'app come sempre, e il telefono
manda al server la pagina della serie. Le tavole il server le prende dal CDN
del sito. Se il sito blocca anche quello dall'indirizzo del server, il lavoro
finisce con un errore che lo dice, e quella serie va scaricata dal telefono.
