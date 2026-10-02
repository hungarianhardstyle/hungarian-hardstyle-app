import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'radio_metadata.dart';

/// A **„most szól"** kiírása a rendszer felületére: Android-értesítés és
/// zárképernyő, illetve iOS „Most szól” panel.
///
/// MIÉRT (a tulajdonos kérése, 2026-10-01): *„kiírhatná itt is a zenét ami szól +
/// zárképernyőn is lehessen látni a radio a real hardstyle fm logóval”*.
///
/// A felosztás szándékos:
///  * **Android** — a rádió egy **előtér-szolgáltatás**, ezért a cím az
///    értesítést és a `MediaSession`-t rajzoló natív kódhoz megy
///    (`hu_hs/radio` → `metadata`). A szolgáltatás **háttérben is** frissít
///    (saját maga olvassa a stream fejlécét), a felület csak akkor küld, ha az
///    app nyitva van — így nincs felesleges hálózati kör.
///  * **iOS** — a rádió `just_audio`-val szól, ezért a „Most szól” panel
///    (`MPNowPlayingInfoCenter`) közvetlenül kapja a címet (`hu_hs/now_playing`).
///
/// ⚠️ A fordítás **tiszta** ([nowPlayingPayload], [shouldReport]): a csatorna
/// hívása nélkül mérhető, hogy mi kerül ki és mikor.
class NowPlayingReporter {
  NowPlayingReporter({@visibleForTesting Future<RadioMetadata?> Function(Uri)? fetch})
      : _fetch = fetch ?? fetchIcyMetadata;

  static const MethodChannel androidChannel = MethodChannel('hu_hs/radio');
  static const MethodChannel appleChannel = MethodChannel('hu_hs/now_playing');

  /// A stream, amit figyelünk (a rádió ugyanezt játssza).
  static final Uri streamUri = Uri.parse('https://stream.realhardstyle.nl');

  /// Ilyen sűrűn olvassuk a metaadatot (a szerver ~4 másodpercenként vált blokkot).
  static const Duration refreshInterval = Duration(seconds: 15);

  final Future<RadioMetadata?> Function(Uri) _fetch;
  Timer? _timer;
  bool _busy = false;
  RadioMetadata _last = const RadioMetadata();

  bool get isRunning => _timer != null;

  /// A kör indítása (a rádió indulásakor).
  void start() {
    if (_timer != null) return;
    _last = const RadioMetadata();
    unawaited(refresh());
    _timer = Timer.periodic(refreshInterval, (_) => unawaited(refresh()));
  }

  /// A kör leállítása (a rádió leállásakor) — a képernyőn maradt cím törlésével.
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _last = const RadioMetadata();
    await clear();
  }

  /// Egy frissítés: kiolvassa a metaadatot, és **csak változáskor** küldi ki.
  Future<void> refresh() async {
    if (_busy) return;
    _busy = true;
    try {
      final metadata = await _fetch(streamUri);
      if (metadata == null || !shouldReport(_last, metadata)) return;
      _last = metadata;
      await report(metadata, androidChannel: androidChannel, appleChannel: appleChannel);
    } catch (error) {
      debugPrint('most szól: a metaadat nem olvasható: $error');
    } finally {
      _busy = false;
    }
  }

  /// A rendszer felületének törlése (a rádió leállt).
  Future<void> clear() async {
    for (final channel in [androidChannel, appleChannel]) {
      try {
        await channel.invokeMethod<void>('clear');
      } catch (_) {
        // A csatorna hiányozhat (pl. régebbi build) — ez nem hiba.
      }
    }
  }

  /// Az üzenet, amit a platform kap.
  static Map<String, String> nowPlayingPayload(RadioMetadata metadata) => {
        'title': metadata.title,
        'next': metadata.next,
        'artist': 'Real Hardstyle FM',
      };

  /// Csak akkor küldünk, ha **tényleg változott** a cím (a rádió sokat ismétel).
  static bool shouldReport(RadioMetadata previous, RadioMetadata current) {
    if (current.isEmpty) return false;
    return previous.title != current.title || previous.next != current.next;
  }

  /// A tényleges kiírás — platformonként a megfelelő csatornára.
  static Future<void> report(
    RadioMetadata metadata, {
    MethodChannel? androidChannel,
    MethodChannel? appleChannel,
  }) async {
    final payload = nowPlayingPayload(metadata);
    // Csak a megadott csatornákra írunk (a null-értékű kimarad).
    final channels = <MethodChannel>[?androidChannel, ?appleChannel];
    for (final channel in channels) {
      try {
        await channel.invokeMethod<void>('metadata', payload);
      } catch (_) {
        // Néma hiba: a lejátszás ettől függetlenül megy tovább.
      }
    }
  }
}

/// A mindenkori jelentő (a felület és az indítás is ezt használja).
final NowPlayingReporter nowPlayingReporter = NowPlayingReporter();
