# Drive e sincronizzazione della cartella

Fatti d'area spostati dal `CLAUDE.md` di root. Codice: `lib/src/data/drive*.dart`, `network.dart`, `folder_sync*.dart`, `downloads.dart`.

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
