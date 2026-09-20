import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/models/label_library.dart';
import 'package:hungarian_hardstyle_app/services/label_library_service.dart';

/// A „Saját zenéim" lista betöltésének bizonyítása.
///
/// A tulajdonos kérése: *„az eddig megvásárolt, letöltött zenéket is tegye be
/// oda, ugye a régebbi verziókban volt aki vásárolt, vagy feloldott zenét"*.
/// A régi bejegyzéseket a szerver ugyanabból a két gyűjteményből adja, ezért itt
/// azt mérjük, hogy a **beolvasás** nem dob el és nem talál ki adatot.
void main() {
  test('a szerver válaszából listát épít (vásárolt + feloldott)', () async {
    final service = LabelLibraryService(
      caller: () async => {
        'items': [
          {
            'releaseId': 12405,
            'purchased': ['radio_mp3_320'],
            'unlocked': ['mp3_128'],
            'variants': ['radio_mp3_320', 'mp3_128'],
          },
        ],
        'count': 1,
      },
    );

    final items = await service.load();

    expect(items, hasLength(1));
    expect(items.first.releaseId, 12405);
    expect(items.first.variants, ['radio_mp3_320', 'mp3_128']);
    expect(items.first.isPurchased, isTrue);
  });

  test('az értelmezhetetlen sorokat kihagyja (nem tippel)', () async {
    final service = LabelLibraryService(
      caller: () async => {
        'items': [
          {'releaseId': 0, 'variants': ['wav']},
          {'releaseId': 100, 'variants': <String>[]},
          {'releaseId': 200, 'purchased': ['wav']},
          'nem objektum',
        ],
      },
    );

    final items = await service.load();

    expect(items, hasLength(1));
    expect(items.first.releaseId, 200);
  });

  test('a hiányzó `items` üres listát ad (nem dob)', () async {
    final service = LabelLibraryService(caller: () async => {'count': 0});
    expect(await service.load(), isEmpty);
  });

  test('a hiba NEM lesz üres könyvtár (a felület meg tudja különböztetni)', () async {
    final service = LabelLibraryService(
      caller: () async => throw StateError('hálózat'),
    );
    // Ez fontos: ha itt üres listát adnánk, a felhasználó azt hinné, elvesztek
    // a vásárlásai. A hiba ezért továbbmegy a felületnek.
    await expectLater(service.load(), throwsA(isA<StateError>()));
  });

  test('a letöltési hivatkozást a szerver adja (a kliens nem dönthet róla)', () async {
    final asked = <String>[];
    final service = LabelLibraryService(
      downloadUrlCaller: (releaseId, variant) async {
        asked.add('$releaseId:$variant');
        return 'https://example.test/signed?release=$releaseId&variant=$variant';
      },
    );

    final url = await service.downloadUrl(releaseId: 12405, variant: 'radio_wav');

    expect(asked, ['12405:radio_wav']);
    expect(url, contains('release=12405'));
  });

  test('a modell a szerver mezőit olvassa (nem a felület találgat)', () {
    final item = LabelLibraryItem.fromJson({
      'releaseId': 12238,
      'purchased': ['extended_mp3_320'],
      'unlocked': ['free_wav'],
    });
    expect(item.owns('extended_mp3_320'), isTrue);
    expect(item.owns('free_wav'), isTrue);
    expect(item.owns('wav'), isFalse);
    expect(item.isAdOnly, isFalse);
  });
}
