/// A főoldali akciósorok (kérdoív, nyeremenyjatek) állapot-döntése.
///
/// **MÉRT OK (a tulajdonos panasza: „...ez az új megvárásolt zenéim is lassan
/// tölt be", és a főoldali sorok másodpercekkel később pattantak be):** a
/// WordPress válaszideje 0,4–2,0 s, ezért a sor eddig üres helyet hagyott
/// (`SizedBox.shrink()`), majd hirtelen megjelent — a főoldal egyet ugrott.
///
/// A döntés ezért **három** állapot, nem kettő:
///
///  * [HomeRowView.content] — van mit rajzolni;
///  * [HomeRowView.loading] — még nincs válasz: a sor **helyét** megtartjuk egy
///    skeletonnal (ugyanolyan magasság és belső margó, mint a valódi kártyánál),
///    így nem ugrik a főoldal, amikor a kártya megérkezik;
///  * [HomeRowView.empty] — tudjuk, hogy nincs mit mutatni (a válasz megvan, és
///    null), vagy hibára futottunk: a sor eltűnik. **Hibánál nem rajzolunk
///    kártyát**, mert az hazugság lenne (nem tudjuk, van-e nyitott kérdoív).
///
/// Tiszta függvény (nem Flutter-widget), ezért a döntés hálózat és Firebase
/// nélkül mérhető.
library;

enum HomeRowView { content, loading, empty }

/// Mit rajzoljon a sor a provider aktuális állapotából.
HomeRowView homeRowView({
  required bool hasValue,
  required bool hasContent,
  required bool isLoading,
}) {
  if (hasContent) return HomeRowView.content;
  // A válasz már megvan, csak épp nincs mit mutatni (nincs nyitott kérdoív):
  // ilyenkor nem skeleton jön, hanem a sor eltűnik — ez a régi, helyes
  // viselkedés.
  if (hasValue) return HomeRowView.empty;
  // Még nincs válasz: a helyet megtartjuk, hogy a főoldal ne ugráljon.
  if (isLoading) return HomeRowView.loading;
  // Hiba: nem tippelünk kártyával.
  return HomeRowView.empty;
}
