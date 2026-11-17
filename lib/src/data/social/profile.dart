/// Il profilo pubblico di un lettore: cosa esce dal telefono quando il social
/// è acceso, e nient'altro. Contratto in `docs/social.md`.
///
/// Tutto qui è puro: [buildPublicProfile] prende ciò che il telefono sa e le
/// scelte dell'utente, e restituisce la riga da pubblicare. Le regole che non
/// devono poter essere dimenticate — nessuna serie nascosta, titoli solo con
/// il loro interruttore, mai un indirizzo — stanno in quella funzione, non in
/// chi la chiama.
library;

import 'dart:convert';

import '../../format/kind.dart';
import '../../format/reading.dart';
import '../statistics.dart';

/// Chi vede il profilo, e con lui i post di chi lo possiede.
enum SocialAudience {
  /// Chiunque abbia il social acceso.
  everyone,

  /// Solo le persone che seguo.
  following,

  /// Solo le persone che seguo e che mi seguono.
  mutual;

  static SocialAudience parse(Object? value) =>
      values.asNameMap()[value] ?? SocialAudience.everyone;
}

/// Chi può scrivermi un messaggio privato.
enum MessagePolicy {
  everyone,
  following,
  mutual,
  nobody;

  static MessagePolicy parse(Object? value) =>
      values.asNameMap()[value] ?? MessagePolicy.following;
}

/// Se [url] è una foto di profilo che si può pubblicare e mostrare: la regola
/// di `profiles_photo_check` (migrazione 0009), cioè `https` di un host delle
/// foto di Google e meno di 512 caratteri. Un indirizzo qualsiasi farebbe
/// vedere a chi lo pubblica l'IP di chi guarda il profilo; fuori regola il
/// backend rifiuterebbe l'intero profilo (23514), e chi lo mostra ha
/// l'iniziale.
bool isProfilePhoto(String? url) =>
    url != null && url.length <= SocialLimits.photo && _profilePhoto.hasMatch(url);

final RegExp _profilePhoto = RegExp(r'^https://lh[3-6]\.googleusercontent\.com/\S+$');

/// I limiti di forma, gli stessi dei `CHECK` del backend: una riga che li
/// supera non verrebbe scritta, quindi si taglia qui.
abstract final class SocialLimits {
  static const int nameMin = 2;
  static const int nameMax = 24;
  static const int bio = 160;
  static const int photo = 511;
  static const int genres = 8;
  static const int genreName = 39;
  static const int series = 10;
  static const int seriesTitle = 119;
  static const int activityDays = 14;
  static const int post = 2000;
  static const int comment = 1000;
  static const int message = 2000;
  static const int reportNote = 500;
  static const int following = 500;
}

/// Le scelte dell'utente sul social. Stanno fra le impostazioni
/// (`social.*`), quindi in backup e account: seguono il lettore.
class SocialSettings {
  const SocialSettings({
    this.enabled = false,
    this.name = '',
    this.bio = '',
    this.audience = SocialAudience.everyone,
    this.messages = MessagePolicy.following,
    this.showPhoto = false,
    this.showSeries = false,
    this.showActivity = false,
    this.muted = const {},
  });

  static const String enabledKey = 'social.enabled';
  static const String nameKey = 'social.name';
  static const String bioKey = 'social.bio';
  static const String audienceKey = 'social.audience';
  static const String messagesKey = 'social.messages';
  static const String showPhotoKey = 'social.showPhoto';
  static const String showSeriesKey = 'social.showSeries';
  static const String showActivityKey = 'social.showActivity';
  static const String mutedKey = 'social.muted';

  static const List<String> keys = [
    enabledKey,
    nameKey,
    bioKey,
    audienceKey,
    messagesKey,
    showPhotoKey,
    showSeriesKey,
    showActivityKey,
    mutedKey,
  ];

  /// Dalle impostazioni lette. Una chiave che manca o non si capisce vale il
  /// suo valore iniziale, che è sempre il più chiuso: spento, niente foto,
  /// niente titoli, niente attività.
  factory SocialSettings.fromSettings(Map<String, String?> settings) {
    Set<String> list(String? source) {
      if (source == null) return const {};
      try {
        final json = jsonDecode(source);
        return json is List ? json.whereType<String>().toSet() : const {};
      } on FormatException {
        return const {};
      }
    }

    return SocialSettings(
      enabled: settings[enabledKey] == 'true',
      name: settings[nameKey] ?? '',
      bio: settings[bioKey] ?? '',
      audience: SocialAudience.parse(settings[audienceKey]),
      messages: MessagePolicy.parse(settings[messagesKey]),
      showPhoto: settings[showPhotoKey] == 'true',
      showSeries: settings[showSeriesKey] == 'true',
      showActivity: settings[showActivityKey] == 'true',
      muted: list(settings[mutedKey]),
    );
  }

  /// Acceso: senza, niente esce e niente degli altri si chiede.
  final bool enabled;

  /// Il soprannome scelto. Mai ricavato dall'account.
  final String name;
  final String bio;
  final SocialAudience audience;
  final MessagePolicy messages;
  final bool showPhoto;

  /// Titoli: le serie più lette e ciò che si ha «in comune».
  final bool showSeries;

  /// Quanto si è letto giorno per giorno nelle ultime due settimane.
  final bool showActivity;

  /// Le persone silenziate: i loro post e commenti non si mostrano. È una
  /// lista privata, e l'altro non lo sa.
  final Set<String> muted;

  /// Se [name] può essere pubblicato.
  bool get hasValidName {
    final length = name.trim().runes.length;
    return length >= SocialLimits.nameMin && length <= SocialLimits.nameMax;
  }

  SocialSettings copyWith({
    bool? enabled,
    String? name,
    String? bio,
    SocialAudience? audience,
    MessagePolicy? messages,
    bool? showPhoto,
    bool? showSeries,
    bool? showActivity,
    Set<String>? muted,
  }) =>
      SocialSettings(
        enabled: enabled ?? this.enabled,
        name: name ?? this.name,
        bio: bio ?? this.bio,
        audience: audience ?? this.audience,
        messages: messages ?? this.messages,
        showPhoto: showPhoto ?? this.showPhoto,
        showSeries: showSeries ?? this.showSeries,
        showActivity: showActivity ?? this.showActivity,
        muted: muted ?? this.muted,
      );

  Map<String, String> toSettings() => {
        enabledKey: '$enabled',
        nameKey: name,
        bioKey: bio,
        audienceKey: audience.name,
        messagesKey: messages.name,
        showPhotoKey: '$showPhoto',
        showSeriesKey: '$showSeries',
        showActivityKey: '$showActivity',
        mutedKey: jsonEncode(muted.toList()..sort()),
      };
}

/// Una serie come serve al profilo: ciò che di lei può uscire.
class ProfileSeries {
  const ProfileSeries({
    required this.key,
    required this.title,
    this.genres = const [],
    this.kind = SeriesKind.other,
    this.read = 0,
    this.status = ShelfStatus.none,
    this.rating,
  });

  final String key;
  final String title;
  final List<String> genres;
  final SeriesKind kind;

  /// Capitoli letti.
  final int read;
  final ShelfStatus status;
  final int? rating;
}

/// La riga `profiles` di un lettore.
class PublicProfile {
  const PublicProfile({
    required this.id,
    required this.name,
    this.bio = '',
    this.photo,
    this.audience = SocialAudience.everyone,
    this.messages = MessagePolicy.following,
    this.since,
    this.chapters = 0,
    this.pages = 0,
    this.minutes = 0,
    this.seriesCount = 0,
    this.completed = 0,
    this.meanRating,
    this.streak = 0,
    this.longestStreak = 0,
    this.weekId = '',
    this.weekChapters = 0,
    this.monthId = '',
    this.monthChapters = 0,
    this.genres = const [],
    this.kinds = const {},
    this.series,
    this.activity,
    this.updatedAt,
  });

  factory PublicProfile.fromRow(Map<String, Object?> row) {
    int number(Object? value) => value is num ? value.toInt() : 0;
    final totals = row['totals'] is Map ? row['totals']! as Map : const {};
    final streak = row['streak'] is Map ? row['streak']! as Map : const {};
    final kinds = row['kinds'] is Map ? row['kinds']! as Map : const {};
    List<(String, int)>? pairs(Object? value, String label, String count) => value is List
        ? [
            for (final item in value.whereType<Map>())
              if (item[label] is String) (item[label] as String, number(item[count])),
          ]
        : null;
    final activity = row['activity'];
    return PublicProfile(
      id: row['id'] as String,
      name: row['name'] as String? ?? '',
      bio: row['bio'] as String? ?? '',
      photo: row['photo'] as String?,
      audience: SocialAudience.parse(row['audience']),
      messages: MessagePolicy.parse(row['messages']),
      since: DateTime.tryParse('${row['since']}'),
      chapters: number(totals['chapters']),
      pages: number(totals['pages']),
      minutes: number(totals['minutes']),
      seriesCount: number(totals['series']),
      completed: number(totals['completed']),
      meanRating: (totals['meanRating'] as num?)?.toDouble(),
      streak: number(streak['current']),
      longestStreak: number(streak['longest']),
      weekId: row['week_id'] as String? ?? '',
      weekChapters: number(row['week_chapters']),
      monthId: row['month_id'] as String? ?? '',
      monthChapters: number(row['month_chapters']),
      genres: pairs(row['genres'], 'name', 'share') ?? const [],
      kinds: {
        for (final kind in SeriesKind.values)
          if (kinds[kind.name] is num) kind: number(kinds[kind.name]),
      },
      series: pairs(row['series'], 'title', 'chapters'),
      activity: activity is List ? [for (final day in activity) number(day)] : null,
      updatedAt: DateTime.tryParse('${row['updated_at']}'),
    );
  }

  /// L'utente del backend (`auth.uid()`): l'unico nome con cui una persona
  /// si indica. Mai un indirizzo.
  final String id;
  final String name;
  final String bio;

  /// Solo con «mostra la foto».
  final String? photo;
  final SocialAudience audience;
  final MessagePolicy messages;

  /// Il mese della prima lettura.
  final DateTime? since;

  final int chapters;
  final int pages;
  final int minutes;
  final int seriesCount;
  final int completed;
  final double? meanRating;

  final int streak;
  final int longestStreak;

  /// La settimana (`AAAA-Wnn`, ISO) e il mese (`AAAA-MM`) a cui si
  /// riferiscono i due conteggi: una classifica chiede le righe con l'id di
  /// adesso, così chi non pubblica da un mese non resta in testa.
  final String weekId;
  final int weekChapters;
  final String monthId;
  final int monthChapters;

  /// Al più [SocialLimits.genres], col peso in centesimi sul letto.
  final List<(String name, int share)> genres;
  final Map<SeriesKind, int> kinds;

  /// Le serie più lette. `null` senza «mostra i titoli»: non una lista vuota,
  /// che vorrebbe dire «non ha letto niente».
  final List<(String title, int chapters)>? series;

  /// Capitoli letti in ognuno degli ultimi [SocialLimits.activityDays]
  /// giorni, il più vecchio per primo. `null` senza «mostra l'attività».
  final List<int>? activity;

  /// Lo mette il backend.
  final DateTime? updatedAt;

  /// La riga da scrivere. `updated_at` non c'è: è del backend.
  Map<String, Object?> toRow() => {
        'id': id,
        'name': name,
        'bio': bio,
        'photo': photo,
        'audience': audience.name,
        'messages': messages.name,
        'since': since == null ? null : _day(since!),
        'totals': {
          'chapters': chapters,
          'pages': pages,
          'minutes': minutes,
          'series': seriesCount,
          'completed': completed,
          'meanRating': ?meanRating,
        },
        'streak': {'current': streak, 'longest': longestStreak},
        'week_id': weekId,
        'week_chapters': weekChapters,
        'month_id': monthId,
        'month_chapters': monthChapters,
        'genres': [
          for (final (name, share) in genres) {'name': name, 'share': share},
        ],
        'kinds': {for (final entry in kinds.entries) entry.key.name: entry.value},
        'series': series == null
            ? null
            : [
                for (final (title, chapters) in series!) {'title': title, 'chapters': chapters},
              ],
        'activity': activity,
      };

  /// Cambia quando cambia ciò che si pubblicherebbe: si pubblica solo allora.
  String get fingerprint => jsonEncode(toRow());
}

String _day(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// `AAAA-MM` di [day].
String monthId(DateTime day) => _day(day).substring(0, 7);

/// `AAAA-Wnn` di [day], settimana ISO: comincia di lunedì, e la prima
/// dell'anno è quella col primo giovedì.
String weekId(DateTime day) {
  final date = DateTime.utc(day.year, day.month, day.day);
  final thursday = date.add(Duration(days: 4 - date.weekday));
  final first = DateTime.utc(thursday.year);
  final week = 1 + thursday.difference(first).inDays ~/ 7;
  return '${thursday.year.toString().padLeft(4, '0')}-W${week.toString().padLeft(2, '0')}';
}

String _cut(String text, int max) {
  final runes = text.trim().runes;
  return runes.length <= max ? text.trim() : String.fromCharCodes(runes.take(max)).trimRight();
}

/// Il profilo da pubblicare.
///
/// [statistics] devono essere state chieste senza le serie [hidden]
/// (`StatisticsRepository.load(excluding: …)`), perché i totali non si
/// possono ripulire dopo: se non lo sono si lancia, che è meglio non
/// pubblicare che pubblicare una serie nascosta. [series] sono tutte quelle
/// della libreria: le nascoste si scartano qui. [photo] è quella
/// dell'account, ed esce solo con il suo interruttore.
PublicProfile buildPublicProfile({
  required String uid,
  required SocialSettings settings,
  required ReadingStatistics statistics,
  required Iterable<ProfileSeries> series,
  required Set<String> hidden,
  required DateTime now,
  String? photo,
}) {
  if (!statistics.excluding.containsAll(hidden)) {
    throw StateError('Le statistiche da pubblicare contengono serie nascoste');
  }
  final shown = [
    for (final entry in series)
      if (!hidden.contains(entry.key) && entry.read > 0) entry,
  ]..sort((a, b) => b.read.compareTo(a.read));

  final read = shown.fold<int>(0, (sum, entry) => sum + entry.read);
  final weights = <String, int>{};
  final kinds = <SeriesKind, int>{};
  for (final entry in shown) {
    kinds[entry.kind] = (kinds[entry.kind] ?? 0) + entry.read;
    for (final genre in entry.genres) {
      final name = _cut(genre, SocialLimits.genreName);
      if (name.isNotEmpty) weights[name] = (weights[name] ?? 0) + entry.read;
    }
  }
  final weight = weights.values.fold<int>(0, (sum, value) => sum + value);
  final genres = weights.entries.toList()
    ..sort((a, b) => b.value != a.value ? b.value.compareTo(a.value) : a.key.compareTo(b.key));
  final ratings = [
    for (final entry in shown)
      if (entry.rating != null) entry.rating!,
  ];

  final today = DateTime(now.year, now.month, now.day);
  int chaptersSince(DateTime from) => statistics.perDay.entries
      .where((day) => !day.key.isBefore(from) && !day.key.isAfter(today))
      .fold<int>(0, (sum, day) => sum + day.value);
  final first = statistics.firstRead?.toLocal();
  final picture = settings.showPhoto && isProfilePhoto(photo) ? photo : null;

  return PublicProfile(
    id: uid,
    name: _cut(settings.name, SocialLimits.nameMax),
    bio: _cut(settings.bio, SocialLimits.bio),
    photo: picture,
    audience: settings.audience,
    messages: settings.messages,
    since: first == null ? null : DateTime(first.year, first.month),
    chapters: statistics.chaptersRead,
    pages: statistics.pagesRead,
    minutes: statistics.timeRead.inMinutes,
    seriesCount: shown.length,
    completed: shown.where((entry) => entry.status == ShelfStatus.completed).length,
    meanRating: ratings.isEmpty
        ? null
        : (ratings.fold<int>(0, (sum, value) => sum + value) * 10 / ratings.length).round() / 10,
    streak: statistics.streak,
    longestStreak: statistics.longestStreak,
    weekId: weekId(today),
    weekChapters: chaptersSince(today.subtract(Duration(days: today.weekday - 1))),
    monthId: monthId(today),
    monthChapters: chaptersSince(DateTime(today.year, today.month)),
    genres: [
      for (final entry in genres.take(SocialLimits.genres))
        (entry.key, (entry.value * 100 / weight).round()),
    ],
    kinds: {
      for (final entry in kinds.entries) entry.key: (entry.value * 100 / read).round(),
    },
    series: settings.showSeries
        ? [
            for (final entry in shown.take(SocialLimits.series))
              (_cut(entry.title, SocialLimits.seriesTitle), entry.read),
          ]
        : null,
    activity: settings.showActivity
        ? [
            for (var back = SocialLimits.activityDays - 1; back >= 0; back--)
              statistics.perDay[DateTime(today.year, today.month, today.day - back)] ?? 0,
          ]
        : null,
  );
}

/// Quanto si somigliano due lettori, da 0 a 100: la parte dei generi che
/// hanno in comune, pesata su quanto ciascuno li legge. Si calcola sul
/// telefono, da due profili che si vedono già.
int affinity(PublicProfile a, PublicProfile b) {
  final other = {for (final (name, share) in b.genres) name.toLowerCase(): share};
  var common = 0;
  for (final (name, share) in a.genres) {
    final theirs = other[name.toLowerCase()];
    if (theirs != null) common += share < theirs ? share : theirs;
  }
  int total(PublicProfile profile) => profile.genres.fold<int>(0, (sum, genre) => sum + genre.$2);
  final most = total(a) > total(b) ? total(a) : total(b);
  return most == 0 ? 0 : (common * 100 / most).round().clamp(0, 100);
}

/// Il nome con cui una serie si riconosce fra due lettori, che la tengono
/// ciascuno nella sua libreria con la sua chiave: il titolo, senza maiuscole
/// né segni. «One-Punch Man» e «one punch man» sono la stessa.
String seriesRef(String title) => title
    .toLowerCase()
    .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
    .trim();

/// I titoli che tutti e due mostrano, come li scrive [a]. Vuoto se uno dei
/// due non mostra i titoli: non si deduce niente da ciò che non si vede.
List<String> inCommon(PublicProfile a, PublicProfile b) {
  final theirs = {for (final (title, _) in b.series ?? const <(String, int)>[]) seriesRef(title)};
  return [
    for (final (title, _) in a.series ?? const <(String, int)>[])
      if (theirs.contains(seriesRef(title))) title,
  ];
}
