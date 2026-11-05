/// A **jogi oldalak** egyetlen helyen (build 406).
///
/// MIÉRT: a tulajdonos kérdése — *„hol az app ÁSZF linkje?”*. A mérés szerint a
/// két jogi oldal **él** a WordPressben (HTTP 200), de az appban **semmilyen
/// hivatkozás** nem volt rájuk. A Play/App Store és az előfizetés (Hardstyle
/// Revolution Label) is megköveteli, hogy a feltételek elérhetők legyenek, ezért
/// a Névjegy alatt mostantól mindkettő ott van.
///
/// ⚠️ Ha a WordPressben átnevezed az oldalakat, CSAK ezt a két állandót kell
/// módosítani — a felület innen olvassa.
library;

/// Az ALKALMAZÁS Általános Szerződési Feltételei (élő oldal: HTTP 200, 2026-11-05;
/// ez az URL kell a Play „kereskedői állapot” képernyőjének ÁSZF-mezőjébe is).
const String legalTermsOfServiceUrl =
    'https://hungarianhardstyle.hu/app-felhasznalasi-feltetelek/';

/// Adatkezelési tájékoztató / adatvédelmi nyilatkozat (élő oldal: HTTP 200).
const String legalPrivacyPolicyUrl =
    'https://hungarianhardstyle.hu/adatvedelmi-nyilatkozat/';
