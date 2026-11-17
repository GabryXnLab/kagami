# Archiviare: cartella condivisa e schede manuali

Fatti d'area spostati dal `CLAUDE.md` di root. Codice: `packages/kagami_archive/` (vincoli del pacchetto nel suo `CLAUDE.md`), `lib/src/archive/`, `lib/src/ui/archive_*.dart`. Formato: `malf.md`.

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
  pixel la verifica non si risolve da sola. «Verifica» apre subito la
  pagina visibile, che si chiude da sola se la verifica è ancora buona; i
  cookie si scrivono su disco appena presi, perché il controllo della notte
  gira in un processo nuovo. Con il server che controlla, il giro notturno
  del telefono gli chiede le serie ferme alla verifica, le apre nella sua
  WebView invisibile e gli manda le pagine (`passServerGated`): la verifica
  data sul telefono serve anche al server, finché il sito la tiene buona, e
  la notifica resta solo per quelle che non passano. Si seguono solo le serie in corso scaricate
  dall'app: quelle del server le segue il suo timer. Una serie esce dal
  controllo solo se il sito la dà per conclusa o cancellata, dopo aver messo
  in coda gli ultimi capitoli; un lavoro automatico si aggiunge a quello
  dell'utente per la stessa serie, non lo sostituisce. Scaricando «man
  mano» (`ArchiveJob.ahead`, `TrackedSeries.ahead`) l'app tiene cinque
  capitoli da leggere davanti al lettore (`data/read_ahead.dart`, a ogni
  stato pubblicato e libreria riletta), e il controllo porta dal sito solo i
  capitoli nuovi che lei chiede (`TrackedSeries.wanted`). Il controllo
  quotidiano senza rete si riprova dopo mezz'ora, e all'avvio l'app rimette
  la catena se si è spezzata (`ExistingWorkPolicy.KEEP`). Chi scarica e
  controlla lo sceglie l'utente (`archive.engine` fra le impostazioni,
  `archiveEngineProvider`): tutto il server o tutto il telefono — serie
  nuove, man mano, controllo —, mai metà e metà. Chi controlla guarda ogni
  giorno le serie che segue lui e tutte le altre serie in corso della
  libreria (`checkLibrary`: nuovi sono i capitoli che l'`index.json` della
  serie non elenca, non quelli non archiviati, che possono esserlo per
  scelta), tranne quelle di «Smetti di seguire» (`archive.unfollowed`, al
  server con `PUT /v2/check`; riscaricare la serie la fa seguire di nuovo).
  Il telefono lo fa con `checkFromPhone` su Drive o, senza, sulla cartella
  scelta, e il suo controllo non si spegne; l'altro lato non controlla
  niente. `ArchiveEngineSync` porta tutto in `archive/check-scope.json`,
  letto ad app chiusa, nella catena del controllo e sul server.
- **Riparare le serie archiviate si lancia da chi lavora, mai da tutti e due.**
  Per una serie (scheda della serie), per un sito o per tutta la libreria
  (Scarica un manga, sotto «Serie seguite»): con il motore server è
  `POST /v2/repair`, offerto solo se `ServerInfo.repair`; con il telefono è
  `repairLibrary` in primo piano sulla libreria di Drive — mai sulla copia
  sincronizzata, che rinominerebbe — o, senza Drive, sulla cartella scelta
  (`lib/src/archive/repair.dart`). Gli esiti vanno nella cronologia con
  `ArchiveOutcome.repair`, letti da `archiveOutcomeText`. Quando un sito passa
  da rotto a sano (`siteHealthProvider`: file del telefono o `check.sites` del
  server; una lettura fallita non conta come «sano») `SiteRecoveryNotifier` lo
  propone una volta per ritorno, fra le impostazioni (`archive.siteRecovery`).
- **Una scheda è una serie MALF senza capitoli, non un dato dell'app.**
  Salvare un manga letto altrove (Scarica un manga → «Solo la scheda»,
  scheda manuale, Importa più link, Condividi) scrive `series.json`,
  copertina, indici e riga di libreria come un download con `ids` vuoto
  (`ArchiveJob.cardOnly`): così sopravvive a una reinstallazione e compare
  ovunque compaia la libreria. Il link generale è `source`. Le schede le
  scrive il telefono e mai il server; quelle in corso si seguono
  (`TrackedSeries.card`) riscrivendo solo l'indice. Un sito che Kagami non
  conosce è lo pseudo-provider `manual` (`packages/kagami_archive/lib/manual.dart`),
  chiave dal link normalizzato: nessun capitolo, solo il numero a cui si è
  arrivati (`seriesStates.reachedChapter`), e «Collega a un sito» porta poi
  i dati personali sulla serie vera (`moveSeries`). Lo stato dell'utente
  si scrive subito, prima che il lavoro finisca: è indicizzato per chiave e
  non aspetta che la serie esista, e così la raccolta scelta nella pagina
  della serie (`ArchiveChoice.collection`), con il telefono o con il server:
  l'ultima scelta (`archive.collection` fra le impostazioni) è la proposta
  della volta dopo, anche per Importa più link. «Arrivato al 52» vuol dire 52 letto
  (stimato) e si scarica dal 53.
