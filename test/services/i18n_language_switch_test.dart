import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/core/i18n/app_language.dart';
import 'package:hungarian_hardstyle_app/core/i18n/app_strings.dart';
import 'package:hungarian_hardstyle_app/providers/content_language_provider.dart';
import 'package:hungarian_hardstyle_app/providers/language_provider.dart';
import 'package:hungarian_hardstyle_app/services/wordpress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A NYELVÁLTÁS azonnali hatása + a kiadvány-címkék fordítása.
///
/// **A tulajdonos jelzései (2026-09-26, Android + iPhone):**
///  1. *„ami iphoneon angol, az androidon magyar maradt"*, majd *„esemény, stb"*,
///     végül *„de más is"* — kiderült: a telefon 365-öt futtat, a **nyelv** viszont
///     **készülékenként** tárolódik, ezért ott még magyar volt (ez nem hiba);
///  2. *„lassan álltak át a dolgok angolra"* → **valódi hiba**: a tartalom a
///     kérés `lang` paraméterével jön, a **feldolgozott** listák viszont
///     nyelvfüggetlen gyorsítótárban élnek, ezért váltás után a régi nyelvű szöveg
///     a képernyőn maradt (lehúzásig / a következő újratöltésig);
///  3. *„itt is maradt magyar"* (képernyőkép a Label fülről, `Megjelenés: 2026-09…`)
///     és *„pl a djk-nél a Megjelenései"* → **nyers, interpolált címkék**, amelyeket
///     sem az extraktor nem látott, sem a fordító nem érintett.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final dictionary = jsonDecode(
    File('assets/i18n/en.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppStrings.setLanguage(AppLanguage.hu);
    AppStrings.setEnglish(null);
  });

  group('a kiadvány-címkék angolul is megjelennek', () {
    test('a szótárban valódi fordítás van (nem üres, nem a kulcs)', () {
      for (final key in [
        'Megjelenés: {d}',
        'Hamarosan · Megjelenés: {d}',
        'Megjelenés: {d}. Ekkor válik megvásárolhatóvá és letölthetővé. Addig a 60 másodperces előzetes hallgatható.',
        'Megjelenése',
        'Megjelenései',
        'Összes megjelenése ({n})',
      ]) {
        final value = dictionary[key];
        expect(value, isA<String>(), reason: 'hiányzik a(z) „$key" kulcs');
        expect(
          (value as String).trim(),
          isNotEmpty,
          reason: 'a(z) „$key" fordítása üres',
        );
        expect(value, isNot(key), reason: 'a(z) „$key" nincs lefordítva');
      }
    });

    test('angol módban a dátum-címke angolul, magyar módban változatlan', () {
      final english = dictionary.map((key, value) => MapEntry(key, '$value'));
      AppStrings.setEnglish(english);

      AppStrings.setLanguage(AppLanguage.en);
      expect(
        AppStrings.trArgs('Megjelenés: {d}', {'d': '2026-09-26'}),
        'Release: 2026-09-26',
      );
      expect(AppStrings.tr('Megjelenései'), 'Appearances');
      expect(AppStrings.tr('Megjelenése'), 'Appearance');
      expect(
        AppStrings.trArgs('Hamarosan · Megjelenés: {d}', {'d': '2026-10-01'}),
        'Coming soon · Release: 2026-10-01',
      );

      AppStrings.setLanguage(AppLanguage.hu);
      expect(
        AppStrings.trArgs('Megjelenés: {d}', {'d': '2026-09-26'}),
        'Megjelenés: 2026-09-26',
      );
      expect(AppStrings.tr('Megjelenései'), 'Megjelenései');
    });

    test('FORRÁS-LINT: a címkék a fordítón mennek át (nincs nyers interpoláció)', () {
      final card = File('lib/widgets/release_card.dart').readAsStringSync();
      final detail = File(
        'lib/screens/releases/release_detail_screen.dart',
      ).readAsStringSync();
      final section = File(
        'lib/widgets/artist_releases_section.dart',
      ).readAsStringSync();

      expect(
        card.contains(r"'Megjelenés: ${release.releaseDate}'"),
        isFalse,
        reason: 'a kártyán nincs nyers interpolált címke',
      );
      expect(card.contains("trArgs(context, 'Megjelenés: {d}'"), isTrue);
      expect(
        detail.contains(r"'Megjelenés: ${release.releaseDate}'"),
        isFalse,
      );
      expect(detail.contains("trArgs(context, 'Megjelenés: {d}'"), isTrue);
      expect(
        section.contains('tr(context, artistReleasesLabel('),
        isTrue,
        reason: 'a DJ-adatlap „Megjelenései" címe a fordítón megy át',
      );
    });
  });

  group('nyelvváltáskor a TARTALOM azonnal átvált', () {
    test('a váltás EGYSZER jelez, és előtte eldobja a feldolgozott listákat', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // A gyökér így tartja életben a figyelést (main.dart).
      container.read(contentLanguageSyncProvider);
      final before = WordpressService.publicContentRefreshGeneration.value;

      container.read(languageProvider.notifier).select(AppLanguage.en);

      // A jelzés pontosan EGYSZER megy ki (a dupla jelzés kétszeres
      // újratöltést indítana)…
      expect(
        WordpressService.publicContentRefreshGeneration.value,
        before + 1,
        reason: 'egy váltás = egy jelzés',
      );

      // …és a feldolgozott listák eldobása NEM jelzés (különben kettő lenne).
      WordpressService().onContentLanguageChanged();
      expect(
        WordpressService.publicContentRefreshGeneration.value,
        before + 1,
        reason: 'a gyorsítótár-eldobás önmagában nem jelzés',
      );
    });

    test('FORRÁS-LINT: a jelzés előtt a feldolgozott listák is eldobódnak', () {
      final source = File(
        'lib/providers/content_language_provider.dart',
      ).readAsStringSync();
      final listener = source.substring(
        source.indexOf('ref.listen<AppLanguage>'),
      );
      expect(
        listener.contains('onContentLanguageChanged()'),
        isTrue,
        reason:
            'a jelzés előtt el kell dobni a nyelvfüggetlen feldolgozott '
            'listákat, különben a váltás csak a cache lejárta után látszik',
      );
      expect(
        listener.indexOf('onContentLanguageChanged()'),
        lessThan(listener.indexOf('publicContentRefreshGeneration.value++')),
        reason: 'a lista-eldobás a jelzés ELŐTT történik',
      );

      // A szolgáltatás oldalán a nyelvfüggetlen listák szerepelnek a metódusban.
      final service = File(
        'lib/services/wordpress_service.dart',
      ).readAsStringSync();
      final method = service.substring(
        service.indexOf('void onContentLanguageChanged()'),
      );
      for (final cache in [
        '_postsCache.clear()',
        '_eventsCache.clear()',
        '_artistsCache.clear()',
        '_organizersCache.clear()',
        '_releasesCache.clear()',
        '_faqCache.clear()',
      ]) {
        expect(method.contains(cache), isTrue, reason: 'hiányzik: $cache');
      }
      expect(
        method.contains('publicContentRefreshGeneration.value++'),
        isFalse,
        reason: 'a jelzést a provider adja (ne duplázódjon)',
      );
    });
  });
}
