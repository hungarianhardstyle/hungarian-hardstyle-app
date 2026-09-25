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

    test('a lejátszási listáról KIVETT tétel kimarad (a fájl megvan)', () {
      // A tulajdonos kérése: *„zenét hogy tud a playlistre rakni/levenni"* —
      // a kivett tétel a készüléken marad, csak nem szól bele a sorba.
      final indices = downloadedIndices(
        ['a', 'b', 'c', 'd'],
        {'a', 'b', 'c', 'd'},
        excluded: {'b', 'd'},
      );
      expect(indices, [0, 2]);
    });

    test('a kivétel csak a letöltöttet érinti (a nem letöltött eleve kimarad)', () {
      expect(
        downloadedIndices(['a', 'b'], {'a'}, excluded: {'b'}),
        [0],
      );
    });

    test('üres kivétellel minden letöltött tétel a listán van', () {
      expect(
        downloadedIndices(['a', 'b'], {'a', 'b'}),
        [0, 1],
      );
    });
  });

  group('a lejátszási lista kézi sorrendje', () {
    // A tulajdonos kérése: *„A lista kézi sorrendje (fel/le mozgatás)"*.
    const keys = ['a', 'b', 'c', 'd'];

    test('kézi sorrend nélkül a könyvtár sorrendje marad', () {
      expect(
        orderedPlaylistIndices(
          keys: keys,
          downloaded: {'a', 'b', 'c', 'd'},
        ),
        [0, 1, 2, 3],
      );
    });

    test('a kézi sorrend elöl megy, a többi utána (könyvtár sorrendben)', () {
      expect(
        orderedPlaylistIndices(
          keys: keys,
          downloaded: {'a', 'b', 'c', 'd'},
          customOrder: ['c', 'a'],
        ),
        [2, 0, 1, 3],
        reason: 'a „c" és „a" elöl, a maradék (b, d) utána',
      );
    });

    test('a frissen letöltött tétel a VÉGÉRE kerül (nem kell felvenni)', () {
      expect(
        orderedPlaylistIndices(
          keys: keys,
          downloaded: {'a', 'b', 'c', 'd'},
          customOrder: ['d', 'c'],
        ),
        [3, 2, 0, 1],
      );
    });

    test('a kivett és a nem letöltött tétel nem hagy lyukat a sorrendben', () {
      expect(
        orderedPlaylistIndices(
          keys: keys,
          downloaded: {'a', 'b', 'c'},
          excluded: {'b'},
          customOrder: ['b', 'c', 'a'],
        ),
        [2, 0],
        reason: 'a kivett „b" kimarad, a „c" és „a" marad a kért sorrendben',
      );
    });

    test('az elavult/duplikált kézi sorrend nem tesz kárt', () {
      expect(
        orderedPlaylistIndices(
          keys: keys,
          downloaded: {'a', 'b'},
          customOrder: ['nincs-ilyen', 'b', 'b', 'a'],
        ),
        [1, 0],
      );
    });

    test('ismétlődő kulcs a bemenetben sem duplázódik', () {
      expect(
        orderedPlaylistIndices(
          keys: ['a', 'a', 'b'],
          downloaded: {'a', 'b'},
        ),
        [0, 2],
      );
    });

    test('22 tételből 15 letöltött → 15 elemű sorrend (a „1/1" nem fordulhat elő)', () {
      // ⚠️ ÉLES HIBA: a sáv „1/1 · 15 letöltve" volt, miközben 22 tétel és 15
      // letöltés létezett. A sorrendnek **minden** letöltött, ki nem vett tételt
      // tartalmaznia kell — ez az invariáns.
      final keys = [for (var i = 0; i < 22; i++) '10$i:mp3_96'];
      final downloaded = {for (var i = 0; i < 15; i++) '10$i:mp3_96'};
      final order = orderedPlaylistIndices(keys: keys, downloaded: downloaded);
      expect(order.length, 15);
      expect(
        order.length,
        greaterThan(1),
        reason: 'egy elemű sorrend 15 letöltött tételnél hiba, nem állapot',
      );
    });
  });

  group('mozgatás a listában', () {
    test('felfelé és lefelé is mozgat', () {
      expect(moveInOrder(['a', 'b', 'c'], 1, -1), ['b', 'a', 'c']);
      expect(moveInOrder(['a', 'b', 'c'], 1, 1), ['a', 'c', 'b']);
    });

    test('a széleken nem mozdul (nincs körbefordulás)', () {
      expect(moveInOrder(['a', 'b', 'c'], 0, -1), ['a', 'b', 'c']);
      expect(moveInOrder(['a', 'b', 'c'], 2, 1), ['a', 'b', 'c']);
    });

    test('a bemenetet nem módosítja', () {
      final order = ['a', 'b', 'c'];
      moveInOrder(order, 0, 1);
      expect(order, ['a', 'b', 'c']);
    });

    test('érvénytelen indexre nem dob', () {
      expect(moveInOrder(['a'], 5, -1), ['a']);
      expect(moveInOrder(const [], 0, 1), isEmpty);
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

  group('a „lejátszás" gomb eldöntése', () {
    test('nincs betöltött forrás → újra kell tölteni', () {
      expect(needsSourceReload(loadedKey: null, wantedKey: '305:mp3_96'), isTrue);
    });

    test('MÁS tétel van betöltve → újra kell tölteni (nem a rosszat indítjuk)', () {
      expect(
        needsSourceReload(loadedKey: '200:mp3_128', wantedKey: '305:mp3_96'),
        isTrue,
      );
    });

    test('ugyanaz a tétel van betöltve → elég a play', () {
      expect(
        needsSourceReload(loadedKey: '305:mp3_96', wantedKey: '305:mp3_96'),
        isFalse,
      );
    });
  });

  // --- FORRÁS-LINT: a lejátszó állapotgépe (a 345 utáni hibák) --------------
  group('forrás-lint: a lejátszó állapotgépe', () {
    late String source;
    late String player;

    setUpAll(() {
      // ⚠️ A **kommenteket kivesszük**: a javítások indoklása szándékosan
      // tartalmazza a régi (hibás) mintát, és a nyers szövegkeresés ettől
      // hamisan piros lenne.
      String stripComments(String path) => File(path)
          .readAsStringSync()
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
      source = stripComments('lib/screens/more/my_music_screen.dart');
      // A **döntés és a végrehajtás** a szolgáltatásban van (a képernyő elhagyása
      // után is működnie kell), ezért azt a fájlt is mérjük.
      player = stripComments('lib/services/music_queue_player.dart');
    });

    test('sikertelen indításnál a hang visszakerül a rádióhoz', () {
      // ⚠️ ÉLES HIBA: ha a rádiót már leállítottuk, és a lejátszás elhalt, a
      // `releasePreviewPlayingState` igaz maradt → a rádió gombja némán
      // működésképtelen lett, az app „nem szólt".
      // A hibaág azóta a **soré** (a szolgáltatásban), mert a képernyő elhagyása
      // után is le kell állnia a lejátszásnak és vissza kell adni a hangot.
      final catchBody = _functionBody(player, 'playAt');
      expect(
        catchBody,
        contains('onStopRequested'),
        reason: 'a sor jelzi a házigazdának, hogy álljon le',
      );
      expect(catchBody, contains('MusicQueueStopReason.failed'));
      expect(
        catchBody,
        contains('playbackErrorMessage('),
        reason: 'a felületre magyar mondat megy, a technikai ok a naplóba',
      );
      expect(
        catchBody,
        contains('_plan.moveToKey(previousKey)'),
        reason: 'a kijelölés nem marad „ez szól" állapotban',
      );
      final release = _functionBody(source, '_releaseAudio');
      expect(release, contains('releasePreviewPlayingState.value = false'));
      final handler = File(
        'lib/services/music_audio_handler.dart',
      ).readAsStringSync();
      // ⚠️ A `_onQueueStopRequested` **`=>` alakú**, ezért a teljes sorra
      // illesztünk (a törzs-kivágó a következő metódus `{`-jét találná meg).
      expect(
        handler,
        contains('_onQueueStopRequested(MusicQueueStopReason reason) => stop();'),
        reason: 'a szolgáltatás a stopnál visszaadja a hangot a rádiónak',
      );
    });

    test('a pásztázás nem használ elavult pillanatképet', () {
      final body = _functionBody(source, '_scanDownloads');
      expect(
        body,
        contains('final queueSignature = _queueSignature;'),
        reason: 'a pásztázás elején mentjük a sor lenyomatát',
      );
      expect(
        body,
        contains('queueSignature != _queueSignature'),
        reason: 'ha közben a sor kicserélődött, az eredményt eldobjuk',
      );
    });

    test('a kijelzés a szolgáltatás sorát követi (nincs külön szinkron)', () {
      // A sor a szolgáltatásé: a pásztázás **átadja** neki az alap-sorrendet, a
      // kirajzolt `_order` pedig az ő sorából épül — így nincs két igazság,
      // amiért „vissza kellene kapcsolni" a kijelzést.
      final body = _functionBody(source, '_scanDownloads');
      expect(
        body,
        contains('_pushBaseOrder('),
        reason: 'a pásztázás adja át a szolgáltatásnak az alap-sorrendet',
      );
      final tracks = _functionBody(source, '_onSessionTracks');
      expect(tracks, contains('_session.tracks.value'));
      expect(
        tracks,
        contains('_order = order;'),
        reason: 'a kirajzolt sorrend a szolgáltatás sorából épül',
      );
      final current = _functionBody(source, '_onSessionCurrent');
      expect(
        current,
        contains('_session.currentKey.value'),
        reason: 'az aktuális tétel is onnan jön (a zárképernyőn is léptethető)',
      );
    });

    test('a léptetés a szolgáltatásban van (a képernyő csak továbbadja)', () {
      expect(_functionBody(player, 'next'), contains('stepPlayback('));
      expect(
        _functionBody(player, 'previous'),
        contains('previousPlaybackStep('),
      );
      expect(_functionBody(source, '_playNext'), contains('_session.next()'));
      expect(
        _functionBody(source, '_playPrevious'),
        contains('_session.previous()'),
      );
      expect(
        source,
        isNot(contains('_advance()')),
        reason: 'a dal végi továbblépés is a szolgáltatásé, nem a képernyőé',
      );
    });

    test('a lejátszás gomb a BETÖLTÖTT tétel azonosítóját is nézi', () {
      final body = _functionBody(player, 'toggle');
      expect(body, contains('needsSourceReload('));
      expect(body, contains('_loadedKey'));
      expect(
        body,
        contains('ProcessingState.idle'),
        reason: 'stop után a play önmagában nem szólal meg',
      );
      expect(
        _functionBody(source, '_togglePlay'),
        contains('session.toggle('),
        reason: 'a gomb döntése is a szolgáltatásé',
      );
    });

    test('a kétszeres indítás kapuja nem dobja el a koppintást', () {
      final body = _functionBody(player, 'playAt');
      expect(body, contains('_pendingIndex = index;'));
      expect(
        body,
        contains('unawaited(playAt(pending))'),
        reason: 'a közben jött kérés a mostani indítás után elindul',
      );
    });

    test('a stop-jelzők a leállítás UTÁN állnak be', () {
      final body = _functionBody(source, '_releaseAudio');
      final stopIndex = body.indexOf('await handler.stop()');
      final flagIndex = body.indexOf('_resumeRadioAfterStop = false');
      expect(stopIndex, isNonNegative);
      expect(flagIndex, isNonNegative);
      expect(
        stopIndex < flagIndex,
        isTrue,
        reason: 'ha a stop hibázik, a „zene szól" jelzés ne vesszen el',
      );
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
        contains("tooltip: tr(context, 'Stop (a szám elejére áll)')"),
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
        contains("label: const AppText('Lista')"),
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
      // A lépés a **szolgáltatásban** dől el (a tiszta `stepPlayback` szabállyal),
      // a képernyő gombjai pedig ezt adják tovább — ezért a zárképernyő gombja
      // akkor is ugyanezt teszi, ha a képernyő nincs nyitva.
      final player = File(
        'lib/services/music_queue_player.dart',
      ).readAsStringSync();
      expect(_functionBody(player, 'next'), contains('stepPlayback('));
      expect(
        _functionBody(player, 'previous'),
        contains('previousPlaybackStep('),
      );
      final state = _functionBody(player, '_onPlayerState');
      expect(state, contains('ProcessingState.completed'));
      expect(
        state,
        contains('isAutoAdvance: true'),
        reason: 'a szám végi továbblépés az ismétlést is figyeli',
      );
      expect(_functionBody(source, '_playNext'), contains('_session.next()'));
      expect(
        _functionBody(source, '_playPrevious'),
        contains('_session.previous()'),
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

    test('a lejátszási listáról ki lehet venni és vissza lehet tenni', () {
      // A tétel sorában ott a lista-gomb, és a döntés a fiókonkénti tárolóba megy.
      expect(source, contains('_togglePlaylistMembership'));
      expect(source, contains('Icons.playlist_remove'));
      expect(source, contains('Icons.playlist_add'));
      expect(
        source,
        contains("'Kivétel a lejátszási listából (a fájl megmarad)'"),
        reason: 'a gomb megmondja, hogy a fájl nem törlődik',
      );
      final body = _functionBody(source, '_togglePlaylistMembership');
      expect(body, contains('_excludedFromPlaylist'));
      expect(
        body,
        contains('_playlist.save('),
        reason: 'a döntés fiókonként megmarad',
      );
      expect(
        body,
        isNot(contains('_downloads.delete(')),
        reason: 'a kivétel nem törli a fájlt — az a külön kuka gomb',
      );
    });

    test('a kivett tétel kimarad a sorrendből, és a lista is frissül', () {
      expect(
        _functionBody(source, '_pushBaseOrder'),
        contains('excluded: _excludedFromPlaylist'),
        reason: 'a lapozás is átugorja a kivett tételt',
      );
      expect(
        source,
        contains('unawaited(_loadPlaylistMembership())'),
        reason: 'megnyitáskor betöltjük a fiók kivételeit',
      );
      final sheet = _functionBody(source, '_showPlaylist');
      expect(
        sheet,
        contains('StatefulBuilder'),
        reason: 'a kivétel után a panel magától frissül',
      );
      expect(sheet, contains('kivéve a listából'));
    });

    test('az épp szóló tétel kivétele megállítja a lejátszást', () {
      final body = _functionBody(source, '_togglePlaylistMembership');
      expect(body, contains('stopCurrent'));
      expect(
        body,
        contains('await _releaseAudio()'),
        reason: 'ne szóljon tovább olyan tétel, ami már nincs a listán',
      );
    });

    test('a listát KÉZZEL lehet rendezni (fel/le), és megmarad', () {
      // A tulajdonos kérése: *„A lista kézi sorrendje (fel/le mozgatás)"*.
      final sheet = _functionBody(source, '_showPlaylist');
      expect(sheet, contains("tooltip: tr(context, 'Feljebb')"));
      expect(sheet, contains("tooltip: tr(context, 'Lejjebb')"));
      expect(sheet, contains('Icons.keyboard_arrow_up'));
      expect(sheet, contains('Icons.keyboard_arrow_down'));
      expect(sheet, contains('_movePlaylistEntry'));
      final body = _functionBody(source, '_movePlaylistEntry');
      expect(body, contains('moveInOrder('));
      expect(
        body,
        contains('_playlist.saveOrder('),
        reason: 'a sorrend fiókonként megmarad',
      );
      expect(
        _functionBody(source, '_pushBaseOrder'),
        contains('customOrder: _playlistOrder'),
        reason: 'a lapozás a kézi sorrendet követi',
      );
      expect(
        source,
        contains('await _playlist.loadOrder('),
        reason: 'megnyitáskor betöltjük a mentett sorrendet',
      );
    });

    test('keverés közben a sorrend nem szerkeszthető (és ezt meg is mondjuk)', () {
      final sheet = _functionBody(source, '_showPlaylist');
      expect(
        sheet,
        contains('position == 0 || _shuffle'),
        reason: 'keverésnél a nyilak le vannak tiltva',
      );
      expect(sheet, contains('Keverés közben a sorrend nem szerkeszthető'));
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
