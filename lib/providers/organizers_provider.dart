import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/organizer.dart';
import 'news_provider.dart';

/// A szervező-lista és a szervező-adatlap.
///
/// ⚠️ **MIÉRT `ref.listen` ÉS NEM `ref.watch`:** ugyanaz a villogás-hiba, mint a
/// DJ-listánál (`lib/providers/artists_provider.dart` fejlécében a teljes ok):
/// a globális WordPress frissítés-jelző `watch`-olása **reload**-ot okoz, ami a
/// `when()` `loading` ágát futtatja — a kész lista helyett spinner villan. A
/// `listen` + `invalidateSelf()` **frissítés**, ezért a lista a helyén marad.
final organizersProvider = FutureProvider.autoDispose
    .family<OrganizersPage, String>((ref, search) async {
      ref.listen(publicContentRefreshProvider, (_, _) => ref.invalidateSelf());
      ref.keepAlive();
      final service = ref.watch(wordpressServiceProvider);
      return service.getOrganizers(search: search);
    });

final organizerDetailProvider = FutureProvider.autoDispose
    .family<OrganizerProfile, int>((ref, organizerId) async {
      ref.listen(publicContentRefreshProvider, (_, _) => ref.invalidateSelf());
      ref.keepAlive();
      final service = ref.watch(wordpressServiceProvider);
      return service.getOrganizer(organizerId);
    });
