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
    data/series_removal.dart   togliere una serie: telefono, Drive nel cestino, coda, serie seguite
    data/site_switch.dart      cambiare provider: la serie fra i risultati per titolo, i capitoli per numero
    data/read_ahead.dart       scaricare man mano: quali capitoli mancano davanti al lettore
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
    data/share_intake.dart     Condividi → Kagami: il testo condiviso, all'avvio e ad app aperta (+ SharedText.kt)
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
    ui/archive_screen.dart     Scarica un manga: ricerca, link, coda, scaricate di recente, serie seguite
    ui/archive_series.dart     la pagina di una serie letta dal sito: modalità, capitoli, destinazione
    ui/archive_flow.dart       il percorso riusabile: link → verifica → pagina della serie → coda, browser
    ui/archive_manual.dart     la scheda manuale: senza link o con un sito non supportato, titolo e copertina dalla pagina
    ui/provider_switch.dart    Cambia provider: elenco dei provider, verifica per titolo, ricerca se non c'è
    ui/archive_import.dart     Importa più link: opzioni, il giro una serie alla volta, stato di ogni riga, verifiche
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
    ui/widgets/                copertina, origine, fogli raccolte, pulizia e punto di lettura, grafici
packages/kagami_archive/       l'archiviatore, Dart puro: lo usano l'app e il server
  lib/model.dart, names.dart, images.dart   metadati, nomi di cartella, header
  lib/http.dart                client limitato ai domini, pagina presa dalla WebView
  lib/providers.dart           registro dei siti, `Provider`, `BrowserGate`
  lib/providers/kit.dart       attrezzi comuni dei siti: link, testi, ordine dei capitoli
  lib/providers/               un file per sito: MangaK, ManhwaRead, Asura Scans, Coffee Manga
  lib/archiver.dart            dal sito alla libreria: manifest, ripresa, tessere
  lib/indexes.dart             index.json, pages.json, riga di libreria, firma
  lib/stores.dart              destinazioni: cartella, Drive (ricevuta MD5)
  lib/drive.dart               client REST di Drive, `SyncRemote`, `NetworkState`
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
test/bulk_import_test.dart     link dal testo e dal JSON, doppioni, già presente, sito o scheda manuale
test/site_switch_test.dart     la serie fra i risultati del provider nuovo, capitoli abbinati per numero o nome
test/archive_choice_test.dart  il punto di lettura che precompila la pagina della serie letta dal sito
firestore.rules                il proprio documento solo a sé; gli inviti ai server a mittente e destinatario
docs/design.md                 funzionalità, interfaccia e scelte tecniche
docs/malf.md                   il formato della libreria: l'originale della specifica
docs/server-api.md             l'API v1 fra app e server: l'originale del protocollo
docs/server.md                 installare il server: Drive, chiavi, come raggiungerlo
docs/readme/                   banner del README, chiaro e scuro (SVG, testo già in tracciati)
.github/workflows/             CI (`ci.yml`), APK e IPA di ogni merge (`build.yml`), release, wrapper del manutentore (+ CLAUDE.md proprio)
```
