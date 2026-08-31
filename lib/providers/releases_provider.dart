import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/release.dart';
import '../services/label_purchase_service.dart';
import 'news_provider.dart';

typedef ReleaseQuery = ({String search, int artistId});

final releasesProvider = FutureProvider.autoDispose
    .family<List<HuhsRelease>, ReleaseQuery>((ref, query) async {
      ref.keepAlive();
      final releases = await ref
          .watch(wordpressServiceProvider)
          .getReleases(search: query.search, artistId: query.artistId);
      LabelPurchaseService.shared.registerProductIds(
        releases.expand(
          (release) => release.products.map((product) => product.id),
        ),
      );
      return sortReleasesByReleaseDate(releases);
    });
