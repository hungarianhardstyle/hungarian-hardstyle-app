import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/event.dart';
import 'news_provider.dart';

final eventsProvider = FutureProvider<List<HuhsEvent>>((ref) async {
  final service = ref.watch(wordpressServiceProvider);
  return service.getEvents();
});

final eventSubmissionGenresProvider = FutureProvider<List<String>>((ref) async {
  final service = ref.watch(wordpressServiceProvider);
  return service.getEventSubmissionGenres();
});
