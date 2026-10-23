# Dati personali, backup, account

Fatti d'area spostati dal `CLAUDE.md` di root. Codice: `lib/src/data/db/database.dart`, `user_repository.dart`, `backup.dart`, `cloud.dart`, `statistics.dart`.

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
  quei campi. Una colonna illeggibile vale una raccolta semplice.
- **Nell'account viaggia il file di backup, non le tabelle.** Quello che
  l'app mette su Firestore è esattamente ciò che esporta come file — gli
  stessi byte compressi, in un `Blob` dentro `readers/{uid}` — perché le
  regole con cui due copie si fondono esistono già, sono quelle del backup e
  sono provate. Rispecchiare campo per campo avrebbe voluto dire tenere lo
  schema in due posti e riscriverle una seconda volta. Sincronizzare è quindi
  `import(remoto, merge)` seguito dal rinvio del risultato, e avviene in tre
  momenti soltanto — all'avvio, uscendo dall'app e a richiesta — perché
  mandare su i dati a ogni pagina girata terrebbe accesa la radio per tutta
  la lettura. Non si manda mai su senza aver fuso (la `revision` del documento
  dice se un altro ha scritto), e il backup di Android è spento: rimetteva
  un database vecchio che la prima uscita dall'app scriveva sopra l'account.
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
