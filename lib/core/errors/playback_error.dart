/// A **lejátszó** hibaüzenetei — mindig magyarul.
///
/// A tulajdonos jelzése a 345-ös csomag után: a képernyőn egy **angol** motor-
/// üzenet jelent meg („You cannot add items while items are being added from
/// addStream"), és a kérése: *„a hibaüzeneteket amúgy is magyarul kéne"*.
///
/// MIÉRT KÜLÖN FÜGGVÉNY: a lejátszó hibái technikaiak (fájl eltűnt, dekódolási
/// hiba, szolgáltatás-hiba), és a felhasználónak **cselekvést** kell mondani,
/// nem a kivétel szövegét. A technikai okot a naplóba írjuk (`debugPrint`), a
/// felületre magyar mondat kerül. Így egy csomagfrissítés sem tud angol szöveget
/// kijuttatni a felületre.
library;

/// A lejátszás-indítás hibájának magyar üzenete.
///
/// Sorrend szándékos: a **fájl eltűnését** előbb nézzük (ilyenkor a „töltsd le
/// újra" a hasznos tanács), aztán a formátum/dekódolás, végül az általános.
String playbackErrorMessage(Object? error) {
  final raw = '${error ?? ''}'.toLowerCase();
  if (raw.contains('no such file') ||
      raw.contains('cannot open') ||
      raw.contains('filenotfound') ||
      raw.contains('os error') ||
      raw.contains('not found')) {
    return 'A letöltött fájl nem található a készüléken — töltsd le újra ezt a zenét.';
  }
  if (raw.contains('unsupported') ||
      raw.contains('format') ||
      raw.contains('decoder') ||
      raw.contains('codec')) {
    return 'Ezt a fájlt a telefon nem tudja lejátszani. Próbáld újra letölteni.';
  }
  if (raw.contains('permission')) {
    return 'A lejátszáshoz nincs engedély a fájlhoz. Indítsd újra az appot.';
  }
  return 'A lejátszás nem indult el. Próbáld újra.';
}
