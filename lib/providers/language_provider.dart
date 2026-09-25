import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/i18n/app_language.dart';
import '../core/i18n/app_strings.dart';

/// A szótár betöltése az assetből.
///
/// Hiba esetén **nem dob**: a szótár hiánya csak azt jelenti, hogy minden
/// felirat magyar marad (ez a kívánt fallback).
Future<void> preloadEnglishDictionary() async {
  try {
    final jsonText = await rootBundle.loadString(AppStrings.dictionaryAsset);
    AppStrings.setEnglish(AppStrings.decodeDictionary(jsonText));
  } catch (_) {
    AppStrings.setEnglish(null);
  }
}

/// A mentett nyelvválasztás + a szótár betöltése a `runApp` előtt.
///
/// Azért indul a `runApp` előtt, hogy az első képkocka már a választott nyelven
/// rajzolódjon (ne villanjon be egy magyar felirat angol módban).
Future<void> preloadAppLanguage({SharedPreferences? preferences}) async {
  AppLanguage language = AppLanguage.hu;
  try {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    language = appLanguageFromCode(prefs.getString(appLanguageStorageKey));
  } catch (_) {
    language = AppLanguage.hu;
  }
  AppStrings.setLanguage(language);
  await preloadEnglishDictionary();
}

/// A nyelv állapota: a felület ezt figyeli, és a választás **mentődik**.
class LanguageController extends Notifier<AppLanguage> {
  @override
  AppLanguage build() => AppStrings.language;

  /// Nyelv váltása + mentés. A mentés hibája nem akadályozhatja a váltást.
  Future<void> select(AppLanguage language) async {
    AppStrings.setLanguage(language);
    if (language != state) state = language;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(appLanguageStorageKey, appLanguageCode(language));
    } catch (_) {
      // A választás ebben a munkamenetben így is érvényes.
    }
  }

  Future<void> toggle() => select(otherLanguage(state));
}

final languageProvider =
    NotifierProvider<LanguageController, AppLanguage>(LanguageController.new);
