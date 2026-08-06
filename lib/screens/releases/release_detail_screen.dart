import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/release.dart';
import 'releases_screen.dart';
import '../../widgets/release_preview_player.dart';
import '../../core/navigation/in_app_browser.dart';

class ReleaseDetailScreen extends StatelessWidget {
  final HuhsRelease release;

  const ReleaseDetailScreen({super.key, required this.release});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(release.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
        children: [
          if (release.coverUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: release.coverUrl,
                height: 280,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 18),
          Text(
            release.title,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
          ),
          if (release.genre.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                release.genre,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: release.artists
                .map(
                  (artist) => ActionChip(
                    label: Text(artist.name),
                    avatar: const Icon(Icons.person_outline, size: 18),
                    onPressed: artist.id == 0
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ReleasesScreen(
                                artistId: artist.id,
                                artistName: artist.name,
                              ),
                            ),
                          ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          ...release.tracks.asMap().entries.map(
            (entry) =>
                ReleasePreviewPlayer(track: entry.value, index: entry.key),
          ),
          if (release.links.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Hol érhető el?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: release.links.entries
                  .map(
                    (entry) => OutlinedButton.icon(
                      onPressed: () => openInAppBrowser(context, entry.value),
                      icon: const Icon(Icons.open_in_new),
                      label: Text(_label(entry.key)),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  String _label(String key) => switch (key) {
    'spotify' => 'Spotify',
    'apple_music' => 'Apple Music',
    'beatport' => 'Beatport',
    'hardstyle_com' => 'Hardstyle.com',
    'youtube' => 'YouTube',
    _ => key,
  };
}
