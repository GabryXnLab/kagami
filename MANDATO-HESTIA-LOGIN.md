# MANDATO — login con email e password (priorità massima)

Dal proprietario, 2026-11-24 (Hestia H129). **Prima di ogni altro lavoro non bloccante di questo progetto:**

1. Il **login principale** dell'app diventa **email + password** su Hestia: registrazione, accesso, «Password dimenticata?»
   e cambio password. **Google resta la seconda opzione**, sotto, separata («Continua con Google»).
2. Contratto, errori e regole d'interfaccia: `~/repos/hestia/docs/LOGIN-EMAIL-PASSWORD.md` (API GoTrue; nessun client
   nuovo da aspettare: usa il tuo, `hestia-client` non c'entra). Leggilo per intero prima di cominciare.
3. Stato del backend: il progetto Hestia `kagami` ha già registrazione e accesso con password attivi e provati dal vivo
   (2026-11-24). I token sono ES256 (JWKS sul gateway). Il server di Kagami accetta ancora i token Firebase
   (`KAGAMI_FIREBASE_PROJECT`): non rimuoverlo con questo mandato.
4. Se ti serve qualcosa che Hestia non ha (redirect, policy diversa, conferma email obbligatoria, template email), non
   aggirarlo: scrivi una richiesta in `~/repos/hestia/richieste/` (formato in `richieste/README.md`).
5. Chiusura: login e registrazione provati con un test (o su dispositivo, dichiarato), account Google esistente ancora
   funzionante, nessuna password in log. Poi cancella questo file e la riga in `CLAUDE.md`.
