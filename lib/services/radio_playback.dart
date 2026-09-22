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
  /// A **szándék** („szóljon a rádió"), nem a pillanatnyi állapot.
  ///
  /// ⚠️ MÉRT TANULSÁG (2026-09-22, YouTube-teszt): a megszakítás kezdetekor a
  /// `just_audio` a maga oldalán is kezeli az eseményt, és **hamarabb lefut**,
  /// mint a mi figyelőnk — ezért mire mi olvassuk, a `_player.playing` már
  /// **hamis** volt, és nem is próbáltunk visszatérni. A szándékot kell követni.
  bool _wantPlaying = false;
  double _volume = 1.0;

  /// A **hangfókusz-események** bekötése — Android-paritás.
  ///
  /// A tulajdonos kérése az Androidnál: *„ha megy a háttérben a rádió és valaki
  /// elindít pl. egy spotifyt, akkor kussoljon be a rádió, ha kikapcsolja a
  /// spotifyt… menjen tovább a rádió"*. Androidon ezt a natív szolgáltatás
  /// intézi; iOS-en eddig **semmi** nem figyelte a megszakításokat.
  ///
  /// ⚠️ KÉT DOLOG, AMITŐL MŰKÖDIK (mérve, 2026-09-22):
  ///  1. a **szándékot** követjük (`_wantPlaying`), nem a pillanatnyi
  ///     `_player.playing`-et — a `just_audio` ugyanis a saját kezelőjével
  ///     hamarabb lefut, és mire mi olvassuk, már szünetel;
  ///  2. a visszatérés **több próbával** megy: az iOS a megszakítás végét
  ///     **előbb jelezheti**, mint hogy a másik app elengedi a sessiont, ilyenkor
  ///     a `setActive(true)` még `false`-t ad.
  ///
  /// ⚠️ Fejhallgató-kihúzás után **nem** folytatjuk (a szándékot töröljük).
  /// A `duck` (pl. navigációs hang) csak lehalkít, majd visszaáll.
  Future<void> _bindSessionEvents() async {
    if (_sessionEventsBound) return;
    _sessionEventsBound = true;
    try {
      final session = await AudioSession.instance;
      session.interruptionEventStream.listen((event) {
        if (event.begin) {
          if (event.type == AudioInterruptionType.duck) {
            unawaited(_player.setVolume(_volume * 0.4));
            return;
          }
          _resumeAfterInterruption = _wantPlaying;
          if (_player.playing) unawaited(_player.pause());
          return;
        }
        if (event.type == AudioInterruptionType.duck) {
          unawaited(_player.setVolume(_volume));
          return;
        }
        final wasWanted = _resumeAfterInterruption;
        _resumeAfterInterruption = false;
        // ⚠️ Szándékosan NEM szűrünk a `type`-ra: az `audio_session` a végét
        // `pause`-ként adja, ha az iOS `shouldResume`-ot jelez, egyébként
        // `unknown`-ként — és a `setActive(true)` úgyis csak akkor sikerül, ha a
        // session valóban szabaddá vált.
        if (wasWanted) unawaited(_resumeWithRetries());
      });
      // Fejhallgató kihúzása: a rendszer jelzi — ilyenkor nem folytatjuk.
      session.becomingNoisyEventStream.listen((_) {
        _resumeAfterInterruption = false;
        _wantPlaying = false;
        if (_player.playing) unawaited(_player.pause());
      });
    } catch (error) {
      debugPrint('rádió: a hangfókusz-figyelés nem köthető be: $error');
    }
  }

  /// Visszatérés a megszakítás után — **több próbával**.
  ///
  /// Az iOS a megszakítás végét előbb jelezheti, mint hogy a másik app elengedi
  /// a sessiont; ilyenkor a `setActive(true)` még `false`, és a lejátszás némán
  /// nem indul. Ezért néhányszor újrapróbáljuk, amíg a szándék él.
  Future<void> _resumeWithRetries() async {
    final url = _url;
    if (url == null || url.isEmpty) return;
    for (var attempt = 0; attempt < 5; attempt++) {
      if (!_wantPlaying) return;
      if (_player.playing) return;
      await play(url);
      if (_player.playing) return;
      await Future<void>.delayed(Duration(milliseconds: 400 + attempt * 400));
    }
    debugPrint('rádió: a megszakítás után nem sikerült visszatérni');
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
    // A SZÁNDÉKOT előre rögzítjük: a megszakítás-figyelő ebből tudja, hogy
    // vissza kell-e térni (a pillanatnyi `playing` nem megbízható).
    _wantPlaying = true;
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
  Future<void> stop() async {
    // A szándék törlése: megszakítás után NE térjen vissza magától.
    _wantPlaying = false;
    _resumeAfterInterruption = false;
    await _player.stop();
  }

  @override
  Future<bool?> isPlaying() async => _player.playing;

  @override
  Future<void> setVolume(double volume) async {
    // ⚠️ A kért hangerőt megjegyezzük: a `duck` (pl. navigációs hang) után
    // EZT állítjuk vissza, nem vakon 1.0-t — különben egy némított rádió
    // magától megszólalna.
    _volume = volume;
    await _player.setVolume(volume);
  }
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
