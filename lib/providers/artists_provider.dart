import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/artist.dart';
import 'news_provider.dart';

typedef ArtistListQuery = ({String category, String search});

final artistsProvider = FutureProvider.family<ArtistsPage, ArtistListQuery>((
  ref,
  query,
) async {
  final service = ref.watch(wordpressServiceProvider);
  return service.getArtists(
    search: query.search,
    category: query.category,
  );
});

final artistDetailProvider = FutureProvider.autoDispose.family<Artist, int>((
  ref,
  artistId,
) async {
  final service = ref.watch(wordpressServiceProvider);
  return service.getArtist(artistId);
});
