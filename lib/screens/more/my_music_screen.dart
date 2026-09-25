import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/errors/user_facing_error.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/i18n/tr.dart';
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
import '../../services/label_playlist_membership.dart';
import '../../services/label_release_availability.dart';
import '../../services/music_audio_handler.dart';
import '../../services/music_queue_player.dart';
import '../../widgets/app_text.dart';
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
///  3. **Csak letöltött zene játszható**, és a lapozás közben **nincs letöltés**:
///     a sor eleve a letöltött (és a listán hagyott) tételekből áll.
///  4. **A léptetés nem itt dől el** ([MusicQueuePlayer]): a képernyő csak az
///     **alap-sorrendet** adja át (mi van letöltve, mi van kivéve, mi a kézi
///     sorrend), a „következő"/„előző" és a dal végi továbblépés a
///     háttér-szolgáltatásban történik — ezért a képernyő elhagyása után sem
///     hal meg a zárképernyő gombja.

class MyMusicScreen extends ConsumerStatefulWidget {
  const MyMusicScreen({super.key});

  @override
  ConsumerState<MyMusicScreen> createState() => _MyMusicScreenState();
}

class _MyMusicScreenState extends ConsumerState<MyMusicScreen> {
  /// A háttér-lejátszó (zárképernyő + értesítés), ha elindult.
  ///
  /// MIÉRT lehet `null`: ha az `AudioService` nem indul el (régi készülék,
  /// szolgáltatás-hiba), a lejátszó **a képernyőn belül** ugyanúgy működik —
  /// ilyenkor a saját példányunkat használjuk. Ez a szándékos tartalék, nem
  /// hibaág.
  MusicAudioHandler? _handler;
  AudioPlayer? _ownedPlayer;

  /// A **tartalék** sor (csak akkor, ha nincs háttér-szolgáltatás).
  ///
  /// A lejátszás és a léptetés ugyanazt az osztályt használja, mint a
  /// szolgáltatás (`MusicQueuePlayer`) — ezért nincs kétféle viselkedés.
  MusicQueuePlayer? _ownSession;

  /// A **lejátszási sor**: a háttér-szolgáltatásé, vagy a saját tartalékunk.
  ///
  /// A léptetés, az ismétlés és a dal végi továbblépés **nem itt** dől el, ezért
  /// a képernyő elhagyása után is működik (ez volt a korábbi korlát: a
  /// zárképernyő gombja néma maradt, a dal végén pedig megállt a zene).
  MusicQueuePlayer get _session =>
      _handler?.session ??
      (_ownSession ??= MusicQueuePlayer(
        player: _ownedPlayer ??= AudioPlayer(),
        onStopRequested: (_) => _releaseAudio(),
      ));

  /// A lejátszó, akár a háttér-szolgáltatásé, akár a sajátunk.
  AudioPlayer get _player =>
      _handler?.player ?? (_ownedPlayer ??= AudioPlayer());

  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;

  final Set<String> _downloaded = <String>{};
  int _currentIndex = -1;
  bool _busy = false;
  bool _resumeRadioAfterStop = false;
  String? _message;
  int _storageBytes = 0;

  /// A **lejátszási sorrend** (a sor indexei) — a szolgáltatás sorának a tükre.
  ///
  /// MIÉRT külön a `_queue`-tól: a keverés a sorrendet változtatja, nem a
  /// tartalmat — a kurzor viszont mindig a **sorrendben** lépked. Az igazság a
  /// `_session.tracks` (a szolgáltatásé); ez a lista csak a kirajzoláshoz kell,
  /// és a szolgáltatás jelzésére épül újra (`_onSessionTracks`).
  List<int> _order = const [];

  /// Ismétlés módja (nincs / mind / egy) és a keverés állapota — a szolgáltatás
  /// állapotának a tükre (a döntés ott van).
  PlaybackRepeat _repeat = PlaybackRepeat.none;
  bool _shuffle = false;

  /// A **letöltött** tételek lenyomata: ebből tudjuk, változott-e a készlet
  /// (ilyenkor érdemes a mentett „folytatás" pontot is újra megnézni).
  String _downloadedSignature = '';

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

  /// A **lejátszási listáról kivett** tételek (fiókonként, helyben tárolva).
  ///
  /// A tulajdonos kérése: *„zenét hogy tud a playlistre rakni/levenni"* — a
  /// kivett tétel **a készüléken marad** (nem kell újra letölteni), csak nem
  /// szól bele a sorba, és a listában sem szerepel.
  final LabelPlaylistMembership _playlist = LabelPlaylistMembership();
  Set<String> _excludedFromPlaylist = <String>{};

  /// A lista **kézi sorrendje** (fiókonként mentve) — a fel/le mozgatás
  /// eredménye. Ami nincs benne, az a könyvtár sorrendjében a végére kerül.
  List<String> _playlistOrder = const [];

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

  /// A „nincs meg a nyilvános listában" jelölés **megmarad** a következő
  /// megnyitásra is (24 óráig), különben minden alkalommal újra lekérdeznénk a
  /// WordPressből (`getRelease`) — az pedig mért érték szerint **0,4–2 másodperc**.
  final LabelReleaseAvailability _availability = LabelReleaseAvailability();

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
    // A háttér-lejátszó **sora az övé** (ezért a zárképernyő gombja a képernyő
    // elhagyása után is működik), a képernyő pedig csak az **alap-sorrendet**
    // adja át, és kirajzolja az állapotot.
    _handler = ref.read(musicAudioHandlerProvider);
    final session = _session;
    session.tracks.addListener(_onSessionTracks);
    session.currentKey.addListener(_onSessionCurrent);
    session.repeat.addListener(_onSessionModes);
    session.shuffle.addListener(_onSessionModes);
    session.errorMessage.addListener(_onSessionError);
    _repeat = session.repeat.value;
    _shuffle = session.shuffle.value;
    _stateSubscription = _player.playerStateStream.listen((state) {
      // ⚠️ A dal **végén** NEM itt lépünk tovább: azt a szolgáltatás végzi
      // (`MusicQueuePlayer`). Ha itt is lenne egy léptető, két helyen lenne
      // ugyanaz a döntés — és a képernyő elhagyása után nem is lenne, aki lépjen.
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
    unawaited(_loadReleaseAvailability());
    unawaited(_loadPlaylistMembership());
    // Ha a zene a háttérben tovább szólt (a képernyőt elhagytuk), a visszatéréskor
    // a **szolgáltatás sora a hiteles forrás**: ahhoz igazítjuk a kijelzést.
    _syncWithBackgroundPlayback();
  }

  /// A **sorrend** követése: a kirajzolt `_order` a szolgáltatás sorából épül.
  void _onSessionTracks() {
    final indexByKey = <String, int>{
      for (var i = 0; i < _queue.length; i++) _queue[i].key: i,
    };
    final order = <int>[];
    for (final track in _session.tracks.value) {
      final index = indexByKey[track.key];
      if (index != null) order.add(index);
    }
    _order = order;
    if (mounted) setState(() {});
  }

  /// Az **aktuális tétel** követése: a szolgáltatás dönt, a felület csak mutatja.
  void _onSessionCurrent() {
    final key = _session.currentKey.value;
    final index = key == null
        ? -1
        : _queue.indexWhere((entry) => entry.key == key);
    _currentIndex = index;
    if (index >= 0) _resumePoint = null;
    if (!mounted) return;
    setState(() {
      _position = _player.position;
      _seekValue = _position.inMilliseconds.toDouble();
    });
  }

  /// Az **ismétlés/keverés** követése (a zárképernyőről is változhat).
  void _onSessionModes() {
    final session = _session;
    _repeat = session.repeat.value;
    _shuffle = session.shuffle.value;
    if (mounted) setState(() {});
  }

  /// A lejátszó **magyar** hibaüzenetének kijelzése (egyszeri üzenet).
  void _onSessionError() {
    final session = _session;
    final message = session.errorMessage.value;
    if (message == null) return;
    session.errorMessage.value = null;
    if (!mounted) return;
    setState(() => _message = message);
  }

  /// A háttérben szóló zene visszakapcsolása a felületre (a képernyő megnyitásakor).
  ///
  /// A **sor a szolgáltatásé**, ezért nincs mit „visszaadni": elég a mostani
  /// állapotot átvenni (sorrend, kurzor, ismétlés, keverés) — így a kijelzés
  /// akkor is helyes, ha közben a zárképernyőről léptettek.
  void _syncWithBackgroundPlayback() {
    _onSessionTracks();
    _onSessionCurrent();
    _onSessionModes();
    _position = _player.position;
    _seekValue = _position.inMilliseconds.toDouble();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    unawaited(_saveProgress(force: true));
    _stateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    final session = _handler?.session ?? _ownSession;
    session?.tracks.removeListener(_onSessionTracks);
    session?.currentKey.removeListener(_onSessionCurrent);
    session?.repeat.removeListener(_onSessionModes);
    session?.shuffle.removeListener(_onSessionModes);
    session?.errorMessage.removeListener(_onSessionError);
    // ⚠️ A **sort nem bontjuk le**, és a zenét **nem állítjuk le**: pont ez a
    // háttér-lejátszás lényege (a zárképernyő következő/előző gombja is ezért
    // működik tovább). A hang visszaadását a rádiónak a szolgáltatás intézi,
    // amikor a zárképernyőn/értesítésben megállítják (`resumeRadioWhenStopped`).
    final handler = _handler;
    if (handler != null) {
      handler.resumeRadioWhenStopped = _resumeRadioAfterStop;
      if (!handler.player.playing) {
        // Ha épp nem szól, nincs mit háttérben tartani: a szokásos lejárás.
        unawaited(_releaseAudio());
      }
    } else {
      // ⚠️ A saját lejátszót csak a leállás **befejezése után** dobjuk el,
      // különben a `stop()`/rádió-visszaadás egy már lezárt lejátszón futna.
      final owned = _ownedPlayer;
      final ownSession = _ownSession;
      unawaited(
        _releaseAudio().whenComplete(() async {
          await ownSession?.dispose();
          await owned?.dispose();
        }),
      );
    }
    super.dispose();
  }

  String get _uid => _uidValue;

  /// A kurzor a **lejátszási sorrendben** (nem a nyers sorban).
  int get _cursor => _order.indexOf(_currentIndex);

  /// Az **alap-sorrend** átadása a szolgáltatásnak — ez az egyetlen bemenet.
  ///
  /// A sor a **lejátszható** tételek listája: letöltött, nincs kivéve, a kézi
  /// sorrend szerint, **fájlútvonallal**. A keverést és a léptetést a szolgáltatás
  /// végzi ([MusicQueuePlayer]), ezért a képernyő elhagyása után is működik a
  /// zárképernyő gombja és a dal végi továbblépés.
  ///
  /// A most hallgatott tételt a szolgáltatás **kulcs alapján** keresi vissza, így
  /// egy új pásztázás (új vásárlás, törölt fájl, átrendezés) nem szakítja meg azt,
  /// ami épp szól.
  void _pushBaseOrder(Map<String, String> paths) {
    final indices = orderedPlaylistIndices(
      keys: [for (final entry in _queue) entry.key],
      downloaded: paths.keys.toSet(),
      excluded: _excludedFromPlaylist,
      customOrder: _playlistOrder,
    );
    _session.setBaseOrder([
      for (final index in indices)
        MusicQueueTrack(
          key: _queue[index].key,
          filePath: paths[_queue[index].key]!,
          item: _mediaItemFor(_queue[index]),
        ),
    ]);
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

  /// A korábban „nem elérhetőnek" jelölt kiadványok betöltése a tárolóból.
  ///
  /// Ez teszi **azonnalivá** a kártyát: a címe helyett nem „betöltés" látszik,
  /// hanem rögtön az, hogy ez a kiadvány már nincs a nyilvános listában.
  Future<void> _loadReleaseAvailability() async {
    try {
      final missing = await _availability.loadMissing();
      if (!mounted || missing.isEmpty) return;
      setState(() => _unavailableReleases.addAll(missing));
    } catch (_) {
      // A tároló hibája nem akadályozhatja a könyvtárat — ilyenkor egyszerűen
      // újra lekérdezzük a hiányzó kiadványokat.
    }
  }

  /// A lejátszási listáról **kivett** tételek betöltése (fiókonként).
  Future<void> _loadPlaylistMembership() async {
    final uid = _uid;
    if (uid.isEmpty) return;
    try {
      final excluded = await _playlist.load(uid);
      final order = await _playlist.loadOrder(uid);
      if (!mounted || (excluded.isEmpty && order.isEmpty)) return;
      setState(() {
        _excludedFromPlaylist = excluded;
        _playlistOrder = order;
      });
      // A sorrendet a következő pásztázás adja át a szolgáltatásnak.
      unawaited(_scanDownloads());
    } catch (_) {
      // A tároló hibája nem akadályozhatja a lejátszást: ilyenkor minden a
      // listán marad (ez a biztonságos irány).
    }
  }

  /// Egy tétel **mozgatása** a listában (`delta` = `-1` fel, `+1` le).
  ///
  /// A látható sorrendet mentjük el kézi sorrendként — így a mozgatás után az
  /// lesz az érvényes sorrend, és az újonnan letöltött tételek a végére kerülnek.
  Future<void> _movePlaylistEntry(LabelQueueEntry entry, int delta) async {
    final uid = _uid;
    if (uid.isEmpty) return;
    final currentKeys = [
      for (final index in _order)
        if (index >= 0 && index < _queue.length) _queue[index].key,
    ];
    final position = currentKeys.indexOf(entry.key);
    if (position < 0) return;
    final next = moveInOrder(currentKeys, position, delta);
    if (listEquals(next, currentKeys)) return;
    setState(() {
      _playlistOrder = next;
      _message = null;
    });
    // A kézi sorrend a szolgáltatás **alap-sorrendje**, ezért újra átadjuk neki.
    unawaited(_scanDownloads());
    try {
      await _playlist.saveOrder(uid, next);
    } catch (_) {
      // A mentés hibája nem akadályozhatja a lejátszást.
    }
  }

  /// Egy tétel ki-/bevétele a lejátszási listából.
  ///
  /// A tulajdonos kérése: *„zenét hogy tud a playlistre rakni/levenni"*. A
  /// fájlt **nem** törli (az a külön kuka gomb): csak arról dönt, hogy a tétel
  /// **beleszól-e a sorba**. Ha épp ez szólt, a kivétel **megállítja** — így a
  /// sáv nem mutat olyat, ami már nincs a listán.
  Future<void> _togglePlaylistMembership(LabelQueueEntry entry) async {
    final uid = _uid;
    if (uid.isEmpty) return;
    final wasExcluded = _excludedFromPlaylist.contains(entry.key);
    final next = <String>{..._excludedFromPlaylist};
    if (wasExcluded) {
      next.remove(entry.key);
    } else {
      next.add(entry.key);
    }
    final isCurrent =
        _currentIndex >= 0 &&
        _currentIndex < _queue.length &&
        _queue[_currentIndex].key == entry.key;
    final stopCurrent = !wasExcluded && isCurrent;
    setState(() {
      _excludedFromPlaylist = next;
      if (stopCurrent) _currentIndex = -1;
      _message = wasExcluded
          ? AppStrings.tr('Visszatéve a lejátszási listára.')
          : AppStrings.tr('Kivéve a lejátszási listából — a fájl a készüléken marad.');
    });
    // A kivétel/betevés az alap-sorrendet változtatja: a szolgáltatás kapja meg.
    unawaited(_scanDownloads());
    if (stopCurrent) await _releaseAudio();
    try {
      await _playlist.save(uid, next);
    } catch (_) {
      // A mentés hibája nem akadályozhatja a lejátszást.
    }
  }

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
        // Ha mégis megvan (újra közzétették), a jelölést is töröljük.
        unawaited(_availability.clear(releaseId));
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _unavailableReleases.add(releaseId);
          _resolvingReleases.remove(releaseId);
        });
        // A jelölés megmarad a következő megnyitásra is (24 óra), hogy ne
        // kérdezzük le újra ugyanazt a WordPressből minden alkalommal.
        unawaited(_availability.markMissing(releaseId));
      }
    }
  }

  Future<String> _urlFor(LabelQueueEntry entry) => ref
      .read(labelLibraryServiceProvider)
      .downloadUrl(releaseId: entry.releaseId, variant: entry.variant);

  /// A meglévő fájlok és a helyfoglalás frissítése (a sor előállítása után).
  Future<void> _scanDownloads() async {
    // ⚠️ PILLANATKÉP: a pásztázás aszinkron, ezért a **sor lenyomatát** is
    // elmentjük. Ha közben a sor kicserélődött (a `build` új queue-t épített),
    // az eredmény elavult — kidobjuk, különben a `_downloaded` és az abból épülő
    // `_order` más állapotból származna (élesben innen lett „1/1 · 15 letöltve":
    // a sorrend egy szűk, régi pillanatképből maradt meg).
    final queue = _queue;
    final queueSignature = _queueSignature;
    final downloaded = <String>{};
    // A **fájlútvonalakat is** begyűjtjük: a szolgáltatás ezekből játszik, ezért
    // egy menetben derül ki, hogy mi van meg, és az is, hogy honnan szól.
    final paths = <String, String>{};
    var storage = 0;
    try {
      for (final entry in queue) {
        final file = await _downloads.fileFor(entry);
        if (await file.exists()) {
          downloaded.add(entry.key);
          paths[entry.key] = file.path;
        }
      }
      storage = await _downloads.totalBytes();
    } catch (_) {
      // Vendég fióknál (nincs mappa) nincs mit pásztázni — nem hiba.
      downloaded.clear();
      paths.clear();
      storage = 0;
    }
    if (!mounted) return;
    if (queueSignature != _queueSignature) {
      // Elavult pásztázás: a sor közben kicserélődött, jön az új pásztázás.
      return;
    }
    final signature = _signatureOf(downloaded);
    final changed = signature != _downloadedSignature;
    // ⚠️ A sorrendet **mindig** a szolgáltatásnak adjuk át, és nem tartunk róla
    // párhuzamos másolatot: két lista ugyanarra a kérdésre garantáltan széthúzna
    // (a 342-es hiba pontosan ez volt). A kevert sorrend így is megmarad — a
    // szolgáltatás a most hallgatott tételt kulcs alapján visszakeresi, és
    // változatlan alapnál nem kever újra.
    _pushBaseOrder(paths);
    _downloadedSignature = signature;
    setState(() {
      _downloaded
        ..clear()
        ..addAll(downloaded);
      _storageBytes = storage;
      if (_currentIndex >= queue.length) _currentIndex = -1;
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

  /// Egy tétel indítása a **sorban** (a képernyő indexei szerint).
  ///
  /// A döntés (mi következik, mi az aktuális tétel) a **szolgáltatásé**: itt csak
  /// a **bemeneti kapuk** vannak (csak letöltött zene játszható, a rádió átadja a
  /// hangot), a többi a [MusicQueuePlayer]-ben történik — ezért a zárképernyőről
  /// indított léptetés és a dal végi továbblépés ugyanígy működik, akkor is, ha a
  /// képernyő már nincs nyitva.
  Future<void> _playIndex(int index, {int? startAtMs}) async {
    if (!mounted) return;
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
    // A rádió és a lejátszó ne szóljon egyszerre — ugyanaz a minta, mint a
    // kiadvány-előhallgatónál.
    if (!releasePreviewPlayingState.value) {
      _resumeRadioAfterStop = await isRadioPlaybackActive();
      if (_resumeRadioAfterStop) await stopRadioPlayback();
      if (mounted) releasePreviewPlayingState.value = true;
    }
    _handler?.resumeRadioWhenStopped = _resumeRadioAfterStop;
    _resumePoint = null;
    _lastSavedMs = startAtMs ?? 0;
    final session = _session;
    // A tételt a **szolgáltatás sorában** keressük meg a kulcsa alapján: így a
    // koppintás akkor is a jó zenét indítja, ha a lista közben elmozdult.
    var position = session.tracks.value.indexWhere(
      (track) => track.key == entry.key,
    );
    if (position < 0) {
      // A sor még nem ismeri (frissen megnyitott képernyő, friss letöltés):
      // egyszer átadjuk neki a fájlútvonalakkal együtt, és újra keressük.
      await _scanDownloads();
      position = session.tracks.value.indexWhere(
        (track) => track.key == entry.key,
      );
    }
    if (position < 0) {
      if (mounted) {
        setState(() => _message = 'Ez a tétel most nincs a lejátszási listán.');
      }
      return;
    }
    await session.playAt(position, startAtMs: startAtMs);
    if (mounted) setState(() => _message = null);
  }

  /// A tételhez tartozó médiamunkamenet-adat (cím, előadó, borító).
  ///
  /// A **sor közzététele** (értesítés, zárképernyő) már nem itt történik: azt a
  /// szolgáltatás végzi a saját sorából (`MusicAudioHandler._publishSession`),
  /// ezért a képernyő elhagyása után is helyes marad a cím és a hossz.
  MediaItem _mediaItemFor(LabelQueueEntry entry) => MediaItem(
    id: entry.key,
    title: entry.title.isEmpty ? entry.nowPlayingLabel : entry.title,
    artist: entry.artist.isEmpty ? 'Hungarian Hardstyle' : entry.artist,
    album: entry.variantLabel,
    artUri: entry.coverUrl.isEmpty ? null : Uri.tryParse(entry.coverUrl),
  );

  /// A „következő" gomb: a sorrendben lép (ismétlés-egy mellett is tovább).
  ///
  /// ⚠️ A döntés a **szolgáltatásé** ([MusicQueuePlayer]), ezért a zárképernyő
  /// gombja pontosan ezt teszi — és akkor is működik, ha a képernyő nincs nyitva.
  /// A **dal végi** automatikus továbblépés szintén ott van, nem itt: ha itt is
  /// lenne léptető, két helyen lenne ugyanaz a döntés.
  Future<void> _playNext() async {
    await _session.next();
  }

  /// Az „előző" gomb: a sorrendben lép vissza (a sor elején az ismétlés dönt).
  Future<void> _playPrevious() async {
    await _session.previous();
  }

  /// **Stop**: megáll, a szám elejére áll, és a rádió visszakapja a hangot.
  ///
  /// Szándékosan **nem** ugyanaz, mint a szünet: a szünetnél a lejátszás helye
  /// megmarad (és a rádió hallgat), a stopnál viszont elölről kezdhető, ezért a
  /// mentett folytatási pontot is töröljük.
  Future<void> _stopPlayback() async {
    // A leállítást a `_releaseAudio` végzi (az veszi le a háttér-értesítést is),
    // ezért itt nem hívunk külön lejátszó-műveletet.
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
  ///
  /// **Háttér-szolgáltatás esetén** a leállítást a szolgáltatás végzi
  /// (`handler.stop()`), mert az értesítést is **le kell venni** — különben ott
  /// maradna egy halott lejátszó a zárképernyőn. A hang visszaadása ugyanígy a
  /// szolgáltatásban történik (`resumeRadioWhenStopped`), ezért az a
  /// zárképernyőről indított stopnál is működik.
  Future<void> _releaseAudio() async {
    final handler = _handler;
    if (handler != null) {
      handler.resumeRadioWhenStopped = _resumeRadioAfterStop;
      await handler.stop();
      // ⚠️ A jelzőket a **leállítás után** állítjuk: ha a stop hibázik, a
      // „zene szól" jelzés ne vesszen el (különben a rádió gombja némán
      // működésképtelen lenne).
      _resumeRadioAfterStop = false;
      releasePreviewPlayingState.value = false;
      return;
    }
    // ⚠️ Csak akkor van mit leállítani, ha ebben a képernyőben már indult zene:
    // a `_session` getter **létrehozná** a lejátszót, ha még nem létezik (az
    // fölösleges erőforrás lenne egy üres képernyőn).
    await _ownSession?.stop();
    releasePreviewPlayingState.value = false;
    if (_resumeRadioAfterStop) {
      _resumeRadioAfterStop = false;
      await resumeRadioPlayback();
    }
  }

  /// A „lejátszás/szünet" gomb: a döntés a szolgáltatásé (`MusicQueuePlayer`).
  ///
  /// Így ugyanezt teszi a zárképernyő play gombja is — és akkor is működik, ha a
  /// képernyő nincs nyitva.
  Future<void> _togglePlay() async {
    if (!mounted) return;
    final session = _session;
    // A rádió és a lejátszó ne szóljon egyszerre (ugyanaz a minta, mint a
    // kiadvány-előhallgatónál): a sor első tételének indítása előtt átvesszük a
    // hangot.
    if (!releasePreviewPlayingState.value && !session.isPlaying) {
      _resumeRadioAfterStop = await isRadioPlaybackActive();
      if (_resumeRadioAfterStop) await stopRadioPlayback();
      if (mounted) releasePreviewPlayingState.value = true;
      _handler?.resumeRadioWhenStopped = _resumeRadioAfterStop;
    }
    await session.toggle(startAtMs: _position.inMilliseconds);
    if (mounted) setState(() {});
  }

  /// Az ismétlés mód léptetése (nincs → mind → egy → nincs).
  ///
  /// A döntés a szolgáltatásé: ugyanezt teszi a zárképernyő is, és az állapot
  /// onnan is visszajön (`_onSessionModes`).
  void _cycleRepeat() {
    _session.setRepeat(nextPlaybackRepeat(_session.repeat.value));
  }

  /// A keverés be/ki. Bekapcsoláskor az aktuális tétel az első helyre kerül.
  ///
  /// A kevert sorrendet a szolgáltatás állítja elő (`MusicQueuePlan`), és változatlan
  /// alap-sorrendnél **nem kever újra** — így a fájlpásztázás nem ugráltatja a
  /// „következő" tételt.
  void _toggleShuffle() {
    _session.setShuffle(!_session.shuffle.value);
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
            child: const AppText('Mégsem'),
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
      AppStrings.tr('Törlés a készülékről'),
      'A(z) „${entry.nowPlayingLabel}" letöltött fájlja törlődik. '
          'A vásárlás megmarad, ezért bármikor újra letöltheted.',
      AppStrings.tr('Törlés'),
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
      AppStrings.tr('Letöltött zenék törlése'),
      AppStrings.tr('Minden letöltött fájl törlődik a készülékről. A vásárlásaid '
          'megmaradnak, bármikor újra letölthetők.'),
      AppStrings.tr('Törlés'),
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
      return _Scaffold(
        child: _Notice(
          icon: Icons.lock_outline,
          title: tr(context, 'A zenéidhez jelentkezz be'),
          body:
              tr(context, 'A megvásárolt zenék a fiókodhoz tartoznak, ezért csak '
              'bejelentkezve láthatók és tölthetők le.'),
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
          title: tr(context, 'A zenéid most nem érhetők el'),
          body: userFacingError(error),
        ),
        data: (items) => releases.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _Notice(
            icon: Icons.cloud_off,
            title: tr(context, 'A kiadványok most nem érhetők el'),
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
              // másik zenére lépne). A sorrendet nem itt építjük: azt a pásztázás
              // adja át a szolgáltatásnak (`_pushBaseOrder`), amely a most szóló
              // tételt szintén kulcs alapján tartja meg.
              final playingKey =
                  _currentIndex >= 0 && _currentIndex < _queue.length
                  ? _queue[_currentIndex].key
                  : null;
              _queueSignature = signature;
              _queue = queue;
              _currentIndex = playingKey == null
                  ? -1
                  : queue.indexWhere((entry) => entry.key == playingKey);
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
    // A tulajdonos kérése (2026-09-21): *„a megvásárolt zenék között ne
    // látszódjon a már eltávolított kiadvány, felesleges"* — ezért a nyilvános
    // katalógusból eltűnt kiadvány **egyáltalán nem kap kártyát** (a feloldása
    // persze megmarad, és ha visszakerül a katalógusba, újra megjelenik).
    final visible = visibleLibraryItems(
      items,
      unavailable: _unavailableReleases,
    );
    if (visible.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const SizedBox(height: 40),
          _Notice(
            icon: Icons.library_music_outlined,
            title: tr(context, 'Még nincs megvásárolt zenéd'),
            body:
                tr(context, 'A Kiadványok fülön megvásárolt (vagy reklámmal feloldott) '
                'zenék itt jelennek meg, és innen játszhatók le.'),
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ReleasesScreen()),
              ),
              icon: const Icon(Icons.album_outlined),
              label: const AppText('Kiadványok böngészése'),
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
                    ? '${visible.length} kiadvány · ${_queue.length} tétel · '
                          '${_formatBytes(_storageBytes)} a készüléken'
                    : '${visible.length} kiadvány · ${_queue.length} tétel',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (_storageBytes > 0)
              TextButton.icon(
                onPressed: _deleteAll,
                icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                label: const AppText('Tárhely ürítése'),
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (_resumePoint != null) _buildResumeBanner(),
        if (_queue.isNotEmpty) _buildPlayerBar(),
        for (final item in visible) _buildReleaseCard(item),
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
    // ⚠️ VÉDELEM: a sor a háttérben változhat (új vásárlás, eltűnt kiadvány), és
    // ilyenkor a mentett tétel kikerülhet belőle. `firstWhere` nélkül ez a
    // `build`-ben dobna — ezért itt csendben eltűnik a felajánlás.
    final index = _queue.indexWhere((item) => item.key == point.entryKey);
    if (index < 0) return const SizedBox.shrink();
    final entry = _queue[index];
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
              child: const AppText('Elölről'),
            ),
            FilledButton(
              onPressed: () => _playIndex(index, startAtMs: point.positionMs),
              child: const AppText('Folytatás'),
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
            : live.inMilliseconds.toDouble().clamp(
                0.0,
                maxMs == 0 ? 1.0 : maxMs,
              );
        final shown = _seeking ? _seekValue : live.inMilliseconds.toDouble();
        final enabled = maxMs > 0;
        return Row(
          children: [
            Text(
              playbackClock(shown.round()),
              style: theme.textTheme.bodySmall,
            ),
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
        // A panel **magától frissül**, amikor egy tételt kiveszünk a listából
        // (különben a kivett sor ott maradna a képernyőn).
        return StatefulBuilder(
          builder: (sheetContext, sheetSetState) {
            final entries = [
              for (final index in _order)
                if (index >= 0 && index < _queue.length)
                  (index: index, entry: _queue[index]),
            ];
            final pending = _queue.length - entries.length;
            final excludedCount = _excludedFromPlaylist.length;
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: AppText(
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
                          subtitle: Text(
                            item.entry.variantLabel,
                            style: theme.textTheme.bodySmall,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Keverés közben a sorrend nem értelmezhető, ezért
                              // ilyenkor a nyilak le vannak tiltva (és a lábléc
                              // meg is mondja, mit kell tenni).
                              IconButton(
                                tooltip: tr(context, 'Feljebb'),
                                visualDensity: VisualDensity.compact,
                                onPressed: (position == 0 || _shuffle)
                                    ? null
                                    : () async {
                                        await _movePlaylistEntry(
                                          item.entry,
                                          -1,
                                        );
                                        if (sheetContext.mounted) {
                                          sheetSetState(() {});
                                        }
                                      },
                                icon: const Icon(Icons.keyboard_arrow_up),
                              ),
                              IconButton(
                                tooltip: tr(context, 'Lejjebb'),
                                visualDensity: VisualDensity.compact,
                                onPressed:
                                    (position == entries.length - 1 || _shuffle)
                                    ? null
                                    : () async {
                                        await _movePlaylistEntry(item.entry, 1);
                                        if (sheetContext.mounted) {
                                          sheetSetState(() {});
                                        }
                                      },
                                icon: const Icon(Icons.keyboard_arrow_down),
                              ),
                              IconButton(
                                tooltip: tr(context, 'Kivétel a lejátszási listából'),
                                visualDensity: VisualDensity.compact,
                                onPressed: () async {
                                  await _togglePlaylistMembership(item.entry);
                                  if (sheetContext.mounted) {
                                    sheetSetState(() {});
                                  }
                                },
                                icon: const Icon(Icons.playlist_remove),
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            unawaited(_playIndex(item.index));
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (pending > 0)
                          AppText(
                            'A nem letöltött tételek nincsenek a listában — '
                            'azokat a kiadvány kártyáján tudod letölteni.',
                            style: theme.textTheme.bodySmall,
                          ),
                        if (excludedCount > 0)
                          Text(
                            '$excludedCount tétel kivéve a listából — a kártyákon '
                            'a lista ikonnal teheted vissza (a fájl megvan).',
                            style: theme.textTheme.bodySmall,
                          ),
                        if (_shuffle && entries.length > 1)
                          AppText(
                            'Keverés közben a sorrend nem szerkeszthető — '
                            'kapcsold ki a keverést a lejátszósávban.',
                            style: theme.textTheme.bodySmall,
                          )
                        else if (entries.length > 1)
                          AppText(
                            'A nyilakkal rendezheted a sorrendet — fiókonként '
                            'megjegyzi.',
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
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
                  tooltip: tr(context, 'Előző'),
                  onPressed: hasPrevious ? _playPrevious : null,
                  icon: const Icon(Icons.skip_previous),
                ),
                IconButton(
                  tooltip: _player.playing ? 'Szünet' : tr(context, 'Lejátszás'),
                  onPressed: _togglePlay,
                  icon: Icon(
                    _player.playing ? Icons.pause_circle : Icons.play_circle,
                    size: 34,
                  ),
                ),
                IconButton(
                  tooltip: tr(context, 'Következő'),
                  onPressed: hasNext ? _playNext : null,
                  icon: const Icon(Icons.skip_next),
                ),
                IconButton(
                  tooltip: tr(context, 'Stop (a szám elejére áll)'),
                  onPressed: hasCurrent ? _stopPlayback : null,
                  icon: const Icon(Icons.stop_circle_outlined),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry?.nowPlayingLabel ?? tr(context, 'Válassz egy zenét'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        hasCurrent
                            ? '${playbackPositionLabel(_cursor, _order.length)} · '
                                  '${_downloaded.length} letöltve'
                            : _downloaded.isEmpty
                            ? tr(context, 'Előbb tölts le egy zenét')
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
                  tooltip: _shuffle ? 'Keverés kikapcsolása' : tr(context, 'Keverés'),
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
                  label: const AppText('Lista'),
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
    // ⚠️ A nyilvános listából **eltűnt** kiadvány ide már nem jut el: azt a
    // `visibleLibraryItems` kiszűri a listából (a tulajdonos kérése: *„a
    // megvásárolt zenék között ne látszódjon a már eltávolított kiadvány,
    // felesleges"*). Ezért itt nincs külön „nem elérhető" kártya.
    if (release == null) {
      return Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          leading: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          title: const AppText('Kiadvány betöltése…'),
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
                        item.isAdOnly ? 'Reklámmal feloldva' : tr(context, 'Megvásárolva'),
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
            tooltip: playing ? 'Szünet' : tr(context, 'Lejátszás'),
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
                        label: const AppText('reklám'),
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
                      ? tr(context, 'A letöltés nem sikerült — próbáld újra')
                      : downloaded
                      ? tr(context, 'Letöltve a készüléken')
                      : tr(context, 'Nincs letöltve'),
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
              tooltip: _excludedFromPlaylist.contains(entry.key)
                  ? tr(context, 'Visszatétel a lejátszási listára')
                  : tr(context, 'Kivétel a lejátszási listából (a fájl megmarad)'),
              onPressed: () => _togglePlaylistMembership(entry),
              icon: Icon(
                _excludedFromPlaylist.contains(entry.key)
                    ? Icons.playlist_add
                    : Icons.playlist_remove,
              ),
            ),
          if (downloaded && progress == null)
            IconButton(
              tooltip: tr(context, 'Törlés a készülékről (a vásárlás megmarad)'),
              onPressed: () => _confirmDelete(entry),
              icon: const Icon(Icons.delete_outline),
            )
          else if (progress == null)
            IconButton(
              tooltip: tr(context, 'Letöltés'),
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
    appBar: AppBar(title: const AppText('Megvásárolt zenéim')),
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
