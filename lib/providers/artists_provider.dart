import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/artist.dart';
import 'news_provider.dart';

typedef ArtistListQuery = ({String category, String search});

/// A DJ-lista és a DJ-adatlap.
///
/// ⚠️ **MIÉRT `ref.listen` ÉS NEM `ref.watch` (éles hiba javítása, 2026-09-21):**
/// a tulajdonos jelzése szerint *„djk, szervezők listája még mindig villog
/// néha"*. A gyökér: a `publicContentRefreshProvider` a **globális** WordPress
/// frissítés-jelző tükre, amit az app **bármely** WordPress-végpontjának
/// head-cache írása felhúz (`WordpressService.publicContentRefreshGeneration`);
/// a `ref.watch` viszont a függőség változását **reload**-nak veszi (Riverpod),
/// ilyenkor a `when()` alapértelmezéssel a **`loading` ág** fut le, és a kész
/// lista helyett **spinner villan** — majd visszajön ugyanaz a lista.
///
/// A `ref.listen(...) → ref.invalidateSelf()` **frissítés** (refresh), nem
/// reload: a korábbi lista a helyén marad, amíg az új adat meg nem érkezik.
/// (A képernyők emellett `skipLoadingOnReload: true`-t is kapnak, hogy semmilyen
/// más reload-út ne tudja kiürteni a listát.)
final artistsProvider = FutureProvider.autoDispose
    .family<ArtistsPage, ArtistListQuery>((ref, query) async {
      ref.listen(publicContentRefreshProvider, (_, _) => ref.invalidateSelf());
      ref.keepAlive();
      final service = ref.watch(wordpressServiceProvider);
      return service.getArtists(search: query.search, category: query.category);
    });

final artistDetailProvider = FutureProvider.autoDispose.family<Artist, int>((
  ref,
  artistId,
) async {
  ref.listen(publicContentRefreshProvider, (_, _) => ref.invalidateSelf());
  ref.keepAlive();
  final service = ref.watch(wordpressServiceProvider);
  return service.getArtist(artistId);
});
