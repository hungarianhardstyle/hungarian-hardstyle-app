import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/achievement_rank_sync.dart';
import '../services/achievement_service.dart';
import 'community_provider.dart';

final achievementServiceProvider = Provider<AchievementService>(
  (ref) => AchievementService(),
);

/// A saját RANG/JELVÉNY figyelése — a tulajdonos kérése szerint.
///
/// „Cache-ben megvan, de ha szintet lép, indítson egy lekérést": a szintek és a
/// jelvény továbbra is gyorsítótárból jönnek (gyors első kirajzolás), de ha a
/// szerver **más rangot** ír a vetületbe, ez a provider azonnal frissít
/// (`refreshMyAchievementBadge`), és kiüríti a profil/jelvény cache-t — így a
/// chat és a profil a következő kirajzoláskor már az új rangot mutatja.
///
/// Firebase nélkül (pl. widget-tesztben) ez a provider `null`-t ad, és nem
/// nyúl sem a Firebase-hez, sem a hálózathoz — ezt a `Firebase.apps` vizsgálata
/// garantálja, mert a widget-tesztekben a Firebase nincs inicializálva.
final achievementRankSyncProvider = Provider<AchievementRankSync?>((ref) {
  if (Firebase.apps.isEmpty) return null;
  final uid = ref.watch(currentUidProvider)?.trim();
  if (uid == null || uid.isEmpty) return null;
  final service = ref.watch(communityServiceProvider);
  final sync = AchievementRankSync(
    uid: uid,
    projection: service.watchPublicProfile(uid),
    onRankChanged: service.refreshMyAchievementBadge,
  );
  sync.start();
  ref.onDispose(sync.dispose);
  return sync;
});

/// A ranglétra (szintek és jelvények) a SZERVERRŐL.
///
/// A szolgáltatás hálózati hiba esetén a beépített tartalék listát adja, ezért
/// ez a provider **soha nem hibázik el** — a képernyő mindig mutat valamit.
/// A widget-teszt így Firebase nélkül is felülírhatja.
final achievementLevelsProvider = FutureProvider<List<AchievementLevel>>((
  ref,
) async {
  return ref.watch(achievementServiceProvider).fetchLevels();
});
