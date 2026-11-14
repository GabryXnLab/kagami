// L'icona di un sito: asset per gli inclusi, rete per quelli degli utenti, globo di riserva.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kagami/src/ui/widgets/kit.dart';
import 'package:kagami_archive/declarative.dart';
import 'package:kagami_archive/providers.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

DeclarativeProvider user(String id, {String? icon}) => DeclarativeProvider.fromJson({
      'format': 1,
      'id': id,
      'name': id,
      'version': 1,
      'home': 'https://examplescans.com',
      'hosts': ['examplescans.com'],
      'icon': ?icon,
      'series': {
        'path': r'^/manga/([a-z0-9-]+)/?$',
        'title': 'h1',
        'chapters': {'items': 'li', 'url': {'css': 'a', 'attr': 'href'}, 'title': 'a'},
      },
      'chapter': {
        'path': r'^/manga/([a-z0-9-]+)/chapter-[a-z0-9-]+/?$',
        'pages': {'items': 'img', 'url': {'attr': 'src'}},
      },
    });

Future<void> show(WidgetTester tester, Provider site) =>
    tester.pumpWidget(MaterialApp(home: Scaffold(body: SiteIcon(site, size: 32))));

void main() {
  testWidgets('un sito incluso usa l\'asset', (tester) async {
    await show(tester, builtInProviders.first);
    expect(tester.widget<Image>(find.byType(Image)).image, isA<AssetImage>());
  });

  testWidgets('un sito degli utenti con icona la prende dalla rete', (tester) async {
    await show(tester, user('examplescans', icon: 'https://examplescans.com/icon.png'));
    expect(tester.widget<Image>(find.byType(Image)).image, isA<NetworkImage>());
  });

  testWidgets('senza icona è il globo, ma se sostituisce un incluso tiene la sua', (tester) async {
    await show(tester, user('examplescans'));
    expect(find.byIcon(LucideIcons.globe), findsOneWidget);
    expect(find.byType(Image), findsNothing);

    await show(tester, user(builtInProviders.first.id));
    expect(tester.widget<Image>(find.byType(Image)).image, isA<AssetImage>());
  });
}
