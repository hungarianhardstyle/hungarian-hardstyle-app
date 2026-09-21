import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A megvásárolt zenék **háttér-lejátszásának** bizonyítása (zárképernyő +
/// értesítés-vezérlés, kikapcsolt képernyőn is).
///
/// MIÉRT FORRÁS-LINT: ez a rész **platform-konfiguráció** (manifest, Activity
/// bázis-osztály, szolgáltatás-indítás) — futásidőben csak egy igazi készüléken
/// látszik, itt viszont minden olyan pont mérhető, ami elrontása **néma** hibát
/// okozna: elmarad a szolgáltatás a manifestből (nincs értesítés), rossz az
/// Activity bázisa (összeomlik az app), vagy a stop nem veszi le az értesítést.
void main() {
  group('Android-manifest: a lejátszó-szolgáltatás és a gombok', () {
    late String manifest;

    setUpAll(() {
      manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
    });

    test('az audio_service szolgáltatása előtér-típussal szerepel', () {
      expect(
        manifest,
        contains('com.ryanheise.audioservice.AudioService'),
        reason: 'enélkül nincs értesítés és nincs zárképernyő',
      );
      expect(
        manifest,
        contains('android.media.browse.MediaBrowserService'),
        reason: 'a médiamunkamenet ezen a szolgáltatáson keresztül kapcsolódik',
      );
      // A `mediaPlayback` típus kötelező Android 14-től az előtér-szolgáltatáshoz.
      final serviceIndex = manifest.indexOf(
        'com.ryanheise.audioservice.AudioService',
      );
      final serviceBlock = manifest.substring(
        serviceIndex,
        manifest.indexOf('</service>', serviceIndex),
      );
      expect(serviceBlock, contains('android:foregroundServiceType="mediaPlayback"'));
      expect(serviceBlock, contains('android:exported="true"'));
    });

    test('a fejhallgató-gombok vevője is be van jelentve', () {
      expect(manifest, contains('MediaButtonReceiver'));
      expect(manifest, contains('android.intent.action.MEDIA_BUTTON'));
    });

    test('a RÁDIÓ szolgáltatása érintetlen (ne törjön el a rádió)', () {
      expect(manifest, contains('.RadioPlaybackService'));
      expect(manifest, contains('android:stopWithTask="true"'));
      expect(manifest, contains('android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK'));
      expect(manifest, contains('android.permission.WAKE_LOCK'));
    });
  });

  group('MainActivity: a médiamunkamenet bázis-osztálya', () {
    late String activity;

    setUpAll(() {
      activity = File(
        'android/app/src/main/kotlin/hu/hungarianhardstyle/app/MainActivity.kt',
      ).readAsStringSync();
    });

    test('az AudioServiceFragmentActivity-ből származik', () {
      expect(activity, contains('class MainActivity : AudioServiceFragmentActivity()'));
      expect(activity, contains('import com.ryanheise.audioservice.AudioServiceFragmentActivity'));
      expect(
        activity,
        isNot(contains('class MainActivity : FlutterFragmentActivity()')),
        reason: 'a régi bázis-osztállyal a médiamunkamenet nem kapcsolódna be',
      );
    });

    test('a fragment-örökség miatt az ujjlenyomat/PIN-es belépés megmarad', () {
      // Az `AudioServiceFragmentActivity` a `FlutterFragmentActivity`-ből
      // származik (ezt a csomag forrása igazolja) — a BiometricPrompt ehhez kell.
      expect(activity, contains('BiometricPrompt'));
      expect(activity, contains('DEVICE_CREDENTIAL'));
    });
  });

  group('indítás és hangfókusz (lib/main.dart)', () {
    late String main;

    setUpAll(() {
      main = File('lib/main.dart').readAsStringSync();
    });

    test('a háttér-lejátszó a runApp ELŐTT indul', () {
      final body = _functionBody(main, 'main');
      final initIndex = body.indexOf('_initializeBackgroundAudio()');
      final runAppIndex = body.indexOf('runApp(');
      expect(initIndex, isNonNegative);
      expect(runAppIndex, isNonNegative);
      expect(
        initIndex < runAppIndex,
        isTrue,
        reason: 'a lejátszó csak utána jön létre, ezért előbb kell indulnia',
      );
    });

    test('a szolgáltatás a saját csatornánkra és helyesen indul', () {
      final body = _functionBody(main, '_initializeBackgroundAudio');
      expect(body, contains('AudioService.init<MusicAudioHandler>'));
      expect(body, contains('hu.hungarianhardstyle.app.music'));
      expect(body, contains('Zenelejátszás'));
      expect(
        body,
        contains('androidStopForegroundOnPause: true'),
        reason: 'szünetnél ne maradjon ott egy álló előtér-szolgáltatás',
      );
      expect(
        body,
        contains('catch'),
        reason: 'ha nem indul el, az app attól még működjön (tartalék)',
      );
    });

    test('a hangfókusz: hívásra szünet, fejhallgató-kihúzásra szünet', () {
      final body = _functionBody(main, '_initializeBackgroundAudio');
      expect(body, contains('AudioSessionConfiguration.music()'));
      expect(body, contains('becomingNoisyEventStream'));
      expect(body, contains('interruptionEventStream'));
      expect(body, contains('AudioInterruptionType.duck'));
      expect(
        body,
        contains('event.type == AudioInterruptionType.pause'),
        reason:
            'csak hívás után folytatjuk magunktól — más zene-apptól nem vesszük '
            'vissza a fókuszt (ugyanaz a szabály, mint a rádiónál)',
      );
    });

    test('a zárképernyőről indított stop is visszaadja a hangot a rádiónak', () {
      final body = _functionBody(main, '_initializeBackgroundAudio');
      expect(body, contains('onResumeRadio'));
      expect(body, contains('resumeRadioPlayback()'));
      expect(body, contains('releasePreviewPlayingState.value = false'));
    });
  });

  group('a háttér-szolgáltatás (music_audio_handler.dart)', () {
    late String handler;

    setUpAll(() {
      handler = File('lib/services/music_audio_handler.dart').readAsStringSync();
    });

    test('a stop leveszi az értesítést és visszaadja a hangot', () {
      final body = _functionBody(handler, 'stop');
      expect(
        body,
        contains('await super.stop()'),
        reason: 'enélkül ott maradna egy halott lejátszó a zárképernyőn',
      );
      expect(body, contains('resumeRadioWhenStopped'));
      expect(body, contains('onResumeRadio'));
    });

    test('a döntéseket a SZOLGÁLTATÁS hozza (nem a képernyő visszahívásai)', () {
      // ⚠️ Ez a 346 utáni javítás lényege: a zárképernyő gombja **néma** volt, és
      // a dal végén **megállt a zene**, mert a döntés a képernyő visszahívásaihoz
      // volt kötve (a `dispose` pedig null-ra állította őket).
      expect(_functionBody(handler, 'skipToNext'), contains('session.next()'));
      expect(
        _functionBody(handler, 'skipToPrevious'),
        contains('session.previous()'),
      );
      expect(
        _functionBody(handler, 'setRepeatMode'),
        contains('session.setRepeat('),
      );
      expect(
        _functionBody(handler, 'setShuffleMode'),
        contains('session.setShuffle('),
      );
      expect(
        handler,
        isNot(contains('onNext')),
        reason: 'nincs többé képernyőhöz kötött döntés-visszahívás',
      );
      expect(
        handler,
        isNot(contains('nextDownloadedIndex')),
        reason: 'a szolgáltatás nem tudhatja, mi van letöltve',
      );
    });

    test('a sor és a dal vége a soré (music_queue_player.dart)', () {
      final player = File(
        'lib/services/music_queue_player.dart',
      ).readAsStringSync();
      final state = _functionBody(player, '_onPlayerState');
      expect(
        state,
        contains('next(isAutoAdvance: true)'),
        reason: 'a dal végén a szolgáltatás lép tovább (nem a képernyő)',
      );
      expect(
        _functionBody(player, 'next'),
        contains('_finishQueue()'),
        reason: 'a sor végén leáll — és a stop visszaadja a hangot a rádiónak',
      );
      expect(
        player,
        contains('_plan.setBaseOrder(base, currentKey: currentKey.value)'),
        reason: 'a sorrendet a képernyő adja (csak ő tudja, mi van letöltve)',
      );
      expect(
        _functionBody(player, 'setBaseOrder'),
        contains('_baseSignature'),
        reason: 'keverésnél változatlan alapnál nem kever újra (nem ugrál)',
      );
    });

    test('a lejátszás/szünet/tekerés viszont a sajátja', () {
      // ⚠️ A `play()` **stop után újratölt** (`ProcessingState.idle`), különben a
      // zárképernyő play gombja némán nem csinálna semmit — ezért nem elég a
      // puszta `_player.play()`.
      final body = _functionBody(handler, 'play');
      expect(body, contains('ProcessingState.idle'));
      expect(body, contains('_player.load()'));
      expect(body, contains('_player.play()'));
      expect(handler, contains('Future<void> pause() => _player.pause();'));
      expect(handler, contains('Future<void> seek(Duration position) => _player.seek(position);'));
    });

    test('az értesítés vezérlői és a tekerés engedélyezve', () {
      expect(handler, contains('MediaControl.skipToPrevious'));
      expect(handler, contains('MediaControl.skipToNext'));
      expect(handler, contains('MediaControl.stop'));
      expect(handler, contains('MediaAction.seek'));
      expect(handler, contains('androidCompactActionIndices'));
    });

    test('a sor és az aktuális tétel közzététele a rendszer felé', () {
      final body = _functionBody(handler, 'publishQueue');
      expect(body, contains('queue.add('));
      expect(body, contains('mediaItem.add('));
      expect(body, contains('queueIndex'));
    });
  });

  group('a képernyő bekötése (my_music_screen.dart)', () {
    late String screen;

    setUpAll(() {
      screen = File('lib/screens/more/my_music_screen.dart').readAsStringSync();
    });

    test('a háttér-szolgáltatást használja, tartalékkal', () {
      expect(screen, contains('musicAudioHandlerProvider'));
      expect(
        screen,
        contains('_handler?.player ??'),
        reason: 'a lejátszó a szolgáltatásé, ha van',
      );
      expect(
        screen,
        contains('_ownedPlayer ??= AudioPlayer()'),
        reason: 'ha nincs szolgáltatás, a képernyőn belül működjön tovább',
      );
    });

    test('a döntések nincsenek a képernyő életciklusához kötve', () {
      // ⚠️ A képernyő `dispose()`-a korábban **null-ra** állította a döntés-
      // visszahívásokat, ezért a zárképernyő gombja néma maradt (a gomb látszott).
      final body = _functionBody(screen, 'initState');
      expect(body, isNot(contains('handler.onNext')));
      expect(body, isNot(contains('handler.onPrevious')));
      expect(
        body,
        contains('session.currentKey.addListener(_onSessionCurrent)'),
        reason: 'a képernyő a szolgáltatás állapotát követi',
      );
      expect(
        _functionBody(screen, 'dispose'),
        isNot(contains('onNext = null')),
        reason: 'a döntések nem a képernyőn élnek',
      );
      expect(_functionBody(screen, '_playNext'), contains('_session.next()'));
      expect(
        _functionBody(screen, '_playPrevious'),
        contains('_session.previous()'),
      );
    });

    test('a lejátszás metaadatot ad a médiamunkamenetnek (cím, előadó, borító)', () {
      final player = File(
        'lib/services/music_queue_player.dart',
      ).readAsStringSync();
      final start = _functionBody(player, 'playAt');
      expect(
        start,
        contains('AudioSource.file('),
        reason: 'a tag nélkül nincs értesítés (a helyi fájl a médiatétel)',
      );
      expect(start, contains('tag: track.item'));
      expect(
        _functionBody(player, '_applyDuration'),
        contains('copyWith(duration: duration)'),
        reason: 'a zárképernyő tekerősávja a MediaItem hosszából dolgozik',
      );
      // A sor közzététele a **szolgáltatásé**: a képernyő elhagyása után is helyes
      // marad a cím, a sor és az aktuális tétel jelölése.
      final handler = File(
        'lib/services/music_audio_handler.dart',
      ).readAsStringSync();
      expect(
        _functionBody(handler, '_publishSession'),
        contains('publishQueue('),
      );
      expect(
        screen,
        isNot(contains('_publishMetadata')),
        reason: 'a metaadatot már nem a képernyő teszi közzé',
      );
      // ⚠️ A `_mediaItemFor` **`=>` alakú**, ezért itt a teljes sorra illesztünk
      // (a törzs-kivágó segéd a `{`-t keresné, és a következő metódus törzsét
      // találná meg).
      expect(screen, contains('MediaItem _mediaItemFor(LabelQueueEntry entry)'));
      expect(screen, contains('album: entry.variantLabel'));
      expect(
        screen,
        contains("artUri: entry.coverUrl.isEmpty ? null : Uri.tryParse(entry.coverUrl)"),
      );
    });

    test('a képernyő elhagyása NEM állítja le a zenét (ez a lényeg)', () {
      final body = _functionBody(screen, 'dispose');
      expect(
        body,
        contains('handler.resumeRadioWhenStopped = _resumeRadioAfterStop'),
        reason: 'a zárképernyőről indított stopnak is vissza kell adnia a hangot',
      );
      expect(
        body,
        contains('if (!handler.player.playing)'),
        reason:
            'csak akkor zárunk le, ha épp nem szól semmi — különben a zene '
            'háttérben folytatódik',
      );
    });

    test('a visszatéréskor a szolgáltatás sora az igazság (nem a régi kijelzés)', () {
      expect(screen, contains('_syncWithBackgroundPlayback'));
      final body = _functionBody(screen, '_syncWithBackgroundPlayback');
      expect(body, contains('_onSessionCurrent()'));
      final current = _functionBody(screen, '_onSessionCurrent');
      expect(
        current,
        contains('_session.currentKey.value'),
        reason: 'a közben (akár a zárképernyőről) léptetett tétel látszik',
      );
      expect(current, contains('_currentIndex = index'));
    });
  });
}

/// Kiveszi egy Dart-metódus törzsét a nyitó kapcsos zárójel bezárásáig.
///
/// ⚠️ KÉT CSAPDA, amit ez a változat kezel (a korábbi másolatok nem):
///  1. a **hívási hely** is illeszkedne (`await _initializeBackgroundAudio()`),
///     ezért a kulcsszavakat kizárjuk a visszatérési típus helyéről;
///  2. a metódus neve utáni **paraméterlistát** át kell ugrani, különben egy
///     néves paraméter kapcsos zárójele lenne a „törzs".
String _functionBody(String source, String name) {
  final match = RegExp(
    '\\n\\s*(?!await\\b|unawaited\\b|return\\b|if\\b|while\\b|for\\b|switch\\b|assert\\b)'
    '[A-Za-z_][\\w<>, ?]*\\s${RegExp.escape(name)}\\(',
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
