import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/async_cache_store.dart';

/// A **cache-first betöltés tárolója** (alapból `SharedPreferences`).
///
/// Azért provider, hogy **tesztben felülírható** legyen: a cache viselkedését
/// (mentett érték azonnal, háttér-egyeztetés, hiba esetén a mentett adat marad)
/// így valódi értékekkel, memóriabeli tárolóval lehet mérni.
final asyncCacheStoreProvider = Provider<AsyncCacheStore>(
  (ref) => AsyncCacheStore.shared,
);
