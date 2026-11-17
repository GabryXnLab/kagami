// Tetti, controllo delle espressioni regolari e degli host di un sito
// (`docs/siti.md`, «Tetti» e «Schemi di host»): ciò che tiene un file
// arrivato da chiunque dentro limiti finiti.
part of 'declarative.dart';

/// Tetti di un'operazione (serie, tavole di un capitolo, ricerca) di un sito
/// degli utenti: il file arriva da chiunque e gira sul telefono o nel server di
/// qualcuno, quindi un sito sbagliato o ostile non deve poterlo occupare senza
/// fine. Ordini di grandezza dai siti inclusi: una pagina HTML o JSON pesa
/// 100-500 KB (2 MB è il tetto di `ProviderHttp.get`, qui ripetuto perché non
/// dipenda dal client); il motore chiede 1 pagina e al più 1 API per
/// operazione, i siti inclusi 1-2 (Coffee Manga una per pagina di capitoli,
/// qualche decina al massimo); 30 s per richiesta e fino a 5 tentativi con
/// attesa che raddoppia in `SiteHttp`, quindi 120 s coprono un sito lento ma
/// non uno che trascina.
const int maxSiteRequests = 8;
const int maxSiteResponseBytes = 2000000;
const Duration maxSiteOperationTime = Duration(seconds: 120);

/// Tempo del browser per una pagina resa (`browser.pages`) e sua dimensione
/// massima, uguale per gli utenti e per il catalogo.
const Duration maxRenderTime = Duration(seconds: 60);
const int maxRenderedPageBytes = 2000000;

/// Tetti di un sito del catalogo: l'indice è firmato, quindi il file non
/// arriva da chiunque e può chiedere di più. 32 richieste coprono un sito che
/// pagina i capitoli (una richiesta per pagina, oggi al più qualche decina di
/// capitoli per pagina) con margine, restando un numero finito; 8 MB di
/// risposta reggono un'API che dà tutti i capitoli di una serie lunga in un
/// colpo. Il tempo resta lo stesso: un sito che trascina non diventa ammissibile
/// perché è firmato.
const int maxCatalogSiteRequests = 32;
const int maxCatalogSiteResponseBytes = 8000000;

/// Il conto di una sola operazione.
class _Budget {
  int requests = 0;

  /// Passi di ricetta eseguiti, contro `_maxRecipeRun`.
  int steps = 0;
}

const int _maxFileBytes = 64 * 1024;
const int _maxCatalogFileBytes = maxCatalogSiteBytes;
const int _maxPattern = 300;

/// Il testo a cui si applica una regex: il `RegExp` di Dart va in
/// backtracking, quindi una pagina enorme non deve poterlo tenere occupato.
const int _maxMatchText = 64 * 1024;

String _clip(String text) => text.length > _maxMatchText ? text.substring(0, _maxMatchText) : text;
final RegExp _idPattern = RegExp(r'^[a-z0-9]{1,32}$');
final RegExp _hostPattern = RegExp(r'^(\*\.)?([a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z][a-z0-9-]*[a-z0-9]$');
const List<String> _privateSuffixes = ['.local', '.lan', '.internal', '.home', '.arpa', '.localhost', '.test', '.invalid'];

/// Quanti `?` può avere un host dei `mediaHosts` (`docs/siti.md`, «Schemi di host»).
const int _maxHostMarks = 4;

final RegExp _hostMark = RegExp(r'^[a-z0-9]$');

bool _hostMatches(String pattern, String host) {
  if (pattern.startsWith('*.')) {
    final suffix = pattern.substring(1);
    return host.length > suffix.length && _sameHost(suffix, host.substring(host.length - suffix.length));
  }
  return _sameHost(pattern, host);
}

/// Uguali carattere per carattere, con `?` per una lettera o una cifra.
bool _sameHost(String pattern, String host) {
  if (!pattern.contains('?')) return pattern == host;
  if (pattern.length != host.length) return false;
  for (var i = 0; i < pattern.length; i++) {
    if (pattern[i] == '?' ? !_hostMark.hasMatch(host[i]) : pattern[i] != host[i]) return false;
  }
  return true;
}

RegExp _pattern(Object? raw, String where) {
  final source = _string(raw, where);
  if (source.length > _maxPattern) throw SiteDefinitionError('$where: espressione oltre $_maxPattern caratteri.');
  final risky = _riskyPattern(source);
  if (risky != null) throw SiteDefinitionError('$where: $risky');
  try {
    return RegExp(source);
  } on FormatException {
    throw SiteDefinitionError('$where: espressione regolare non valida.');
  }
}

/// Controllo euristico sul sorgente (non una prova): rifiuta le
/// backreference e un gruppo quantificato con `+`, `*` o `{n,}` che contiene
/// a sua volta una ripetizione illimitata, come `(a+)+` o `(.*a){2,}`.
String? _riskyPattern(String source) {
  // Per ogni gruppo aperto: contiene una ripetizione illimitata?
  final open = <bool>[false];
  var i = 0;
  // Fine dell'eventuale quantificatore in [at]: (illimitato, prossimo indice).
  (bool, int) quantifier(int at) {
    if (at >= source.length) return (false, at);
    final c = source[at];
    var unbounded = c == '+' || c == '*';
    var end = at + 1;
    if (c == '{') {
      final found = RegExp(r'^\{(\d+)(,(\d*))?\}').firstMatch(source.substring(at));
      if (found == null) return (false, at);
      unbounded = found[2] != null && found[3]!.isEmpty;
      end = at + found[0]!.length;
    } else if (c != '?' && !unbounded) {
      return (false, at);
    }
    if (end < source.length && (source[end] == '?' || source[end] == '+')) end++;
    return (unbounded, end);
  }

  while (i < source.length) {
    final c = source[i];
    if (c == r'\') {
      final next = i + 1 < source.length ? source[i + 1] : '';
      if (RegExp(r'[1-9]').hasMatch(next) || next == 'k') return 'riferimenti a gruppi (backreference) non ammessi.';
      final (unbounded, after) = quantifier(i + 2);
      if (unbounded) open[open.length - 1] = true;
      i = after;
    } else if (c == '[') {
      i++;
      if (i < source.length && source[i] == '^') i++;
      if (i < source.length && source[i] == ']') i++;
      while (i < source.length && source[i] != ']') {
        i += source[i] == r'\' ? 2 : 1;
      }
      final (unbounded, after) = quantifier(i + 1);
      if (unbounded) open[open.length - 1] = true;
      i = after;
    } else if (c == '(') {
      open.add(false);
      i++;
    } else if (c == ')') {
      if (open.length == 1) return null;
      final inner = open.removeLast();
      final (unbounded, next) = quantifier(i + 1);
      if (unbounded && inner) return 'ripetizioni annidate (come (a+)+) non ammesse.';
      if (unbounded || inner) open[open.length - 1] = true;
      i = next;
    } else if (c == '^' || c == r'$' || c == '|') {
      i++;
    } else {
      final (unbounded, next) = quantifier(i + 1);
      if (unbounded) open[open.length - 1] = true;
      i = next;
    }
  }
  return null;
}

List<String> _hosts(Object? raw, String where, {required bool wildcard}) {
  if (raw is! List || raw.any((host) => host is! String)) throw SiteDefinitionError('$where: una lista di host.');
  final hosts = [for (final host in raw.cast<String>()) host.trim().toLowerCase()];
  for (final host in hosts) {
    // Uno schema con `?` vale solo se ogni nome che descrive resta un dominio
    // pubblico: si prova con una lettera e con una cifra al posto di ogni `?`.
    final marks = '?'.allMatches(host).length;
    if (marks > 0 && (!wildcard || marks > _maxHostMarks || host.split('.').last.contains('?'))) {
      throw SiteDefinitionError('$where: «$host»: al più $_maxHostMarks «?», solo nei mediaHosts e mai nell\'ultima etichetta.');
    }
    for (final sample in {host.replaceAll('?', 'a'), host.replaceAll('?', '0')}) {
      if (!_hostPattern.hasMatch(sample) || (!wildcard && sample.startsWith('*.')) || !_publicHost(sample.replaceFirst('*.', ''))) {
        throw SiteDefinitionError('$where: «$host» non è un nome di dominio pubblico.');
      }
    }
    if (host.startsWith('*.') && host.split('.').length < 3) {
      throw SiteDefinitionError('$where: «$host» vale per un dominio intero.');
    }
  }
  return hosts;
}

/// Un nome di dominio, non un indirizzo IP né un nome della rete di casa.
bool _publicHost(String host) =>
    host.contains('.') &&
    !RegExp(r'^[\d.]+$').hasMatch(host) &&
    !host.contains(':') &&
    host != 'localhost' &&
    !_privateSuffixes.any(host.endsWith);
