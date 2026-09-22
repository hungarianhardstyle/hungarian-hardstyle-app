import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hungarian_hardstyle_app/services/radio_playback.dart';

/// **A rádió lejátszása iOS-en — a néma hiba őre.**
///
/// A tulajdonos jelzése (2026-09-22, a telepített iOS-buildben): *„Rádió nem megy
/// egyáltalán"*.
///
/// A gyökér **platform-különbség**: a rádió eddig **kizárólag** natív Android
/// szolgáltatáson ment (`MethodChannel('hu_hs/radio')` →
/// `RadioPlaybackService.kt`). iOS-en nem volt mögötte semmi, ezért minden hívás
/// `MissingPluginException`-be futott — amit a hívók `try/catch`-e **elnémított**,
/// így a felület sem jelzett semmit. Pontosan az a néma hiba-osztály, amit ez a
/// projekt máshol is üldöz.
///
/// ⚠️ **Amit ez a teszt NEM tud:** a tényleges hangzást (`just_audio` + `AVPlayer`
/// a streamen). Azt csak telefonon lehet igazolni — a forrást viszont igen, hogy
/// a viselkedés ne tudjon csendben eltűnni.
void main() {
  group('a platform-döntés tiszta szabálya', () {
    test('Androidon a natív előtér-szolgáltatás megy', () {
      expect(radioUsesNativeService(TargetPlatform.android), isTrue);
    });

    test('iOS-en NEM a natív szolgáltatás megy (ez volt a hiba)', () {
      expect(radioUsesNativeService(TargetPlatform.iOS), isFalse,
          reason: 'iOS-en nincs `RadioPlaybackService.kt` — a csatorna néma');
    });

    test('minden más platform is a stream-útra esik (nem a néma csatornára)', () {
      for (final platform in const [
        TargetPlatform.iOS,
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      ]) {
        expect(radioUsesNativeService(platform), isFalse, reason: '$platform');
      }
    });
  });

  group('forrás-lint: a bekötés nem csúszhat el', () {
    late String service;
    late String bar;

    setUpAll(() {
      service = _read('lib/services/radio_playback.dart');
      bar = _read('lib/widgets/radio_player_bar.dart');
    });

    test('az Android metódusnevei és csatornája bitre ugyanazok', () {
      expect(service, contains("MethodChannel('hu_hs/radio')"),
          reason: 'az Android natív oldala ehhez a névhez kötött');
      for (final method in ["'play'", "'stop'", "'isPlaying'", "'volume'"]) {
        expect(service, contains(method),
            reason: '$method nélkül az Android rádió elhallgat');
      }
      // ⚠️ A `play` a stream URL-t is átadja — a natív oldal ezt várja.
      expect(service, contains("invokeMethod<void>('play', url)"));
    });

    test('az iOS-út valódi lejátszó, és kezeli a stop utáni újraindítást', () {
      expect(service, contains('AudioPlayer('));
      expect(service, contains('ProcessingState.idle'),
          reason: 'a stop utáni play különben néma marad (friss forrás kell)');
      expect(service, contains('unawaited(_player.play())'),
          reason: 'a stream végtelen, a play() future soha nem fejeződik be');
    });

    test('az iOS-út VISSZASZERZI a hang-sessiont (ez volt a néma hiba)', () {
      // ⚠️ MÉRT GYÖKÉR (2026-09-22): a `just_audio` `play()`-je a
      // `AudioSession.setActive(true)` sikerétől függ, és ha az `false`, akkor
      // **kivétel nélkül, némán** nem indul el a lejátszás. A projekt a
      // sessiont csak induláskor konfigurálja, az `setActive` viszont tranziens:
      // a leállított előzetes/zene után elveszik — ezért nem indult újra a rádió.
      expect(service, contains("import 'package:audio_session/audio_session.dart';"));
      expect(service, contains('AudioSession.instance'));
      expect(service, contains('session.setActive(true)'));
      expect(service, contains('_activateSession()'),
          reason: 'a play() előtt vissza kell szerezni a sessiont');
      // A visszaszerzés a lejátszás ELŐTT legyen a kódban.
      expect(service.indexOf('await _activateSession()'),
          lessThan(service.indexOf('await _player.setUrl(url)')));
    });

    test('a hangfókusz-megszakítás is bekötött (Android-paritás)', () {
      // Androidon a natív szolgáltatás intézi: másik zene-app/hívás esetén
      // elhallgat, majd magától visszatér. iOS-en ezt eddig SEMMI nem figyelte.
      expect(service, contains('interruptionEventStream'));
      expect(service, contains('becomingNoisyEventStream'));
      expect(service, contains('AudioInterruptionType.pause'),
          reason: 'csak pause típusú megszakítás után folytatjuk magunktól — '
              'egy másik zene-apptól nem vesszük vissza a fókusz');
      // Fejhallgató-kihúzás után NEM folytatjuk.
      expect(service.contains('_resumeAfterInterruption = false;\n        if (_player.playing)'),
          isTrue,
          reason: 'a becomingNoisy ág törölje a folytatás szándékát');
    });

    test('a widget a platform-rétegen megy át, nem nyúl a csatornához', () {
      expect(bar, isNot(contains('MethodChannel')),
          reason: 'a widget ne tudjon platformot választani — az egy helyen van');
      expect(bar, contains('radioPlayback.'),
          reason: 'a hívások a közös szerződésen menjenek');
      for (final call in const [
        'radioPlayback.stop()',
        'radioPlayback.play(',
        'radioPlayback.isPlaying()',
        'radioPlayback.setVolume(',
      ]) {
        expect(bar, contains(call), reason: '$call hiányzik');
      }
    });

    test('a hívók (előzetes lejátszó) szerződése változatlan', () {
      final preview = _read('lib/widgets/release_preview_player.dart');
      expect(preview, contains('isRadioPlaybackActive()'));
      expect(preview, contains('stopRadioPlayback()'));
      expect(preview, contains('resumeRadioPlayback()'));
    });
  });
}

String _read(String path) =>
    File(path).readAsStringSync().replaceAll('\r\n', '\n');
