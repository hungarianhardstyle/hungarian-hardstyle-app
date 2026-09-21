import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import 'label_playback_plan.dart';
import 'music_queue_player.dart';

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
///  1. **A sor a szolgáltatásé** ([MusicQueuePlayer]): a „következő" / „előző" /
///     ismétlés / keverés és a **dal végi** továbblépés itt dől el. Ez azért
///     fontos, mert korábban ezek a **képernyő visszahívásai** voltak: a képernyő
///     elhagyása után a zárképernyő gombja **néma** maradt, a dal végén pedig
///     **megállt a zene**. A döntés továbbra is egy helyen van, a tiszta
///     `label_playback_plan.dart`-ban — csak már nem függ a felülettől.
///  2. **Amit a szolgáltatás maga intéz:** lejátszás, szünet, stop, tekerés — ezek
///     a lejátszón műveletek, nem döntések. A sorrendet a képernyő adja át
///     (`session.setBaseOrder`), mert csak ő tudja, mi van **letöltve**.
///  3. **Az értesítés csak akkor marad**, ha szól valami: `androidStopForegroundOnPause`
///     (szünetnél elengedi az előtér-státuszt), és a stop **leveszi** az
///     értesítést (`super.stop()`), hogy ne maradjon ott egy halott lejátszó.
///  4. **A rádió hangja nem vész el:** a stop — akár a zárképernyőről jött —
///     visszaadja a hangot a rádiónak (`resumeRadioWhenStopped` + `onResumeRadio`),
///     és ugyanez történik a sor természetes végén meg egy indítási hibánál is.
class MusicAudioHandler extends BaseAudioHandler with SeekHandler {
  MusicAudioHandler() {
    // ⚠️ NEM `.pipe(playbackState)`!
    //
    // A `Stream.pipe(consumer)` a `consumer.addStream(...)`-et hívja, a
    // `playbackState` viszont egy **rxdart `BehaviorSubject`** — az `addStream`
    // pedig **egyszer s mindenkorra** letiltja az `add()`-ot, és csak akkor
    // engedi el, ha a forrás lezárul. A lejátszó eseménystreamje **soha nem
    // zárul le**, ezért minden további `playbackState.add(...)` dobott:
    //
    //     You cannot add items while items are being added from addStream
    //
    // Élesben pontosan ez volt a hiba a „Megvásárolt zenéim" képernyőn: a
    // metaadatok közzététele dobott, így a zene **el sem indult**. A javítás a
    // kézi `listen` + `add` (lásd `test/services/music_audio_handler_pipe_test.dart`).
    // ⚠️ A **sor előbb** jön létre, mint a lejátszó-eseményekre való feliratkozás:
    // a `_toPlaybackState` ugyanis a sor állapotát (ismétlés, keverés) is
    // közzéteszi, és egy `late final` mezőhöz idő előtt hozzányúlni
    // `LateInitializationError`-t dobna.
    session = MusicQueuePlayer(
      player: _player,
      onStopRequested: _onQueueStopRequested,
    );
    _stateSubscription = _player.playbackEventStream
        .map(_toPlaybackState)
        .listen(playbackState.add, onError: playbackState.addError);
    // A sor és az aktuális tétel közzététele a rendszer felé (ebből lesz az
    // értesítés és a zárképernyő).
    session.tracks.addListener(_publishSession);
    session.currentKey.addListener(_publishSession);
    session.repeat.addListener(_publishModes);
    session.shuffle.addListener(_publishModes);
  }

  StreamSubscription<PlaybackState>? _stateSubscription;

  final AudioPlayer _player = AudioPlayer();

  /// A **lejátszási sor** — a szolgáltatásé, nem a képernyőé (lásd az 1. szabályt).
  late final MusicQueuePlayer session;

  /// A lejátszó a felületnek (a folyamatjelző és a hossz ugyanaz a stream).
  AudioPlayer get player => _player;

  /// A látható tétel (az értesítés címe, előadója, borítója).
  MediaItem? get currentItem => mediaItem.value;

  /// A **rádió** visszakapja a hangot, ha előtte az szólt (a `main`-ben kötjük
  /// be, hogy a szolgáltatás ne függjön a felület fájljaitól).
  Future<void> Function()? onResumeRadio;

  /// Jelezte-e a képernyő, hogy a zene átvette a hangot a rádiótól.
  ///
  /// MIÉRT itt, és nem a képernyőn: a stop a **zárképernyőről** is jöhet, amikor a
  /// képernyő már megszűnt — ilyenkor is vissza kell adni a hangot a rádiónak.
  bool resumeRadioWhenStopped = false;

  @override
  Future<void> play() async {
    // Ha még **semmi** nincs betöltve (pl. a zárképernyőről indítanak), akkor a
    // sor első tételét indítjuk: a szolgáltatás ismeri a sort, nem kell hozzá a
    // képernyő.
    if (_player.audioSource == null) {
      await session.toggle();
      return;
    }
    // ⚠️ Stop után a dekóderek el vannak engedve (`processingState == idle`):
    // ilyenkor előbb **újra be kell tölteni** a forrást, különben a `play()`
    // némán nem csinál semmit (a zárképernyő play gombja így nem működne).
    if (_player.processingState == ProcessingState.idle) {
      await _player.load();
    }
    await _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  /// Stop: megáll, az értesítést is **leveszi** (nem marad halott lejátszó), és
  /// visszaadja a hangot a rádiónak, ha a zene vette át tőle.
  @override
  Future<void> stop() async {
    await session.stop();
    await super.stop();
    if (resumeRadioWhenStopped) {
      resumeRadioWhenStopped = false;
      final resume = onResumeRadio;
      if (resume != null) await resume();
    }
  }

  /// A sor **vége vagy egy hiba**: leállítunk, és a hang visszamegy a rádiónak.
  Future<void> _onQueueStopRequested(MusicQueueStopReason reason) => stop();

  @override
  Future<void> skipToNext() async {
    // ⚠️ NEM visszahívás a képernyőre: a sor a szolgáltatásé, ezért a zárképernyő
    // gombja a képernyő elhagyása után is ugyanazt teszi, mint az appban.
    await session.next();
  }

  @override
  Future<void> skipToPrevious() async {
    await session.previous();
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    // A lejátszó saját ismétlés-mezőjét nem használjuk (a sor végén a MI
    // szabályunk dönt), ezért csak a sor kapja meg.
    session.setRepeat(switch (repeatMode) {
      AudioServiceRepeatMode.one => PlaybackRepeat.one,
      AudioServiceRepeatMode.all ||
      AudioServiceRepeatMode.group => PlaybackRepeat.all,
      AudioServiceRepeatMode.none => PlaybackRepeat.none,
    });
    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode != AudioServiceShuffleMode.none;
    session.setShuffle(enabled);
    playbackState.add(playbackState.value.copyWith(shuffleMode: shuffleMode));
  }

  /// A sor közzététele a rendszer felé (az értesítés „sor" nézete és a
  /// következő/előző gombok ehhez igazodnak).
  void publishQueue(List<MediaItem> items, {int index = 0}) {
    queue.add(items);
    // A `mediaItem.add(null)` az audio_service-ben **némán nem csinál semmit**
    // (a platform a korábbi tételt tartaná meg, azaz elavult címet mutatna) —
    // ezért üres sornál nem írunk semmit.
    if (index >= 0 && index < items.length) {
      mediaItem.add(items[index]);
    }
    playbackState.add(
      playbackState.value.copyWith(queueIndex: index < 0 ? null : index),
    );
  }

  /// Az aktuális tétel beállítása (a sáv és az értesítés címe).
  void publishCurrent(MediaItem? item, {int? index}) {
    if (item == null) return;
    mediaItem.add(item);
    if (index != null) {
      playbackState.add(
        playbackState.value.copyWith(queueIndex: index < 0 ? null : index),
      );
    }
  }

  /// A **sor** közzététele a szolgáltatás állapotából (a képernyő nélkül is).
  ///
  /// ⚠️ Saját hibakezelés: a közzététel csak *megjelenítés* (értesítés,
  /// zárképernyő) — ha ez elhasal, a zenének akkor is szólnia kell.
  void _publishSession() {
    try {
      final items = [for (final track in session.tracks.value) track.item];
      if (items.isEmpty) return;
      final index = session.index;
      publishQueue(
        items,
        index: index < 0 || index >= items.length ? 0 : index,
      );
    } catch (error) {
      debugPrint('Lejátszó-metaadat hiba: $error');
    }
  }

  /// Az ismétlés/keverés állapotának közzététele (a zárképernyő is mutatja).
  void _publishModes() {
    try {
      playbackState.add(
        playbackState.value.copyWith(
          repeatMode: _audioServiceRepeat(session.repeat.value),
          shuffleMode: session.shuffle.value
              ? AudioServiceShuffleMode.all
              : AudioServiceShuffleMode.none,
        ),
      );
    } catch (error) {
      debugPrint('Lejátszó-metaadat hiba: $error');
    }
  }

  AudioServiceRepeatMode _audioServiceRepeat(PlaybackRepeat repeat) {
    switch (repeat) {
      case PlaybackRepeat.one:
        return AudioServiceRepeatMode.one;
      case PlaybackRepeat.all:
        return AudioServiceRepeatMode.all;
      case PlaybackRepeat.none:
        return AudioServiceRepeatMode.none;
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
      // Az ismétlés/keverés a **soré** (nem a just_audio-é): enélkül minden
      // esemény visszaállítaná a zárképernyőn a „nincs ismétlés" jelzést.
      repeatMode: _audioServiceRepeat(session.repeat.value),
      shuffleMode: session.shuffle.value
          ? AudioServiceShuffleMode.all
          : AudioServiceShuffleMode.none,
      // ⚠️ `queueIndex`-et SZÁNDÉKOSAN nem tesszük be: mi egyetlen
      // `AudioSource.file`-t játszunk, ezért a just_audio `event.currentIndex`-e
      // mindig `0` (vagy null) — az pedig **felülírná** a saját sor-indexünket,
      // és az értesítés mindig az első tételt jelölné. A sor a MIÉNK
      // (`publishQueue`), ezért azt itt nem bántjuk.
    );
  }

  /// A lejátszó erőforrásainak elengedése (a szolgáltatás lezárásakor).
  Future<void> disposePlayer() async {
    await session.dispose();
    await _stateSubscription?.cancel();
    return _player.dispose();
  }
}
