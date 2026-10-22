# CLAUDE.md — Kagami

## Cos'è

Lettore di manga per archivi MALF già pronti. Non conosce nessun sito: legge
una cartella sincronizzata sul telefono, la stessa cartella direttamente su
Google Drive, o tutte e due insieme, e la presenta come un lettore musicale
presenta una discoteca — raccolte, ripresa della lettura, stato e voto per
ogni serie. Da Drive legge in streaming e scarica sul telefono solo ciò che
l'utente sceglie. Può anche archiviare da sé: da una ricerca o da un link
(Impostazioni → Scarica un manga) scarica una serie dal sito nella cartella di Drive o sul telefono,
con lo stesso motore dell'estensione MangaArchive portato in Dart
(`packages/kagami_archive/`). Lo stesso motore gira anche in **Kagami
Server** (`server/`), un programma che chiunque può tenere acceso su un suo
computer perché scarichi e carichi su Drive al posto del telefono, per sé e
per gli account Google che ammette: l'app lo crea generando un comando
`docker run` e gli parla col token dell'account (protocollo in
`docs/server-api.md`).

La cartella arriva da questa catena, che l'app non controlla (salvo l'ultimo
tratto, se l'utente lo affida a lei) e su cui non deve fare assunzioni oltre
al formato:

```text
MangaArchive (estensione Cobalt, server) ──┐
Kagami (Scarica un manga, telefono) ───────┤
Kagami Server (computer dell'utente) ──────┤
  → cartella Google Drive ─────────────→ Kagami (streaming)
    → sincronizzazione di Kagami o FolderSync
      → cartella locale ───────────────→ Kagami
```

Gli archiviatori scrivono nella stessa cartella di Drive e convivono con le
regole di «Chi scrive» in `docs/malf.md`.

Il contratto con l'archivio è il formato **MALF**, specificato in
[docs/malf.md](docs/malf.md). **L'originale è quello, in questo repo**: un
campo nuovo si aggiunge prima lì, poi in `packages/kagami_archive/` (chi scrive) e in
`lib/src/format/malf.dart` (chi legge). Gli archiviatori esterni come
`mangaarchive` seguono la specifica di Kagami, non il contrario: allinearli è
compito loro, e una loro modifica al formato non vale finché non entra qui.
Un dato che esiste solo nell'app non sopravvive a una reinstallazione.

Leggere [docs/design.md](docs/design.md) prima di lavorare sull'interfaccia o
sul modello dei dati: contiene le funzionalità attese, le scelte già prese e i
motivi per cui sono state prese.

## Stack

Flutter 3.47 / Dart 3.13, gestione pacchetti `flutter pub` (mai `dart pub` qui).

Interfaccia in nove lingue con `flutter_localizations` e `gen-l10n` (`l10n.yaml`):
i testi stanno in `lib/l10n/app_<lingua>.arb`, il codice `app_localizations*.dart`
lì accanto è generato da `flutter gen-l10n` (o `flutter pub get`) e va nel commit.

Stato con `flutter_riverpod` 3 — niente `StateProvider`, che nella 3 è legacy:
si usano `Notifier` e `NotifierProvider`. Interfaccia Material 3 vestita con un
kit di componenti proprio (`lib/src/ui/widgets/kit.dart`), carattere **Figtree**
in `fonts/` e icone **Lucide** (`lucide_icons_flutter`): una famiglia sola, mai
`Icons.*` accanto a quelle.

Account con `firebase_core`/`firebase_auth`/`cloud_firestore` e
`google_sign_in`: fanno seguire i dati personali al lettore invece che al
telefono e, con l'autorizzazione `drive.readonly`, danno il token con cui
l'app legge Drive — l'API REST, chiamata con `dart:io` senza pacchetti
`googleapis`. Il progetto Firebase è di chi compila:
`android/app/google-services.json` dice all'app qual è, resta fuori da git e
senza di lui l'app nasce senza account né Drive (`cloudAvailable`).

Dati personali su SQLite con `drift` (+ `drift_flutter`): le query girano in un
isolate e il codice delle tabelle è **generato**, quindi dopo ogni modifica a
`lib/src/data/db/database.dart` va rieseguito `build_runner`. Grafici con
`fl_chart`, schermo sempre acceso in lettura con `wakelock_plus`.

L'archivio usa `html` (le pagine di ManhwaRead), `crypto` (SHA-256 dei
manifest, MD5 della ricevuta di Drive), `unorm_dart` (la NFKC dei nomi di
cartella, uguale a quella di Python) e `webview_flutter` (la verifica di
Cloudflare, superata dall'utente).

Errori e crash vanno su **Sentry** (`sentry_flutter`), se chi compila passa il
suo DSN con `--dart-define=SENTRY_DSN=…`; senza, Sentry resta spento.
`SentryFlutter.init` in `lib/main.dart` avvolge sia l'app sia i giri ad app
chiusa. `sentry_flutter` 9 fissa `jni` alla 0.14, per questo
`path_provider_android` resta alla 2.2.

Nessun valore personale nel codice: progetto Firebase, DSN di Sentry, chiavi di
firma, segreto del client «Web» e indirizzi del server sono di chi compila o di chi installa,
e arrivano da file fuori da git, da `--dart-define` o dalle variabili del server.
Le note di una macchina o di un manutentore vanno in `CLAUDE.local.md`, che git
ignora.

## Struttura

Albero completo (ogni file di `lib/`, del pacchetto, del server e dei test, con una riga di
descrizione): [docs/struttura.md](docs/struttura.md). In breve:

```text
lib/                  l'app Flutter (src/format, archive, data, ui; l10n/ i testi in nove lingue)
packages/kagami_archive/  l'archiviatore, Dart puro: lo usano l'app e il server
server/               Kagami Server, Dart puro (`dart compile exe`), Dockerfile
test/, test_driver/   test dell'app; l'app con Flutter Driver acceso per l'MCP di Dart
docs/                 design.md, malf.md (formato), server-api.md, server.md e i documenti d'area (tabella sotto)
firestore.rules       il proprio documento solo a sé; gli inviti ai server a mittente e destinatario
fonts/, assets/       Figtree; icone dei siti da cui si archivia
.github/workflows/    CI, APK e IPA di ogni merge, release, wrapper del manutentore (+ CLAUDE.md proprio)
```

## Comandi

```bash
flutter pub get
dart run build_runner build     # codice di drift, dopo ogni modifica allo schema
flutter analyze                 # deve restare senza segnalazioni
flutter test
(cd packages/kagami_archive && dart analyze && dart test)   # l'archiviatore, Dart puro
(cd server && dart pub get && dart analyze && dart test)    # il server
(cd server && dart compile exe bin/kagami_server.dart -o kagami-server)
docker build -f server/Dockerfile --target test .   # i test del server con libvips, dentro l'immagine
docker build -f server/Dockerfile -t kagami-server . # l'immagine; contesto la radice del repo
flutter build apk --debug       # con google-services.json: account e Drive
flutter build apk --release --dart-define=SENTRY_DSN=…   # Sentry facoltativo
flutter build apk --release --dart-define=GOOGLE_SERVER_CLIENT_SECRET=…   # per creare e collegare server
flutter build linux --debug     # solo per vedere che compili: niente Firebase
flutter build ios --release --no-codesign   # solo su macOS; l'IPA non firmato lo fa build.yml

firebase deploy --only firestore:rules   # le regole di sicurezza, sul proprio progetto
```

La CI pubblica è `.github/workflows/ci.yml`: analisi e test su runner di GitHub,
senza servizi esterni. Gli APK release (per architettura e universale) e l'IPA iOS
non firmato di ogni push su `main` li fa `build.yml`, con il reusable pubblico
`GabryXnLab/flutter-ci`. Funzionano anche in un fork, con i secret di chi compila;
dettagli nel `CLAUDE.md` della cartella.

`test_driver/app.dart` è l'app con Flutter Driver acceso, per provarla con l'MCP
di Dart (`dart mcp-server`) su un emulatore o un telefono: `launch_app` con
`target` `test_driver/app.dart`, poi `set_frame_sync` a `"false"` e
`set_semantics` a `"true"`; le voci della barra in basso si trovano con
`BySemanticsLabel`, perché il loro testo esiste solo quando sono selezionate.
Quale build: **profile** per le prestazioni e per i cicli che non si fermano —
la debug ha gli assert di Riverpod, che nascondevano il giro infinito della
sincronizzazione —, **release** per i crash che vengono da R8. L'accesso con
Google funziona solo con una chiave di firma la cui impronta SHA-1 è registrata
nel proprio progetto Firebase.

## Aree (instradatore)

I fatti d'area stanno nei documenti di sottosistema; si leggono prima di toccare i file indicati.
Un `CLAUDE.md` annidato si carica da solo lavorando in quella cartella.

| Area | File | Da leggere |
|---|---|---|
| Kagami Server (identità, `KAGAMI_SETUP`, utenti, coda, aggiornatore) | `server/`, `lib/src/ui/archive_server.dart`, `lib/src/data/server_access.dart` | `server/CLAUDE.md` (annidato), `docs/server-api.md`, `docs/server.md` |
| Archiviatore: pacchetto Dart puro, un file per sito | `packages/kagami_archive/` | `packages/kagami_archive/CLAUDE.md` (annidato), `docs/malf.md` |
| Archiviare: cartella condivisa, schede manuali, indici su Drive | `lib/src/archive/`, `lib/src/ui/archive_*.dart` | `docs/archivio.md` |
| Libreria ibrida, indici, cancellazioni, capitoli nuovi e «Novità» | `lib/src/data/library*.dart`, `series_removal.dart`, `arrivals.dart`, `notifications.dart` | `docs/libreria.md`, `docs/malf.md` |
| Lettore: tavole, fasce, decodifica, posizione di lettura | `lib/src/ui/reader_*.dart`, `page_bands.dart`, `lib/src/data/page_decoder.dart` | `docs/lettore.md` |
| Dati personali, backup, account, grafici | `lib/src/data/db/`, `user_repository.dart`, `backup.dart`, `cloud.dart`, `statistics.dart` | `docs/dati.md` |
| Drive, rete, cache, sincronizzazione della cartella | `lib/src/data/drive*.dart`, `network.dart`, `folder_sync*.dart`, `downloads.dart` | `docs/drive.md` |
| Testi e lingue | `lib/l10n/`, `lib/src/l10n.dart` | `lib/l10n/CLAUDE.md` (annidato) |
| Interfaccia e scelte di prodotto | `lib/src/ui/` | `docs/design.md` |
| CI, build, release | `.github/workflows/` | `.github/workflows/CLAUDE.md` (annidato) |

⚠️ Documenti grandi: `docs/design.md` (71 KB) e `README.md` (26 KB) non si leggono interi, `rg -n` e
poi la sezione; `docs/malf.md` e `docs/server-api.md` (15 KB ciascuno) solo per la parte che serve.

## Note architetturali importanti

- **Kagami è indipendente da Cobalt Extended, e resta così.** Il progetto
  è pubblico e deve funzionare per chiunque. Chi non ha mai installato
  `cobalt-extended` deve avere un'app completa. Kagami non ne importa codice,
  non lo presuppone installato e non ne chiama le API, né quelle di
  `mangaarchive` né quelle di RemoteGate. `mangaarchive` è solo uno degli
  archiviatori che possono scrivere una libreria MALF nella stessa cartella.
  Anche il server per scaricare lontano dal telefono è di Kagami, sta in questo
  repo e parla un protocollo di Kagami. Non va mai sostituito con
  `mangaarchive`, Cobalt o un servizio del manutentore, nemmeno «per ora».
- **`permission_handler` è fermo a `^12.0.0` di proposito.** La 14 dichiara
  `compileSdk = 37`, mentre l'Android Gradle Plugin generato da Flutter 3.47
  (9.1.0) supporta al massimo 36, e una platform `android-37` "pura" non esiste
  più nel repository di Google: ci sono solo `37.0`, `37.1`, `37.2`. Alzare il
  vincolo senza aggiornare AGP fa fallire la build.
- Il resto dei vincoli per area è nei documenti della tabella sopra: spostati lì senza riassumerli,
  con le stesse parole.

## Strumenti per gli agenti

Workflow degli agenti: ricetta ottimizza-claude rev. 2026-10-15.2. Gli strumenti stanno in
`scripts/agent/` e `.claude/` (non vanno nel repo pubblico).

| Cosa | Dove |
|---|---|
| stato del repo all'avvio (hook) | `scripts/agent/session-brief.sh` |
| verifica sul diff (`flutter analyze`, test relativi ai file toccati, `dart analyze`/`dart test` di pacchetto e server); `--full` per tutto | `scripts/agent/verify.sh` |
| `dart analyze` dei file toccati a fine turno (hook Stop; esce se `stop_hook_active`) | `scripts/agent/stop-check.sh` |
| output di `flutter test`/`dart test` su file: a Claude arrivano errori, coda ed exit code veri (`--full-output` per averlo intero; log in `.claude/.cache/`) | `scripts/agent/filtra-output.sh` (hook PreToolUse con `if`) |
| guardie: `dart format`, npm/yarn, segreti in `git add`, build senza timeout; edit a mano di `*.g.dart` e `app_localizations*.dart` | `scripts/agent/guard-bash.sh`, `guard-edit.sh` |
| brief comune dei subagenti che scrivono codice | `scripts/agent/brief-subagente.md` — il prompt non lo ricopia |
| agenti di progetto: `correttore` (sonnet, 1-3 difetti dalla causa al test), `collaudatore` (haiku, collaudo a schermo sull'emulatore della macchina di prova, descritta nelle note locali) | `.claude/agents/` |
| skill di progetto: `riprendi`, `chiudi-sessione`, `piano` (handoff in `handoff/<feature>/`) | `.claude/skills/` |

Lettura: `rg -n` e poi `Read` con offset/limit; un file oltre ~400 righe non si legge intero.
Nessun subagente senza modello deciso (haiku per cercare e collaudare, sonnet per implementare con
un contratto chiaro, opus solo per causa ignota). Un subagente = 1-3 voci coese.

## Scelte e libertà

- Codice e identificatori in inglese; commenti, documentazione, commit e risposte in italiano.
- Commit atomici per voce, messaggio da file (`git commit -F`), mai `-m` con backtick o `$(…)`.
- Niente formattatori su file interi (il progetto non segue `dart format`), niente refactor non
  richiesto, commenti solo per il perché non ovvio. Mai `git stash` dove si usano worktree.
- Adozione, non sovrascrittura: una lettura fallita (Drive, disco, rete) non è «vuoto»; tre stati
  (*non ho potuto chiedere* ≠ *non c'è* ≠ *c'è*) davanti a ogni scrittura che parte da uno stato letto.
- Test verdi: un rosso si diagnostica, non si archivia come «noto»; nessuna feature dichiarata
  finita senza test.
- **Push su `main` solo se il proprietario lo chiede**: avvia `build.yml` (APK e IPA su runner) e
  `public-sync.yml` (PR sul repo pubblico). Mai force push.
- Libertà senza chiedere: ristrutturare file di documentazione e workflow (CLAUDE.md, skill, agenti,
  script) quando riduce lo spreco; cancellare codice morto coperto da test.

# Compact instructions

Nel riassunto conserva: voce in corso e criterio di fine, file modificati, comandi di verifica e
ultimo esito, decisioni del proprietario della sessione. Dopo la compattazione `session-brief.sh`
ristampa le note architetturali.

## Convenzioni

Codice e identificatori in inglese, commenti e documentazione in italiano.
I commenti spiegano il perché, non il cosa. Commit atomici, messaggi in
italiano. `flutter analyze` pulito prima di ogni commit.
