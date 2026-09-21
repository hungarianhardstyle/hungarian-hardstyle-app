import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/services/music_queue_player.dart';

/// A **lejátszási sor tiszta állapotgépe** (`MusicQueuePlan`).
///
/// MIÉRT PONT EZ A TESZT: a 346 utáni átkötés lényege, hogy a „mi következik"
/// döntés a **szolgáltatásba** került — a képernyő csak az alap-sorrendet adja át.
/// Ettől két dolog sérülhet **némán**:
///
///  1. a **most hallgatott tétel elveszik**, amikor a lista elmozdul (új vásárlás,
///     törölt fájl, átrendezés) → a „következő" gomb másik zenére lépne;
///  2. a **keverés minden fájlpásztázásnál újrakever**, ezért a „következő" gomb
///     ugrál (a felhasználó azt hinné, elromlott a lejátszó).
///
/// A terv **lejátszó nélkül** mérhető (nincs `AudioPlayer`, nincs platformcsatorna),
/// ezért ez a teszt gyors és mindig fut.
void main() {
  MusicQueueTrack track(int id) => MusicQueueTrack(
    key: '$id:mp3_96',
    filePath: '/tmp/$id.mp3',
    item: MediaItem(id: '$id:mp3_96', title: 'Zene $id'),
  );

  List<String> keysOf(MusicQueuePlan plan) => [
    for (final item in plan.tracks) item.key,
  ];

  group('a sorrend és a kurzor', () {
    test('keverés nélkül az alap-sorrend az érvényes', () {
      final plan = MusicQueuePlan();
      plan.setBaseOrder([track(1), track(2), track(3)]);
      expect(keysOf(plan), ['1:mp3_96', '2:mp3_96', '3:mp3_96']);
      expect(plan.index, -1, reason: 'még nincs kiválasztott tétel');
      expect(plan.currentKey, isNull);
    });

    test('a most szóló tételt KULCS alapján találja meg (nem index alapján)', () {
      final plan = MusicQueuePlan();
      plan.setBaseOrder([track(1), track(2), track(3)]);
      plan.moveToKey('3:mp3_96');
      expect(plan.index, 2);

      // A lista elé beszúrnak egy új tételt: az indexek elmozdulnak, a szóló
      // tétel viszont marad.
      plan.setBaseOrder([track(9), track(1), track(2), track(3)]);
      expect(
        plan.currentKey,
        '3:mp3_96',
        reason: 'különben a „következő" gomb másik zenére lépne',
      );
      expect(plan.index, 3);
    });

    test('a kurzor -1 lesz, ha a szóló tétel kikerül a sorból', () {
      final plan = MusicQueuePlan();
      plan.setBaseOrder([track(1), track(2)]);
      plan.moveToKey('2:mp3_96');
      plan.setBaseOrder([track(1)]);
      expect(plan.currentKey, isNull);
      expect(plan.index, -1);
    });

    test('az új tétel a sor végére kerül (nem kell „felvenni")', () {
      final plan = MusicQueuePlan();
      plan.setBaseOrder([track(1)]);
      plan.moveToKey('1:mp3_96');
      plan.setBaseOrder([track(1), track(2)]);
      expect(keysOf(plan), ['1:mp3_96', '2:mp3_96']);
      expect(plan.currentKey, '1:mp3_96');
    });

    test('üres sor: nincs kurzor, és nem dob', () {
      final plan = MusicQueuePlan();
      plan.setBaseOrder(const []);
      expect(plan.tracks, isEmpty);
      expect(plan.index, -1);
      plan.moveToKey('1:mp3_96');
      expect(plan.index, -1);
    });
  });

  group('a keverés', () {
    test('permutáció: minden tétel pontosan egyszer szerepel', () {
      for (var seed = 0; seed < 30; seed++) {
        final plan = MusicQueuePlan(random: Random(seed));
        plan.setBaseOrder([for (var id = 1; id <= 12; id++) track(id)]);
        plan.setShuffle(true);
        final keys = keysOf(plan);
        expect(keys.length, 12, reason: 'seed=$seed');
        expect(keys.toSet().length, 12, reason: 'nincs duplázás (seed=$seed)');
        for (var id = 1; id <= 12; id++) {
          expect(keys, contains('$id:mp3_96'), reason: 'nincs kihagyás');
        }
      }
    });

    test('bekapcsoláskor a szóló tétel az ELSŐ helyre kerül', () {
      final plan = MusicQueuePlan(random: Random(7));
      plan.setBaseOrder([for (var id = 1; id <= 8; id++) track(id)]);
      plan.moveToKey('5:mp3_96');
      plan.setShuffle(true);
      expect(
        plan.tracks.first.key,
        '5:mp3_96',
        reason: 'a keverés nem szakíthatja meg azt, amit épp hallgatunk',
      );
      expect(plan.currentKey, '5:mp3_96');
      expect(plan.index, 0);
    });

    test('kikapcsoláskor visszaáll az alap-sorrend', () {
      final plan = MusicQueuePlan(random: Random(3));
      plan.setBaseOrder([for (var id = 1; id <= 6; id++) track(id)]);
      plan.moveToKey('4:mp3_96');
      plan.setShuffle(true);
      plan.setShuffle(false);
      expect(keysOf(plan), [
        for (var id = 1; id <= 6; id++) '$id:mp3_96',
      ]);
      expect(plan.currentKey, '4:mp3_96');
      expect(plan.index, 3);
    });

    test('VÁLTOZATLAN alapnál NEM kever újra (nem ugrál a következő)', () {
      final plan = MusicQueuePlan(random: Random(11));
      final base = [for (var id = 1; id <= 10; id++) track(id)];
      plan.setBaseOrder(base);
      plan.moveToKey('2:mp3_96');
      plan.setShuffle(true);
      final first = keysOf(plan);

      // Ugyanaz az alap-sorrend még egyszer (fájlpásztázás, katalógus-újraépítés).
      plan.setBaseOrder(base);
      expect(
        keysOf(plan),
        first,
        reason: 'különben minden pásztázás újrakeverne, és a „következő" ugrálna',
      );
      expect(plan.currentKey, '2:mp3_96');
    });

    test('MEGVÁLTOZOTT alapnál újrakever, de a szóló tétel megmarad', () {
      final plan = MusicQueuePlan(random: Random(5));
      plan.setBaseOrder([for (var id = 1; id <= 5; id++) track(id)]);
      plan.moveToKey('3:mp3_96');
      plan.setShuffle(true);

      plan.setBaseOrder([for (var id = 1; id <= 6; id++) track(id)]);
      expect(plan.tracks.length, 6, reason: 'az új tétel bekerül a sorba');
      expect(plan.currentKey, '3:mp3_96');
      expect(
        plan.tracks.first.key,
        '3:mp3_96',
        reason: 'a szóló tétel az első helyen marad',
      );
    });

    test('keverésnél a szóló tétel kikerülése nem hagy hibás kurzort', () {
      final plan = MusicQueuePlan(random: Random(13));
      plan.setBaseOrder([for (var id = 1; id <= 5; id++) track(id)]);
      plan.moveToKey('4:mp3_96');
      plan.setShuffle(true);
      plan.setBaseOrder([for (var id = 1; id <= 5; id++) track(id)]);
      plan.setBaseOrder([track(1), track(2), track(3), track(5)]);
      expect(plan.currentKey, isNull);
      expect(plan.index, -1);
      expect(plan.tracks.length, 4);
    });
  });

  group('a megjelenítési adat', () {
    test('a hossz az AKTUÁLIS tételre kerül (a zárképernyő tekerősávjához)', () {
      final plan = MusicQueuePlan();
      plan.setBaseOrder([track(1), track(2)]);
      plan.moveToKey('2:mp3_96');
      plan.updateCurrentItem(
        plan.tracks[plan.index].item.copyWith(
          duration: const Duration(minutes: 3, seconds: 20),
        ),
      );
      expect(
        plan.tracks[plan.index].item.duration,
        const Duration(minutes: 3, seconds: 20),
      );
      expect(
        plan.tracks[0].item.duration,
        isNull,
        reason: 'csak a szóló tétel hosszát írjuk be',
      );
    });

    test('a hossz a kurzor nélkül nem tesz kárt', () {
      final plan = MusicQueuePlan();
      plan.setBaseOrder([track(1)]);
      plan.updateCurrentItem(
        track(1).item.copyWith(duration: const Duration(minutes: 1)),
      );
      expect(plan.tracks.single.item.duration, isNull);
    });
  });
}
