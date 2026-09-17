import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game.dart';
import 'news_provider.dart';

final activeGameProvider = FutureProvider.autoDispose<HuhsGame?>((ref) {
  ref.keepAlive();
  ref.watch(publicContentRefreshProvider);
  return ref.watch(wordpressServiceProvider).getActiveGame();
});

final latestGameResultsProvider = FutureProvider.autoDispose<HuhsGame?>((ref) {
  ref.keepAlive();
  ref.watch(publicContentRefreshProvider);
  return ref.watch(wordpressServiceProvider).getLatestGameResults();
});
