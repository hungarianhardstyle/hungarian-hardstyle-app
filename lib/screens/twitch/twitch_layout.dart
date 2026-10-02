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
    this.keyboardVisible = false,
  });

  /// A lejátszó (WebView) — a **méretet a váza adja**.
  final Widget video;

  /// Cím, nézőszám és a támogatás gomb.
  final Widget info;

  /// A stream-chat.
  final Widget chat;

  /// Gépelés közben (billentyűzet nyitva) a **függőleges** elrendezésben a videó
  /// és az adatsáv is eltűnik — így a chat olvasható része a lehető legnagyobb
  /// (a tulajdonos jelzése: *„az a chat rész NAGYON kicsi, az olvasható rész”*).
  final bool keyboardVisible;

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
        // Gépelés közben a videó és az adatsáv eltűnik: a chat olvasható része
        // ilyenkor a teljes magasság (a tulajdonos jelzése: *„az a chat rész
        // NAGYON kicsi, az olvasható rész”*).
        if (!keyboardVisible) ...[
          _videoArea(twitchStackedVideoHeight(size)),
          info,
        ],
        Expanded(
          key: const Key('twitch-stacked-chat'),
          child: chat,
        ),
      ],
    );
  }
}
