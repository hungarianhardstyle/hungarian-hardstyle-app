import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A Real Hardstyle FM rádió **natív** viselkedése (Android).
///
/// A tulajdonos jelzései, amelyeket ez a teszt őriz:
///  * *„Rádiót nézzük meg… ha valaki nincs belépve, 5 perc után megszakad…
///    Cél az, hogy folyamatosan menjen a rádió"* → a szolgáltatás **ébren
///    tartja** a készüléket (wake lock + Wi-Fi lock + `setWakeMode`);
///  * *„ha megy a rádió, de valaki elindítja a spotifyt vagy a youtubeot, szól
///    tovább a rádió, közben el kéne hallgatnia"* → hangfókusz kérése;
///  * *„ha megy a háttérben a rádió és valaki elindít pl egy spotifyt, akkor
///    kussoljon be a rádió, ha kikapcsolja a spotifyt, vagy youtubeot, stb,
///    menjen tovább a rádió"* → a fókusz elvesztése **nem** állítja le a
///    szolgáltatást, és a másik app befejezése után **magától folytatjuk**;
///  * *„rádió leáll ha kilépek az appból, ha csak háttérbe teszem megy tovább,
///    ami helyes működés"* → a kilépés (`onTaskRemoved`) **továbbra is** leállít.
///
/// A futásidejű hangzást csak telefonon lehet igazolni (az emulátoron a debug
/// build összeomlik), ezért ez a teszt a **forrást** zárja le: a fenti
/// viselkedés nem tud csendben eltűnni.
void main() {
  late String service;
  late String manifest;

  setUpAll(() {
    service = File(
      'android/app/src/main/kotlin/hu/hungarianhardstyle/app/RadioPlaybackService.kt',
    ).readAsStringSync();
    manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
  });

  group('manifest: a háttérben futó lejátszás feltételei', () {
    test('a szükséges engedélyek megvannak', () {
      for (final permission in const [
        'android.permission.WAKE_LOCK',
        'android.permission.FOREGROUND_SERVICE',
        'android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK',
        'android.permission.ACCESS_WIFI_STATE',
        'android.permission.CHANGE_WIFI_MULTICAST_STATE',
        'android.permission.INTERNET',
      ]) {
        expect(
          manifest,
          contains(permission),
          reason: '$permission nélkül a rádió képernyő-ki mellett megáll',
        );
      }
    });

    test('a szolgáltatás médialejátszó előtér-szolgáltatásként fut', () {
      expect(manifest, contains('RadioPlaybackService'));
      expect(
        manifest,
        contains('android:foregroundServiceType="mediaPlayback"'),
        reason: 'Android 14+ enélkül nem indítható a lejátszás',
      );
    });
  });

  group('folyamatos lejátszás (nem szakad meg képernyő-ki mellett)', () {
    test('a lejátszó és a szolgáltatás is ébren tartja a készüléket', () {
      expect(service, contains('setWakeMode(applicationContext, PowerManager.PARTIAL_WAKE_LOCK)'));
      expect(service, contains('PARTIAL_WAKE_LOCK'));
      expect(service, contains('newWakeLock('));
      expect(service, contains('.acquire()'));
    });

    test('streameléshez a CPU-lock KORLÁTLAN (nem járhat le képernyő-ki alatt)', () {
      final body = _functionBody(service, 'acquireLocks');
      expect(body, contains('lock.acquire()'));
      expect(
        RegExp(r'\.acquire\(\s*\d').hasMatch(body),
        isFalse,
        reason: 'a streamelés lockja nem kaphat lejáratot',
      );
      expect(body, contains('WIFI_MODE_FULL_HIGH_PERF'));
      expect(
        _functionBody(service, 'startPlayer'),
        contains('acquireLocks()'),
        reason: 'minden lejátszás-indításnál biztosítjuk a lockot',
      );
    });

    test('fókusz miatti elhallgatáskor is ébren marad a CPU (de korlátozottan)', () {
      expect(
        _functionBody(service, 'pauseForFocusLoss'),
        contains('acquireFocusWatchLock()'),
        reason: 'különben képernyő-ki mellett az őrkutya nem futna le',
      );
      final body = _functionBody(service, 'acquireFocusWatchLock');
      expect(body, contains('lock.acquire(FOCUS_WATCH_WAKE_LOCK_MS)'));
      expect(
        body,
        contains('wifiLock?.let'),
        reason: 'a Wi-Fi lockot elengedjük, amíg nem streamelünk',
      );
      expect(
        service,
        contains('FOCUS_WATCH_WAKE_LOCK_MS = 20 * 60 * 1_000L'),
        reason: 'a védelem korlátozott ideig tart, hogy ne merítse a telepet',
      );
    });

    test('nagy teljesítményű Wi-Fi lock is van', () {
      expect(service, contains('createWifiLock('));
      expect(service, contains('WIFI_MODE_FULL_HIGH_PERF'));
    });

    test('az újracsatlakozás alatt sem engedjük el a lockot', () {
      final body = _functionBody(service, 'scheduleReconnect');
      expect(body, contains('postDelayed'));
      expect(
        body,
        contains('releaseLocks'),
        reason: 'ha nem kértünk lejátszást, a lockot el kell engedni',
      );
      expect(
        body.indexOf('isPlaybackRequested()'),
        lessThan(body.lastIndexOf('releaseLocks')),
        reason: 'csak leállított rádió esetén szabad elengedni a lockot',
      );
    });

    test('a rendszer által újraindított szolgáltatás folytatja a lejátszást', () {
      expect(service, contains('START_STICKY'));
      expect(service, contains('KEY_URL'), reason: 'az URL is mentődik');
      final body = _functionBody(service, 'onStartCommand');
      expect(
        body,
        contains('isPlaybackRequested()'),
        reason: 'intent nélkül (rendszer-indítás) a mentett állapot dönt',
      );
      expect(body, contains('startPlayer'));
    });
  });

  group('hangfókusz: más app indulásakor elhallgatunk', () {
    test('kérünk fókuszt, és figyeljük a változást', () {
      expect(service, contains('requestAudioFocus('));
      expect(service, contains('AudioManager.AUDIOFOCUS_GAIN'));
      expect(service, contains('OnAudioFocusChangeListener'));
      expect(service, contains('abandonAudioFocus'));
    });

    test('a hangerőt csökkentjük, ha csak halkan szabad szólni (duck)', () {
      expect(service, contains('AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK'));
      expect(service, contains('setVolume(0.2f, 0.2f)'));
    });

    test('a hang elvesztése elhallgattat, de nem állítja le a szolgáltatást', () {
      final body = _functionBody(service, 'pauseForFocusLoss');
      expect(body, contains('releasePlayer'));
      expect(
        body,
        contains('acquireFocusWatchLock'),
        reason: 'a CPU marad ébren, hogy az őrkutya képernyő-ki mellett is fusson',
      );
      expect(
        body,
        isNot(contains('releaseLocks()')),
        reason: 'a lock teljes elengedése képernyő-ki mellett megállítaná a figyelést',
      );
      expect(body, contains('pausedByFocus = permanent'));
      expect(
        body,
        isNot(contains('stopSelf')),
        reason: 'a Spotify befejezése után folytatni kell — nem adjuk fel',
      );
      expect(
        body,
        isNot(contains('putBoolean(KEY_PLAYING, false)')),
        reason: 'a lejátszási szándék megmarad',
      );
      expect(
        body,
        isNot(contains('stopForeground')),
        reason: 'az értesítés maradjon ott, hogy vissza tudjunk térni',
      );
      expect(
        _bodyAfter(service, 'val focusListener'),
        contains('pauseForFocusLoss(permanent = true)'),
        reason: 'a végleges elvesztés külön ág',
      );
      expect(
        _bodyAfter(service, 'val focusListener'),
        contains('pauseForFocusLoss(permanent = false)'),
        reason: 'a hívás/navigáció ideiglenes ág',
      );
    });
  });

  group('folytatás, ha a másik app abbahagyta', () {
    test('figyeljük a rendszer lejátszás-listáját (API 26+)', () {
      expect(service, contains('AudioManager.AudioPlaybackCallback'));
      expect(service, contains('registerAudioPlaybackCallback(watcher'));
      expect(service, contains('unregisterAudioPlaybackCallback(it)'));
      expect(
        _functionBody(service, 'onCreate'),
        contains('Build.VERSION_CODES.O'),
        reason: 'a visszahívás csak API 26-tól létezik',
      );
      expect(
        _functionBody(service, 'onCreate'),
        contains('registerPlaybackWatcher()'),
      );
      expect(
        _functionBody(service, 'onDestroy'),
        contains('unregisterPlaybackWatcher()'),
        reason: 'a le nem mondott visszahívás szivárogna',
      );
    });

    test('a figyelő NEM jön létre a szolgáltatás létrehozásakor', () {
      expect(
        service,
        contains('private var playbackWatcher: AudioManager.AudioPlaybackCallback? = null'),
        reason: 'mezőinicializálóban API 26-os osztály a régi Androidon elhasal',
      );
      expect(
        RegExp(
          r'@RequiresApi\(Build\.VERSION_CODES\.O\)\s*\n\s*private fun registerPlaybackWatcher\(',
        ).hasMatch(service),
        isTrue,
        reason: 'a létrehozás csak a védett úton történhet',
      );
      final body = _functionBody(service, 'registerPlaybackWatcher');
      expect(body, contains('object : AudioManager.AudioPlaybackCallback()'));
      expect(
        body.indexOf('if (playbackWatcher != null) return'),
        lessThan(body.indexOf('object :')),
        reason: 'kétszer ne regisztráljunk',
      );
    });

    test('csak akkor kérünk új fókuszt, ha MÁS app már nem játszik', () {
      final body = _functionBody(service, 'resumeAfterFocusLoss');
      expect(body, contains('isMusicActive'));
      expect(body, contains('if (musicPlaying) return'));
      expect(body, contains('if (!pausedByFocus'));
      expect(
        body,
        contains('MODE_IN_CALL'),
        reason: 'hívás közben a zene-stream nem aktív — a rádió beleszólna',
      );
      expect(body, contains('MODE_IN_COMMUNICATION'));
      expect(
        service,
        isNot(contains('clientUid')),
        reason: 'a getClientUid()/isActive() rendszer-API: nem is fordul le',
      );
    });

    test('ideiglenes elvesztésnél (hívás) nem indul őrkutya', () {
      final body = _functionBody(service, 'pauseForFocusLoss');
      expect(
        body.indexOf('if (!permanent) return'),
        lessThan(body.indexOf('postDelayed(focusWatchdog')),
        reason: 'a hívás alatt nem szabad fókuszt visszakérni',
      );
    });

    test('a döntést a visszahívás ÉS a 2 másodperces őrkutya is hívja', () {
      expect(
        _functionBody(service, 'onPlaybackConfigChanged'),
        contains('resumeAfterFocusLoss()'),
        reason: 'a lista-változás azonnali folytatást ad',
      );
      final watchdog = _functionBody(service, 'run');
      expect(watchdog, contains('resumeAfterFocusLoss()'));
      expect(watchdog, contains('postDelayed'));
      expect(
        _functionBody(service, 'pauseForFocusLoss'),
        contains('postDelayed(focusWatchdog'),
        reason: 'elhallgatáskor indul a figyelés',
      );
      expect(
        _functionBody(service, 'stopPlayer'),
        contains('removeCallbacks(focusWatchdog)'),
        reason: 'leállításkor nem szabad tovább figyelni',
      );
      expect(
        _bodyAfter(service, 'val focusListener'),
        contains('removeCallbacks(focusWatchdog)'),
        reason: 'a rendszer jelezte fókusz-visszakapásnál is leáll a figyelés',
      );
    });

    test('a folytatás valódi: fókusz + lejátszó újraindítása', () {
      final body = _functionBody(service, 'resumeAfterFocusLoss');
      expect(body, contains('requestAudioFocus()'));
      expect(body, contains('startPlayer(url)'));
      expect(
        body,
        contains('pausedByFocus = false'),
        reason: 'különben az őrkutya újra és újra elindítaná',
      );
      expect(
        body,
        contains('runCatching'),
        reason: 'a figyelő nem boríthatja az appot',
      );
    });

    test('a rádió indítása és leállítása rendbe teszi a jelzőt', () {
      expect(_functionBody(service, 'play'), contains('pausedByFocus = false'));
      expect(_functionBody(service, 'stopPlayer'), contains('pausedByFocus = false'));
    });
  });

  group('a kilépés továbbra is leállít (a tulajdonos által igazolt helyes működés)', () {
    test('onTaskRemoved leállítja a lejátszást', () {
      final body = _functionBody(service, 'onTaskRemoved');
      expect(body, contains('stopPlayer()'));
      expect(body, contains('stopSelf()'));
    });

    test('a kliens csatornája változatlan (play/stop/isPlaying/volume)', () {
      final activity = File(
        'android/app/src/main/kotlin/hu/hungarianhardstyle/app/MainActivity.kt',
      ).readAsStringSync();
      for (final method in const ['"play"', '"stop"', '"isPlaying"', '"volume"']) {
        expect(activity, contains(method));
      }
      expect(activity, contains('hu_hs/radio'));
    });
  });
}

/// Kiveszi egy Kotlin-függvény törzsét a nyitó kapcsos zárójel bezárásáig.
String _functionBody(String source, String name) {
  final start = source.indexOf('fun $name(');
  expect(start, isNonNegative, reason: 'nincs ilyen függvény: $name');
  return _bodyAfter(source, 'fun $name(');
}

/// Kiveszi a megadott szövegrész UTÁNI első kapcsos blokk törzsét.
String _bodyAfter(String source, String anchor) {
  final start = source.indexOf(anchor);
  expect(start, isNonNegative, reason: 'nincs ilyen rész: $anchor');
  final open = source.indexOf('{', start);
  expect(open, isNonNegative, reason: '$anchor törzse nem található');
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    final char = source[i];
    if (char == '{') depth++;
    if (char == '}') {
      depth--;
      if (depth == 0) return source.substring(open + 1, i);
    }
  }
  fail('$anchor törzse nem záródik le');
}
