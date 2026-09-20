import 'package:firebase_core/firebase_core.dart';

import '../core/firebase/firebase_callable.dart';
import '../models/label_library.dart';
import 'label_purchase_service.dart';

/// A szerveroldali könyvtár-lekérdezés típusa (a teszt így tud Firebase nélkül
/// mérni — ugyanaz a minta, mint az `AchievementService.catalogCaller`-nél).
typedef LabelLibraryCaller = Future<Map<String, dynamic>> Function();

/// A letöltési hivatkozás kérése (a valódi útvonal a `LabelPurchaseService`,
/// amely a **jogosultságot a szerveren** ellenőrzi — a kliens nem dönthet róla).
typedef LabelDownloadUrlCaller =
    Future<String> Function(int releaseId, String variant);

/// A „Saját zenéim" könyvtár betöltése.
///
/// A szerver (`getMyLabelLibrary`) a **saját** vásárlásokat és reklám-feloldásokat
/// adja vissza; itt csak beolvassuk és megtisztítjuk. Három szándékos szabály:
///
///  1. **Firebase nélkül nem dob**, hanem üres listát ad — a widget-tesztek
///     (és egy Firebase nélkül induló build) ne omoljanak el ezen.
///  2. **A hibás elemeket kihagyjuk**, nem tippelünk: ha egy sorban nincs
///     értelmezhető kiadvány-azonosító, az nem kerül a könyvtárba.
///  3. **A hiba nem lesz üres könyvtár**: ha a hálózat/szerver hibázik, a hiba
///     **továbbmegy** a felületnek, hogy meg tudja különböztetni a „nincs
///     zenéd" és a „most nem érhető el" állapotot. Ez fontos: a felhasználó
///     különben azt hinné, elvesztek a vásárlásai.
class LabelLibraryService {
  LabelLibraryService({
    LabelLibraryCaller? caller,
    LabelDownloadUrlCaller? downloadUrlCaller,
  }) : // A privát mezőhöz nem lehet `this._x` nevű NÉVES paramétert adni, ezért
       // szándékos a kézi hozzárendelés (ugyanaz a minta, mint a letöltés-kezelőnél).
       // ignore: prefer_initializing_formals
       _caller = caller,
       // ignore: prefer_initializing_formals
       _downloadUrlCaller = downloadUrlCaller;

  final LabelLibraryCaller? _caller;
  final LabelDownloadUrlCaller? _downloadUrlCaller;

  /// Aláírt letöltési hivatkozás egy **birtokolt** változathoz.
  ///
  /// A jogosultságot a szerver ellenőrzi (`getLabelDownloadUrl`), ezért ez a
  /// hívás más fiók zenéjéhez **nem** ad linket — a „ne tudja letölteni" rész
  /// itt is szerveroldalon dől el, nem a felületen.
  Future<String> downloadUrl({
    required int releaseId,
    required String variant,
  }) {
    final custom = _downloadUrlCaller;
    if (custom != null) return custom(releaseId, variant);
    return LabelPurchaseService.shared.getDownloadUrl(
      releaseId: releaseId,
      variant: variant,
    );
  }

  Future<List<LabelLibraryItem>> load() async {
    if (_caller == null && Firebase.apps.isEmpty) return const [];
    final caller =
        _caller ??
        () => callFirebaseCallable<Map<String, dynamic>>('getMyLabelLibrary')
            .then((result) => result.data);
    final data = await caller();
    final rawItems = data['items'];
    if (rawItems is! List) return const [];
    final items = <LabelLibraryItem>[];
    for (final raw in rawItems) {
      if (raw is! Map) continue;
      final item = LabelLibraryItem.fromJson(
        raw.map((key, value) => MapEntry('$key', value)),
      );
      if (item.releaseId < 1) continue;
      if (item.variants.isEmpty) continue;
      items.add(item);
    }
    return items;
  }
}
