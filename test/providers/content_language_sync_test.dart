import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungarian_hardstyle_app/core/i18n/app_language.dart';
import 'package:hungarian_hardstyle_app/core/i18n/app_strings.dart';
import 'package:hungarian_hardstyle_app/providers/content_language_provider.dart';
import 'package:hungarian_hardstyle_app/providers/language_provider.dart';
import 'package:hungarian_hardstyle_app/services/wordpress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Nyelvváltáskor a **betöltött tartalom is érvénytelenné válik**.
///
/// **MIÉRT KELL:** a tartalom nyelvfüggő (kérés `lang` paramétere + nyelvi
/// cache-kulcs), a Riverpod-provide­rek viszont memóriában tartják a listát.
/// Enélkül a feliratok átváltanának angolra, a **hírek/események viszont
/// magyarul maradnának** a következő újratöltésig.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppStrings.setLanguage(AppLanguage.hu);
    AppStrings.setEnglish(null);
  });

  tearDown(() {
    AppStrings.setLanguage(AppLanguage.hu);
    AppStrings.setEnglish(null);
  });

  test('nyelvváltás felhúzza a tartalom-frissítés jelzőjét', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // A gyökér így tartja életben a figyelést.
    container.read(contentLanguageSyncProvider);
    final before = WordpressService.publicContentRefreshGeneration.value;

    await container.read(languageProvider.notifier).select(AppLanguage.en);
    expect(
      WordpressService.publicContentRefreshGeneration.value,
      before + 1,
      reason: 'a tartalom-provide­rek ezt a jelzést figyelik',
    );

    await container.read(languageProvider.notifier).select(AppLanguage.hu);
    expect(WordpressService.publicContentRefreshGeneration.value, before + 2);
  });

  test('ugyanarra a nyelvre váltás nem frissít fölöslegesen', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(contentLanguageSyncProvider);
    final before = WordpressService.publicContentRefreshGeneration.value;

    await container.read(languageProvider.notifier).select(AppLanguage.hu);
    expect(WordpressService.publicContentRefreshGeneration.value, before);
  });

  test('a váltás a nyelvi állapotot is átállítja (a kérés ezt használja)', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(contentLanguageSyncProvider);

    await container.read(languageProvider.notifier).select(AppLanguage.en);
    expect(container.read(languageProvider), AppLanguage.en);
    expect(AppStrings.language, AppLanguage.en);
  });
}
