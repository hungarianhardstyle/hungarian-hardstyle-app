/// A **Twitch-oldal elrendezése** — tiszta döntések, hogy mérhető legyen.
///
/// ## A tulajdonos jelzései (2026-10-02, videóval az Android-telefonról)
///
/// *„gond van androidon is, az a chat rész elég pici”*, *„+ hiba, fekvő módban
/// nincs chat”*, *„+ figyelj a tabletre is”*.
///
/// **A mért gyökér:** az oldal egyetlen **függőleges** `Column` volt: felül a
/// 16:9-es videó (`AspectRatio`), alatta a chat. **Fekvő módban** (és tableten) a
/// szélesség nagy, ezért a 16:9-es videó magassága **majdnem a teljes képernyőt**
/// elvitte — a chat `Expanded`-je **nulla magasságot** kapott, ezért **eltűnt**.
/// Álló módban pedig a videó + a fejléc + az írósáv után a chat-listára ~40-60 px
/// maradt, ami használhatatlan.
///
/// **A megoldás:** az elrendezés **alkalmazkodik** a képernyőhöz:
///  * **keskeny** (álló telefon): videó felül — de **legfeljebb a magasság
///    [twitchVideoHeightFraction] része** —, alatta a chat;
///  * **széles** (fekvő telefon, tablet): videó **balra**, chat **jobbra**
///    ([twitchSideChatWidth] szélességben), így a chat mindig látszik.
library;

import 'dart:ui' show Size;

/// Az elrendezés két módja.
enum TwitchLayoutMode {
  /// Keskeny: videó felül, chat alatta.
  stacked,

  /// Széles: videó balra, chat jobbra.
  sideBySide,
}

/// Ettől a (logikai) szélességtől számít „szélesnek” a képernyő — a tabletek
/// álló módban is ide esnek (a tulajdonos kérése: *„figyelj a tabletre is”*).
const double twitchSideBySideMinWidth = 700;

/// A stacked módban a videó legfeljebb a rendelkezésre álló magasság ennyi
/// része lehet — a **chat kapja a többit** (*„az a chat rész elég pici”*).
const double twitchVideoHeightFraction = 0.34;

/// A chat oszlop szélessége oldal-egymás mellett (ebbe az irányba zárva).
const double twitchSideChatMinWidth = 320;
const double twitchSideChatMaxWidth = 460;

/// Melyik elrendezés való ehhez a képernyőhöz?
///
/// Széles, ha **legalább [twitchSideBySideMinWidth]** széles (tablet), **vagy**
/// ha **fekvő** (szélesebb, mint amilyen magas) — utóbbi a bejelentett hiba
/// („fekvő módban nincs chat”), mert ott a függőleges elrendezés lenullázta a
/// chatet.
TwitchLayoutMode twitchLayoutModeFor(Size size) {
  if (size.width >= twitchSideBySideMinWidth || size.width > size.height) {
    return TwitchLayoutMode.sideBySide;
  }
  return TwitchLayoutMode.stacked;
}

/// A videó magassága a **stacked** módban: 16:9 a szélességből, de legfeljebb a
/// magasság [twitchVideoHeightFraction] része (hogy a chatnek maradjon hely).
double twitchStackedVideoHeight(Size size) {
  final byWidth = size.width * 9 / 16;
  final cap = size.height * twitchVideoHeightFraction;
  return byWidth < cap ? byWidth : cap;
}

/// A videó magassága a **sideBySide** módban: 16:9 a bal oldali sáv szélességéből.
double twitchSideVideoHeight(Size size) {
  final columnWidth = size.width - twitchSideChatWidth(size);
  return columnWidth <= 0 ? 0 : columnWidth * 9 / 16;
}

/// A chat oszlop szélessége oldal-egymás mellett (a képernyő 38%-a,
/// [twitchSideChatMinWidth]…[twitchSideChatMaxWidth] között).
double twitchSideChatWidth(Size size) {
  final wanted = size.width * 0.38;
  if (wanted < twitchSideChatMinWidth) return twitchSideChatMinWidth;
  if (wanted > twitchSideChatMaxWidth) return twitchSideChatMaxWidth;
  return wanted;
}
