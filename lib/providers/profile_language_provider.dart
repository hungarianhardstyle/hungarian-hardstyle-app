import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'community_provider.dart';
import 'language_provider.dart';

/// A választott felületi nyelv **tárolása a profilban**.
///
/// MIÉRT KELL: az értesítéseket a **szerver** írja (Firebase Functions) és a
/// push üzenetet is ő küldi, ezért a szervernek tudnia kell, melyik nyelven
/// szóljon. A címzett nyelve a `community_profiles/{uid}.language` mezőből
/// dől el (`functions/notification-texts.js`, alapérték: magyar).
///
/// KÉT ESEMÉNYRE írunk:
///  1. **nyelvváltáskor** (`languageProvider`), és
///  2. **bejelentkezéskor / induláskor** — hogy egy régi fiók (amelyben még
///     nincs `language` mező) is megkapja a jelenlegi választást anélkül, hogy a
///     felhasználónak újra kellene váltania.
///
/// ⚠️ Best-effort: a hálózat/hatókör hiba **nem** dob és nem blokkol (a nyelv a
/// készüléken így is átvált), ezért a felület nem tud elakadni egy mentésen.
final profileLanguageSyncProvider = Provider<void>((ref) {
  final uid = ref.watch(currentUidProvider);
  final language = ref.watch(languageProvider);
  if (uid == null || uid.isEmpty) return;
  // A hívást szándékosan nem várjuk meg (tűz-és-felejts): a felület azonnal
  // váltson nyelvet, a mentés a háttérben történik.
  ref.read(communityServiceProvider).saveProfileLanguage(uid, language);
});
