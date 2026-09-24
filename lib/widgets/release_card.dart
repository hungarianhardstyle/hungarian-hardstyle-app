import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/release.dart';
import '../screens/releases/release_detail_screen.dart';
import '../services/wordpress_service.dart';
import 'detail_prefetch.dart';

/// Egy kiadvány kártyája — **egy helyen** él, mert két felület használja:
/// a kiadvány-lista (`ReleasesScreen`) és a DJ-adatlap „Megjelenései" szakasza.
///
/// A megjelenés szándékosan **bitre ugyanaz**, mint a listában volt: a képernyő
/// a borítót 150 px szélesen, gyorsítótárazva rajzolja, a kártyára koppintás
/// pedig a kiadvány adatlapját nyitja meg. A `DetailPrefetch` már a lista
/// rajzolásakor elkezdi letölteni a részletes rekordot, ezért a megnyitás
/// azonnali.
class ReleaseCard extends StatelessWidget {
  final HuhsRelease release;

  const ReleaseCard({super.key, required this.release});

  @override
  Widget build(BuildContext context) {
    return DetailPrefetch(
      onPrefetch: () => WordpressService().getRelease(release.id),
      child: _buildCard(context),
    );
  }

  Widget _buildCard(BuildContext context) {
    final coverCacheWidth = (150 * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(300, 600);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ReleaseDetailScreen(release: release),
          ),
        ),
        child: SizedBox(
          height: 150,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 150,
                child: release.coverUrl.isEmpty
                    ? const ColoredBox(
                        color: Color(0xFF242424),
                        child: Icon(
                          Icons.album,
                          size: 42,
                          color: Colors.redAccent,
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: release.coverUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: coverCacheWidth,
                        maxWidthDiskCache: coverCacheWidth,
                      ),
              ),
              Expanded(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  title: Text(
                    release.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    [
                      if (release.artists.isNotEmpty)
                        release.artists
                            .map((artist) => artist.name)
                            .join(' · '),
                      if (release.releaseDate.isNotEmpty)
                        release.isUpcoming
                            ? 'Hamarosan · Megjelenés: ${release.releaseDate}'
                            : 'Megjelenés: ${release.releaseDate}',
                      if (release.genre.isNotEmpty) release.genre,
                    ].join('\n'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
