import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/models/prize.dart';
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
    // A statikus (memóriabeli) tükör nem szivároghat át a következő tesztbe.
    VoteMemory.resetForTests();
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

  group('a SZINKRON emlékezet (preload) — a másodpercek eltüntetése', () {
    test('preload után a szinkron olvasó azonnal válaszol', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'huhs.played.game.uid-A.42': true,
        'huhs.played.game.uid-A.43': false,
      });
      VoteMemory.resetForTests();

      await VoteMemory.preload();

      expect(VoteMemory.isLoaded, isTrue);
      expect(VoteMemory.isGamePlayedSync('uid-A', 42), isTrue);
      expect(
        VoteMemory.isGamePlayedSync('uid-A', 43),
        isFalse,
        reason: 'hamis értéket sosem mondunk igaznak',
      );
      expect(VoteMemory.isGamePlayedSync('uid-B', 42), isFalse);
      expect(VoteMemory.isGamePlayedSync(null, 42), isFalse);
    });

    test('preload ELŐTT a szinkron olvasó nem hazudik igazat', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'huhs.played.game.uid-A.42': true,
      });
      VoteMemory.resetForTests();

      expect(VoteMemory.isGamePlayedSync('uid-A', 42), isFalse);
      // …az aszinkron út viszont már tudja:
      expect(await VoteMemory.isGamePlayed('uid-A', 42), isTrue);
      // …és onnantól a szinkron is (a találat bekerül a tükörbe).
      expect(VoteMemory.isGamePlayedSync('uid-A', 42), isTrue);
    });

    test('írás és törlés AZONNAL látszik a szinkron olvasón', () async {
      await VoteMemory.markGamePlayed('uid-A', 42);
      expect(VoteMemory.isGamePlayedSync('uid-A', 42), isTrue);

      await VoteMemory.clearGamePlayed('uid-A', 42);
      expect(VoteMemory.isGamePlayedSync('uid-A', 42), isFalse);
    });

    test('a kérdőív és a nyereményjáték is kapott szinkron utat', () async {
      await VoteMemory.markPollVoted('uid-A', 7);
      expect(VoteMemory.isPollVotedSync('uid-A', 7), isTrue);
      expect(VoteMemory.isPollVotedSync('uid-A', 8), isFalse);

      await VoteMemory.markPrizePlayed(
        'uid-A',
        9,
        const HuhsPrizePlay(played: true, correct: true, answerIndex: 2),
      );
      final play = VoteMemory.prizePlaySync('uid-A', 9);
      expect(play, isNotNull);
      expect(play!.correct, isTrue);
      expect(play.answerIndex, 2);
      expect(VoteMemory.prizePlaySync('uid-A', 10), isNull);
    });

    test('minden írás ÉRTESÍTÉST ad (a kártya magától frissül)', () async {
      var notifications = 0;
      void listener() => notifications += 1;
      VoteMemory.revision.addListener(listener);
      addTearDown(() => VoteMemory.revision.removeListener(listener));

      await VoteMemory.markGamePlayed('uid-A', 42);
      expect(notifications, 1);
      await VoteMemory.clearGamePlayed('uid-A', 42);
      expect(notifications, 2);
      // Az ismételt törlés nem ad felesleges értesítést.
      await VoteMemory.clearGamePlayed('uid-A', 42);
      expect(notifications, 2);
    });
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

    test('a jelzés már az első képkockán beáll (szinkron útból)', () {
      expect(source, contains('VoteMemory.isGamePlayedSync('));
      expect(
        source.indexOf('VoteMemory.isGamePlayedSync('),
        lessThan(source.indexOf('_loadSubmissionStatus()')),
        reason: 'az initState-ben, minden await előtt kell lennie',
      );
      expect(
        source,
        contains("if (FirebaseAuth.instance.currentUser == null)"),
        reason: 'ne várjunk feleslegesen az auth-jelzésre',
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

  group('forrás-lint: a kvíz KÁRTYÁJA is azonnal a helyes állapotot mutatja', () {
    late String home;

    setUpAll(() {
      home = File('lib/screens/home/home_screen.dart').readAsStringSync();
    });

    test('a kártya a szinkron emlékezetből dönt', () {
      expect(home, contains('VoteMemory.isGamePlayedSync(uid, game.id)'));
    });

    test('a kártya szövege megmondja, hogy már játszottál', () {
      expect(home, contains('Már játszottál — eredmény megtekintése'));
    });

    test('a kártya figyeli az emlékezet változását', () {
      expect(home, contains('VoteMemory.revision'));
      expect(home, contains('ValueListenableBuilder<int>'));
    });
  });
}
