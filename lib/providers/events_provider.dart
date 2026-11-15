import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/event.dart';
import '../services/wordpress_service.dart';
import 'news_provider.dart';

final eventsPageProvider = FutureProvider.autoDispose<EventsPage>((ref) async {
  ref.keepAlive();
  ref.watch(publicContentRefreshProvider);
  final refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
    ref.invalidateSelf();
  });
  ref.onDispose(refreshTimer.cancel);

  final service = ref.watch(wordpressServiceProvider);
  return service.getEventsPage();
});

final eventsProvider = FutureProvider.autoDispose<List<HuhsEvent>>((ref) async {
  ref.keepAlive();
  return (await ref.watch(eventsPageProvider.future)).items;
});

final pastEventsPageProvider = FutureProvider.autoDispose<EventsPage>((
  ref,
) async {
  ref.keepAlive();
  ref.watch(publicContentRefreshProvider);
  return ref.watch(wordpressServiceProvider).getEventsPage(includePast: true);
});

final pastEventsProvider = FutureProvider.autoDispose<List<HuhsEvent>>((
  ref,
) async {
  ref.keepAlive();
  final events = (await ref.watch(pastEventsPageProvider.future)).items;
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

final eventSubmissionGenresProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  final service = ref.watch(wordpressServiceProvider);
  return service.getEventSubmissionGenres();
});
