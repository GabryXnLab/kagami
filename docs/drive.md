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
- **Lo scope è `drive.readonly`, e `drive` solo per chi carica o condivide.** Leggere,
  scaricare e sincronizzare in sola discesa usano la sola lettura; lo scope
  completo (dichiarato nella schermata di consenso del progetto Google Cloud) si
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

## La libreria condivisa (contratto)

Un account lascia leggere la cartella della sua libreria su Drive (`drive.folder`, tutta, in sola
lettura) a un altro, per un tempo scelto quando lo concede. I pezzi sono tre, e ognuno dice una cosa sola:

| Dove | Cosa dice | Chi lo scrive |
|---|---|---|
| permesso di Drive (`reader`, `user`) sulla cartella | chi **può** leggere | chi condivide: `DriveClient.share`, `renewShare`, `unshare` |
| riga di `drive_shares` sul backend (`backend/`, migrazioni 0004 e 0010) | l'invito per chi riceve, **fino a quando** vale e se può anche **scaricare** | chi condivide; chi riceve la legge soltanto |
| `SourceConfig` di tipo `driveShared` in `library.sources` | che chi riceve ha accettato | chi riceve |

- **La scadenza è della riga, non di Drive.** A Drive si chiede di togliere il permesso da solo
  (`expirationTime`), ma lo concede solo ai lettori di una cartella, al massimo per un anno, e non è
  verificato per quali account: se rifiuta, `share` crea il permesso senza e lo dice con
  `DrivePermission.expiresAt` vuoto. `expires_at` della riga è il termine vero in ogni caso, e lo fanno
  valere in tre: Drive dove può; chi condivide, che ritira i permessi scaduti (l'app all'avvio, andando
  in secondo piano e aprendo il foglio; il suo Kagami Server all'ora giusta, `docs/server-api.md`); chi
  riceve, che da `expiresAt` in poi non legge più la sorgente anche se Drive risponde ancora.
- **Permesso di scaricare** (`drive_shares.download`, migrazione 0010, `DriveShare.download`): di serie falso =
  «solo streaming»; si sceglie in `DriveAccess.share(download:)` e si cambia con `DriveAccess.setDownload`, che
  scrive la sola riga (su Drive non cambia niente; il rinnovo lo conserva). È un patto fra app, non una
  protezione: il ruolo `reader` lascia scaricare a chiunque abbia l'accesso. Lo scrive solo chi condivide (chi
  riceve non ha `UPDATE` sulla riga: casi in `backend/rls-test.sql`, T21). Un backend senza la colonna rifiuta
  il campo (`PGRST204`, `42703`, `42501`): `SupabaseShareDirectory.put` riscrive la riga senza, e chi legge una
  riga senza il campo la tratta come «solo streaming»; su un backend così `setDownload` non cambia niente.
- **Passo zero: i dati personali escono dalla cartella** (`DriveAccess.personalData`, FASE-5b §2).
  Prima di `share` e di `renew` si cercano in `reading/` della cartella la cartella `backup` e i file
  `state.json` e `collections.json` (copie e stato di prima del database: `downloads.json` non è un dato
  personale e resta), e vanno nel cestino di Drive con lo scope completo che la condivisione chiede
  comunque (la finestra del consenso lo dice). Elenco o cestino falliti → nessun permesso: «non ho potuto
  controllare» non è «niente». Il foglio, se qualcuno legge già la cartella, rifà la ricerca: trovati →
  avviso con «Togli»; ricerca fallita → avviso che non ha potuto controllare.
- **Due scritture, in quest'ordine** (`lib/src/data/drive_access.dart`, `DriveAccess`):
  - *condividere*: prima il permesso, poi la riga. Se la riga non si scrive, il permesso si ritira; se
    nemmeno quello riesce resta un permesso senza riga, che il foglio mostra (sotto).
  - *rinnovare*: `renewShare` sullo stesso permesso — un 404 vuol dire che Drive l'ha già fatto scadere,
    e allora un permesso nuovo, senza rifare il passo zero — poi `permission_id` ed `expires_at` nella riga. Se la riga non si
    aggiorna non c'è niente da disfare: vale ancora il termine di prima.
  - *ritirare* (a mano o per scadenza): prima `unshare`, poi la riga, che si toglie **solo se Drive ha
    risposto** (tolto, o 404 = già tolto). Senza rete resta tutto e si riprova al giro dopo.
  - La passata delle scadenze non apre mai la finestra del consenso: se manca lo scope completo la riga
    resta, e il foglio la mostra scaduta con il suo «Togli».
- **L'indirizzo è quello che risponde Drive.** `to_email` è `DrivePermission.email` (minuscolo), non
  ciò che è stato digitato: chi riceve trova la riga con l'indirizzo verificato del suo account, e un
  alias scritto diverso non la troverebbe. `id` è i primi 32 caratteri esadecimali di
  `sha256("<from_email>|<to_email>|<folder_id>")`, e la tabella lo controlla. I testi stanno sotto i
  128 caratteri: un nome di cartella più lungo si tronca prima di scriverlo.
- **Chi riceve non toglie la riga** (a differenza di `server_invites`): è l'unico posto dove sta il
  termine quando Drive non lo tiene, e senza la riga il permesso resterebbe per sempre senza che
  nessuno lo sappia. Rifiutare un invito o togliere la sorgente è un fatto locale: `id` e `at`
  dell'invito finiscono nell'impostazione `drive.shares.dismissed`, e un invito riscritto dopo un
  ritiro ha un `at` nuovo e torna a proporsi.
- **Il foglio «Chi può leggere la mia libreria» dice il vero.** Elenca le righe di chi condivide
  (`mine()`, anche di una cartella che nel frattempo non è più la libreria) e, sotto, le persone che
  `sharedWith` trova su Drive senza una riga — condivise a mano dal sito di Drive, o rimaste da una
  scrittura a metà — senza termine e con lo stesso «Togli». Un permesso per link, dominio o gruppo è una
  riga d'avviso: si gestisce da Drive. Elencare funziona con `drive.readonly`; lo scope completo
  (`DriveAuth.authorize(write: true)`) si chiede al primo gesto che scrive, dopo aver detto che l'altra
  persona vedrà tutti i file della cartella.
- **Tre stati, come ovunque.** Righe non lette ≠ nessuna riga; `sharedWith` fallito ≠ nessun altro
  lettore (il foglio mostra le righe e dice che Drive non ha risposto). Tabella assente o `42501` è
  `ShareUnavailable`: su questo backend la funzione non c'è, e non si offre.
- **Chi riceve** rilegge le sue righe (`forMe`) all'avvio, tornando in primo piano e a ogni evento del
  realtime — che porta inviti e rinnovi, non i ritiri: di una riga tolta dice solo la chiave. Una riga
  che non è già una sorgente (`owner` + `folderId`) né fra i rifiutati è un invito: una notifica, una
  volta. Accettare aggiunge la sorgente, in sola lettura (`SourceCapabilities.readOnly`): `label` il
  nome della cartella, `params` `folderId`, `folderName`, `owner` (l'indirizzo), `ownerName`, e
  `expiresAt` della riga, e `account`, l'indirizzo (minuscolo) che ha accettato. La sorgente resta di quell'account: se entra
  un altro (o nessuno) resta in elenco ma non si legge (`SourceState.otherAccount`, «Di un altro account»: né scaduta né vuota, e lo
  stato di lettura non si tocca), e le righe di un altro account non la seguono né la scadono; una configurazione senza `account`
  lo prende alla prima rilettura **riuscita** in cui una riga combacia. A ogni rilettura **riuscita** la sorgente segue la riga: termine cambiato →
  cambia e la sorgente riparte da sola; riga sparita → scaduta da adesso, e resta in elenco. Una
  rilettura fallita non cambia niente. Scaduta o ritirata, le serie che venivano solo da lì escono
  dalla libreria e **lo stato di lettura non si tocca**; se Drive risponde 403 o 404 a una sorgente non
  scaduta è `SourceUnavailable`, mai «vuota».
- **Scaricare da una condivisione** (`lib/src/data/shared_copies.dart`): `params['download']` segue la riga a
  ogni rilettura riuscita e dà `SourceCapabilities.download`, cioè «Scarica» sulla scheda. Le copie vanno nello
  scaffale privato della sorgente, `<support>/drive-shared/<id>/library/` (un `LibraryRepository` privato, letto
  prima di Drive), **mai** nella cartella scelta: la sincronizzazione le porterebbe nel Drive dell'utente e la
  scadenza non le raggiungerebbe più. Seguono il permesso: termine passato (lo sa il telefono, senza rete, e
  ad app aperta la sorgente si spegne all'ora giusta), riga sparita, sorgente tolta o di un altro account → via
  copie, istantanea e cache delle tavole; `download` tornato falso → via le sole copie. Una rilettura fallita o
  un 403/404 non tolgono niente: fino al termine le copie si leggono senza rete. Per la pulizia e «Elimina
  serie» sono copie del telefono (FASE-5b §5).
- **Scadenza vicina.** Per le righe accettate (non rifiutate) con un termine, a 7 giorni e a 1 giorno
  una notifica locale, una volta per soglia (`lib/src/data/share_expiry_notice.dart`, impostazione
  `drive.shares.expiry.seen`), a ogni lettura riuscita delle righe e ad app aperta; toccandola si apre il
  foglio «Librerie condivise con me», che ha «Chiedi più tempo». Aperta a meno di un giorno dal termine
  dà solo l'avviso di 1 giorno. Il termine entra nell'id dell'avviso: un rinnovo lo cambia e riarma le
  soglie. Chi condivide, rinnovando dal messaggio, sceglie la durata come sul foglio (`RenewChoice`).
- **Di una riga è verificato solo chi l'ha scritta.** `from_email` e `from_uid` li garantisce il
  backend; `from_name` e `folder_name` li dichiara chi scrive. Invito e sorgente mostrano sempre
  l'indirizzo, il nome accanto. `from_uid` serve al social, dove gli indirizzi non esistono: è così che
  chi riceve trova a chi chiedere più tempo (`docs/social.md`).
- **Non provato dal vivo** (2026-11-14): le quattro chiamate sono provate contro un Drive finto
  (`test/drive_share_client_test.dart`), le regole su un Postgres usa e getta (`backend/test.sh`).
  Restano da vedere con due account veri: se Drive accetta `expirationTime` su un account personale, e
  se `emailAddress` della risposta è l'indirizzo principale del destinatario.
