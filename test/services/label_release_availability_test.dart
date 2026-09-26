import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/services/label_release_availability.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A „nyilvános listáról eltűnt kiadvány" emlékezetének bizonyítása.
///
/// MIÉRT FONTOS: ettől lesz **azonnali** a kártya (nem „Kiadvány betöltése…"),
/// viszont ha rosszul működik, akkor **örökre elrejthet** egy létező kiadványt —
/// ezért a lejárat és a hibás bejegyzések kezelése a legfontosabb itt.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  LabelReleaseAvailability store() => LabelReleaseAvailability();

  const ttlMs = 24 * 3600 * 1000;

  group('a tiszta szűrő (lejárat és hibás bejegyzés)', () {
    final now = DateTime(2026, 9, 20, 12).millisecondsSinceEpoch;

    test('a friss jelölés benne marad', () {
      expect(
        activeMissingIds(
          [
            {'id': 12327, 'at': now - 1000},
          ],
          nowMs: now,
          ttlMs: ttlMs,
        ),
        [12327],
      );
    });

    test('a 24 óránál régebbi jelölés lejár (újra megnézzük)', () {
      expect(
        activeMissingIds(
          [
            {'id': 12327, 'at': now - ttlMs - 1},
          ],
          nowMs: now,
          ttlMs: ttlMs,
        ),
        isEmpty,
      );
      // Pontosan a határon (24 óra) még érvényes: nem lötyögünk a határral.
      expect(
        activeMissingIds(
          [
            {'id': 12327, 'at': now - ttlMs},
          ],
          nowMs: now,
          ttlMs: ttlMs,
        ),
        [12327],
      );
    });

    test('hibás sorokat eldobunk (nem lesz belőlük „nem elérhető")', () {
      expect(
        activeMissingIds(
          [
            {'id': '12327', 'at': now},
            {'id': 0, 'at': now},
            {'id': -5, 'at': now},
            {'id': 305},
            {'id': 305, 'at': 'tegnap'},
            'nem egy térkép',
            null,
          ],
          nowMs: now,
          ttlMs: ttlMs,
        ),
        isEmpty,
      );
    });

    test('ugyanaz az azonosító nem kerül be kétszer', () {
      expect(
        activeMissingIds(
          [
            {'id': 305, 'at': now},
            {'id': 305, 'at': now - 10},
          ],
          nowMs: now,
          ttlMs: ttlMs,
        ),
        [305],
      );
    });
  });

  group('mentés és visszaolvasás', () {
    test('a megjelölt kiadvány visszaolvasható', () async {
      await store().markMissing(12327);
      expect(await store().loadMissing(), {12327});
    });

    test('több kiadvány is megjelölhető, és a törlés csak azt veszi ki', () async {
      final first = store();
      await first.markMissing(12327);
      await first.markMissing(999);
      expect(await first.loadMissing(), {12327, 999});
      await first.clear(12327);
      expect(await first.loadMissing(), {999});
    });

    test('érvénytelen azonosítót nem írunk be', () async {
      final target = store();
      await target.markMissing(0);
      await target.markMissing(-3);
      expect(await target.loadMissing(), isEmpty);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('huhs.release.missing'), isNull);
    });

    test('az ismételt megjelölés nem növeszti a tárolót', () async {
      final target = store();
      await target.markMissing(305);
      await target.markMissing(305);
      await target.markMissing(305);
      final preferences = await SharedPreferences.getInstance();
      final payload = preferences.getString('huhs.release.missing')!;
      // ⚠️ MÉRT ESZKÖZ-HIBA (javítva, 2026-09-26): a régi ellenőrzés a **nyers**
      // szövegben számolta a „305" rész-szöveget (`'305'.allMatches(payload)`);
      // a tárolt JSON viszont az **időpontot is** tartalmazza (`at`), és ha a
      // timestamp számjegyei között ott a `305` (mért gyakoriság: **0,8%**),
      // a találatok száma 2 lett → a teszt **hamisan bukott** (a CI-n pontosan
      // ez történt: „Expected: <1> Actual: <2>", miközben a tároló helyes volt).
      // Mostantól a **feldolgozott** listát számoljuk: az időpont számjegyei
      // nem játszanak (`tmp/probe-label-flake-cause.mjs` méri a gyakoriságot).
      final stored = (jsonDecode(payload) as List)
          .whereType<Map>()
          .where((entry) => entry['id'] == 305)
          .length;
      expect(stored, 1, reason: 'tároló: $payload');
    });

    test('az utolsó törlés után a kulcs eltűnik (nem marad üres lista)', () async {
      final target = store();
      await target.markMissing(305);
      await target.clear(305);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('huhs.release.missing'), isNull);
    });
  });

  group('hibás tároló', () {
    test('nem-JSON esetén üres halmaz, és a hibás kulcs törlődik', () async {
      SharedPreferences.setMockInitialValues({
        'huhs.release.missing': 'ez nem json',
      });
      expect(await store().loadMissing(), isEmpty);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('huhs.release.missing'), isNull);
    });

    test('a nem-lista JSON sem dob hibát', () async {
      SharedPreferences.setMockInitialValues({
        'huhs.release.missing': '{"id":305}',
      });
      expect(await store().loadMissing(), isEmpty);
    });

    test('a lejárt bejegyzést a betöltés ki is takarítja', () async {
      final old = DateTime.now().millisecondsSinceEpoch - ttlMs - 5000;
      SharedPreferences.setMockInitialValues({
        'huhs.release.missing': '[{"id":12327,"at":$old}]',
      });
      expect(await store().loadMissing(), isEmpty);
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getString('huhs.release.missing'),
        isNull,
        reason: 'a lejárt jelölés ne maradjon a tárolóban',
      );
    });
  });

  // --- FORRÁS-LINT: a képernyő tényleg használja-e --------------------------
  group('forrás-lint: a könyvtár megjegyzi az eltűnt kiadványt', () {
    late String source;

    setUpAll(() {
      source = File(
        'lib/screens/more/my_music_screen.dart',
      ).readAsStringSync();
    });

    test('a képernyő a megnyitáskor betölti a jelöléseket', () {
      expect(
        source,
        contains('unawaited(_loadReleaseAvailability())'),
        reason: 'különben a kártya megint „betöltés" állapotban indul',
      );
      expect(source, contains('_availability.loadMissing()'));
    });

    test('a sikeres lekérdezés TÖRLI, a sikertelen MEGJELÖLI a kiadványt', () {
      final body = _functionBody(source, '_resolveMissingReleases');
      final clearIndex = body.indexOf('_availability.clear(');
      final markIndex = body.indexOf('_availability.markMissing(');
      expect(clearIndex, isNonNegative, reason: 'ha mégis megvan, törölni kell');
      expect(markIndex, isNonNegative, reason: 'ha nincs meg, meg kell jegyezni');
      expect(
        clearIndex < markIndex,
        isTrue,
        reason: 'a törlés a siker-ágban, a jelölés a hiba-ágban van',
      );
    });
  });
}

/// Kiveszi egy Dart-metódus törzsét a nyitó kapcsos zárójel bezárásáig.
///
/// Ugyanaz a segéd, mint a `label_library_plan_test.dart`-ban (a paraméterlistát
/// átugorja, különben egy néves paraméter kapcsos zárójele lenne a „törzs").
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
