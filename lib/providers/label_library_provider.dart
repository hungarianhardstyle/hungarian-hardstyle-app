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
final labelLibraryProvider =
    FutureProvider.autoDispose<List<LabelLibraryItem>>((ref) async {
      final uid = ref.watch(currentUidProvider);
      if (uid == null) return const [];
      return ref.watch(labelLibraryServiceProvider).load();
    });

/// A **fiókhoz kötött** helyi tároló. Nincs bejelentkezés → üres UID, és akkor
/// a tároló nem is hoz létre mappát (nem lehet letölteni).
final labelDownloadManagerProvider = Provider<LabelDownloadManager>((ref) {
  final uid = ref.watch(currentUidProvider) ?? '';
  return LabelDownloadManager(uid: uid);
});
