// Miniature e tessere con libvips. Si salta dove `vips` non c'è: l'immagine
// Docker del server lo ha, e lì questo test gira.
import 'dart:io';

import 'package:kagami_archive/images.dart';
import 'package:kagami_server/kagami_server.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

Future<void> main() async {
  final vips = await VipsImageTools.available();

  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('kagami-vips-'));
  tearDown(() => dir.delete(recursive: true));

  Future<File> image(int width, int height) async {
    final file = File(p.join(dir.path, 'in-${width}x$height.webp'));
    final made = await Process.run('vips', ['black', '${file.path}[Q=80]', '$width', '$height']);
    expect(made.exitCode, 0, reason: '${made.stderr}');
    return file;
  }

  Future<(int, int)> size(List<int> bytes) async {
    final file = File(p.join(dir.path, 'out-${DateTime.now().microsecondsSinceEpoch}.webp'));
    await file.writeAsBytes(bytes);
    Future<int> field(String name) async =>
        int.parse('${(await Process.run('vipsheader', ['-f', name, file.path])).stdout}'.trim());
    return (await field('width'), await field('height'));
  }

  test('la miniatura sta dentro 360×540 e una copertina piccola non si ingrandisce', () async {
    final tools = VipsImageTools(Directory(p.join(dir.path, 'scratch')));
    expect(await size((await tools.thumbnail(await image(1000, 1500)))!), (360, 540));
    expect(await size((await tools.thumbnail(await image(200, 300)))!), (200, 300));
  }, skip: vips ? false : 'manca vips');

  test('le tessere hanno la larghezza della tavola e le altezze chieste', () async {
    final tools = VipsImageTools(Directory(p.join(dir.path, 'scratch')));
    final heights = tileHeights(3000);
    final parts = (await tools.tiles(await image(720, 3000), heights))!;
    expect(parts, hasLength(heights.length));
    for (final (index, part) in parts.indexed) {
      expect(await size(part), (720, heights[index]));
    }
  }, skip: vips ? false : 'manca vips');

  test('senza vips si dice che non c\'è, invece di rompersi', () async {
    expect(await VipsImageTools.available(vips: 'vips-che-non-esiste'), isFalse);
  });
}
