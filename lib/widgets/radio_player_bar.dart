import 'dart:async';

import 'package:flutter/material.dart';

import '../core/i18n/tr.dart';
import '../services/now_playing.dart';
import '../services/radio_metadata.dart';
import '../services/radio_playback.dart';
import '../services/radio_remote.dart';
import 'app_text.dart';

class RadioPlayerBar extends StatefulWidget {
  const RadioPlayerBar({super.key});

  @override
  State<RadioPlayerBar> createState() => _RadioPlayerBarState();
}

final radioPlayingState = ValueNotifier<bool>(false);
final releasePreviewPlayingState = ValueNotifier<bool>(false);
const _radioStreamUrl = 'https://stream.realhardstyle.nl';

Future<void> stopRadioPlayback() async {
  try {
    await radioPlayback.stop();
  } catch (_) {}
  radioPlayingState.value = false;
  // A rendszer felületéről (értesítés + zárképernyő) is eltűnik a cím.
  await nowPlayingReporter.stop();
  // ⚠️ Az állapotot is „leállt”-ra tesszük: enélkül a szívverés tovább
  // ismételné a „szól” állapotot egy leállított rádióhoz.
  await reportRadioNowPlayingState(NowPlayingPlaybackState.stopped);
}

/// **Szünet**: a hang elhallgat, de a vezérlő **ott marad**.
///
/// ⚠️ MIÉRT NEM `stop` (a tulajdonos jelzései, 2026-10-03): *„kéne egy pause gomb
/// is az értesítési és a zártképernyős rádió vezérlőre”* és *„néha eltűnik az
/// értesítési mezőből a rádió vezérlője”*. A rendszer felületét ezért **nem**
/// töröljük (`nowPlayingReporter.stop()` = a cím eltűnése, Androidon az
/// értesítés megszűnése): a „Folytatás” gombnak és a címnek a helyén kell
/// maradnia, hogy a felhasználó vissza tudjon jönni.
///
/// ⚠️ 2026-10-03: az **állapotot** viszont ki kell írni (`paused`) — az iOS
/// zárképernyője a `playbackState`-ből rajzolja a gombot, és enélkül „szól”
/// állapotban maradna (a tulajdonos jelzése: *„nincs pause gomb”*).
Future<void> pauseRadioPlayback() async {
  try {
    await radioPlayback.pause();
  } catch (_) {}
  radioPlayingState.value = false;
  await reportRadioNowPlayingState(NowPlayingPlaybackState.paused);
}

/// A **rendszer felületének az állapota** (iOS: `playbackState` + `playbackRate`).
///
/// ⚠️ MIÉRT KELL SZINKRON (mért hiba, 2026-10-04, a tulajdonos jelzése: *„play
/// van meg stop és ha rányomok a playre, egy pillre pause lesz belőle aztán
/// visszaáll … és szól a rádió”*): az állapotot **egyszer**, a szándék
/// pillanatában küldtük — a hang viszont csak a stream betöltése után indul, az
/// iOS pedig közben visszaállította a play gombot, és a `playbackRate` is
/// beleragadt a 0-ba.
///
/// Ezért három ponton írjuk ki: (1) minden állapotváltáskor, (2) amikor a hang
/// **tényleg** elindul (`radioAudioPlayingState`), (3) 5 másodpercenként
/// (szívverés) — így egyetlen kimaradt pillanat sem hagyja „play” állapotban a
/// zárképernyőt.
NowPlayingPlaybackState _nowPlayingState = NowPlayingPlaybackState.stopped;
Timer? _nowPlayingHeartbeat;

/// Az állapot kiírása **és** megjegyzése (a szívverés ezt ismétli).
Future<void> reportRadioNowPlayingState(NowPlayingPlaybackState state) async {
  _nowPlayingState = state;
  _refreshNowPlayingHeartbeat();
  await NowPlayingReporter.reportState(state);
}

/// A szívverés beállítása: **álló** rádiónál nincs (nem pörög feleslegesen),
/// szólónál/szüneteltnél 5 másodpercenként megismétli ugyanazt az állapotot.
void _refreshNowPlayingHeartbeat() {
  _nowPlayingHeartbeat?.cancel();
  _nowPlayingHeartbeat = null;
  if (_nowPlayingState == NowPlayingPlaybackState.stopped) return;
  _nowPlayingHeartbeat = Timer.periodic(const Duration(seconds: 5), (_) {
    if (_nowPlayingState == NowPlayingPlaybackState.stopped) return;
    unawaited(NowPlayingReporter.reportState(_nowPlayingState));
  });
}

void _onRadioAudioStateChanged() {
  if (_nowPlayingState == NowPlayingPlaybackState.stopped) return;
  // A hang tényleg elindult (vagy elhallgatott): azonnal újra kiírjuk.
  unawaited(
    NowPlayingReporter.reportState(
      radioPlayingState.value
          ? NowPlayingPlaybackState.playing
          : NowPlayingPlaybackState.paused,
    ),
  );
}

/// A szinkron bekötése (az induláskor, egyszer).
void startRadioNowPlayingSync() {
  radioAudioPlayingState.removeListener(_onRadioAudioStateChanged);
  radioAudioPlayingState.addListener(_onRadioAudioStateChanged);
}

/// A **távvezérlő** (zárképernyő, fejhallgató-gombok, értesítés) bekötése.
///
/// MIÉRT (mért hiány, 2026-10-03): az iOS-oldalon a `just_audio` **nem** köti be
/// a `MPRemoteCommandCenter`-t (a csomag `darwin` forrásaiban nincs rá hivatkozás),
/// az `AppDelegate.swift` pedig eddig csak a „Most szól” panel tartalmát írta —
/// ezért a zárképernyő gombjai hatástalanok voltak. A parancs értelmezése és a
/// műveletek itt, a valódi rádió-életcikluson mennek át (ugyanaz, amit a felület
/// használ), ezért nem tud széthúzni a kettő.
void bindRadioRemoteCommands() {
  bindRadioRemoteChannel(
    NowPlayingReporter.appleChannel,
    play: resumeRadioPlayback,
    pause: pauseRadioPlayback,
    stop: stopRadioPlayback,
    isPlaying: isRadioPlaybackActive,
  );
  // Az állapot-szinkron (szívverés) is itt indul — az app indításakor egyszer.
  startRadioNowPlayingSync();
}

Future<void> resumeRadioPlayback() async {
  try {
    await radioPlayback.play(_radioStreamUrl);
    radioPlayingState.value = true;
    nowPlayingReporter.start();
    // Az ÁLLAPOT is kimegy (iOS: `playbackState = .playing`) — ettől jelenik meg
    // a zárképernyőn a pause gomb.
    await reportRadioNowPlayingState(NowPlayingPlaybackState.playing);
  } catch (_) {}
}

Future<bool> isRadioPlaybackActive() async {
  try {
    return await radioPlayback.isPlaying() ?? radioPlayingState.value;
  } catch (_) {
    return radioPlayingState.value;
  }
}

class _RadioPlayerBarState extends State<RadioPlayerBar> {
  static final _streamUri = Uri.parse('https://stream.realhardstyle.nl');
  String _title = 'Real Hardstyle FM';
  bool _muted = false;
  bool _playing = false;
  bool _toggleBusy = false;
  bool _readingMetadata = false;
  Timer? _metadataTimer;
  VoidCallback? _previewListener;

  @override
  void initState() {
    super.initState();
    _previewListener = () {
      if (releasePreviewPlayingState.value) {
        // Reset the visual state immediately as well as stopping the native
        // player. This prevents a rapid tap from leaving the bar on Stop
        // while a release preview is playing.
        if (mounted && _playing) {
          setState(() {
            _playing = false;
            _title = 'Real Hardstyle FM';
          });
          _stopMetadataRefresh();
        }
        // ReleasePreviewPlayer stops the native radio before it starts the
        // preview. This listener only keeps the visible radio state in sync.
      }
    };
    releasePreviewPlayingState.addListener(_previewListener!);
    radioPlayingState.addListener(_syncExternalRadioState);
    unawaited(_syncPlaying());
  }

  void _syncExternalRadioState() {
    if (!mounted || radioPlayingState.value == _playing) return;
    setState(() {
      _playing = radioPlayingState.value;
      if (!_playing) _title = 'Real Hardstyle FM';
    });
    if (_playing) {
      _startMetadataRefresh();
    } else {
      _stopMetadataRefresh();
    }
  }

  Future<void> _syncPlaying() async {
    try {
      final playing = await radioPlayback.isPlaying() ?? false;
      if (!mounted) return;
      setState(() => _playing = playing);
      radioPlayingState.value = playing;
      if (playing) _startMetadataRefresh();
    } catch (_) {}
  }

  void _startMetadataRefresh() {
    _metadataTimer?.cancel();
    unawaited(_readMetadata());
    _metadataTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_readMetadata()),
    );
    // A rendszer felületére (értesítés + zárképernyő) is kimegy a cím.
    nowPlayingReporter.start();
    // …és az ÁLLAPOT is (iOS `playbackState`): ettől lesz pause gomb a
    // zárképernyőn (a tulajdonos jelzése: *„nincs pause gomb”*).
    unawaited(reportRadioNowPlayingState(NowPlayingPlaybackState.playing));
  }

  /// ⚠️ A `clear` **szándékosan** külön kapcsoló (2026-10-03): a rádió
  /// **szüneteltetése** is ide fut be (`radioPlayingState` hamis lesz), és ilyenkor
  /// a rendszer felületének **meg kell maradnia** — különben pont a „Folytatás”
  /// gomb tűnne el. Csak a tényleges leállítás töröl (`stopRadioPlayback`).
  void _stopMetadataRefresh({bool clear = false}) {
    _cancelMetadataTimer();
    if (clear) {
      unawaited(nowPlayingReporter.stop());
      unawaited(reportRadioNowPlayingState(NowPlayingPlaybackState.stopped));
    } else {
      unawaited(reportRadioNowPlayingState(NowPlayingPlaybackState.paused));
    }
  }

  /// A címfrissítő időzítő leállítása **állapot-kiírás nélkül**.
  ///
  /// ⚠️ MIÉRT KÜLÖN (mért hiba, 2026-10-04): a `dispose()` innen hívott, és a
  /// `_stopMetadataRefresh()` ilyenkor **szünetet** jelentett — miközben a rádió a
  /// háttérben **tovább szól**. Ez két hibát okozott: (1) a zárképernyő „play”
  /// gombra váltott egy szóló rádió mellett, (2) a jelentés **új időzítőt** hozott
  /// létre a kilépés pillanatában (a `widget_test.dart` „A Timer is still pending”
  /// hibája). A kilépés nem állapotváltozás: csak az időzítőt állítjuk le.
  void _cancelMetadataTimer() {
    _metadataTimer?.cancel();
    _metadataTimer = null;
  }

  Future<void> _togglePlay() async {
    if (_toggleBusy || releasePreviewPlayingState.value) return;
    _toggleBusy = true;
    try {
      final isPlaying =
          await radioPlayback.isPlaying() ?? _playing;
      if (isPlaying) {
        // A preview can stop the native player while this widget still has a
        // stale snapshot. If the UI says stopped, clear that stale native
        // state before handling the user's new Play tap.
        if (!_playing) {
          await radioPlayback.stop();
          radioPlayingState.value = false;
        }
        if (!_playing) {
          await radioPlayback.play(_streamUri.toString());
          if (mounted) setState(() => _playing = true);
          radioPlayingState.value = true;
          _startMetadataRefresh();
          return;
        }
        await radioPlayback.stop();
        // Ez **tényleges** leállítás (a felhasználó a Leállítás gombot nyomta):
        // ilyenkor a rendszer felülete is törlődik.
        _stopMetadataRefresh(clear: true);
        if (mounted) {
          setState(() {
            _playing = false;
            _title = 'Real Hardstyle FM';
          });
        }
        radioPlayingState.value = false;
      } else {
        // The preview may have started while the native radio call was
        // awaiting. Never allow the radio to win that race.
        if (releasePreviewPlayingState.value) return;
        await radioPlayback.play(_streamUri.toString());
        if (releasePreviewPlayingState.value) {
          await stopRadioPlayback();
          return;
        }
        if (mounted) setState(() => _playing = true);
        radioPlayingState.value = true;
        _startMetadataRefresh();
      }
    } catch (_) {
    } finally {
      _toggleBusy = false;
    }
  }

  Future<void> _readMetadata() async {
    if (_readingMetadata || !_playing) return;
    _readingMetadata = true;
    try {
      // ⚠️ A kiolvasás a **közös** szolgáltatásban él (`radio_metadata.dart`),
      // mert ugyanezt használja majd az értesítés/zárképernyő is — a mérésnek
      // egy helyen kell lennie, nem két másolatban.
      final metadata = await fetchIcyMetadata(_streamUri);
      final title = metadata?.title ?? '';
      if (mounted && title.isNotEmpty) {
        setState(() => _title = title);
      }
    } finally {
      _readingMetadata = false;
    }
  }

  @override
  void dispose() {
    // ⚠️ Kilépéskor **nem** jelentünk állapotot: a rádió a háttérben tovább szól,
    // és a jelentés új időzítőt is hozna létre (lásd `_cancelMetadataTimer`).
    _cancelMetadataTimer();
    if (_previewListener != null) {
      releasePreviewPlayingState.removeListener(_previewListener!);
    }
    radioPlayingState.removeListener(_syncExternalRadioState);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ⚠️ A tulajdonos képernyőképe (2026-09-26): angol módban a rádiósávban
    // „Élő adás" jelent meg. Ez a **ternary-ág** osztály: a felirat nyersen állt,
    // a szótárban sem volt — ezért a megjelenítés helyén fordítjuk, és a
    // fordítás is bekerült.
    final trackTitle = _title == 'Real Hardstyle FM' ? tr(context, 'Élő adás') : _title;
    final compact = MediaQuery.orientationOf(context) == Orientation.landscape;

    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: Colors.transparent,
      child: Container(
        height: compact ? 46 : 52,
        margin: EdgeInsets.fromLTRB(compact ? 6 : 10, 3, compact ? 6 : 10, 3),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Tooltip(
              message: _playing
                  ? tr(context, 'Leállítás')
                  : tr(context, 'Lejátszás'),
              child: Material(
                color: scheme.primary,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _togglePlay,
                  child: SizedBox.square(
                    dimension: compact ? 34 : 38,
                    child: Icon(
                      _playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                      color: Colors.black,
                      size: compact ? 21 : 24,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _playing
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: AppText(
                          'REAL HARDSTYLE FM',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    trackTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: _muted ? tr(context, 'Némítás feloldása') : tr(context, 'Némítás'),
              onPressed: () {
                setState(() => _muted = !_muted);
                radioPlayback.setVolume(_muted ? 0.0 : 1.0);
              },
              style: IconButton.styleFrom(
                side: BorderSide.none,
                visualDensity: VisualDensity.compact,
                shape: const CircleBorder(),
              ),
              icon: Icon(
                _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
