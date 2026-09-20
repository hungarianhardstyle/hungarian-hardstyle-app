import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/models/label_library.dart';
import 'package:hungarian_hardstyle_app/services/label_download_manager.dart';

/// A megvásárolt zene **helyi** tárolásának bizonyítása.
///
/// A tulajdonos kérései: *„le is tudja tölteni újra, úgymond megmarad ott a
/// megvásárolt zenéje"*, *„tudjon törölni is ha akar, de a letöltési lehetősége
/// maradjon meg"*, és: *„ha másik accal lép be, ne látszódjon és letölteni se
/// tudja"*.
///
/// A „megmaradás" két dolgot jelent, és mindkettőt mérjük: a fájl **helyben
/// marad** (nem kell újra letölteni), és ha mégis törli, a **vásárlás** miatt
/// bármikor újra letölthető.
///
/// A teszt valódi (ideiglenes) mappába dolgozik, de a hálózatot **hamis
/// letöltő** helyettesíti — így a lejárt-link és a fél fájl esete is mérhető.
void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('huhs_label_test');
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  LabelQueueEntry entry({int releaseId = 100, String variant = 'radio_wav'}) =>
      LabelQueueEntry(
        releaseId: releaseId,
        variant: variant,
        title: 'Teszt kiadvány',
        artist: 'Teszt',
        coverUrl: '',
      );

  LabelDownloadManager manager(
    String uid, {
    void Function(String url, String path)? onDownload,
  }) => LabelDownloadManager(
    uid: uid,
    directoryProvider: () async => temp,
    downloader: (url, path, {onProgress}) async {
      onDownload?.call(url, path);
      await File(path).writeAsBytes([1, 2, 3]);
    },
  );

  test('a letöltés fájlt hoz létre, és a folyamat jelezve van', () async {
    final calls = <String>[];
    final progress = <double>[];
    late final LabelDownloadManager subject;
    subject = LabelDownloadManager(
      uid: 'uid-A',
      directoryProvider: () async => temp,
      downloader: (url, path, {onProgress}) async {
        calls.add(path);
        onProgress?.call(50, 100);
        progress.add(subject.progressOf(entry().key) ?? -1);
        await File(path).writeAsBytes(List<int>.filled(10, 1));
      },
    );

    final file = await subject.download(
      entry(),
      urlFor: () async => 'https://example.test/a.wav',
    );

    expect(await file.exists(), isTrue);
    expect(file.path, endsWith('huhs_100_radio_wav.wav'));
    expect(file.path, contains('uid-A'), reason: 'a fiók mappájába kerül');
    expect(await subject.isDownloaded(entry()), isTrue);
    expect(progress.single, closeTo(0.5, 0.0001));
    expect(subject.hasFailed(entry().key), isFalse);
    expect(calls, hasLength(1));
    // A `.part` fájl nem maradhat a mappában rendezetlenül.
    final leftovers = temp
        .listSync(recursive: true)
        .where((entity) => entity.path.endsWith('.part'));
    expect(leftovers, isEmpty);
  });

  test('bejelentkezés nélkül (vendég) nincs letöltés, és nem is jön létre mappa', () async {
    final subject = LabelDownloadManager(
      uid: '',
      directoryProvider: () async => temp,
      downloader: (url, path, {onProgress}) async {
        await File(path).writeAsBytes([1]);
      },
    );

    await expectLater(
      subject.download(entry(), urlFor: () async => 'https://x/a.wav'),
      throwsA(isA<StateError>()),
    );
    await expectLater(subject.isDownloaded(entry()), throwsA(isA<StateError>()));
    expect(await temp.list().toList(), isEmpty);
  });

  test('a lejárt link nem viszi el a letöltést: új linkkel újrapróbál', () async {
    var urls = 0;
    var attempts = 0;
    final manager = LabelDownloadManager(
      uid: 'uid-A',
      directoryProvider: () async => temp,
      downloader: (url, path, {onProgress}) async {
        attempts++;
        if (attempts == 1) {
          throw const SocketException('lejárt link');
        }
        await File(path).writeAsBytes([1]);
      },
    );

    final file = await manager.download(
      entry(),
      urlFor: () async {
        urls++;
        return 'https://example.test/$urls.wav';
      },
    );

    expect(await file.exists(), isTrue);
    expect(urls, 2, reason: 'minden próbálkozásnál FRISS linket kérünk');
    expect(manager.hasFailed(entry().key), isFalse);
  });

  test('ha kétszer sem sikerül, hiba lesz és nem marad fél fájl', () async {
    final manager = LabelDownloadManager(
      uid: 'uid-A',
      directoryProvider: () async => temp,
      downloader: (url, path, {onProgress}) async {
        // Fél fájlt hagyunk magunk után, hogy lássuk: nem marad meg.
        await File(path).writeAsBytes([1, 2, 3]);
        throw const SocketException('nincs hálózat');
      },
    );

    await expectLater(
      manager.download(entry(), urlFor: () async => 'https://x/y.wav'),
      throwsA(isA<SocketException>()),
    );

    expect(manager.hasFailed(entry().key), isTrue);
    expect(manager.progressOf(entry().key), isNull);
    expect(await manager.isDownloaded(entry()), isFalse);
    expect(
      temp.listSync().where((entity) => entity.path.contains('.part')),
      isEmpty,
      reason: 'a megszakadt letöltés nem hagy „kész" látszatú fájlt',
    );
  });

  test('a törlés eltünteti a fájlt, a vásárlás nem vész el', () async {
    final manager = LabelDownloadManager(
      uid: 'uid-A',
      directoryProvider: () async => temp,
      downloader: (url, path, {onProgress}) async {
        await File(path).writeAsBytes([1, 2, 3]);
      },
    );
    await manager.download(entry(), urlFor: () async => 'https://x/y.wav');
    expect(await manager.isDownloaded(entry()), isTrue);

    await manager.delete(entry());

    expect(await manager.isDownloaded(entry()), isFalse);
    expect(await manager.totalBytes(), 0);
  });

  test('a helyfoglalás a meglevő fájlokból számol', () async {
    final manager = LabelDownloadManager(
      uid: 'uid-A',
      directoryProvider: () async => temp,
      downloader: (url, path, {onProgress}) async {
        await File(path).writeAsBytes(List<int>.filled(1500, 7));
      },
    );
    await manager.download(entry(), urlFor: () async => 'https://x/a.wav');
    await manager.download(
      entry(variant: 'mp3_320'),
      urlFor: () async => 'https://x/b.mp3',
    );

    expect(await manager.totalBytes(), 3000);
    expect(await manager.downloadedKeys([entry()]), {'100:radio_wav'});
  });

  test('ugyanazt a tételt nem töltjük le kétszer egyszerre', () async {
    var calls = 0;
    final manager = LabelDownloadManager(
      uid: 'uid-A',
      directoryProvider: () async => temp,
      downloader: (url, path, {onProgress}) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await File(path).writeAsBytes([1]);
      },
    );

    final results = await Future.wait([
      manager.download(entry(), urlFor: () async => 'https://x/a.wav'),
      manager.download(entry(), urlFor: () async => 'https://x/a.wav'),
    ]);

    expect(calls, 1);
    expect(results.first.path, results.last.path);
  });

  group('másik fiók nem láthatja és nem töltheti le a zenémet', () {
    test('a letöltött zene fiókhoz kötött (A megvan, B nem látja)', () async {
      final a = manager('uid-A');
      await a.download(entry(), urlFor: () async => 'https://x/a.wav');
      expect(await a.isDownloaded(entry()), isTrue);

      final b = manager('uid-B');
      expect(
        await b.isDownloaded(entry()),
        isFalse,
        reason: 'a fájl létezése a „megvan" jelzés — más fióknak nem szabad látnia',
      );
      expect(await b.downloadedKeys([entry()]), isEmpty);
      expect(await b.totalBytes(), 0);

      // A két fiók fájl-útvonala el is tér, tehát B el sem érné A fájlját.
      expect(
        (await a.fileFor(entry())).path,
        isNot((await b.fileFor(entry())).path),
      );
    });

    test('a fiókváltás nem viszi el a korábbi fiók zenéjét', () async {
      final a = manager('uid-A');
      await a.download(entry(), urlFor: () async => 'https://x/a.wav');

      // B belép, majd A vissza: A zenéje még megvan (nem kell újra letöltenie).
      final b = manager('uid-B');
      expect(await b.isDownloaded(entry()), isFalse);

      final aAgain = manager('uid-A');
      expect(await aAgain.isDownloaded(entry()), isTrue);
    });

    test('az egyik fiók törlése nem törli a másik fájlját', () async {
      final a = manager('uid-A');
      await a.download(entry(), urlFor: () async => 'https://x/a.wav');

      final b = manager('uid-B');
      await b.delete(entry());

      expect(await a.isDownloaded(entry()), isTrue);
    });

    test('hibás (elválasztót tartalmazó) azonosító sem lép ki a saját mappájából', () async {
      final escaped = LabelDownloadManager(
        uid: '../uid-A',
        directoryProvider: () async => temp,
        downloader: (url, path, {onProgress}) async {
          await File(path).writeAsBytes([1]);
        },
      );
      final file = await escaped.fileFor(entry());
      expect(file.path, isNot(contains('..')));
      expect(file.path, contains('label_music'));
    });
  });
}
