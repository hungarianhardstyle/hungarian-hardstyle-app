import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **Követés és heti összefoglaló** — a kliens-oldali kapcsolatok mérése.
///
/// MIÉRT FORRÁS-LINT: mindkettő olyan „néma" hibaosztály, amit a felhasználó csak
/// hetekkel később venne észre (nem kap összefoglalót; nem tudja követni a DJ-t a
/// profiljáról). A mérés ezért a **huzalozást** kéri számon:
///   * a Beállításokban van „Heti összefoglaló" kapcsoló, és a mentés a szerverre
///     (`notificationPreferences.digest`) is eljut;
///   * a DJ-adatlap fejlécében van kedvenc („követés") gomb.
void main() {
  test('a Beállításokban van heti összefoglaló kapcsoló', () {
    final source = File('lib/screens/more/settings_screen.dart').readAsStringSync();
    expect(source.contains("_digestNotificationsKey = 'weekly_digest_enabled'"), isTrue);
    expect(source.contains("AppText('Heti összefoglaló')"), isTrue);
    // A kapcsoló a közös preference-mentő utat használja (nem saját írás).
    expect(source.contains('_setNotificationPreference('), isTrue);
    expect(source.contains('digest: _digestNotificationsEnabled'), isTrue);
  });

  test('a beállítás a szerverre is eljut (Firestore notificationPreferences.digest)', () {
    final source = File('lib/services/push_notification_service.dart').readAsStringSync();
    expect(source.contains('required bool digest'), isTrue, reason: 'hiányzik a paraméter');
    // ⚠️ SZÁMOLUNK, NEM „SZEREPEL-E” — a mutációs bizonyíték mérte ki, hogy a
    // puszta `contains` **nem** fogta el azt, amikor a Firestore-írásból kivettem
    // a kulcsot: a plugin-payloadban ugyanaz a szöveg ott maradt. Ezért:
    //   (1) a `notificationPreferences` blokkban KÜLÖN meg kell lennie,
    //   (2) összesen pontosan **kettő** előfordulás van (Firestore + plugin).
    expect(
      RegExp(r"'notificationPreferences': \{[\s\S]{0,500}?'digest': digest,").hasMatch(source),
      isTrue,
      reason: 'a Firestore notificationPreferences blokkból hiányzik a digest',
    );
    final occurrences = RegExp(r"'digest': digest,").allMatches(source).length;
    expect(occurrences, 2, reason: 'Firestore + plugin payload = 2 előfordulás (mért: $occurrences)');
  });

  test('a DJ-adatlap fejlécében van kedvenc (követés) gomb', () {
    final source = File('lib/screens/artists/artist_detail_screen.dart').readAsStringSync();
    expect(source.contains('FavoriteButton('), isTrue);
    expect(source.contains('FavoriteKind.artist'), isTrue);
    expect(source.contains("import '../../widgets/favorite_button.dart'"), isTrue);
  });

  test('a szótár tartalmazza a két új feliratot', () {
    final dictionary =
        jsonDecode(File('assets/i18n/en.json').readAsStringSync()) as Map<String, dynamic>;
    expect(dictionary['Heti összefoglaló'], 'Weekly recap');
    expect(
      dictionary['Vasárnap esti összegzés a hét híreiről és eseményeiről'],
      contains('Sunday'),
    );
  });

  test('forrás-lint: a szerver a digest kaput olvassa (nem csak a kliens írja)', () {
    final server = File('functions/weekly-digest-plan.js').readAsStringSync();
    expect(server.contains("prefs.digest === false"), isTrue, reason: 'a szerver-kapu hiányzik');
    final wired = File('functions/index.js').readAsStringSync();
    expect(wired.contains('weeklyDigestAllowed('), isTrue);
  });
}
