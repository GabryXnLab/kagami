// I pezzi finti che l'API vuole: il giro e il Drive del server.
import 'package:kagami_archive/drive.dart';
import 'package:kagami_archive/jobs.dart';
import 'package:kagami_server/kagami_server.dart';

class FakeJobs implements JobControl {
  int woken = 0;
  final List<String> cancelled = [];
  int checks = 0;
  ArchiveFiles? files;

  @override
  void wake() => woken++;

  @override
  Future<void> cancel(String id) async {
    cancelled.add(id);
    await files?.remove(id);
  }

  @override
  Future<void> checkNow() async => checks++;
}

class FakeDrive implements DriveSetup {
  bool ready = true;
  @override
  String? folderId = 'cartella-libreria';
  @override
  String? folderName = 'MangaArchive';

  @override
  Future<bool> get authorized async => ready;

  @override
  Future<DriveItem> choose(String id) async {
    if (id == 'non-esiste') throw const DriveException('File non trovato su Drive', status: 404);
    folderId = id;
    folderName = 'Scelta';
    return DriveItem(id: id, name: 'Scelta', folder: true);
  }
}
