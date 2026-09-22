import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

/// A rádió lejátszása — platformonként **más**, de egy szerződéssel.
///
/// MIÉRT KELL (mérve, 2026-09-22): a rádió eddig **kizárólag** natív Android
/// szolgáltatáson ment (`MethodChannel('hu_hs/radio')` →
/// `RadioPlaybackService.kt`). iOS-en nem volt mögötte semmi, ezért **minden**
/// hívás `MissingPluginException`-be futott — amit a hívók `try/catch`-e
/// **elnémított**. A tulajdonos jelzése szerint a rádió *„egyáltalán nem megy"*:
/// pontosan az a néma hiba-osztály, amit a projekt máshol is üldöz (a lejátszó
/// „némasága", a `free_link` feloldás, az App Check).
///
/// ⚠️ **Az Android útja bitre változatlan:** ugyanaz a csatorna, ugyanazok a
/// metódusnevek (`play` / `stop` / `isPlaying` / `volume`), ugyanabban a
/// sorrendben. Az iOS a streamet **közvetlenül** játssza le `just_audio`-val
/// (a stream `audio/mpeg`, 192 kbps — ezt az iOS `AVPlayer` eljátssza).
abstract class RadioPlayback {
  Future<void> play(String url);
  Future<void> stop();

  /// ⚠️ **Nullázható**, hogy az Android út bitre ugyanaz maradjon: a csatorna
  /// `null`-t is adhat (nincs válasz), és a hívók ilyenkor a
  /// `radioPlayingState` notifierre esnek vissza — nem pedig `false`-ra.
  Future<bool?> isPlaying();

  Future<void> setVolume(double volume);
}

/// Android: a meglévő natív előtér-szolgáltatás.
class AndroidRadioPlayback implements RadioPlayback {
  const AndroidRadioPlayback();

  static const MethodChannel methodChannel = MethodChannel('hu_hs/radio');

  @override
  Future<void> play(String url) => methodChannel.invokeMethod<void>('play', url);

  @override
  Future<void> stop() => methodChannel.invokeMethod<void>('stop');

  @override
  Future<bool?> isPlaying() =>
      methodChannel.invokeMethod<bool>('isPlaying');

  @override
  Future<void> setVolume(double volume) =>
      methodChannel.invokeMethod<void>('volume', volume);
}

/// iOS (és minden nem-Android): `just_audio` a streamre.
///
/// ⚠️ A stream **végtelen**, ezért a `play()` future-je soha nem fejeződik be —
/// ugyanaz a minta, mint az előzetes lejátszónál (`unawaited(_player.play())`).
class StreamRadioPlayback implements RadioPlayback {
  StreamRadioPlayback({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  String? _url;
  bool _sessionEventsBound = false;
  bool _resumeAfterInterruption = false;

  /// A **hangfókusz-események** bekötése — Android-paritás.
  ///
  /// A tulajdonos kérése az Androidnál: *„ha megy a háttérben a rádió és valaki
  /// elindít pl. egy spotifyt, akkor kussoljon be a rádió, ha kikapcsolja a
  /// spotifyt… menjen tovább a rádió"*. Androidon ezt a natív szolgáltatás
  /// intézi; iOS-en eddig **semmi** nem figyelte a megszakításokat, ezért egy
  /// hívás vagy másik zene-app után a rádió **némán elhallgatott** (a session
  /// elveszett, és a `just_audio` nem jelzi — lásd `_activateSession`).
  ///
  /// ⚠️ Csak **`pause` típusú** megszakítás után folytatjuk magunktól: egy másik
  /// zene-apptól nem vesszük vissza a fókuszt. Ugyanaz a szabály, mint a
  /// zenénél (`main.dart`).
  Future<void> _bindSessionEvents() async {
    if (_sessionEventsBound) return;
    _sessionEventsBound = true;
    try {
      final session = await AudioSession.instance;
      session.interruptionEventStream.listen((event) {
        if (event.begin) {
          _resumeAfterInterruption = _player.playing;
          if (_player.playing) unawaited(_player.pause());
          return;
        }
        final wasPlaying = _resumeAfterInterruption;
        _resumeAfterInterruption = false;
        if (!wasPlaying) return;
        if (event.type != AudioInterruptionType.pause &&
            event.type != AudioInterruptionType.unknown) {
          return;
        }
        final url = _url;
        if (url == null || url.isEmpty) return;
        unawaited(play(url));
      });
      // Fejhallgató kihúzása: a rendszer jelzi — ilyenkor nem folytatjuk.
      session.becomingNoisyEventStream.listen((_) {
        _resumeAfterInterruption = false;
        if (_player.playing) unawaited(_player.pause());
      });
    } catch (error) {
      debugPrint('rádió: a hangfókusz-figyelés nem köthető be: $error');
    }
  }

  /// A hang-session visszaszerzése — **iOS-en ez a lényeg.**
  ///
  /// ⚠️ MÉRT GYÖKÉR (2026-09-22, `just_audio-0.10.6`, `just_audio.dart`
  /// 1097–1120. sor): a `play()` a `AudioSession.setActive(true)` **sikerétől**
  /// függ, és ha az `false`, akkor a lejátszás **kivétel nélkül, némán** nem
  /// indul el — csak `playing = false` lesz. A `_setPlatformActive` hibáit is
  /// elnyeli (`catchError((e) async => null)`). A projekt a sessiont csak
  /// **induláskor** konfigurálja (`main.dart`), az `setActive` viszont
  /// **tranziens**: a leállított előzetes/zene után elveszik.
  ///
  /// Ez volt a tünet oka: a rádió elindult, az előzetes elhallgattatta, majd
  /// **nem indult újra** — és semmi nem jelezte, miért.
  ///
  /// @returns true, ha a session aktív.
  Future<bool> _activateSession() async {
    try {
      final session = await AudioSession.instance;
      return await session.setActive(true);
    } catch (error) {
      debugPrint('rádió: a hang-session aktiválása hibára futott: $error');
      return false;
    }
  }

  @override
  Future<void> play(String url) async {
    await _bindSessionEvents();
    // A sessiont **a lejátszás előtt** szerezzük vissza; ha elsőre nem megy,
    // rövid várakozás után még egyszer (a másik lejátszó épp tehette tönkre).
    if (!await _activateSession()) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!await _activateSession()) {
        debugPrint(
          'rádió: a hang-session nem aktiválható — a lejátszás néma maradna',
        );
      }
    }
    // ⚠️ A `stop()` utáni újraindításhoz FRISS forrás kell (`setUrl`), nem
    // `load()`: a live streamet az iOS `AVPlayer` a leállítás után így veszi
    // újra, és így az élő adás szélére csatlakozik vissza.
    if (_url != url || _player.processingState == ProcessingState.idle) {
      _url = url;
      await _player.setUrl(url);
    }
    unawaited(_player.play());
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<bool?> isPlaying() async => _player.playing;

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);
}

/// A platform-döntés **tiszta** függvénye — instance és plugin nélkül mérhető.
///
/// ⚠️ Csak az **Android** használja a natív előtér-szolgáltatást; minden más
/// platform a `just_audio`-s útra esik. Ez szándékos: egy új platform így nem a
/// **néma csatornára** kerül, ami pont ezt a hibát okozta.
bool radioUsesNativeService(TargetPlatform platform) =>
    platform == TargetPlatform.android;

/// A platform-döntés **bekötése** (a tiszta szabály fenti, ez csak leképezés).
RadioPlayback radioPlaybackFor(TargetPlatform platform) =>
    radioUsesNativeService(platform)
        ? androidRadioPlayback
        : streamRadioPlayback;

const RadioPlayback androidRadioPlayback = AndroidRadioPlayback();
final RadioPlayback streamRadioPlayback = StreamRadioPlayback();

/// Az aktuális platform lejátszója.
RadioPlayback get radioPlayback => radioPlaybackFor(defaultTargetPlatform);
