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
    build: 345,
    changes: [
      'A megvásárolt zenéd mostantól kikapcsolt képernyőn is szól, és a zárképernyőn (meg az értesítésben) vezérelhető: előző, szünet, következő, stop és tekerés.',
      'Ha közben más app indít zenét, vagy hívást kapsz, a lejátszó szünetel — hívás után magától folytatja. A fejhallgató kihúzásakor is megáll.',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 344,
    changes: [
      'A frissen megvásárolt (vagy reklámmal feloldott) zene már másodperceken belül megjelenik a „Megvásárolt zenéim" listában — eddig előfordulhatott, hogy csak az app újraindítása után látszott.',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 343,
    changes: [
      'Gyorsabb betöltés: a hírek, a kiadványok és a saját zenéid a készüléken tárolt példányból azonnal megjelennek, a frissítés a háttérben fut.',
      'A lájk és az ismerősnek jelölés azonnal látszik — a szerver a háttérben dolgozik, hiba esetén a jelzés visszaáll és üzenetet kapsz.',
      'A „Megvásárolt zenéim" lejátszójában tekerhető a folyamatjelző, és külön stop gomb állítja le a zenét.',
      'Új lejátszási lista („Lista") a letöltött zenékből, ismétléssel (nincs / mind / egy) és keveréssel.',
      'A lejátszó felajánlja, hogy ott folytasd, ahol abbahagytad — fiókonként megjegyzi a helyet.',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 342,
    changes: [
      'Javítva: a „Megvásárolt zenéim" listában a kiadványok címe újra megjelenik (a 341-ben a kártyák végig „betöltés" állapotban maradtak).',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 341,
    changes: [
      'A „Megvásárolt zenéim" a Több menüben mostantól a menü többi szakaszához illeszkedik, és a neve is ezt tükrözi.',
      'A lejátszó csak a letöltött zenéket játssza: lapozásnál átugorja a még le nem töltötteket, és nem indít helyettük letöltést. Ha egy zene nincs meg, azt kiírja.',
      'Ha egy kiadvány időközben lekerült a nyilvános listáról (pl. régi reklámmal feloldott zene), azt mostantól megnevezzük — nem egy értelmezhetetlen „Kiadvány #szám" sort látsz.',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 340,
    changes: [
      'A kvíz mostantól azonnal jelzi, hogy már kitöltötted — eddig néhány másodpercig úgy látszott, mintha újra játszhatnál.',
      'Ez a telefon jegyzi meg, a szerver pedig a háttérben ellenőrzi: ha az admin újranyitja a kvízt, akkor újra játszható lesz.',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 339,
    changes: [
      'ÚJ: „Saját zenéim" a Több menüben — a megvásárolt (és reklámmal feloldott) zenéid egy helyen, a fiókodhoz kötve.',
      'Innen játszhatod le őket: a szám végén magától a következőre lép, és a sor a következő kiadvánnyal folytatódik.',
      'A zenék letölthetők a készülékre (offline is szólnak), és bármikor törölhetők — a vásárlás megmarad, ezért újra letölthetők.',
      'A régebbi vásárlásaid és reklámmal feloldott zenéid is megjelennek a listában.',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 338,
    changes: [
      'Értesítést kapsz, ha valaki kedveli a Chat-üzenetedet, vagy válaszol rá — és akkor is, ha a cikkhez írt hozzászólásodra válaszolnak. (Push helyett csak az app értesítéslistája szól.)',
      'Az app ikonja mutatja az olvasatlan értesítéseid számát.',
      'A rádió folyamatosan szól akkor is, ha a képernyő ki van kapcsolva — javítottuk a lejátszást, ami néhány perc után megállt.',
      'A rádió elhallgat, ha közben elindítasz egy másik zenét (Spotify, YouTube), és amint az befejeződik, magától folytatódik.',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 337,
    changes: [
      'A cikkekben lévő YouTube-videó mostantól az appban játszódik le: a videó a cikk „Média" szakaszában jelenik meg saját lejátszóval, nem nyitja meg a YouTube-alkalmazást.',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 336,
    changes: [
      'A Chat-üzeneteknél mostantól egyértelműen látszik, hogy TE már reagáltál: a reakciógomb bejelölve (pipa) és kiemelve jelenik meg. Nevek nem szerepelnek, csak a saját reakciód.',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 335,
    changes: [
      'Eseményt mostantól csak szervezői szerepkörrel lehet beküldeni (a DJ-t DJ-, a szervezőt szervezői szerepkörrel, ahogy eddig) — a gomb csak annak látszik, akinek szabad.',
      'Az Achievement-útmutató megmondja, ki mit küldhet be, és hogy a beküldésért járó pont a jóváhagyáskor jár a beküldőnek.',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 334,
    changes: [
      'Az Achievement-útmutató (Több → Achievementek) pontos leírásokat kapott: a napi keretek (lájk 3, komment 3, beküldés 3), a lájkpont véglegessége, és az is, hogy az esemény/meetup pont eseményenként egyszer jár, de lemondásnál elvész.',
      'A szintek és jelvények listája mostantól a szerverről jön, ezért azonnal követi, ha az adminban átírnak egy küszöböt vagy nevet.',
      'Kiadvány megvásárlásáért +20 pont jár minden megvásárolt változatért (a vásárlást a Google Play ellenőrzi).',
      'A jóváhagyott beküldésekért (esemény, DJ, szervező) +10 pont jár a beküldőnek, naponta legfeljebb 3 beküldésért.',
      'ÚJ napi aktivitási pont: a cikkhez írt hozzászólásaidért és a chat-üzeneteidért a következő napon 1–5 pontot kapsz, amennyit a szerver az aktivitásodból számol.',
      'A rangod és a jelvényed szintlépésnél magától frissül, nem kell újranyitni az appot.',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 332,
    changes: [
      'A hírek, a DJ-k és az események listája görgetés közben már nem villog — a képek áttűnés nélkül, azonnal megjelennek.',
      'Ha a napi lájkpontod (3) elfogyott, az app mostantól szól, mielőtt lájkolnál — eddig csendben maradt, pedig ilyenkor nem járt pont.',
      'A hír kedveléséért járó pontot a lájk visszavonása már nem veszi el, és a régebben tévesen elvett lájkpontok visszaálltak.',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 331,
    changes: [
      'A HUHS adminban (natív) mostantól új kérdőív, nyereményjáték és kvíz is létrehozható — nem kell hozzá a WordPress admin.',
      'A kvíz-szerkesztőben kérdéseket vehetsz fel 2–6 válasszal, és bepipálhatod a helyes választ; mentés előtt minden hibát megnevez a képernyő.',
      'A nyereményjátéknál a helyes válasz sorszámát adod meg, a látszási napokat pedig számban — a lista pedig azonnal frissül.',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 330,
    changes: [
      'A HUHS Vezérlőközpontban (natív admin) új menüpontok: „Kvíz és játékok", „Kérdőív" és „Nyereményjáték" — a kérdőív eredményei és a nyereményjáték résztvevői mostantól innen is elérhetők.',
      'A Vezérlőközpontban elérhető lett a „Hírlevél", a „Shortcode-ok" és a „Beállítások" menüpont is (eddig a háttérben már működtek, de nem lehetett megnyitni őket).',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 329,
    changes: [
      'A Chatben lefelé görgetve betölti a régebbi üzeneteket — akár hetekkel ezelőttit is visszaolvashatsz, és egy gombbal visszaugorhatsz a legfrissebbhez.',
      'A nyereményjáték és a kérdőív „már játszottam / már szavaztam" állapota azonnal megjelenik nyitáskor, nem kell a betöltésre várni.',
      'Adminoknak: új „Résztvevők" nézet a nyereményjátékhoz az appban — ki játszott, mit válaszolt, helyes volt-e, és ki nyert.',
    ],
  ),
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
