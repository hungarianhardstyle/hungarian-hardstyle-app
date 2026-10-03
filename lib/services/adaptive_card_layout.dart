/// **Széles elrendezés** (fekvő telefon, tablet) — egy helyen.
///
/// MIÉRT (a tulajdonos jelzései, 2026-10-03):
///  * *„Fekvő módban és tableten fekvő módban a friss hírek kártya és a twitch
///    beharangozó túl nagy. Álló módban jó!”*
///  * korábban: *„tableten a kiemelt hírek a hírek tabon nagyon nagyok”*.
///
/// A mért gyökér: a kártyák **16:9-es képe** a **teljes szélességhez** igazodott,
/// ezért fekvő módban (és tableten) a kép magassága a képernyő jelentős részét
/// elvitte. A régi szabály **csak a fekvő tájolást** nézte, ezért a **tablet álló**
/// nézete kimaradt — mostantól a **szélesség** dönt (ugyanaz a küszöb, mint a
/// Twitch-oldal elrendezésénél).
library;

import 'dart:ui' show Size;

/// Ettől a (logikai) szélességtől számít szélesnek a képernyő.
const double wideLayoutMinWidth = 700;

/// A kártya legnagyobb szélessége széles elrendezésben.
///
/// Ennél szélesebb kártyánál a 16:9-es kép már „óriási” lenne (a tulajdonos
/// jelzése), ezért a kártya **középre igazítva** ennyi marad.
const double wideCardMaxWidth = 760;

/// Széles-e az elrendezés? (fekvő telefon **vagy** tablet — állóban is.)
bool isWideCardLayout(Size size) =>
    size.width >= wideLayoutMinWidth || size.width > size.height;

/// A kártya legnagyobb szélessége ehhez a képernyőhöz.
double cardMaxWidthFor(Size size) =>
    isWideCardLayout(size) ? wideCardMaxWidth : double.infinity;
