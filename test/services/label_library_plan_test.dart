import 'dart:io';

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

  group('a megjelenített kiadványok (a listából eltűnt kiadvány)', () {
    test('a már nem elérhető kiadvány NEM jelenik meg', () {
      // A tulajdonos kérése: *„a megvásárolt zenék között ne látszódjon a már
      // eltávolított kiadvány, felesleges"*.
      final items = [
        item(100, ['radio_wav']),
        item(200, ['mp3_96']),
      ];
      final visible = visibleLibraryItems(items, unavailable: {200});
      expect(visible.map((entry) => entry.releaseId), [100]);
    });

    test('ha minden kiadvány eltűnt, üres a lista (nem hiba)', () {
      final visible = visibleLibraryItems(
        [
          item(100, ['radio_wav']),
        ],
        unavailable: {100},
      );
      expect(visible, isEmpty);
    });

    test('üres kihagyás-halmaznál minden megmarad, és a lista másolat', () {
      final items = [
        item(100, ['radio_wav']),
      ];
      final visible = visibleLibraryItems(items);
      expect(visible.map((entry) => entry.releaseId), [100]);
      expect(
        identical(visible, items),
        isFalse,
        reason: 'a bemenetet nem adjuk vissza (a hívó módosíthatja)',
      );
    });

    test('a vásárlás/feloldás adata megmarad a szűrés után is', () {
      final visible = visibleLibraryItems([
        item(100, [], unlocked: ['mp3_96']),
      ]);
      expect(visible.single.unlocked, ['mp3_96']);
      expect(visible.single.isAdOnly, isTrue);
    });
  });

  group('a lejátszási sor összeállítása', () {
    test('a könyvtár sorrendjét követi (a legfrissebb kiadvánnyal elöl)', () {
      final queue = buildLabelQueue(
        items: [
          item(305, ['radio_wav']),
          item(200, ['radio_wav']),
        ],
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
        items: [
          item(999, ['wav']),
        ],
        catalog: const {},
      );
      expect(queue.length, 1);
      expect(queue.first.title, 'Kiadvány #999');
      expect(queue.first.artist, isEmpty);
      expect(queue.first.coverUrl, isEmpty);
    });

    test('a kiadvány címe és előadója a katalógusból jön', () {
      final queue = buildLabelQueue(
        items: [
          item(100, ['wav']),
        ],
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

    test('az első LETÖLTÖTT tétel adja a lejátszás kezdetét', () {
      final queue = buildLabelQueue(
        items: [
          item(100, ['radio_wav', 'wav']),
        ],
        catalog: {100: release(100, 'Kiadvány')},
      );
      expect(
        firstDownloadedIndex(queue, {}),
        -1,
        reason: 'amíg semmi nincs letöltve, nincs mit lejátszani',
      );
      expect(firstDownloadedIndex(queue, {'100:wav'}), 1);
      expect(firstDownloadedIndex(queue, {'100:radio_wav'}), 0);
    });

    test(
      'a lapozás ÁTUGORJA a nem letöltött tételeket (nem indít letöltést)',
      () {
        final queue = buildLabelQueue(
          items: [
            item(100, ['radio_wav', 'wav', 'mp3_320']),
          ],
          catalog: {100: release(100, 'Kiadvány')},
        );
        // Csak az első és a harmadik van meg: a „következő" a harmadik legyen.
        final downloaded = {'100:radio_wav', '100:mp3_320'};
        expect(nextDownloadedIndex(queue, downloaded, 0), 2);
        expect(previousDownloadedIndex(queue, downloaded, 2), 0);
      },
    );

    test('a sor végén megáll (nincs több letöltött tétel)', () {
      final queue = buildLabelQueue(
        items: [
          item(100, ['radio_wav', 'wav']),
        ],
        catalog: {100: release(100, 'Kiadvány')},
      );
      expect(nextDownloadedIndex(queue, {'100:radio_wav'}, 0), -1);
      expect(previousDownloadedIndex(queue, {'100:wav'}, 1), -1);
    });

    test('kiindulás: az első, illetve a legutolsó letöltött tétel', () {
      final queue = buildLabelQueue(
        items: [
          item(100, ['radio_wav', 'wav']),
        ],
        catalog: {100: release(100, 'Kiadvány')},
      );
      final downloaded = {'100:wav'};
      expect(nextDownloadedIndex(queue, downloaded, -1), 1);
      expect(previousDownloadedIndex(queue, downloaded, -1), 1);
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

  group('forrás-lint: a felület csak a LETÖLTÖTT zenéket játssza', () {
    late String source;
    late String player;

    setUpAll(() {
      source = File('lib/screens/more/my_music_screen.dart').readAsStringSync();
      // A **léptetés és a végrehajtás** a szolgáltatásban van (hogy a képernyő
      // elhagyása után is működjön), ezért azt a fájlt is mérjük.
      player = File('lib/services/music_queue_player.dart').readAsStringSync();
    });

    test('a lapozás a LETÖLTÖTT tételek sorrendjében lépked', () {
      // A 343-as körben a lapozás a **lejátszási sorrend** (`_order`) felé
      // került, hogy a keverés és az ismétlés működhessen; a 345-ben ehhez a
      // **kézi sorrend** és a **kivétel** is hozzátartozik. A szabály viszont
      // változatlan: a sorrend **csak letöltött** tételekből állhat.
      expect(
        source,
        contains('orderedPlaylistIndices('),
        reason: 'a sorrend a letöltött, ki nem vett tételekből épül',
      );
      expect(
        source,
        contains('excluded: _excludedFromPlaylist'),
        reason: 'a listáról kivett tétel nem szól bele a sorba',
      );
      expect(
        source,
        contains('customOrder: _playlistOrder'),
        reason: 'a kézi sorrend is érvényesül',
      );
      expect(
        source,
        contains('MusicQueueTrack('),
        reason: 'a sor a lejátszható tételeket (fájlútvonallal) kapja meg',
      );
      expect(
        source,
        contains('downloaded: paths.keys.toSet()'),
        reason: 'csak a letöltött fájlok kerülhetnek a sorba',
      );
      expect(
        player,
        contains('playOrderFor('),
        reason: 'a sorrend a keverést is figyelembe veszi (a szolgáltatásban)',
      );
      expect(
        source,
        isNot(contains('nextLabelQueueIndex(')),
        reason: 'a „nyers" következő már nem használható a lapozáshoz',
      );
      expect(
        _functionBody(player, 'toggle'),
        contains('await playAt(0'),
        reason: 'ha nincs kiválasztott tétel, az első lejátszható indul',
      );
    });

    test('a lejátszás NEM indít letöltést (csak jelzi, hogy nincs meg)', () {
      final body = _functionBody(source, '_playIndex');
      expect(body, isNot(contains('_ensureDownloaded')));
      expect(body, contains('if (!_downloaded.contains(entry.key))'));
      expect(body, contains('még nincs letöltve'));
    });

    test('a szám végi továbblépés is a letöltött sorrendben lép', () {
      // ⚠️ A dal **vége** a szolgáltatásban dől el: ezért lép tovább a zene akkor
      // is, ha a képernyőt közben elhagyták (korábban ott megállt).
      final body = _functionBody(player, '_onPlayerState');
      expect(body, contains('ProcessingState.completed'));
      expect(body, contains('next(isAutoAdvance: true)'));
      expect(body, isNot(contains('_ensureDownloaded')));
      expect(
        source,
        isNot(contains('_advance()')),
        reason: 'a képernyőn nem marad második léptető (két döntés = hiba)',
      );
    });

    test('a nyilvános listából eltűnt kiadvány NEM kap kártyát', () {
      // A tulajdonos kérése (2026-09-21): *„a megvásárolt zenék között ne
      // látszódjon a már eltávolított kiadvány, felesleges"*. Ezért a listát a
      // tiszta `visibleLibraryItems` szűri, és a régi „Ez a kiadvány már nem
      // elérhető" kártya **eltűnt** (nem csak átfogalmazva lett).
      expect(source, contains('visibleLibraryItems('));
      expect(source, contains('unavailable: _unavailableReleases'));
      expect(
        source,
        isNot(contains("'Ez a kiadvány már nem elérhető'")),
        reason: 'a hely kitöltése helyett a kiadvány ki sem kerül a listára',
      );
      expect(source, isNot(contains('_buildUnavailableCard')));
      expect(source, contains('for (final item in visible) _buildReleaseCard'));
      expect(
        source,
        contains(r'${visible.length} kiadvány'),
        reason: 'a fejléc is a látható kiadványokat számolja',
      );
      expect(source, contains('.getRelease(releaseId)'));
      expect(
        source,
        contains('catalogById.containsKey(item.releaseId)'),
        reason: 'a sorba csak az kerülhet, amiről tudjuk, mi az',
      );
    });

    test('a KÁRTYA is a katalógusból veszi a címet (ez tört el a 341-ben)', () {
      // ⚠️ A tulajdonos képernyőfelvétele: a lista végig „Kiadvány #12466 /
      // Adatok betöltése…" volt, miközben a lejátszósáv MÁR a valódi címet
      // mutatta. Az ok: a kártya csak a lusta térképet (`_releaseMeta`) nézte,
      // a katalógust (`_catalogById`) nem — a sor viszont a katalógust használta,
      // ezért mondott ellent a kettő.
      final body = _functionBody(source, '_buildReleaseCard');
      expect(
        body,
        contains('_catalogById[item.releaseId]'),
        reason: 'a kártya címe a katalógusból jön',
      );
      expect(body, contains('?? _releaseMeta[item.releaseId]'));
      expect(
        source,
        contains('_catalogById = catalogById;'),
        reason: 'a képernyő a katalógust is eltárolja a rajzoláshoz',
      );
    });
  });
}

/// Kiveszi egy Dart-metódus törzsét a nyitó kapcsos zárójel bezárásáig.
///
/// A minta a **definícióra** illeszkedik (sortörés + visszatérési típus + név +
/// `(`), nem a puszta névre: a `_advance(` alak a **hívási helyet** is eltalálná
/// (`unawaited(_advance())`), és akkor rossz kapcsos zárójelet párosítana.
///
/// ⚠️ A **paraméterlistát át kell ugrani**: a névvel kezdődő NÉVES paraméter
/// (`{int? startAtMs}`) kapcsos zárójele különben a metódus törzse helyett
/// találódna meg — ez a hiba 2026-09-20-án több forrás-lintet is „elhasaltatott"
/// látszólag ok nélkül.
String _functionBody(String source, String name) {
  final match = RegExp(
    '\\n\\s*[A-Za-z_][\\w<>, ?]*\\s${RegExp.escape(name)}\\(',
  ).firstMatch(source);
  expect(match, isNotNull, reason: 'nincs ilyen tag: $name');
  final openParen = source.indexOf('(', match!.start);
  expect(
    openParen,
    isNonNegative,
    reason: '$name paraméterlistája nem található',
  );
  var parens = 0;
  var afterParams = -1;
  for (var i = openParen; i < source.length; i++) {
    final char = source[i];
    if (char == '(') parens++;
    if (char == ')') {
      parens--;
      if (parens == 0) {
        afterParams = i;
        break;
      }
    }
  }
  expect(
    afterParams,
    isNonNegative,
    reason: '$name paraméterlistája nem záródik le',
  );
  final open = source.indexOf('{', afterParams);
  expect(open, isNonNegative, reason: '$name törzse nem található');
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    final char = source[i];
    if (char == '{') depth++;
    if (char == '}') {
      depth--;
      if (depth == 0) return source.substring(open + 1, i);
    }
  }
  fail('$name törzse nem záródik le');
}
