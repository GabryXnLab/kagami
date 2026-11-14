/// Ciò che di un errore va a Sentry: senza indirizzi, email e id di Drive.
///
/// Sentry è del progetto di chi compila, non dell'utente: un'eccezione porta
/// facilmente l'indirizzo di un server o di un WebDAV, l'email dell'account o
/// l'id di una cartella condivisa (FASE-8, T19). Il tipo dell'errore e la
/// pila bastano a correggerlo.
library;

import 'package:sentry_flutter/sentry_flutter.dart';

final List<(RegExp, String Function(Match))> _rules = [
  // Un indirizzo con schema, credenziali comprese: via tutto fino allo spazio.
  (RegExp(r'\b[a-zA-Z][a-zA-Z0-9+.-]*://[^\s\x27"<>]+'), (_) => '<url>'),
  (RegExp(r'[\w.%+-]+@[\w-]+(?:\.[\w-]+)+'), (_) => '<email>'),
  (RegExp(r'\b\d{1,3}(?:\.\d{1,3}){3}\b'), (_) => '<ip>'),
  (RegExp(r'\[?\b[0-9a-fA-F]{1,4}(?::[0-9a-fA-F]{0,4}){3,7}\]?'), (_) => '<ip>'),
  // I nomi che `SocketException` e `HttpException` mettono nel messaggio.
  (RegExp(r"(host lookup: )'[^']*'"), (match) => "${match[1]}'<host>'"),
  (RegExp(r'(address = )[^\s,]+'), (match) => '${match[1]}<host>'),
  // Id di Drive (e token): lunghi, con almeno una cifra.
  (RegExp(r'(?<![\w-])(?=[\w-]*\d)[\w-]{25,}(?![\w-])'), (_) => '<id>'),
];

/// [text] senza indirizzi, email, IP e id lunghi.
String scrubText(String text) {
  var result = text;
  for (final (pattern, replace) in _rules) {
    result = result.replaceAllMapped(pattern, replace);
  }
  return result;
}

Object? _scrubValue(Object? value) => switch (value) {
      String() => scrubText(value),
      Map() => {for (final entry in value.entries) entry.key: _scrubValue(entry.value)},
      List() => [for (final item in value) _scrubValue(item)],
      _ => value,
    };

/// Il `beforeSend` di Sentry: toglie dati personali da messaggio, eccezioni,
/// breadcrumb e richiesta, e l'email dall'utente.
SentryEvent scrubEvent(SentryEvent event, [Hint? hint]) {
  final message = event.message;
  if (message != null) {
    message.formatted = scrubText(message.formatted);
    if (message.template case final template?) message.template = scrubText(template);
    if (message.params case final params?) message.params = [for (final p in params) _scrubValue(p)];
  }
  for (final exception in event.exceptions ?? const <SentryException>[]) {
    if (exception.value case final value?) exception.value = scrubText(value);
  }
  for (final crumb in event.breadcrumbs ?? const <Breadcrumb>[]) {
    if (crumb.message case final text?) crumb.message = scrubText(text);
    if (crumb.data case final data?) crumb.data = {for (final entry in data.entries) entry.key: _scrubValue(entry.value)};
  }
  if (event.request case final request?) {
    if (request.url case final url?) request.url = scrubText(url);
    request.queryString = null;
    request.headers = const {};
    request.cookies = null;
  }
  event.user?.email = null;
  event.user?.ipAddress = null;
  return event;
}
