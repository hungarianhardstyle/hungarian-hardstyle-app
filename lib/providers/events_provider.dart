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

final pastEventsProvider = FutureProvider<List<HuhsEvent>>((ref) async {
  final service = ref.watch(wordpressServiceProvider);
  final events = await service.getEvents(includePast: true);
  final past = events.where((event) => event.isPast).toList();
  past.sort((a, b) => _eventDateTime(b).compareTo(_eventDateTime(a)));
  return List.unmodifiable(past);
});

DateTime _eventDateTime(HuhsEvent event) {
  final date = event.endDate.trim().isNotEmpty
      ? event.endDate.trim()
      : event.startDate.trim();
  final time = event.endDate.trim().isNotEmpty
      ? event.endTime.trim()
      : event.startTime.trim();
  return DateTime.tryParse('$date ${time.isEmpty ? '23:59' : time}') ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

final eventSubmissionGenresProvider = FutureProvider<List<String>>((ref) async {
  final service = ref.watch(wordpressServiceProvider);
  return service.getEventSubmissionGenres();
});
