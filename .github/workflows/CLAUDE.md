# CLAUDE.md — Workflow CI (Kagami)

## `ci.yml` (**CI**): quello di tutti

Gira sui runner di GitHub, non chiama repo o servizi esterni e funziona uguale in
ogni fork. È autonomo di proposito: analisi, test e l'APK delle release non devono
dipendere da nessun altro repo.

| Job | Quando | Cosa fa |
| :--- | :--- | :--- |
| `check` | push su `main`, PR, a mano | `.g.dart` allineati allo schema, `flutter analyze`, `flutter test`, `dart analyze` e `dart test` di `packages/kagami_archive` e `server` |
| `server-image` | idem | `docker build --target test`: i test del server con libvips |
| `android` | a mano, e chiamato da `release.yml` | APK (release di default, `build_mode` a mano; `split_per_abi` per uno per architettura), artefatto del run |

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

Valgono per `ci.yml` e per `build.yml`.

| Secret | Senza | Con |
| :--- | :--- | :--- |
| `GOOGLE_SERVICES_JSON` | APK senza account né Drive | il contenuto di `google-services.json` del proprio progetto Firebase |
| `ANDROID_KEYSTORE` | chiave nuova a ogni run: l'APK non si installa sopra il precedente e l'accesso con Google fallisce | il keystore con cui firmare, in base64 (`base64 -w0 <file>`); la sua SHA-1 va registrata in Firebase e il run la scrive nel riepilogo |
| `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | quelli di una chiave di debug (`android`, `androiddebugkey`) | quelli della propria chiave di release |
| `SENTRY_DSN` | Sentry spento | errori e crash sul proprio progetto Sentry |

## `build.yml` (**Build**): gli APK e l'IPA di ogni merge

A ogni push su `main` (in un repo privato solo a mano: lì un minuto macOS ne vale
dieci) tre job in parallelo, tutti sui runner di GitHub, con il reusable pubblico
[`GabryXnLab/flutter-ci`](https://github.com/GabryXnLab/flutter-ci)
(`flutter-build.yml`):

| Job | Artefatto |
| :--- | :--- |
| `android-per-abi` | un APK release per architettura: `arm64-v8a`, `armeabi-v7a`, `x86_64` |
| `android-universal` | l'APK release che le contiene tutte |
| `ios` | `Kagami-ios-release-unsigned.ipa`: `Payload/Runner.app` zippato, **non firmato** |

Flutter dà o gli APK per architettura o l'universale, mai tutti in un giro: da qui due
job. Gli APK si firmano con la chiave dei secret `ANDROID_KEYSTORE*` e il riepilogo di
ogni job ha la SHA-1 di ciascuno; con una chiave nei secret e una firma diversa il job
fallisce. Analisi e test non si ripetono: li fa `check` di `ci.yml` sullo stesso push.

L'IPA non ha firma perché serve un account Apple Developer: lo firma chi lo installa,
con AltStore o Sideloadly e il proprio Apple ID (un'app così dura sette giorni, poi
va rifirmata). Su iOS account e Drive restano spenti (Firebase si accende solo su
Android), quindi non serve `GoogleService-Info.plist`; Sentry sì, con `SENTRY_DSN`. I
plugin passano da Swift Package Manager, già integrato nel progetto Xcode: niente
`Podfile`, e il deployment target (15.0) è quello che chiedono i plugin Firebase.

`runner` è fisso a `github`: il self-hosted del manutentore non serve i repo pubblici,
e questo workflow esiste perché la build non dipenda da lui. Per questo non ha
nemmeno gli input `runner`, `max_workers` e `clear_cache` degli altri wrapper.

`SENTRY_DSN` arriva al reusable come `DART_DEFINES: SENTRY_DSN=…`: nel blocco `with:`
di un reusable i secret non si possono usare. Telegram: senza i secret
`TELEGRAM_BOT_TOKEN` e `TELEGRAM_CHAT_ID` (un fork, o questo repo se non li ha) la
notifica non parte e il run non avvisa.

## `release.yml` (**Release**): le versioni pubbliche

Solo a mano, da `main`, dopo aver alzato `version` in `pubspec.yaml`:

1. `version` legge la versione e si ferma se la release `v<versione>` esiste già;
2. `check` chiama `ci.yml` (`workflow_call`, `build_apk: false`): analisi, test e
   immagine del server, senza il suo APK;
3. `build` chiama `build.yml` (`workflow_call`): le stesse build di ogni merge, cioè un
   APK per architettura (`arm64-v8a`, `armeabi-v7a`, `x86_64`), l'universale e l'IPA
   iOS non firmata;
4. `publish` scarica gli artefatti di quel run (`Kagami-*-release*-<sha>`), rifiuta un
   APK firmato con una chiave di debug e crea la release con i quattro APK, l'IPA, un
   `kagami-<versione>.sha256` per tutti e, nelle note, quale scegliere e l'impronta
   della firma.

Con `--split-per-abi` Flutter somma al `versionCode` mille per l'architettura (arm64
2000): un APK per architettura si installa sopra l'universale, non il contrario. Le
note della release lo dicono: si sceglie un tipo di APK e si resta su quello.

Le release si firmano con la **chiave di release** (secret `ANDROID_KEYSTORE*`), sempre
la stessa: Android installa un aggiornamento solo sopra un APK con la stessa firma, e
cambiarla vorrebbe dire far disinstallare l'app a chiunque l'abbia.

## Il sync verso il repo pubblico

Lo sviluppo avviene in un repo privato, e il repo pubblico riceve le modifiche come PR
preparate da un workflow di quel repo: un thin wrapper sul reusable comune di
[`GabryXnLab/build-kit`](https://github.com/GabryXnLab/build-kit) (`public-sync.yml`,
con lo script in `public-sync/sync.py`), dove stanno anche i template per pubblicare
allo stesso modo un altro progetto. Il wrapper e la configurazione del progetto
(esclusioni, modelli dello scanner, eccezioni) restano nel privato: qui si vede solo il
risultato.

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
  private (i modelli generici del kit), più quelli del progetto e i dati personali e
  i nomi dell'infrastruttura del manutentore, che non stanno in nessun repo. Se trova
  qualcosa il sync si ferma e il riepilogo dice file, riga e tipo, mai il valore.
- **Un commit fatto direttamente qui non si perde.** Se `main` di questo repo ha
  cambiamenti che non vengono da un sync, e la PR successiva li cancellerebbe, il sync
  si ferma e prepara la patch da riportare nel privato. Una PR di un contributore si
  unisce qui come sempre; i sync riprendono quando la modifica è anche nel privato.

## Gli altri workflow

`build-android.yml`, `check.yml` e `update-deps.yml` sono i thin wrapper del
manutentore sugli stessi reusable, ma per il suo runner self-hosted: solo
`workflow_dispatch`, non partono mai da soli e in un fork non servono. `copilot-setup-steps.yml` prepara
l'ambiente del Copilot cloud agent.
