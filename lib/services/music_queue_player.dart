/// A „Megvásárolt zenéim" **lejátszási sorának** és léptetésének a helye.
///
/// MIÉRT NEM A KÉPERNYŐ VEZÉREL: eddig a zárképernyő „következő"/„előző" gombja
/// és a dal végi automatikus továbblépés a **képernyő visszahívásaihoz** volt
/// kötve (`onNext` / `onPrevious`), és a képernyő `dispose()`-a **null-ra** állította
/// őket. A háttér-szolgáltatás viszont tovább élt, ezért a képernyő elhagyása után
///  a gomb **ott maradt, de néma volt**, a dal végén pedig **megállt a zene**.
///
/// A megoldás: a **sor** (a ténylegesen lejátszható tételek, fájlútvonallal) és a
/// léptetés a szolgáltatásban él, a képernyő pedig csak **megadja az alap-sorrendet**
/// (mi van letöltve, mi van kivéve, mi a kézi sorrend) és kirajzolja az állapotot.
/// Így a döntés továbbra is **egy helyen** van (`label_playback_plan.dart`), de már
/// nem függ attól, hogy a felület épp létezik-e.
///
/// HÁROM SZÁNDÉKOS SZABÁLY:
///  1. **A tiszta döntés külön osztályban van** ([MusicQueuePlan]): a sorrend,
///     a keverés és a kurzor lejátszó **nélkül** is mérhető (futó tesztben).
///  2. **A végrehajtó ([MusicQueuePlayer]) nem dönt**: csak végrehajtja, amit a
///     tiszta modul mond, és a hibát **magyar** üzenetté alakítja.
///  3. **A sor természetes vége és a hiba ugyanazt jelenti:** a házigazda
///     (a háttér-szolgáltatás) leállít, és **visszaadja a hangot a rádiónak**
///     ([MusicQueueStopReason]).
library;

import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../core/errors/playback_error.dart';
import 'label_playback_plan.dart';

/// Miért kell leállítani a lejátszást?
enum MusicQueueStopReason {
  /// Elfogytak a tételek (a sor végén megállunk).
  queueEnded,

  /// Egy tétel indítása hibázott — a hang nem maradhat elzárva.
  failed,
}

/// Egy **lejátszható** tétel: a letöltött fájl és a megjelenítendő adat.
@immutable
class MusicQueueTrack {
  const MusicQueueTrack({
    required this.key,
    required this.filePath,
    required this.item,
  });

  /// A tétel azonosítója (`kiadvány:változat`) — ezzel párosít a képernyő sora,
  /// a médiamunkamenet és a mentett folytatási pont is.
  final String key;

  /// A **letöltött** fájl útvonala: ebből játszik a szolgáltatás.
  final String filePath;

  /// Cím, előadó, album (változat), borító és hossz az értesítéshez.
  final MediaItem item;

  MusicQueueTrack withItem(MediaItem item) =>
      MusicQueueTrack(key: key, filePath: filePath, item: item);
}

/// A sorrend és a kurzor **tiszta** kezelése — lejátszó és hálózat nélkül mérhető.
///
/// A bemenet az **alap-sorrend** (a képernyőtől: letöltött, nincs kivéve, kézi
/// sorrenddel), a kimenet pedig a **lejátszási sorrend** (keverve vagy sem).
class MusicQueuePlan {
  MusicQueuePlan({Random? random}) : _random = random ?? Random();

  final Random _random;

  List<MusicQueueTrack> _base = const [];
  List<MusicQueueTrack> _tracks = const [];
  String _baseSignature = '';
  int _index = -1;
  bool _shuffle = false;

  /// A lejátszási sorrend (keverés esetén a kevert sorrend).
  List<MusicQueueTrack> get tracks => _tracks;

  /// A kurzor a [tracks] listában (`-1` = nincs kiválasztott tétel).
  int get index => _index;

  bool get shuffle => _shuffle;

  /// Az aktuális tétel azonosítója (a kijelzés és az értesítés ehhez igazodik).
  String? get currentKey =>
      _index >= 0 && _index < _tracks.length ? _tracks[_index].key : null;

  /// Az **alap-sorrend** cseréje, a most hallgatott tétel megtartásával.
  ///
  /// A tételt **kulcs alapján** keressük vissza, mert a lista indexei közben
  /// elmozdulhatnak (új vásárlás, törölt fájl, átrendezés) — enélkül a
  /// „következő" gomb másik zenére lépne. Ha a most hallgatott tétel **kikerült**
  /// a sorból, a kurzor `-1` lesz (a hang természetesen szól tovább).
  void setBaseOrder(List<MusicQueueTrack> base, {String? currentKey}) {
    final keepKey = currentKey ?? this.currentKey;
    final signature = [for (final track in base) track.key].join('|');
    final unchanged = signature == _baseSignature && _tracks.isNotEmpty;
    _base = List<MusicQueueTrack>.of(base);
    _baseSignature = signature;
    // ⚠️ Ha az alap-sorrend **nem változott** és keverünk, a kevert sorrendet
    // **megtartjuk**: különben minden fájlpásztázás újra keverne, és a
    // „következő" gomb másik zenére ugrana.
    if (_shuffle && unchanged) {
      _index = keepKey == null
          ? -1
          : _tracks.indexWhere((track) => track.key == keepKey);
      return;
    }
    _rebuild(keepKey: keepKey);
  }

  /// A keverés be/ki. Bekapcsoláskor az aktuális tétel **az első helyre** kerül,
  /// ezért a keverés nem szakítja meg azt, amit épp hallgatsz.
  void setShuffle(bool value) {
    if (_shuffle == value) return;
    _shuffle = value;
    _rebuild(keepKey: currentKey);
  }

  /// A kurzor átállítása egy kulcsra (`null` = nincs kiválasztott tétel).
  void moveToKey(String? key) {
    _index = key == null ? -1 : _tracks.indexWhere((track) => track.key == key);
  }

  /// Az **aktuális** tétel megjelenítési adatának frissítése (pl. a hossz).
  ///
  /// A hossz azért kell, mert a zárképernyő tekerősávja a `MediaItem` hosszából
  /// dolgozik — enélkül nulla hosszú lenne.
  void updateCurrentItem(MediaItem item) {
    final index = _index;
    if (index < 0 || index >= _tracks.length) return;
    final key = _tracks[index].key;
    final updated = List<MusicQueueTrack>.of(_tracks);
    updated[index] = updated[index].withItem(item);
    _tracks = updated;
    _base = [
      for (final track in _base)
        if (track.key == key) updated[index] else track,
    ];
  }

  void _rebuild({String? keepKey}) {
    final indices = [for (var i = 0; i < _base.length; i++) i];
    final baseIndex = keepKey == null
        ? -1
        : _base.indexWhere((track) => track.key == keepKey);
    final order = playOrderFor(
      indices: indices,
      shuffle: _shuffle,
      random: _random,
      currentIndex: baseIndex < 0 ? null : baseIndex,
    );
    _tracks = [for (final index in order) _base[index]];
    _index = keepKey == null
        ? -1
        : _tracks.indexWhere((track) => track.key == keepKey);
  }
}

/// A lejátszási sor **végrehajtója**: betöltés, indítás, léptetés, ismétlés, hiba.
///
/// Ezt használja a háttér-szolgáltatás (`MusicAudioHandler`) **és** a képernyő
/// tartalék-ága (ha az `AudioService` nem indul el) — ezért a viselkedés
/// ugyanaz, akár van háttér-szolgáltatás, akár nincs.
class MusicQueuePlayer {
  MusicQueuePlayer({
    AudioPlayer? player,
    this.onStopRequested,
    Random? random,
  }) : player = player ?? AudioPlayer(),
       _plan = MusicQueuePlan(random: random) {
    _stateSubscription = this.player.playerStateStream.listen(_onPlayerState);
    _durationSubscription = this.player.durationStream.listen(_onDuration);
  }

  /// A sor **természetes vége** vagy egy indítási hiba: a házigazda ilyenkor
  /// leállít (és a szolgáltatásé a rádió visszaadása).
  final Future<void> Function(MusicQueueStopReason reason)? onStopRequested;

  /// A lejátszó (a házigazda birtokolja: a szolgáltatásé a sajátja, a
  /// tartalék-ágban a képernyőé).
  final AudioPlayer player;

  final MusicQueuePlan _plan;

  /// A lejátszási sorrend — a felület **és** az értesítés is ebből dolgozik.
  final ValueNotifier<List<MusicQueueTrack>> tracks = ValueNotifier(const []);

  /// Az aktuális tétel azonosítója (a sáv és az értesítés címe).
  final ValueNotifier<String?> currentKey = ValueNotifier(null);

  final ValueNotifier<PlaybackRepeat> repeat = ValueNotifier(PlaybackRepeat.none);
  final ValueNotifier<bool> shuffle = ValueNotifier(false);

  /// Egyszeri, **magyar** hibaüzenet a felületre (a technikai ok a naplóba megy).
  final ValueNotifier<String?> errorMessage = ValueNotifier(null);

  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<Duration?>? _durationSubscription;

  bool _starting = false;
  int? _pendingIndex;
  bool _advancing = false;
  bool _disposed = false;
  String? _loadedKey;

  /// A kurzor a lejátszási sorrendben (`-1` = nincs).
  int get index => _plan.index;

  /// A **betöltött** hangforrás azonosítója (`null`, ha nincs betöltve).
  ///
  /// ⚠️ Saját nyilvántartás: a `just_audio` `AudioSource` **alaposztályán** nincs
  /// `tag` getter, ezért a `MediaItem`-et nem tudjuk visszaolvasni a lejátszóból
  /// — a betöltés pillanatában jegyezzük meg.
  String? get loadedKey => _loadedKey;

  bool get isPlaying => player.playing;

  /// Az **alap-sorrend** átvétele a képernyőtől (ez az egyetlen bemenet).
  void setBaseOrder(List<MusicQueueTrack> base) {
    if (_disposed) return;
    _plan.setBaseOrder(base, currentKey: currentKey.value);
    _publishPlan();
  }

  void setShuffle(bool value) {
    if (_disposed) return;
    _plan.setShuffle(value);
    shuffle.value = _plan.shuffle;
    _publishPlan();
  }

  void setRepeat(PlaybackRepeat value) {
    if (_disposed) return;
    repeat.value = value;
  }

  /// Egy tétel indítása a **lejátszási sorrend** indexe szerint.
  Future<void> playAt(int index, {int? startAtMs}) async {
    if (_disposed) return;
    final list = _plan.tracks;
    if (index < 0 || index >= list.length) return;
    // ⚠️ Kétszeres indítás elleni kapu: a dal végi automatikus továbblépés és a
    // zárképernyő „következő" gombja egyszerre is jöhet — két párhuzamos
    // `setAudioSource` összekeverné a lejátszást. A kérés viszont **nem vész el**:
    // a legfrissebbet eltesszük, és az indítás végén elindítjuk.
    if (_starting) {
      _pendingIndex = index;
      return;
    }
    final track = list[index];
    final previousKey = _plan.currentKey;
    _starting = true;
    _plan.moveToKey(track.key);
    errorMessage.value = null;
    _publishPlan();
    try {
      await player.setAudioSource(AudioSource.file(track.filePath, tag: track.item));
      _loadedKey = track.key;
      // A „folytatás" pontját a betöltés **után** keressük meg (addig nincs
      // hossz, és a seek nem is értelmezhető).
      if (startAtMs != null && startAtMs > 0) {
        await player.seek(Duration(milliseconds: startAtMs));
      }
      _applyDuration(player.duration);
      unawaited(player.play());
    } catch (error) {
      // A technikai okot a naplóba írjuk, a felületre magyar mondat megy.
      debugPrint('Lejátszás-indítási hiba: $error');
      _loadedKey = null;
      // A kijelölést **visszaállítjuk**: a sor ne maradjon „ez szól" állapotban,
      // miközben semmi nem szól.
      _plan.moveToKey(previousKey);
      _publishPlan();
      errorMessage.value = playbackErrorMessage(error);
      // ⚠️ A hang nem maradhat elzárva: a házigazda leállít, és a szolgáltatás
      // visszaadja a hangot a rádiónak.
      final stop = onStopRequested;
      if (stop != null) await stop(MusicQueueStopReason.failed);
    } finally {
      _starting = false;
      final pending = _pendingIndex;
      _pendingIndex = null;
      if (pending != null && !_disposed) unawaited(playAt(pending));
    }
  }

  /// A **következő** tétel. `isAutoAdvance` = a dal magától ért véget (ilyenkor az
  /// ismétlés-egy ugyanezt a tételt indítja újra); a kézi gomb mindig továbblép.
  Future<void> next({bool isAutoAdvance = false}) async {
    if (_disposed) return;
    final next = stepPlayback(
      cursor: _plan.index,
      length: _plan.tracks.length,
      repeat: repeat.value,
      isAutoAdvance: isAutoAdvance,
    );
    if (next < 0) {
      await _finishQueue();
      return;
    }
    await playAt(next);
  }

  /// Az **előző** tétel (a sor elején az ismétlés dönt).
  Future<void> previous() async {
    if (_disposed) return;
    final previous = previousPlaybackStep(
      cursor: _plan.index,
      length: _plan.tracks.length,
      repeat: repeat.value,
    );
    if (previous < 0) return;
    await playAt(previous);
  }

  /// A „lejátszás/szünet" gomb: ugyanaz a viselkedés, mint a felületen.
  Future<void> toggle({int? startAtMs}) async {
    if (_disposed) return;
    final list = _plan.tracks;
    final index = _plan.index;
    final wanted = index >= 0 && index < list.length ? list[index] : null;
    if (wanted != null && player.playing) {
      await player.pause();
      return;
    }
    if (wanted != null &&
        !needsSourceReload(loadedKey: _loadedKey, wantedKey: wanted.key) &&
        player.processingState != ProcessingState.idle) {
      // ⚠️ `idle` = stop utáni állapot (a dekóderek el vannak engedve), illetve
      // ha **más** tétel van betöltve, akkor is újra kell tölteni — különben a
      // gomb rossz zenét indítana.
      unawaited(player.play());
      return;
    }
    if (wanted != null) {
      await playAt(index, startAtMs: startAtMs);
      return;
    }
    if (list.isEmpty) {
      errorMessage.value =
          'Még nincs letöltött zenéd — tölts le egyet a Letöltés gombbal.';
      return;
    }
    await playAt(0, startAtMs: startAtMs);
  }

  /// A **stop** gomb: megáll, de a tétel kijelölése megmarad (egy koppintással
  /// újraindítható) — a rádió visszaadása a házigazda dolga.
  Future<void> stop() async {
    if (_disposed) return;
    _loadedKey = null;
    await player.stop();
  }

  /// Az erőforrások elengedése. A **lejátszót nem** dobjuk el: azt a házigazda
  /// birtokolja (a szolgáltatás a sajátját, a tartalék-ág a képernyőét).
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _stateSubscription?.cancel();
    await _durationSubscription?.cancel();
    tracks.dispose();
    currentKey.dispose();
    repeat.dispose();
    shuffle.dispose();
    errorMessage.dispose();
  }

  /// A dal **vége** — itt dől el, mi következik, nem a képernyőn.
  void _onPlayerState(PlayerState state) {
    if (_disposed) return;
    if (state.processingState != ProcessingState.completed) return;
    if (_advancing || _starting) return;
    _advancing = true;
    unawaited(
      next(isAutoAdvance: true).whenComplete(() => _advancing = false),
    );
  }

  /// A hossz közzététele a zárképernyő tekerősávjához.
  void _onDuration(Duration? duration) {
    if (_disposed) return;
    // Csak a **betöltött** tételre írjuk (gyors váltásnál a régi forrás hossza
    // érkezhet meg később).
    if (_loadedKey == null || _loadedKey != _plan.currentKey) return;
    _applyDuration(duration);
  }

  void _applyDuration(Duration? duration) {
    if (_disposed || duration == null || duration <= Duration.zero) return;
    final index = _plan.index;
    final list = _plan.tracks;
    if (index < 0 || index >= list.length) return;
    if (list[index].item.duration != null) return;
    _plan.updateCurrentItem(list[index].item.copyWith(duration: duration));
    _publishPlan();
  }

  /// A sor **természetes vége**: nincs több tétel, a kijelölés is elmegy.
  Future<void> _finishQueue() async {
    _loadedKey = null;
    _plan.moveToKey(null);
    _publishPlan();
    await player.stop();
    final stop = onStopRequested;
    if (stop != null) await stop(MusicQueueStopReason.queueEnded);
  }

  /// A **megjelenítés** közzététele (a felület és az értesítés ehhez igazodik).
  ///
  /// ⚠️ Saját hibakezelés: ez csak *megjelenítés*. Ha egy figyelő (pl. a
  /// médiamunkamenet felé író szolgáltatás) hibázik, a zenének akkor is szólnia
  /// kell — élesben pont az ellenkezője történt, és a lejátszó néma maradt.
  void _publishPlan() {
    if (_disposed) return;
    try {
      tracks.value = _plan.tracks;
      currentKey.value = _plan.currentKey;
    } catch (error) {
      debugPrint('Lejátszó-metaadat hiba: $error');
    }
  }
}
