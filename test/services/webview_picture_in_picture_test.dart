import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/services/webview_picture_in_picture.dart';

/// A **kis képernyő (PiP)** döntései és a WebView-híd — eszköz nélkül mérve.
///
/// MIÉRT EZEK A MÉRÉSEK: a tulajdonos kérése szerint a stream **iOS-en is**
/// menjen kicsiben, ha az app háttérbe kerül. Ezt a JavaScript-híd viszi
/// (`webkitSetPresentationMode`, illetve a szabványos `requestPictureInPicture`),
/// a belépés **pillanata** pedig tiszta döntés. Mindkettő mérhető anélkül, hogy
/// WebView vagy telefon kellene hozzá.
void main() {
  group('a JavaScript-híd', () {
    test('a WebView dokumentumában keresi a videót (nem iframe-ben)', () {
      expect(webviewPictureInPictureScript, contains("document.querySelectorAll('video')"));
      expect(webviewPictureInPictureScript, contains('Array.prototype.slice.call'));
    });

    test('a JÁTSZÓ videót választja, ha több elem van (hirdetés/előnézet)', () {
      expect(webviewPictureInPictureScript, contains('!videos[i].paused && !videos[i].ended'));
      // …és ha egy sem játszik, az elsőhöz nyúl (nem marad néma).
      expect(webviewPictureInPictureScript, contains('playing || videos[0]'));
    });

    test('iOS-en a WebKit saját módját hívja', () {
      expect(webviewPictureInPictureScript, contains('webkitSetPresentationMode'));
      expect(webviewPictureInPictureScript, contains("'picture-in-picture'"));
    });

    test('a szabványos API a tartalék út', () {
      expect(webviewPictureInPictureScript, contains('requestPictureInPicture'));
      // A WebKit-ág ELŐBB van, mint a szabványos (a sorrend számít).
      expect(
        webviewPictureInPictureScript.indexOf('webkitSetPresentationMode'),
        lessThan(webviewPictureInPictureScript.indexOf('requestPictureInPicture')),
      );
    });

    test('videó nélkül és hibára is MOND valamit (nem néma)', () {
      expect(webviewPictureInPictureScript, contains("return 'no-video'"));
      expect(webviewPictureInPictureScript, contains("return 'unsupported'"));
      expect(webviewPictureInPictureScript, contains("return 'error'"));
    });
  });

  group('a visszaadott érték értelmezése', () {
    test('a WebKit ág sikeres (idézőjelekkel is, ahogy a platform adja)', () {
      expect(parseWebviewPictureInPictureResult('"webkit"'), WebviewPipResult.webkit);
      expect(parseWebviewPictureInPictureResult("'webkit';"), WebviewPipResult.webkit);
      expect(webviewPipResultSucceeded(WebviewPipResult.webkit), isTrue);
    });

    test('a szabványos ág sikeres', () {
      expect(parseWebviewPictureInPictureResult('"standard"'), WebviewPipResult.standard);
      expect(webviewPipResultSucceeded(WebviewPipResult.standard), isTrue);
    });

    test('a WebKit saját visszaadott értéke (picture-in-picture) is siker', () {
      // Egyes WebKit-verziók a beállított módot adják vissza szövegként.
      expect(parseWebviewPictureInPictureResult('"picture-in-picture"'), WebviewPipResult.webkit);
      expect(webviewPipResultSucceeded(WebviewPipResult.webkit), isTrue);
    });

    test('a „nincs videó" nem siker (ilyenkor jön a tartalék út)', () {
      expect(parseWebviewPictureInPictureResult('"no-video"'), WebviewPipResult.noVideo);
      expect(webviewPipResultSucceeded(WebviewPipResult.noVideo), isFalse);
    });

    test('a nem támogatott és a hiba nem siker', () {
      expect(parseWebviewPictureInPictureResult('"unsupported"'), WebviewPipResult.unsupported);
      expect(parseWebviewPictureInPictureResult('"error"'), WebviewPipResult.failed);
      expect(webviewPipResultSucceeded(WebviewPipResult.unsupported), isFalse);
      expect(webviewPipResultSucceeded(WebviewPipResult.failed), isFalse);
    });

    test('üres és ismeretlen válaszra nem tippelünk', () {
      expect(parseWebviewPictureInPictureResult(null), WebviewPipResult.empty);
      expect(parseWebviewPictureInPictureResult(''), WebviewPipResult.empty);
      expect(parseWebviewPictureInPictureResult('   '), WebviewPipResult.empty);
      expect(parseWebviewPictureInPictureResult('true'), WebviewPipResult.failed);
    });
  });

  group('a belépés pillanata (tiszta döntés)', () {
    test('háttérbe kerüléskor belép (paused és hidden)', () {
      expect(
        shouldEnterPictureInPicture(enabled: true, state: AppLifecycleState.paused),
        isTrue,
      );
      expect(
        shouldEnterPictureInPicture(enabled: true, state: AppLifecycleState.hidden),
        isTrue,
      );
    });

    test('inactive-ra NEM lép be (iOS rendszer-párbeszéd is ezt adja)', () {
      expect(
        shouldEnterPictureInPicture(enabled: true, state: AppLifecycleState.inactive),
        isFalse,
      );
    });

    test('előtérben és lecsatolva sem lép be', () {
      expect(
        shouldEnterPictureInPicture(enabled: true, state: AppLifecycleState.resumed),
        isFalse,
      );
      expect(
        shouldEnterPictureInPicture(enabled: true, state: AppLifecycleState.detached),
        isFalse,
      );
    });

    test('ha az oldal nem kérte (enabled = false), háttérben sem lép be', () {
      expect(
        shouldEnterPictureInPicture(enabled: false, state: AppLifecycleState.paused),
        isFalse,
      );
    });

    test('az életciklus neve naplózható (nem felületi szöveg)', () {
      expect(appLifecycleName(AppLifecycleState.paused), 'paused');
      expect(appLifecycleName(AppLifecycleState.resumed), 'resumed');
    });
  });

  group('a kérés-kapu (egy háttérbe-kerülés = egy kérés)', () {
    test('a háttérbe kerüléskor egyszer enged, aztán nem', () {
      final gate = PictureInPictureRequestGate();
      expect(gate.takeIfNeeded(enabled: true, state: AppLifecycleState.paused), isTrue);
      expect(gate.requested, isTrue);
      // Újabb paused esemény (pl. képernyő kikapcsolás) nem indít új kérést.
      expect(gate.takeIfNeeded(enabled: true, state: AppLifecycleState.paused), isFalse);
    });

    test('visszatérés előtérbe újra engedi (következő háttérbe kerülésre)', () {
      final gate = PictureInPictureRequestGate();
      expect(gate.takeIfNeeded(enabled: true, state: AppLifecycleState.paused), isTrue);
      expect(gate.takeIfNeeded(enabled: true, state: AppLifecycleState.resumed), isFalse);
      expect(gate.requested, isFalse);
      expect(gate.takeIfNeeded(enabled: true, state: AppLifecycleState.paused), isTrue);
    });

    test('inactive nem foglalja le a kaput (a valódi háttérbe kerülés még jöhet)', () {
      final gate = PictureInPictureRequestGate();
      expect(gate.takeIfNeeded(enabled: true, state: AppLifecycleState.inactive), isFalse);
      expect(gate.requested, isFalse);
      expect(gate.takeIfNeeded(enabled: true, state: AppLifecycleState.paused), isTrue);
    });

    test('reset után újra kérhető (a képernyő elhagyásakor)', () {
      final gate = PictureInPictureRequestGate();
      expect(gate.takeIfNeeded(enabled: true, state: AppLifecycleState.paused), isTrue);
      gate.reset();
      expect(gate.takeIfNeeded(enabled: true, state: AppLifecycleState.paused), isTrue);
    });
  });

  group('forrás-lint: a képernyő és a natív oldal együtt él', () {
    final screen = File('lib/screens/twitch/twitch_screen.dart').readAsStringSync();
    final service = File('lib/services/picture_in_picture.dart').readAsStringSync();
    final activity =
        File('android/app/src/main/kotlin/hu/hungarianhardstyle/app/MainActivity.kt').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    test('a Twitch-oldal figyeli az életciklust és bekéri a kis képernyőt', () {
      expect(screen, contains('with WidgetsBindingObserver'));
      expect(screen, contains('WidgetsBinding.instance.addObserver(this)'));
      expect(screen, contains('WidgetsBinding.instance.removeObserver(this)'));
      expect(screen, contains('void didChangeAppLifecycleState(AppLifecycleState state)'));
      expect(screen, contains('_pictureInPictureGate.takeIfNeeded'));
      // ⚠️ A MUTÁCIÓS BIZONYÍTÉK TANULSÁGA (2026-10-02): a puszta
      // „szerepel-e a hívás a fájlban" gyenge volt — a `_requestPictureInPicture`
      // gomb-ágában is ott a hívás, ezért a háttérbe-kerülés ágát **a metódus
      // testére** mérjük (a hívás a életciklus-kezelőben legyen).
      final lifecycleBody = RegExp(
        r'void didChangeAppLifecycleState\(AppLifecycleState state\) \{([\s\S]*?)\n  \}',
      ).firstMatch(screen)?.group(1);
      expect(lifecycleBody, isNotNull, reason: 'nincs életciklus-kezelő a képernyőn');
      expect(lifecycleBody, contains('takeIfNeeded'));
      expect(lifecycleBody, contains('enterStreamPictureInPicture(_controller)'));
      expect(lifecycleBody, contains('unawaited('));
    });

    test('a képernyő a WebView-ból futtatja a hidat', () {
      expect(screen, contains('runJavaScriptReturningResult(webviewPictureInPictureScript)'));
      expect(screen, contains('parseWebviewPictureInPictureResult'));
    });

    test('van gomb a kis képernyőre, és tartalék út Androidra', () {
      expect(screen, contains("tr(context, 'Kis képernyő')"));
      expect(screen, contains('pictureInPicture.enter()'));
      expect(screen, contains('Icons.picture_in_picture_alt'));
    });

    test('az iOS WebView inline lejátszással és koppintás nélkül jön létre', () {
      // ⚠️ Ez a mért hiány javítása: enélkül iOS-en nincs PiP.
      expect(screen, contains('WebKitWebViewControllerCreationParams('));
      expect(screen, contains('allowsInlineMediaPlayback: true'));
      expect(screen, contains('mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{}'));
      expect(screen, contains('defaultTargetPlatform == TargetPlatform.iOS'));
    });

    test('a platform-csomag közvetlen függőség (különben nem fordulna)', () {
      expect(pubspec, contains('webview_flutter_wkwebview:'));
    });

    test('a Dart szolgáltatás tud azonnali belépést kérni', () {
      expect(service, contains("invokeMethod<bool>('enter')"));
      expect(service, contains("'setEnabled'"));
    });

    test('a natív oldal „enter" művelete ugyanazokat a kapukat használja', () {
      expect(activity, contains('"enter" -> result.success(enterPictureInPictureNow())'));
      expect(activity, contains('private fun enterPictureInPictureNow(): Boolean'));
      // ⚠️ A MUTÁCIÓS BIZONYÍTÉK TANULSÁGA (2026-10-02): az „előfordul-e a
      // fájlban" itt is gyenge volt — a KAPUKAT a natív belépő függvény
      // **testére** mérjük (a mező, az API-szint és a szolgáltatás is).
      final enterBody = RegExp(
        r'private fun enterPictureInPictureNow\(\): Boolean \{([\s\S]*?)\n    \}',
      ).firstMatch(activity)?.group(1);
      expect(enterBody, isNotNull, reason: 'nincs natív belépő függvény');
      expect(enterBody, contains('if (!pictureInPictureEnabled) return false'));
      expect(enterBody, contains('Build.VERSION.SDK_INT < Build.VERSION_CODES.O'));
      expect(enterBody, contains('hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)'));
      expect(enterBody, contains('enterPictureInPictureMode('));
      // Az app elhagyása ugyanezt az utat hívja (egy helyen a döntés).
      expect(activity, contains('override fun onUserLeaveHint()'));
      final leaveBody = RegExp(
        r'override fun onUserLeaveHint\(\) \{([\s\S]*?)\n    \}',
      ).firstMatch(activity)?.group(1);
      expect(leaveBody, contains('enterPictureInPictureNow()'));
    });
  });
}
