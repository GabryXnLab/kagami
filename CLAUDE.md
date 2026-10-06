# CLAUDE.md — Kagami

## Cos'è

Lettore di manga per archivi MALF già pronti. Non conosce nessun sito: legge
una cartella sincronizzata sul telefono, la stessa cartella direttamente su
Google Drive, o tutte e due insieme, e la presenta come un lettore musicale
presenta una discoteca — raccolte, ripresa della lettura, stato e voto per
ogni serie. Da Drive legge in streaming e scarica sul telefono solo ciò che
l'utente sceglie. Può anche archiviare da sé: da una ricerca o da un link
(Impostazioni → Scarica un manga) scarica una serie dal sito nella cartella di Drive o sul telefono,
con lo stesso motore dell'estensione MangaArchive portato in Dart
(`packages/kagami_archive/`). Lo stesso motore gira anche in **Kagami
Server** (`server/`), un programma che chiunque può tenere acceso su un suo
computer perché scarichi e carichi su Drive al posto del telefono, per sé e
per gli account Google che ammette: l'app lo crea generando un comando
`docker run` e gli parla col token dell'account (protocollo in
`docs/server-api.md`).

La cartella arriva da questa catena, che l'app non controlla (salvo l'ultimo
tratto, se l'utente lo affida a lei) e su cui non deve fare assunzioni oltre
al formato:

```text
MangaArchive (estensione Cobalt, server) ──┐
Kagami (Scarica un manga, telefono) ───────┤
Kagami Server (computer dell'utente) ──────┤
  → cartella Google Drive ─────────────→ Kagami (streaming)
    → sincronizzazione di Kagami o FolderSync
      → cartella locale ───────────────→ Kagami
```

Gli archiviatori scrivono nella stessa cartella di Drive e convivono con le
regole di «Chi scrive» in `docs/malf.md`.

Il contratto con l'archivio è il formato **MALF**, specificato in
[docs/malf.md](docs/malf.md). **L'originale è quello, in questo repo**: un
campo nuovo si aggiunge prima lì, poi in `packages/kagami_archive/` (chi scrive) e in
`lib/src/format/malf.dart` (chi legge). Gli archiviatori esterni come
`mangaarchive` seguono la specifica di Kagami, non il contrario: allinearli è
compito loro, e una loro modifica al formato non vale finché non entra qui.
Un dato che esiste solo nell'app non sopravvive a una reinstallazione.

Leggere [docs/design.md](docs/design.md) prima di lavorare sull'interfaccia o
sul modello dei dati: contiene le funzionalità attese, le scelte già prese e i
motivi per cui sono state prese.

## Stack

Flutter 3.47 / Dart 3.13, gestione pacchetti `flutter pub` (mai `dart pub` qui).

Interfaccia in nove lingue con `flutter_localizations` e `gen-l10n` (`l10n.yaml`):
i testi stanno in `lib/l10n/app_<lingua>.arb`, il codice `app_localizations*.dart`
lì accanto è generato da `flutter gen-l10n` (o `flutter pub get`) e va nel commit.

Stato con `flutter_riverpod` 3 — niente `StateProvider`, che nella 3 è legacy:
si usano `Notifier` e `NotifierProvider`. Interfaccia Material 3 vestita con un
kit di componenti proprio (`lib/src/ui/widgets/kit.dart`), carattere **Figtree**
in `fonts/` e icone **Lucide** (`lucide_icons_flutter`): una famiglia sola, mai
`Icons.*` accanto a quelle.

Account con `firebase_core`/`firebase_auth`/`cloud_firestore` e
`google_sign_in`: fanno seguire i dati personali al lettore invece che al
telefono e, con l'autorizzazione `drive.readonly`, danno il token con cui
l'app legge Drive — l'API REST, chiamata con `dart:io` senza pacchetti
`googleapis`. Il progetto Firebase è di chi compila:
`android/app/google-services.json` dice all'app qual è, resta fuori da git e
senza di lui l'app nasce senza account né Drive (`cloudAvailable`).

Dati personali su SQLite con `drift` (+ `drift_flutter`): le query girano in un
isolate e il codice delle tabelle è **generato**, quindi dopo ogni modifica a
`lib/src/data/db/database.dart` va rieseguito `build_runner`. Grafici con
`fl_chart`, schermo sempre acceso in lettura con `wakelock_plus`.

L'archivio usa `html` (le pagine di ManhwaRead), `crypto` (SHA-256 dei
manifest, MD5 della ricevuta di Drive), `unorm_dart` (la NFKC dei nomi di
cartella, uguale a quella di Python) e `webview_flutter` (la verifica di
Cloudflare, superata dall'utente).

Errori e crash vanno su **Sentry** (`sentry_flutter`), se chi compila passa il
suo DSN con `--dart-define=SENTRY_DSN=…`; senza, Sentry resta spento.
`SentryFlutter.init` in `lib/main.dart` avvolge sia l'app sia i giri ad app
chiusa. `sentry_flutter` 9 fissa `jni` alla 0.14, per questo
`path_provider_android` resta alla 2.2.

Nessun valore personale nel codice: progetto Firebase, DSN di Sentry, chiavi di
firma, segreto del client «Web» e indirizzi del server sono di chi compila o di chi installa,
e arrivano da file fuori da git, da `--dart-define` o dalle variabili del server.
Le note di una macchina o di un manutentore vanno in `CLAUDE.local.md`, che git
ignora.

## Struttura

```text
lib/
  main.dart                    avvio, tema, ripristino della cartella salvata
  src/
    format/malf.dart           modelli del formato dell'archivio (sola lettura)
    archive/device.dart        il motore sul telefono: immagini dal Kotlin (+ ArchiveImages.kt),
                               destinazioni, avvio del lavoro (+ ArchiveWorker.kt)
    archive/background.dart    il giro nel motore senza schermo
    format/reading.dart        stato di lettura, raccolte, merge dei conflitti
    data/library.dart          sorgenti unite per serie e per capitolo
    data/library_repository.dart  la sorgente locale: indici, download, capitoli presenti
    data/drive.dart            client REST di Drive, token, cache delle tavole
    data/drive_library.dart    la sorgente Drive: indici, percorsi, streaming
    data/network.dart          se c'è rete e quando torna (+ NetworkWatcher.kt)
    data/downloads.dart        da Drive alla cartella: il pulsante «Scarica»
    data/cleanup.dart          capitoli letti da togliere dal telefono: cosa e quanto
    data/folder_sync.dart      cartella del telefono ↔ Drive: piano, giro, ricordi
    data/folder_sync_schedule.dart  giro a mano e programmato (+ FolderSyncWorker.kt)
    data/db/database.dart      schema SQLite dei dati personali (+ .g.dart)
    data/user_repository.dart  stato, capitoli letti, cronologia, raccolte
    data/statistics.dart       aggregazioni della cronologia per i grafici
    data/backup.dart           esportazione, ripristino, copia automatica
    data/cloud.dart            accesso con Google e sincronizzazione dei dati
    data/library_location.dart cartella scelta e permessi di piattaforma
    data/library_view.dart     segnali per serie, ricerca, filtri, ordinamenti
    data/arrivals.dart         capitoli nuovi: conteggio e di quali dare notizia
    data/notifications.dart    notifiche dei capitoli nuovi (+ ArrivalNotifier.kt, LibraryWatchWorker.kt)
    data/reader_settings.dart  modalità di lettura per serie (non è MALF)
    data/page_decoder.dart     file interi col codec di Flutter, fasce e tessere dal Kotlin
    data/phone_tiles.dart      tessere fatte dal telefono per le tavole alte non tagliate
    data/reader_probe.dart     misure di fluidità del lettore, accese dalle impostazioni
    providers.dart             grafo delle dipendenze
    ui/app_shell.dart          le quattro destinazioni
    ui/home_screen.dart        riprendi, aggiornamenti, da iniziare, simili
    ui/library_screen.dart     griglia, ricerca, filtri; griglia riusabile
    ui/series_screen.dart      scheda: metadati, capitoli, stato e voto
    ui/reader_screen.dart      lettore continuo e paginato
    ui/collections_screen.dart raccolte automatiche e manuali
    ui/history_screen.dart     cronologia per giorno e incognito
    ui/statistics_screen.dart  numeri e grafici della lettura
    ui/settings_screen.dart    la quarta destinazione: profilo, scaricare, cronologia, statistiche,
                               incognito, aspetto; pagine di libreria, lettura, account, dati
    ui/archive_screen.dart     Scarica un manga: ricerca, link, capitoli, destinazione, coda
    ui/archive_server.dart     il server lì dentro: crearlo, collegarlo, utenti, coda, cartella
    data/server_access.dart    account davanti al server: token, permesso di Drive, inviti su Firestore
    ui/browser_check_page.dart WebView per la verifica di Cloudflare e per cercare sui siti protetti
    ui/setup_screen.dart       permesso, cartella, stati vuoti e di errore
    ui/reader_metrics.dart     geometria della striscia a fasce, senza schermo
    ui/page_bands.dart         magazzino delle fasce, catena delle fonti, disegno
    ui/drive_ui.dart           collegare Drive, cartelle, destinazione, avvisi
    ui/sync_screen.dart        direzione, cancellazioni, ora della sincronizzazione
    ui/theme.dart              superfici, tipografia e colori di significato
    ui/widgets/kit.dart        schede, pastiglie, segmentati, fogli, vuoti
    ui/widgets/                copertina, origine, fogli raccolte e pulizia, grafici
packages/kagami_archive/       l'archiviatore, Dart puro: lo usano l'app e il server
  lib/model.dart, names.dart, images.dart   metadati, nomi di cartella, header
  lib/http.dart                client limitato ai domini, pagina presa dalla WebView
  lib/providers.dart           registro dei siti, `Provider`, `BrowserGate`
  lib/providers/kit.dart       attrezzi comuni dei siti: link, testi, ordine dei capitoli
  lib/providers/               un file per sito: MangaK, ManhwaRead, Asura Scans
  lib/archiver.dart            dal sito alla libreria: manifest, ripresa, tessere
  lib/indexes.dart             index.json, pages.json, riga di libreria, firma
  lib/stores.dart              destinazioni: cartella, Drive (ricevuta MD5)
  lib/drive.dart               client REST di Drive, `SyncRemote`, `NetworkState`
  lib/remote.dart              client dell'API del server, `KAGAMI_SETUP` e comando, indirizzi privati
  lib/google_token.dart        endpoint dei token di Google: riscattare e rinnovare i permessi
  lib/image_tools.dart         miniature e tessere: l'interfaccia, chi le fa è fuori
  lib/jobs.dart, runner.dart   coda, avanzamento, storico, il giro
  lib/tracking.dart            serie in corso e controllo dei capitoli nuovi
  test/                        provider con fixture copiate, contratto di ogni sito,
                               motore su cartella e Drive finto, coda, serie in corso (`dart test`)
server/                        Kagami Server, Dart puro (`dart compile exe`)
  bin/kagami_server.dart       riga di comando: serve, users, status, ping, idle, update
  lib/src/api.dart             l'API v2: rotte, chi chiama, utenti, validazione dei lavori
  lib/src/identity.dart        token d'identità di Firebase: firma RS256, progetto, account Google
  lib/src/users.dart           account ammessi, proprietario, uno spazio (coda, Drive, giro) per utente
  lib/src/google.dart          il Drive di un utente: refresh token e cartella
  lib/src/worker.dart          il giro della coda (ArchiveRunner) e il controllo quotidiano
  lib/src/images.dart          miniature e tessere con libvips
  lib/src/updater.dart         l'aggiornatore: API di Docker sul socket, ricrea il server con l'immagine nuova
  lib/src/config.dart, server.dart  cartella dei dati, `KAGAMI_SETUP`, impostazioni, accensione
  test/                        firme vere con una chiave di prova, Google finto, API e client sul loopback, giro
  Dockerfile, docker-compose.yml  immagine con libvips; il target `test` fa girare anche i test di vips
lib/l10n/                      testi dell'interfaccia: app_it.arb l'originale, le altre lingue tradotte (+ generati)
lib/src/l10n.dart              `context.l10n`, `currentL10n()` fuori dai widget, nomi delle lingue
fonts/                         Figtree, il carattere dell'interfaccia
assets/providers/              icone dei siti da cui si archivia (`Provider.icon`)
test_driver/app.dart           l'app con Flutter Driver acceso, per l'MCP di Dart sull'emulatore
test/malf_test.dart            legge una libreria finta creata dal test stesso
test/library_view_test.dart    segnali, filtri e ordinamenti senza disco
test/user_repository_test.dart database in memoria: stato, cronologia, import
test/backup_test.dart          andata e ritorno di un backup fra due database
test/reader_metrics_test.dart  la striscia si tocca: fasce, altezze, ripresa
test/page_bands_test.dart      decodifica a ritagli e sfratto delle fasce
test/library_merge_test.dart   unione delle sorgenti, capitoli presenti, cache
test/drive_library_test.dart   Drive finto in memoria: richieste, percorsi, download, offline
test/drive_client_test.dart    client contro un server locale: ripresa, blocchi, offline
test/network_test.dart         monitor della rete e fasce che tornano da sole
test/arrivals_test.dart        pallino dei capitoli nuovi, notifiche, silenzio nel backup
test/folder_sync_test.dart     piano della sincronizzazione e giri contro un Drive finto
test/tag_tint_test.dart        il colore di un'etichetta dipende solo dal suo testo
firestore.rules                il proprio documento solo a sé; gli inviti ai server a mittente e destinatario
docs/design.md                 funzionalità, interfaccia e scelte tecniche
docs/malf.md                   il formato della libreria: l'originale della specifica
docs/server-api.md             l'API v1 fra app e server: l'originale del protocollo
docs/server.md                 installare il server: Drive, chiavi, come raggiungerlo
docs/readme/                   banner del README, chiaro e scuro (SVG, testo già in tracciati)
.github/workflows/             CI (`ci.yml`), APK e IPA di ogni merge (`build.yml`), release, wrapper del manutentore (+ CLAUDE.md proprio)
```

## Comandi

```bash
flutter pub get
dart run build_runner build     # codice di drift, dopo ogni modifica allo schema
flutter analyze                 # deve restare senza segnalazioni
flutter test
(cd packages/kagami_archive && dart analyze && dart test)   # l'archiviatore, Dart puro
(cd server && dart pub get && dart analyze && dart test)    # il server
(cd server && dart compile exe bin/kagami_server.dart -o kagami-server)
docker build -f server/Dockerfile --target test .   # i test del server con libvips, dentro l'immagine
docker build -f server/Dockerfile -t kagami-server . # l'immagine; contesto la radice del repo
flutter build apk --debug       # con google-services.json: account e Drive
flutter build apk --release --dart-define=SENTRY_DSN=…   # Sentry facoltativo
flutter build apk --release --dart-define=GOOGLE_SERVER_CLIENT_SECRET=…   # per creare e collegare server
flutter build linux --debug     # solo per vedere che compili: niente Firebase
flutter build ios --release --no-codesign   # solo su macOS; l'IPA non firmato lo fa build.yml

firebase deploy --only firestore:rules   # le regole di sicurezza, sul proprio progetto
```

La CI pubblica è `.github/workflows/ci.yml`: analisi e test su runner di GitHub,
senza servizi esterni. Gli APK release (per architettura e universale) e l'IPA iOS
non firmato di ogni push su `main` li fa `build.yml`, con il reusable pubblico
`GabryXnLab/flutter-ci`. Funzionano anche in un fork, con i secret di chi compila;
dettagli nel `CLAUDE.md` della cartella.

`test_driver/app.dart` è l'app con Flutter Driver acceso, per provarla con l'MCP
di Dart (`dart mcp-server`) su un emulatore o un telefono: `launch_app` con
`target` `test_driver/app.dart`, poi `set_frame_sync` a `"false"` e
`set_semantics` a `"true"`; le voci della barra in basso si trovano con
`BySemanticsLabel`, perché il loro testo esiste solo quando sono selezionate.
Quale build: **profile** per le prestazioni e per i cicli che non si fermano —
la debug ha gli assert di Riverpod, che nascondevano il giro infinito della
sincronizzazione —, **release** per i crash che vengono da R8. L'accesso con
Google funziona solo con una chiave di firma la cui impronta SHA-1 è registrata
nel proprio progetto Firebase.

## Note architetturali importanti

- **Kagami è indipendente da Cobalt Extended, e resta così.** Il progetto
  è pubblico e deve funzionare per chiunque. Chi non ha mai installato
  `cobalt-extended` deve avere un'app completa. Kagami non ne importa codice,
  non lo presuppone installato e non ne chiama le API, né quelle di
  `mangaarchive` né quelle di RemoteGate. `mangaarchive` è solo uno degli
  archiviatori che possono scrivere una libreria MALF nella stessa cartella.
  Anche il server per scaricare lontano dal telefono è di Kagami, sta in questo
  repo e parla un protocollo di Kagami. Non va mai sostituito con
  `mangaarchive`, Cobalt o un servizio del manutentore, nemmeno «per ora».
- **Kagami Server è l'archiviatore del telefono su un computer acceso.** Stesso
  `ArchiveRunner`, stessi file di coda e stato (`ArchiveFiles`), uno spazio
  per account in `users/` della cartella dei dati, destinazione solo la
  cartella di Drive della libreria di chi chiede. Il protocollo è
  `docs/server-api.md`, e si cambia prima lì. Vincoli:
  - sul server non si configura niente e non si fa nessun accesso: tutto
    arriva da `KAGAMI_SETUP`, che l'app genera per il proprietario dentro un
    comando `docker run` (progetto Firebase, client «Web», permesso di Drive
    e cartella del proprietario). Si applica quando cambia, per impronta:
    rilanciare lo stesso comando non rimette un permesso vecchio;
  - chi chiama lo dice il **token d'identità di Firebase** (`Bearer`),
    verificato con le chiavi pubbliche di Google (`identity.dart`, RS256
    confrontando il blocco intero, senza dipendenze): `aud` il progetto,
    accesso con Google, indirizzo verificato. Niente sessioni né chiavi su
    disco; l'elenco degli account è del proprietario, che lo cambia
    dall'app (`/v2/users`);
  - ogni account ha il **suo** Drive: un refresh token per il client «Web»
    del progetto Firebase, riscattato dall'app dal `serverAuthCode` di
    Android col segreto del client, che mette chi compila
    (`--dart-define=GOOGLE_SERVER_CLIENT_SECRET`). Il telefono non può
    prestare il suo token, che dura un'ora. Con l'app OAuth in «Testing» i
    permessi scadono in sette giorni: `docs/server.md` lo dice;
  - gli inviti sono documenti Firestore (`serverInvites`, regole in
    `firestore.rules`): il server non manda email e di Firebase conosce solo
    i token. La notifica dell'invito la dà l'app di chi lo riceve;
  - il server non fa TLS. L'HTTPS lo mette chi lo espone (Tailscale Funnel,
    reverse proxy); in chiaro va bene solo in casa o dentro Tailscale;
  - niente browser: per ManhwaRead la pagina della serie la manda il
    telefono (`snapshot`), le tavole si prendono dal CDN;
  - l'immagine Docker si costruisce dalla radice (serve `packages/`), e
    `.dockerignore` fa entrare solo `server/` e il motore. La pubblica su
    GHCR `ci.yml` dal repo pubblico, ed è quella del comando dell'app
    (`serverImage`): non contiene niente di personale. Sulla macchina
    condivisa si toglie per nome solo ciò che si è creato, mai con `prune`;
  - si aggiorna da sé: il comando dell'app accende anche `kagami-updater`,
    la stessa immagine con `update`, il socket di Docker e root, che ogni
    ora scarica l'immagine e, se è cambiata e il server non scarica,
    ricrea il contenitore con la sua configurazione (`recreateBody`) e poi
    sé stesso. Niente Watchtower (fermo, e muto con Docker 29); il socket
    non entra mai nel contenitore del server;
  - prima di ogni giro si chiede se il Drive di quell'account è pronto
    (`UserDrive.blocked`): senza, i lavori aspettano in coda invece di
    fallire tutti;
  - nell'app il collegamento (`server.link`) è solo l'indirizzo, fra le
    impostazioni del database, quindi va in backup e account. La coda del
    server si chiede solo a schermata aperta (`remoteArchiveProvider`,
    autoDispose). Il client è `packages/kagami_archive/lib/remote.dart`, e i
    test del server lo provano contro `ServerApi`: chi cambia l'API cambia
    tutti e due.
- **L'archiviatore è un pacchetto Dart puro** (`packages/kagami_archive/`),
  perché lo usano sia l'app sia il server, e il server non ha Flutter. Lì non
  entra niente di Flutter, Android o dell'account. Ciò che il telefono
  aggiunge arriva da fuori, per interfaccia: le immagini (`ImageTools`, sul
  telefono il Kotlin), il token (la funzione passata a `DriveClient`, sul
  telefono `DriveAuth`), la rete (`NetworkState`, sul telefono
  `NetworkMonitor`) e i guasti (`ArchiveRunner.onError`, sul telefono
  Sentry).
- **Un sito è un file, e nient'altro lo nomina.** Ogni provider sta in
  `packages/kagami_archive/lib/providers/<id>.dart`, usa `providers/kit.dart`
  per ciò che deve valere uguale per tutti (link accettati, testi, ordine e
  unicità dei capitoli) e si registra in `providers`; l'icona è
  `assets/providers/<id>.png`. App, server, coda e serie in corso non
  chiedono mai «quale sito»: un sito dietro Cloudflare lo dice con
  `Provider.browser` (`BrowserGate`: host dei cookie, segni della pagina
  vera), e da lì seguono WebView, ricerca invisibile, `snapshot` per il
  server e salto nei controlli automatici. `provider_contract_test.dart`
  ferma un sito registrato senza icona, con un id non valido o con una
  verifica su host non suoi. Un attrezzo che serve a due siti va nel kit,
  non copiato.
- **Gli indici non si ricostruiscono qui**, se non per le serie che l'app
  archivia lei (`packages/kagami_archive/`). `library.json`, `index.json` e
  `pages.json` di una libreria esistente li scrive l'archiviatore. Se mancano, l'app lo dice e
  rimanda a chi ha scritto la libreria: scandire l'albero dal telefono è
  esattamente il costo che il formato esiste per evitare.
- **Ogni decodifica JSON passa da `compute`.** `library.json` di una libreria
  vera è di qualche centinaio di kilobyte e sul thread della UI si vede.
- **In lettura continua le tavole stanno attaccate.** Ogni pagina occupa
  esattamente l'altezza che le tocca alla larghezza dello schermo, e il
  rapporto arriva prima da `pages.json`, poi — appena l'immagine è decodificata
  — da quello vero, che ha la precedenza. Correggere una tavola già superata
  sposta lo scorrimento di altrettanto, altrimenti il capitolo scivola via da
  solo. La matematica sta in `ui/reader_metrics.dart` perché è l'unica parte
  del lettore che si possa provare senza uno schermo.
- **Una fascia si prende dalla prima fonte che ce l'ha**, in quest'ordine:
  tessera dell'archivio (MALF `tiles`), tavola intera se è bassa, tessera
  tagliata dal telefono (`data/phone_tiles.dart`), ritaglio nativo. Le prime
  tre sono file per il codec di Flutter; il ritaglio è ciò che resta per le
  tavole alte che nessuno ha ancora tagliato. Il motivo è il thread: da
  Flutter 3.29 Dart gira sul thread principale di Android, senza modo di
  separarli, e ogni fascia nativa porta megabyte di pixel in Dart. Le righe
  sono le stesse da ogni fonte, quindi una che manca passa alla seguente
  (`PageBandCache._fetch`) senza muovere la striscia. Una nuova fonte va in
  quella catena, non nel lettore.
- **Una tavola non si decodifica intera: si decodifica a fasce.** Le tavole di
  un manhwa stitchato arrivano a 16383 px — intere sono cinquanta megabyte di
  bitmap e una texture più grande di quanto la GPU accetti, e tre vive nella
  lista sono l'app che sparisce. Le fasce le dà il Kotlin
  (`android/app/src/main/kotlin/dev/local/kagami/PageDecoder.kt`, lato Dart
  `data/page_decoder.dart`): decodifica la tavola **una volta**, la tiene in
  memoria nativa (due al massimo, fino a 64 MB l'una) e ne ritaglia le
  fasce. Non ritaglia dal file con `BitmapRegionDecoder`, se non per le
  tavole più grandi di così: il decodificatore WebP non sa saltare le righe
  sopra il ritaglio, e l'ultima fascia di una tavola costava quanto la
  tavola intera — undici fasce, sei tavole di lavoro. I pixel tornano come byte grezzi, con la
  risposta data dal thread del decodificatore e non da `MethodChannel`: da
  Flutter 3.29 il thread di Android è quello dell'interfaccia, e il codec
  standard che ricopia megabyte a ogni fascia lì dentro è uno scatto nello
  scorrimento. Una fascia è alta al più 512 px della sorgente,
  un terzo di schermata — ogni fascia è una texture caricata sulla GPU in un
  colpo solo, e a 1536 px quel caricamento era lo scatto al cambio di
  fascia —, e **le fasce sono gli elementi della lista**: è così che
  la memoria dipende dallo schermo e non dall'altezza della tavola. Il
  magazzino (`ui/page_bands.dart`) ne tiene sei schermate e butta per prime
  quelle che non guarda più nessuno, mai quelle sullo schermo. Dove il
  decodificatore a ritagli non c'è — build Linux, test — non si taglia niente e
  un tetto agli otto megapixel evita il disastro. Niente ingrandisce una
  tavola: resta alla risoluzione del file. La griglia, per lo stesso motivo,
  legge `cover.thumb.webp` e non la copertina piena.
- **`width`/`height` in `pages.json` servono a impaginare senza aprire i file.**
  Un capitolo deve poter riservare lo spazio di scorrimento prima che le
  immagini siano decodificate, altrimenti la posizione salta durante la lettura.
- **Su Android serve l'accesso a tutti i file**
  (`MANAGE_EXTERNAL_STORAGE`), non il Storage Access Framework: SAF costa una
  chiamata di piattaforma per file e qui i file sono decine di migliaia. È una
  scelta consapevole, documentata in `docs/design.md`, e va spiegata all'utente
  nella schermata che la chiede.
- **La sincronizzazione può essere a metà.** Record senza file, capitoli
  annunciati e non scaricati, indice più vecchio dei file: sono stati normali,
  non errori. L'app mostra ciò che ha.
- **Lo stato utente vive nel database dell'app**, non più in `reading/`. La
  cronologia è una riga per capitolo letto con la sua data, e le statistiche
  sono raggruppamenti per data: su un JSON riletto e riscritto per intero a
  ogni gesto non stavano in piedi. `reading/state.json` e `collections.json`
  si leggono **una volta sola**, per importarli, e non si riscrivono più.
- **Il backup è ciò che prima faceva la cartella sincronizzata.** Un file
  compresso esportabile dove si vuole, più una copia automatica al giorno in
  `reading/backup/`, che FolderSync porta fuori dal telefono con i manga.
  Ripristinando si sceglie se fondere o sostituire; fondendo, i capitoli letti
  si uniscono — un capitolo letto non torna mai da leggere — e sul resto vince
  il record con `updatedAt` più recente, impostazioni comprese: la
  sincronizzazione d'avvio altrimenti rimetteva il valore vecchio in rete
  sopra una cartella di Drive appena scelta. Sessioni e segnalibri non hanno
  un «più recente»: un indice unico li tiene una volta sola, perché la
  sincronizzazione è una fusione e un doppione rifuso a ogni giro raddoppia.
- **Ogni tabella ha `profileId`.** Oggi il profilo è uno solo, ma la libreria è
  condivisa: è il gancio previsto per più lettori sullo stesso archivio.
- **`permission_handler` è fermo a `^12.0.0` di proposito.** La 14 dichiara
  `compileSdk = 37`, mentre l'Android Gradle Plugin generato da Flutter 3.47
  (9.1.0) supporta al massimo 36, e una platform `android-37` "pura" non esiste
  più nel repository di Google: ci sono solo `37.0`, `37.1`, `37.2`. Alzare il
  vincolo senza aggiornare AGP fa fallire la build.
- **Nel database non entra la libreria.** Gli indici MALF sono già la forma
  indicizzata e li scrive qualcun altro: copiarli significherebbe mantenere una
  seconda versione da invalidare a ogni sincronizzazione. Il campo `signature`
  dice se una serie è cambiata senza confrontare i capitoli.
- **La posizione di lettura è un punto, non una tavola, e non si scrive al
  ritmo dello scorrimento.** Su un webtoon una tavola è dieci schermate: la
  ripresa porta con sé quanto se n'era scorso (`progresses.offset`, nel backup
  e quindi nell'account). La riga va su disco dopo una pausa di un secondo e
  mezzo; la fotografia in memoria dei dati personali si pubblica una volta
  sola, uscendo dal lettore. Pubblicarla prima ricalcolava segnali, filtri e
  ordinamenti di tutta la libreria — che resta montata sotto il lettore — a
  ogni movimento del dito. Lo stesso vale per il capitolo finito, segnato in
  silenzio e pubblicato all'uscita, e per l'apertura della scheda,
  pubblicata a transizione finita.

- **La libreria è ibrida: una serie sola, risolta per capitolo.** Cartella
  scelta, spazio privato dell'app e Drive sono `LibraryShelf` in ordine di
  preferenza (`data/library.dart`); le serie si uniscono per chiave, i
  capitoli per id, e ogni capitolo si legge dalla prima sorgente che lo sa
  servire. Un capitolo locale conta solo se la sua cartella c'è davvero
  (una lettura di `chapters/` per serie), altrimenti si legge da Drive o si
  mostra come non scaricato. L'icona d'origine compare solo quando Drive c'è.
- **L'app cancella solo dal foglio «Libera spazio»** (`data/cleanup.dart`),
  e solo capitoli già letti: cartella scelta, spazio dell'app, cache di
  Drive e, se lo si accende (spento di partenza), Drive stesso — nel
  cestino. Si propone aprendo la scheda solo per ciò che sta sul telefono,
  finché l'utente non dice «Non chiedere più» (`cleanup.quiet`, nel backup).
  Il foglio decide per sé: ciò che toglie lo annota per la sincronizzazione
  (`sync/released.json`), che al giro seguente non lo riporta e non lo toglie
  dall'altra parte, e mentre un giro è in corso aspetta. Con FolderSync,
  che l'app non vede, può solo avvisare.
- **Un capitolo tolto da Drive resta nel suo indice** finché il server non
  lo riscrive: `DriveRepository` lo ricorda (`withdrawn.json`) e non lo
  serve (`LibraryShelf.withdrawnChapters`), finché un elenco nuovo della
  cartella dei capitoli non lo mostra di nuovo, rimesso dal server.
- **I capitoli precedenti a uno finito si segnano letti solo chiedendo**, una
  volta per lettura, e con `estimated`: non sono letture di oggi, e
  cronologia e statistiche non le contano. Anche quelli non scaricati né
  sul telefono né su Drive (serie archiviata da un capitolo in poi): per
  questo i segnali di una serie archiviata a metà e cominciata si contano
  sul suo indice (`SeriesSignals.needsChapters`), perché senza i letti si
  suppongono tutti archiviati e la serie risulterebbe finita.
- **Una tavola di Drive è un indirizzo `drive:…` finché non serve.** Il
  magazzino delle fasce aspetta che `RemoteFiles` l'abbia portata in cache —
  fuori dal decodificatore, che è uno solo e non deve fermarsi dietro a un
  download — e poi la decodifica come un file qualsiasi: fasce, geometria e
  ripresa non devono sapere da dove arriva. Le tavole del capitolo scendono
  in ordine, dalla prima all'ultima, non inseguendo lo schermo. Non
  aggiungere al lettore rami per Drive.
- **Drive si paga in richieste, non in byte.** All'apertura: elenco della
  radice più una ricerca unica per indici e copertine di tutte le serie. Gli
  elenchi delle cartelle stanno su disco e si rifanno solo se manca un nome;
  un'istantanea apre la libreria a ogni avvio, anche con la rete, e Drive
  si rilegge dietro alla griglia (`DriveRepository.revalidate`). Il token
  si chiede per l'indirizzo dell'account, mai con
  `attemptLightweightAuthentication`, che rifà l'accesso a schermo. Vedere
  `docs/design.md`.
- **La rete è uno stato, non un tentativo.** `NetworkMonitor`
  (`data/network.dart`, lato nativo `NetworkWatcher.kt`) dice se c'è rete; un
  errore di rete è `DriveOffline` e passa da solo. Offline le richieste
  falliscono subito, la cache si legge lo stesso, le tavole mostrano un
  avviso che sparisce quando la rete torna (le riprova `PageBandCache`).
  I download riprendono con `Range`, quindi un file `.part` non si cancella
  per un errore di rete. Chi aggiunge una richiesta a Drive passa da
  `DriveClient`, che sa tutto questo.
- **La cache di Drive butta per capitolo, non per tavola.** I nomi dei file
  sono impronte, quindi il lettore annota quali tavole fanno ogni capitolo
  aperto (`RemoteFiles.rememberChapter`) e `planCache` in `data/drive.dart`
  decide con lo stato di lettura: finito o già passato esce dopo tre giorni,
  lasciato dopo due settimane, il seguito di un capitolo a metà e le
  miniature mai prima del resto. I conti si rifanno quando lo stato si
  pubblica — all'avvio e uscendo dal lettore — mai mentre si scorre.
- **Scaricando da Drive, l'app non riscrive mai `library.json`**: con FolderSync
  bidirezionale finirebbe su Drive al posto di quello del server. I capitoli
  vanno nell'albero MALF (via `.part`, rinominati a fine download) e le serie
  scaricate in `reading/downloads.json`. Senza una cartella scelta vanno nello
  spazio privato dell'app, dopo averlo chiesto.
- **L'archiviatore è `mangaarchive` in Dart, e la cartella è condivisa.**
  Stessi nomi di cartella, manifest e indici del server, provati con le sue
  fixture: server e telefono si allungano a vicenda le serie su Drive
  (regole in `malf.md`, «Chi scrive»). Su Drive `library.json` si cambia
  una riga alla volta e il server tiene le righe che non ha; sul telefono
  non si tocca e le serie vanno in `reading/downloads.json`. Una cartella di
  Drive senza `library.json` è una libreria vuota. Le tavole lasciano il
  telefono solo dopo il confronto dell'MD5 con Drive. I download girano in
  `ArchiveWorker.kt` (in primo piano, motore Dart senza schermo) perché una
  serie sono ore; coda e stato sono file in `archive/` nello spazio
  dell'app. ManhwaRead dietro Cloudflare passa da una WebView
  (`browser_check_page.dart`): la verifica la fa l'utente, e user agent e
  cookie seguono il lavoro. Anche la sua ricerca passa da una WebView,
  invisibile e grande quanto lo schermo (`BrowserFetcher`): Cloudflare non
  risponde a `SiteHttp` nemmeno con quei cookie, e in una WebView di un
  pixel la verifica non si risolve da sola. Si seguono solo le serie in corso scaricate
  dall'app: quelle del server le segue il suo timer. Il server, se l'account
  lo lascia acceso, guarda anche tutta la libreria su Drive
  (`checkLibrary`): nuovi sono i capitoli che l'`index.json` della serie non
  elenca, non quelli non archiviati, che possono esserlo per scelta. Il
  telefono gli lascia allora le sue serie di quella cartella
  (`archive/server-check.json`), per non scaricarle due volte.
- **Su Drive una voce d'indice si riusa solo se è intera.** Ricostruendo
  `index.json` e `pages.json`, `DriveStore` riprende dall'indice di prima i
  capitoli completi e con le tavole; gli altri li rilegge dal loro
  `chapter.json`. Copiare anche le voci a metà le rendeva eterne: un
  capitolo indicizzato mentre saliva restava «non scaricato» anche dopo.
- **Lo scope è `drive.readonly`, e `drive` solo per chi carica.** Leggere,
  scaricare e sincronizzare in sola discesa usano la sola lettura; lo scope
  completo (dichiarato nella schermata di consenso del progetto Firebase) si
  chiede quando l'utente sceglie una sincronizzazione che carica su Drive, o
  un download dai siti con destinazione Drive
  (`DriveAuth.authorize(write: true)`), perché le cartelle le ha create
  rclone e `drive.file` non ci lascerebbe scrivere.
- **La sincronizzazione della cartella è di Kagami** (`data/folder_sync.dart`),
  al posto di FolderSync: da Drive, verso Drive o in entrambe, a mano o ogni
  giorno a un'ora. Non confronta contenuti: ricorda per ogni file com'era
  all'ultimo giro (`sync/state.json` nello spazio dell'app, fuori dal
  backup) e copia ciò che è cambiato da una parte; cambiato da tutt'e due
  vince il più recente. Gli indici MALF non salgono mai. Senza «Propaga le
  cancellazioni» un file tolto da una parte resta dall'altra e non torna —
  è ciò che tiene in piedi «Libera spazio» —; con, da Drive si toglie solo
  nel cestino. Le impostazioni stanno in `sync/settings.json` e non nel
  database perché le legge anche il giro programmato.
- **Il giro programmato è lo stesso Dart dell'app.** `FolderSyncWorker.kt`
  (WorkManager, un lavoro singolo che a fine giro accoda quello del giorno
  dopo: un periodico scivolerebbe d'ora) accende un motore Flutter senza
  schermo su `folderSyncMain` in `main.dart`, in primo piano con una
  notifica perché un lavoro normale ha dieci minuti. Il token lo dà
  `google_sign_in` senza attività, dal permesso già concesso. App e lavoro
  stanno nello stesso processo: si escludono con il lucchetto su disco
  `sync/lock`, non con uno del sistema.
- **"Novità" ha finalmente una data sua.** L'ultima apertura della scheda
  (`lastOpenedAt`) la registra il database; prima ci si doveva accontentare di
  `updatedAt` dello stato, che cambiava anche solo mettendo un voto. Il backup
  se la porta dietro, quindi non è più un dato che muore reinstallando.
- **I capitoli nuovi si contano, non si datano.** MALF dà la data
  dell'ultimo arrivo, non quanti capitoli sono arrivati: il numero sul
  pallino è la differenza con un riferimento per serie (`SeriesArrivals`),
  preso aprendo la scheda. Il riferimento è del telefono e resta fuori dal
  backup; il silenzio per serie (`seriesStates.muted`) invece ci entra.
  Si guarda solo un catalogo senza avvisi e con la cartella di Drive già
  nota, e i conteggi non scendono mai: una libreria letta a metà farebbe
  sembrare nuovi, dopo, i capitoli che c'erano già. Le notifiche sono Kotlin
  puro (`ArrivalNotifier.kt`), nessun pacchetto. Ad app chiusa
  `LibraryWatchWorker.kt` (WorkManager, ogni ora) guarda solo la cartella
  locale: le serie da guardare gliele lascia Dart uscendo
  (`arrivals/watch.json`), quelle annunciate gliele rilegge Dart
  (`arrivals/record.json`). Drive non c'è perché servirebbe il token
  dell'account fuori dall'app.
- **Le modalità di lettura non sono MALF**: sono impostazioni di
  visualizzazione e il formato non le prevede. Stanno però nel database insieme
  al resto, quindi il backup se le porta dietro; una serie senza impostazioni
  proprie eredita quelle predefinite, che sono l'ultima scelta fatta.
- **La cartella di Drive è un'impostazione del database** (`drive.folder`),
  quindi viaggia con backup e account: su un telefono nuovo la libreria
  compare al primo accesso.
- **Nell'account viaggia il file di backup, non le tabelle.** Quello che
  l'app mette su Firestore è esattamente ciò che esporta come file — gli
  stessi byte compressi, in un `Blob` dentro `readers/{uid}` — perché le
  regole con cui due copie si fondono esistono già, sono quelle del backup e
  sono provate. Rispecchiare campo per campo avrebbe voluto dire tenere lo
  schema in due posti e riscriverle una seconda volta. Sincronizzare è quindi
  `import(remoto, merge)` seguito dal rinvio del risultato, e avviene in tre
  momenti soltanto — all'avvio, uscendo dall'app e a richiesta — perché
  mandare su i dati a ogni pagina girata terrebbe accesa la radio per tutta
  la lettura.
- **L'accesso passa dal token d'identità, non dal browser.** `google_sign_in`
  chiede al sistema chi è l'utente e Firebase verifica la firma: per conto di
  quale client OAuth chiederlo lo dice `google-services.json`, quindi nel
  codice non c'è nessun identificativo da tenere aggiornato. Su una
  piattaforma senza Firebase — la build Linux, che serve solo a verificare
  che il codice compili — la sezione «Account» dice che non c'è.
- **I grafici hanno una tavolozza verificata**, non scelta a occhio: sei tinte
  in ordine fisso, controllate per chi non distingue i colori come la
  maggioranza su entrambe le superfici. L'ordine non si cicla e nessun grafico
  affida l'identità al solo colore: accanto ci sono legenda e valori.
- **I testi sono in `app_it.arb`, le altre lingue lo seguono.** Un testo
  nuovo si scrive in italiano in `app_it.arb`, con una `description` che dica
  dove compare (chi traduce non vede lo schermo), e si traduce negli altri
  `app_<lingua>.arb`; finché manca, quella lingua mostra l'italiano. Frasi
  intere con segnaposto e plurali ICU, mai pezzi concatenati: l'ordine delle
  parole cambia fra le lingue. Date e ore da `DateFormat` col locale, mai
  nomi di mesi scritti a mano. Dove non c'è un `BuildContext` (eccezioni,
  etichette degli enum, notifiche) si usa `currentL10n()`, che legge la lingua
  scelta (`app.locale` fra le impostazioni del database, vuota per quella del
  sistema). Il Kotlin ha i suoi testi in `res/values*/strings.xml` e, da
  Android 13, la lingua gliela passa Dart (`kagami/locale`) perché valga ad
  app chiusa. I messaggi del motore (`packages/kagami_archive/`) restano in
  italiano: li produce anche il server, che una lingua non ce l'ha.

## Convenzioni

Codice e identificatori in inglese, commenti e documentazione in italiano.
I commenti spiegano il perché, non il cosa. Commit atomici, messaggi in
italiano. `flutter analyze` pulito prima di ogni commit.
