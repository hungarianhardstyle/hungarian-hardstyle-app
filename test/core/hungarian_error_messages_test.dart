import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/core/errors/playback_error.dart';
import 'package:hungarian_hardstyle_app/core/errors/user_facing_error.dart';

/// A tulajdonos kérése: *„a hibaüzeneteket amúgy is magyarul kéne"*.
///
/// Az éles eset: a lejátszó egy **angol** motor-üzenetet írt ki a képernyőre
/// („You cannot add items while items are being added from addStream"). Ezek a
/// tesztek azt őrzik, hogy a felületre **soha** ne kerülhessen idegen nyelvű
/// technikai szöveg, a saját magyar üzeneteink viszont maradjanak meg.
void main() {
  group('a lejátszó hibaüzenetei', () {
    test('az rxdart/audio_service éles üzenete MAGYAR üzenetet ad', () {
      final message = playbackErrorMessage(
        StateError(
          'You cannot add items while items are being added from addStream',
        ),
      );
      expect(message, 'A lejátszás nem indult el. Próbáld újra.');
    });

    test('eltűnt fájlra a „töltsd le újra" tanácsot adja', () {
      expect(
        playbackErrorMessage(Exception('FileSystemException: no such file')),
        contains('töltsd le újra'),
      );
      expect(
        playbackErrorMessage(Exception('Cannot open file')),
        contains('töltsd le újra'),
      );
    });

    test('ismeretlen formátumnál a formátumra utal', () {
      expect(
        playbackErrorMessage(Exception('Unsupported format')),
        contains('nem tudja lejátszani'),
      );
    });

    test('ismeretlen hibára is magyar, általános üzenet jön', () {
      expect(
        playbackErrorMessage(null),
        'A lejátszás nem indult el. Próbáld újra.',
      );
      expect(
        playbackErrorMessage(Exception('valami furcsa')),
        'A lejátszás nem indult el. Próbáld újra.',
      );
    });

    test('EGYIK üzenet sem tartalmaz idegen (angol) fordulatot', () {
      final samples = <Object?>[
        StateError('You cannot add items while items are being added'),
        Exception('no such file'),
        Exception('Unsupported codec'),
        Exception('permission denied'),
        null,
        'random',
      ];
      for (final sample in samples) {
        final message = playbackErrorMessage(sample);
        expect(
          looksLikeForeignEngineMessage(message),
          isFalse,
          reason: 'a felületre csak magyar szöveg kerülhet: „$message"',
        );
      }
    });
  });

  group('a közös hibaüzenet-fordító (userFacingError)', () {
    test('a saját MAGYAR StateError üzenetünk változatlanul megy át', () {
      expect(
        userFacingError(StateError('Ismerős-jelöléshez regisztráció szükséges.')),
        'Ismerős-jelöléshez regisztráció szükséges.',
      );
      expect(
        userFacingError(StateError('Csak admin törölhet Chat-üzenetet.')),
        'Csak admin törölhet Chat-üzenetet.',
      );
    });

    test('az ANGOL motor-üzenet viszont már nem jut ki', () {
      final message = userFacingError(
        StateError(
          'You cannot add items while items are being added from addStream',
        ),
      );
      expect(looksLikeForeignEngineMessage(message), isFalse);
      expect(message, 'A művelet nem sikerült. Próbáld újra később.');
    });

    test('más tipikus angol keretrendszer-szövegek sem jutnak ki', () {
      for (final english in [
        'Null check operator used on a null value',
        'Bad state: Stream has already been listened to.',
        'UnimplementedError',
        'type \'int\' is not a subtype of type \'String\'',
        'A ValueNotifier<int> was used after being disposed',
      ]) {
        final message = userFacingError(StateError(english));
        expect(
          looksLikeForeignEngineMessage(message),
          isFalse,
          reason: 'ezt fordítottuk: „$english"',
        );
      }
    });

    test('a hálózati hibákra továbbra is a magyar üzenet jön', () {
      expect(
        userFacingError(Exception('network-request-failed')),
        'Nem sikerült kapcsolódni. Ellenőrizd az internetkapcsolatot.',
      );
    });

    test('üres StateError üzenetre az általános magyar üzenet jön', () {
      expect(
        userFacingError(StateError('')),
        'A művelet nem sikerült. Próbáld újra később.',
      );
    });
  });

  group('a szűrő (looksLikeForeignEngineMessage) önmagában', () {
    test('a magyar mondatokat nem bántja', () {
      for (final hungarian in [
        'Ismerős-jelöléshez regisztráció szükséges.',
        'Ez a név már foglalt.',
        'A művelet nem sikerült. Próbáld újra később.',
      ]) {
        expect(looksLikeForeignEngineMessage(hungarian), isFalse);
      }
    });

    test('az angol fordulatokat felismeri', () {
      for (final english in [
        'You cannot add items',
        'Bad state: no element',
        'Null check operator used on a null value',
        'Unhandled exception',
        'was used after being disposed',
      ]) {
        expect(
          looksLikeForeignEngineMessage(english),
          isTrue,
          reason: 'ezt fel kell ismerni: „$english"',
        );
      }
    });
  });
}
