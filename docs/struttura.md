# Struttura del repo (albero completo)

Spostato dal `CLAUDE.md` di root, che ne tiene la versione corta.

```text
lib/
  main.dart                    avvio, tema, ripristino della cartella salvata
  src/
    format/malf.dart           modelli del formato dell'archivio (sola lettura)
    archive/device.dart        il motore sul telefono: immagini dal Kotlin (+ ArchiveImages.kt),
                               destinazioni, avvio del lavoro (+ ArchiveWorker.kt)
    archive/background.dart    il giro nel motore senza schermo
    archive/page_browser.dart  il browser invisibile per piattaforma: Kotlin su Android, WKWebView su iOS e macOS
    archive/manual_card.dart   salvare una scheda manuale senza interfaccia: store, dati personali, link già presenti
    archive/bulk_import.dart   tanti link in una volta: testo o JSON, righe senza doppioni, strada di ognuna
    format/reading.dart        stato di lettura, raccolte, merge dei conflitti
    data/library.dart          sorgenti unite per serie e per capitolo
    data/library_repository.dart  la sorgente locale: indici, download, capitoli presenti
    data/drive.dart            client REST di Drive, token, cache delle tavole
    data/drive_library.dart    la sorgente Drive: indici, percorsi, streaming
    data/network.dart          se c'è rete e quando torna (+ NetworkWatcher.kt)
    data/downloads.dart        da Drive alla cartella: il pulsante «Scarica»
    data/cleanup.dart          capitoli letti da togliere dal telefono: cosa e quanto
    data/auto_cleanup.dart     pulizia automatica: regole, piano su disco, giro (+ AutoCleanupWorker.kt)
    data/series_removal.dart   togliere una serie: telefono, Drive nel cestino, coda, serie seguite
    data/site_switch.dart      cambiare provider: la serie fra i risultati per titolo, i capitoli per numero
    data/read_ahead.dart       scaricare man mano: quali capitoli mancano davanti al lettore
    data/folder_sync.dart      cartella del telefono ↔ Drive: piano, giro, ricordi
    data/folder_sync_schedule.dart  giro a mano e programmato (+ FolderSyncWorker.kt)
    data/db/database.dart      schema SQLite dei dati personali (+ .g.dart)
    data/db/account_databases.dart  un file SQLite per account: slot, nota, adozione del file storico, `AccountSlots`
    data/user_repository.dart  stato, capitoli letti, cronologia, raccolte
    data/statistics.dart       aggregazioni della cronologia per i grafici
    data/social/profile.dart   social: impostazioni, profilo pubblico (`buildPublicProfile`), affinità, in comune
    data/social/content.dart   social: post, commenti, messaggi, segnalazioni, avviso spoiler
    data/social/backend.dart   social: ciò che si chiede al backend (`SocialBackend`, `SocialPosts`, `SocialMessages`, `SocialReports`)
    data/backup.dart           esportazione, ripristino, copia automatica
    data/reading_migration.dart  sposta fuori dalla libreria le copie e lo stato storico di `reading/` (D5)
    data/cloud.dart            accesso con Google e sincronizzazione dei dati
    data/sentry_scrub.dart     beforeSend di Sentry: via indirizzi, email e id di Drive
    data/backend.dart          il backend di chi compila: configurazione, client, errori, riga del lettore
    data/sources/source.dart   sorgenti in più: configurazione, capacità, stato, lista salvata, segreti
    data/sources/shelf_source.dart  involucro `StorageSource` sugli scaffali di sempre (cartella, spazio dell'app, Drive)
    data/sources/webdav_source.dart  sorgente WebDAV: trasporto con la password dai segreti, prova di connessione
    data/sources/smb_transport.dart  `SmbTransport` (SMB 2.1+, sola lettura) sopra la cucitura `SmbSession`, `smbHost`/`smbShare`; sessione vera su `dart_smb2`
    data/sources/smb_source.dart  sorgente SMB: trasporto con la password dai segreti
    native_licenses.dart       licenze di libsmb2 e OpenSSL nella pagina delle licenze
    data/sources/secure_source_secrets.dart  `SourceSecrets` su `flutter_secure_storage`
    ui/sources_screen.dart, ui/sources_sheets.dart  Impostazioni → Libreria → Sorgenti: elenco, aggiungi, dettaglio
    data/sources/remote_router.dart  smista `drive:` e `remote:<id>/` verso la sorgente che li serve
    data/reader_store.dart     la riga del lettore nella tabella `readers` di un backend compatibile Supabase
    data/library_location.dart cartella scelta e permessi di piattaforma
    data/library_view.dart     segnali per serie, ricerca, filtri, ordinamenti
    data/arrivals.dart         capitoli nuovi: conteggio e di quali dare notizia
    data/notifications.dart    notifiche dei capitoli nuovi (+ ArrivalNotifier.kt, LibraryWatchWorker.kt)
    data/share_intake.dart     Condividi → Kagami: il testo condiviso, all'avvio e ad app aperta (+ SharedText.kt)
    data/reader_settings.dart  modalità di lettura per serie (non è MALF)
    data/page_decoder.dart     file interi col codec di Flutter, fasce e tessere dal Kotlin
    data/phone_tiles.dart      tessere fatte dal telefono per le tavole alte non tagliate
    data/reader_probe.dart     misure di fluidità del lettore, accese dalle impostazioni
    providers.dart             grafo delle dipendenze
    providers_sources.dart     le sorgenti in più: lista salvata e segreti (`librarySourcesProvider`) e la loro composizione (`storageSourcesProvider`)
    providers_shares.dart      la libreria condivisa: `driveAccessProvider`, `driveShareReadersProvider` (con la passata delle scadenze) e `driveShareSweepProvider` (avvio e secondo piano)
    ui/app_shell.dart          le quattro destinazioni
    ui/account_scope.dart      `ProviderScope` a chiave di slot: cambiare account ricrea il contenitore
    ui/home_screen.dart        riprendi, aggiornamenti, da iniziare, simili
    ui/library_screen.dart     griglia, ricerca, filtri; griglia riusabile
    ui/series_screen.dart      scheda: metadati, capitoli, stato e voto
    ui/reader_screen.dart      lettore continuo e paginato
    ui/collections_screen.dart raccolte automatiche e manuali, aperte dalla libreria
    ui/history_screen.dart     cronologia per giorno e incognito
    ui/statistics_screen.dart  numeri e grafici della lettura
    ui/settings_screen.dart    la quarta destinazione: profilo, scaricare, cronologia, statistiche,
                               incognito, aspetto; pagine di libreria, lettura, account, dati
    ui/archive_screen.dart     Scarica un manga: ricerca, link, coda, scaricate di recente, serie seguite
    ui/archive_series.dart     la pagina di una serie letta dal sito: modalità, capitoli, destinazione
    ui/archive_flow.dart       il percorso riusabile: link → verifica → pagina della serie → coda, browser
    ui/archive_manual.dart     la scheda manuale: senza link o con un sito non supportato, titolo e copertina dalla pagina
    ui/provider_switch.dart    Cambia provider: elenco dei provider, verifica per titolo, ricerca se non c'è
    ui/archive_import.dart     Importa più link: opzioni, il giro una serie alla volta, stato di ogni riga, verifiche
    ui/archive_server.dart     il server lì dentro: crearlo, collegarlo, utenti, coda, cartella
    data/server_access.dart    account davanti al server: token, permesso di Drive, inviti (`InviteStore`)
    data/drive_access.dart     la libreria condivisa: `DriveAccess` (condividere, rinnovare, ritirare, passata delle scadenze, chi può leggere), le due scritture in ordine
    data/share_directory.dart  righe di `drive_shares`: `DriveShare`, `ShareDirectory` (Supabase e in memoria), `ShareUnavailable`
    data/invite_store.dart     gli inviti su `server_invites` del backend, con ascolto in tempo reale
    ui/browser_check_page.dart WebView per la verifica di Cloudflare e per cercare sui siti protetti
    ui/setup_screen.dart       permesso, cartella, stati vuoti e di errore
    ui/reader_metrics.dart     geometria della striscia a fasce, senza schermo
    ui/page_bands.dart         magazzino delle fasce, catena delle fonti, disegno
    ui/drive_ui.dart           collegare Drive, cartelle, destinazione, avvisi
    ui/drive_share_sheet.dart  «Chi può leggere la mia libreria»: righe, permessi senza riga, durata, rinnovo, consenso allo scope completo
    ui/sync_screen.dart        direzione, cancellazioni, ora della sincronizzazione
    ui/theme.dart              superfici, tipografia e colori di significato
    ui/widgets/kit.dart        schede, pastiglie, segmentati, fogli, vuoti
    ui/widgets/                copertina, origine, fogli raccolte, pulizia e punto di lettura, grafici
packages/kagami_archive/       l'archiviatore, Dart puro: lo usano l'app e il server
  lib/model.dart, names.dart, images.dart   metadati, nomi di cartella, header
  lib/http.dart                client limitato ai domini, pagina presa dalla WebView
  lib/providers.dart           registro dei siti, `Provider`, `BrowserGate`
  lib/providers/kit.dart       attrezzi comuni dei siti: link, testi, ordine dei capitoli
  lib/providers/               un file per sito: MangaK, ManhwaRead, Asura Scans, Coffee Manga
  lib/declarative.dart         siti degli utenti e del catalogo: il file JSON interpretato (`docs/siti.md`)
  lib/declarative_vars.dart    variabili, modelli e indirizzi composti del formato 2 (`part` del precedente)
  lib/declarative_filters.dart filtri e condizioni del formato 2 (`filters`, `skip`, `require`, `locked`; `part`)
  lib/site_engine.dart         `siteMinEngine`: l'`engine` che serve a una definizione di sito
  lib/renderer.dart            `PageRenderer`: il browser iniettato per le pagine rese (`browser.pages`)
  lib/archiver.dart            dal sito alla libreria: manifest, ripresa, tessere
  lib/indexes.dart             index.json, pages.json, riga di libreria, firma
  lib/stores.dart              destinazioni: cartella, Drive (ricevuta MD5)
  lib/drive.dart               client REST di Drive, `SyncRemote`, `NetworkState`
  lib/transport.dart           `StorageTransport`: una libreria letta per percorsi (WebDAV, poi SMB), errori nei tre stati
  lib/webdav.dart              `WebDavTransport` in sola lettura, `webDavAddress` (https, http solo in casa)
  lib/remote.dart              client dell'API del server, `KAGAMI_SETUP` e comando, indirizzi privati
  lib/google_token.dart        endpoint dei token di Google: riscattare e rinnovare i permessi
  lib/image_tools.dart         miniature e tessere: l'interfaccia, chi le fa è fuori
  lib/jobs.dart, runner.dart   coda, avanzamento, storico, il giro
  lib/tracking.dart            serie in corso e controllo dei capitoli nuovi
  lib/manual.dart              schede manuali: pseudo-sito `manual`, chiave dal link, scrittura senza capitoli
  test/                        provider con fixture copiate, contratto di ogni sito,
                               motore su cartella e Drive finto, coda, serie in corso (`dart test`)
server/                        Kagami Server, Dart puro (`dart compile exe`)
  bin/kagami_server.dart       riga di comando: serve, users, status, ping, idle, update
  lib/src/api.dart             l'API v2: rotte, chi chiama, utenti, validazione dei lavori
  lib/src/identity.dart        chi chiama: token del backend (JWKS RS256 o `/auth/v1/user` in cache) o di Firebase, smistati per `iss`
  lib/src/users.dart           account ammessi, proprietario, uno spazio (coda, Drive, giro) per utente
  lib/src/google.dart          il Drive di un utente: refresh token e cartella
  lib/src/shares.dart          condivisioni della libreria affidate dall'app (`shares`), ritirate alla scadenza
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
test/account_database_test.dart slot, nota, adozione del file storico, `AccountSlots`, contenitore per slot
test/app_shell_device_notes_test.dart note del dispositivo riscritte anche con `SetupScreen` a schermo
test/backup_location_test.dart copie automatiche fuori dalla libreria e migrazione di `reading/`
test/reader_metrics_test.dart  la striscia si tocca: fasce, altezze, ripresa
test/page_bands_test.dart      decodifica a ritagli e sfratto delle fasce
test/library_merge_test.dart   unione delle sorgenti, capitoli presenti, cache
test/library_merge_sources_test.dart   unione di più remote: vince la prima, una remota vince su locale, sorgente non disponibile = avviso
test/drive_library_test.dart   Drive finto in memoria: richieste, percorsi, download, offline
test/drive_client_test.dart    client contro un server locale: ripresa, blocchi, offline
test/drive_share_client_test.dart  permessi di una cartella: condividere, rinnovare, ritirare, elencare; scadenza rifiutata
test/social_profile_test.dart  social: cosa esce dal telefono (nascoste fuori, interruttori, limiti), statistiche con `excluding`
test/drive_access_test.dart          DriveAccess: ordine delle due scritture, rinnovo con 404, passata delle scadenze, chi può leggere
test/drive_share_sheet_test.dart     il foglio di chi condivide: elenco, aggiunta, rinnovo, togli, Drive muto, funzione assente, righe non lette
test/network_test.dart         monitor della rete e fasce che tornano da sole
test/auto_cleanup_test.dart    pulizia automatica: scadenze del piano e giro su una cartella vera
test/arrivals_test.dart        pallino dei capitoli nuovi, notifiche, silenzio nel backup
test/folder_sync_test.dart     piano della sincronizzazione e giri contro un Drive finto
test/tag_tint_test.dart        il colore di un'etichetta dipende solo dal suo testo
test/bulk_import_test.dart     link dal testo e dal JSON, doppioni, già presente, sito o scheda manuale
test/site_switch_test.dart     la serie fra i risultati del provider nuovo, capitoli abbinati per numero o nome
test/archive_choice_test.dart  il punto di lettura che precompila la pagina della serie letta dal sito
test/remote_router_test.dart   indirizzi `drive:` e `remote:`, sorgente assente = errore, precarichi per sorgente
test/sources_wiring_test.dart   `libraryProvider` compone gli scaffali dalle sorgenti: le tre di sempre, tipo senza costruttore, lista illeggibile, serie non cancellabile
test/second_transport_test.dart  `SmbTransport` su una sessione finta: elenco, errori, tempo massimo, ripresa, host pubblico in chiaro
test/sources_test.dart         lista delle sorgenti: va e torna, illeggibile non riscritta, ordine, righe di un tipo ignoto
test/backend_config_test.dart  build senza backend, client che nasce, errori che non sono «vuoto», schema = migrazioni
test/backend_fakes.dart        il backend finto dei test: `ReaderStore` e `InviteStore` in memoria
test/server_invites_backend_test.dart  inviti: id, minuscole, mittente, ascolto che rilegge, errore ≠ nessun invito; `SupabaseInviteStore` contro un PostgREST finto
test/cloud_sync_backend_test.dart  fusione per revisione, riga assente ≠ errore; `SupabaseReaderStore` contro un PostgREST finto
backend/                       schema del backend (migrazioni, `schema.sql`), regole provate (`rls-test.sql`, `test.sh`) (+ README proprio)
docs/design.md                 funzionalità, interfaccia e scelte tecniche
docs/malf.md                   il formato della libreria: l'originale della specifica
docs/server-api.md             l'API v1 fra app e server: l'originale del protocollo
docs/server.md                 installare il server: Drive, chiavi, come raggiungerlo
docs/readme/                   banner del README, chiaro e scuro (SVG, testo già in tracciati)
.github/workflows/             CI (`ci.yml`), APK e IPA di ogni merge (`build.yml`), release, wrapper del manutentore (+ CLAUDE.md proprio)
```

## Provare l'app a schermo: `test_driver/`

Spostato dal `CLAUDE.md` di root.

`test_driver/app.dart` è l'app con Flutter Driver acceso, per provarla con l'MCP
di Dart (`dart mcp-server`) su un emulatore o un telefono: `launch_app` con
`target` `test_driver/app.dart`, poi `set_frame_sync` a `"false"` e
`set_semantics` a `"true"`; le voci della barra in basso si trovano con
`BySemanticsLabel`, perché il loro testo esiste solo quando sono selezionate.
Quale build: **profile** per le prestazioni e per i cicli che non si fermano —
la debug ha gli assert di Riverpod, che nascondevano il giro infinito della
sincronizzazione —, **release** per i crash che vengono da R8. L'accesso con
Google funziona solo con una chiave di firma la cui impronta SHA-1 è registrata
nel client OAuth Android del proprio progetto Google Cloud.
