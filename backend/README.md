# Il backend di Kagami

Account, dati personali che seguono il lettore e inviti fra account vivono su un backend
**compatibile con Supabase, di chi compila**: un progetto Supabase, o un servizio che ne parla le
API (PostgREST, GoTrue, realtime). L'app lo trova con `--dart-define=BACKEND_URL=…` e
`--dart-define=BACKEND_ANON_KEY=…`; senza, nasce senza account.

Qui sta lo schema che quel backend deve avere, ed è l'originale: una tabella o una regola nuova
nasce qui, poi nel codice.

| File | Cosa |
|---|---|
| `migrations/NNNN_*.sql` | i passi, in ordine; uno applicato non si riscrive, se ne aggiunge un altro |
| `schema.sql` | le stesse migrazioni una dopo l'altra, per un backend nuovo |
| `rls-test.sql` | le regole, provate: una transazione che alla fine si annulla |
| `local-shim.sql`, `test.sh` | il minimo di Supabase su un Postgres usa e getta, per provarle senza un backend |

## Applicarlo

- Backend nuovo: `psql "$DATABASE_URL" -f backend/schema.sql`.
- Backend che ha già una parte dello schema: solo le migrazioni che mancano, in ordine.
- Poi `psql "$DATABASE_URL" -f backend/rls-test.sql`: deve finire con `rls-test: ok`.

Sul backend serve anche l'accesso con Google abilitato, con il client OAuth «Web» di chi compila
come destinatario del token (lo stesso che usa `google_sign_in` nell'app).

Un'app più nuova del backend non si rompe: una tabella che manca vale «funzione non disponibile».

## Le segnalazioni del social

`reports` (0005, `docs/social.md`) non ha nessuna regola di lettura: l'app scrive una segnalazione e
non la rilegge più, e nell'app non c'è un pannello di moderazione. Le legge **chi gestisce il
backend**, con `service_role` (la chiave di servizio, o `psql` come proprietario dello schema):

```sql
SELECT r.at, r.target, r.target_id, r.target_user, r.reason, r.note, r.snapshot
  FROM public.reports r ORDER BY r.at DESC;
```

`snapshot` è la copia del testo al momento della segnalazione: resta anche se l'autore lo toglie.
Un contenuto con tre o più segnalazioni (`flags`) l'app lo mostra coperto, non lo toglie: toglierlo è
una scelta di chi gestisce, con `DELETE` da `service_role`.

## Cambiarlo

Una migrazione nuova con il numero successivo, accodata a `schema.sql`, e il suo caso in
`rls-test.sql`; poi `backend/test.sh` e `flutter test test/backend_config_test.dart`, che controlla
che `schema.sql` e le migrazioni dicano la stessa cosa.
