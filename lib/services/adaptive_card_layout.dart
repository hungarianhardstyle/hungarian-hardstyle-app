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

/// A kártya legnagyobb magassága a **képernyő magasságához** képest, széles
/// nézetben.
///
/// ⚠️ MIÉRT (a tulajdonos jelzése, 2026-10-03): *„ájfónon a kiemelt hír és a
/// twitch kártya a főoldalon ugyanakkora mint eddig, fekvő nézetben”*, majd
/// *„pedig elugattam, hogy túl nagy, bár túl kicsi se legyen”*.
///
/// A **mért** gyökér fekvő iPhone-on (667×375): a főoldali kiemelt hír
/// **354,9 px**, a Twitch-kártya **455,8 px** magas volt — utóbbi **magasabb a
/// képernyőnél**. A **szélesség-korlát** (760 px) ezt nem fogja meg, mert egy
/// 667 px széles telefon eleve keskenyebb annál: a **magasságot** kell
/// korlátozni. 0,55 × 375 = **206 px**, a tablet fekvő nézetében viszont
/// 0,55 × 768 = 422 px (a korábbi 460 helyett) — a szabály tehát épp ott szól
/// bele, ahol a tulajdonos jelezte.
const double wideCardHeightFraction = 0.55;

/// Széles-e az elrendezés? (fekvő telefon **vagy** tablet — állóban is.)
bool isWideCardLayout(Size size) =>
    size.width >= wideLayoutMinWidth || size.width > size.height;

/// A kártya legnagyobb magassága ehhez a képernyőhöz (álló nézetben korlátlan).
double wideCardMaxHeightFor(Size size) => isWideCardLayout(size)
    ? size.height * wideCardHeightFraction
    : double.infinity;

/// A kártya legnagyobb szélessége ehhez a képernyőhöz.
double cardMaxWidthFor(Size size) =>
    isWideCardLayout(size) ? wideCardMaxWidth : double.infinity;

/// A kiemelt hír legnagyobb szélessége **álló** nézetben (a régi érték).
const double heroCardMaxWidthPortrait = 820;

/// A kiemelt hír legkisebb magassága (a régi érték — álló nézetben ez a döntő).
const double heroCardMinHeight = 250;

/// A kiemelt hír „természetes” legnagyobb magassága (a régi érték).
const double heroCardMaxHeight = 460;

/// A főoldali **kiemelt hír** kártyájának a mérete — **tiszta**, ezért mérhető.
///
/// MIÉRT KÜLÖN (mért hiba, 2026-10-03): a keringő a **saját** méretét adta
/// (`constraints.maxWidth.clamp(0, 820)` + `width * 9 / 16` 250…460 között),
/// ezért fekvő iPhone-on a kártya **354,9 px** magas lett egy **375 px** magas
/// képernyőn — a tulajdonos jelzése: *„ugyanakkora mint eddig”*.
///
/// A szabály ugyanaz, mint a többi kártyánál: **álló** nézetben bitre a régi
/// (a tulajdonos szerint az jó), **széles** nézetben a közös szélesség- és
/// magasság-korlát.
///
/// @param viewport a képernyő logikai mérete (`MediaQuery.sizeOf`).
/// @param availableWidth a rendelkezésre álló szélesség (a lista belső szélessége).
({double width, double height}) heroCardSizeFor({
  required Size viewport,
  required double availableWidth,
}) {
  final wide = isWideCardLayout(viewport);
  final width = availableWidth.clamp(
    0.0,
    wide ? wideCardMaxWidth : heroCardMaxWidthPortrait,
  );
  final natural = (width * 9 / 16).clamp(heroCardMinHeight, heroCardMaxHeight);
  final cap = wideCardMaxHeightFor(viewport);
  return (width: width, height: natural > cap ? cap : natural);
}
