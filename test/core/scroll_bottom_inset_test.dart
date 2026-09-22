import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/core/layout/scroll_bottom_inset.dart';

/// A görgethető oldalak ALJÁNAK bizonyítása.
///
/// A tulajdonos jelzése (2026-09-22): *„ha az achievement notifyra nyomok,
/// megnyílik a saját adatlap, viszont nem tudok legörgetni az aljára rendesen"*.
///
/// A gyökér: a **saját profil** (`CommunityPublicProfileScreen`) volt az egyetlen
/// hosszú, görgethető oldal, amelynek az alján **nem** volt hely a rendszer alsó
/// sávjának — a többi részletoldal (hír, esemény, DJ, szervező) már használt
/// ilyet. Ezért az utolsó kártya (átvett DJ-adatlapok, kedvenc DJ-k, megjelölt
/// események) takarásban maradt.
///
/// A döntés ezért **egy helyre** került (`scrollBottomInset`), és a szabályt
/// forrás-lint is méri mind az öt érintett képernyőn.
void main() {
  group('a görgetési alsó hely (tiszta számítás)', () {
    test('a rendszer sávja + a szándékos levegő', () {
      expect(scrollBottomInsetFor(0), 24);
      expect(scrollBottomInsetFor(48), 72);
      expect(scrollBottomInsetFor(48, extra: 28), 76);
    });

    test('hibás/hiányzó érték nem visz mínuszba', () {
      // A `MediaQuery` hiba esetén 0-t ad, de védjük magunkat a képtelen
      // értékektől is: egy mínuszos padding összehúzná a listát.
      expect(scrollBottomInsetFor(-10), 24);
      expect(scrollBottomInsetFor(double.nan), 24);
      expect(scrollBottomInsetFor(double.infinity), 24);
    });

    test('a levegő nélkül is marad a rendszer sávja', () {
      expect(scrollBottomInsetFor(30, extra: 0), 30);
    });
  });

  group('FORRÁS-LINT: minden hosszú, görgethető oldal használja', () {
    String read(String path) =>
        File(path).readAsStringSync().replaceAll('\r\n', '\n');

    test('a SAJÁT PROFIL — ez volt a hiba', () {
      final source = read('lib/screens/more/community_users_screen.dart');
      expect(
        source.contains('ScrollBottomInset'),
        isTrue,
        reason: 'a profil aljára kell a rendszer sávja + levegő',
      );
      // A korábbi `EdgeInsets.all(20)` alsó 20 px-e kevés volt: alulra 0 kerül,
      // a helyet a `ScrollBottomInset` adja.
      expect(
        source.contains('EdgeInsets.fromLTRB(20, 20, 20, 0)'),
        isTrue,
        reason: 'a profil lista alsó paddingje ne legyen fix 20',
      );
      // A beszúrás a lista VÉGÉN van (a kedvenc szekció után).
      final favorite = source.indexOf('_FavoriteProfilesSection(');
      final inset = source.indexOf('const ScrollBottomInset(),');
      expect(inset, greaterThan(favorite));
    });

    test('a többi részletoldal is a KÖZÖS szabályt használja', () {
      // A négy oldal korábban külön-külön írta ki ugyanezt a számítást
      // (+24/+28); most egy helyről jön, ezért nem tud széthúzni.
      const screens = {
        'lib/screens/news/news_detail_screen.dart': 'scrollBottomInset(',
        'lib/screens/events/event_detail_screen.dart': 'ScrollBottomInset',
        'lib/screens/artists/artist_detail_screen.dart': 'ScrollBottomInset(',
        'lib/screens/organizers/organizer_detail_screen.dart':
            'ScrollBottomInset(',
      };
      screens.forEach((path, marker) {
        final source = read(path);
        expect(
          source.contains(marker),
          isTrue,
          reason: '$path: a közös alsó helyet kell használnia',
        );
        expect(
          source.contains('MediaQuery.viewPaddingOf(context).bottom + '),
          isFalse,
          reason: '$path: ne írja ki külön a számítást',
        );
      });
    });
  });
}
