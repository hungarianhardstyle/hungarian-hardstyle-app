import 'package:flutter/widgets.dart';

/// Az app nyelvei. A **magyar az alapértelmezett**, az angol opt-in.
///
/// A döntés (tulajdonos, 2026-09-25): a felület nyelve választható, a magyar
/// marad a fallback, és a **felhasználói tartalom** (chat, hozzászólás, nevek)
/// soha nem fordítódik.
enum AppLanguage { hu, en }

/// A mentett nyelvválasztás kulcsa a `SharedPreferences`-ben.
const String appLanguageStorageKey = 'app_language';

const Map<AppLanguage, String> _languageCodes = {
  AppLanguage.hu: 'hu',
  AppLanguage.en: 'en',
};

/// Mentett/kapott kódból nyelv. **Minden ismeretlen és hiányzó érték magyar**,
/// hogy egy régi vagy hibás mentés ne hagyja üresen a felületet.
AppLanguage appLanguageFromCode(String? code) {
  final normalized = (code ?? '').trim().toLowerCase();
  if (normalized == 'en' || normalized.startsWith('en_') || normalized.startsWith('en-')) {
    return AppLanguage.en;
  }
  return AppLanguage.hu;
}

/// A másik nyelv — a kapcsoló mindig erre vált.
AppLanguage otherLanguage(AppLanguage language) =>
    language == AppLanguage.en ? AppLanguage.hu : AppLanguage.en;

String appLanguageCode(AppLanguage language) => _languageCodes[language] ?? 'hu';

Locale appLanguageLocale(AppLanguage language) => language == AppLanguage.en
    ? const Locale('en', 'US')
    : const Locale('hu', 'HU');

/// A kapcsoló felirata: mindig a **másik** nyelv kódja (HU-nál „EN", EN-nél „HU").
String appLanguageSwitchLabel(AppLanguage language) =>
    appLanguageCode(otherLanguage(language)).toUpperCase();

/// A nyelv neve a saját nyelvén (beállítás-listához, feliratnak).
String appLanguageName(AppLanguage language) =>
    language == AppLanguage.en ? 'English' : 'Magyar';
