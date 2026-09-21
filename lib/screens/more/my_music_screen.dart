import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/errors/user_facing_error.dart';
import '../../models/label_library.dart';
import '../../models/release.dart';
import '../../providers/community_provider.dart';
import '../../providers/label_library_provider.dart';
import '../../providers/news_provider.dart';
import '../../providers/releases_provider.dart';
import '../../services/label_download_manager.dart';
import '../../services/label_library_plan.dart';
import '../../services/label_playback_memory.dart';
import '../../services/label_playback_plan.dart';
import '../../widgets/radio_player_bar.dart';
import '../../widgets/resized_network_image.dart';
import '../releases/releases_screen.dart';

/// „Saját zenéim" — a **megvásárolt** (és reklámmal feloldott) zenék.
///
/// A tulajdonos kérése: *„kéne egy user specifikus menüpont a megvett zenékre,
/// ahol le tudja játszani, ha vége a zenének, ugrik a következőre, le is tudja
/// tölteni újra, úgymond megmarad ott a megvásárolt zenéje"* — kiegészítve:
/// *„tudjon törölni is ha akar, de a letöltési lehetősége maradjon meg"*, és
/// *„ha másik accal lép be, ne látszódjon és letölteni se tudja"*.
///
/// AMI EBBŐL A KÉPERNYŐN KÖVETKEZIK:
///  1. **A lista a szerverről jön** (a hitelesített UID-del szűrve), a letöltött
///     fájlok pedig **fiókonként külön mappában** vannak — ezért más fiók sem
///     listát, sem lejátszható fájlt nem lát.
///  2. **A törlés csak a készülékről töröl**: a vásárlás a szerveren marad,
///     ezért a „Letöltés" gomb **azonnal visszakerül** a törölt tételhez.
///  3. **A szám végén magától a következőre lép**, és ha az még nincs meg,
///     előbb letölti — a sor nem akad meg.
class MyMusicScreen extends ConsumerStatefulWidget {
  const MyMusicScreen({super.key});

  @override
  ConsumerState<MyMusicScreen> createState() => _MyMusicScreenState();
}

class _MyMusicScreenState extends ConsumerState<MyMusicScreen> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;

  final Set<String> _downloaded = <String>{};
  int _currentIndex = -1;
  bool _busy = false;
  bool _resumeRadioAfterStop = false;
  String? _message;
  int _storageBytes = 0;

  /// A **lejátszási sorrend** (a sor indexei) és az abban álló kurzor.
  ///
  /// MIÉRT külön a `_queue`-tól: a keverés a sorrendet változtatja, nem a
  /// tartalmat — a kurzor viszont mindig a **sorrendben** lépked, ezért a
  /// „következő" gomb a kevert sorrendet követi (és a sor végén megáll).
  List<int> _order = const [];

  /// Ismétlés módja (nincs / mind / egy) és a keverés állapota.
  PlaybackRepeat _repeat = PlaybackRepeat.none;
  bool _shuffle = false;

  /// A **letöltött** tételek lenyomata: ebből tudjuk, kell-e újraépíteni a
  /// sorrendet. Enélkül minden fájlpásztázás átrendezné a kevert sorrendet.
  String _downloadedSignature = '';

  /// Ha a **sor** változott (új vásárlás, eltűnt kiadvány), a benne lévő
  /// indexek elavulnak, ezért a sorrendet újra kell építeni. Ezt külön jelöljük,
  /// mert a letöltött készlet lenyomata önmagában nem változik ilyenkor.
  bool _orderDirty = true;

  /// A lejátszás kijelzése: a pozíció és a hossz. A `_position` **nem**
  /// `setState`-tel frissül (200 ms-onként újrarajzolná a listát), hanem a
  /// folyamatjelző saját `StreamBuilder`-je olvassa a lejátszó streameit.
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  /// Tekerés közben a **kéz** számít: a stream ilyenkor nem írja felül a sávot.
  bool _seeking = false;
  double _seekValue = 0;

  /// A felajánlott „folytatás" pont (a képernyő megnyitásakor olvassuk be).
  LabelPlaybackPoint? _resumePoint;

  /// A legutóbb **mentett** pozíció — 5 másodpercenként mentünk, nem 200 ms-onként.
  int _lastSavedMs = 0;

  /// A lejátszási pont emlékezete (fiókonként; vendégnél nem ír).
  final LabelPlaybackMemory _memory = LabelPlaybackMemory();

  /// A bejelentkezett UID **gyorsítótárazva**.
  ///
  /// MIÉRT: a `dispose()`-ban is mentünk (hogy egy hirtelen kilépés ne vigye el a
  /// folytatási pontot), ott viszont a `ref` már nem biztonságos — ezért a
  /// `build`-ben eltároljuk az értéket, és a lejátszóéletciklus abból dolgozik.
  String _uidValue = '';

  /// A legutóbb kiszámolt sor — a `build`-ben **tisztán** áll elő, ezért nem
  /// kell `setState` a számításhoz (az csak a fájlok pásztázásához kell).
  List<LabelQueueEntry> _queue = const [];
  String _queueSignature = '';

  /// Kiadvány-adatok a könyvtárhoz. A lista a **nyilvános katalógusból** jön, de
  /// egy régi (időközben törölt/elrejtett) kiadvány abban **már nincs benne** —
  /// ilyenkor egyenként kérdezzük le (`/releases/<id>`), és ha az sem adja,
  /// **nem elérhetőnek** jelöljük. (A tulajdonos jelezte: *„van ott egy kiadvány
  /// #12327 ami nem tudom mi"* — az pontosan egy ilyen, a listából eltűnt
  /// kiadvány volt, amit egy reklámmal oldott fel korábban.)
  final Map<int, HuhsRelease> _releaseMeta = {};
  final Set<int> _unavailableReleases = {};
  final Set<int> _resolvingReleases = {};

  /// A **katalógus + a lusta lekérdezések** együtt — ebből rajzolódnak a kártyák
  /// ÉS épül a lejátszási sor.
  ///
  /// ⚠️ EZT A KÉT HELYET EGYÜTT KELL HASZNÁLNI. A 341-es változat a kártyáknál
  /// **csak** a lusta térképet nézte, ezért a katalógusból ismert kiadványok
  /// címe **soha nem jelent meg**: a lista végig „Adatok betöltése…" volt, miközben
  /// a lejátszósáv már a valódi címet mutatta (a sor a helyes térképet használta).
  Map<int, HuhsRelease> _catalogById = const {};

  @override
  void initState() {
    super.initState();
    _stateSubscription = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        unawaited(_advance());
        return;
      }
      // Szünet/újraindítás: a pozíciót ilyenkor érdemes elmenteni (a hirtelen
      // kilépésnél ez a pont marad meg).
      if (!state.playing) unawaited(_saveProgress(force: true));
    });
    // A pozíciót NEM `setState`-tel követjük (az a teljes listát újrarajzolná
    // 200 ms-onként), hanem eltároljuk a mentéshez és a folyamatjelzőhöz.
    _positionSubscription = _player.positionStream.listen((position) {
      _position = position;
      if (!_seeking) _seekValue = position.inMilliseconds.toDouble();
      unawaited(_saveProgress());
    });
    _durationSubscription = _player.durationStream.listen((duration) {
      _duration = duration ?? Duration.zero;
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    unawaited(_saveProgress(force: true));
    _stateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    unawaited(_releaseAudio());
    _player.dispose();
    super.dispose();
  }

  String get _uid => _uidValue;

  /// A kurzor a **lejátszási sorrendben** (nem a nyers sorban).
  int get _cursor => _order.indexOf(_currentIndex);

  /// A sorrend újraépítése a letöltött tételekből.
  ///
  /// Keverésnél az **aktuális tétel marad az első**, ezért a keverés
  /// bekapcsolása nem szakítja meg azt, amit épp hallgatsz.
  void _rebuildOrder({int? previousCurrent}) {
    final indices = downloadedIndices(
      [for (final entry in _queue) entry.key],
      _downloaded,
    );
    _order = playOrderFor(
      indices: indices,
      shuffle: _shuffle,
      random: Random(),
      currentIndex: previousCurrent ?? _currentIndex,
    );
  }

  /// A letöltött tételek lenyomata — a sorrend csak **változáskor** épül újra.
  String _signatureOf(Set<String> downloaded) {
    final keys = downloaded.toList()..sort();
    return keys.join('|');
  }

  /// A lejátszási pont mentése (5 másodpercenként, illetve `force` esetén).
  ///
  /// Csak **érdemi** pozíciót mentünk (`worthResuming`), ezért nem marad mentés
  /// a szám legelejéről — azt a „folytatás" felajánlás úgysem kínálná fel.
  Future<void> _saveProgress({bool force = false}) async {
    if (_currentIndex < 0 || _currentIndex >= _queue.length) return;
    final uid = _uid;
    if (uid.isEmpty) return;
    final positionMs = _position.inMilliseconds;
    if (!force && (positionMs - _lastSavedMs).abs() < 5000) return;
    _lastSavedMs = positionMs;
    final entry = _queue[_currentIndex];
    if (!worthResuming(positionMs, _duration.inMilliseconds)) {
      // Elöl (5 s előtt) vagy a legvégén: inkább töröljük a pontot, hogy ne
      // ajánljunk fel értelmetlen folytatást.
      await _memory.clear(uid);
      return;
    }
    await _memory.save(
      uid,
      LabelPlaybackPoint(
        releaseId: entry.releaseId,
        variant: entry.variant,
        positionMs: positionMs,
      ),
    );
  }

  /// A mentett pont beolvasása és felajánlása (ha a fájl meg is van).
  Future<void> _loadResumePoint() async {
    final uid = _uid;
    if (uid.isEmpty) {
      if (mounted) setState(() => _resumePoint = null);
      return;
    }
    final point = await _memory.load(uid);
    if (!mounted) return;
    // Csak akkor ajánljuk fel, ha a tétel a sorban **és a készüléken** is megvan:
    // különben egy törölt fájlra kínálnánk folytatást.
    final known =
        point != null &&
        _queue.any((entry) => entry.key == point.entryKey) &&
        _downloaded.contains(point.entryKey);
    setState(() => _resumePoint = known ? point : null);
  }

  LabelDownloadManager get _downloads => ref.read(labelDownloadManagerProvider);

  /// A katalógusból hiányzó kiadványok egyenkénti lekérdezése.
  ///
  /// Csak **egyszer** próbáljuk (a `_resolvingReleases`/`_unavailableReleases`
  /// miatt), és a hiba nem hibaüzenet: az azt jelenti, hogy a kiadvány már nincs
  /// meg a nyilvános listában, ezért „nem elérhető"-ként jelöljük.
  Future<void> _resolveMissingReleases(List<int> releaseIds) async {
    for (final releaseId in releaseIds) {
      if (_resolvingReleases.contains(releaseId) ||
          _releaseMeta.containsKey(releaseId) ||
          _unavailableReleases.contains(releaseId)) {
        continue;
      }
      _resolvingReleases.add(releaseId);
      try {
        final release = await ref
            .read(wordpressServiceProvider)
            .getRelease(releaseId);
        if (!mounted) return;
        setState(() {
          _releaseMeta[releaseId] = release;
          _resolvingReleases.remove(releaseId);
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _unavailableReleases.add(releaseId);
          _resolvingReleases.remove(releaseId);
        });
      }
    }
  }

  Future<String> _urlFor(LabelQueueEntry entry) => ref
      .read(labelLibraryServiceProvider)
      .downloadUrl(releaseId: entry.releaseId, variant: entry.variant);

  /// A meglévő fájlok és a helyfoglalás frissítése (a sor előállítása után).
  Future<void> _scanDownloads() async {
    final queue = _queue;
    Set<String> downloaded;
    var storage = 0;
    try {
      downloaded = await _downloads.downloadedKeys(queue);
      storage = await _downloads.totalBytes();
    } catch (_) {
      // Vendég fióknál (nincs mappa) nincs mit pásztázni — nem hiba.
      downloaded = <String>{};
      storage = 0;
    }
    if (!mounted) return;
    final signature = _signatureOf(downloaded);
    final changed = signature != _downloadedSignature || _orderDirty;
    setState(() {
      _downloaded
        ..clear()
        ..addAll(downloaded);
      _storageBytes = storage;
      if (_currentIndex >= queue.length) _currentIndex = -1;
      // A sorrend csak **változáskor** épül újra: különben minden pásztázás
      // átrendezné a kevert sorrendet, és a „következő" gomb ugrálna.
      if (changed) {
        _downloadedSignature = signature;
        _orderDirty = false;
        _rebuildOrder();
      }
    });
    // A „folytatás" felajánlása csak akkor érdekes, ha a letöltött készlet
    // változott (ekkor derülhet ki, hogy a mentett tétel fájlja megvan-e).
    if (changed) unawaited(_loadResumePoint());
  }

  Future<bool> _ensureDownloaded(LabelQueueEntry entry) async {
    try {
      if (await _downloads.isDownloaded(entry)) {
        if (mounted) setState(() => _downloaded.add(entry.key));
        return true;
      }
      await _downloads.download(entry, urlFor: () => _urlFor(entry));
      if (mounted) {
        setState(() {
          _downloaded.add(entry.key);
          _message = null;
        });
      }
      unawaited(_scanDownloads());
      return true;
    } catch (error) {
      if (mounted) setState(() => _message = userFacingError(error));
      return false;
    }
  }

  Future<void> _playIndex(int index, {int? startAtMs}) async {
    if (index < 0 || index >= _queue.length) return;
    final entry = _queue[index];
    // ⚠️ CSAK LETÖLTÖTT zene játszható: a lapozás és az automatikus továbblépés
    // nem indít letöltést (a tulajdonos jelzése: „le akarja tölteni ami nincs
    // letöltve… csak a letöltött zenéket játsza le").
    if (!_downloaded.contains(entry.key)) {
      if (mounted) {
        setState(
          () => _message =
              'A(z) „${entry.nowPlayingLabel}" még nincs letöltve — előbb '
              'töltsd le, és utána játszható.',
        );
      }
      return;
    }
    setState(() {
      _currentIndex = index;
      _resumePoint = null;
    });
    try {
      // A rádió és a lejátszó ne szóljon egyszerre — ugyanaz a minta, mint a
      // kiadvány-előhallgatónál.
      if (!releasePreviewPlayingState.value) {
        _resumeRadioAfterStop = await isRadioPlaybackActive();
        if (_resumeRadioAfterStop) await stopRadioPlayback();
        if (mounted) releasePreviewPlayingState.value = true;
      }
      final file = await _downloads.fileFor(entry);
      await _player.setFilePath(file.path);
      // A „folytatás" pontját a betöltés **után** keressük meg (addig nincs
      // hossz, és a seek nem is értelmezhető).
      if (startAtMs != null && startAtMs > 0) {
        await _player.seek(Duration(milliseconds: startAtMs));
      }
      _lastSavedMs = startAtMs ?? 0;
      unawaited(_player.play());
      if (mounted) setState(() => _message = null);
    } catch (error) {
      if (mounted) setState(() => _message = userFacingError(error));
    }
  }

  /// A szám végén a **sorrend** szerinti következő tételre lép.
  ///
  /// Az ismétlés (egy / mind) itt dönt: a [PlaybackRepeat.one] ugyanezt a tételt
  /// indítja újra, a [PlaybackRepeat.all] körbefordul, egyébként megáll — és
  /// ilyenkor a rádió visszakapja a hangot.
  Future<void> _advance() async {
    final next = stepPlayback(
      cursor: _cursor,
      length: _order.length,
      repeat: _repeat,
      isAutoAdvance: true,
    );
    if (next < 0) {
      await _releaseAudio();
      if (mounted) setState(() => _currentIndex = -1);
      return;
    }
    await _playIndex(_order[next]);
  }

  /// A „következő" gomb: a sorrendben lép (ismétlés-egy mellett is tovább).
  Future<void> _playNext() async {
    final next = stepPlayback(
      cursor: _cursor,
      length: _order.length,
      repeat: _repeat,
      isAutoAdvance: false,
    );
    if (next < 0) return;
    await _playIndex(_order[next]);
  }

  /// Az „előző" gomb: a sorrendben lép vissza.
  Future<void> _playPrevious() async {
    final previous = previousPlaybackStep(
      cursor: _cursor,
      length: _order.length,
      repeat: _repeat,
    );
    if (previous < 0) return;
    await _playIndex(_order[previous]);
  }

  /// **Stop**: megáll, a szám elejére áll, és a rádió visszakapja a hangot.
  ///
  /// Szándékosan **nem** ugyanaz, mint a szünet: a szünetnél a lejátszás helye
  /// megmarad (és a rádió hallgat), a stopnál viszont elölről kezdhető, ezért a
  /// mentett folytatási pontot is töröljük.
  Future<void> _stopPlayback() async {
    await _player.stop();
    await _releaseAudio();
    await _memory.clear(_uid);
    _lastSavedMs = 0;
    if (!mounted) return;
    setState(() {
      _position = Duration.zero;
      _seekValue = 0;
      _duration = Duration.zero;
      _message = null;
    });
  }

  /// Leállás: a rádió visszakapja a hangot, ha előtte az szólt.
  Future<void> _releaseAudio() async {
    await _player.stop();
    releasePreviewPlayingState.value = false;
    if (_resumeRadioAfterStop) {
      _resumeRadioAfterStop = false;
      await resumeRadioPlayback();
    }
  }

  Future<void> _togglePlay() async {
    if (_currentIndex >= 0 && _player.playing) {
      await _player.pause();
    } else if (_currentIndex >= 0 && _player.audioSource != null) {
      unawaited(_player.play());
    } else {
      final start = firstDownloadedIndex(_queue, _downloaded);
      if (start < 0) {
        setState(
          () => _message =
              'Még nincs letöltött zenéd — tölts le egyet a Letöltés gombbal.',
        );
      } else {
        await _playIndex(start);
      }
    }
    if (mounted) setState(() {});
  }

  /// Az ismétlés mód léptetése (nincs → mind → egy → nincs).
  void _cycleRepeat() {
    setState(() => _repeat = nextPlaybackRepeat(_repeat));
  }

  /// A keverés be/ki. Bekapcsoláskor az aktuális tétel az első helyre kerül.
  void _toggleShuffle() {
    setState(() {
      _shuffle = !_shuffle;
      _rebuildOrder();
    });
  }

  Future<void> _downloadOnly(LabelQueueEntry entry) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _ensureDownloaded(entry);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Mégsem'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _confirmDelete(LabelQueueEntry entry) async {
    final ok = await _confirm(
      'Törlés a készülékről',
      'A(z) „${entry.nowPlayingLabel}" letöltött fájlja törlődik. '
          'A vásárlás megmarad, ezért bármikor újra letöltheted.',
      'Törlés',
    );
    if (!ok) return;
    await _downloads.delete(entry);
    if (!mounted) return;
    setState(() {
      _downloaded.remove(entry.key);
      _message = 'Törölve a készülékről — a vásárlás megmaradt.';
      if (_currentIndex >= 0 &&
          _currentIndex < _queue.length &&
          _queue[_currentIndex].key == entry.key) {
        _currentIndex = -1;
      }
    });
    await _scanDownloads();
  }

  Future<void> _deleteAll() async {
    final ok = await _confirm(
      'Letöltött zenék törlése',
      'Minden letöltött fájl törlődik a készülékről. A vásárlásaid '
          'megmaradnak, bármikor újra letölthetők.',
      'Törlés',
    );
    if (!ok) return;
    await _releaseAudio();
    for (final entry in List<LabelQueueEntry>.from(_queue)) {
      await _downloads.delete(entry);
    }
    if (!mounted) return;
    setState(() {
      _downloaded.clear();
      _currentIndex = -1;
      _message = 'A letöltött zenék törölve — a vásárlásaid megmaradtak.';
    });
    await _scanDownloads();
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    if (mb < 0.1) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${mb.toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider);
    _uidValue = uid ?? '';
    if (uid == null) {
      return const _Scaffold(
        child: _Notice(
          icon: Icons.lock_outline,
          title: 'A zenéidhez jelentkezz be',
          body:
              'A megvásárolt zenék a fiókodhoz tartoznak, ezért csak '
              'bejelentkezve láthatók és tölthetők le.',
        ),
      );
    }

    final library = ref.watch(labelLibraryProvider);
    final releases = ref.watch(releasesProvider((search: '', artistId: 0)));

    return _Scaffold(
      child: library.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _Notice(
          icon: Icons.cloud_off,
          title: 'A zenéid most nem érhetők el',
          body: userFacingError(error),
        ),
        data: (items) => releases.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _Notice(
            icon: Icons.cloud_off,
            title: 'A kiadványok most nem érhetők el',
            body: userFacingError(error),
          ),
          data: (catalog) {
            final catalogById = <int, HuhsRelease>{
              for (final release in catalog) release.id: release,
              ..._releaseMeta,
            };
            // A katalógusból hiányzó kiadványokat egyenként kérdezzük le — a
            // válasz után derül el, hogy megvan-e még egyáltalán.
            final missing = <int>[
              for (final item in items)
                if (!catalogById.containsKey(item.releaseId) &&
                    !_unavailableReleases.contains(item.releaseId) &&
                    !_resolvingReleases.contains(item.releaseId))
                  item.releaseId,
            ];
            if (missing.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                unawaited(_resolveMissingReleases(missing));
              });
            }
            // A lejátszási sorba csak az kerül, amiről **tudjuk**, mi az; a már
            // nem elérhető kiadványt nem is kínáljuk lejátszásra.
            final playable = items
                .where((item) => catalogById.containsKey(item.releaseId))
                .toList(growable: false);
            final queue = buildLabelQueue(
              items: playable,
              catalog: catalogById,
            );
            _catalogById = catalogById;
            final signature = queue.map((entry) => entry.key).join(',');
            if (signature != _queueSignature) {
              // A sor **indexei** változtak, ezért a most hallgatott tételt a
              // kulcsa alapján keressük vissza (különben a „következő" gomb egy
              // másik zenére lépne), a sorrendet pedig újra kell építeni.
              final playingKey =
                  _currentIndex >= 0 && _currentIndex < _queue.length
                  ? _queue[_currentIndex].key
                  : null;
              _queueSignature = signature;
              _queue = queue;
              _currentIndex = playingKey == null
                  ? -1
                  : queue.indexWhere((entry) => entry.key == playingKey);
              _orderDirty = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                unawaited(_scanDownloads());
              });
            }
            return _buildContent(items);
          },
        ),
      ),
    );
  }

  Widget _buildContent(List<LabelLibraryItem> items) {
    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const SizedBox(height: 40),
          const _Notice(
            icon: Icons.library_music_outlined,
            title: 'Még nincs megvásárolt zenéd',
            body:
                'A Kiadványok fülön megvásárolt (vagy reklámmal feloldott) '
                'zenék itt jelennek meg, és innen játszhatók le.',
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ReleasesScreen()),
              ),
              icon: const Icon(Icons.album_outlined),
              label: const Text('Kiadványok böngészése'),
            ),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        if (_message != null) _MessageBanner(message: _message!),
        Row(
          children: [
            Expanded(
              child: Text(
                _storageBytes > 0
                    ? '${items.length} kiadvány · ${_queue.length} tétel · '
                          '${_formatBytes(_storageBytes)} a készüléken'
                    : '${items.length} kiadvány · ${_queue.length} tétel',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (_storageBytes > 0)
              TextButton.icon(
                onPressed: _deleteAll,
                icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                label: const Text('Tárhely ürítése'),
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (_resumePoint != null) _buildResumeBanner(),
        if (_queue.isNotEmpty) _buildPlayerBar(),
        for (final item in items) _buildReleaseCard(item),
      ],
    );
  }

  /// A „folytatás ott, ahol abbahagytad" felajánlás.
  ///
  /// Csak akkor jelenik meg, ha a mentett tétel **le is van töltve** (a
  /// `_loadResumePoint` ellenőrzi), és a [worthResuming] szerint érdemi
  /// pozícióról van szó. A „Mégsem" törli a pontot, hogy ne kérdezze újra.
  Widget _buildResumeBanner() {
    final point = _resumePoint!;
    final entry = _queue.firstWhere((item) => item.key == point.entryKey);
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            const Icon(Icons.history, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Folytatás: ${entry.nowPlayingLabel} — '
                '${playbackClock(point.positionMs)}-tól',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () async {
                await _memory.clear(_uid);
                if (!mounted) return;
                setState(() => _resumePoint = null);
              },
              child: const Text('Elölről'),
            ),
            FilledButton(
              onPressed: () => _playIndex(
                _queue.indexWhere((item) => item.key == point.entryKey),
                startAtMs: point.positionMs,
              ),
              child: const Text('Folytatás'),
            ),
          ],
        ),
      ),
    );
  }

  /// A **tekerhető** folyamatjelző: húzás közben a kéz számít, ezért a
  /// lejátszó pozíció-streame ilyenkor **nem** írja felül a sávot.
  Widget _buildSeekRow(ThemeData theme) {
    return StreamBuilder<Duration>(
      stream: _player.positionStream,
      builder: (context, snapshot) {
        final live = snapshot.data ?? _position;
        final duration = _duration;
        final maxMs = duration.inMilliseconds > 0
            ? duration.inMilliseconds.toDouble()
            : 0.0;
        final value = _seeking
            ? _seekValue
            : live.inMilliseconds.toDouble().clamp(0.0, maxMs == 0 ? 1.0 : maxMs);
        final shown = _seeking ? _seekValue : live.inMilliseconds.toDouble();
        final enabled = maxMs > 0;
        return Row(
          children: [
            Text(playbackClock(shown.round()), style: theme.textTheme.bodySmall),
            Expanded(
              child: Slider(
                value: enabled ? value.clamp(0.0, maxMs) : 0,
                max: enabled ? maxMs : 1,
                onChanged: enabled
                    ? (next) => setState(() {
                        _seeking = true;
                        _seekValue = next;
                      })
                    : null,
                onChangeEnd: enabled
                    ? (next) async {
                        await _player.seek(
                          Duration(milliseconds: next.round()),
                        );
                        if (!mounted) return;
                        setState(() => _seeking = false);
                      }
                    : null,
              ),
            ),
            Text(
              playbackClock(duration.inMilliseconds),
              style: theme.textTheme.bodySmall,
            ),
          ],
        );
      },
    );
  }

  /// A **lejátszási lista** (playlist): csak a letöltött tételek, a lejátszási
  /// sorrendben, az aktuális kiemelve. Koppintásra azonnal indul, és a panel
  /// bezárul (így nem marad elavult állapot a képernyőn).
  void _showPlaylist() {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final entries = [
          for (final index in _order)
            if (index >= 0 && index < _queue.length) (index: index, entry: _queue[index]),
        ];
        final pending = _queue.length - entries.length;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Lejátszási lista',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      '${entries.length} tétel'
                      '${_shuffle ? ' · keverve' : ''}'
                      '${pending > 0 ? ' · $pending nincs letöltve' : ''}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: entries.length,
                  itemBuilder: (context, position) {
                    final item = entries[position];
                    final isCurrent = item.index == _currentIndex;
                    return ListTile(
                      dense: true,
                      selected: isCurrent,
                      leading: isCurrent
                          ? Icon(
                              _player.playing
                                  ? Icons.graphic_eq
                                  : Icons.pause_circle_outline,
                              color: theme.colorScheme.primary,
                            )
                          : Text('${position + 1}.'),
                      title: Text(
                        item.entry.nowPlayingLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        item.entry.variantLabel,
                        style: theme.textTheme.bodySmall,
                      ),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        unawaited(_playIndex(item.index));
                      },
                    );
                  },
                ),
              ),
              if (pending > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    'A nem letöltött tételek nincsenek a listában — azokat a '
                    'kiadvány kártyáján tudod letölteni.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlayerBar() {
    final hasCurrent = _currentIndex >= 0 && _currentIndex < _queue.length;
    final entry = hasCurrent ? _queue[_currentIndex] : null;
    final theme = Theme.of(context);
    final hasPrevious =
        previousPlaybackStep(
          cursor: _cursor,
          length: _order.length,
          repeat: _repeat,
        ) >=
        0;
    final hasNext =
        stepPlayback(
          cursor: _cursor,
          length: _order.length,
          repeat: _repeat,
          isAutoAdvance: false,
        ) >=
        0;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Előző',
                  onPressed: hasPrevious ? _playPrevious : null,
                  icon: const Icon(Icons.skip_previous),
                ),
                IconButton(
                  tooltip: _player.playing ? 'Szünet' : 'Lejátszás',
                  onPressed: _togglePlay,
                  icon: Icon(
                    _player.playing ? Icons.pause_circle : Icons.play_circle,
                    size: 34,
                  ),
                ),
                IconButton(
                  tooltip: 'Következő',
                  onPressed: hasNext ? _playNext : null,
                  icon: const Icon(Icons.skip_next),
                ),
                IconButton(
                  tooltip: 'Stop (a szám elejére áll)',
                  onPressed: hasCurrent ? _stopPlayback : null,
                  icon: const Icon(Icons.stop_circle_outlined),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry?.nowPlayingLabel ?? 'Válassz egy zenét',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        hasCurrent
                            ? '${playbackPositionLabel(_cursor, _order.length)} · '
                                  '${_downloaded.length} letöltve'
                            : _downloaded.isEmpty
                            ? 'Előbb tölts le egy zenét'
                            : '${_downloaded.length} letöltött zene',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            _buildSeekRow(theme),
            Row(
              children: [
                IconButton(
                  tooltip: playbackRepeatLabel(_repeat),
                  isSelected: _repeat != PlaybackRepeat.none,
                  onPressed: _cycleRepeat,
                  icon: Icon(
                    _repeat == PlaybackRepeat.one
                        ? Icons.repeat_one
                        : Icons.repeat,
                  ),
                ),
                IconButton(
                  tooltip: _shuffle ? 'Keverés kikapcsolása' : 'Keverés',
                  isSelected: _shuffle,
                  onPressed: _toggleShuffle,
                  icon: const Icon(Icons.shuffle),
                ),
                const Spacer(),
                TextButton.icon(
                  // Üres listát ne nyissunk: ha nincs letöltött tétel, nincs mit
                  // mutatni (a kártyákon ott a „Letöltés" gomb).
                  onPressed: _order.isEmpty ? null : _showPlaylist,
                  icon: const Icon(Icons.queue_music, size: 20),
                  label: const Text('Lista'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReleaseCard(LabelLibraryItem item) {
    // ⚠️ A KATALÓGUSBÓL is: a lusta lekérdezés csak a kiegészítés.
    final release =
        _catalogById[item.releaseId] ?? _releaseMeta[item.releaseId];
    // A nyilvános listából eltűnt kiadvány: a feloldás/vásárlás megvan, de a zene
    // már nem érhető el. **Megmondjuk**, mi ez, ahelyett hogy egy értelmezhetetlen
    // „Kiadvány #szám" sort mutatnánk.
    if (_unavailableReleases.contains(item.releaseId)) {
      return _buildUnavailableCard(item);
    }
    if (release == null) {
      return Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          leading: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          title: const Text('Kiadvány betöltése…'),
          subtitle: Text('Azonosító: ${item.releaseId}'),
        ),
      );
    }
    final entries = _queue
        .where((entry) => entry.releaseId == item.releaseId)
        .toList(growable: false);
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 52,
                  height: 52,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: release.coverUrl.isNotEmpty
                        ? ResizedNetworkImage(
                            url: release.coverUrl,
                            physicalWidth: 160,
                          )
                        : const Icon(Icons.album, size: 32),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        release.title,
                        style: theme.textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (release.artists.isNotEmpty)
                        Text(
                          release.artists
                              .map((artist) => artist.name)
                              .join(' & '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      Text(
                        item.isAdOnly ? 'Reklámmal feloldva' : 'Megvásárolva',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: item.isAdOnly
                              ? theme.colorScheme.tertiary
                              : theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (final entry in entries) _buildEntryRow(item, entry),
          ],
        ),
      ),
    );
  }

  /// Egy kiadvány, ami **már nincs** a nyilvános listában (törölt/elrejtett).
  Widget _buildUnavailableCard(LabelLibraryItem item) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(
          children: [
            Icon(Icons.cloud_off, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ez a kiadvány már nem elérhető',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    item.isAdOnly
                        ? 'Korábban reklámmal feloldottad (kiadvány #${item.releaseId}), '
                              'de a kiadvány már nincs a nyilvános listában.'
                        : 'Megvásároltad (kiadvány #${item.releaseId}), de a '
                              'kiadvány már nincs a nyilvános listában.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryRow(LabelLibraryItem item, LabelQueueEntry entry) {
    final downloaded = _downloaded.contains(entry.key);
    final progress = _downloads.progressOf(entry.key);
    final failed = _downloads.hasFailed(entry.key);
    final isCurrent =
        _currentIndex >= 0 &&
        _currentIndex < _queue.length &&
        _queue[_currentIndex].key == entry.key;
    final playing = isCurrent && _player.playing;
    final unlockedOnly = item.unlocked.contains(entry.variant);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          IconButton(
            tooltip: playing ? 'Szünet' : 'Lejátszás',
            onPressed: progress != null
                ? null
                : () => isCurrent
                      ? _togglePlay()
                      : _playIndex(_queue.indexOf(entry)),
            icon: Icon(
              progress != null
                  ? Icons.downloading
                  : playing
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_fill,
              color: isCurrent ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.variantLabel,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (unlockedOnly) ...[
                      const SizedBox(width: 6),
                      Chip(
                        label: const Text('reklám'),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        labelStyle: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ],
                ),
                Text(
                  progress != null
                      ? 'Letöltés… ${(progress * 100).round()}%'
                      : failed
                      ? 'A letöltés nem sikerült — próbáld újra'
                      : downloaded
                      ? 'Letöltve a készüléken'
                      : 'Nincs letöltve',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (progress != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, right: 8),
                    child: LinearProgressIndicator(value: progress),
                  ),
              ],
            ),
          ),
          if (downloaded && progress == null)
            IconButton(
              tooltip: 'Törlés a készülékről (a vásárlás megmarad)',
              onPressed: () => _confirmDelete(entry),
              icon: const Icon(Icons.delete_outline),
            )
          else if (progress == null)
            IconButton(
              tooltip: 'Letöltés',
              onPressed: () => _downloadOnly(entry),
              icon: const Icon(Icons.download_outlined),
            ),
        ],
      ),
    );
  }
}

class _Scaffold extends StatelessWidget {
  const _Scaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Megvásárolt zenéim')),
    body: SafeArea(child: child),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 44),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(body, textAlign: TextAlign.center),
      ],
    ),
  );
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        const Icon(Icons.info_outline, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ],
    ),
  );
}
