import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/models/label_library.dart';
import 'package:hungarian_hardstyle_app/models/release.dart';
import 'package:hungarian_hardstyle_app/services/label_library_plan.dart';

/// A „Saját zenéim" lejátszási sor és a könyvtár-adat bizonyítása.
///
/// A tulajdonos kérése: *„le tudja játszani, ha vége a zenének, ugrik a
/// következőre"*, *„az egész könyvtárban tovább"*, és hogy a megvásárolt zene
/// **maradjon meg** (újra letölthető legyen).
///
/// Amit itt mérünk, az a felhasználó **füle** számára számít: mi következik, mi
/// marad ki, és mi történik a sor végén. Lejátszó és Firebase nélkül, ezért
/// minden eset mérhető.
void main() {
  HuhsRelease release(int id, String title, {String artist = 'Valaki'}) =>
      HuhsRelease(
        id: id,
        title: title,
        coverUrl: 'https://cdn.example/$id.jpg',
        genre: 'Hardstyle',
        artists: [ReleaseArtist(id: 1, name: artist)],
        tracks: const [],
        links: const {},
        products: const [],
        versions: const [],
        audioStatus: '',
        releaseDate: '2026-01-01',
        isFree: false,
        freeExternalLink: '',
      );

  LabelLibraryItem item(
    int releaseId,
    List<String> purchased, {
    List<String> unlocked = const [],
  }) => LabelLibraryItem(
    releaseId: releaseId,
    purchased: purchased,
    unlocked: unlocked,
    variants: [...purchased, ...unlocked],
  );

  group('a lejátszási sor összeállítása', () {
    test('a könyvtár sorrendjét követi (a legfrissebb kiadvánnyal elöl)', () {
      final queue = buildLabelQueue(
        items: [item(305, ['radio_wav']), item(200, ['radio_wav'])],
        catalog: {305: release(305, 'Új'), 200: release(200, 'Régi')},
      );
      expect(queue.map((entry) => entry.releaseId), [305, 200]);
    });

    test('egy kiadvány változatai a felületi sorrendben mennek', () {
      final queue = buildLabelQueue(
        items: [
          item(100, ['extended_mp3_320', 'radio_wav']),
        ],
        catalog: {100: release(100, 'Kiadvány')},
      );
      expect(queue.map((entry) => entry.variant), [
        'extended_mp3_320',
        'radio_wav',
      ]);
    });

    test('ugyanaz a tétel nem kerül kétszer a sorba', () {
      final queue = buildLabelQueue(
        items: [
          item(100, ['radio_wav', 'radio_wav']),
          item(100, ['radio_wav']),
        ],
        catalog: {100: release(100, 'Kiadvány')},
      );
      expect(queue.length, 1);
    });

    test('a reklámmal feloldott változat is hallgatható', () {
      final queue = buildLabelQueue(
        items: [
          item(100, ['radio_wav'], unlocked: ['mp3_128']),
        ],
        catalog: {100: release(100, 'Kiadvány')},
      );
      expect(queue.map((entry) => entry.variant), ['radio_wav', 'mp3_128']);
    });

    test('a katalógusból hiányzó kiadvány is a sorban marad', () {
      final queue = buildLabelQueue(
        items: [item(999, ['wav'])],
        catalog: const {},
      );
      expect(queue.length, 1);
      expect(queue.first.title, 'Kiadvány #999');
      expect(queue.first.artist, isEmpty);
      expect(queue.first.coverUrl, isEmpty);
    });

    test('a kiadvány címe és előadója a katalógusból jön', () {
      final queue = buildLabelQueue(
        items: [item(100, ['wav'])],
        catalog: {100: release(100, 'Goze - Change of Pace', artist: 'Goze')},
      );
      expect(queue.first.title, 'Goze - Change of Pace');
      expect(queue.first.artist, 'Goze');
      expect(queue.first.coverUrl, 'https://cdn.example/100.jpg');
      expect(queue.first.nowPlayingLabel, 'Goze - Change of Pace — WAV');
    });

    test('üres könyvtárból üres sor lesz (nem dob)', () {
      expect(buildLabelQueue(items: const [], catalog: const {}), isEmpty);
    });
  });

  group('lépkedés a sorban', () {
    test('a szám végén a következőre lép', () {
      expect(nextLabelQueueIndex(0, 3), 1);
      expect(nextLabelQueueIndex(1, 3), 2);
    });

    test('a sor végén megáll (nem teker körbe)', () {
      expect(nextLabelQueueIndex(2, 3), -1);
      expect(nextLabelQueueIndex(0, 1), -1);
    });

    test('az elsőnél nincs előző, és üres sornál sincs hova lépni', () {
      expect(previousLabelQueueIndex(0, 3), -1);
      expect(previousLabelQueueIndex(2, 3), 1);
      expect(nextLabelQueueIndex(0, 0), -1);
      expect(previousLabelQueueIndex(0, 0), -1);
    });

    test('az első letöltetlen tétel adja a sor kezdetét', () {
      final queue = buildLabelQueue(
        items: [item(100, ['radio_wav', 'wav'])],
        catalog: {100: release(100, 'Kiadvány')},
      );
      expect(firstUndownloadedIndex(queue, {}), 0);
      expect(firstUndownloadedIndex(queue, {'100:radio_wav'}), 1);
      expect(
        firstUndownloadedIndex(queue, {'100:radio_wav', '100:wav'}),
        -1,
        reason: 'ha minden megvan, nincs mit letölteni',
      );
    });
  });

  group('változat-nevek, kiterjesztések és fájlnevek', () {
    test('a változat neve emberi nyelvre fordul', () {
      expect(labelVariantLabel('radio_wav'), 'Radio (WAV)');
      expect(labelVariantLabel('extended_mp3_320'), 'Extended (MP3 320)');
      expect(labelVariantLabel('mp3_128'), 'MP3 128');
      expect(labelVariantLabel('free_wav'), 'WAV (ingyenes)');
      expect(labelVariantLabel('ismeretlen'), 'ismeretlen');
    });

    test('a kiterjesztés a változatból jön (ismeretlen nem tippel)', () {
      expect(labelVariantExtension('radio_wav'), 'wav');
      expect(labelVariantExtension('mp3_320'), 'mp3');
      expect(labelVariantExtension('free_wav'), 'wav');
      expect(labelVariantExtension('free_link'), 'bin');
    });

    test('a fájlnév egyedi (kiadvány + változat)', () {
      expect(labelFileName(12699, 'radio_wav'), 'huhs_12699_radio_wav.wav');
      expect(labelFileName(12699, 'mp3_320'), 'huhs_12699_mp3_320.mp3');
      expect(
        labelFileName(12699, 'radio_wav'),
        isNot(labelFileName(12699, 'radio_mp3_320')),
      );
      expect(
        labelFileName(12699, 'radio_wav'),
        isNot(labelFileName(12700, 'radio_wav')),
      );
    });
  });

  group('a könyvtár-adat beolvasása (a szerver válaszából)', () {
    test('a hiányzó `variants` a két listából áll össze', () {
      final parsed = LabelLibraryItem.fromJson({
        'releaseId': 100,
        'purchased': ['radio_wav'],
        'unlocked': ['mp3_128'],
      });
      expect(parsed.variants, ['radio_wav', 'mp3_128']);
      expect(parsed.isPurchased, isTrue);
      expect(parsed.isAdOnly, isFalse);
    });

    test('a nem-string és üres elemek kimaradnak (nem dob)', () {
      final parsed = LabelLibraryItem.fromJson({
        'releaseId': '305',
        'purchased': ['wav', 42, '', null, '  '],
        'unlocked': 'nem lista',
      });
      expect(parsed.releaseId, 305);
      expect(parsed.purchased, ['wav']);
      expect(parsed.unlocked, isEmpty);
    });

    test('a csak reklámmal feloldott kiadvány nem számít vásárlásnak', () {
      final parsed = LabelLibraryItem.fromJson({
        'releaseId': 100,
        'purchased': <String>[],
        'unlocked': ['mp3_96'],
      });
      expect(parsed.isPurchased, isFalse);
      expect(parsed.isAdOnly, isTrue);
      expect(parsed.owns('mp3_96'), isTrue);
      expect(parsed.owns('wav'), isFalse);
    });
  });
}
