import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/onboarding_state.dart';

/// A bemutatóban választott műfajok (helyi tároló). A főoldal és a DJ-ajánlás
/// ebből szab személyre; a bemutató mentés után **érvényteleníti**, ezért a
/// változás azonnal látszik. Hiba esetén üres halmaz (nincs személyre szabás).
final preferredGenresProvider = FutureProvider<Set<String>>((ref) async {
  try {
    return preferredGenresFromPreferences(
      await SharedPreferences.getInstance(),
    );
  } catch (_) {
    return const {};
  }
});
