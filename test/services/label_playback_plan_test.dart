import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/services/label_playback_plan.dart';

/// A „Megvásárolt zenéim" lejátszójának bizonyítása: ismétlés, keverés,
/// léptetés, óra-felirat és a „folytatás" szabálya.
///
/// MIÉRT EZEK A TESZTEK: a lejátszó hibái **hallhatók** — a keverés kihagyhat
/// egy tételt vagy kétszer adhatja ugyanazt, az ismétlés „beragadhat", a sor
/// végén nem áll meg. Ezek a hibák a felületen nem látszanak, ezért itt mérjük
/// őket, lejátszó és hálózat nélkül.
void main() {
  group('a letöltött tételek kiválasztása', () {
    test('csak a letöltötteket adja vissza, a sor eredeti sorrendjében', () {
      final indices = downloadedIndices(
        ['a', 'b', 'c', 'd'],
        {'d', 'b'},
      );
      expect(indices, [1, 3]);
    });

    test('üres bemenetnél üres a lista (nem dob)', () {
      expect(downloadedIndices(const [], const {}), isEmpty);
      expect(downloadedIndices(const ['a'], const {}), isEmpty);
    });

    test('a sorrend a könyvtár sorrendje marad (nem ABC)', () {
      final indices = downloadedIndices(
        ['z', 'a', 'm'],
        {'z', 'a', 'm'},
      );
      expect(indices, [0, 1, 2]);
    });
  });

  group('keverés', () {
    test('a keverés PERMUTÁCIÓ: minden tétel pontosan egyszer szerepel', () {
      final indices = List<int>.generate(17, (index) => index);
      for (var seed = 0; seed < 50; seed++) {
        final shuffled = shuffledIndices(indices, Random(seed));
        expect(
          shuffled.length,
          indices.length,
          reason: 'a keverés nem veszíthet el tételt (seed=$seed)',
        );
        expect(
          shuffled.toSet(),
          indices.toSet(),
          reason: 'a keverés nem duplázhat (seed=$seed)',
        );
      }
    });

    test('a keverés tényleg kever (17 tételnél nem marad az eredeti sorrend)', () {
      final indices = List<int>.generate(17, (index) => index);
      var changed = 0;
      for (var seed = 0; seed < 20; seed++) {
        if (shuffledIndices(indices, Random(seed)).toString() !=
            indices.toString()) {
          changed += 1;
        }
      }
      expect(changed, greaterThan(15));
    });

    test('a bemenetet nem módosítja (a hívó listája érintetlen)', () {
      final indices = [0, 1, 2, 3];
      shuffledIndices(indices, Random(7));
      expect(indices, [0, 1, 2, 3]);
    });

    test('egyetlen tételnél és üres listánál sincs hiba', () {
      expect(shuffledIndices([5], Random(1)), [5]);
      expect(shuffledIndices(const [], Random(1)), isEmpty);
    });
  });

  group('a lejátszási sorrend', () {
    test('keverés nélkül az eredeti sorrend marad', () {
      final order = playOrderFor(indices: [3, 1, 0], shuffle: false);
      expect(order, [3, 1, 0]);
    });

    test('keverésnél az AKTUÁLIS tétel kerül az első helyre', () {
      final order = playOrderFor(
        indices: [0, 1, 2, 3, 4],
        shuffle: true,
        random: Random(3),
        currentIndex: 3,
      );
      expect(order.first, 3, reason: 'a most hallgatott zene ne szakadjon meg');
      expect(order.length, 5);
      expect(order.toSet(), {0, 1, 2, 3, 4});
      expect(
        order.where((index) => index == 3).length,
        1,
        reason: 'az aktuális tétel ne szerepeljen kétszer',
      );
    });

    test('keverésnél, ha az aktuális nincs a letöltöttek között, nincs kiemelés', () {
      final order = playOrderFor(
        indices: [1, 2],
        shuffle: true,
        random: Random(9),
        currentIndex: 7,
      );
      expect(order.toSet(), {1, 2});
      expect(order.length, 2);
    });

    test('keverés nélkül az aktuális index nem befolyásol semmit', () {
      expect(
        playOrderFor(indices: [2, 0], shuffle: false, currentIndex: 0),
        [2, 0],
      );
    });
  });

  group('léptetés a sorban', () {
    test('a sor végén MEGÁLL, ha nincs ismétlés', () {
      expect(
        stepPlayback(
          cursor: 2,
          length: 3,
          repeat: PlaybackRepeat.none,
          isAutoAdvance: true,
        ),
        -1,
      );
      expect(
        stepPlayback(
          cursor: 2,
          length: 3,
          repeat: PlaybackRepeat.none,
          isAutoAdvance: false,
        ),
        -1,
      );
    });

    test('az egész sor ismétlése körbefordul (kézzel és magától is)', () {
      expect(
        stepPlayback(
          cursor: 2,
          length: 3,
          repeat: PlaybackRepeat.all,
          isAutoAdvance: true,
        ),
        0,
      );
      expect(
        stepPlayback(
          cursor: 2,
          length: 3,
          repeat: PlaybackRepeat.all,
          isAutoAdvance: false,
        ),
        0,
      );
    });

    test('egy szám ismétlése a VÉGÉN önmagát indítja újra', () {
      expect(
        stepPlayback(
          cursor: 1,
          length: 3,
          repeat: PlaybackRepeat.one,
          isAutoAdvance: true,
        ),
        1,
      );
      expect(
        stepPlayback(
          cursor: 0,
          length: 1,
          repeat: PlaybackRepeat.one,
          isAutoAdvance: true,
        ),
        0,
      );
    });

    test('egy szám ismétlése mellett a kézi „következő" TOVÁBBLÉP', () {
      expect(
        stepPlayback(
          cursor: 1,
          length: 3,
          repeat: PlaybackRepeat.one,
          isAutoAdvance: false,
        ),
        2,
        reason: 'különben beragadna egy számba, ha tovább akar lépni',
      );
      expect(
        stepPlayback(
          cursor: 2,
          length: 3,
          repeat: PlaybackRepeat.one,
          isAutoAdvance: false,
        ),
        -1,
        reason: 'a sor végén kézzel sem tekeredik körbe',
      );
    });

    test('a sor elején (nincs kiválasztott tétel) az elsőre lép', () {
      expect(
        stepPlayback(
          cursor: -1,
          length: 4,
          repeat: PlaybackRepeat.none,
          isAutoAdvance: true,
        ),
        0,
      );
    });

    test('üres sornál nincs hova lépni', () {
      expect(
        stepPlayback(
          cursor: 0,
          length: 0,
          repeat: PlaybackRepeat.all,
          isAutoAdvance: true,
        ),
        -1,
      );
    });
  });

  group('visszalépés', () {
    test('az első tételnél nincs előző (körbefordulás nélkül)', () {
      expect(
        previousPlaybackStep(cursor: 0, length: 3, repeat: PlaybackRepeat.none),
        -1,
      );
    });

    test('az egész sor ismétlésénél az elsőről az utolsóra lép', () {
      expect(
        previousPlaybackStep(cursor: 0, length: 3, repeat: PlaybackRepeat.all),
        2,
      );
    });

    test('egy szám ismétlése nem akadálya a visszalépésnek', () {
      expect(
        previousPlaybackStep(cursor: 2, length: 3, repeat: PlaybackRepeat.one),
        1,
      );
      expect(
        previousPlaybackStep(cursor: 0, length: 3, repeat: PlaybackRepeat.one),
        -1,
      );
    });

    test('üres sornál és ismeretlen kurzornál sem dob', () {
      expect(
        previousPlaybackStep(cursor: 0, length: 0, repeat: PlaybackRepeat.all),
        -1,
      );
      expect(
        previousPlaybackStep(cursor: -1, length: 3, repeat: PlaybackRepeat.all),
        0,
      );
    });
  });

  group('ismétlés mód körbejárása', () {
    test('nincs → mind → egy → nincs', () {
      expect(nextPlaybackRepeat(PlaybackRepeat.none), PlaybackRepeat.all);
      expect(nextPlaybackRepeat(PlaybackRepeat.all), PlaybackRepeat.one);
      expect(nextPlaybackRepeat(PlaybackRepeat.one), PlaybackRepeat.none);
    });

    test('minden módhoz van magyar felirat', () {
      for (final repeat in PlaybackRepeat.values) {
        expect(playbackRepeatLabel(repeat).trim(), isNotEmpty);
      }
    });
  });

  group('feliratok', () {
    test('a hely-felirat 1-től számol, és üres, ha nincs tétel', () {
      expect(playbackPositionLabel(0, 17), '1/17');
      expect(playbackPositionLabel(16, 17), '17/17');
      expect(playbackPositionLabel(-1, 17), '');
      expect(playbackPositionLabel(0, 0), '');
      expect(playbackPositionLabel(5, 3), '');
    });

    test('az óra-felirat m:ss, és 0:00-ra kerekít lefelé', () {
      expect(playbackClock(0), '0:00');
      expect(playbackClock(-500), '0:00');
      expect(playbackClock(1000), '0:01');
      expect(playbackClock(65000), '1:05');
      expect(playbackClock(600000), '10:00');
      expect(playbackClock(3599000), '59:59');
    });
  });

  group('a „folytatás ott, ahol abbahagytad" szabálya', () {
    test('az első 5 másodpercben nem ajánlunk folytatást', () {
      expect(worthResuming(0, 200000), isFalse);
      expect(worthResuming(4999, 200000), isFalse);
      expect(worthResuming(5000, 200000), isTrue);
    });

    test('a szám végén (10 másodpercen belül) nem ajánlunk folytatást', () {
      expect(worthResuming(190000, 200000), isFalse);
      expect(worthResuming(189000, 200000), isTrue);
    });

    test('ismeretlen hossznál csak az alsó határ számít', () {
      expect(worthResuming(60000, 0), isTrue);
      expect(worthResuming(1000, 0), isFalse);
    });
  });

  // --- FORRÁS-LINT: a felület tényleg ezt a logikát használja -----------------
  //
  // A tiszta modul önmagában nem elég: ha a képernyő a saját (régi) logikáját
  // használná, a fenti tesztek zölden futnának, a felhasználó viszont nem
  // kapná meg a kért gombokat. Ezért a képernyő forrását is mérjük.
  group('forrás-lint: a lejátszó gombjai és a folyamatjelző', () {
    late String source;

    setUpAll(() {
      source = File('lib/screens/more/my_music_screen.dart').readAsStringSync();
    });

    test('van tekerhető folyamatjelző, és húzás közben a kéz számít', () {
      final body = _functionBody(source, '_buildSeekRow');
      expect(body, contains('Slider('));
      expect(body, contains('_player.seek('));
      expect(
        body,
        contains('_seeking'),
        reason: 'húzás közben a stream nem írhatja felül a sávot',
      );
      expect(body, contains('onChangeEnd:'));
      expect(
        source,
        contains('positionStream'),
        reason: 'a pozíció a lejátszó streamjéből jön',
      );
      expect(
        source,
        contains('durationStream'),
        reason: 'a hossz a lejátszó streamjéből jön (a seek max értéke)',
      );
    });

    test('van stop gomb, és az a szám elejére állít', () {
      final body = _functionBody(source, '_stopPlayback');
      expect(body, contains('_releaseAudio()'));
      expect(body, contains('_memory.clear('));
      expect(
        body,
        contains('Duration.zero'),
        reason: 'a stop a szám elejére állít',
      );
      // ⚠️ A leállítás a `_releaseAudio`-ban van (ott a háttér-értesítés
      // levétele is), ezért azt is mérjük — a stop-gombra önmagában nem elég a
      // hívás megléte.
      final release = _functionBody(source, '_releaseAudio');
      expect(
        release,
        contains('stop()'),
        reason: 'a hangnak tényleg meg kell állnia',
      );
      expect(release, contains('releasePreviewPlayingState.value = false'));
      expect(
        source,
        contains("tooltip: 'Stop (a szám elejére áll)'"),
        reason: 'a gomb a sávban is megjelenik',
      );
    });

    test('van lejátszási lista (playlist) panel', () {
      final body = _functionBody(source, '_showPlaylist');
      expect(body, contains('showModalBottomSheet'));
      expect(body, contains('Lejátszási lista'));
      expect(
        body,
        contains('for (final index in _order)'),
        reason: 'a lista a lejátszási SORRENDET mutatja (keverés is látszik)',
      );
      expect(
        source,
        contains("label: const Text('Lista')"),
        reason: 'a panel a lejátszósávból nyílik',
      );
    });

    test('az ismétlés és a keverés a bar-ban elérhető', () {
      final body = _functionBody(source, '_buildPlayerBar');
      expect(body, contains('_cycleRepeat'));
      expect(body, contains('_toggleShuffle'));
      expect(body, contains('Icons.repeat_one'));
      expect(body, contains('Icons.shuffle'));
      expect(
        source,
        contains('playbackRepeatLabel'),
        reason: 'a gomb megmondja, mit jelent az aktuális mód',
      );
    });

    test('a lapozás a lejátszási sorrendet követi (nem a nyers sort)', () {
      expect(_functionBody(source, '_playNext'), contains('stepPlayback('));
      expect(
        _functionBody(source, '_playNext'),
        contains('_order['),
        reason: 'a kevert sorrendben kell lépni',
      );
      expect(
        _functionBody(source, '_playPrevious'),
        contains('previousPlaybackStep('),
      );
      expect(
        _functionBody(source, '_advance'),
        contains('isAutoAdvance: true'),
        reason: 'a szám végi továbblépés az ismétlést is figyeli',
      );
    });

    test('a „folytatás" csak letöltött tételre és érdemi pozícióra szól', () {
      final loadBody = _functionBody(source, '_loadResumePoint');
      expect(loadBody, contains('_downloaded.contains(point.entryKey)'));
      final saveBody = _functionBody(source, '_saveProgress');
      expect(
        saveBody,
        contains('worthResuming('),
        reason: 'elöl/legvégén nem mentünk folytatható pontot',
      );
      expect(
        loadBody,
        contains('_memory.load('),
        reason: 'az emlékezet fiókonként olvas',
      );
      expect(
        source,
        contains('_buildResumeBanner'),
        reason: 'a felajánlás a felületen is megjelenik',
      );
    });

    test('a pontot nem 200 ms-onként mentjük (nem terheli a lejátszást)', () {
      final body = _functionBody(source, '_saveProgress');
      expect(
        body,
        contains('5000'),
        reason: 'legfeljebb 5 másodpercenként írunk a tárolóba',
      );
      expect(body, contains('if (!force &&'));
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
/// (`{bool force = false}`) kapcsos zárójele különben a metódus törzse helyett
/// találódna meg — ez a hiba 2026-09-20-án három forrás-lintet is „elhasaltatott"
/// látszólag ok nélkül.
String _functionBody(String source, String name) {
  final match = RegExp(
    '\\n\\s*(?!await\\b|unawaited\\b|return\\b|if\\b|while\\b|for\\b|switch\\b|assert\\b)'
    '[A-Za-z_][\\w<>, ?]*\\s${RegExp.escape(name)}\\(',
  ).firstMatch(source);
  expect(match, isNotNull, reason: 'nincs ilyen tag: $name');
  final openParen = source.indexOf('(', match!.start);
  expect(openParen, isNonNegative, reason: '$name paraméterlistája nem található');
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
