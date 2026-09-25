import '../core/i18n/app_language.dart';

/// A WordPress-tartalom kérésének **nyelvi** szabálya.
///
/// MIÉRT KÜLÖN TISZTA MODUL: a `wordpress_service.dart` hálózatot és cache-t is
/// használ, ezért a nyelvi döntés (mi kerül a kérésbe, és mi a cache-kulcs
/// nyelvi összetevője) itt mérhető, hálózat nélkül.
///
/// A plugin a `lang` paramétert **ismeretlenként hagyja figyelmen kívül**, ha az
/// adott végpont még nem tud angolul (ezt mérve: a 2.10.0 plugin a
/// `/posts?lang=en` kérésre `200`-at adott magyar tartalommal, hiba nélkül) —
/// ezért a `lang` **minden** kérésre mehet: amelyik végpont tudja, fordítva
/// válaszol, a többi a magyart adja. Így a plugin 2.12.0 (esemény/DJ/szervező/
/// kiadvány angol mezői) **app-frissítés nélkül** érvényesül.
const String wordpressLanguageParameter = 'lang';

/// A kérés query-paraméterei: a hívó paraméterei + a **nyelv**.
///
/// Ha a hívó kifejezetten megadott `lang`-ot, az nyer (így egy kézi, más nyelvű
/// kérés nem törhető el).
Map<String, String> wordpressContentQuery({
  Map<String, dynamic>? queryParameters,
  required AppLanguage language,
}) {
  final result = <String, String>{
    for (final entry in (queryParameters ?? const <String, dynamic>{}).entries)
      entry.key: '${entry.value}',
  };
  result.putIfAbsent(wordpressLanguageParameter, () => appLanguageCode(language));
  return result;
}

/// A mentett (ETag-es) válasz **cache-kulcsának nyelvi összetevője**.
///
/// ⚠️ Ez azért kell, mert a cache a nyers választ tárolja: ha a kulcs nem
/// tartalmazná a nyelvet, a magyarul mentett cikk **angol módban is magyarul**
/// jönne vissza (és fordítva) — a nyelvváltás pedig a mentett, más nyelvű
/// választól „nem látszana".
String wordpressCacheContext(AppLanguage language) => appLanguageCode(language);
