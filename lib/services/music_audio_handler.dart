import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import 'label_playback_plan.dart';

/// Az app **egyetlen** háttér-lejátszója (a `main`-ben jön létre).
///
/// MIÉRT globális: az `AudioService.init`-et egyszer lehet meghívni, és a
/// képernyő (ami bármikor újraépülhet) ugyanezt a példányt kapja. Ha a
/// háttér-szolgáltatás nem indul el (pl. régi készülék), ez `null` marad, és a
/// lejátszó **a képernyőn belül** ugyanúgy működik — ez a szándékos tartalék.
MusicAudioHandler? _shared;
MusicAudioHandler? get sharedMusicAudioHandler => _shared;

void setSharedMusicAudioHandler(MusicAudioHandler? handler) => _shared = handler;

/// A képernyő innen kéri a lejátszót (`null` = nincs háttér-szolgáltatás).
final musicAudioHandlerProvider = Provider<MusicAudioHandler?>(
  (ref) => sharedMusicAudioHandler,
);

/// A „Megvásárolt zenéim" lejátszójának **háttér-szolgáltatása**.
///
/// A tulajdonos kérése: *„zárképernyő + értesítés-vezérlés"* — vagyis a
/// megvásárolt zene **kikapcsolt képernyőn is szóljon**, és a zárképernyőn (meg a
/// fejhallgató gombjaival) lehessen vezérelni.
///
/// MIÉRT EZ A MEGOLDÁS: az `audio_service` adja a rendszer-szintű médiamunkamenetet
/// (MediaSession) és az értesítést, a `just_audio` pedig a lejátszást — így **nem
/// kell saját Kotlin-szolgáltatást írni** (a rádióé már van, és szándékosan
/// érintetlen marad: azt ne is bántsuk, mert nehezen működik jól).
///
/// NÉGY SZÁNDÉKOS SZABÁLY:
///  1. **A döntés a képernyőé marad.** Ez a szolgáltatás **nem** tudja, mi a
///     letöltött tétel, mi a kevert sorrend, és hol van a sor vége — ezért a
///     „következő" / „előző" / ismétlés / keverés **visszahívásokon** keresztül
///     kérdez vissza a képernyőtől (`onNext`, `onPrevious`, `onRepeatChanged`,
///     `onShuffleChanged`). Egy szabály egy helyen: nem lehet, hogy a
///     zárképernyő mást csinál, mint az appban a gomb.
///  2. **Amit a szolgáltatás maga intéz:** lejátszás, szünet, stop, tekerés — ezek
///     a lejátszón műveletek, nem döntések.
///  3. **Az értesítés csak akkor marad**, ha szól valami: `androidStopForegroundOnPause`
///     (szünetnél elengedi az előtér-státuszt), és a stop **leveszi** az
///     értesítést (`super.stop()`), hogy ne maradjon ott egy halott lejátszó.
///  4. **A rádió hangja nem vész el:** a stop/lezárás visszahíváson keresztül
///     szól a képernyőnek (`onStopped`), amely visszaadja a hangot a rádiónak —
///     ugyanaz a viselkedés, mint eddig.
class MusicAudioHandler extends BaseAudioHandler with SeekHandler {
  MusicAudioHandler() {
    // A lejátszó minden eseménye átfordul a rendszer felé látható állapottá
    // (ebből él az értesítés és a zárképernyő).
    _player.playbackEventStream.map(_toPlaybackState).pipe(playbackState);
  }

  final AudioPlayer _player = AudioPlayer();

  /// A lejátszó a felületnek (a folyamatjelző és a hossz ugyanaz a stream).
  AudioPlayer get player => _player;

  /// A látható tétel (az értesítés címe, előadója, borítója).
  MediaItem? get currentItem => mediaItem.value;

  /// A képernyő visszahívásai (a szolgáltatás sosem dönt helyettük).
  Future<void> Function()? onNext;
  Future<void> Function()? onPrevious;
  Future<void> Function(PlaybackRepeat mode)? onRepeatChanged;
  Future<void> Function(bool shuffle)? onShuffleChanged;

  /// A **rádió** visszakapja a hangot, ha előtte az szólt (a `main`-ben kötjük be,
  /// hogy a szolgáltatás ne függjön a felület fájljaitól).
  Future<void> Function()? onResumeRadio;

  /// Jelezte-e a képernyő, hogy a zene átvette a hangot a rádiótól.
  ///
  /// MIÉRT itt, és nem a képernyőn: a stop a **zárképernyőről** is jöhet, amikor a
  /// képernyő már megszűnt — ilyenkor is vissza kell adni a hangot a rádiónak.
  bool resumeRadioWhenStopped = false;

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  /// Stop: megáll, az értesítést is **leveszi** (nem marad halott lejátszó), és
  /// visszaadja a hangot a rádiónak, ha a zene vette át tőle.
  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
    if (resumeRadioWhenStopped) {
      resumeRadioWhenStopped = false;
      final resume = onResumeRadio;
      if (resume != null) await resume();
    }
  }

  @override
  Future<void> skipToNext() async {
    final callback = onNext;
    if (callback != null) await callback();
  }

  @override
  Future<void> skipToPrevious() async {
    final callback = onPrevious;
    if (callback != null) await callback();
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    // A lejátszó saját ismétlés-mezőjét nem használjuk (a sor végén a MI
    // szabályunk dönt), ezért csak továbbadjuk a képernyőnek.
    final mode = switch (repeatMode) {
      AudioServiceRepeatMode.one => PlaybackRepeat.one,
      AudioServiceRepeatMode.all ||
      AudioServiceRepeatMode.group => PlaybackRepeat.all,
      AudioServiceRepeatMode.none => PlaybackRepeat.none,
    };
    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
    final callback = onRepeatChanged;
    if (callback != null) await callback(mode);
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode != AudioServiceShuffleMode.none;
    playbackState.add(playbackState.value.copyWith(shuffleMode: shuffleMode));
    final callback = onShuffleChanged;
    if (callback != null) await callback(enabled);
  }

  /// A sor közzététele a rendszer felé (az értesítés „sor" nézete és a
  /// következő/előző gombok ehhez igazodnak).
  void publishQueue(List<MediaItem> items, {int index = 0}) {
    queue.add(items);
    if (index >= 0 && index < items.length) {
      mediaItem.add(items[index]);
    } else {
      mediaItem.add(null);
    }
    playbackState.add(
      playbackState.value.copyWith(queueIndex: index < 0 ? null : index),
    );
  }

  /// Az aktuális tétel beállítása (a sáv és az értesítés címe).
  void publishCurrent(MediaItem? item, {int? index}) {
    mediaItem.add(item);
    if (index != null) {
      playbackState.add(
        playbackState.value.copyWith(queueIndex: index < 0 ? null : index),
      );
    }
  }

  PlaybackState _toPlaybackState(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {MediaAction.seek},
      // A kompakt nézetben az előző / play-pause / következő legyen.
      androidCompactActionIndices: const [0, 1, 2],
      processingState: switch (_player.processingState) {
        ProcessingState.idle => AudioProcessingState.idle,
        ProcessingState.loading => AudioProcessingState.loading,
        ProcessingState.buffering => AudioProcessingState.buffering,
        ProcessingState.ready => AudioProcessingState.ready,
        ProcessingState.completed => AudioProcessingState.completed,
      },
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }

  /// A lejátszó erőforrásainak elengedése (a képernyő lezárásakor).
  Future<void> disposePlayer() => _player.dispose();
}
