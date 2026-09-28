# CLAUDE.md — Workflow CI (Kagami)

## `ci.yml` (**CI**): quello di tutti

Gira sui runner di GitHub, non chiama repo o servizi esterni e funziona uguale in
ogni fork. È autonomo di proposito: la logica sta qui e non in un reusable, perché
un repo pubblico non può chiamare i workflow di un repo privato.

| Job | Quando | Cosa fa |
| :--- | :--- | :--- |
| `check` | push su `main`, PR, a mano | `.g.dart` allineati allo schema, `flutter analyze`, `flutter test`, `dart analyze` e `dart test` di `packages/kagami_archive` e `server` |
| `server-image` | idem | `docker build --target test`: i test del server con libvips |
| `android` | push su `main`, a mano (mai nelle PR) | APK (release di default, `build_mode` a mano), artefatto del run |

In un repo privato (il manutentore, un fork chiuso) `check` e `server-image` partono
solo a mano, e l'APK con loro: lì ci sono altre CI, e questa a ogni push costerebbe i
minuti del piano. Il gruppo di `concurrency` porta il nome del workflow, così un push su
`main` non annulla una release in corso.

`FLUTTER_VERSION` è quella del `CLAUDE.md` di root: si aggiornano insieme.

I `.g.dart` di drift stanno in git e l'APK non li rigenera: che siano allineati lo
controlla `check`, perché uno schema cambiato senza rigenerarli compila lo stesso e si
scopre solo a runtime.

`dart format` non si controlla: il progetto non lo segue, e accenderlo vorrebbe dire
riformattare tutto in un commit che non c'entra niente.

### Secret, tutti facoltativi

| Secret | Senza | Con |
| :--- | :--- | :--- |
| `GOOGLE_SERVICES_JSON` | APK senza account né Drive | il contenuto di `google-services.json` del proprio progetto Firebase |
| `ANDROID_KEYSTORE` | chiave nuova a ogni run: l'APK non si installa sopra il precedente e l'accesso con Google fallisce | il keystore con cui firmare, in base64 (`base64 -w0 <file>`); la sua SHA-1 va registrata in Firebase e il run la scrive nel riepilogo |
| `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | quelli di una chiave di debug (`android`, `androiddebugkey`) | quelli della propria chiave di release |
| `SENTRY_DSN` | Sentry spento | errori e crash sul proprio progetto Sentry |

## `release.yml` (**Release**): le versioni pubbliche

Solo a mano, da `main`, dopo aver alzato `version` in `pubspec.yaml`:

1. `version` legge la versione e si ferma se la release `v<versione>` esiste già;
2. `build` chiama `ci.yml` (`workflow_call`): stessi controlli, stesso APK;
3. `publish` rifiuta un APK firmato con una chiave di debug, poi crea la release con
   l'APK, il suo `.sha256` e l'impronta SHA-256 della firma nelle note.

Le release si firmano con la **chiave di release** (secret `ANDROID_KEYSTORE*`), sempre
la stessa: Android installa un aggiornamento solo sopra un APK con la stessa firma, e
cambiarla vorrebbe dire far disinstallare l'app a chiunque l'abbia.

## Il sync verso il repo pubblico

Lo sviluppo avviene in un repo privato, e il repo pubblico riceve le modifiche come PR
preparate da un workflow di quel repo (`public-sync.yml`, con la logica in
`.github/public-sync/sync.py`). Workflow, script e configurazione restano nel privato:
qui si vede solo il risultato.

- **Un commit per PR, mai la storia privata.** A ogni push su `main` del privato, il
  sync costruisce l'albero di `main` meno i percorsi della sua lista di esclusioni e lo
  mette in un commit nuovo il cui unico genitore è `main` di questo repo, sul branch
  `sync/<sha corto del privato>`. Il messaggio elenca i soggetti dei commit privati
  inclusi. Un percorso escluso che esiste qui resta com'è. Se l'albero coincide già
  con `main` non succede niente; una PR di sync nuova chiude quella ancora aperta.
- **Il trailer `Private-Sync: <sha>`** in fondo al commit e alla descrizione della PR
  dice qual è l'ultimo commit privato arrivato qui, e il sync seguente riparte da lì.
  Si può unire con merge, squash o rebase, purché il trailer resti l'ultima riga del
  messaggio.
- **Uno scanner blocca le fughe.** Prima del push controlla ogni file dell'albero e il
  messaggio: chiavi e token di servizi, configurazioni Firebase, keystore, chiavi
  private, dati personali e nomi dell'infrastruttura del manutentore. Se trova
  qualcosa il sync si ferma e il riepilogo dice file, riga e tipo, mai il valore.
- **Un commit fatto direttamente qui non si perde.** Se `main` di questo repo ha
  cambiamenti che non vengono da un sync, e la PR successiva li cancellerebbe, il sync
  si ferma e prepara la patch da riportare nel privato. Una PR di un contributore si
  unisce qui come sempre; i sync riprendono quando la modifica è anche nel privato.

## Gli altri workflow

`build-android.yml`, `check.yml` e `update-deps.yml` sono i thin wrapper del
manutentore sui suoi reusable privati e sul suo runner: solo `workflow_dispatch`, non
partono mai da soli e in un fork non servono. `copilot-setup-steps.yml` prepara
l'ambiente del Copilot cloud agent.
