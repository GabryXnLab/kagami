# Il lettore: tavole, fasce, posizione di lettura

Fatti d'area spostati dal `CLAUDE.md` di root. Codice: `lib/src/ui/reader_screen.dart`, `reader_metrics.dart`, `page_bands.dart`, `lib/src/data/page_decoder.dart`, `reader_settings.dart`. Misure e storia degli scatti: `handoff-scatti-lettore.md` (fuori da git).

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
- **Le modalità di lettura non sono MALF**: sono impostazioni di
  visualizzazione e il formato non le prevede. Stanno però nel database insieme
  al resto, quindi il backup se le porta dietro; una serie senza impostazioni
  proprie eredita quelle predefinite, che sono l'ultima scelta fatta.
