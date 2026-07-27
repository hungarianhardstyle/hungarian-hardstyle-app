import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/event.dart';
import 'news_provider.dart';

final eventsProvider = FutureProvider<List<HuhsEvent>>((ref) async {
  final refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
    ref.invalidateSelf();
  });
  ref.onDispose(refreshTimer.cancel);

  final service = ref.watch(wordpressServiceProvider);
  return service.getEvents();
});

final eventSubmissionGenresProvider = FutureProvider<List<String>>((ref) async {
  final service = ref.watch(wordpressServiceProvider);
  return service.getEventSubmissionGenres();
});
