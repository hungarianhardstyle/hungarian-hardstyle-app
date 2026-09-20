import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/services/vote_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A kvíz „már játszottál" állapotának **azonnali** kijelzése.
///
/// A tulajdonos jelzése: *„kviznél lassan frissül, hogy már kitöltötte, pár
/// másodpercig úgy jelzi mintha tudna még játszani"*.
///
/// A mért gyökér: az állapot csak egy három lépcsős út végén derül ki
/// (app → Cloud Function → WordPress), a képernyő pedig addig játszhatónak
/// mutatta a kvízt. A kérdőív és a nyereményjáték **már** megkapta érte a helyi
/// emlékezetet (`VoteMemory`), a kvíz viszont nem — ez a hiány pótolva.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('a beküldött kvíz megjegyződik, és azonnal látszik', () async {
    expect(await VoteMemory.isGamePlayed('uid-A', 42), isFalse);

    await VoteMemory.markGamePlayed('uid-A', 42);

    expect(await VoteMemory.isGamePlayed('uid-A', 42), isTrue);
  });

  test('a jelzés TÖRÖLHETŐ (ha a szerver szerint mégsem játszottál)', () async {
    await VoteMemory.markGamePlayed('uid-A', 42);
    await VoteMemory.clearGamePlayed('uid-A', 42);

    expect(await VoteMemory.isGamePlayed('uid-A', 42), isFalse);
  });

  test('másik fiók NEM örökli az emlékezetet (UID a kulcsban)', () async {
    await VoteMemory.markGamePlayed('uid-A', 42);

    expect(await VoteMemory.isGamePlayed('uid-B', 42), isFalse);
  });

  test('másik kvíz nem keveredik össze', () async {
    await VoteMemory.markGamePlayed('uid-A', 42);

    expect(await VoteMemory.isGamePlayed('uid-A', 43), isFalse);
  });

  test('vendégként (UID nélkül) nem írunk és nem is olvasunk emléket', () async {
    await VoteMemory.markGamePlayed(null, 42);
    await VoteMemory.markGamePlayed('   ', 42);

    expect(await VoteMemory.isGamePlayed(null, 42), isFalse);
    expect(await VoteMemory.isGamePlayed('', 42), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys().where((key) => key.contains('game')), isEmpty);
  });

  test('érvénytelen kvíz-azonosítóval nem írunk félre semmit', () async {
    await VoteMemory.markGamePlayed('uid-A', 0);
    await VoteMemory.markGamePlayed('uid-A', -5);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys().where((key) => key.contains('game')), isEmpty);
  });

  test('a kvíz-emlékezet nem nyúl a kérdőív/nyereményjáték kulcsaihoz', () async {
    await VoteMemory.markGamePlayed('uid-A', 42);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), contains('huhs.played.game.uid-A.42'));
    expect(await VoteMemory.isPollVoted('uid-A', 42), isFalse);
    expect(await VoteMemory.prizePlay('uid-A', 42), isNull);
  });

  group('forrás-lint: a kvíz képernyője tényleg használja az emlékezetet', () {
    late String source;

    setUpAll(() {
      source = File('lib/screens/games/game_screen.dart').readAsStringSync();
    });

    test('beküldés után megjegyzi a tényt', () {
      expect(source, contains('VoteMemory.markGamePlayed('));
    });

    test('a döntés előtt a helyi emlékezetet is megkérdezi', () {
      expect(source, contains('VoteMemory.isGamePlayed('));
      expect(
        source.indexOf('VoteMemory.isGamePlayed('),
        lessThan(source.indexOf('getGameAttemptStatus(')),
        reason: 'az emlékezetet ELŐBB kell kérdezni, mint a szervert',
      );
    });

    test('a szerver a hiteles forrás: ha nem játszottál, törli a jelzést', () {
      expect(source, contains('VoteMemory.clearGamePlayed('));
    });

    test('a játszható kvíz nem látszik, ha az emlékezet szerint már játszottál', () {
      expect(source, contains('_playedHint && !_submitted'));
      expect(source, contains('_buildWaitingForResult'));
      expect(
        source,
        contains("'Ebben a kvízben már játszottál'"),
        reason: 'a várakozás alatt is egyértelmű, hogy már megvan',
      );
    });
  });
}
