import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/i18n/tr.dart';
import '../../services/picture_in_picture.dart';
import '../../services/twitch_live.dart';
import '../../widgets/app_text.dart';
import '../community/community_screen.dart';
import '../more/donate_screen.dart';
import '../../widgets/radio_player_bar.dart';

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
///  3. **PayPal támogatás** — a meglévő `DonateScreen` linkjével;
///  4. **hangfókusz**: belépéskor a rádió és az előzetes **leáll** (nem szól két
///     hang egyszerre), kilépéskor a rádió **visszatér**, ha előtte szólt;
///  5. **kis képernyő (PiP)**: amíg ez az oldal van nyitva, az app elhagyásakor
///     Androidon a stream kicsiben megy tovább.
class TwitchScreen extends ConsumerStatefulWidget {
  const TwitchScreen({super.key});

  @override
  ConsumerState<TwitchScreen> createState() => _TwitchScreenState();
}

class _TwitchScreenState extends ConsumerState<TwitchScreen> {
  WebViewController? _controller;
  TwitchLiveStatus? _status;
  bool _radioWasPlaying = false;

  @override
  void initState() {
    super.initState();
    unawaited(_enter());
  }

  /// Belépés: hangfókusz + kis képernyő + a lejátszó betöltése.
  Future<void> _enter() async {
    _radioWasPlaying = await isRadioPlaybackActive();
    await stopRadioPlayback();
    releasePreviewPlayingState.value = false;
    await pictureInPicture.setEnabled(true);
    if (!mounted) return;
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      // ⚠️ A webview_flutter 4.x nem ad API-t a „gesztus nélküli lejátszás”
      // beállítására, ezért az automatikus indítást a beágyazott lejátszó
      // `autoplay=true` paramétere viszi (és ha az Android WebView mégis kér
      // koppintást, a Twitch saját lejátszógombja ott van a videón).
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

  @override
  void dispose() {
    unawaited(pictureInPicture.setEnabled(false));
    // Ha a rádió szólt, mielőtt a streamhez jöttünk, visszakapja a hangot.
    if (_radioWasPlaying) unawaited(resumeRadioPlayback());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
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
            tooltip: tr(context, 'Támogatás PayPallal'),
            onPressed: () => unawaited(DonateScreen.openDonate()),
            icon: const Icon(Icons.favorite),
          ),
        ],
      ),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(
              color: Colors.black,
              child: _controller == null
                  ? const Center(child: CircularProgressIndicator())
                  : WebViewWidget(controller: _controller!),
            ),
          ),
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
          const Divider(height: 12),
          // Az app SAJÁT chatje — ugyanaz a közösségi felület, ami a Chat fülön.
          const Expanded(child: LiveFeedScreen()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => unawaited(DonateScreen.openDonate()),
        icon: const Icon(Icons.payment),
        label: const AppText('Támogatás'),
      ),
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
