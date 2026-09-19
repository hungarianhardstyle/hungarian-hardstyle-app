import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/achievement_service.dart';

final achievementServiceProvider = Provider<AchievementService>(
  (ref) => AchievementService(),
);

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
