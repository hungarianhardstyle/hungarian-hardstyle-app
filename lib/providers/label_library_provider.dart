import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/label_library.dart';
import '../services/label_download_manager.dart';
import '../services/label_library_service.dart';
import 'community_provider.dart';

/// A könyvtár-lekérdezés szolgáltatása (tesztben felülírható).
final labelLibraryServiceProvider = Provider<LabelLibraryService>(
  (ref) => LabelLibraryService(),
);

/// A **bejelentkezett fiók** zenéi.
///
/// A lista a szerverről jön, a hitelesített UID-del szűrve — a kliens nem tud
/// más fiók zenéihez hozzáférni. Azért `watch`-olja a [currentUidProvider]-t,
/// hogy **fiókváltásnál automatikusan újratöltődjön**: eszébe se jusson a
/// korábbi fiók listáját mutatni.
///
/// **`keepAlive` (a tulajdonos panasza):** *„ez az új megvárásolt zenéim is
/// lassan tölt be"*. A provider korábban `autoDispose` volt, ezért a képernyő
/// minden megnyitása elölről kérdezte le a szervert (0,4–2,0 s) — a megtartott
/// állapot viszont azonnal rajzol.
///
/// **A mentett lista azonnal kimegy** (`LabelLibraryService.load`), a hálózat
/// pedig csak a háttérben egyeztet; amikor az megjött, a provider
/// újraszámol, és a (már friss) mentett listát rajzolja — hálózati várakozás
/// nélkül. A fiókváltás továbbra is újratöltést indít (a UID a kulcsban van).
///
/// **Az életben tartott állapot nem öregedhet meg észrevétlenül:** a `keepAlive`
/// miatt a képernyő újranyitása nem futtatja újra a providert, ezért egy időzítő
/// **30 másodpercenként** újraszámolást kér. A `load()` ilyenkor a mentett listát
/// adja azonnal (nincs töltő állapot: a riverpod a frissítésnél a korábbi értéket
/// rajzolja), és csak a lejárt mentést egyezteti a háttérben. Enélkül egy frissen
/// megvett kiadvány **a munkamenet végéig** hiányozhatna a listából. (Ugyanaz a
/// minta, mint az `eventsProvider` percenkénti újraszámolásánál.)
final labelLibraryProvider =
    FutureProvider.autoDispose<List<LabelLibraryItem>>((ref) async {
      ref.keepAlive();
      final uid = ref.watch(currentUidProvider);
      if (uid == null) return const [];
      final service = ref.watch(labelLibraryServiceProvider);
      // A háttérellenőrzés a képernyő lezárása UTÁN is befejeződhet; ilyenkor
      // nem szabad újraszámolni (a provider „loading" állapotban szűnne meg).
      var disposed = false;
      ref.onDispose(() => disposed = true);
      final refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        ref.invalidateSelf();
      });
      ref.onDispose(refreshTimer.cancel);
      final items = await service.load(uid: uid);
      final pending = service.pendingRefresh(uid);
      if (pending != null) {
        unawaited(
          pending.then((_) {
            if (!disposed) ref.invalidateSelf();
          }),
        );
      }
      return items;
    });

/// A **fiókhoz kötött** helyi tároló. Nincs bejelentkezés → üres UID, és akkor
/// a tároló nem is hoz létre mappát (nem lehet letölteni).
final labelDownloadManagerProvider = Provider<LabelDownloadManager>((ref) {
  final uid = ref.watch(currentUidProvider) ?? '';
  return LabelDownloadManager(uid: uid);
});
