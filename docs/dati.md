# Dati personali, backup, account

Fatti d'area spostati dal `CLAUDE.md` di root. Codice: `lib/src/data/db/database.dart`, `user_repository.dart`, `backup.dart`, `cloud.dart`, `statistics.dart`.

- **Lo stato utente vive nel database dell'app**, non più in `reading/`. La
  cronologia è una riga per capitolo letto con la sua data, e le statistiche
  sono raggruppamenti per data: su un JSON riletto e riscritto per intero a
  ogni gesto non stavano in piedi. `reading/state.json` e `collections.json`
  si leggono **una volta sola**, per importarli, e non si riscrivono più.
- **Il backup è ciò che prima faceva la cartella sincronizzata.** Un file
  compresso esportabile dove si vuole, più una copia automatica al giorno (cinque
  tenute) in `<support>/backup/`, lo spazio dell'app: mai nella libreria, che si
  condivide (D5). Quelle copie proteggono da una fusione o un ripristino
  sbagliati, non dalla perdita del telefono. L'utente può scegliere
  una cartella del telefono dove la copia va anche (`backup_folder.dart`): la
  scelta è una nota del dispositivo (`<support>/backup-folder.json`, non
  un'impostazione, non viaggia con backup e account), si rifiuta se sta dentro
  la radice di una sorgente locale, e un file illeggibile non vale «nessuna
  cartella» (la copia extra salta, nulla si riscrive). Le vecchie copie di
  `reading/backup/` e i JSON storici già importati si spostano da lì una volta
  per cartella (`reading_migration.dart`, segno `moved.reading:<radice>`).
  Ripristinando si sceglie se fondere o sostituire; fondendo, i capitoli letti
  si uniscono — un capitolo letto non torna mai da leggere — e sul resto vince
  il record con `updatedAt` più recente, impostazioni comprese: la
  sincronizzazione d'avvio altrimenti rimetteva il valore vecchio in rete
  sopra una cartella di Drive appena scelta. Sessioni e segnalibri non hanno
  un «più recente»: un indice unico li tiene una volta sola, perché la
  sincronizzazione è una fusione e un doppione rifuso a ogni giro raddoppia.
- **Ogni tabella ha `profileId`.** Oggi il profilo è uno solo, ma la libreria è
  condivisa: è il gancio previsto per più lettori sullo stesso archivio.
- **Nel database non entra la libreria.** Gli indici MALF sono già la forma
  indicizzata e li scrive qualcun altro: copiarli significherebbe mantenere una
  seconda versione da invalidare a ogni sincronizzazione. Il campo `signature`
  dice se una serie è cambiata senza confrontare i capitoli.
- **La cartella di Drive è un'impostazione del database** (`drive.folder`),
  quindi viaggia con backup e account: su un telefono nuovo la libreria
  compare al primo accesso.
- **Le proprietà di una raccolta (regole, caratteristiche, serie automatiche e
  saltate) stanno in una colonna JSON sola**, `collection_rows.properties`
  (schema 10), e nel backup come campi facoltativi di `Collection.toJson`
  (`rules`, `traits`, `auto`, `skipped`), scritti solo se non vuoti: un
  backup vecchio si legge e uno nuovo letto da un'app vecchia perde solo
  quei campi. Una colonna illeggibile vale una raccolta semplice. Anche
  «vincolante» sta lì (`rules.binding`, scritto solo se vero e con almeno un
  criterio), senza colonne nuove.
- **Nell'account viaggia il file di backup, non le tabelle.** Quello che
  l'app mette nel backend è esattamente ciò che esporta come file — gli
  stessi byte compressi, in base64 dentro `data.payload` della riga di
  `readers` del lettore — perché le regole con cui due copie si fondono
  esistono già, sono quelle del backup e sono provate. Rispecchiare campo per
  campo avrebbe voluto dire tenere lo schema in due posti e riscriverle una
  seconda volta. Sincronizzare è quindi `import(remoto, merge)` seguito dal
  rinvio del risultato, e avviene in tre momenti soltanto — all'avvio, uscendo
  dall'app e a richiesta — perché mandare su i dati a ogni pagina girata
  terrebbe accesa la radio per tutta la lettura. Non si manda mai su senza
  aver fuso (la `revision` della riga dice se un altro ha scritto), e il
  backup di Android è spento: rimetteva un database vecchio che la prima
  uscita dall'app scriveva sopra l'account. `CloudSync` parla con un
  `ReaderStore`, non con le tabelle: una lettura fallita lancia e non si
  scrive niente, una riga assente fa caricare i dati di qui senza fondere. La
  riga si trova per proprietario (`owner`), non per `id`: chi arriva da
  Firebase (dove l'account stava prima) ha una riga importata con l'`id` di allora, e chi scrive lo riusa
  (`SupabaseReaderStore`, `lib/src/data/reader_store.dart`); `updated_at` lo
  mette il backend, non l'orologio del telefono.
- **L'accesso passa dal token d'identità, non dal browser.** `google_sign_in`
  chiede al sistema chi è l'utente e il backend verifica la firma del token
  (`signInWithIdToken`), poi tiene la sessione da sé, nell'archivio sicuro del sistema
  (`backend_session.dart`, non nelle preferenze; la sessione di prima vi passa al primo avvio). Per conto di quale
  client OAuth chiederlo lo dice `--dart-define=GOOGLE_SERVER_CLIENT_ID`, o
  in sua assenza `google-services.json`. Chi era entrato quando l'account
  stava su Firebase rientra da sé al primo avvio: se il backend non ha
  sessione, si chiede a Google lo stesso account senza finestre
  (`attemptLightweightAuthentication`); uscire lo segna, così chi è uscito non
  rientra. Al Kagami Server l'app manda il
  token della sessione del backend. Su una piattaforma senza accesso con
  Google — la build Linux, che serve solo a verificare che il codice compili
  — la sezione «Account» dice che non c'è.
- **Il backend dell'account è di chi compila, e parla come Supabase.** L'app
  non ne conosce nessuno: indirizzo e chiave pubblica arrivano con
  `--dart-define=BACKEND_URL` e `BACKEND_ANON_KEY`
  (`lib/src/data/backend.dart`), e senza la build nasce senza account. Lo
  schema che quel backend deve avere sta in `backend/` — migrazioni numerate,
  lo stesso contenuto in `schema.sql`, le regole provate da `rls-test.sql` — ed
  è l'originale: una tabella nuova nasce lì, poi nel codice. Il codice regge
  un backend rimasto indietro: tabella assente o non concessa vuol dire
  «funzione non disponibile» (`backendFailure`), mai «non c'è niente», perché
  da un «niente» chi sincronizza conclude che può scrivere senza fondere. Firebase
  non c'è più nell'app: accesso, dati personali e inviti a un server
  (`server_access.dart`) stanno tutti sul backend.
- **I grafici hanno una tavolozza verificata**, non scelta a occhio: sei tinte
  in ordine fisso, controllate per chi non distingue i colori come la
  maggioranza su entrambe le superfici. L'ordine non si cicla e nessun grafico
  affida l'identità al solo colore: accanto ci sono legenda e valori.

## Un database per account

Decisione del proprietario (2026-11-14): cambiare account sullo stesso telefono vuol dire cambiare file,
**mai fondere**. Codice: `lib/src/data/db/account_databases.dart`, `lib/src/ui/account_scope.dart`.

- **File.** In `<documents>/`: `kagami-guest.sqlite` per l'uso senza account, `kagami-u-<uid>.sqlite` per
  un account (`uid` = id dell'utente sul backend, accettato solo se `^[A-Za-z0-9-]{1,64}$`: un dato remoto
  non diventa mai un percorso). Lo schema è lo stesso di sempre, cambia solo quale file si apre.
- **Nota dello slot** (`kagami-slot.json`, scritta su file temporaneo e rename): lo slot attivo, in tre
  stati. *Assente*: mai deciso, si migra. *Illeggibile*: errore, si apre lo slot della sessione **senza**
  migrare né riscrivere la nota, e lo si manda a Sentry. *Presente*: si apre quello.
- **Lo slot segue l'account voluto, non la sessione** (`nextSlot`, pura): un accesso, anche silenzioso, con
  uid diverso dallo slot porta a `u-<uid>`; `signOut` e `forget` portano a `guest`, dopo l'invio dei dati che
  c'è già; un evento di sessione persa (`null`) non cambia niente, perché a schermo restano i dati di prima e
  solo la sincronizzazione non parte. Uscire quindi «nasconde» i dati dell'account: restano nel suo file,
  non visibili finché non si rientra con lo stesso account.
- **Contenitore.** `AccountScope` monta `ProviderScope(key: ValueKey(slot))`: cambiare slot smonta tutto, e
  `databaseProvider` chiude il suo file. Un `KagamiDatabase` è legato a un file solo, perciò una scrittura
  rimasta in volo fallisce invece di finire nell'altro.
- **Guardia uid-sessione = slot.** `CloudSync.sync/forget` e la pubblicazione del profilo social lavorano solo
  se l'uid della sessione è quello dello slot (`guest` non sincronizza mai): altrimenti non leggono né
  scrivono. Chiude la corsa fra `signIn()` e il vecchio contenitore, che manderebbe il file `guest` nella
  riga del nuovo account.
- **`adoptLegacy`.** Una volta, se la nota è assente e `kagami.sqlite` esiste: lo slot che lo adotta è
  l'uid della sessione ripristinata (si attende il rientro silenzioso fino a 5 s) oppure `guest`; copia con
  `VACUUM INTO` su file temporaneo e rename (un journal rimasto viene riapplicato); un target già presente
  non si tocca; poi nota, copie storiche in `backup/<slot>/` e il vecchio file diventa
  `kagami.sqlite.adopted`, che resta. Idempotente dopo un crash a ogni punto. Chi si aggiorna senza sessione
  né rientro entro 5 s finisce in `guest`: i dati mai sincronizzati si recuperano con Esporta e Importa.
- **Backup per slot.** `<support>/backup/<slot>/`; la copia extra va in `<cartella scelta>/<slot>/`, così la
  potatura di uno slot non tocca l'altro. Elenco e ripristino vedono solo lo slot attivo; Esporta, Importa e
  `wipe()` lavorano sul file attivo. Importare un backup in un altro slot è l'unico modo, manuale, di portare
  dati da un account all'altro.
- **Giri ad app chiusa.** Non aprono il database (leggono note del dispositivo in `<support>`), e così
  resta: un giro futuro che ne avesse bisogno apre **lo slot della nota** (`AccountDatabases.readNote`,
  `resolveActive`), **mai quello della sessione**. Le note che copiano dati del database (cartella di Drive,
  server, piano della pulizia) le riscrive ogni contenitore nuovo, anche con `SetupScreen` a schermo.
- **Resta del dispositivo**: cartella del telefono, stato di Drive per cartella, coda dei download e copie
  scaricate. I file degli account usciti restano sul telefono, senza una schermata per toglierli.
- **Collaudo a due account**: non ancora fatto (serve un secondo account), vedi `FASE-9.md`.
