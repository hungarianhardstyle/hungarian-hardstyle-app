import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/release.dart';
import 'news_provider.dart';

typedef ReleaseQuery = ({String search, int artistId});

final releasesProvider = FutureProvider.autoDispose
    .family<List<HuhsRelease>, ReleaseQuery>((ref, query) async {
      return ref
          .watch(wordpressServiceProvider)
          .getReleases(search: query.search, artistId: query.artistId);
    });
