import 'dart:async';

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
/// A `stop()` utáni újraindításhoz újra be kell tölteni a forrást
/// (`ProcessingState.idle` → `load()`), különben a zárképernyő play gombja néma.
class StreamRadioPlayback implements RadioPlayback {
  StreamRadioPlayback({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  String? _url;

  @override
  Future<void> play(String url) async {
    if (_url != url) {
      _url = url;
      await _player.setUrl(url);
    } else if (_player.processingState == ProcessingState.idle) {
      await _player.load();
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
