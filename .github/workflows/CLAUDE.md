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
| `ANDROID_DEBUG_KEYSTORE` | chiave nuova a ogni run: l'APK non si installa sopra il precedente e l'accesso con Google fallisce | il proprio `debug.keystore` in base64 (`base64 -w0 ~/.android/debug.keystore`), la cui SHA-1 è registrata in Firebase |
| `SENTRY_DSN` | Sentry spento | errori e crash sul proprio progetto Sentry |

## Gli altri workflow

`build-android.yml`, `check.yml` e `update-deps.yml` sono i thin wrapper del
manutentore sui suoi reusable privati e sul suo runner: solo `workflow_dispatch`, non
partono mai da soli e in un fork non servono. `copilot-setup-steps.yml` prepara
l'ambiente del Copilot cloud agent.
