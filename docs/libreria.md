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
  scelta, spazio privato dell'app e Drive sono `LibraryShelf` in ordine di
  preferenza (`data/library.dart`); le serie si uniscono per chiave, i
  capitoli per id, e ogni capitolo si legge dalla prima sorgente che lo sa
  servire. Un capitolo locale conta solo se la sua cartella c'è davvero
  (una lettura di `chapters/` per serie), altrimenti si legge da Drive o si
  mostra come non scaricato. L'icona d'origine compare solo quando Drive c'è.
- **Una serie adottata cambia chiave, non identità.** Una riga con la chiave
  nei `formerKeys` di un'altra si ignora nell'unione delle sorgenti
  (`LibraryCatalog.merge`), sia locale sia di Drive: sul telefono la riga
  vecchia di `library.json` resta finché non la riscrive chi l'ha scritta. I
  dati personali la seguono con `adoptFormerKeys` (`data/adoption.dart`,
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
  l'app gli lascia `cleanup/plan.json`, ogni capitolo con la sua scadenza e la
  cartella di Drive, rifatto a ogni stato pubblicato; Drive lo apre con
  `DriveRepository.withdrawPaths`, e `withdrawn.json` l'app lo rilegge quando
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
