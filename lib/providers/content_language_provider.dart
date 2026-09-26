import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n/app_language.dart';
import '../services/wordpress_service.dart';
import 'language_provider.dart';

/// Nyelvváltáskor **érvényteleníti a betöltött tartalmat**.
///
/// MIÉRT KELL: a WordPress-tartalom nyelvfüggő — a kérés `lang` paramétere és a
/// mentett ETag-es cache nyelvi kulcsa is a választott nyelvet használja
/// (`wordpress_language_plan.dart`). A Riverpod-provide­rek viszont a
/// **memóriában** is megtartják a listát, ezért a nyelvváltás önmagában a régi
/// (más nyelvű) listát mutatná mindaddig, amíg valami újra nem tölti.
///
/// A meglévő `WordpressService.publicContentRefreshGeneration` jelző felhúzása
/// pontosan ezt teszi: a hírek, események, DJ-k, szervezők, kiadványok, játékok,
/// szavazás, kérdőív, nyereményjáték és a GYIK providere **mind** ezt figyeli,
/// ezért egyetlen jelzés az egész tartalmat az új nyelven tölti újra.
///
/// A gyökérben egyszer `ref.watch`-oljuk (`HungarianHardstyleApp`), így a
/// figyelés az app teljes élettartamára él.
///
/// ⚠️ **A MÁSODIK LÉPÉS IS KELL (mért hiba, 2026-09-26):** a jelzés önmagában
/// nem volt elég — a tulajdonos azt jelezte, hogy *„nyelvváltáskor lassan áll át
/// az adott nyelvre"*. A jelzés ugyanis a providereket építi újra, azok viszont a
/// szolgáltatás **feldolgozott** (nyelvfüggetlen kulcsú) gyorsítótárából
/// olvastak, amely 30 s / 45 s / 2–5 percig él — ezért a váltás csak a cache
/// lejárta után látszott. Ezért a jelzés **előtt** eldobjuk ezeket a listákat
/// (`onContentLanguageChanged()`), így az újratöltés tényleg az új nyelven megy.
final contentLanguageSyncProvider = Provider<void>((ref) {
  ref.listen<AppLanguage>(languageProvider, (previous, next) {
    if (previous == next) return;
    WordpressService().onContentLanguageChanged();
    WordpressService.publicContentRefreshGeneration.value++;
  });
});
