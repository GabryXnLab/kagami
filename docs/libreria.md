# La libreria: sorgenti, indici, cancellazioni, novità

Fatti d'area spostati dal `CLAUDE.md` di root (instradatore). Codice: `lib/src/data/library*.dart`, `series_removal.dart`, `arrivals.dart`, `notifications.dart`. Formato: `malf.md`.

- **Gli indici non si ricostruiscono qui**, se non per le serie che l'app
  archivia lei (`packages/kagami_archive/`). `library.json`, `index.json` e
  `pages.json` di una libreria esistente li scrive l'archiviatore. Se mancano, l'app lo dice e
  rimanda a chi ha scritto la libreria: scandire l'albero dal telefono è
  esattamente il costo che il formato esiste per evitare.
- **Ogni decodifica JSON passa da `compute`.** `library.json` di una libreria
  vera è di qualche centinaio di kilobyte e sul thread della UI si vede.
- **Su Android serve l'accesso a tutti i file**
  (`MANAGE_EXTERNAL_STORAGE`), non il Storage Access Framework: SAF costa una
  chiamata di piattaforma per file e qui i file sono decine di migliaia. È una
  scelta consapevole, documentata in `docs/design.md`, e va spiegata all'utente
  nella schermata che la chiede.
- **La sincronizzazione può essere a metà.** Record senza file, capitoli
  annunciati e non scaricati, indice più vecchio dei file: sono stati normali,
  non errori. L'app mostra ciò che ha.
- **La libreria è ibrida: una serie sola, risolta per capitolo.** Cartella
  scelta, spazio privato dell'app, Drive dell'account e le altre remote sono
  `LibraryShelf` in ordine di preferenza (`data/library.dart`), ognuno con
  il suo `sourceId`; le serie si uniscono per chiave, i capitoli per id, e
  ogni capitolo si legge dalla prima sorgente che lo sa servire
  (`SeriesChapters.sourceOf` dice quale). La riga della serie e il titolo
  vengono da una remota se ce n'è una — una copia sul telefono può essere
  indietro — e fra le remote dalla prima, cioè dal Drive dell'account
  davanti alle altre; i capitoli che ha solo un'altra si aggiungono, serviti
  da lei. `SeriesPlace.drive` vuol dire «solo remota», qualunque sia. Un
  capitolo locale conta solo se la sua cartella c'è davvero (una lettura di
  `chapters/` per serie), altrimenti si legge da una remota o si mostra come
  non scaricato. Una sorgente che non risponde diventa un avviso del
  catalogo, mai una sorgente vuota; quella che sa dire perché (scaduta,
  senza credenziali, irraggiungibile) lancia `SourceUnavailable` con id e
  stato (`data/sources/source.dart`), e l'avviso è quello. L'icona d'origine
  compare solo quando Drive c'è.
- **Una sorgente in più è una riga di configurazione**
  (`data/sources/source.dart`). Le tre di sempre — cartella scelta, spazio
  dell'app, Drive dell'account — restano con le loro impostazioni; le altre
  (un Drive condiviso, un NAS) stanno nell'impostazione `library.sources`, una
  lista JSON di `SourceConfig` che viaggia con backup e account e che per
  questo non contiene mai un segreto (`SourceSecrets`, per id). Tre stati
  anche qui: lista vuota, lista letta, lista **illeggibile** — nell'ultimo
  caso nessuna sorgente in più e l'impostazione non si riscrive finché
  l'utente non ne modifica una (`librarySourcesProvider`,
  `providers_sources.dart`); una riga di un tipo nato in una versione più
  nuova non si usa ma si riscrive com'è. Lo stato di una sorgente
  (`SourceState`) dice qualcosa del contenuto solo quando è `ready`: scaduta,
  senza credenziali o irraggiungibile non è mai «vuota». L'id (`s-` e otto
  cifre esadecimali) finisce negli indirizzi dei file e nelle chiavi di
  cache, quindi non cambia più. Le sorgenti si compongono in un posto solo
  (`storageSourcesProvider`, `providers_sources.dart`): le tre di sempre come
  `ShelfSource` — involucri sottili sugli scaffali che già esistono — poi le
  altre per `order`, costruite da una tabella tipo → costruttore
  (`sourceBuildersProvider`: Drive condiviso e WebDAV); `libraryProvider` ne passa gli
  scaffali a `Library`. Una riga scaduta, di un tipo senza costruttore, o la
  lista illeggibile non sono sorgenti vuote: danno un `SourceUnavailable`
  (`Library.notices`, poi `LibraryCatalog.notices`) e nessuno scaffale. Chi
  scrive o cancella passa solo da ciò che lo permette: le cancellazioni
  agiscono sui soli `LibraryRepository` e `DriveRepository`, e una serie che
  hanno soltanto altre sorgenti non si propone come eliminabile
  (`canRemoveSeries`, `series_removal.dart`).
- **Le password delle sorgenti stanno in `flutter_secure_storage`**
  (Keystore/Keychain; `SecureSourceSecrets`, dipendenza nuova): le
  impostazioni viaggiano con backup e account, un segreto no. Su un telefono
  nuovo la sorgente WebDAV c'è ed è `needsAuth` («Riscrivi la password»), non
  una libreria vuota: `SecretWebDavTransport` legge il segreto alla prima
  richiesta e senza password non chiede niente al server. Rimuovere una
  sorgente toglie configurazione, segreto, stato (`support/sources/<id>/`) e
  cache (`cache/sources/<id>/`), mai lo stato di lettura. La schermata è
  Impostazioni → Libreria → Sorgenti (`ui/sources_screen.dart`, fogli in
  `ui/sources_sheets.dart`).
- **`dart_smb2` (SMB, seconda sorgente remota) è una dipendenza dell'app, non
  del pacchetto**, e sta a `0.4.0` esatta. Il server si compila con `dart
  compile exe`, che rifiuta i build hook del pacchetto: non lo può avere
  (prova del 2026-11-14). 22 versioni in sette mesi con l'API che cambia a ogni
  minore: si alza a mano, rileggendo il changelog e `libsmb2Release`
  (`native_licenses.dart`). Porta codice nativo, libsmb2 (LGPL-2.1+) con
  OpenSSL (Apache-2.0) dentro, scaricato in build dalle release del pacchetto
  con SHA-256 fissato: le licenze e l'indirizzo del sorgente corrispondente
  stanno nella pagina delle licenze (`native_licenses.dart`) e nel README.
  Condizioni: SMB 2.1 o più recente (la 2.02 non negozia), porta 445
  soltanto, sola lettura; in chiaro solo verso indirizzi privati, verso un
  host pubblico solo con la cifratura SMB 3 (`seal`); ogni operazione ha un
  tempo massimo e allo scadere si annulla con `Smb2CancelToken` (il `timeout`
  del pool da solo ci mette più del doppio). Android: `minSdk` è
  `flutter.minSdkVersion`, 24 per Flutter 3.47, quanto richiede il pacchetto.
  **Non provato**: build Android e iOS con il build hook, un NAS vero (solo
  Samba): residuo R8. Il trasporto sta in `data/sources/smb_transport.dart`
  dietro `SmbSession`, per provarlo senza rete.
- **Un punto solo porta i file remoti sul telefono**
  (`data/sources/remote_router.dart`). Gli indirizzi del Drive dell'account
  restano `drive:<percorso>` — stanno nelle chiavi della cache di ogni
  telefono, e cambiarli le svuoterebbe — e quelli delle altre sorgenti sono
  `remote:<id>/<percorso>`. `RemoteRouter` è il `RemoteFiles.instance`
  dell'app e li smista: il lettore non prende rami per sorgente. Una sorgente
  che non c'è più è un errore, mai un file vuoto.
- **Una serie adottata cambia chiave, non identità.** Una riga con la chiave
  nei `formerKeys` di un'altra si ignora nell'unione delle sorgenti
  (`LibraryCatalog.merge`), sia locale sia di Drive: sul telefono la riga
  vecchia di `library.json` resta finché non la riscrive chi l'ha scritta.
  I `formerKeys` di una sorgente non mia (condivisione, NAS) nascondono solo
  righe di quella sorgente, e i dati non si spostano da una chiave che il
  telefono o il Drive dell'account tengono ancora (`ownedKeys`, FASE-5b §3).
  I dati personali la seguono con `adoptFormerKeys` (`data/adoption.dart`,
  agganciato da `IdentityAdoption` a ogni catalogo ricaricato): solo se la
  chiave vecchia ha ancora dati, con la mappa id vecchio → nuovo dai
  `formerIds`. Le copie scaricate sul telefono (`reading/downloads.json`) con
  una chiave vecchia prendono cartelle, id e riga nuovi prima dello
  spostamento, senza rete (`adoptCopy` del pacchetto, da
  `adoptDownloadedCopies`): i capitoli già scaricati restano scaricati. Se il
  `series.json` di Drive non si legge, la copia resta com'è e si riprova. Un capitolo
  `listed: false` resta leggibile e porta «Non più sul sito» nella scheda.
- **L'app cancella solo quando lo chiede l'utente**, o quando ha acceso la
  pulizia automatica (sotto): eliminando una serie
  (`data/series_removal.dart`: cartelle sul telefono, su Drive nel cestino
  con la sua riga di `library.json`, coda e serie seguite; le serie tolte
  restano nascoste per firma in `library.removed`, perché una copia locale
  vecchia di `library.json` non le riporti) o dal foglio «Libera spazio»
  (`data/cleanup.dart`), solo capitoli già letti: cartella scelta, spazio dell'app, cache di
  Drive e, se lo si accende (spento di partenza), Drive stesso — nel
  cestino. Si propone aprendo la scheda solo per ciò che sta sul telefono,
  finché l'utente non dice «Non chiedere più» (`cleanup.quiet`, nel backup).
  Il foglio decide per sé: ciò che toglie lo annota per la sincronizzazione
  (`sync/released.json`), che al giro seguente non lo riporta e non lo toglie
  dall'altra parte, e mentre un giro è in corso aspetta. Con FolderSync,
  che l'app non vede, può solo avvisare.
- **Si cancella solo dove l'utente possiede** (FASE-5b §5,
  `data/drive_ownership.dart`). Su Drive vale solo lo scaffale del Drive
  dell'account (`origin == LibraryOrigin.drive`, `ownDriveShelf`), mai quello
  di una condivisione: `withdrawPaths`/`withdrawChapters` lanciano
  `StateError` su uno scaffale non proprio, perché un chiamante nuovo non salti
  la regola. E solo se la cartella è dell'account: `DriveClient.owned`
  (`ownedByMe`), ricordato in `drive.folder.owned` come `<folderId>:<true|false>`
  (`driveFolderOwnedProvider`). Tre stati: non letta → nessuna cancellazione su
  Drive, la pulizia lo richiede al giro dopo; falsa → niente pulizia su Drive,
  niente capitoli di Drive nel foglio «Libera spazio», «Elimina» non tocca
  Drive (il foglio dice perché, e una serie che sta solo lì non si propone né
  si nasconde) e la condivisione della libreria non si offre. Un capitolo letto
  da una condivisione è letto: la regola dei letti toglie anche la copia nel
  proprio Drive, e la schermata lo dice.
- **La pulizia automatica** (`data/auto_cleanup.dart`, Impostazioni →
  Libreria, `cleanup.auto` nel backup, spenta di partenza) toglie da ogni
  posto della libreria — cartella scelta, spazio dell'app e Drive, nel
  cestino; mai lo stato di lettura — i capitoli letti e, con la seconda
  regola, anche quelli da leggere di una serie in cui non si legge niente da
  N giorni (14 di partenza; contano le posizioni salvate e i capitoli finiti
  non stimati, e un capitolo arrivato da meno non si tocca). Su Drive la
  seconda regola vale solo per le serie già cominciate e per i capitoli con
  `archivedAt`: lì c'è l'archivio intero. Il permesso di scrivere su Drive si
  chiede accendendo una regola; senza, si toglie solo dal telefono. Il lavoro ad app chiusa (`AutoCleanupWorker.kt`, WorkManager alla
  prossima scadenza, motore Dart senza schermo) non ha database né libreria:
  l'app gli lascia `cleanup/plan.json`, ogni capitolo con la sua scadenza,
  l'account e la cartella di Drive, rifatto a ogni stato pubblicato e quando
  account o cartella cambiano (prima di tutto ne escono i capitoli su Drive
  che non sono di quell'account e cartella). `runAutoCleanup` toglie da Drive
  solo se account e cartella di adesso sono quelli del piano, altrimenti li
  lascia all'app. Il lavoro non ha la sessione del backend: salta Drive se dal
  telefono si è usciti (`cloud.signedOut`), chiede il token per l'account del
  piano e, prima di togliere, richiede a Drive se la cartella è sua; Drive lo
  apre con `DriveRepository.withdrawPaths`, e `withdrawn.json` l'app lo rilegge quando
  cambia sul disco. Le serie aperte nel lettore
  aspettano, le cartelle sincronizzate si annotano come nel foglio e con un
  giro in corso aspettano; «man mano» lascia stare le serie che la seconda
  regola svuota, finché non le si riprende. Limite: i capitoli scesi ad app
  chiusa entrano nel piano solo alla riapertura.
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
  sembrare nuovi, dopo, i capitoli che c'erano già — salvo quando cambia la
  base: una scheda (`SeriesSignals.isCard`) conta i capitoli del sito
  (`SeriesSignals.arrivalCount`), le altre gli archiviati, e il riferimento
  ricorda su quale dei due è stato preso (`SeriesArrivals.onSite`); al primo
  download, o tornando scheda, riparte da ciò che c'è senza annunciare.
  Ad app chiusa i conteggi del sito stanno sotto `<chiave>@site` in
  `record.json`, perché un numero del sito riletto come di archiviati
  fermerebbe le notizie. Le notifiche sono Kotlin
  puro (`ArrivalNotifier.kt`), nessun pacchetto. Ad app chiusa
  `LibraryWatchWorker.kt` (WorkManager, ogni ora) guarda solo la cartella
  locale: le serie da guardare gliele lascia Dart uscendo
  (`arrivals/watch.json`), quelle annunciate gliele rilegge Dart
  (`arrivals/record.json`). Drive non c'è perché servirebbe il token
  dell'account fuori dall'app.
