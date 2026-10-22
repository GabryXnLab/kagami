# CLAUDE.md — Testi e lingue (`lib/l10n/`)

Vincoli dei testi dell'interfaccia; il resto del progetto è nel `CLAUDE.md` di root.

- **I testi sono in `app_it.arb`, le altre lingue lo seguono.** Un testo
  nuovo si scrive in italiano in `app_it.arb`, con una `description` che dica
  dove compare (chi traduce non vede lo schermo), e si traduce negli altri
  `app_<lingua>.arb`; finché manca, quella lingua mostra l'italiano. Frasi
  intere con segnaposto e plurali ICU, mai pezzi concatenati: l'ordine delle
  parole cambia fra le lingue. Date e ore da `DateFormat` col locale, mai
  nomi di mesi scritti a mano. Dove non c'è un `BuildContext` (eccezioni,
  etichette degli enum, notifiche) si usa `currentL10n()`, che legge la lingua
  scelta (`app.locale` fra le impostazioni del database, vuota per quella del
  sistema). Il Kotlin ha i suoi testi in `res/values*/strings.xml` e, da
  Android 13, la lingua gliela passa Dart (`kagami/locale`) perché valga ad
  app chiusa. I messaggi del motore (`packages/kagami_archive/`) restano in
  italiano: li produce anche il server, che una lingua non ce l'ha.
