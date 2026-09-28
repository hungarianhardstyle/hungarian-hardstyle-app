/// A push-kérés **nyelvi mezője** — tiszta, hálózat nélkül tesztelhető kód.
///
/// MIÉRT KELL (mért hiány, 2026-09-28): a WordPress-plugin **2.14.6**-tól a
/// `/push/register` és a `/push/preferences` végpont fogadja a `language` mezőt
/// (`hu`/`en`), és ez dönti el, hogy az **esemény-emlékeztető** melyik nyelven
/// megy ki. Enélkül a token-rekordban nincs nyelv, ezért **mindenki magyar**
/// emlékeztetőt kap — az angol felületű tag is.
///
/// A szerver a **hiányzó és ismeretlen** értéket magyarra normalizálja, ezért a
/// régi kliensek viselkedése változatlan; ez a modul ugyanezt a szabályt
/// képviseli a kliens oldalon, hogy a két hely ne mondhasson mást.
library;

import 'package:shared_preferences/shared_preferences.dart';

import '../core/i18n/app_language.dart';
import '../core/i18n/app_strings.dart';

/// A kérés mezőjének neve (a plugin `huhs_push_normalize_language()`-ével egyezik).
const String pushLanguageField = 'language';

/// Bármilyen mentett/kapott nyelvkódból a **küldhető** alak (`hu` vagy `en`).
///
/// A `SharedPreferences`-ben bármi állhat (régi build, kézi szerkesztés, `null`),
/// ezért a döntés a meglévő [appLanguageFromCode]-ra épül: **minden ismeretlen és
/// hiányzó érték magyar**. Ez pontosan a szerver fallbackje, tehát a kliens nem
/// tud olyat küldeni, amit a szerver másképp értelmezne.
String pushLanguageCode(String? storedCode) =>
    appLanguageCode(appLanguageFromCode(storedCode));

/// Az **aktuális felületi nyelv** push-kódja.
///
/// Elsődlegesen a mentett választás (`SharedPreferences` kulcs:
/// [appLanguageStorageKey]) számít, mert az a `runApp` előtt betöltődik és a
/// nyelvváltó is oda ír; ha a tároló nem érhető el (pl. korai hívás vagy
/// tesztkörnyezet), a memóriabeli [AppStrings.language] a tartalék. Így a
/// függvény **soha nem dob**, és sosem ad üres értéket.
Future<String> resolvePushLanguage({SharedPreferences? preferences}) async {
  try {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    return pushLanguageCode(prefs.getString(appLanguageStorageKey));
  } catch (_) {
    return appLanguageCode(AppStrings.language);
  }
}
