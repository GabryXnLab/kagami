# CLAUDE.md — Kagami Server (`server/`)

Vincoli del server; il resto del progetto è nel `CLAUDE.md` di root. Protocollo: `../docs/server-api.md`; installazione: `../docs/server.md`.

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
  - per ManhwaRead la pagina della serie da scaricare la manda il telefono
    (`snapshot`), le tavole si prendono dal CDN. I controlli la leggono da
    sé con un Chromium senza schermo (`browser.dart`, DevTools su un
    WebSocket, senza dipendenze; nell'immagine c'è `chromium`), e il
    telefono ad app chiusa con una WebView invisibile (`PageBrowser.kt`):
    tutti e due passano solo la verifica che si risolve da sola, la casella
    «Verify you are human» non la spunta nessuno, di proposito. Le serie
    rimaste ferme (`GatedSeries`, `check.gated`) le sblocca l'utente
    dall'app (`passVerification`, notifica `verify:` del giro ad app
    chiusa), che manda le pagine con `POST /v2/check/pages`; il giro
    notturno del telefono prova prima a mandarle da sé, con i cookie della
    verifica già passata (`passServerGated`);
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
  - «man mano» sul server: la serie la segue lui (`ahead`), i capitoli li
    chiede l'app, che sa cosa si legge (`POST /v2/jobs` con `automatic`,
    `PUT /v2/ongoing/{key}`). L'app lo offre solo a un server che elenca
    `ahead` fra le `features` di `/v2/server`: una funzione nuova del
    protocollo si dichiara lì, perché il server si aggiorna quando vuole;
  - il target `test` del Dockerfile è quello che blocca la pubblicazione
    dell'immagine in CI: ciò che i test leggono fuori da `server/` e dal
    motore (le icone di `assets/providers`) va copiato lì;
  - nessuna attesa senza limite: ogni richiesta lasciata a metà si
    interrompe (`DriveClient._abandon`), o tiene una delle otto connessioni
    per host per sempre — così il server è rimasto fermo una settimana. In
    più `serve` esce se il giro non dà segni di vita da un'ora
    (`ServerWorker.stuck`), e `--restart` lo riaccende;
  - prima di ogni giro si chiede se il Drive di quell'account è pronto
    (`UserDrive.blocked`): senza, i lavori aspettano in coda invece di
    fallire tutti;
  - nell'app il collegamento (`server.link`) è solo l'indirizzo, fra le
    impostazioni del database, quindi va in backup e account. La coda del
    server si chiede solo a schermata aperta (`remoteArchiveProvider`,
    autoDispose). Il client è `packages/kagami_archive/lib/remote.dart`, e i
    test del server lo provano contro `ServerApi`: chi cambia l'API cambia
    tutti e due.
