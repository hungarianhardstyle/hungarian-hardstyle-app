import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../core/i18n/tr.dart';
import '../../services/picture_in_picture.dart';
import '../../services/twitch_live.dart';
import '../../services/webview_picture_in_picture.dart';
import '../../widgets/app_text.dart';
import '../more/donate_screen.dart';
import '../../widgets/radio_player_bar.dart';
import 'twitch_chat.dart';
import 'twitch_layout.dart';

/// **Twitch-élő adás az appban** — a tulajdonos kérése (2026-10-01):
/// *„lehessen nézni az appban… nyisson meg egy külön oldalt… legessen chatelni
/// alatta az appban… legyen ott a donate paypal gomb… ha leteszi az appot
/// hatterben menjen a stream kiskepernyon”*.
///
/// Amit a képernyő összefog:
///  1. **beágyazott Twitch-lejátszó** (`player.twitch.tv`, WebView);
///  2. **az app SAJÁT chatje** alatta (a tulajdonos választása: *„appban lehessen
///     chatelni, nem twitch chat”*) — ugyanaz a közösségi chat, emotokkal,
///     reakciókkal, `@`hivatkozásokkal, push-sal;
///  3. **PayPal támogatás** — a meglévő `DonateScreen` linkjével, a **videó alatti
///     sávban** (a tulajdonos jelzése, 2026-10-02: *„az a támogatás gomb nagyon
///     rossz helyen van"* — a lebegő gomb a chat „Küldés" gombja mellé esett,
///     ezért könnyen összetéveszthető volt);
///  4. **hangfókusz**: belépéskor a rádió és az előzetes **leáll** (nem szól két
///     hang egyszerre), kilépéskor a rádió **visszatér**, ha előtte szólt;
///  5. **kis képernyő (PiP)**: amíg ez az oldal van nyitva, az app elhagyásakor
///     a stream kicsiben megy tovább — Androidon a natív aktivitás-PiP, iOS-en a
///     WebKit saját videó-PiP-je (lásd `webview_picture_in_picture.dart`).
class TwitchScreen extends ConsumerStatefulWidget {
  const TwitchScreen({super.key});

  @override
  ConsumerState<TwitchScreen> createState() => _TwitchScreenState();
}

class _TwitchScreenState extends ConsumerState<TwitchScreen> with WidgetsBindingObserver {
  WebViewController? _controller;
  TwitchLiveStatus? _status;
  bool _radioWasPlaying = false;

  /// A kis képernyő kérése egy háttérbe-kerüléskor **egyszer** menjen.
  final PictureInPictureRequestGate _pictureInPictureGate = PictureInPictureRequestGate();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_enter());
  }

  /// A lejátszó vezérlője — **platformfüggő** beállításokkal.
  ///
  /// ⚠️ MÉRT HIÁNY (2026-10-02): a `webview_flutter` iOS-alapértéke
  /// `allowsInlineMediaPlayback = false` + `mediaTypesRequiringUserAction =
  /// {audio, video}`. Ezzel a Twitch videó **teljes képernyőre váltott** és a
  /// **kis képernyő nem is volt elérhető** (a WebKit csak inline lejátszásnál ad
  /// PiP-et). Ezért iOS-en kézzel adjuk át a helyes beállításokat; minden más
  /// platformon marad az alap.
  WebViewController _createController() {
    final PlatformWebViewControllerCreationParams platformParams =
        const PlatformWebViewControllerCreationParams();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return WebViewController.fromPlatformCreationParams(
        WebKitWebViewControllerCreationParams(
          // A videó a helyén játsszon (ne ugorjon teljes képernyőre)…
          allowsInlineMediaPlayback: true,
          // …és ne kérjen koppintást: a Twitch `autoplay=true` paramétere így
          // tényleg érvényesül (a felhasználó a kártyára koppintva már jelezte
          // a szándékát).
          mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
        ),
      );
    }
    return WebViewController.fromPlatformCreationParams(platformParams);
  }

  /// Belépés: hangfókusz + kis képernyő + a lejátszó betöltése.
  Future<void> _enter() async {
    _radioWasPlaying = await isRadioPlaybackActive();
    await stopRadioPlayback();
    releasePreviewPlayingState.value = false;
    await pictureInPicture.setEnabled(true);
    if (!mounted) return;
    final controller = _createController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      // ⚠️ A webview_flutter 4.x nem ad API-t a „gesztus nélküli lejátszás”
      // beállítására Androidon, ezért ott az automatikus indítást a beágyazott
      // lejátszó `autoplay=true` paramétere viszi (és ha az Android WebView mégis
      // kér koppintást, a Twitch saját lejátszógombja ott van a videón).
      // iOS-en a `mediaTypesRequiringUserAction` ürítése oldja meg ugyanezt.
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (error) {
            // Fejlesztői napló (nem felületi szöveg) — ezért angolul.
            debugPrint('twitch: the embedded player reported an error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(twitchEmbedUrl(twitchChannel)));
    setState(() => _controller = controller);
    final status = await fetchTwitchLive();
    if (mounted) setState(() => _status = status);
  }

  /// Az app **háttérbe került** — a stream kicsiben menjen tovább.
  ///
  /// A döntés tiszta (`shouldEnterPictureInPicture`), a belépés maga a WebView
  /// JavaScript-hídja: iOS-en a WebKit `webkitSetPresentationMode`, máshol a
  /// szabványos `requestPictureInPicture`. Androidon a natív aktivitás-PiP már
  /// az app elhagyásakor belép (`onUserLeaveHint`), ezért ott ez a hívás csak
  /// rásegítés (a videót teszi ki külön ablakba, ha a WebView tudja).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ask = _pictureInPictureGate.takeIfNeeded(enabled: true, state: state);
    if (!ask) return;
    debugPrint('twitch: app went to ${appLifecycleName(state)} — asking for picture-in-picture');
    unawaited(enterStreamPictureInPicture(_controller));
  }

  /// A WebView videójának kitétele kis képernyőre (a szkript eredményével).
  Future<WebviewPipResult> enterStreamPictureInPicture(WebViewController? controller) async {
    if (controller == null) return WebviewPipResult.empty;
    try {
      final raw = await controller.runJavaScriptReturningResult(webviewPictureInPictureScript);
      return parseWebviewPictureInPictureResult(raw);
    } catch (error) {
      debugPrint('twitch: the picture-in-picture call failed: $error');
      return WebviewPipResult.failed;
    }
  }

  /// A **gomb** nyomása: először a videó-PiP (szebb, csak a kép), és ha az nem
  /// megy, Androidon a **natív** aktivitás-PiP — így a kis képernyő mindkét
  /// platformon elérhető, nem csak app-elhagyáskor.
  ///
  /// ⚠️ Ha **egyik út sem él**, azt KI KELL MONDANI (a tulajdonos jelzése:
  /// *„a pip gomb se megy amúgy a twitch oldalon”*) — eddig csak annyi látszott,
  /// hogy „a videó saját gombjával is kicsinyíthető”, amiből nem derült ki, hogy
  /// a rendszer utasította el a kérést.
  Future<void> _requestPictureInPicture() async {
    final result = await enterStreamPictureInPicture(_controller);
    if (webviewPipResultSucceeded(result)) return;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final entered = await pictureInPicture.enter();
      if (entered) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
            tr(context, 'A rendszer most nem engedte a kis képernyőt — nézd meg a telefon beállításaiban (Alkalmazások → HUHS → Kép a képben).'),
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: AppText(tr(context, 'A videó saját gombjával is kicsinyíthető.'))),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pictureInPictureGate.reset();
    unawaited(pictureInPicture.setEnabled(false));
    // Ha a rádió szólt, mielőtt a streamhez jöttünk, visszakapja a hangot.
    if (_radioWasPlaying) unawaited(resumeRadioPlayback());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    // A KIS KÉPERNYŐ (393) — a tulajdonos jelzése: *„ez a kis ablak a PIP is elég
    // FOSCSI, a rádió gomb dominál”*. PiP-ben ezért **csak a videó** rajzolódik
    // ki: se fejléc, se adatsáv (támogatás), se chat — a kis ablak így egy
    // valódi lejátszó. A keret többi része (rádiósáv, alsó menü) a
    // `HiddenInPictureInPicture` burkon keresztül tűnik el.
    return ValueListenableBuilder<bool>(
      valueListenable: pictureInPicture.active,
      builder: (context, inPictureInPicture, _) {
        if (inPictureInPicture) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: AspectRatio(aspectRatio: 16 / 9, child: _player()),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                if (status?.isLive ?? false) ...[
                  const _LiveBadge(),
                  const SizedBox(width: 8),
                ],
                const Expanded(
                  child: AppText('Twitch élő adás', maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: tr(context, 'Kis képernyő'),
                onPressed: () => unawaited(_requestPictureInPicture()),
                icon: const Icon(Icons.picture_in_picture_alt),
              ),
              IconButton(
                tooltip: tr(context, 'Támogatás PayPallal'),
                onPressed: () => unawaited(DonateScreen.openDonate()),
                icon: const Icon(Icons.volunteer_activism),
              ),
            ],
          ),
          // AZ ELRENDEZÉS (392) — a tulajdonos jelzései: *„az a chat rész elég pici”*,
          // *„fekvő módban nincs chat”*, *„figyelj a tabletre is”*. A váz
          // (`TwitchLayoutFrame`) dönt: keskenyen egymás alatt (a videó legfeljebb a
          // magasság harmada), szélesen/tableten egymás MELLETT, ezért a chat mindig
          // látszik. A mérés a `test/screens/twitch_layout_test.dart`-ban van.
          body: TwitchLayoutFrame(
            video: _player(),
            info: _infoColumn(context, status),
            chat: const TwitchStreamChat(),
          ),
        );
      },
    );
  }

  /// A beágyazott lejátszó (vagy amíg nincs vezérlő, töltésjelző).
  Widget _player() => _controller == null
      ? const Center(child: CircularProgressIndicator())
      : WebViewWidget(controller: _controller!);

  /// A videó alatti adatsáv: cím, nézőszám és a **támogatás** gomb.
  ///
  /// TÁMOGATÁS (390): a tulajdonos jelzése — *„az a támogatás gomb nagyon rossz
  /// helyen van”*. Eddig lebegő gomb (FAB) volt, ezért a chat alsó sávjában, pont
  /// a „Küldés” gomb mellett lebegett: úgy nézett ki, mintha a chathez tartozna,
  /// és véletlenül is el lehetett találni (az pedig fizetési oldalt nyit). Most a
  /// videó alatti adatsávban van, a chattől **elkülönítve** — az app sávjában
  /// pedig ugyanez az ikon (`volunteer_activism`) jelöli ugyanazt a műveletet.
  Widget _infoColumn(BuildContext context, TwitchLiveStatus? status) {
    return Column(
      key: const Key('twitch-info-column'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (status != null && status.title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: AppText(
                    status.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (status.isLive)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: AppText('${status.viewers} ${tr(context, 'néző')}'),
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => unawaited(DonateScreen.openDonate()),
              icon: const Icon(Icons.volunteer_activism, size: 18),
              label: const AppText('Támogatás PayPallal'),
            ),
          ),
        ),
      ],
    );
  }
}

/// Az „ÉLŐ” jelvény (a Twitch saját színével).
class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE91916),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const AppText(
        'ÉLŐ',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}
