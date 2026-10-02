<?php

if (!defined('ABSPATH')) {
    exit;
}

/*
|--------------------------------------------------------------------------
| Ország- és helységnevek angolul — plugin 2.13.0
|--------------------------------------------------------------------------
|
| MIÉRT KELL (mérve, 2026-09-25): az app `lang=en` kérése eddig a fordítási
| metákat adta vissza (cím, törzs, kivonat), a **meta-mezők** viszont
| változatlanul magyarul mentek ki. A mérés szerint angol módban ez volt a
| legláthatóbb magyar szöveg a DJ-/szervező-/esemény-adatlapon:
|
|   country / venue_country = "Magyarország"   (17 DJ, 4 szervező, minden esemény)
|   city  = "Bécs"
|
| Ezek **nem prózai szövegek**, hanem nevek, ezért nem a fordítási folyamat
| (AI) dolgozik rajtuk: egy **determinisztikus névtár** fordítja őket. Ez
| előny: nincs API-hívás, nincs késleltetés, és a válasz mindig ugyanaz.
|
| ⚠️ AMIT SZÁNDÉKOSAN NEM FORDÍTUNK:
|  * a **helyszín neve** (`venue_name`) tulajdonnév ("Stenk", "SPOTx Club",
|    "Surfcamping - Gárdony") — nem szabad fordítani;
|  * az ismeretlen ország/helység érték **változatlanul** megy ki (nincs
|    tippelés): a névtár csak a biztos neveket tartalmazza;
|  * a magyar ág (`lang=hu`) **bájtazonos** marad a 2.12.0-éval (a függvény a
|    nem-angol kérésre az eredeti értéket adja vissza, átalakítás nélkül).
|
| ⚠️ A "Velence" CSAPDA (ezért nincs a helység-névtárban): a Velence olasz
| város angolul Venice, DE a magyar Velence (a Velencei-tó melletti város,
| ahol a Hard Lake események vannak) ugyanígy "Velence" — egy vak névtár a
| magyar esemény helyszínét fordítaná félre. Ezért a helység-lista csak
| **egyértelmű** magyar exonimákat tartalmaz.
*/

/**
 * Magyar országnév → angol név.
 *
 * A kulcs **kisbetűs, ékezet-megtartó** alak (a `huhs_translation_place_key()`
 * így normalizál); az érték a bevett angol név.
 */
function huhs_translation_country_names()
{
    return array(
        'magyarország' => 'Hungary',
        'ausztria' => 'Austria',
        'németország' => 'Germany',
        'hollandia' => 'Netherlands',
        'belgium' => 'Belgium',
        'franciaország' => 'France',
        'olaszország' => 'Italy',
        'spanyolország' => 'Spain',
        'portugália' => 'Portugal',
        'egyesült királyság' => 'United Kingdom',
        'nagy-britannia' => 'United Kingdom',
        'írország' => 'Ireland',
        'svájc' => 'Switzerland',
        'ausztrália' => 'Australia',
        'lengyelország' => 'Poland',
        'csehország' => 'Czechia',
        'szlovákia' => 'Slovakia',
        'szlovénia' => 'Slovenia',
        'horvátország' => 'Croatia',
        'szerbia' => 'Serbia',
        'románia' => 'Romania',
        'bulgária' => 'Bulgaria',
        'görögország' => 'Greece',
        'törökország' => 'Turkey',
        'svédország' => 'Sweden',
        'norvégia' => 'Norway',
        'dánia' => 'Denmark',
        'finnország' => 'Finland',
        'izland' => 'Iceland',
        'észtország' => 'Estonia',
        'lettország' => 'Latvia',
        'litvánia' => 'Lithuania',
        'oroszország' => 'Russia',
        'ukrajna' => 'Ukraine',
        'luxemburg' => 'Luxembourg',
        'málta' => 'Malta',
        'ciprus' => 'Cyprus',
        'egyesült államok' => 'United States',
        'amerikai egyesült államok' => 'United States',
        'usa' => 'United States',
        'kanada' => 'Canada',
        'mexikó' => 'Mexico',
        'brazília' => 'Brazil',
        'argentína' => 'Argentina',
        'új-zéland' => 'New Zealand',
        'japán' => 'Japan',
        'dél-korea' => 'South Korea',
        'kína' => 'China',
        'thaiföld' => 'Thailand',
        'indonézia' => 'Indonesia',
        'india' => 'India',
        'izrael' => 'Israel',
        'egyiptom' => 'Egypt',
        'marokkó' => 'Morocco',
        'tunézia' => 'Tunisia',
        'dél-afrikai köztársaság' => 'South Africa',
        'szingapúr' => 'Singapore',
        'malajzia' => 'Malaysia',
        'egyesült arab emírségek' => 'United Arab Emirates',
        'szaúd-arábia' => 'Saudi Arabia',
        'katar' => 'Qatar',
    );
}

/**
 * Magyar helységnév → angol név — **csak egyértelmű exonimák**.
 *
 * A lista szándékosan rövid: ami kétértelmű lehet (lásd a "Velence" csapdát a
 * fájl fejlécében), az **nincs** benne, mert ott a félrefordítás rosszabb, mint
 * a magyar név meghagyása.
 */
function huhs_translation_city_names()
{
    return array(
        'bécs' => 'Vienna',
        'prága' => 'Prague',
        'varsó' => 'Warsaw',
        'krakkó' => 'Krakow',
        'koppenhága' => 'Copenhagen',
        'brüsszel' => 'Brussels',
        'antwerpen' => 'Antwerp',
        'róma' => 'Rome',
        'nápoly' => 'Naples',
        'milánó' => 'Milan',
        'lisszabon' => 'Lisbon',
        'kijev' => 'Kyiv',
        'moszkva' => 'Moscow',
        'szentpétervár' => 'Saint Petersburg',
        'bukarest' => 'Bucharest',
        'belgrád' => 'Belgrade',
        'zágráb' => 'Zagreb',
        'pozsony' => 'Bratislava',
        'kassa' => 'Košice',
        'kolozsvár' => 'Cluj-Napoca',
        'újvidék' => 'Novi Sad',
        'athén' => 'Athens',
        'isztambul' => 'Istanbul',
        'köln' => 'Cologne',
        'münchen' => 'Munich',
        'bázel' => 'Basel',
        'genf' => 'Geneva',
        'hága' => 'The Hague',
    );
}

/**
 * A névtár kulcsa: kisbetűs, ékezet-megtartó, összevont whitespace.
 *
 * ⚠️ Az ékezetet **megtartjuk** (nem `sanitize_title`-szerűen dobjuk el): a
 * "Bécs" és a "Becs" így nem keveredik, és a névtár kulcsai olvashatók maradnak.
 */
function huhs_translation_place_key($value)
{
    $raw = trim((string) $value);
    $raw = preg_replace('/\s+/u', ' ', $raw);
    if (function_exists('mb_strtolower')) {
        return mb_strtolower($raw, 'UTF-8');
    }
    return strtolower($raw);
}

/**
 * Az ország angol neve a kért nyelven.
 *
 * Nem-angol kérésre az **eredeti értéket** adja vissza (a magyar ág így
 * bájtazonos marad), és ismeretlen névre sem tippel: ilyenkor szintén az
 * eredeti érték megy ki.
 */
function huhs_translation_country_value($value, $lang)
{
    if ($lang !== 'en') {
        return $value;
    }

    $key = huhs_translation_place_key($value);
    if ($key === '') {
        return $value;
    }

    $names = huhs_translation_country_names();

    return isset($names[$key]) ? $names[$key] : $value;
}

/** A helységnév angol neve — ugyanazzal a szabállyal, mint az országnál. */
function huhs_translation_city_value($value, $lang)
{
    if ($lang !== 'en') {
        return $value;
    }

    $key = huhs_translation_place_key($value);
    if ($key === '') {
        return $value;
    }

    $names = huhs_translation_city_names();

    return isset($names[$key]) ? $names[$key] : $value;
}
