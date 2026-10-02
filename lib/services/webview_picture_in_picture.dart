/// **Kis képernyő (PiP) a beágyazott Twitch-lejátszóhoz** — a tulajdonos kérése:
/// *„ha leteszi az appot hatterben menjen a stream kiskepernyon”*, és a kis
/// képernyő **iOS-en is** kell.
///
/// MIÉRT ÍGY (mért okok, 2026-10-02):
///  * A Twitch-lejátszó **közvetlenül** töltődik a WebView-ba
///    (`player.twitch.tv`, nem `<iframe>` egy oldalban), ezért a videó elem a
///    WebView **saját dokumentumában** van — a JavaScript belelát és tudja
///    vezérelni (cross-origin iframe-nél ez nem működne).
///  * **iOS-en** a WebKit a saját API-ját adja erre:
///    `video.webkitSetPresentationMode('picture-in-picture')`.
///  * **A szabványos** `video.requestPictureInPicture()` a többi WebView-ban
///    (Chromium-alapú) él — ez a tartalék út.
///
/// A szkript és az értelmezés **tiszta** (nincs benne WebView-hívás), ezért
/// hálózat és eszköz nélkül mérhető; magát a futtatást a képernyő végzi.
library;

import 'package:flutter/widgets.dart';

/// Egy kis képernyő kísérlet eredménye (a szkript visszaadott szövegéből).
enum WebviewPipResult {
  /// A WebKit saját módjával indult (iOS).
  webkit,

  /// A szabványos Picture-in-Picture API-val indult.
  standard,

  /// Nem talált videót a dokumentumban (még tölt, vagy nem indult lejátszás).
  noVideo,

  /// A WebView nem támogatja egyik utat sem.
  unsupported,

  /// Hiba történt a szkriptben.
  failed,

  /// Üres/hiányzó válasz (a hívás nem adott értéket).
  empty,
}

/// A szkript, ami a **lejátszó videót** kis képernyőre teszi.
///
/// A sorrend szándékos: először a **WebKit** út (iOS), aztán a **szabványos**;
/// ha egyik sem él, `unsupported`. A *szóló* videót választja (amelyik éppen
/// játszik) — a Twitch oldalán több videó elem is lehet (hirdetés, előnézet).
const String webviewPictureInPictureScript = '''
(function () {
  try {
    var videos = Array.prototype.slice.call(document.querySelectorAll('video'));
    if (!videos.length) { return 'no-video'; }
    var playing = null;
    for (var i = 0; i < videos.length; i++) {
      if (!videos[i].paused && !videos[i].ended) { playing = videos[i]; break; }
    }
    var video = playing || videos[0];
    if (typeof video.webkitSetPresentationMode === 'function') {
      video.webkitSetPresentationMode('picture-in-picture');
      return 'webkit';
    }
    if (typeof video.requestPictureInPicture === 'function') {
      video.requestPictureInPicture();
      return 'standard';
    }
    return 'unsupported';
  } catch (error) {
    return 'error';
  }
})();
''';

/// A WebView visszaadott értékének értelmezése — **tiszta**.
///
/// A `runJavaScriptReturningResult` platformonként máshogy adja vissza ugyanazt:
/// iOS-en és Androidon is **idézőjeles** szöveg jön (pl. `"webkit"`), ezért a
/// felesleges idézőjeleket és a záró pontosvesszőt is leválogatjuk. Ismeretlen
/// szövegre `failed` (nem tippelünk).
WebviewPipResult parseWebviewPictureInPictureResult(Object? raw) {
  var text = raw?.toString().trim() ?? '';
  if (text.isEmpty) return WebviewPipResult.empty;
  text = text.replaceAll('"', '').replaceAll("'", '').replaceAll(';', '').trim();
  switch (text) {
    case 'webkit':
    case 'picture-in-picture':
      return WebviewPipResult.webkit;
    case 'standard':
      return WebviewPipResult.standard;
    case 'no-video':
      return WebviewPipResult.noVideo;
    case 'unsupported':
      return WebviewPipResult.unsupported;
    default:
      return WebviewPipResult.failed;
  }
}

/// A kísérlet **sikerült-e** (a hívó ilyenkor nem nyúl a tartalék úthoz).
bool webviewPipResultSucceeded(WebviewPipResult result) =>
    result == WebviewPipResult.webkit || result == WebviewPipResult.standard;

/// Belépjünk-e kis képernyőre ebben az életciklus-állapotban?
///
/// **Tiszta döntés**, ezért mérhető:
///  * csak akkor, ha a Twitch-oldal **kérte** (`enabled`),
///  * és az app **tényleg háttérbe került** (`paused`/`hidden`),
///  * `inactive`-ra **nem** lépünk be: iOS-en ezt olyankor is megkapja az app,
///    amikor csak egy rendszer-párbeszéd (pl. engedélykérés) kerül előtérbe —
///    ilyenkor a kis képernyő **zavaró** lenne,
///  * `resumed`-re nem (olyankor épp visszatértünk).
bool shouldEnterPictureInPicture({
  required bool enabled,
  required AppLifecycleState state,
}) {
  if (!enabled) return false;
  return state == AppLifecycleState.paused || state == AppLifecycleState.hidden;
}

/// Az életciklus-állapot neve — a naplóhozá és a méréshez (nem felületi szöveg).
String appLifecycleName(AppLifecycleState state) {
  switch (state) {
    case AppLifecycleState.resumed:
      return 'resumed';
    case AppLifecycleState.inactive:
      return 'inactive';
    case AppLifecycleState.paused:
      return 'paused';
    case AppLifecycleState.hidden:
      return 'hidden';
    case AppLifecycleState.detached:
      return 'detached';
  }
}

/// A kis képernyő **egyszer** induljon el egy háttérbe-kerüléskor: ez a kapu
/// megjegyzi, hogy már kértük, és visszatéréskor (`resumed`) újra engedi.
///
/// Azért osztály, hogy a képernyő ne egy csupasz `bool`-t őrizgessen (a
/// „kértük-e már” és a „visszaállítás” egy helyen legyen, és mérhető legyen).
class PictureInPictureRequestGate {
  bool _requested = false;

  bool get requested => _requested;

  /// Igaz, ha **most** kell kérni (és meg is jegyzi).
  bool takeIfNeeded({required bool enabled, required AppLifecycleState state}) {
    if (state == AppLifecycleState.resumed) {
      _requested = false;
      return false;
    }
    if (_requested) return false;
    if (!shouldEnterPictureInPicture(enabled: enabled, state: state)) return false;
    _requested = true;
    return true;
  }

  /// Visszatérés előtérbe (vagy a képernyő elhagyása) — a kapu újra nyílik.
  void reset() => _requested = false;
}
