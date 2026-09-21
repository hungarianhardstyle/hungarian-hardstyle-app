import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// „Új DJ került fel" — a tulajdonos jelzése (2026-09-21):
/// *„az »új dj került fel« notifyra nem nyitja meg az adott dj adalapját, ha
/// rányomok"*.
///
/// A gyökér: az értesítés-útválasztó (`notification_center_screen.dart::_open`)
/// **nem ismerte** az `artist` célpontot, ezért a koppintás a szám-feldolgozás
/// után **egyik ágba sem** esett, és némán elveszett (se hiba, se navigáció).
///
/// Ez a teszt a **szerver összes** célpontját megköveteli a kliensen — így egy
/// új értesítés-típus nem tud csendben néma koppintássá válni.
void main() {
  late String router;
  late String server;

  setUpAll(() {
    String read(String path) =>
        File(path).readAsStringSync().replaceAll('\r\n', '\n');
    router = read('lib/screens/notifications/notification_center_screen.dart');
    server = read('functions/index.js');
  });

  test('minden szerver-oldali célpontot kezel az app', () {
    final targets = RegExp(r"targetType:\s*'([a-z_]+)'")
        .allMatches(server)
        .map((match) => match.group(1)!)
        .toSet();
    expect(
      targets.length,
      greaterThanOrEqualTo(8),
      reason: 'a szerver ennyi célpontot küld (a mérés 11 volt)',
    );
    // Ismert, dokumentált hiány: a nyeremény-értesítéshez a kliensnek nincs
    // „nyeremény azonosító alapján" lekérdezése (csak az **aktív** játéké), ezért
    // az külön kör. A lista szándékosan **rövid** — ne nőjön csendben.
    const knownGaps = {'prize'};
    for (final target in targets) {
      if (knownGaps.contains(target)) continue;
      expect(
        router,
        contains("'$target'"),
        reason: 'a(z) "$target" célpontú értesítés nem nyit semmit',
      );
    }
  });

  test('a DJ-értesítés a DJ-adatlapot nyitja (ez volt a hiba)', () {
    expect(router, contains("targetType == 'artist'"));
    expect(
      router,
      contains('ArtistDetailScreen(artistId: id)'),
      reason: 'a koppintásnak az adott DJ adatlapjára kell vinnie',
    );
  });

  test('a szervező-értesítés is nyit (ugyanaz a hiba-osztály)', () {
    expect(router, contains("targetType == 'organizer'"));
    expect(router, contains('OrganizerDetailScreen(organizerId: id)'));
  });

  test('a chatjelentés is nyit (nem szám azonosítóval)', () {
    expect(router, contains("targetType == 'chat_report'"));
    expect(router, contains('CommunityReportsScreen()'));
    final chatReportIndex = router.indexOf("targetType == 'chat_report'");
    final parseIndex = router.indexOf('final id = int.tryParse(target);');
    expect(chatReportIndex, isNonNegative);
    expect(parseIndex, isNonNegative);
    expect(
      chatReportIndex < parseIndex,
      isTrue,
      reason:
          'a jelentés azonosítója nem szám: a szám-feldolgozás előtt kell '
          'kezelni, különben a koppintás némán elveszne',
    );
  });
}
