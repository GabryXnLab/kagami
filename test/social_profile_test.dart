/// Cosa esce dal telefono quando il social è acceso: le regole di
/// `docs/social.md` che non devono poter essere dimenticate da chi chiama.
library;

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/data/db/database.dart';
import 'package:kagami/src/data/social/content.dart';
import 'package:kagami/src/data/social/profile.dart';
import 'package:kagami/src/data/statistics.dart';
import 'package:kagami/src/format/kind.dart';
import 'package:kagami/src/format/reading.dart';

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  ReadingStatistics statistics({Set<String> excluding = const {}, Map<DateTime, int>? perDay}) => ReadingStatistics(
        chaptersRead: 120,
        pagesRead: 2400,
        timeRead: const Duration(minutes: 800),
        perDay: perDay ?? {today: 3, today.subtract(const Duration(days: 1)): 2},
        perMonth: const {},
        topSeries: const [],
        firstRead: DateTime(2024, 3, 14),
        excluding: excluding,
      );

  const visible = [
    ProfileSeries(
      key: 'a',
      title: 'Alfa',
      genres: ['Azione', 'Commedia'],
      kind: SeriesKind.manga,
      read: 60,
      status: ShelfStatus.completed,
      rating: 8,
    ),
    ProfileSeries(key: 'b', title: 'Beta', genres: ['Azione'], kind: SeriesKind.manhwa, read: 20, rating: 7),
    ProfileSeries(key: 'mai', title: 'Mai aperta', genres: ['Sport']),
  ];
  const secret = ProfileSeries(
    key: 'segreta',
    title: 'Titolo Segreto',
    genres: ['Genere Segreto'],
    kind: SeriesKind.manhua,
    read: 500,
    status: ShelfStatus.completed,
    rating: 10,
  );
  const open = SocialSettings(
    enabled: true,
    name: 'Lettrice',
    showPhoto: true,
    showSeries: true,
    showActivity: true,
  );

  PublicProfile build({
    SocialSettings settings = open,
    Iterable<ProfileSeries> series = visible,
    Set<String> hidden = const {},
    ReadingStatistics? from,
    String? photo = 'https://lh3.googleusercontent.com/a/foto=s96-c',
  }) =>
      buildPublicProfile(
        uid: 'u-1',
        settings: settings,
        statistics: from ?? statistics(excluding: hidden),
        series: series,
        hidden: hidden,
        now: now,
        photo: photo,
      );

  group('le serie nascoste non escono mai', () {
    test('né titoli, né generi, né numeri', () {
      final profile = build(series: [...visible, secret], hidden: {'segreta'});
      final row = jsonEncode(profile.toRow());
      expect(row, isNot(contains('Segret')));
      expect(profile.series, [('Alfa', 60), ('Beta', 20)]);
      expect(profile.seriesCount, 2);
      expect(profile.completed, 1);
      expect(profile.meanRating, 7.5);
      expect(profile.kinds.containsKey(SeriesKind.manhua), isFalse);
      // Uguale al profilo di chi quella serie non l'ha proprio.
      expect(row, jsonEncode(build().toRow()));
    });

    test('statistiche che le contano ancora non si pubblicano', () {
      expect(
        () => build(series: [...visible, secret], hidden: {'segreta'}, from: statistics()),
        throwsStateError,
      );
    });

    test('i totali le lasciano fuori solo se chiesto: in privato contano', () async {
      final db = KagamiDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      Future<void> read(String series, String chapter, {bool estimated = false}) =>
          db.into(db.chapterReads).insert(ChapterReadsCompanion.insert(
                profileId: defaultProfileId,
                seriesKey: series,
                chapterId: chapter,
                readAt: now,
                estimated: Value(estimated),
              ));
      Future<void> session(String series, int pages) =>
          db.into(db.readingSessions).insert(ReadingSessionsCompanion.insert(
                profileId: defaultProfileId,
                seriesKey: series,
                chapterId: '1',
                startedAt: now.subtract(const Duration(minutes: 10)),
                endedAt: now,
                pagesRead: Value(pages),
              ));
      await read('a', '1');
      await read('a', '2', estimated: true);
      await read('segreta', '1');
      await read('segreta', '2');
      await read('segreta', '3', estimated: true);
      await session('a', 20);
      await session('segreta', 70);

      final repository = StatisticsRepository(db);
      final private = await repository.load();
      expect((private.chaptersRead, private.pagesRead, private.timeRead.inMinutes), (5, 90, 20));
      expect(private.perDay.values.single, 3);
      expect(private.excluding, isEmpty);

      final public = await repository.load(excluding: {'segreta'});
      expect((public.chaptersRead, public.pagesRead, public.timeRead.inMinutes), (2, 20, 10));
      expect(public.perDay.values.single, 1);
      expect(public.perMonth.values.single, 1);
      expect(public.topSeries, [('a', 1)]);
      expect(public.excluding, {'segreta'});
    });

    test('un post non nomina una serie nascosta', () {
      const draft = PostDraft(body: 'Che finale', seriesKey: 'segreta', seriesTitle: 'Titolo Segreto');
      expect(draft.refusal(hidden: {'segreta'}), PostRefusal.hiddenSeries);
      expect(draft.refusal(hidden: const {}), isNull);
    });
  });

  group('esce solo ciò che l\'utente ha acceso', () {
    test('di partenza: spento, chiuso', () {
      final settings = SocialSettings.fromSettings(const {});
      expect(settings.enabled, isFalse);
      expect((settings.showPhoto, settings.showSeries, settings.showActivity), (false, false, false));
      expect(settings.messages, MessagePolicy.following);
      // Un valore che non si capisce non apre niente.
      final odd = SocialSettings.fromSettings(const {
        SocialSettings.enabledKey: 'sì',
        SocialSettings.showSeriesKey: '1',
        SocialSettings.mutedKey: 'non json',
      });
      expect((odd.enabled, odd.showSeries), (false, false));
      expect(odd.muted, isEmpty);
    });

    test('le impostazioni fanno andata e ritorno', () {
      const settings = SocialSettings(
        enabled: true,
        name: 'Lettrice',
        bio: 'Solo seinen',
        audience: SocialAudience.mutual,
        messages: MessagePolicy.nobody,
        showSeries: true,
        muted: {'u-9', 'u-3'},
      );
      final back = SocialSettings.fromSettings(settings.toSettings());
      expect((back.enabled, back.name, back.bio), (true, 'Lettrice', 'Solo seinen'));
      expect((back.audience, back.messages), (SocialAudience.mutual, MessagePolicy.nobody));
      expect((back.showPhoto, back.showSeries, back.showActivity), (false, true, false));
      expect(back.muted, {'u-3', 'u-9'});
      expect(settings.toSettings().keys, unorderedEquals(SocialSettings.keys));
    });

    test('titoli, foto e attività: ognuno col suo interruttore', () {
      final closed = build(settings: const SocialSettings(enabled: true, name: 'Lettrice'));
      expect((closed.series, closed.photo, closed.activity), (null, null, null));
      // I numeri e i generi ci sono lo stesso: sono il profilo.
      expect((closed.chapters, closed.genres.first), (120, ('Azione', 57)));

      final titles = build(settings: const SocialSettings(enabled: true, name: 'Lettrice', showSeries: true));
      expect(titles.series, [('Alfa', 60), ('Beta', 20)]);
      expect((titles.photo, titles.activity), (null, null));

      final all = build();
      expect(all.photo, 'https://lh3.googleusercontent.com/a/foto=s96-c');
      expect(all.activity, hasLength(SocialLimits.activityDays));
      expect(all.activity!.sublist(SocialLimits.activityDays - 2), [2, 3]);
    });

    test('una foto non di Google non esce: il backend rifiuterebbe il profilo (0009)', () {
      expect(build(photo: 'https://example.com/foto.png').photo, isNull);
      expect(build(photo: 'http://lh3.googleusercontent.com/a/x').photo, isNull);
    });

    test('nessun indirizzo, da nessuna parte', () {
      final row = jsonEncode(build().toRow());
      expect(row, isNot(contains('@')));
      expect(build().toRow().keys, isNot(contains('email')));
    });
  });

  group('forma e limiti', () {
    test('testi tagliati, liste corte', () {
      final many = [
        for (var i = 0; i < 30; i++)
          ProfileSeries(key: 's$i', title: 'T$i ${'x' * 200}', genres: ['Genere $i', 'g' * 80], read: 30 - i),
      ];
      final profile = build(
        settings: SocialSettings(enabled: true, name: 'n' * 60, bio: 'b' * 400, showSeries: true),
        series: many,
        photo: 'https://lh3.googleusercontent.com/${'p' * 600}',
      );
      expect(profile.name.length, SocialLimits.nameMax);
      expect(profile.bio.length, SocialLimits.bio);
      expect(profile.genres, hasLength(SocialLimits.genres));
      expect(profile.genres.every((genre) => genre.$1.length <= SocialLimits.genreName), isTrue);
      expect(profile.series, hasLength(SocialLimits.series));
      expect(profile.series!.every((entry) => entry.$1.length <= SocialLimits.seriesTitle), isTrue);
      expect(profile.series!.first.$2, 30);
    });

    test('il nome: da due a ventiquattro caratteri', () {
      expect(const SocialSettings(name: ' a ').hasValidName, isFalse);
      expect(const SocialSettings(name: 'Yu').hasValidName, isTrue);
      expect(SocialSettings(name: 'n' * 25).hasValidName, isFalse);
    });

    test('settimana e mese a cui valgono i conteggi', () {
      expect(weekId(DateTime(2026, 11, 14)), '2026-W46');
      expect(weekId(DateTime(2027, 1, 1)), '2026-W53');
      expect(weekId(DateTime(2024, 12, 30)), '2025-W01');
      expect(monthId(DateTime(2026, 3, 9)), '2026-03');

      final monday = today.subtract(Duration(days: today.weekday - 1));
      final profile = build(
        from: statistics(perDay: {
          today: 4,
          monday.subtract(const Duration(days: 1)): 9,
          DateTime(today.year, today.month - 1, 1): 50,
        }),
      );
      expect((profile.weekId, profile.monthId), (weekId(today), monthId(today)));
      expect(profile.weekChapters, 4);
      // La domenica scorsa è di un'altra settimana, ma dello stesso mese se
      // non era l'ultimo giorno del mese prima.
      final sunday = monday.subtract(const Duration(days: 1));
      expect(profile.monthChapters, sunday.month == today.month ? 13 : 4);
      expect(profile.since, DateTime(2024, 3));
    });

    test('la riga fa andata e ritorno', () {
      final profile = build();
      final back = PublicProfile.fromRow(jsonDecode(jsonEncode(profile.toRow())) as Map<String, Object?>);
      expect(back.fingerprint, profile.fingerprint);
      expect(back.kinds, {SeriesKind.manga: 75, SeriesKind.manhwa: 25});
    });

    test('si ripubblica solo se qualcosa è cambiato', () {
      expect(build().fingerprint, build().fingerprint);
      expect(
        build(settings: const SocialSettings(enabled: true, name: 'Lettrice')).fingerprint,
        isNot(build().fingerprint),
      );
    });
  });

  group('fra due lettori', () {
    PublicProfile reader(List<(String, int)> genres, [List<(String, int)>? series]) =>
        PublicProfile(id: 'x', name: 'x', genres: genres, series: series);

    test('affinità: i generi in comune, pesati', () {
      final a = reader([('Azione', 60), ('Commedia', 40)]);
      expect(affinity(a, a), 100);
      expect(affinity(a, reader([('azione', 30), ('Horror', 70)])), 30);
      expect(affinity(a, reader([('Sport', 100)])), 0);
      expect(affinity(a, reader(const [])), 0);
    });

    test('in comune: solo se tutti e due mostrano i titoli', () {
      final a = reader(const [], [('One-Punch Man', 100), ('Alfa', 3)]);
      final b = reader(const [], [('one punch man', 5), ('Beta', 9)]);
      expect(inCommon(a, b), ['One-Punch Man']);
      expect(inCommon(a, reader(const [])), isEmpty);
    });
  });

  test('uno spoiler resta coperto finché non ci si è arrivati', () {
    Post post({bool spoiler = true, num? chapter}) => Post(
          id: 'p',
          author: const SocialCard(id: 'u', name: 'n'),
          body: 'muore',
          at: now,
          spoiler: spoiler,
          chapter: chapter,
        );
    expect(post(spoiler: false, chapter: 50).concealedFor(null), isFalse);
    expect(post(chapter: 50).concealedFor(49), isTrue);
    expect(post(chapter: 50).concealedFor(50), isFalse);
    // Chi non ha la serie, o un avviso senza capitolo: coperto.
    expect(post(chapter: 50).concealedFor(null), isTrue);
    expect(post().concealedFor(900), isTrue);
  });
}
