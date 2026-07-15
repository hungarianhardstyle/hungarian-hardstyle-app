import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/organizer.dart';
import 'news_provider.dart';

final organizersProvider = FutureProvider.autoDispose
    .family<OrganizersPage, String>((
  ref,
  search,
) async {
  final service = ref.watch(wordpressServiceProvider);
  return service.getOrganizers(search: search);
});

final organizerDetailProvider = FutureProvider.autoDispose
    .family<OrganizerProfile, int>((
  ref,
  organizerId,
) async {
  final service = ref.watch(wordpressServiceProvider);
  return service.getOrganizer(organizerId);
});
