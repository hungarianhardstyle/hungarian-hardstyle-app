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
    build: 367,
    changes: [
      'Javítva: angol felületen a játék eredményei képernyő fejléce (és a főoldali „JÁTÉK EREDMÉNYEI" jelvény) is angolul jelenik meg — eddig ezek magyarul maradtak.',
      'Javítva: angol felületen a válasz-előnézet is angolul szól a Chatben és a hozzászólásoknál („Válasz … üzenetére / hozzászólására").',
      'Javítva: további angolul maradt feliratok — a hozzászólás-előtag, az adatvédelmi tájékoztató és a Saját zenék súgóinak mondatai (a szótár ezeket eddig nem találta meg).',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 366,
    changes: [
      'Javítva: a kiadványok dátum-címkéje („Megjelenés: …") és a DJ-adatlap „Megjelenései" rovata angol felületen is angolul jelenik meg.',
      'Javítva: nyelvváltáskor a betöltött tartalom (hírek, események, DJ-k, kiadványok) azonnal átvált a választott nyelvre — eddig a mentett lista miatt késlekedett.',
      'A GYÍK neve angolul „FAQ", és a válaszaiban nincs többé formázás-szemét (a `</p>` tagek eltűntek).',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 365,
    changes: [
      'ÚJ: a főoldal és a Hírek fül listája magától frissül — ha új cikk kerül fel, az legfeljebb egy percen belül megjelenik, lehúzás nélkül; amikor az app előtérbe kerül (például egy értesítésre nyitod meg), azonnal ellenőrizzük.',
      'ÚJ a Chatben: a válasz idézetére koppintva az app ODAUGRLIK az eredeti üzenetre a beszélgetésben (és rövid ideig kiemeli) — nem nyit külön ablakot.',
      'Angol felületen a „Bulizó" szerepkör felirata mostantól „Partyface".',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 364,
    changes: [
      'Az értesítések is a választott nyelven jönnek: a Chat-lájk, a válasz, a megemlítés, a hozzászólás, az esemény-értékelés, az új tartalom, a nyeremény és az ismerősnek jelölés szövege is angolul jelenik meg, ha angolra váltottál.',
      'A beállított nyelv a profilodban tárolódik, ezért a push értesítések is a te nyelveden szólnak.',
      'Az angol felület tovább bővült: a hosszú magyarázó és jogi szövegek (adatkezelési tájékoztató, súgók) is angolul jelennek meg.',
      'Angol felületen a hírek kategória- és címke-nevei is angolul jelennek meg (pl. Hírek → News, fesztivál → festival) — a DJ- és márkanevek változatlanok maradnak.',
      'Angol felületen az Achievement-nevek és -leírások is angolul jelennek meg — a HUHS Legenda toplistában és a közösségi listában is —, és a „Közösség" gomb felirata (Community) is kifér a fejlécben.',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 363,
    changes: [
      'Az angol felületen további sok száz felirat jelenik meg angolul: a listák, kártyák, gombok és állapotüzenetek szövegei, amelyek eddig részben magyarul maradtak.',
      'A magyar felület változatlan, és a Chat, valamint a felhasználók saját szövegei továbbra sem fordulnak le.',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 362,
    changes: [
      'Angol felületnél a legutóbbi cikkek is angolul jelennek meg — a fordítást a szerver adja.',
      'Nyelvváltáskor a betöltött tartalom is frissül, ezért nem marad más nyelvű lista a képernyőn.',
      'Több képernyőn (Több, Beállítások, Névjegy, hírlevél, zene) a hosszabb magyarázó szövegek is angolul jelennek meg.',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 361,
    changes: [
      'ÚJ: HU/EN nyelvváltó a főoldal jobb sarkában — az app felülete (menük, gombok, üzenetek) angolul is elérhető.',
      'A magyar marad az alapértelmezett, a választás megjegyződik. A Chat és a felhasználók saját szövegei nem fordulnak le.',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 360,
    changes: [
      'ÚJ a Chatben: @mindenki — ha beírod, mindenki értesítést kap az üzenetről. Ezt csak admin/moderátor tudja használni.',
      'A Chat-értesítésre koppintva az app mostantól a mélyebben lévő, régebbi üzeneteknél is pontosan a megjelölt üzenetre ugrik.',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 359,
    changes: [
      'A Chat-értesítésre koppintva az app mostantól MINDIG a megjelölt üzenetre ugrik — eddig hideg indításnál (amikor a Chat még nem volt megnyitva) ez elmaradhatott.',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 358,
    changes: [
      'ÚJ a Chatben: @-tal hivatkozhatsz valakire vagy valamire — személyre, cikkre, DJ-re, szervezőre, eseményre és kiadványra. Elég beírni a @ jelet és a név első betűit, a lehetőségeket magától feldobja.',
      'A hivatkozás kattintható: a személynél a profilja, a cikknél a cikk, a DJ-nél az adatlapja, a szervezőnél, az eseménynél és a kiadványnál a saját oldala nyílik meg.',
      'Ha valakit megemlítesz, az értesítést kap róla, és a koppintás egyenesen arra a Chat-üzenetre visz.',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 357,
    changes: [
      'Az értesítéseknél mostantól látszik, KI kedvelte a Chat-üzenetedet, és ki szólt hozzá egy cikkhez — eddig csak annyi volt, hogy „kedvelték", illetve „valaki hozzászólt".',
      'A Chat-értesítésre koppintva a Chat egyenesen arra az üzenetre ugrik, amelyről az értesítés szól, és rövid ideig ki is emeli — nem kell magadtól megkeresni.',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 356,
    changes: [
      'A hírlevélnél nem megy ki újra a megerősítő e-mail arra a címre, amelyre már kiment — a képernyő megmondja, hogy már feliratkoztál, vagy hogy hamarosan újra kérheted. Eddig ugyanarra a címre korlátlanul lehetett megerősítő levelet generálni.',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 354,
    changes: [
      'ÚJ: a DJ-adatlapon mostantól látszanak a DJ megjelenései — azok a kiadványok, amelyekben szerepel. A legfrissebb van elöl, négy darabig, alatta pedig az „Összes megjelenése" gomb nyitja a teljes listát.',
      'A kiadvány-kártya ugyanaz, mint a kiadványok listájában: a borítót, az előadókat, a megjelenés dátumát és a műfajt mutatja, és koppintásra megnyílik az adatlap.',
      'A szakasz a mentett adatból azonnal megjelenik, és csak akkor látszik, ha a DJ-nek van megjelenése — üresen nem hagy helyet.',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 353,
    changes: [
      'A kvíz azonnal mutatja, hogy már játszottál — nem kell megvárni a betöltést.',
      'A DJ-adatlap „ez az enyém / átvehető" állapota és a profil DJ-adatlap kártyái azonnal megjelennek: a telefon a legutóbbi ismert állapotot mutatja, és közben a háttérben frissít.',
      'Belső frissítés: a bejelentkezés, az adatbázis, az értesítések és a vásárlás mögötti Firebase-összetevők újabb verzióra kerültek (a Google legfrissebb javításaival).',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 352,
    changes: [
      'ÚJ: „Vásárlási diagnosztika" a „Több → Az appról" képernyőn. Ha egy vásárlás nem indul el, egy gomb megmutatja, mit válaszol a Google Play az adott készüléken: hány terméket lát, milyen áron és pénznemben, és mi volt a legutóbbi hiba kódja — a jelentést egy mozdulattal el lehet küldeni.',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 351,
    changes: [
      'Javítva: az értesítéseknél mostantól TÖBB sor is kijelölhető egyszerre — eddig minden koppintás lecserélte az előző kijelölést, ezért csak egyet vagy az összeset lehetett.',
      'ÚJ: az átvett DJ-adatlapodat te szerkesztheted (név, bemutatkozás, közösségi linkek, képcsere).',
      'ÚJ: az értesítéseket ki lehet jelölni törléshez — csak azt törlöd, amit akarsz.',
      'A „Claim" helyett magyar szó: „Adatlap átvétele"; és az adatlapok aljára rendesen le lehet görgetni.',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 350,
    changes: [
      'ÚJ: az átvett DJ-adatlapodat mostantól te szerkesztheted az appban — név, valódi név, város, ország, bemutatkozás, közösségi linkek és a kép cseréje. A foglalási e-mail cím és a mûfajok továbbra is a Hungarian Hardstyle kezében maradnak.',
      'ÚJ: az értesítéseket ki lehet jelölni törléshez — így csak azt törlöd, amit akarsz, nem az egész listát és nem is egyenként. A fejlécben a pipa ikon indítja a kijelölést.',
      'A „Claim" helyett mindenhol magyar szó áll: „Adatlap átvétele" — az átvétel visszavonása, az átvett adatlap jelölése és a hibaszövegek is ezt használják.',
      'Javítva: az értesítésre megnyíló saját adatlap aljára mostantól rendesen le lehet görgetni (az utolsó kártya nem marad a rendszer sávja alatt). Ugyanez a javítás a hír-, esemény-, DJ- és szervező-adatlapokon is egységes lett.',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 349,
    changes: [
      'Javítva: a jutalmazott reklámmal feloldható ingyenes külső link mostantól tényleg megnyílik — eddig hiába futott le a reklám, a feloldás elveszett.',
      'Javítva: tableten fekvő nézetben a kiadvány adatlapja nem lesz óriási — a borító és a teljes tartalom is normál méretű.',
      'Javítva: a DJ-k és a szervezők listája nem villog többé: a háttérben frissülő tartalom nem üríti ki a listát.',
      'Javítva: a „Megvásárolt zenéim" listában nem látszik többé az a kiadvány, amely már nincs a nyilvános listában.',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 348,
    changes: [
      'DJ-adatlapot mostantól csak az claimelhet (jelölhet a magáénak), akinek a bejelentkezési e-mail címe egyezik az adatlapon szereplő booking vagy privát e-mail címmel. Eddig előfordulhatott, hogy idegen adatlap került egy fiókra.',
      'A „DJ-adatlap claimelése" gomb csak akkor jelenik meg, ha valóban a tiéd lehet az adatlap — és a saját claimet bármikor visszavonhatod.',
      'A profilodon megjelenik a claimelt DJ-adatlapod egy kattintható kártyaként.',
      'Javítva: az „Új DJ került fel" értesítésre koppintva megnyílik az adott DJ adatlapja (eddig semmi nem történt). Ugyanígy nyílik az „Új szervező" és a chatjelentés értesítés is.',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 347,
    changes: [
      'A megvásárolt zene lejátszója a képernyő elhagyása után is vezérelhető: a zárképernyő következő/előző gombja mostantól működik, és a dal végén magától jön a következő (eddig ott megállt a zene).',
      'A lejátszási lista keverése stabil: a „következő" tétel nem ugrál akkor sem, ha közben frissül a lista (új vásárlás, új letöltés).',
      'Tableten fekvő nézetben a kiemelt hírkártyák és a játék kártya akkora, mint a többi kártya — eddig a teljes szélességben óriásira nőttek.',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 346,
    changes: [
      'Javítva: a „Megvásárolt zenéim" lejátszója elindul — a 345-ben néma maradt, és egy angol hibaüzenetet írt ki.',
      'Javítva: minden hibaüzenet magyar (eddig a lejátszó hibája angolul jelent meg).',
      'Javítva: ha egy zene indítása nem sikerül, a hang visszakerül a rádióhoz, és az app nem némul el.',
      'Javítva: a lejátszási lista és a lapozás mindig az összes letöltött zenét mutatja (előfordult, hogy csak egy tételt látott).',
      'Javítva: a zárképernyőn a tekerősáv hossza és az aktuális tétel jelölése is helyes.',
    ],
  ),
  AppReleaseNotes(
    version: '1.0.0',
    build: 345,
    changes: [
      'A megvásárolt zenéd mostantól kikapcsolt képernyőn is szól, és a zárképernyőn (meg az értesítésben) vezérelhető: előző, szünet, következő, stop és tekerés.',
      'Ha közben más app indít zenét, vagy hívást kapsz, a lejátszó szünetel — hívás után magától folytatja. A fejhallgató kihúzásakor is megáll.',
      'A lejátszási listáról ki tudsz venni egy letöltött zenét (a fájl a készüléken marad), és bármikor vissza is teheted — a döntést fiókonként megjegyzi.',
      'A lejátszási lista sorrendjét kézzel is rendezheted (fel/le mozgatás a „Lista" panelen) — a sorrendet fiókonként megjegyzi.',
      'A frissen megvásárolt (vagy reklámmal feloldott) zene másodperceken belül megjelenik a listában.',
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
