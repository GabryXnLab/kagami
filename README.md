# Kagami

Lettore di manga per Android che presenta una libreria come un lettore
musicale presenta una discoteca: raccolte, ripresa della lettura, stato e voto
per ogni serie, cronologia e statistiche. La libreria può stare in una cartella
del telefono, su Google Drive (letta in streaming) o in tutti e due i posti.

Kagami sa anche riempirla da sé. Da **Altro → Scarica un manga** si cerca una
serie sui siti supportati, o se ne incolla il link, e la si scarica nella
cartella di Drive o sul telefono. Chi non vuole tenere il telefono acceso per
ore può farla scaricare al proprio **Kagami Server**, un programma da tenere
acceso su un computer qualsiasi.

## Scaricare l'app

L'APK firmato di ogni versione è nelle
[Releases](https://github.com/GabryXnLab/kagami/releases), con il suo SHA-256.
Usa il progetto Firebase del manutentore per account e Drive; per usarne uno
proprio si compila da sé (sotto, «Farsi il proprio Kagami»).

## Come è fatto

- **La libreria è un formato aperto**, [MALF](docs/malf.md): cartelle, manifest
  e tre indici derivati che permettono di disegnare la libreria con una lettura
  invece di una per capitolo. Chiunque scriva MALF può riempire la libreria
  di Kagami, e Kagami non dipende da nessun altro programma.
- **Il motore che scarica** è un pacchetto Dart senza Flutter
  ([`packages/kagami_archive`](packages/kagami_archive)): lo usano l'app e il
  server, quindi scrivono la stessa libreria e convivono nella stessa cartella.
- **Kagami Server** ([`server/`](server)) mette quel motore dietro un'API con
  chiave ([protocollo](docs/server-api.md)). Si installa con Docker o come
  eseguibile unico, e si raggiunge in casa, con Tailscale (anche senza un
  dominio) o con un reverse proxy: [guida](docs/server.md).
- I dati personali (stato, cronologia, raccolte, impostazioni) stanno in un
  database dell'app, si esportano in un backup e, con l'accesso Google, seguono
  il lettore da un telefono all'altro.

## Server in breve

```bash
cd server
docker compose up -d
docker compose logs kagami-server                           # la chiave API
docker compose exec kagami-server kagami-server drive login
docker compose exec kagami-server kagami-server drive folder <link della cartella>
```

Poi, nell'app: Scarica un manga → Server → indirizzo e chiave. Il client OAuth
di Google da creare una volta e i modi per raggiungere il server da fuori casa
sono in [docs/server.md](docs/server.md).

## Farsi il proprio Kagami

Nel repo non c'è nessun servizio del manutentore: progetto Firebase, Sentry,
chiave di firma e server sono di chi compila. Tutto ciò che segue è
facoltativo, e l'app si adatta a quello che trova.

| Con | L'app ha |
| :--- | :--- |
| niente | libreria in una cartella del telefono, lettore, stato, voti, raccolte, cronologia, statistiche, backup su file, download dai siti sul telefono |
| `android/app/google-services.json` | in più: accesso con Google, dati personali che seguono il lettore, libreria su Drive, sincronizzazione della cartella, download verso Drive |
| `--dart-define=SENTRY_DSN=…` | in più: errori e crash sul proprio progetto Sentry |
| un Kagami Server | in più: download fatti da un computer acceso invece che dal telefono |

### Compilare l'APK

Serve Flutter 3.47 (Linux, macOS o Windows; x64 o arm64) con l'SDK Android
e Java 17, oppure il devcontainer in `.devcontainer/` (Codespaces compreso):

```bash
flutter pub get
flutter build apk --release
```

Senza altro, la release si firma con la chiave di debug della macchina. Per
firmare con la propria si crea `android/key.properties`, che git ignora:

```properties
storeFile=/percorso/della/chiave.jks
storePassword=…
keyAlias=…
keyPassword=…
```

Senza una macchina adatta si fa un fork e si lancia **CI** dalla scheda
Actions: l'APK arriva fra gli artefatti del run. Quali secret accendono cosa
è in [.github/workflows/CLAUDE.md](.github/workflows/CLAUDE.md).

### Account e Drive: il proprio progetto Firebase

1. Su <https://console.firebase.google.com> crea un progetto.
2. *Authentication → Metodo di accesso*: attiva **Google**.
3. *Firestore Database*: crea il database, poi carica le regole del repo, che
   lasciano a ognuno solo il proprio documento:
   `firebase deploy --only firestore:rules --project <id-del-progetto>`.
4. *Impostazioni del progetto → Aggiungi app → Android*: pacchetto
   `dev.local.kagami` e l'impronta SHA-1 della chiave con cui firmi l'APK.
   Per la chiave di debug:
   `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android`.
   Una chiave diversa, una SHA-1 in più: con una chiave non registrata
   l'accesso con Google fallisce.
5. Scarica `google-services.json` (dopo il passo 2, perché contenga il client
   di Google) e mettilo in `android/app/`. Git lo ignora.
6. Per Drive, sulla [console di Google Cloud](https://console.cloud.google.com)
   dello stesso progetto: abilita **Google Drive API**, e nella schermata di
   consenso OAuth aggiungi gli scope `drive.readonly` e `drive` e il tuo
   account fra gli utenti di test.

Ricompila, e in *Altro → Impostazioni* compaiono «Account» e «Google Drive».

### Il server

È in [docs/server.md](docs/server.md): Docker o eseguibile unico, un client
OAuth tuo per Drive, e i modi per raggiungerlo da fuori casa.

## Sviluppo

```bash
flutter pub get
flutter analyze && flutter test
(cd packages/kagami_archive && dart test)
(cd server && dart pub get && dart test)
flutter build apk --debug
```

- [CLAUDE.md](CLAUDE.md): struttura, comandi e vincoli del progetto
- [docs/design.md](docs/design.md): funzionalità, interfaccia e scelte tecniche
- [docs/malf.md](docs/malf.md): il formato della libreria
- [docs/server-api.md](docs/server-api.md): il protocollo fra app e server

## Licenza

[GPL-3.0](LICENSE). Il carattere Figtree è sotto [SIL OFL 1.1](fonts/OFL.txt).

Kagami scarica da siti di terzi solo ciò che l'utente gli chiede: rispettare
i diritti su ciò che si scarica, e le condizioni di quei siti, è compito di
chi lo usa.
