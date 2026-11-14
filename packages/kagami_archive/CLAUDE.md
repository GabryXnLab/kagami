# CLAUDE.md — l'archiviatore (`packages/kagami_archive/`)

Vincoli del pacchetto Dart puro; il resto del progetto è nel `CLAUDE.md` di root. L'integrazione con la cartella condivisa, le schede manuali e l'app è in `../../docs/archivio.md`.

- **L'archiviatore è un pacchetto Dart puro** (`packages/kagami_archive/`),
  perché lo usano sia l'app sia il server, e il server non ha Flutter. Lì non
  entra niente di Flutter, Android o dell'account. Ciò che il telefono
  aggiunge arriva da fuori, per interfaccia: le immagini (`ImageTools`, sul
  telefono il Kotlin), il token (la funzione passata a `DriveClient`, sul
  telefono `DriveAuth`), la rete (`NetworkState`, sul telefono
  `NetworkMonitor`) e i guasti (`ArchiveRunner.onError`, sul telefono
  Sentry).
- **Un sito è un file, e nient'altro lo nomina.** Ogni provider sta in
  `packages/kagami_archive/lib/providers/<id>.dart`, usa `providers/kit.dart`
  per ciò che deve valere uguale per tutti (link accettati, testi, ordine e
  unicità dei capitoli) e si registra in `providers`; l'icona è
  `assets/providers/<id>.png`. App, server, coda e serie in corso non
  chiedono mai «quale sito»: un sito dietro Cloudflare lo dice con
  `Provider.browser` (`BrowserGate`: host dei cookie, segni della pagina
  vera), e da lì seguono WebView, ricerca invisibile, `snapshot` per il
  server e salto nei controlli automatici. `provider_contract_test.dart`
  ferma un sito registrato senza icona, con un id non valido o con una
  verifica su host non suoi. Un attrezzo che serve a due siti va nel kit,
  non copiato.
- **I siti degli utenti non sono file Dart.** Un sito descritto da un JSON
  (`docs/siti.md`, `providers/<id>.json` nella libreria) lo interpreta
  `declarative.dart` (`DeclarativeProvider`, nessun codice eseguito, host
  validati all'installazione). Il registro [providers] è un getter: inclusi
  (`builtInProviders`) più quelli degli utenti, sul telefono con
  `installUserProviders`, sul server per account con `withUserProviders` /
  `withUserProviderSource` (una zona: due account possono avere lo stesso id
  con file diversi). Un campo nuovo del formato si aggiunge prima in
  `docs/siti.md`, poi qui e in `test/declarative_test.dart`.
- **Perché ogni dipendenza** (spostato dal `CLAUDE.md` di root): `html` per
  le pagine di ManhwaRead, `crypto` per lo SHA-256 dei manifest e l'MD5 della
  ricevuta di Drive, `unorm_dart` per la NFKC dei nomi di cartella, uguale a
  quella di Python, `xml` per il `multistatus` di WebDAV (`webdav.dart`),
  letto per namespace e non per prefisso, che ogni server sceglie a modo suo.
  Nell'app, fuori dal pacchetto, `webview_flutter` fa
  superare all'utente la verifica di Cloudflare.
