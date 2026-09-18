/// Az app kiadási jegyzete (changelog).
///
/// A tulajdonos kérése: *„az appról részbe legyen changelog is"*, illetve
/// korábban: *„a Névjegy alatt legyen aktuális changelog verziószámmal"*.
///
/// **A szöveg forrása a `docs/RELEASE_CHANGELOG_CHECKLIST.md`**, ami szerint
/// ugyanazt a magyar changelogot kell vezetni a Play Console-on, az app
/// Névjegyén és a WordPress-plugin kiadásjegyzékén. Ez a fájl az app oldali
/// példány, ezért **új kiadásnál ide is fel kell venni** a bejegyzést — a
/// `test/data/app_changelog_test.dart` pedig megköveteli, hogy a `pubspec.yaml`
/// verziójához tartozó bejegyzés létezzen, különben a felhasználó üres
/// changelogot látna a frissítés után.
library;

/// Egy kiadás: verzió, buildszám és a felhasználónak szóló pontok.
class AppReleaseNotes {
  const AppReleaseNotes({
    required this.version,
    required this.build,
    required this.changes,
  });

  /// A verzióneve (pl. `1.0.0`).
  final String version;

  /// A verziókód (pl. `326`). Ez az, amivel a Play azonosítja a kiadást, ezért
  /// ehhez hasonlítjuk az aktuális telepítést.
  final int build;

  /// A felhasználónak szóló pontok, magyarul, `- ` nélkül.
  final List<String> changes;
}

/// A kiadások, a LEGFRISSEBBEL ELÖL.
///
/// Csak olyan pont kerülhet ide, ami tényleg eljutott a felhasználóhoz — a
/// changelog nem ígérhet olyat, ami nincs a buildben.
const appChangelog = <AppReleaseNotes>[
  AppReleaseNotes(
    version: '1.0.0',
    build: 328,
    changes: [
      'A főoldalon a „További hírek" sor ugyanolyan kártyaformát kapott, mint a kérdőív és a nyereményjáték — így egységes a megjelenés.',
      'A GYIK (Segítség) témakörökre bontva, érthetőbben — és a pontok, valamint a napi limitek a valós értékeket mutatják.',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 327,
    changes: [
      'ÚJ: a Névjegy alatt mostantól látszik a kiadási jegyzet (changelog) verziószámmal.',
      'Az aktuális verzió ki van emelve, alatta a korábbi kiadások újdonságai.',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 326,
    changes: [
      'A Chatben a saját üzenetedet szerkesztheted, az admin bárkiét is — és az admin törölhet.',
      'Ugyanez a cikkek alatti hozzászólásoknál: a sajátodat szerkesztheted, az admin bárkiét.',
      'A szerkesztett üzenet és hozzászólás mellett „szerkesztve" jelzés látszik.',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 325,
    changes: [
      'Az értesítéseknél az „összes törlése" már csak a látható fület üríti: az Aktív fül az aktívakat, az Archivált fül az archiváltakat.',
      'A törlés megerősítő szövege megmondja, melyik fület érinti.',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 324,
    changes: [
      'A nyereményjáték nyertese már azonnal megjelenik a kártyán, nem késik perceket.',
      'A kérdőív nyitása és zárása is azonnal követi a szervert.',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 323,
    changes: [
      'A kérdőív eredményeinél már a kérdőív saját válaszai látszanak az éves szavazás adatai helyett.',
      'A nyereményjátéknál eltűnt a felesleges kép mező.',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 322,
    changes: [
      'ÚJ: Nyereményjáték a főoldalon — kvízkérdés, helyes válasszal részt veszel a sorsoláson.',
      'A nyertes nevét és a nyeremény leírását a játék lezárása után az app is mutatja.',
      'A Kérdőív és a Szavazz/Eredmények sor a főoldalon ugyanolyan széles, mint a felette lévő kártya.',
      'A kérdőív eredményeit csak adminisztrátor látja; adminnak szavazás nélkül is látszik.',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 321,
    changes: [
      'A kérdőívben a szavazatod állapota már nem ragad be: újranyitás után is helyesen látszik, szavaztál-e.',
      'Aki már szavazott, nem látja újra a válaszlehetőségeket.',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 320,
    changes: [
      'A kiadványoknál a „Hamarosan" kártya és a PRESAVE felület; a vásárlás a megjelenésig rejtve.',
      'A kiadvány előzetes lejátszója már a megjelenés előtt működik.',
      'Új Kérdőív kártya a főoldalon.',
      'Gyorsabb indulás és képbetöltés.',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 319,
    changes: [
      'A főoldalon megjelenik a nyitott kérdőív a kérdéssel.',
      'A kérdőív szavazólapja saját képernyőn nyílik, így nem nyomja el a hírfolyamot.',
    ],
  ),
];

/// Az aktuális telepítéshez tartozó kiadás, vagy null, ha ehhez a buildhez még
/// nincs bejegyzés (ilyenkor a felület jelzi, hogy nincs újdonság).
AppReleaseNotes? releaseNotesForBuild(
  Iterable<AppReleaseNotes> notes,
  int build,
) {
  for (final note in notes) {
    if (note.build == build) return note;
  }
  return null;
}

/// Igaz, ha a kiadás **régebbi**, mint az aktuális build.
///
/// Ez alapján a felület a régieket halványabban, „Korábbi kiadások" fejléccel
/// mutatja, az aktualitást pedig kiemeli — a legfrissebbel kezdve.
bool isOlderRelease(AppReleaseNotes note, int currentBuild) =>
    note.build < currentBuild;

/// A kiadások rendezve, a legfrissebbel elöl.
///
/// A lista kézzel szerkesztett, ezért ez a függvény védi meg a felületet attól,
/// hogy egy elrontott sorrend miatt a régi kiadás kerüljön felülre.
List<AppReleaseNotes> sortedChangelog(Iterable<AppReleaseNotes> notes) {
  final sorted = notes.toList()
    ..sort((a, b) => b.build.compareTo(a.build));
  return sorted;
}
