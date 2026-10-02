import 'package:flutter/material.dart';

import '../../services/twitch_layout.dart';

/// A Twitch-oldal **alkalmazkodó váza**: videó + adatsáv + chat.
///
/// MIÉRT külön widget: így az elrendezés **mérhető** — a valódi képernyő
/// WebView-t és Firestore-t hoz magával, azt nem lehet widget-tesztben kirajzolni.
/// A váza viszont tiszta: a videót, az adatsávot és a chatet **paraméterként**
/// kapja, ezért a teszt egyszerű helyettesítőkkel **lemérheti a geometriát**
/// (álló telefon, fekvő telefon, tablet) — pontosan azt, amit a tulajdonos
/// jelzett: *„az a chat rész elég pici”*, *„fekvő módban nincs chat”*,
/// *„figyelj a tabletre is”*.
class TwitchLayoutFrame extends StatelessWidget {
  const TwitchLayoutFrame({
    super.key,
    required this.video,
    required this.info,
    required this.chat,
  });

  /// A lejátszó (WebView) — a **méretet a váza adja**.
  final Widget video;

  /// Cím, nézőszám és a támogatás gomb.
  final Widget info;

  /// A stream-chat.
  final Widget chat;

  /// A videó sávja: fekete alapon, 16:9 arányban középre igazítva.
  Widget _videoArea(double height) => SizedBox(
        key: const Key('twitch-video-area'),
        height: height,
        width: double.infinity,
        child: ColoredBox(
          color: Colors.black,
          child: Center(
            child: AspectRatio(aspectRatio: 16 / 9, child: video),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final mode = twitchLayoutModeFor(size);

    if (mode == TwitchLayoutMode.sideBySide) {
      final chatWidth = twitchSideChatWidth(size);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              key: const Key('twitch-side-left-column'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _videoArea(twitchSideVideoHeight(size)),
                info,
                const Spacer(),
              ],
            ),
          ),
          SizedBox(
            key: const Key('twitch-side-chat-column'),
            width: chatWidth,
            child: chat,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _videoArea(twitchStackedVideoHeight(size)),
        info,
        Expanded(
          key: const Key('twitch-stacked-chat'),
          child: chat,
        ),
      ],
    );
  }
}
