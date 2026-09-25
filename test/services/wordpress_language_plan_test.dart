import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/core/i18n/app_language.dart';
import 'package:hungarian_hardstyle_app/services/wordpress_language_plan.dart';

/// A WordPress-tartalom nyelvi szabálya.
///
/// **MÉRT INDOK:** a plugin a `lang` paramétert ismeretlenként hagyja figyelmen
/// kívül, ha az adott végpont még nem tud angolul (a 2.10.0 plugin a
/// `/posts?lang=en` kérésre `200`-at adott magyar tartalommal) — ezért a `lang`
/// **minden** kérésre mehet, és a plugin 2.12.0 app-frissítés nélkül érvényesül.
void main() {
  group('wordpressContentQuery', () {
    test('magyar nyelvnél lang=hu kerül a kérésbe', () {
      final query = wordpressContentQuery(language: AppLanguage.hu);
      expect(query[wordpressLanguageParameter], 'hu');
      expect(query.length, 1);
    });

    test('angol nyelvnél lang=en kerül a kérésbe', () {
      final query = wordpressContentQuery(language: AppLanguage.en);
      expect(query[wordpressLanguageParameter], 'en');
    });

    test('a hívó paraméterei megmaradnak (és stringgé válnak)', () {
      final query = wordpressContentQuery(
        queryParameters: {'per_page': 10, 'page': 2, 'search': 'rebirth'},
        language: AppLanguage.en,
      );
      expect(query['per_page'], '10');
      expect(query['page'], '2');
      expect(query['search'], 'rebirth');
      expect(query[wordpressLanguageParameter], 'en');
    });

    test('a hívó szándékos lang-ja NYER (nem írjuk felül)', () {
      final query = wordpressContentQuery(
        queryParameters: {wordpressLanguageParameter: 'de'},
        language: AppLanguage.en,
      );
      expect(query[wordpressLanguageParameter], 'de');
    });

    test('üres paramétereknél csak a nyelv marad', () {
      expect(wordpressContentQuery(language: AppLanguage.en).keys.toList(), ['lang']);
      expect(wordpressContentQuery(queryParameters: {}, language: AppLanguage.hu).length, 1);
    });
  });

  group('wordpressCacheContext', () {
    test('a cache nyelvi összetevője a nyelv kódja', () {
      expect(wordpressCacheContext(AppLanguage.hu), 'hu');
      expect(wordpressCacheContext(AppLanguage.en), 'en');
    });

    test('a két nyelv cache-kulcsa KÜLÖNBÖZIK (nem keveredhet)', () {
      expect(
        wordpressCacheContext(AppLanguage.hu) == wordpressCacheContext(AppLanguage.en),
        isFalse,
        reason: 'ha egyezne, a nyelvváltás a mentett, más nyelvű választ adná',
      );
    });
  });
}
