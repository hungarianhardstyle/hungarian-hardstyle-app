<?php
/**
 * GYIK — a felhasznalonak szolo, emberi szovegek (v4).
 *
 * A TULAJDONOS JELZESE: „nezzuk meg a GYIK menut is mert most eleg gagyi,
 * ertheto normalis funkcio ismerteto kell, nem pedig mindenfele Firebase meg
 * semmi ertelme duma, es csak az elerheto funkciokrol segitseg".
 *
 * MI VOLT A BAJ (merve, nem sejtve):
 *  1. TARGYI HIBA: a „Hogyan mukodnek az achievement pontok?" azt allitotta,
 *     hogy cikkkommentert „naponta legfeljebb ot alkalom" jar. A kodban a plafon
 *     HAROM (`ARTICLE_COMMENT_DAILY_POINT_LIMIT = 3`). Aki elhitte, a negyedik
 *     komment utan azt hitte, elromlott az app.
 *  2. DUPLIKACIO: a „Hogyan torolhetem a profilomat?" ket kulon bejegyzeskent
 *     szerepelt (12172 es 12076).
 *  3. RENDSZERLEIRAS A SEGITSEG HELYETT: „Ugyanaz az inditasi kep egy telefonon
 *     ket oran belul nem jelenik meg ujra." — ez a mukodes leirasa, nem segitseg.
 *  4. ZAJ: „Mire keres ra a hirek keresője?" (a kereso definicioja) es a kulso
 *     oldalak jogi bekezdese.
 *  5. HIANYZO TEMAK: a nyeremenyjatekrol es a kerdőívrol EGYETLEN szo sem volt,
 *     az ertesitesek Aktv/Archivalt fuleerol sem.
 *  6. SORREND: a v3 seeder minden bejegyzesnek `menu_order = 100`-at adott, a
 *     jatekoknak 95-ot, 16 bejegyzesnek pedig 0-t — ezert a lista eljen
 *     osszevissza, kategoria nelkul keveredve jelent meg.
 *
 * AMIT EZ A MIGRACIO TESZ: temakorokbe rendezi a GYIK-et (a temakor-sorrend
 * a `menu_order` tizes egysegeivel), es a fenti szovegeket irja be. Egyesevel,
 * nev (slug) szerint, ezert UJRATFUTTATVA IS ugyanazt adja. A felhasznalo altal
 * kesobb atirt szoveget a `_huhs_faq_content_version` meta vedi: ha valaki
 * kezzel atirta, a migracio NEM irja felul.
 */

if (!defined('ABSPATH')) {
    exit;
}

add_action('admin_init', 'huhs_seed_human_faq_once');

/**
 * A GYIK-szovegek (es a hozza tartozo migracio) verzioja.
 *
 * EMELNI KELL, ha a szoveg VAGY a migracio viselkedese valtozik — kulonben a
 * migracio NEMAN elhal: a `huhs_seed_human_faq_once()` a
 * `huhs_faq_human_version` opcioval osszevetve rogton visszater.
 *
 * EZ PONTOSAN MEGTORTENT: a 2.5.3 is a 4-es verziojelzot hasznalta, es az
 * opcio elesben mar 4-en allt. Ezert a szigorubb nyugdijazas a 4-es jelzovel
 * SOHA nem futott volna le. A javitas az 5-os emeles.
 */
define('HUHS_FAQ_CONTENT_VERSION', 5);

/**
 * A temakorok es a hozzajuk tartozo sorszam-tartomany.
 *
 * A `menu_order` tizes egysegei adjak a temakor-sorrendet, a tizesen beluli
 * ertek pedig a temakoron beluli sorrendet. Igy a GYIK listaja tematikusan
 * rendezett marad, es kesobb is konnyen bovitheto.
 */
function huhs_faq_v4_groups()
{
    return array(
        'elso-lepesek' => array('name' => 'Első lépések', 'base' => 100),
        'kozosseg' => array('name' => 'Közösség', 'base' => 200),
        'hirek-es-ertesitesek' => array('name' => 'Hírek és értesítések', 'base' => 300),
        'zene-es-kiadvanyok' => array('name' => 'Zene és kiadványok', 'base' => 400),
        'jatekok' => array('name' => 'Játékok', 'base' => 500),
        'szavazas-es-nyeremenyjatek' => array('name' => 'Szavazás és nyereményjáték', 'base' => 600),
        'segitseg-es-adatvedelem' => array('name' => 'Segítség és adatvédelem', 'base' => 700),
    );
}

/**
 * A GYIK bejegyzesek: nev (slug), temakor, kerdes, valasz, temakoron beluli sorrend.
 *
 * A valaszok SZANDEKOSAN rovidek es a felhasznalonak szolnak. Technikai reszlet
 * (Firebase, fajlformatum, bitrata, cache) NEM kerulhet bele — a tulajdonos
 * kifejezett keresere.
 */
function huhs_faq_v4_items()
{
    return array(
        /* --- Elso lepesek ------------------------------------------------ */
        array(
            'slug' => 'hogyan-regisztralhatok',
            'group' => 'elso-lepesek',
            'order' => 1,
            'title' => 'Hogyan regisztrálhatok?',
            'content' => 'Koppints a Regisztrációra, add meg a kért adatokat, majd erősítsd meg az e-mail-címedet a kapott levélben. Google-fiókkal is regisztrálhatsz — akkor e-mail-megerősítésre nincs szükség. Utána saját profilod lesz, és használhatod a közösségi funkciókat.',
        ),
        array(
            'slug' => 'bejelentkezes-nelkul-elerheto-funkciok',
            'group' => 'elso-lepesek',
            'order' => 2,
            'title' => 'Mely funkciók használhatók bejelentkezés nélkül?',
            'content' => 'Bejelentkezés nélkül is böngészheted a híreket, az eseményeket, a DJ-ket és a kiadványokat, hallgathatod a rádiót, szavazhatsz az éves szavazáson és hozzászólhatsz a cikkekhez. A Chathez, a privát üzenetekhez, a kedvencekhez, a jelvényekhez és a vásárlásokhoz viszont fiók kell.',
        ),
        array(
            'slug' => 'miert-erdemes-kitolteni-a-profit',
            'group' => 'elso-lepesek',
            'order' => 3,
            'title' => 'Miért érdemes kitölteni a profilomat?',
            'content' => 'Mert a profilodból dolgozik a közösség: a neved és a képed jelenik meg a chatben és a hozzászólásoknál, és a profilod adja a rangodat. Ráadásul a teljes profilért 30 achievement-pontot kapsz egyszer.',
        ),
        array(
            'slug' => 'fiok-torlese',
            'group' => 'elso-lepesek',
            'order' => 4,
            'title' => 'Hogyan törölhetem a fiókomat?',
            'content' => 'A profilod beállításainál indíthatod el a fiók törlését, majd meg kell erősítened. A törlés után a hozzád tartozó helyi adatok és a gyorsítótár is törlődik, és visszakerülsz a kezdőlapra. A törlés végleges, ezért csak akkor csináld, ha biztos vagy benne.',
        ),

        /* --- Kozosseg ---------------------------------------------------- */
        array(
            'slug' => 'hogyan-mukodik-a-chat',
            'group' => 'kozosseg',
            'order' => 1,
            'title' => 'Hogyan működik a chat?',
            'content' => 'A nyilvános chatben mindenki látja az üzeneteidet, a privát beszélgetésekben csak te és a másik fél. Tudsz válaszolni egy üzenetre, emojival reagálni, és a saját üzenetedet utólag szerkeszteni is. Ha valami nem oda való, jelentsd vagy tiltsd le azt a felhasználót.',
        ),
        array(
            'slug' => 'cikkek-kommentelese',
            'group' => 'kozosseg',
            'order' => 2,
            'title' => 'Tudok hozzászólni a cikkekhez?',
            'content' => 'Igen, minden cikknek külön hozzászólásai vannak — így nem keverednek össze a különböző cikkek alatti beszélgetések. Bejelentkezés nélkül is írhatsz, ilyenkor egy automatikus nevet kapsz; regisztráltan a saját profilneved jelenik meg. A saját hozzászólásodat később szerkesztheted, és ha valaki mást ír, válaszolhatsz rá.',
        ),
        array(
            'slug' => 'mit-jelent-a-kedvencek',
            'group' => 'kozosseg',
            'order' => 3,
            'title' => 'Mit jelent a kedvencek?',
            'content' => 'A kedvencekbe a számodra érdekes DJ-ket és szervezőket mentheted el, hogy később könnyen megtaláld őket. A jelölést ugyanott vissza is vonhatod. Ez független a hírek kedvelésétől.',
        ),
        array(
            'slug' => 'achievement-pontok',
            'group' => 'kozosseg',
            'order' => 4,
            'title' => 'Hogyan gyűjthetek achievement-pontokat?',
            'content' => "A közösségben végzett tevékenységekért pont jár:\n\n• profil teljes kitöltése — 30 pont (egyszer)\n• éves szavazás leadása — 10 pont\n• lejárt esemény értékelése — 10 pont\n• Meetup jelzés — 5 pont\n• játék teljesítése — 1–20 pont az eredménytől függően\n• ajánlás, ha a meghívottad regisztrál — 50 pont\n• cikk kedvelése — 2 pont\n• cikkhez írt hozzászólás — 1 pont\n\nHír kedveléséért és hozzászólásért naponta legfeljebb 3-3 alkalommal jár pont — a többi lájkolás és komment természetesen működik, csak nem ad több pontot aznap. A pontjaidból rangot és jelvényt kapsz, és szintlépésnél értesítést is kapsz.",
        ),
        array(
            'slug' => 'rangok-es-jelvenyek',
            'group' => 'kozosseg',
            'order' => 5,
            'title' => 'Mit jelentenek a rangok és a jelvények?',
            'content' => 'A rangod és a jelvényed a megszerzett pontjaid alapján jelenik meg. Mások a nyilvános profilodon és a chatben is a jelenlegi állapotodat látják. Ha új rangot érsz el, a profilod magától frissül, és értesítést is kaphatsz róla.',
        ),
        array(
            'slug' => 'mi-az-a-meetup',
            'group' => 'kozosseg',
            'order' => 6,
            'title' => 'Mi az a Meetup?',
            'content' => 'Ha egy eseménynél bejelölöd a Meetupot, akkor jelzed, hogy szívesen találkoznál más résztvevőkkel. Ők az esemény adatlapján látják, hogy ott leszel — így könnyebb egymásra találni egy bulin. A jelzésért 5 pont jár.',
        ),
        array(
            'slug' => 'esemeny-ertekelesc',
            'group' => 'kozosseg',
            'order' => 7,
            'title' => 'Hogyan értékelhetek egy eseményt?',
            'content' => 'Lejárt eseményt csak az értékelhet, aki korábban jelezte, hogy ott lesz. Az értékelés 1–5 csillagos, egyszer adható le, és később nem módosítható. Az értékelésért 10 achievement-pont jár, az esemény összesített értékelése pedig csillagokkal jelenik meg az adatlapján.',
        ),

        /* --- Hirek es ertesitesek --------------------------------------- */
        array(
            'slug' => 'hirek-kedvelese',
            'group' => 'hirek-es-ertesitesek',
            'order' => 1,
            'title' => 'Hogyan kedvelhetem a híreket?',
            'content' => 'A híreknél a kedvelés gombbal jelezheted, hogy tetszett a cikk, és a reakciód később vissza is vonhatod. A hírek mindig azt mutatják, ami a weboldalon is látszik, tehát frissítés után ugyanazt kapod, mint a gépen.',
        ),
        array(
            'slug' => 'hogyan-kapok-ertesitest',
            'group' => 'hirek-es-ertesitesek',
            'order' => 2,
            'title' => 'Hogyan kapok értesítést?',
            'content' => 'Értesítést kaphatsz új hírekről, közelgő eseményekről, privát üzenetről, a hozzászólásaidra érkező válaszról, valamint pont- és szintlépésről. A Beállításokban kiválaszthatod, melyik típusokról szeretnél értesülni. Ha egy értesítésre koppintasz, azonnal a hozzá tartozó tartalom nyílik meg.',
        ),
        array(
            'slug' => 'aktiv-es-archivalt-ertesitesek',
            'group' => 'hirek-es-ertesitesek',
            'order' => 3,
            'title' => 'Mi az „Aktív" és az „Archivált" fül az értesítéseknél?',
            'content' => 'Az Aktív fülön a friss értesítések vannak, az Archivált fülre azok kerülnek, amelyeket elolvastál és eltettél. Így a lényeges dolgok nem vesznek el a sok olvasott között. A törlés mindig csak a látható fülre vonatkozik: az Aktív fül az aktívakat törli, az Archivált fül az archiváltakat.',
        ),
        array(
            'slug' => 'hirlevel-feliratkozas',
            'group' => 'hirek-es-ertesitesek',
            'order' => 4,
            'title' => 'Hogyan iratkozhatok fel a hírlevélre?',
            'content' => 'A Hírlevél résznél add meg az e-mail-címedet, majd erősítsd meg a feliratkozást a kapott levélben. Az appban visszajelzést kapsz arról, hogy a megerősítés sikerült. A leiratkozás ugyanitt bármikor elindítható.',
        ),

        /* --- Zene es kiadvanyok ----------------------------------------- */
        array(
            'slug' => 'kiadvany-elozetes',
            'group' => 'zene-es-kiadvanyok',
            'order' => 1,
            'title' => 'Hogyan hallgathatom meg előre egy kiadványt?',
            'content' => 'A kiadvány adatlapján általában van egy rövid előzetes, amit egy lejátszóval azonnal meg is hallgathatsz. Ez a megjelenés előtt is működik, így előre be tudod lőni, tetszik-e.',
        ),
        array(
            'slug' => 'vasarlas-es-letoltes',
            'group' => 'zene-es-kiadvanyok',
            'order' => 2,
            'title' => 'Hogyan vásárolhatok és tölthetek le zenét?',
            'content' => 'A teljes, jó minőségű változatot megvásárlás után töltheted le. A kisebb minőségű MP3 egy rövid reklám megtekintésével ingyen nyílik meg. A vásárláshoz és a védett letöltésekhez be kell jelentkezned, a fizetést a Google Play intézi.',
        ),
        array(
            'slug' => 'radio-es-extended-valtozat',
            'group' => 'zene-es-kiadvanyok',
            'order' => 3,
            'title' => 'Mi a különbség a Radio és az Extended változat között?',
            'content' => 'A Radio a rövidebb, rádióbarát változat, az Extended a hosszabb klubverzió. Nem minden kiadványnál van mindkettő — mindig az adatlap mutatja, mi érhető el.',
        ),
        array(
            'slug' => 'vasarlas-visszaallitasa',
            'group' => 'zene-es-kiadvanyok',
            'order' => 4,
            'title' => 'Már megvettem korábban — hogyan kapom vissza?',
            'content' => 'Ha ugyanazzal a Google-fiókkal vásároltad, a vásárlásod visszaállítható. Sikeres ellenőrzés után a letöltés gomb ismét megjelenik. Ha mégsem, indítsd el a vásárlások visszaállítását, és próbáld újra.',
        ),
        array(
            'slug' => 'radio-hallgatasa',
            'group' => 'zene-es-kiadvanyok',
            'order' => 5,
            'title' => 'Hallgathatom a rádiót az appban?',
            'content' => 'Igen. A lejátszó gombjával indíthatod, a hangerőt a lejátszónál állíthatod, és a lejátszás akkor is megy, ha közben másik képernyőt nyitsz meg.',
        ),

        /* --- Jatekok ----------------------------------------------------- */
        array(
            'slug' => 'milyen-jatekok-vannak',
            'group' => 'jatekok',
            'order' => 1,
            'title' => 'Milyen játékok vannak?',
            'content' => 'Időszakosan elérhető HUHS-játékokat találsz, például kvízt és Hardstyle idővonalat. A játékokért a teljesítményedtől függően achievement-pont jár, az eredményeidet pedig az app mutatja.',
        ),
        array(
            'slug' => 'jatekok-pontozasa',
            'group' => 'jatekok',
            'order' => 2,
            'title' => 'Hogyan működik a pontozás a játékokban?',
            'content' => 'A kvízeknél a helyes válaszok aránya számít: minél jobb az eredményed, annál több pontot kapsz. A többi játéktípusnál a hibátlan teljesítés kell a pontért.',
        ),

        /* --- Szavazas, kerdőív, nyeremenyjatek --------------------------- */
        array(
            'slug' => 'huhs-szavazas',
            'group' => 'szavazas-es-nyeremenyjatek',
            'order' => 1,
            'title' => 'Hogyan működik az éves HUHS szavazás?',
            'content' => 'A kategóriáknál az app kiírja, hány jelöltet kell választanod, a teljes szavazólapot pedig egyetlen gombbal küldheted be. Egy készülékről egy évadban csak egyszer lehet szavazni, ezért beküldés előtt nézd át a választásaidat. Bejelentkezve 10 pontot kapsz érte.',
        ),
        array(
            'slug' => 'huhs-szavazas-eredmenyek',
            'group' => 'szavazas-es-nyeremenyjatek',
            'order' => 2,
            'title' => 'Mikor láthatók a szavazás eredményei?',
            'content' => 'A szavazás lezárása után az eredmények nem jelennek meg azonnal. Akkor tesszük közzé őket, amikor minden ellenőrzés lezajlott — onnantól az appban és a weboldalon ugyanazt látod, kategóriánként, szavazatszám szerinti sorrendben.',
        ),
        array(
            'slug' => 'mi-az-a-kerdoiv',
            'group' => 'szavazas-es-nyeremenyjatek',
            'order' => 3,
            'title' => 'Mi az a kérdőív?',
            'content' => 'A kérdőív egy rövid, egykérdéses szavazás a főoldalon — például arról, hogy tetszik-e az app. Egy fiókkal egyszer szavazhatsz, és a szavazatod utólag nem módosítható. Az eredmény nem nyilvános.',
        ),
        array(
            'slug' => 'hogyan-mukodik-a-nyeremenyjatek',
            'group' => 'szavazas-es-nyeremenyjatek',
            'order' => 4,
            'title' => 'Hogyan működik a nyereményjáték?',
            'content' => 'A főoldalon látszik, ha nyitva van egy nyereményjáték. Egy kvízkérdésre kell válaszolnod, és csak a helyes válasz vesz részt a sorsolásban. Egy fiókkal egyszer játszhatsz: ha elrontod, sajnos nem tudod újra megpróbálni — de a következő játéknál ott leszünk.',
        ),
        array(
            'slug' => 'nyeremenyjatek-nyertes',
            'group' => 'szavazas-es-nyeremenyjatek',
            'order' => 5,
            'title' => 'Honnan tudom, hogy nyertem?',
            'content' => 'A játék lezárása után rövid időn belül kisorsoljuk a nyertest egy helyes válaszoló közül, és ezt az appban is látni fogod a nyertes nevével együtt. Ha te nyersz, értesítést és e-mailt is kapsz a részletekkel. A nyertes nevét a játék beállításától függő ideig mutatjuk.',
        ),

        /* --- Segitseg es adatvedelem ------------------------------------- */
        array(
            'slug' => 'hiba-jelzese',
            'group' => 'segitseg-es-adatvedelem',
            'order' => 1,
            'title' => 'Hogyan jelezhetek hibát vagy küldhetek ötletet?',
            'content' => 'A Több menüben a Hibajelzésnél tudsz levelet írni — az app automatikusan csatolja a verziószámot, ami sokat segít. Írd le röviden, mi történt és melyik képernyőn, és ha lehet, csatolj képernyőképet.',
        ),
        array(
            'slug' => 'adatkezeles',
            'group' => 'segitseg-es-adatvedelem',
            'order' => 2,
            'title' => 'Hogyan kezelitek az adataimat?',
            'content' => 'Csak a működéshez szükséges adatokat tároljuk. A profilod nyilvános részét te töltöd ki, a személyes adataidat nem tesszük közzé. A részleteket az Adatkezelési tájékoztatóban olvashatod, és a fiókodat bármikor törölheted.',
        ),
        array(
            'slug' => 'bekuldesek-es-jovahagyas',
            'group' => 'segitseg-es-adatvedelem',
            'order' => 3,
            'title' => 'Beküldtem egy DJ-t vagy eseményt — mi történik vele?',
            'content' => 'A beküldött adatokat átnézzük, ezért nem jelennek meg azonnal. Ha kell, pontosítjuk őket, és külön döntünk a közzétételről. Ez azért van, hogy a katalógusban minden adat ellenőrzött legyen.',
        ),
        array(
            'slug' => 'szerepkor-modositasa',
            'group' => 'segitseg-es-adatvedelem',
            'order' => 4,
            'title' => 'Módosíthatom később a szerepkörömet?',
            'content' => 'Igen. A szerepköröd a profilodhoz tartozik, és a profilbeállításokban módosíthatod. Ha elakadsz, írj a Kapcsolat oldalon.',
        ),
    );
}

/**
 * A REGI bejegyzesek nyugdijazasa.
 *
 * FONTOS, MERVE: a WordPressben **14 bejegyzes `menu_order = 0`-val** maradt bent
 * a korabbi seedekbol, es pont ezek kerulnek a lista ELEJERE, kategoria nelkul,
 * osszevissza — pontosan ez volt a „gagyi" erzes fo oka. Emellett tovabbi 8 regi
 * bejegyzes a „App és közösség" kategoriaban ul, reszben UGYANAZOKRA a kerdésekre,
 * mint az uj lista (peldaul a jutalmazott feloldas vagy a vasarlas
 * visszaallitasa).
 *
 * Ezert a nyugdijazas NEM egy kezzel irt lista, hanem **minden olyan
 * bejegyzes, ami nincs benne az uj listaban** (a kezzel irt kivetelekkel, lasd
 * lent). Igy az eredmeny az uj, 31 bejegyzesbol allo GYIK — determinisztikus es
 * ujrafuttathato.
 *
 * A nyugdijazas **vazlatba** tesz, nem torol: a tulajdonos a WordPress adminban
 * barmikor visszatalal rajuk es ujra kozzetetheti.
 *
 * KIVETEL — es ez fontos: amit a tulajdonos **kezzel irt vagy atirt**
 * (`_huhs_faq_human_edited`), azt NEM tesszuk vazlatba. Az az o szovege; a
 * migracio feladata a gepi szemét eltakaritasa, nem a tulajdonos munkajanak
 * eldobasa. Ezek a bejegyzesek publikaltak maradnak, es a naploba bekerulnek.
 *
 * @return array{retired: string[], kept: string[]} A vazlatba tett, illetve a
 *         kezi szerkesztes miatt szandekosan megtartott bejegyzesek cimei.
 */
function huhs_faq_v4_retire_stale($keep_slugs)
{
    $retired = array();
    $kept = array();
    $existing = get_posts(array(
        'post_type' => 'huhs_faq',
        'post_status' => 'publish',
        'posts_per_page' => 500,
        'fields' => 'ids',
        'no_found_rows' => true,
    ));
    foreach ($existing as $post_id) {
        if (in_array((string) get_post_field('post_name', $post_id), $keep_slugs, true)) continue;
        // A tulajdonos kezzel irt/atirt szoveget nem dobunk el.
        if (get_post_meta((int) $post_id, '_huhs_faq_human_edited', true) === '1') {
            update_post_meta((int) $post_id, '_huhs_faq_kept_by_hand', HUHS_FAQ_CONTENT_VERSION);
            $kept[] = (string) get_the_title($post_id);
            continue;
        }
        // Csak a PUBLIKALT sorokat nyugdijazzuk; egy mar vazlatban levo
        // bejegyzeshez nem nyulunk (lehet, hogy a tulajdonos eppen szerkeszti).
        wp_update_post(array('ID' => (int) $post_id, 'post_status' => 'draft'));
        update_post_meta((int) $post_id, '_huhs_faq_retired_by', HUHS_FAQ_CONTENT_VERSION);
        $retired[] = (string) get_the_title($post_id);
    }
    return array('retired' => $retired, 'kept' => $kept);
}

function huhs_seed_human_faq_once()
{
    if (!current_user_can('manage_options')) {
        return;
    }
    $applied = (int) get_option('huhs_faq_human_version', 0);
    if ($applied >= HUHS_FAQ_CONTENT_VERSION) {
        return;
    }

    // Amig ez a jelzo be van kapcsolva, a `save_post_huhs_faq` marker NEM
    // belyegez semmit „kezi szerkesztesnek": a migracio a sajat irasat ne
    // ertelmezze a tulajdonos munkajakent.
    $GLOBALS['huhs_faq_v4_seeding'] = true;

    $groups = huhs_faq_v4_groups();
    $group_ids = array();
    foreach ($groups as $slug => $group) {
        $term = term_exists($group['name'], 'huhs_faq_category');
        if (!$term || is_wp_error($term)) {
            $term = wp_insert_term($group['name'], 'huhs_faq_category');
        }
        if (is_wp_error($term)) continue;
        $group_ids[$slug] = is_array($term) ? (int) $term['term_id'] : (int) $term;
    }

    $items = huhs_faq_v4_items();
    $keep_slugs = array();
    foreach ($items as $item) {
        if (!isset($group_ids[$item['group']])) continue;
        $keep_slugs[] = $item['slug'];
        $menu_order = $groups[$item['group']]['base'] + (int) $item['order'];

        $existing = get_page_by_path($item['slug'], OBJECT, 'huhs_faq');
        if ($existing) {
            $post_id = (int) $existing->ID;
            // Ha a tulajdonos kezzel atirta a szoveget, NEM irjuk felul — csak a
            // besorolast es a sorrendet igazitjuk.
            $edited = get_post_meta($post_id, '_huhs_faq_human_edited', true) === '1';
            $patch = array('ID' => $post_id, 'menu_order' => $menu_order);
            if (!$edited) {
                $patch['post_title'] = $item['title'];
                $patch['post_content'] = $item['content'];
            }
            if ($existing->post_status !== 'publish') {
                $patch['post_status'] = 'publish';
            }
            wp_update_post($patch);
        } else {
            $post_id = wp_insert_post(array(
                'post_type' => 'huhs_faq',
                'post_status' => 'publish',
                'post_title' => $item['title'],
                'post_name' => $item['slug'],
                'post_content' => $item['content'],
                'menu_order' => $menu_order,
            ), true);
        }
        if (is_wp_error($post_id)) continue;
        wp_set_object_terms((int) $post_id, array($group_ids[$item['group']]), 'huhs_faq_category');
        update_post_meta((int) $post_id, '_huhs_faq_content_version', HUHS_FAQ_CONTENT_VERSION);
    }

    // A fenti lista UTAN nyugdijazzuk a tobbit, hogy a „nincs benne" feltetel
    // pontosan az uj keszlethez viszonyitson.
    $result = huhs_faq_v4_retire_stale($keep_slugs);
    if ($result['retired']) {
        error_log(sprintf(
            'huhs_faq_v4: %d regi GYIK bejegyzes vazlatba teve: %s',
            count($result['retired']),
            implode(' | ', array_slice($result['retired'], 0, 20))
        ));
    }
    if ($result['kept']) {
        error_log(sprintf(
            'huhs_faq_v4: %d bejegyzes MEGMARADT, mert a tulajdonos kezzel irta: %s',
            count($result['kept']),
            implode(' | ', array_slice($result['kept'], 0, 20))
        ));
    }

    unset($GLOBALS['huhs_faq_v4_seeding']);
    update_option('huhs_faq_human_version', HUHS_FAQ_CONTENT_VERSION, false);
}

/**
 * Ha a tulajdonos a WordPress adminban kezzel ir vagy atir egy GYIK bejegyzest,
 * megjeloljuk — igy (1) a kovetkezo migracio nem irja felul a sajat
 * megfogalmazasat, es (2) a nyugdijazas nem teszi vazlatba az o szoveget.
 *
 * FONTOS: `save_post_huhs_faq` az UJ bejegyzesre is lefut (a `post_updated`
 * NEM, mert az csak modositasnal indul), ezert a kezzel LETREHOZOTT GYIK is
 * vedelmet kap — korabban ez a res vedtelen volt.
 */
add_action('save_post_huhs_faq', function ($post_id, $post, $update) {
    if (!empty($GLOBALS['huhs_faq_v4_seeding'])) return;
    if (!$post instanceof WP_Post || $post->post_type !== 'huhs_faq') return;
    if (wp_is_post_revision($post_id) || wp_is_post_autosave($post_id)) return;
    if (!current_user_can('manage_options')) return;
    update_post_meta((int) $post_id, '_huhs_faq_human_edited', '1');
}, 10, 3);
